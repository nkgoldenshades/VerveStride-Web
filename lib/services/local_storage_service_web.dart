import 'dart:convert';
import 'dart:html' as html;
import 'package:vervestride/models/meal_item.dart';
import 'package:vervestride/models/activity.dart';
import 'package:vervestride/models/calendar_event.dart';

class LocalStorageService {
  static LocalStorageService? _instance;

  LocalStorageService._();

  static LocalStorageService get instance {
    _instance ??= LocalStorageService._();
    return _instance!;
  }

  String? _userId;

  void setUserId(String? uid) {
    _userId = uid;
  }

  Future<void> init() async {}

  Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    final suffix = _userId != null ? '_$_userId' : '';
    await _write('app_settings$suffix', settings);
  }

  Future<Map<String, dynamic>?> getAppSettings() async {
    final suffix = _userId != null ? '_$_userId' : '';
    final json = await _read('app_settings$suffix');
    if (json is Map) return json.cast<String, dynamic>();
    return null;
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
    return true; // enabled by default
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
    html.window.localStorage.clear();
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

  Future<bool> isRingMetricEnabled(String metricKey) async {
    final map = await getRingEnabled();
    return map[metricKey] ?? (_defaultRingEnabled()[metricKey] ?? false);
  }

  Future<void> saveMeals(List<Map<String, dynamic>> meals) async {
    final items = meals.map((m) => MealItemIsar.fromMap(m)).toList();
    final json = items.map((e) => _mealToJson(e)).toList();
    await _write('meals', json);
  }

  Future<void> addMeal(Map<String, dynamic> meal) async {
    final json = await _read('meals');
    final items = (json as List<dynamic>?)?.cast<dynamic>().toList() ?? [];
    final item = MealItemIsar.fromMap(meal);
    items.add(_mealToJson(item));
    await _write('meals', items);
  }

  Future<void> updateMeal(String mealId, Map<String, dynamic> meal) async {
    final json = await _read('meals');
    final items = (json as List<dynamic>?)?.cast<dynamic>().toList() ?? [];
    final updated = <dynamic>[];
    for (final e in items) {
      if (e is Map && e['id']?.toString() == mealId) {
        continue;
      }
      updated.add(e);
    }

    final item = MealItemIsar.fromMap({
      ...meal,
      'id': mealId,
    });
    updated.add(_mealToJson(item));
    await _write('meals', updated);
  }

  Future<void> deleteMeal(String mealId) async {
    final json = await _read('meals');
    final items = (json as List<dynamic>?)?.cast<dynamic>().toList() ?? [];
    final filtered = items.where((e) {
      if (e is! Map) return true;
      return e['id']?.toString() != mealId;
    }).toList();
    await _write('meals', filtered);
  }

  Future<void> saveActivities(List<Map<String, dynamic>> activities) async {
    final items = activities.map((a) => ActivityIsar.fromMap(a)).toList();
    final json = items.map((e) => _activityToJson(e)).toList();
    await _write('activities', json);
  }

  Future<void> addActivity(Map<String, dynamic> activity) async {
    final json = await _read('activities');
    final items = (json as List<dynamic>?)?.cast<dynamic>().toList() ?? [];
    final item = ActivityIsar.fromMap(activity);
    items.add(_activityToJson(item));
    await _write('activities', items);
  }

  Future<bool> hasAnyDataBefore(DateTime cutoff) async {
    final allMeals = await _read('meals');
    final meals = (allMeals as List<dynamic>?)?.cast<dynamic>().toList() ?? [];
    for (final e in meals) {
      if (e is! Map) continue;
      final createdAt = DateTime.tryParse(e['created_at']?.toString() ?? '');
      if (createdAt != null && createdAt.isBefore(cutoff)) return true;
    }

    final allActivities = await _read('activities');
    final activities =
        (allActivities as List<dynamic>?)?.cast<dynamic>().toList() ?? [];
    for (final e in activities) {
      if (e is! Map) continue;
      final createdAt = DateTime.tryParse(e['created_at']?.toString() ?? '');
      if (createdAt != null && createdAt.isBefore(cutoff)) return true;
    }
    return false;
  }

  Future<List<MealItemIsar>> getMealsInRange(
      DateTime start, DateTime end) async {
    final all = await _read('meals');
    final items = (all as List<dynamic>?)
            ?.map((e) => MealItemIsar.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return items
        .where((m) => !m.createdAt.isBefore(s) && !m.createdAt.isAfter(e))
        .toList();
  }

  Future<List<ActivityIsar>> getActivitiesInRange(
      DateTime start, DateTime end) async {
    final all = await _read('activities');
    final items = (all as List<dynamic>?)
            ?.map((e) => ActivityIsar.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return items
        .where((a) => !a.createdAt.isBefore(s) && !a.createdAt.isAfter(e))
        .toList();
  }

  Future<Map<String, int>> getWaterByDayInRange(
      DateTime start, DateTime end) async {
    final all = await _read('water');
    final map = <String, int>{};
    if (all is Map) {
      for (final e in all.entries) {
        final k = e.key?.toString();
        if (k == null) continue;
        final v = e.value;
        if (v is! int) continue;
        final y = int.tryParse(k.substring(0, 4));
        final m = int.tryParse(k.substring(4, 6));
        final d = int.tryParse(k.substring(6, 8));
        if (y == null || m == null || d == null) continue;
        final date = DateTime(y, m, d);
        if (!date.isBefore(start) && !date.isAfter(end)) {
          map[k] = v;
        }
      }
    }
    return map;
  }

  Future<List<CalendarEventIsar>> getEventsInRange(
      DateTime start, DateTime end) async {
    final all = await _read('events');
    final items = (all as List<dynamic>?)
            ?.map((e) => CalendarEventIsar.fromMap(e as Map<String, dynamic>))
            .cast<CalendarEventIsar>()
            .toList() ??
        [];
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return items
        .where((ev) => !ev.createdAt.isBefore(s) && !ev.createdAt.isAfter(e))
        .toList();
  }

  Future<void> deleteInRange(DateTime start, DateTime end) async {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

    final meals = await getMealsInRange(s, e);
    final activities = await getActivitiesInRange(s, e);
    final events = await getEventsInRange(s, e);
    final waterMap = await getWaterByDayInRange(s, e);

    final existingMeals = await _read('meals');
    final existingActivities = await _read('activities');
    final existingEvents = await _read('events');
    final existingWater = await _read('water');

    final filteredMeals = (existingMeals as List<dynamic>?)
            ?.where((e) => e is Map && !meals.any((m) => m.uuid == e['id']))
            .toList() ??
        [];
    final filteredActivities = (existingActivities as List<dynamic>?)
            ?.where(
                (e) => e is Map && !activities.any((a) => a.uuid == e['id']))
            .toList() ??
        [];
    final filteredEvents = (existingEvents as List<dynamic>?)
            ?.where((e) => e is Map && !events.any((ev) => ev.uuid == e['id']))
            .toList() ??
        [];
    final filteredWater = <String, dynamic>{};
    if (existingWater is Map) {
      for (final k in existingWater.keys) {
        if (!waterMap.containsKey(k)) filteredWater[k] = existingWater[k];
      }
    }

    await _write('meals', filteredMeals);
    await _write('activities', filteredActivities);
    await _write('events', filteredEvents);
    await _write('water', filteredWater);
  }

  Future<void> updateActivity(
      String activityId, Map<String, dynamic> activity) async {
    final json = await _read('activities');
    final items = (json as List<dynamic>?)?.cast<dynamic>().toList() ?? [];
    final updated = <dynamic>[];
    for (final e in items) {
      if (e is Map && e['id']?.toString() == activityId) {
        continue;
      }
      updated.add(e);
    }
    final item = ActivityIsar.fromMap(activity);
    updated.add(_activityToJson(item));
    await _write('activities', updated);
  }

  Future<void> deleteActivity(String activityId) async {
    final json = await _read('activities');
    final items = (json as List<dynamic>?)?.cast<dynamic>().toList() ?? [];
    final filtered = items.where((e) {
      if (e is! Map) return true;
      return e['id']?.toString() != activityId;
    }).toList();
    await _write('activities', filtered);
  }

  Future<List<MealItemIsar>> getMealsForDate(DateTime day) async {
    final json = await _read('meals');
    final items = (json as List<dynamic>?)
            ?.map((e) => MealItemIsar.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    return items.where((e) => _sameDay(e.createdAt, day)).toList();
  }

  Future<List<ActivityIsar>> getActivitiesForDate(DateTime day) async {
    final json = await _read('activities');
    final items = (json as List<dynamic>?)
            ?.map((e) => ActivityIsar.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    return items.where((e) => _sameDay(e.createdAt, day)).toList();
  }

  Future<List<MealItemIsar>> getMealsForMonth(DateTime month) async {
    final json = await _read('meals');
    final items = (json as List<dynamic>?)
            ?.map((e) => MealItemIsar.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    return items.where((e) => _sameMonth(e.createdAt, month)).toList();
  }

  Future<List<ActivityIsar>> getActivitiesForMonth(DateTime month) async {
    final json = await _read('activities');
    final items = (json as List<dynamic>?)
            ?.map((e) => ActivityIsar.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    return items.where((e) => _sameMonth(e.createdAt, month)).toList();
  }

  Future<void> deleteMealsForMonth(DateTime month) async {
    final json = await _read('meals');
    final items = (json as List<dynamic>?)
            ?.map((e) => MealItemIsar.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    final kept = items.where((e) => !_sameMonth(e.createdAt, month)).toList();
    await _write('meals', kept.map((e) => _mealToJson(e)).toList());
  }

  Future<void> deleteActivitiesForMonth(DateTime month) async {
    final json = await _read('activities');
    final items = (json as List<dynamic>?)
            ?.map((e) => ActivityIsar.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    final kept = items.where((e) => !_sameMonth(e.createdAt, month)).toList();
    await _write('activities', kept.map((e) => _activityToJson(e)).toList());
  }

  Future<void> saveUserProfile(Map<String, dynamic> profileData) async {
    if (profileData['goalStartDate'] == null &&
        profileData['goalDate'] != null) {
      profileData['goalStartDate'] = profileData['goalDate'];
    }
    await _write('user_profile', profileData);
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final raw = await _read('user_profile');
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }
    return null;
  }

  Future<int> getWaterForDate(DateTime day) async {
    final key = _dayKey(day);
    final map = await _read('water_by_day');
    if (map is Map && map[key] != null) {
      return (map[key] as num).toInt();
    }
    return 0;
  }

  Future<void> setWaterForDate(DateTime day, int ml) async {
    final key = _dayKey(day);
    final map = await _read('water_by_day');
    final updated = <String, dynamic>{
      ...(map is Map ? map.cast<String, dynamic>() : {})
    };
    updated[key] = ml.clamp(0, double.infinity).toInt();
    await _write('water_by_day', updated);
  }

  Future<Map<String, int>> getWaterByDayForMonth(DateTime month) async {
    final prefix =
        '${month.year.toString().padLeft(4, '0')}${month.month.toString().padLeft(2, '0')}';
    final map = await _read('water_by_day');
    final result = <String, int>{};
    if (map is Map) {
      for (final entry in map.entries) {
        final k = entry.key?.toString() ?? '';
        if (!k.startsWith(prefix)) continue;
        final v = entry.value;
        if (v is num) {
          final amount = v.toInt();
          if (amount > 0) result[k] = amount;
        }
      }
    }
    return result;
  }

  Future<void> addWaterForToday(int ml) async {
    final key = _dayKey(DateTime.now());
    final map = await _read('water_by_day');
    final current =
        (map is Map && map[key] != null) ? (map[key] as num).toInt() : 0;
    final updated = <String, dynamic>{
      ...(map is Map ? map.cast<String, dynamic>() : {})
    };
    updated[key] = current + ml;
    await _write('water_by_day', updated);
  }

  Future<void> removeWaterForToday(int ml) async {
    final key = _dayKey(DateTime.now());
    final map = await _read('water_by_day');
    final current =
        (map is Map && map[key] != null) ? (map[key] as num).toInt() : 0;
    final newAmount = (current - ml).clamp(0, double.infinity).toInt();
    final updated = <String, dynamic>{
      ...(map is Map ? map.cast<String, dynamic>() : {})
    };
    updated[key] = newAmount;
    await _write('water_by_day', updated);
  }

  Future<void> addCalendarEvent({
    required DateTime day,
    required String title,
    String? note,
  }) async {
    final items = await _read('calendar_events');
    final list = (items as List<dynamic>?)?.cast<dynamic>().toList() ?? [];

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    list.add({
      'id': id,
      'day_key': _dayKey(day),
      'title': title,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _write('calendar_events', list);
  }

  Future<void> deleteCalendarEvent(String eventId) async {
    final items = await _read('calendar_events');
    final list = (items as List<dynamic>?)?.cast<dynamic>().toList() ?? [];
    final filtered = list.where((e) {
      if (e is! Map) return true;
      return e['id']?.toString() != eventId;
    }).toList();
    await _write('calendar_events', filtered);
  }

  Future<void> updateCalendarEvent({
    required String eventId,
    required String title,
    String? note,
  }) async {
    final items = await _read('calendar_events');
    final list = (items as List<dynamic>?)?.cast<dynamic>().toList() ?? [];

    final updated = <dynamic>[];
    for (final e in list) {
      if (e is Map && e['id']?.toString() == eventId) {
        updated.add({
          ...e,
          'title': title,
          'note': note,
        });
      } else {
        updated.add(e);
      }
    }

    await _write('calendar_events', updated);
  }

  Future<List<Map<String, dynamic>>> getCalendarEventsForDate(
      DateTime day) async {
    final key = _dayKey(day);
    final items = await _read('calendar_events');
    final list = (items as List<dynamic>?)?.cast<dynamic>().toList() ?? [];

    final events = list
        .where((e) {
          if (e is! Map) return false;
          return e['day_key']?.toString() == key;
        })
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    events.sort((a, b) {
      final ad = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    return events;
  }

  Future<List<Map<String, dynamic>>> getCalendarEventsForMonth(
      DateTime month) async {
    final prefix =
        '${month.year.toString().padLeft(4, '0')}${month.month.toString().padLeft(2, '0')}';
    final items = await _read('calendar_events');
    final list = (items as List<dynamic>?)?.cast<dynamic>().toList() ?? [];

    final events = list
        .where((e) {
          if (e is! Map) return false;
          final k = e['day_key']?.toString() ?? '';
          return k.startsWith(prefix);
        })
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    events.sort((a, b) {
      final ad = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    return events;
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  bool _sameMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Map<String, dynamic> _mealToJson(MealItemIsar e) => {
        'id': e.uuid,
        'meal_type': e.mealTypeKey,
        'name': e.name,
        'calories': e.calories,
        'protein': e.protein,
        'carbs': e.carbs,
        'fat': e.fat,
        'fiber': e.fiber,
        'sodium': e.sodium,
        'added_sugar': e.addedSugar,
        'image_url': e.imageUrl,
        'note': e.note,
        'created_at': e.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _activityToJson(ActivityIsar e) => {
        'id': e.uuid,
        'activity_type': e.activityType,
        'activity_date': e.activityDate.toIso8601String(),
        'distance_km': e.distanceKm,
        'duration_minutes': e.durationMinutes,
        'calories_burned': e.caloriesBurned,
        'route_data': e.routeData,
        'note': e.note,
        'created_at': e.createdAt.toIso8601String(),
      };

  Future<dynamic> _read(String key) async {
    final raw = html.window.localStorage[key];
    if (raw == null) return null;
    if (raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, dynamic value) async {
    html.window.localStorage[key] = jsonEncode(value);
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
}
