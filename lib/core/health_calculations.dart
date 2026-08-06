import 'package:vervestride/models/user_profile.dart';
import '../services/local_storage_service.dart';

Future<int> recommendedWaterMl() async {
  final json = await LocalStorageService.instance.getUserProfile();
  if (json == null) return 3000;
  final profile = UserProfile.fromJson(json);
  final targets = profile.calculateDailyTargets();
  final fromTargets = (targets['waterMl'] as num?)?.toInt();
  if (fromTargets != null && fromTargets > 0) return fromTargets;

  return (profile.weightKg * 35).round();
}

Future<int> waterGoalForDate(DateTime date) async {
  final json = await LocalStorageService.instance.getUserProfile();
  if (json == null) return 3000;
  final profile = UserProfile.fromJson(json);
  final targets = profile.calculateDailyTargets(forDate: date);
  final fromTargets = (targets['waterMl'] as num?)?.toInt();
  if (fromTargets != null && fromTargets > 0) return fromTargets;
  return (profile.weightKg * 35).round();
}

Future<int> waterDrunkMlForDate(DateTime date) async {
  return LocalStorageService.instance.getWaterForDate(date);
}

Future<int> todayDrunkMl() async {
  return LocalStorageService.instance.getWaterForDate(DateTime.now());
}

Future<void> addWaterLog(int ml) async {
  await LocalStorageService.instance.addWaterForToday(ml);
}

Future<void> removeWaterLog(int ml) async {
  await LocalStorageService.instance.removeWaterForToday(ml);
}

Future<void> setWaterAmount(int ml) async {
  final current = await todayDrunkMl();
  final delta = ml - current;
  if (delta > 0) {
    await addWaterLog(delta);
  } else if (delta < 0) {
    await removeWaterLog(-delta);
  }
}

// Calculate daily energy expenditure (TDEE)
// Using fixed multiplier 1.375 (lightly active) for all users
double calculateTDEE(double bmr) {
  return bmr * 1.375; // Fixed lightly active multiplier
}
