import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:vervestride/models/meal_item_isar.dart';
import 'package:vervestride/models/activity_isar.dart';
import 'package:vervestride/models/user_profile_isar.dart';
import 'package:vervestride/models/water_log_isar.dart';
import 'package:vervestride/models/calendar_event_isar.dart';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static LocalStorageService? _instance;
  late final Isar _isar;
  bool _initialized = false;
  Future<void>? _initFuture;

  static const String _isarName = 'local_storage';

  LocalStorageService._();

  static LocalStorageService get instance {
    _instance ??= LocalStorageService._();
    return _instance!;
  }

  Future<void> init([Isar? isarInstance]) async {
    if (_initialized) return;

    if (isarInstance != null) {
      _isar = isarInstance;
      _initialized = true;
      return;
    }

    if (_initFuture != null) return _initFuture;
    _initFuture = _doInit();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<bool> getHasSeenOnboarding() async {
    final settings = await getAppSettings();
    final raw = settings?['has_seen_onboarding'];
    if (raw is bool) return raw;
    return false;
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    final settings = await getAppSettings() ?? <String, dynamic>{};
    settings['has_seen_onboarding'] = value;
    await saveAppSettings(settings);
  }

  Future<bool> getIsPremium() async {
    final settings = await getAppSettings();
    final rawPm = settings?['is_premium'];
    final rawAd = settings?['ad_free'];
    if ((rawPm is bool && rawPm == true) || (rawAd is bool && rawAd == true)) {
      return true;
    }

    // Check temporary premium
    final tempUntilStr = settings?['temp_premium_until'];
    if (tempUntilStr != null) {
      final until = DateTime.tryParse(tempUntilStr.toString());
      if (until != null && until.isAfter(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  Future<void> setIsPremium(bool value) async {
    final settings = await getAppSettings() ?? <String, dynamic>{};
    settings['is_premium'] = value;
    await saveAppSettings(settings);
  }

  Future<void> setTempPremiumUntil(DateTime until) async {
    final settings = await getAppSettings() ?? <String, dynamic>{};
    settings['temp_premium_until'] = until.toIso8601String();
    await saveAppSettings(settings);
  }

  Future<DateTime?> getTempPremiumUntil() async {
    final settings = await getAppSettings();
    final raw = settings?['temp_premium_until'];
    if (raw != null) return DateTime.tryParse(raw.toString());
    return null;
  }

  Future<bool> getSparkleEffectEnabled() async {
    final settings = await getAppSettings();
    final raw = settings?['web_sparkle_effect_enabled'];
    if (raw is bool) return raw;
    return false;
  }

  Future<void> setSparkleEffectEnabled(bool value) async {
    final settings = await getAppSettings() ?? <String, dynamic>{};
    settings['web_sparkle_effect_enabled'] = value;
    await saveAppSettings(settings);
  }

  Future<bool> getPerformanceMode() async {
    final settings = await getAppSettings();
    final raw = settings?['performance_mode_enabled'];
    if (raw is bool) return raw;
    return false;
  }

  Future<void> setPerformanceMode(bool value) async {
    final settings = await getAppSettings() ?? <String, dynamic>{};
    settings['performance_mode_enabled'] = value;
    await saveAppSettings(settings);
  }

  Future<void> _doInit() async {
    final existing = Isar.getInstance(_isarName);
    if (existing != null) {
      _isar = existing;
      _initialized = true;
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    try {
      _isar = await Isar.open(
        [
          MealItemIsarSchema,
          ActivityIsarSchema,
          UserProfileIsarSchema,
          WaterLogIsarSchema,
          CalendarEventIsarSchema,
        ],
        directory: dir.path,
        name: _isarName,
      );
      _initialized = true;
    } catch (e, stack) {
      debugPrint('Isar.open error: $e');
      debugPrint(stack.toString());
      // Last ditch effort - maybe it opened in another isolate?
      final retry = Isar.getInstance(_isarName);
      if (retry != null) {
        _isar = retry;
        _initialized = true;
      } else {
        rethrow;
      }
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await init();
  }

  Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    final dir = await getApplicationDocumentsDirectory();
    // Always use the same file regardless of userId to avoid data loss
    // Subscription data is device-local, not user-specific
    final file = File('${dir.path}${Platform.pathSeparator}app_settings.json');
    debugPrint('💾 Saving app settings to: ${file.path}');
    await file.writeAsString(jsonEncode(settings));
  }

  Future<Map<String, dynamic>?> getAppSettings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      // Always use the same file regardless of userId to avoid data loss
      final file = File('${dir.path}${Platform.pathSeparator}app_settings.json');
      if (!await file.exists()) {
        debugPrint('📦 App settings file not found: ${file.path}');
        return null;
      }
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        debugPrint('📦 Loaded app settings from: ${file.path}');
        return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error reading app settings: $e');
      return null;
    }
  }

  Future<Map<String, List<String>>> getDebugBehaviorLog() async {
    final settings = await getAppSettings();
    final raw = settings?['debug_behavior_log'];
    if (raw is! Map) return <String, List<String>>{};

    final out = <String, List<String>>{};
    for (final e in raw.entries) {
      final key = e.key?.toString();
      if (key == null) continue;
      final v = e.value;
      if (v is List) {
        out[key] = v.map((x) => x.toString()).toList();
      }
    }
    return out;
  }

  Future<List<String>> getDebugBehaviorLogForDay(String dayKey) async {
    final all = await getDebugBehaviorLog();
    return all[dayKey] ?? <String>[];
  }

  Future<void> appendDebugBehaviorLog(String dayKey, String entry) async {
    final settings = await getAppSettings() ?? <String, dynamic>{};
    final raw = settings['debug_behavior_log'];

    final map = <String, dynamic>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = e.key?.toString();
        if (k == null) continue;
        map[k] = e.value;
      }
    }

    final listRaw = map[dayKey];
    final list = (listRaw is List)
        ? listRaw.map((x) => x.toString()).toList()
        : <String>[];
    list.add(entry);
    map[dayKey] = list;

    settings['debug_behavior_log'] = map;
    await saveAppSettings(settings);
  }

  Future<void> clearDebugBehaviorLog() async {
    final settings = await getAppSettings() ?? <String, dynamic>{};
    settings.remove('debug_behavior_log');
    await saveAppSettings(settings);
  }

  Future<void> clearUserData() async {
    final settings = await getAppSettings() ?? <String, dynamic>{};
    settings.remove('is_premium');
    settings.remove('ad_free');
    settings.remove('temp_premium_until');
    // Keep onboarding status as that's often device-specific, but clear user auth data
    await saveAppSettings(settings);

    // Also clear Isar data for user privacy if needed, but for now focus on settings
    // await _isar.writeTxn(() async {
    //   await _isar.clear();
    // });
  }

  Map<String, bool> _defaultRingEnabled() {
    return {
      'calories': true,
      'protein': true,
      'burn': true,
      'water': true,
      'fiber': false,
      'sodium': false,
      'addedSugar': false,
    };
  }

  Map<String, int> _defaultRingWeights() {
    return {
      'calories': 25,
      'protein': 25,
      'burn': 25,
      'water': 25,
      'fiber': 0,
      'sodium': 0,
      'addedSugar': 0,
    };
  }

  Future<Map<String, bool>> getRingEnabled() async {
    final settings = await getAppSettings();
    final raw = settings?['ring_enabled'];
    if (raw is Map) {
      final defaults = _defaultRingEnabled();
      final out = <String, bool>{...defaults};
      for (final e in raw.entries) {
        final k = e.key?.toString();
        if (k == null) continue;
        final v = e.value;
        if (v is bool) out[k] = v;
      }
      return out;
    }
    return _defaultRingEnabled();
  }

  Future<void> saveRingEnabled(Map<String, bool> enabled) async {
    final existing = await getAppSettings() ?? <String, dynamic>{};
    existing['ring_enabled'] = enabled;
    await saveAppSettings(existing);
  }

  Future<Map<String, int>> getRingWeights() async {
    final settings = await getAppSettings();
    final raw = settings?['ring_weights'];
    if (raw is Map) {
      final defaults = _defaultRingWeights();
      final out = <String, int>{...defaults};
      for (final e in raw.entries) {
        final k = e.key?.toString();
        if (k == null) continue;
        final v = e.value;
        if (v is num) out[k] = v.round().clamp(0, 100);
      }
      return out;
    }
    return _defaultRingWeights();
  }

  Future<void> saveRingWeights(Map<String, int> weights) async {
    final existing = await getAppSettings() ?? <String, dynamic>{};
    final sanitized = <String, int>{};
    for (final e in weights.entries) {
      sanitized[e.key] = e.value.clamp(0, 100);
    }
    existing['ring_weights'] = sanitized;
    await saveAppSettings(existing);
  }

  // AI Settings Methods
  Future<void> saveAISettings(Map<String, dynamic> aiSettings) async {
    final existing = await getAppSettings() ?? <String, dynamic>{};
    existing['ai_settings'] = aiSettings;
    await saveAppSettings(existing);
  }

  Future<Map<String, dynamic>> getAISettings() async {
    final settings = await getAppSettings();
    final aiSettings = settings?['ai_settings'];
    if (aiSettings is Map) {
      return aiSettings.cast<String, dynamic>();
    }
    return {};
  }

  /// VerveStride AI — no API key needed, always enabled
  Future<bool> isAIEnabled() async => true;

  Future<bool> isAIFeatureEnabled(String feature) async {
    final aiSettings = await getAISettings();
    return aiSettings['${feature}_enabled'] ?? true;
  }

  Future<bool> getAIFloatingAssistantHidden() async {
    final settings = await getAppSettings();
    final raw = settings?['ai_floating_assistant_hidden'];
    if (raw is bool) return raw;
    return false;
  }

  Future<void> setAIFloatingAssistantHidden(bool hidden) async {
    final settings = await getAppSettings() ?? <String, dynamic>{};
    settings['ai_floating_assistant_hidden'] = hidden;
    await saveAppSettings(settings);
  }

  Future<Map<String, double>?> getAIFloatingPosition() async {
    final settings = await getAppSettings();
    final raw = settings?['ai_floating_position'];
    if (raw is Map) {
      final x = (raw['x'] as num?)?.toDouble();
      final y = (raw['y'] as num?)?.toDouble();
      if (x != null && y != null) return {'x': x, 'y': y};
    }
    return null;
  }

  Future<void> setAIFloatingPosition(double x, double y) async {
    final settings = await getAppSettings() ?? <String, dynamic>{};
    settings['ai_floating_position'] = {'x': x, 'y': y};
    await saveAppSettings(settings);
  }

  Future<List<Map<String, dynamic>>> getAIChatHistory() async {
    final settings = await getAppSettings();
    final raw = settings?['ai_chat_history'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<void> saveAIChatHistory(List<Map<String, dynamic>> history) async {
    final existing = await getAppSettings() ?? <String, dynamic>{};
    existing['ai_chat_history'] = history;
    await saveAppSettings(existing);
  }

  Future<List<Map<String, dynamic>>> getAISavedMemories() async {
    final settings = await getAppSettings();
    final raw = settings?['ai_saved_memories'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<void> saveAISavedMemories(List<Map<String, dynamic>> memories) async {
    final existing = await getAppSettings() ?? <String, dynamic>{};
    existing['ai_saved_memories'] = memories;
    await saveAppSettings(existing);
  }

  Future<void> clearAIChatData() async {
    final existing = await getAppSettings() ?? <String, dynamic>{};
    existing.remove('ai_chat_history');
    existing.remove('ai_saved_memories');
    existing.remove('ai_chat_sessions');
    await saveAppSettings(existing);
  }

  // AI Chat Session Management
  Future<Map<String, dynamic>> getAIChatSessions() async {
    final settings = await getAppSettings();
    final raw = settings?['ai_chat_sessions'];
    if (raw is! Map) return <String, dynamic>{};
    return raw.cast<String, dynamic>();
  }

  Future<void> saveAIChatSessions(Map<String, dynamic> sessions) async {
    final existing = await getAppSettings() ?? <String, dynamic>{};
    existing['ai_chat_sessions'] = sessions;
    await saveAppSettings(existing);
  }

  Future<bool> isRingMetricEnabled(String metricKey) async {
    final map = await getRingEnabled();
    return map[metricKey] ?? (_defaultRingEnabled()[metricKey] ?? false);
  }

  Future<void> saveMeals(List<Map<String, dynamic>> meals) async {
    await _ensureInitialized();
    final items = meals.map((m) => MealItemIsar.fromMap(m)).toList();

    for (final item in items) {
      final existing =
          await _isar.mealItemIsars.filter().uuidEqualTo(item.uuid).findFirst();
      if (existing != null) {
        item.id = existing.id;
      }
    }

    await _isar.writeTxn(() async {
      await _isar.mealItemIsars.putAll(items);
    });
  }

  Future<void> addMeal(Map<String, dynamic> meal) async {
    await _ensureInitialized();
    final item = MealItemIsar.fromMap(meal);

    final existing =
        await _isar.mealItemIsars.filter().uuidEqualTo(item.uuid).findFirst();
    if (existing != null) {
      item.id = existing.id;
    }

    await _isar.writeTxn(() async {
      await _isar.mealItemIsars.put(item);
    });
  }

  Future<void> updateMeal(String mealId, Map<String, dynamic> meal) async {
    await addMeal({
      ...meal,
      'id': mealId,
    });
  }

  Future<void> deleteMeal(String mealId) async {
    await _ensureInitialized();
    final item =
        await _isar.mealItemIsars.filter().uuidEqualTo(mealId).findFirst();
    if (item == null) return;
    await _isar.writeTxn(() async {
      await _isar.mealItemIsars.delete(item.id);
    });
  }

  Future<void> saveActivities(List<Map<String, dynamic>> activities) async {
    await _ensureInitialized();
    final items = activities.map((a) => ActivityIsar.fromMap(a)).toList();

    for (final item in items) {
      final existing =
          await _isar.activityIsars.filter().uuidEqualTo(item.uuid).findFirst();
      if (existing != null) {
        item.id = existing.id;
      }
    }

    await _isar.writeTxn(() async {
      await _isar.activityIsars.putAll(items);
    });
  }

  Future<void> addActivity(Map<String, dynamic> activity) async {
    await _ensureInitialized();
    final item = ActivityIsar.fromMap(activity);

    final existing =
        await _isar.activityIsars.filter().uuidEqualTo(item.uuid).findFirst();
    if (existing != null) {
      item.id = existing.id;
    }

    await _isar.writeTxn(() async {
      await _isar.activityIsars.put(item);
    });
  }

  Future<void> updateActivity(
      String activityId, Map<String, dynamic> payload) async {
    await _ensureInitialized();
    final existing =
        await _isar.activityIsars.filter().uuidEqualTo(activityId).findFirst();
    if (existing == null) return;
    final updated = ActivityIsar.fromMap(payload);
    updated.id = existing.id;
    await _isar.writeTxn(() async {
      await _isar.activityIsars.put(updated);
    });
  }

  Future<void> deleteActivity(String activityId) async {
    await _ensureInitialized();
    final item =
        await _isar.activityIsars.filter().uuidEqualTo(activityId).findFirst();
    if (item == null) return;
    await _isar.writeTxn(() async {
      await _isar.activityIsars.delete(item.id);
    });
  }

  Future<List<MealItemIsar>> getMealsForDate(DateTime day) async {
    await _ensureInitialized();
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    return await _isar.mealItemIsars
        .where()
        .createdAtBetween(start, end)
        .sortByCreatedAt()
        .findAll();
  }

  Future<List<ActivityIsar>> getActivitiesForDate(DateTime day) async {
    await _ensureInitialized();
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    return await _isar.activityIsars
        .where()
        .createdAtBetween(start, end)
        .sortByCreatedAt()
        .findAll();
  }

  Future<List<MealItemIsar>> getMealsForMonth(DateTime month) async {
    await _ensureInitialized();
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    return await _isar.mealItemIsars
        .where()
        .createdAtBetween(start, end)
        .sortByCreatedAt()
        .findAll();
  }

  Future<List<ActivityIsar>> getActivitiesForMonth(DateTime month) async {
    await _ensureInitialized();
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    return await _isar.activityIsars
        .where()
        .createdAtBetween(start, end)
        .sortByCreatedAt()
        .findAll();
  }

  Future<void> deleteMealsForMonth(DateTime month) async {
    await _ensureInitialized();
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    final items = await _isar.mealItemIsars
        .where()
        .createdAtBetween(start, end)
        .findAll();
    await _isar.writeTxn(() async {
      await _isar.mealItemIsars.deleteAll(items.map((e) => e.id).toList());
    });
  }

  Future<void> deleteActivitiesForMonth(DateTime month) async {
    await _ensureInitialized();
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    final items = await _isar.activityIsars
        .where()
        .createdAtBetween(start, end)
        .findAll();
    await _isar.writeTxn(() async {
      await _isar.activityIsars.deleteAll(items.map((e) => e.id).toList());
    });
  }

  Future<bool> hasAnyDataBefore(DateTime cutoff) async {
    await _ensureInitialized();
    final meal = await _isar.mealItemIsars
        .filter()
        .createdAtLessThan(cutoff)
        .findFirst();
    if (meal != null) return true;

    final activity = await _isar.activityIsars
        .filter()
        .createdAtLessThan(cutoff)
        .findFirst();
    return activity != null;
  }

  Future<List<MealItemIsar>> getMealsInRange(
      DateTime start, DateTime end) async {
    await _ensureInitialized();
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return await _isar.mealItemIsars
        .where()
        .createdAtBetween(s, e)
        .sortByCreatedAt()
        .findAll();
  }

  Future<List<ActivityIsar>> getActivitiesInRange(
      DateTime start, DateTime end) async {
    await _ensureInitialized();
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return await _isar.activityIsars
        .where()
        .createdAtBetween(s, e)
        .sortByCreatedAt()
        .findAll();
  }

  Future<Map<String, int>> getWaterByDayInRange(
      DateTime start, DateTime end) async {
    await _ensureInitialized();
    final keys = <String>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final limit = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(limit)) {
      keys.add(_dayKey(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }

    final entries = await _isar.waterLogIsars
        .filter()
        .anyOf(keys, (q, String key) => q.dayKeyEqualTo(key))
        .findAll();

    final result = <String, int>{};
    for (final e in entries) {
      if (e.amountMl > 0) result[e.dayKey] = e.amountMl;
    }
    return result;
  }

  Future<List<CalendarEventIsar>> getEventsInRange(
      DateTime start, DateTime end) async {
    await _ensureInitialized();
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return await _isar.calendarEventIsars
        .where()
        .createdAtBetween(s, e)
        .sortByCreatedAt()
        .findAll();
  }

  Future<void> deleteInRange(DateTime start, DateTime end) async {
    await _ensureInitialized();
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

    final meals =
        await _isar.mealItemIsars.where().createdAtBetween(s, e).findAll();
    final activities =
        await _isar.activityIsars.where().createdAtBetween(s, e).findAll();
    final events =
        await _isar.calendarEventIsars.where().createdAtBetween(s, e).findAll();

    final waterKeys = <String>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final limit = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(limit)) {
      waterKeys.add(_dayKey(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }
    final waterEntries = await _isar.waterLogIsars
        .filter()
        .anyOf(waterKeys, (q, String key) => q.dayKeyEqualTo(key))
        .findAll();

    await _isar.writeTxn(() async {
      await _isar.mealItemIsars.deleteAll(meals.map((e) => e.id).toList());
      await _isar.activityIsars.deleteAll(activities.map((e) => e.id).toList());
      await _isar.calendarEventIsars
          .deleteAll(events.map((e) => e.id).toList());
      await _isar.waterLogIsars
          .deleteAll(waterEntries.map((e) => e.id).toList());
    });
  }

  Future<void> saveUserProfile(Map<String, dynamic> profileData) async {
    await _ensureInitialized();
    final existing = await _isar.userProfileIsars.where().findFirst();
    final profile = UserProfileIsar(
      uuid: existing?.uuid ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: profileData['name'] ?? '',
      age: profileData['age'] ?? 25,
      gender: profileData['gender'] ?? 'male',
      heightCm: profileData['heightCm'] ?? 170.0,
      weightKg: profileData['weightKg'] ?? 70.0,
      activityLevel: profileData['activityLevel'] ?? 3,
      goal: profileData['goal'] ?? 'maintain',
      targetWeightKg: profileData['targetWeightKg'] ?? 0.0,
      goalStartDate: (() {
        final raw = profileData['goalStartDate'] ?? profileData['goalDate'];
        return raw != null ? DateTime.tryParse(raw.toString()) : null;
      })(),
      goalEndDate: (() {
        final raw = profileData['goalEndDate'];
        return raw != null ? DateTime.tryParse(raw.toString()) : null;
      })(),
      goalsJson: profileData['goals'] != null
          ? jsonEncode(profileData['goals'])
          : null,
    );

    if (existing != null) {
      profile.id = existing.id;
    }

    await _isar.writeTxn(() async {
      await _isar.userProfileIsars.put(profile);
    });
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    await _ensureInitialized();
    final profiles = await _isar.userProfileIsars.where().findAll();
    return profiles.isNotEmpty ? profiles.first.toJson() : null;
  }

  Future<int> getWaterForDate(DateTime day) async {
    await _ensureInitialized();
    final key = _dayKey(day);
    final existing =
        await _isar.waterLogIsars.filter().dayKeyEqualTo(key).findFirst();
    return existing?.amountMl ?? 0;
  }

  Future<void> setWaterForDate(DateTime day, int ml) async {
    await _ensureInitialized();
    final key = _dayKey(day);
    final existing =
        await _isar.waterLogIsars.filter().dayKeyEqualTo(key).findFirst();

    final entry = existing ?? (WaterLogIsar()..dayKey = key);
    entry.amountMl = ml.clamp(0, double.infinity).toInt();
    entry.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.waterLogIsars.put(entry);
    });
  }

  Future<void> addWaterForToday(int ml) async {
    await _ensureInitialized();
    final key = _dayKey(DateTime.now());
    final existing =
        await _isar.waterLogIsars.filter().dayKeyEqualTo(key).findFirst();

    final entry = existing ?? (WaterLogIsar()..dayKey = key);
    entry.amountMl = (existing?.amountMl ?? 0) + ml;
    entry.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.waterLogIsars.put(entry);
    });
  }

  Future<void> removeWaterForToday(int ml) async {
    await _ensureInitialized();
    final key = _dayKey(DateTime.now());
    final existing =
        await _isar.waterLogIsars.filter().dayKeyEqualTo(key).findFirst();
    if (existing == null) return;
    existing.amountMl =
        (existing.amountMl - ml).clamp(0, double.infinity).toInt();
    existing.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.waterLogIsars.put(existing);
    });
  }

  Future<Map<String, int>> getWaterByDayForMonth(DateTime month) async {
    await _ensureInitialized();
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final last = nextMonth.subtract(const Duration(days: 1));

    final keys = <String>[];
    for (int d = 1; d <= last.day; d++) {
      keys.add(_dayKey(DateTime(month.year, month.month, d)));
    }

    final entries = await _isar.waterLogIsars
        .filter()
        .anyOf(keys, (q, String key) => q.dayKeyEqualTo(key))
        .findAll();

    final result = <String, int>{};
    for (final e in entries) {
      if (e.amountMl > 0) result[e.dayKey] = e.amountMl;
    }
    return result;
  }

  Future<void> addCalendarEvent({
    required DateTime day,
    required String title,
    String? note,
  }) async {
    await _ensureInitialized();
    final e = CalendarEventIsar();
    e.dayKey = _dayKey(day);
    e.title = title;
    e.note = note;
    e.createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.calendarEventIsars.put(e);
    });
  }

  Future<void> deleteCalendarEvent(String eventId) async {
    await _ensureInitialized();
    final existing = await _isar.calendarEventIsars
        .filter()
        .uuidEqualTo(eventId)
        .findFirst();
    if (existing == null) return;
    await _isar.writeTxn(() async {
      await _isar.calendarEventIsars.delete(existing.id);
    });
  }

  Future<void> updateCalendarEvent({
    required String eventId,
    required String title,
    String? note,
  }) async {
    await _ensureInitialized();
    final existing = await _isar.calendarEventIsars
        .filter()
        .uuidEqualTo(eventId)
        .findFirst();
    if (existing == null) return;

    existing.title = title;
    existing.note = note;

    await _isar.writeTxn(() async {
      await _isar.calendarEventIsars.put(existing);
    });
  }

  Future<List<Map<String, dynamic>>> getCalendarEventsForDate(
      DateTime day) async {
    await _ensureInitialized();
    final key = _dayKey(day);
    final events = await _isar.calendarEventIsars
        .filter()
        .dayKeyEqualTo(key)
        .sortByCreatedAtDesc()
        .findAll();
    return events.map((e) => e.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> getCalendarEventsForMonth(
      DateTime month) async {
    await _ensureInitialized();
    final prefix =
        '${month.year.toString().padLeft(4, '0')}${month.month.toString().padLeft(2, '0')}';
    final events = await _isar.calendarEventIsars
        .filter()
        .dayKeyStartsWith(prefix)
        .sortByCreatedAtDesc()
        .findAll();
    return events.map((e) => e.toJson()).toList();
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
