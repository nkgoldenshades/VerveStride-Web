import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:vervestride/models/profile_isar.dart';
import 'package:vervestride/models/goal_isar.dart';

class IsarService {
  static late Isar _isar;
  static bool _initialized = false;
  static Future<void>? _initFuture;

  static const String _isarName = 'profile';

  static Future<void> initialize() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture;
    _initFuture = _doInit();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  static Future<void> _doInit() async {
    final dir = await getApplicationDocumentsDirectory();
    final existing = Isar.getInstance(_isarName);
    if (existing != null) {
      _isar = existing;
      _initialized = true;
      return;
    }

    _isar = await Isar.open(
      [ProfileSchema, GoalSchema],
      directory: dir.path,
      name: _isarName,
    );
    _initialized = true;
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await initialize();
  }

  static Isar get instance {
    if (!_initialized) {
      throw StateError(
          'IsarService not initialized. Call IsarService.initialize() first.');
    }
    return _isar;
  }

  static Future<Profile?> getProfile() async {
    await _ensureInitialized();
    return await _isar.profiles.where().findFirst();
  }

  static Future<void> saveProfile(Profile profile) async {
    await _ensureInitialized();
    profile.updatedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.profiles.put(profile));
  }

  static Future<List<Goal>> getAllGoals() async {
    await _ensureInitialized();
    return await _isar.goals.where().sortByFromDate().findAll();
  }

  static Future<void> saveGoal(Goal goal) async {
    await _ensureInitialized();
    await _isar.writeTxn(() => _isar.goals.put(goal));
  }

  static Future<void> deleteGoal(int goalId) async {
    await _ensureInitialized();
    await _isar.writeTxn(() => _isar.goals.delete(goalId));
  }

  static Future<Goal?> getActiveGoalForDate(DateTime date) async {
    await _ensureInitialized();
    final goals = await _isar.goals.where().findAll();
    for (final goal in goals) {
      if (goal.isActiveForDate(date)) return goal;
    }
    return null;
  }

  static Future<bool> checkGoalOverlap(
    DateTime newFrom,
    DateTime newTo, {
    int? excludeId,
  }) async {
    await _ensureInitialized();
    final goals = await _isar.goals.where().findAll();
    for (final goal in goals) {
      if (excludeId != null && goal.id == excludeId) continue;
      final overlap =
          newFrom.isBefore(goal.toDate) && newTo.isAfter(goal.fromDate);
      if (overlap) return true;
    }
    return false;
  }
}
