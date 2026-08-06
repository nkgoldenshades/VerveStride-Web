import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'credits_service.dart';

/// Cloud Sync Service
///
/// Storage is LOCAL by default for all users.
/// Cloud sync is an optional feature for Pro/Elite/Lifetime subscribers.
///
/// What syncs to cloud (Pro+):
///   - User profile (name, age, weight, goals)
///   - Workouts
///   - Meals
///   - Water intake
///   - Calendar events
///   - AI chat threads
///   - App settings
///
/// What stays local only (all tiers):
///   - AI model selection
///   - UI preferences
///   - Cached data
///
/// Users can:
///   - Enable/disable cloud sync
///   - Download their cloud data to device
///   - Delete all cloud data
class CloudSyncService extends ChangeNotifier {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  bool _syncEnabled = false;
  bool _isSyncing = false;
  DateTime? _lastSyncAt;
  String? _syncError;

  bool get syncEnabled => _syncEnabled;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get syncError => _syncError;

  /// User can sync if they are signed in and have enough credits
  bool get canUseCloudSync {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return CreditsService.instance.availableCredits >= CreditsService.creditsPerCloudBackup;
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('user_data').doc(uid);
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    try {
      final settings = await LocalStorageService.instance.getAppSettings();
      _syncEnabled = settings?['cloud_sync_enabled'] as bool? ?? false;
      _lastSyncAt = settings?['cloud_sync_last_at'] != null
          ? DateTime.tryParse(settings!['cloud_sync_last_at'] as String)
          : null;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ CloudSync load error: $e');
    }
  }

  Future<void> setSyncEnabled(bool enabled) async {
    if (!canUseCloudSync && enabled) return;
    _syncEnabled = enabled;
    final settings = await LocalStorageService.instance.getAppSettings() ?? {};
    settings['cloud_sync_enabled'] = enabled;
    await LocalStorageService.instance.saveAppSettings(settings);
    notifyListeners();
    if (enabled) await syncToCloud();
  }

  // ── Upload to cloud ───────────────────────────────────────────────────────

  /// Sync all local data to Firestore — costs [CreditsService.creditsPerCloudBackup] credits
  Future<SyncResult> syncToCloud() async {
    if (!canUseCloudSync) {
      return SyncResult.error('Not enough credits. Cloud backup costs ${CreditsService.creditsPerCloudBackup} credits.');
    }
    if (_uid == null) {
      return SyncResult.error('Not signed in.');
    }
    if (_isSyncing) {
      return SyncResult.error('Sync already in progress.');
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final storage = LocalStorageService.instance;
      final now = DateTime.now();

      // Gather all local data
      final profile = await storage.getUserProfile();
      final appSettings = await storage.getAppSettings();
      final aiSettings = await storage.getAISettings();
      final chatHistory = await storage.getAIChatHistory();

      // Build the sync payload
      final payload = <String, dynamic>{
        'synced_at': now.toIso8601String(),
        'app_version': '1.0.0',
        'platform': defaultTargetPlatform.name,
      };

      if (profile != null) payload['profile'] = profile;
      if (appSettings != null) {
        // Strip sensitive/device-specific keys before syncing
        final syncableSettings = Map<String, dynamic>.from(appSettings)
          ..remove('ai_floating_position_x')
          ..remove('ai_floating_position_y')
          ..remove('ai_floating_hidden');
        payload['app_settings'] = syncableSettings;
      }
      if (aiSettings.isNotEmpty) {
        // Strip model selection (device preference, not synced)
        final syncableAI = Map<String, dynamic>.from(aiSettings)
          ..remove('selected_general_model')
          ..remove('selected_vision_model')
          ..remove('selected_live_model');
        payload['ai_settings'] = syncableAI;
      }
      if (chatHistory.isNotEmpty) {
        payload['chat_history'] = chatHistory;
      }

      // Write to Firestore
      await _userDoc!.set(payload, SetOptions(merge: true));

      // Deduct credits for the backup
      await CreditsService.instance.useCredits(
        CreditsService.creditsPerCloudBackup,
        description: 'Cloud backup',
      );

      // Update last sync time
      _lastSyncAt = now;
      final settings = await storage.getAppSettings() ?? {};
      settings['cloud_sync_last_at'] = now.toIso8601String();
      await storage.saveAppSettings(settings);

      _isSyncing = false;
      notifyListeners();
      debugPrint('✅ Cloud sync complete: ${now.toIso8601String()}');
      return SyncResult.success('Data synced to cloud successfully.');
    } catch (e) {
      _isSyncing = false;
      _syncError = e.toString();
      notifyListeners();
      debugPrint('❌ Cloud sync error: $e');
      return SyncResult.error('Sync failed: ${e.toString()}');
    }
  }

  // ── Download from cloud ───────────────────────────────────────────────────

  /// Download cloud data and restore to local storage
  Future<SyncResult> downloadFromCloud() async {
    if (!canUseCloudSync) {
      return SyncResult.error('Not enough credits. Cloud backup costs ${CreditsService.creditsPerCloudBackup} credits.');
    }
    if (_uid == null) {
      return SyncResult.error('Not signed in.');
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final doc = await _userDoc!.get();
      if (!doc.exists || doc.data() == null) {
        _isSyncing = false;
        notifyListeners();
        return SyncResult.error('No cloud backup found.');
      }

      final data = doc.data() as Map<String, dynamic>;
      final storage = LocalStorageService.instance;

      // Restore profile
      if (data['profile'] != null) {
        await storage.saveUserProfile(
          Map<String, dynamic>.from(data['profile'] as Map),
        );
      }

      // Restore app settings (merge, don't overwrite device-specific keys)
      if (data['app_settings'] != null) {
        final current = await storage.getAppSettings() ?? {};
        final cloud = Map<String, dynamic>.from(data['app_settings'] as Map);
        // Keep device-specific keys from local
        final merged = {...cloud, ...{
          'ai_floating_position_x': current['ai_floating_position_x'],
          'ai_floating_position_y': current['ai_floating_position_y'],
          'ai_floating_hidden': current['ai_floating_hidden'],
          'selected_general_model': current['selected_general_model'],
          'selected_vision_model': current['selected_vision_model'],
          'selected_live_model': current['selected_live_model'],
        }..removeWhere((k, v) => v == null)};
        await storage.saveAppSettings(merged);
      }

      // Restore AI settings
      if (data['ai_settings'] != null) {
        final current = await storage.getAISettings();
        final cloud = Map<String, dynamic>.from(data['ai_settings'] as Map);
        final merged = {...cloud, ...current}; // local model selection wins
        await storage.saveAISettings(merged);
      }

      // Restore chat history
      if (data['chat_history'] != null) {
        final history = (data['chat_history'] as List)
            .cast<Map<String, dynamic>>();
        await storage.saveAIChatHistory(history);
      }

      _isSyncing = false;
      notifyListeners();
      debugPrint('✅ Cloud data downloaded and restored');
      return SyncResult.success(
        'Data restored from cloud backup (${_formatDate(data['synced_at'] as String?)}).',
      );
    } catch (e) {
      _isSyncing = false;
      _syncError = e.toString();
      notifyListeners();
      debugPrint('❌ Cloud download error: $e');
      return SyncResult.error('Download failed: ${e.toString()}');
    }
  }

  // ── Delete from cloud ─────────────────────────────────────────────────────

  /// Permanently delete all cloud backup data
  Future<SyncResult> deleteFromCloud() async {
    if (_uid == null) {
      return SyncResult.error('Not signed in.');
    }

    try {
      await _userDoc!.delete();
      _lastSyncAt = null;
      _syncEnabled = false;

      final settings = await LocalStorageService.instance.getAppSettings() ?? {};
      settings.remove('cloud_sync_last_at');
      settings['cloud_sync_enabled'] = false;
      await LocalStorageService.instance.saveAppSettings(settings);

      notifyListeners();
      debugPrint('✅ Cloud data deleted');
      return SyncResult.success('All cloud data deleted permanently.');
    } catch (e) {
      debugPrint('❌ Cloud delete error: $e');
      return SyncResult.error('Delete failed: ${e.toString()}');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get lastSyncLabel {
    if (_lastSyncAt == null) return 'Never synced';
    final diff = DateTime.now().difference(_lastSyncAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'unknown date';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'unknown date';
    }
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;

  const SyncResult._({required this.success, required this.message});

  factory SyncResult.success(String message) =>
      SyncResult._(success: true, message: message);

  factory SyncResult.error(String message) =>
      SyncResult._(success: false, message: message);
}
