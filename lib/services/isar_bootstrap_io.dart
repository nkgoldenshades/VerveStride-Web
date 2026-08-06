import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'local_storage_service.dart';
import '../models/user_profile_isar.dart';
import '../models/activity_isar.dart';
import '../models/meal_item_isar.dart';
import '../models/water_log_isar.dart';
import '../models/calendar_event_isar.dart';

Future<void> preInitIsar() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    debugPrint('📂 Isar Directory: ${dir.path}');

    final isar = await Isar.open(
      [
        UserProfileIsarSchema,
        ActivityIsarSchema,
        MealItemIsarSchema,
        WaterLogIsarSchema,
        CalendarEventIsarSchema,
      ],
      directory: dir.path,
      name: 'local_storage',
    );

    await LocalStorageService.instance.init(isar);
    debugPrint('✅ Isar (local_storage) initialized manually in main');
  } catch (e) {
    debugPrint('⚠️ Manual Isar Init Failed: $e');
  }
}
