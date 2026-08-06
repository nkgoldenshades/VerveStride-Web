import 'package:vervestride/models/profile.dart';
import 'package:vervestride/models/goal.dart';

class IsarService {
  static bool _initialized = false;

  static Profile? _profile;
  static final List<Goal> _goals = [];
  static int _nextGoalId = 1;

  static Future<void> initialize() async {
    _initialized = true;
  }

  static Future<Profile?> getProfile() async {
    if (!_initialized) await initialize();
    return _profile;
  }

  static Future<void> saveProfile(Profile profile) async {
    if (!_initialized) await initialize();

    profile.updatedAt = DateTime.now();
    _profile = profile;
  }

  static Future<List<Goal>> getAllGoals() async {
    if (!_initialized) await initialize();

    _goals.sort((a, b) => a.fromDate.compareTo(b.fromDate));
    return List<Goal>.from(_goals);
  }

  static Future<void> saveGoal(Goal goal) async {
    if (!_initialized) await initialize();

    if (goal.id == 0) {
      goal.id = _nextGoalId++;
    }

    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx >= 0) {
      _goals[idx] = goal;
    } else {
      _goals.add(goal);
    }
  }

  static Future<void> deleteGoal(int goalId) async {
    if (!_initialized) await initialize();
    _goals.removeWhere((g) => g.id == goalId);
  }

  static Future<Goal?> getActiveGoalForDate(DateTime date) async {
    if (!_initialized) await initialize();

    for (final goal in _goals) {
      if (goal.isActiveForDate(date)) return goal;
    }
    return null;
  }

  static Future<bool> checkGoalOverlap(
    DateTime newFrom,
    DateTime newTo, {
    int? excludeId,
  }) async {
    if (!_initialized) await initialize();

    for (final goal in _goals) {
      if (excludeId != null && goal.id == excludeId) continue;
      final overlap =
          newFrom.isBefore(goal.toDate) && newTo.isAfter(goal.fromDate);
      if (overlap) return true;
    }
    return false;
  }
}
