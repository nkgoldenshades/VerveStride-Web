import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;
import 'package:share_plus/share_plus.dart';

import '../../core/app_theme.dart';
import '../../core/ui_constants.dart';
import '../../core/file_saver.dart';
import 'package:vervestride/models/activity.dart';
import 'package:vervestride/models/meal_item.dart';
import 'package:vervestride/models/user_profile.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/gradient_scaffold.dart';
import '../premium/premium_screen.dart';
import 'meals_list_page.dart';
import '../../controllers/theme_controller.dart';
import 'package:vervestride/utils/polyline_codec.dart';
import '../../services/user_subscription_service.dart';
import 'home_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
  
  // Static method to refresh from anywhere
  static Future<void> globalRefresh() async {
    await _CalendarScreenState.globalRefresh();
  }
}

enum _HistoryView {
  calendar,
  charts,
}

enum _ChartMetric {
  calories,
  protein,
  burn,
  water,
}

enum _ChartType {
  bar,
  line,
  pie,
}

class _ChartPoint {
  final DateTime day;
  final double actual;
  final double goal;

  const _ChartPoint({
    required this.day,
    required this.actual,
    required this.goal,
  });
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Color barColor;
  final List<_ChartPoint> series;
  final String subtitle;
  final _ChartType chartType;

  const _ChartCard({
    required this.title,
    required this.barColor,
    required this.series,
    required this.subtitle,
    required this.chartType,
  });

  @override
  Widget build(BuildContext context) {
    final maxActual = series.isEmpty
        ? 0.0
        : series.map((p) => p.actual).reduce((a, b) => a > b ? a : b);
    final maxGoal = series.isEmpty
        ? 0.0
        : series.map((p) => p.goal).reduce((a, b) => a > b ? a : b);
    final maxY = (maxActual > maxGoal ? maxActual : maxGoal);

    final painter = chartType == _ChartType.bar
        ? _MonthlyBarChartPainter(series: series, barColor: barColor)
        : chartType == _ChartType.line
            ? _MonthlyLineChartPainter(series: series, lineColor: barColor)
            : _GoalPieChartPainter(series: series, accentColor: barColor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                maxY <= 0 ? '' : 'Max ${(maxY).round()}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: painter,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyBarChartPainter extends CustomPainter {
  final List<_ChartPoint> series;
  final Color barColor;

  const _MonthlyBarChartPainter({
    required this.series,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ),
      bgPaint,
    );

    if (series.isEmpty) return;

    final maxActual =
        series.map((p) => p.actual).reduce((a, b) => a > b ? a : b);
    final maxGoal = series.map((p) => p.goal).reduce((a, b) => a > b ? a : b);
    final maxY = (maxActual > maxGoal ? maxActual : maxGoal);
    final denom = maxY <= 0 ? 1.0 : maxY;

    const topPad = 10.0;
    const bottomPad = 10.0;
    final chartHeight =
        (size.height - topPad - bottomPad).clamp(1.0, double.infinity);

    final n = series.length;
    final slotW = size.width / n;
    final barW = (slotW * 0.55).clamp(2.0, 18.0);

    final barPaint = Paint()
      ..color = barColor.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final goalLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final goalDotPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final goalPath = Path();
    for (int i = 0; i < n; i++) {
      final p = series[i];
      final xCenter = (i + 0.5) * slotW;

      final actualH = (p.actual / denom) * chartHeight;
      final barTop = topPad + (chartHeight - actualH);
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          xCenter - (barW / 2),
          barTop,
          barW,
          actualH,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(barRect, barPaint);

      final goalY = topPad + (chartHeight - ((p.goal / denom) * chartHeight));
      if (i == 0) {
        goalPath.moveTo(xCenter, goalY);
      } else {
        goalPath.lineTo(xCenter, goalY);
      }
      canvas.drawCircle(Offset(xCenter, goalY), 2.2, goalDotPaint);
    }

    canvas.drawPath(goalPath, goalLinePaint);
  }

  @override
  bool shouldRepaint(covariant _MonthlyBarChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.barColor != barColor;
  }
}

class _MonthlyLineChartPainter extends CustomPainter {
  final List<_ChartPoint> series;
  final Color lineColor;

  const _MonthlyLineChartPainter({
    required this.series,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ),
      bgPaint,
    );

    if (series.isEmpty) return;

    final maxActual =
        series.map((p) => p.actual).reduce((a, b) => a > b ? a : b);
    final maxGoal = series.map((p) => p.goal).reduce((a, b) => a > b ? a : b);
    final maxY = (maxActual > maxGoal ? maxActual : maxGoal);
    final denom = maxY <= 0 ? 1.0 : maxY;

    const topPad = 12.0;
    const bottomPad = 12.0;
    const sidePad = 10.0;
    final chartHeight =
        (size.height - topPad - bottomPad).clamp(1.0, double.infinity);
    final chartWidth = (size.width - (2 * sidePad)).clamp(1.0, double.infinity);

    final n = series.length;
    final stepX = n <= 1 ? 0.0 : chartWidth / (n - 1);

    final actualLinePaint = Paint()
      ..color = lineColor.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final goalLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = lineColor.withOpacity(0.95)
      ..style = PaintingStyle.fill;

    final goalDotPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final actualPath = Path();
    final goalPath = Path();

    for (int i = 0; i < n; i++) {
      final p = series[i];
      final x = sidePad + (i * stepX);

      final actualY =
          topPad + (chartHeight - ((p.actual / denom) * chartHeight));
      final goalY = topPad + (chartHeight - ((p.goal / denom) * chartHeight));

      if (i == 0) {
        actualPath.moveTo(x, actualY);
        goalPath.moveTo(x, goalY);
      } else {
        actualPath.lineTo(x, actualY);
        goalPath.lineTo(x, goalY);
      }

      canvas.drawCircle(Offset(x, actualY), 2.4, dotPaint);
      canvas.drawCircle(Offset(x, goalY), 2.2, goalDotPaint);
    }

    canvas.drawPath(goalPath, goalLinePaint);
    canvas.drawPath(actualPath, actualLinePaint);
  }

  @override
  bool shouldRepaint(covariant _MonthlyLineChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.lineColor != lineColor;
  }
}

class _GoalPieChartPainter extends CustomPainter {
  final List<_ChartPoint> series;
  final Color accentColor;

  const _GoalPieChartPainter({
    required this.series,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ),
      bgPaint,
    );

    if (series.isEmpty) return;

    final totalActual = series.fold<double>(0.0, (s, p) => s + p.actual);
    final totalGoal = series.fold<double>(0.0, (s, p) => s + p.goal);
    if (totalGoal <= 0) return;

    final ratio = (totalActual / totalGoal).clamp(0.0, 1.0);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide * 0.34).clamp(18.0, 60.0);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = accentColor.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -1.57079632679, 6.28318530718, false, trackPaint);
    canvas.drawArc(
        rect, -1.57079632679, 6.28318530718 * ratio, false, progressPaint);

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      text: TextSpan(
        text: '${(ratio * 100).round()}%',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    )..layout(maxWidth: size.width);

    final subPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      text: TextSpan(
        text: 'of goal',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    )..layout(maxWidth: size.width);

    final totalH = textPainter.height + 4 + subPainter.height;
    final startY = center.dy - (totalH / 2);
    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2), startY),
    );
    subPainter.paint(
      canvas,
      Offset(
        center.dx - (subPainter.width / 2),
        startY + textPainter.height + 4,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _GoalPieChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.accentColor != accentColor;
  }
}

class _CalendarScreenState extends State<CalendarScreen> {
  final LocalStorageService _storage = LocalStorageService.instance;
  
  // Static reference for global refresh
  static _CalendarScreenState? _activeInstance;
  
  static Future<void> globalRefresh() async {
    await _activeInstance?._loadMonthData(_activeInstance!._focusedDay);
    if (_activeInstance?._selectedDay != null) {
      await _activeInstance?._loadSelectedDayExtras(_activeInstance!._selectedDay!);
    }
  }

  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  DateTime? _chartFrom;
  DateTime? _chartTo;
  _ChartMetric _chartMetric = _ChartMetric.calories;
  _ChartType _chartType = _ChartType.bar;
  bool _isExporting = false;

  CalendarFormat _calendarFormat = CalendarFormat.month;

  UserProfile? _profile;
  bool _isInitializing = true;

  Map<DateTime, List<MealItemIsar>> _mealsByDate = {};
  final Map<DateTime, int> _activitiesByDate =
      {}; // Count of activities per date
  Map<DateTime, List<String>> _notesByDate = {};
  Map<DateTime, double> _completionByDate = {};
  Map<String, int> _waterByDayKey = {};
  int _selectedWaterMl = 0;
  List<Map<String, dynamic>> _selectedEvents = [];
  Map<DateTime, int> _eventsByDate = {};
  bool _hasOldData = false;

  // Chart data
  Map<DateTime, List<MealItemIsar>> _chartMealsByDate = {};
  Map<DateTime, int> _chartBurnedByDate = {};
  Map<String, int> _chartWaterByDayKey = {};
  bool _chartLoading = false;

  // Stats
  double _weekAvg = 0;
  String _strongestHabit = '';

  _HistoryView _view = _HistoryView.calendar;

  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void dispose() {
    _activeInstance = null; // Unregister this instance
    _searchController.dispose();
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _activeInstance = this; // Register this instance
    _selectedDay = _focusedDay;
    _selectedMonth = _focusedDay.month;
    _selectedYear = _focusedDay.year;
    ThemeController.instance.addListener(_onThemeChanged);
    _setDefaultChartRangeForSelectedMonth();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Ensure LocalStorageService is initialized before loading data
      await _storage.init();

      // Now safe to load data
      await Future.wait([
        _checkOldData(),
        _loadUserProfile(),
        _loadMonthData(_focusedDay),
        _loadSelectedDayExtras(_focusedDay),
      ]);
    } catch (e) {
      debugPrint('Error initializing calendar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _checkOldData() async {
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 90));
      final meals =
          await _storage.getMealsInRange(DateTime(2020, 1, 1), cutoff);
      final activities =
          await _storage.getActivitiesInRange(DateTime(2020, 1, 1), cutoff);
      final hasOld = meals.isNotEmpty || activities.isNotEmpty;
      if (!mounted) return;
      setState(() {
        _hasOldData = hasOld;
      });
    } catch (_) {
      // no-op
    }
  }

  Future<void> _downloadAndDeleteOldData() async {
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download & Delete Old Data'),
        content:
            const Text('Choose format to download data older than 90 days:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'csv'),
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'excel'),
            child: const Text('Excel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (format == null) return;
    final now = DateTime.now();
    final start = DateTime(2020, 1, 1);
    final end = now.subtract(const Duration(days: 90));
    if (format == 'csv') {
      await _exportCsv(start, end);
    } else {
      await _exportExcel(start, end);
    }
  }

  void _openPremium() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }

  void _setDefaultChartRangeForSelectedMonth() {
    final start = DateTime(_selectedYear, _selectedMonth, 1);
    final end = DateTime(_selectedYear, _selectedMonth + 1, 0);
    _chartFrom = start;
    _chartTo = end;
  }

  Future<void> _loadChartRangeData(DateTime start, DateTime end) async {
    if (_chartLoading) return;
    setState(() {
      _chartLoading = true;
    });
    try {
      final meals = await _storage.getMealsInRange(start, end);
      final activities = await _storage.getActivitiesInRange(start, end);
      final waterMap = await _storage.getWaterByDayInRange(start, end);

      final mealsByDate = <DateTime, List<MealItemIsar>>{};
      for (final meal in meals) {
        final dateKey = DateTime(
            meal.createdAt.year, meal.createdAt.month, meal.createdAt.day);
        mealsByDate.putIfAbsent(dateKey, () => []).add(meal);
      }

      final burnedByDate = <DateTime, int>{};
      for (final a in activities) {
        final dateKey =
            DateTime(a.createdAt.year, a.createdAt.month, a.createdAt.day);
        burnedByDate[dateKey] = (burnedByDate[dateKey] ?? 0) + a.caloriesBurned;
      }

      if (!mounted) return;
      setState(() {
        _chartMealsByDate = mealsByDate;
        _chartBurnedByDate = burnedByDate;
        _chartWaterByDayKey = waterMap;
      });
    } catch (_) {
      // no-op
    } finally {
      if (mounted) {
        setState(() {
          _chartLoading = false;
        });
      }
    }
  }

  Widget _historySectionTile({
    required Widget title,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: title,
        children: children,
      ),
    );
  }

  Widget _historyMealRow(DateTime day, MealItemIsar meal) {
    return InkWell(
      onTap: () => _showMealDetailsSheet(day, meal),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                meal.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${meal.calories} cal',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyActivityRow(DateTime day, ActivityIsar a) {
    final type = a.activityType;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              type,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${a.caloriesBurned} kcal',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final json = await _storage.getUserProfile();
      if (json == null) return;
      final profile = UserProfile.fromJson(json);
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } catch (_) {
      // no-op
    }
  }

  bool _isGoalDay(DateTime day) {
    final p = _profile;
    if (p == null) return false;
    return p.activeGoalForDate(day) != null;
  }

  int _estimateBurnTargetFromActivityLevel(int level) {
    switch (level) {
      case 1:
        return 200;
      case 2:
        return 300;
      case 3:
        return 400;
      case 4:
        return 550;
      case 5:
        return 700;
      default:
        return 400;
    }
  }

  void _updateFocusedDayFromMonthYear() {
    final newFocusedDay = DateTime(_selectedYear, _selectedMonth, 1);
    setState(() {
      _focusedDay = newFocusedDay;
      _selectedDay = newFocusedDay;
    });

    _setDefaultChartRangeForSelectedMonth();
    _loadMonthData(newFocusedDay);
    _loadSelectedDayExtras(newFocusedDay);

    final from = _chartFrom;
    final to = _chartTo;
    if (_view == _HistoryView.charts && from != null && to != null) {
      _loadChartRangeData(from, to);
    }
  }

  xl.CellStyle _headerStyle() {
    return xl.CellStyle(
      bold: true,
      horizontalAlign: xl.HorizontalAlign.Center,
      verticalAlign: xl.VerticalAlign.Center,
      backgroundColorHex: xl.ExcelColor.fromHexString('FF1E1E1E'),
      fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
    );
  }

  Future<void> _loadSelectedDayExtras(DateTime day) async {
    debugPrint('💧 WATER LOAD: Loading extras for day: $day');
    try {
      final water = await _storage.getWaterForDate(day);
      debugPrint('💧 WATER LOAD: Got water from storage: $water ml');
      
      final events = await _storage.getCalendarEventsForDate(day);
      debugPrint('💧 WATER LOAD: Got ${events.length} events from storage');
      
      if (!mounted) {
        debugPrint('💧 WATER LOAD: Widget not mounted, skipping setState');
        return;
      }
      
      setState(() {
        _selectedWaterMl = water;
        _selectedEvents = events;
      });
      debugPrint('💧 WATER LOAD: ✅ Updated state - _selectedWaterMl = $_selectedWaterMl ml');
    } catch (e) {
      debugPrint('💧 WATER LOAD: ❌ Error loading: $e');
    }
  }

  Future<void> _addWaterForSelectedDay() async {
    if (_selectedDay == null) {
      debugPrint('💧 WATER: Cannot add water - no day selected');
      return;
    }

    debugPrint('💧 WATER: Adding water for selected day: $_selectedDay');
    debugPrint('💧 WATER: Current water amount: $_selectedWaterMl ml');

    // Show dialog to select water amount
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Add Water',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('250 ml (1 glass)', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, 250),
            ),
            ListTile(
              title: const Text('500 ml (1 bottle)', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, 500),
            ),
            ListTile(
              title: const Text('750 ml', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, 750),
            ),
            ListTile(
              title: const Text('1000 ml (1 liter)', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, 1000),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (amount == null) {
      debugPrint('💧 WATER: User cancelled - no amount selected');
      return;
    }

    debugPrint('💧 WATER: User selected amount: $amount ml');

    try {
      // Add water to the selected day
      final newTotal = _selectedWaterMl + amount;
      debugPrint('💧 WATER: New total will be: $newTotal ml');
      debugPrint('💧 WATER: Saving to storage for date: $_selectedDay');
      
      await _storage.setWaterForDate(_selectedDay!, newTotal);
      debugPrint('💧 WATER: ✅ Saved to storage successfully');
      
      // Reload data
      debugPrint('💧 WATER: Reloading selected day extras...');
      await _loadSelectedDayExtras(_selectedDay!);
      debugPrint('💧 WATER: After reload - _selectedWaterMl = $_selectedWaterMl ml');
      
      debugPrint('💧 WATER: Reloading month data...');
      await _loadMonthData(_focusedDay);
      
      if (!mounted) {
        debugPrint('💧 WATER: Widget not mounted, skipping setState');
        return;
      }
      
      debugPrint('💧 WATER: Calling setState to update UI');
      setState(() {});
      
      // If adding water for today, refresh home screen
      final today = DateTime.now();
      final isToday = _selectedDay!.year == today.year &&
          _selectedDay!.month == today.month &&
          _selectedDay!.day == today.day;
      
      if (isToday) {
        debugPrint('💧 WATER: Adding water for today - refreshing home screen');
        await HomeScreen.globalRefresh();
      }
      
      // Also refresh calendar itself to ensure sync
      await CalendarScreen.globalRefresh();
      
      debugPrint('💧 WATER: ✅ Water add complete!');
    } catch (e) {
      debugPrint('💧 WATER: ❌ Error adding water: $e');
    }
  }

  Future<void> _loadMonthData(DateTime month) async {
    try {
      final meals = await _storage.getMealsForMonth(month);
      final activities = await _storage.getActivitiesForMonth(month);
      final waterByDay = await _storage.getWaterByDayForMonth(month);
      final events = await _storage.getCalendarEventsForMonth(month);

      final ringEnabled = await _storage.getRingEnabled();

      final profileJson = await _storage.getUserProfile();
      final profile =
          profileJson != null ? UserProfile.fromJson(profileJson) : _profile;

      final Map<DateTime, List<MealItemIsar>> mealsByDate = {};
      final Map<DateTime, List<String>> notesByDate = {};
      for (final meal in meals) {
        final dateKey = DateTime(
          meal.createdAt.year,
          meal.createdAt.month,
          meal.createdAt.day,
        );
        mealsByDate.putIfAbsent(dateKey, () => []).add(meal);
        final note = meal.note.toString();
        if (note.trim().isNotEmpty) {
          notesByDate.putIfAbsent(dateKey, () => []).add(note.trim());
        }
      }

      final Map<DateTime, int> activitiesByDate = {};
      final Map<DateTime, int> burnedByDate = {};
      for (final activity in activities) {
        final dateKey = DateTime(
          activity.createdAt.year,
          activity.createdAt.month,
          activity.createdAt.day,
        );
        activitiesByDate[dateKey] = (activitiesByDate[dateKey] ?? 0) + 1;
        burnedByDate[dateKey] =
            (burnedByDate[dateKey] ?? 0) + (activity.caloriesBurned);

        final directNote = activity.note.toString();
        if (directNote.trim().isNotEmpty) {
          notesByDate.putIfAbsent(dateKey, () => []).add(directNote.trim());
        }

        final rawRoute = activity.routeData.toString();
        if (rawRoute.trim().isNotEmpty &&
            rawRoute.length <= 20000 &&
            rawRoute.contains('"notes"')) {
          try {
            final decoded = jsonDecode(rawRoute);
            if (decoded is Map) {
              final routeNote = decoded['notes'].toString();
              if (routeNote.trim().isNotEmpty) {
                notesByDate
                    .putIfAbsent(dateKey, () => [])
                    .add(routeNote.trim());
              }
            }
          } catch (_) {
            // no-op
          }
        }
      }

      final Map<DateTime, int> eventsByDate = {};
      for (final e in events) {
        final key = e['day_key'].toString();
        if (key.length != 8) continue;
        final y = int.tryParse(key.substring(0, 4));
        final m = int.tryParse(key.substring(4, 6));
        final d = int.tryParse(key.substring(6, 8));
        if (y == null || m == null || d == null) continue;
        final dateKey = DateTime(y, m, d);
        eventsByDate[dateKey] = (eventsByDate[dateKey] ?? 0) + 1;
      }

      final Map<DateTime, double> completionByDate = {};
      final Map<DateTime, double> caloriesPercentByDate = {};
      final Map<DateTime, double> burnPercentByDate = {};
      final Map<DateTime, double> waterPercentByDate = {};
      double weekAvg = 0.0;
      String strongestHabit = '';

      if (profile != null) {
        final today = DateTime.now();
        final weekStart = DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: today.weekday - DateTime.monday));
        final weekEnd = weekStart.add(const Duration(days: 6));

        double sumWeekOverall = 0.0;
        int weekDaysCounted = 0;

        double sumWeekCalories = 0.0;
        double sumWeekProtein = 0.0;
        double sumWeekBurn = 0.0;
        double sumWeekWater = 0.0;

        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        for (int i = 0; i < daysInMonth; i++) {
          final day = DateTime(month.year, month.month, i + 1);
          final mealsForDay = mealsByDate[day] ?? const <MealItemIsar>[];
          final dayCalories =
              mealsForDay.fold<int>(0, (sum, m) => sum + m.calories);
          final dayProtein =
              mealsForDay.fold<double>(0, (sum, m) => sum + m.protein);
          final dayBurned = burnedByDate[day] ?? 0;
          final waterMl = waterByDay[_dayKey(day)] ?? 0;

          final activeGoal = profile.activeGoalForDate(day);
          final targets = profile.calculateDailyTargets(forDate: day);

          final overrideCalories = activeGoal?.targetCalories;
          final overrideProtein = activeGoal?.targetProteinGrams;
          final overrideWater = activeGoal?.targetWaterMl;
          final overrideBurn = activeGoal?.targetBurnCalories;

          final caloriesTarget =
              (overrideCalories != null && overrideCalories > 0)
                  ? overrideCalories
                  : ((targets['dailyCalories'] as num?)?.toInt() ?? 2500);
          final proteinTarget = (overrideProtein != null && overrideProtein > 0)
              ? overrideProtein
              : ((targets['proteinGrams'] as num?)?.toInt() ?? 150);
          final waterTarget = (overrideWater != null && overrideWater > 0)
              ? overrideWater
              : ((targets['waterMl'] as num?)?.toInt() ??
                  (profile.weightKg * 35).round());
          final burnTarget = (overrideBurn != null && overrideBurn > 0)
              ? overrideBurn
              : _estimateBurnTargetFromActivityLevel(profile.activityLevel);

          final caloriesPercent = caloriesTarget > 0
              ? (dayCalories / caloriesTarget).clamp(0.0, 1.0)
              : 0.0;
          final proteinPercent = proteinTarget > 0
              ? (dayProtein / proteinTarget).clamp(0.0, 1.0)
              : 0.0;
          final burnPercent =
              burnTarget > 0 ? (dayBurned / burnTarget).clamp(0.0, 1.0) : 0.0;
          final waterPercent =
              waterTarget > 0 ? (waterMl / waterTarget).clamp(0.0, 1.0) : 0.0;

          caloriesPercentByDate[day] = caloriesPercent;
          burnPercentByDate[day] = burnPercent;
          waterPercentByDate[day] = waterPercent;

          final enabledPercents = <double>[];
          if (ringEnabled['calories'] ?? true)
            enabledPercents.add(caloriesPercent);
          if (ringEnabled['protein'] ?? true)
            enabledPercents.add(proteinPercent);
          if (ringEnabled['burn'] ?? true) enabledPercents.add(burnPercent);
          if (ringEnabled['water'] ?? true) enabledPercents.add(waterPercent);

          final overall = enabledPercents.isEmpty
              ? 1.0
              : (enabledPercents.reduce((a, b) => a + b) /
                  enabledPercents.length);

          // Debug: Print calendar values to verify smooth decimals
          if (day.day == DateTime.now().day) {}

          completionByDate[day] = overall;

          if (!day.isBefore(weekStart) && !day.isAfter(weekEnd)) {
            sumWeekOverall += overall;
            if (ringEnabled['calories'] ?? true)
              sumWeekCalories += caloriesPercent;
            if (ringEnabled['protein'] ?? true)
              sumWeekProtein += proteinPercent;
            if (ringEnabled['burn'] ?? true) sumWeekBurn += burnPercent;
            if (ringEnabled['water'] ?? true) sumWeekWater += waterPercent;
            weekDaysCounted++;
          }
        }

        if (weekDaysCounted > 0) {
          weekAvg = sumWeekOverall / weekDaysCounted;

          final avgCalories = sumWeekCalories / weekDaysCounted;
          final avgProtein = sumWeekProtein / weekDaysCounted;
          final avgBurn = sumWeekBurn / weekDaysCounted;
          final avgWater = sumWeekWater / weekDaysCounted;

          final candidates = <String, double>{
            if (ringEnabled['calories'] ?? true) 'Calories': avgCalories,
            if (ringEnabled['protein'] ?? true) 'Protein': avgProtein,
            if (ringEnabled['burn'] ?? true) 'Movement': avgBurn,
            if (ringEnabled['water'] ?? true) 'Water': avgWater,
          };
          candidates.removeWhere((_, v) => v <= 0);
          if (candidates.isNotEmpty) {
            strongestHabit = candidates.entries
                .reduce((a, b) => a.value >= b.value ? a : b)
                .key;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _mealsByDate = mealsByDate;
        _activitiesByDate
          ..clear()
          ..addAll(activitiesByDate);
        _notesByDate = notesByDate;
        _waterByDayKey = waterByDay;
        _eventsByDate = eventsByDate;
        _completionByDate = completionByDate;
        _weekAvg = weekAvg;
        _strongestHabit = strongestHabit;
      });
    } catch (e) {
      debugPrint('Error loading month data: $e');
    }
  }

  List<MealItemIsar> _getMealsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _mealsByDate[dateKey] ?? [];
  }

  int _getActivitiesCountForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _activitiesByDate[dateKey] ?? 0;
  }

  bool _hasDataForDay(DateTime day) {
    final meals = _getMealsForDay(day);
    final activities = _getActivitiesCountForDay(day);
    final key = _dayKey(day);
    final water = _waterByDayKey[key] ?? 0;
    final events = _eventsByDate[DateTime(day.year, day.month, day.day)] ?? 0;
    return meals.isNotEmpty ||
        activities > 0 ||
        water > 0 ||
        events > 0 ||
        _isGoalDay(day);
  }

  bool _passesDateFilter(DateTime day) {
    if (_filterStartDate != null && day.isBefore(_filterStartDate!)) {
      return false;
    }
    if (_filterEndDate != null && day.isAfter(_filterEndDate!)) {
      return false;
    }
    return true;
  }

  bool _passesSearchFilter(DateTime day) {
    if (_searchQuery.isEmpty) return true;

    final meals = _getMealsForDay(day);
    final notes = _notesByDate[DateTime(day.year, day.month, day.day)] ??
        const <String>[];
    final key = _dayKey(day);
    final water = _waterByDayKey[key] ?? 0;

    // Search in meal names
    for (final meal in meals) {
      if (meal.name.toLowerCase().contains(_searchQuery)) return true;
    }

    // Search in notes
    for (final n in notes) {
      if (n.toLowerCase().contains(_searchQuery)) return true;
    }

    // Search in water amount
    if (water > 0 && _searchQuery.contains('water')) return true;

    return false;
  }

  bool _shouldShowDay(DateTime day) {
    return _hasDataForDay(day) &&
        _passesDateFilter(day) &&
        _passesSearchFilter(day);
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return GradientScaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading calendar...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GradientScaffold(
      body: CustomScrollView(
        slivers: [
          // Premium Collapsing Header
          SliverAppBar(
            expandedHeight: _view == _HistoryView.charts ? 170 : 500,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: LayoutBuilder(
                builder: (context, constraints) {
                  return ClipRect(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            children: [
                              const SizedBox(height: UIConstants.spacingXS),
                              Padding(
                                padding: UIConstants.screenPadding,
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'History',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SegmentedButton<_HistoryView>(
                                      segments: const [
                                        ButtonSegment<_HistoryView>(
                                          value: _HistoryView.calendar,
                                          label: Text('Calendar'),
                                        ),
                                        ButtonSegment<_HistoryView>(
                                          value: _HistoryView.charts,
                                          label: Text('Charts'),
                                        ),
                                      ],
                                      selected: <_HistoryView>{_view},
                                      showSelectedIcon: false,
                                      onSelectionChanged: (value) {
                                        if (value.isEmpty) return;
                                        setState(() {
                                          _view = value.first;
                                        });

                                        if (value.first ==
                                            _HistoryView.charts) {
                                          final from = _chartFrom;
                                          final to = _chartTo;
                                          if (from != null && to != null) {
                                            _loadChartRangeData(from, to);
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: UIConstants.spacingSM),
                              if (_hasOldData)
                                Padding(
                                  padding: UIConstants.screenPadding,
                                  child: Container(
                                    padding: UIConstants.cardPaddingCompact,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.orange.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(
                                          UIConstants.radiusMD),
                                      border: Border.all(
                                          color: Colors.orange
                                              .withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.storage,
                                            color: Colors.orange.shade700,
                                            size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Reduce storage: download and delete old data (older than 90 days)',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: _downloadAndDeleteOldData,
                                          icon: const Icon(Icons.download,
                                              size: 16),
                                          label:
                                              const Text('Download & Delete'),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                Colors.orange.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (_view == _HistoryView.calendar)
                                Padding(
                                  padding: UIConstants.screenPadding,
                                  child: Container(
                                    padding: UIConstants.cardPadding,
                                    decoration: BoxDecoration(
                                      color: AppColors.card
                                          .withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(
                                          UIConstants.radiusLG),
                                      border: Border.all(
                                          color: Colors.white
                                              .withOpacity(0.1)),
                                    ),
                                    child: _buildCalendarContent(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Content below the collapsing header
          if (_view == _HistoryView.charts) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: UIConstants.screenPadding,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: 24 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: _buildChartsView(),
                ),
              ),
            ),
          ],
          if (_view == _HistoryView.calendar) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: UIConstants.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: UIConstants.cardPadding,
                      decoration: BoxDecoration(
                        color: AppColors.card.withOpacity(0.75),
                        borderRadius:
                            BorderRadius.circular(UIConstants.radiusLG),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'This week',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Average completion: ${(_weekAvg * 100).round()}%',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_strongestHabit.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Strongest habit: $_strongestHabit',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: UIConstants.spacingXS),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(
                            Icons.circle, AppColors.accent, 'Has Data'),
                        const SizedBox(width: 20),
                        _buildLegendItem(
                            Icons.circle, AppColors.primary, 'Selected'),
                      ],
                    ),
                    const SizedBox(height: UIConstants.spacingSM),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : _showExportCsvDialog,
                        icon: _isExporting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(AppColors.primary),
                                ),
                              )
                            : const Icon(Icons.file_download),
                        label: Text(
                            _isExporting ? 'Exporting…' : 'Export Data (CSV)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: UIConstants.spacingXS),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : _showExportExcelDialog,
                        icon: _isExporting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(AppColors.primary),
                                ),
                              )
                            : const Icon(Icons.table_chart),
                        label: Text(_isExporting
                            ? 'Exporting…'
                            : 'Export Data (Excel)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: UIConstants.spacingSM),
                    _buildSelectedDayDetails(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  if (!UserSubscriptionService.instance.isAdFree)
                    const SafeArea(
                      top: false,
                      child: Center(
                        child:
                            AdBannerWidget(adUnitId: AdBannerWidget.banner1Id),
                      ),
                    ),
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedDayDetails() {
    if (_selectedDay == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Select a date to view history',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: UIConstants.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.75),
        borderRadius: BorderRadius.circular(UIConstants.radiusLG),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: _buildDayHistory(_selectedDay!),
    );
  }

  Widget _buildCalendarContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3)),
                ),
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  underline: const SizedBox(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem<int>(
                      value: month,
                      child:
                          Text(DateFormat('MMM').format(DateTime(2023, month))),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedMonth = value;
                      });
                      _updateFocusedDayFromMonthYear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3)),
                ),
                child: DropdownButton<int>(
                  value: _selectedYear,
                  underline: const SizedBox(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  items: List.generate(20, (index) {
                    final year = DateTime.now().year - 5 + index;
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedYear = value;
                      });
                      _updateFocusedDayFromMonthYear();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: _calendarFormat,
          rowHeight: 34,
          daysOfWeekHeight: 18,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
              _selectedMonth = focusedDay.month;
              _selectedYear = focusedDay.year;
            });
            _loadSelectedDayExtras(selectedDay);
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
              _selectedMonth = focusedDay.month;
              _selectedYear = focusedDay.year;
            });
            _loadMonthData(focusedDay);
          },
          calendarBuilders: CalendarBuilders(
            dowBuilder: (context, day) {
              return const SizedBox();
            },
            defaultBuilder: (context, day, focusedDay) {
              if (day.month != focusedDay.month ||
                  day.year != focusedDay.year) {
                return null;
              }
              final key = DateTime(day.year, day.month, day.day);
              final pct = _completionByDate[key];
              final showRing = pct != null && _shouldShowDay(day);
              if (showRing) {
                return _MiniRingDayCell(
                  day: day,
                  percent: pct,
                  isToday: isSameDay(day, DateTime.now()),
                  isSelected: isSameDay(day, _selectedDay),
                  hasData: _hasDataForDay(day),
                );
              }

              final isToday = isSameDay(day, DateTime.now());
              final isSelected = isSameDay(day, _selectedDay);
              final textColor = isSelected || isToday
                  ? Colors.white
                  : AppColors.textSecondary;

              return Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : isToday
                            ? AppColors.accent.withOpacity(0.7)
                            : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            headerPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            titleTextStyle: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon: const Icon(
              Icons.chevron_left,
              color: Colors.white,
            ),
            rightChevronIcon: const Icon(
              Icons.chevron_right,
              color: Colors.white,
            ),
            titleTextFormatter: (date, locale) =>
                DateFormat.yMMMM(locale).format(date),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            defaultTextStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            weekendTextStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            todayTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            markerSize: 6,
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle:
                TextStyle(color: AppColors.textSecondary, fontSize: 11),
            weekendStyle:
                TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          eventLoader: (day) {
            // Disabled: rings are shown via defaultBuilder instead
            return [];
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildChartsView() {
    final from = _chartFrom ?? DateTime(_selectedYear, _selectedMonth, 1);
    final to = _chartTo ?? DateTime(_selectedYear, _selectedMonth + 1, 0);

    final subtitle =
        '${DateFormat('d MMM y').format(from)}  –  ${DateFormat('d MMM y').format(to)}';

    final series =
        _buildSeriesForRange(metric: _chartMetric, start: from, end: to);

    final metricTitle = _chartMetric == _ChartMetric.calories
        ? 'Calories vs goal'
        : _chartMetric == _ChartMetric.protein
            ? 'Protein vs goal'
            : _chartMetric == _ChartMetric.burn
                ? 'Burn vs goal'
                : 'Water vs goal';

    final metricColor = _chartMetric == _ChartMetric.calories
        ? AppColors.accent
        : _chartMetric == _ChartMetric.protein
            ? Colors.redAccent
            : _chartMetric == _ChartMetric.burn
                ? AppColors.secondary
                : Colors.lightBlueAccent;

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: from,
                    firstDate: DateTime(2020, 1, 1),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked == null) return;
                  final newStart =
                      DateTime(picked.year, picked.month, picked.day);
                  final currentEnd = _chartTo ?? to;
                  final endNorm = DateTime(
                      currentEnd.year, currentEnd.month, currentEnd.day);
                  if (newStart.isAfter(endNorm)) return;
                  setState(() {
                    _chartFrom = newStart;
                  });
                  await _loadChartRangeData(newStart, endNorm);
                },
                child: Text('From: ${DateFormat('d MMM').format(from)}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: to,
                    firstDate: DateTime(2020, 1, 1),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked == null) return;
                  final newEnd =
                      DateTime(picked.year, picked.month, picked.day);
                  final currentStart = _chartFrom ?? from;
                  final startNorm = DateTime(
                      currentStart.year, currentStart.month, currentStart.day);
                  if (newEnd.isBefore(startNorm)) return;
                  setState(() {
                    _chartTo = newEnd;
                  });
                  await _loadChartRangeData(startNorm, newEnd);
                },
                child: Text('To: ${DateFormat('d MMM').format(to)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<_ChartMetric>(
          segments: const [
            ButtonSegment<_ChartMetric>(
              value: _ChartMetric.calories,
              label: Text('Calories'),
            ),
            ButtonSegment<_ChartMetric>(
              value: _ChartMetric.protein,
              label: Text('Protein'),
            ),
            ButtonSegment<_ChartMetric>(
              value: _ChartMetric.burn,
              label: Text('Burn'),
            ),
            ButtonSegment<_ChartMetric>(
              value: _ChartMetric.water,
              label: Text('Water'),
            ),
          ],
          selected: <_ChartMetric>{_chartMetric},
          showSelectedIcon: false,
          onSelectionChanged: (value) {
            if (value.isEmpty) return;
            final next = value.first;
            setState(() {
              _chartMetric = next;
            });
          },
        ),
        const SizedBox(height: 10),
        SegmentedButton<_ChartType>(
          segments: const [
            ButtonSegment<_ChartType>(
              value: _ChartType.bar,
              label: Text('Bar'),
            ),
            ButtonSegment<_ChartType>(
              value: _ChartType.line,
              label: Text('Line'),
            ),
            ButtonSegment<_ChartType>(
              value: _ChartType.pie,
              label: Text('Pie'),
            ),
          ],
          selected: <_ChartType>{_chartType},
          showSelectedIcon: false,
          onSelectionChanged: (value) {
            if (value.isEmpty) return;
            setState(() {
              _chartType = value.first;
            });
          },
        ),
        const SizedBox(height: 12),
        if (!_chartLoading)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Icons.square, metricColor, 'You'),
              const SizedBox(width: 16),
              _buildLegendItem(Icons.circle, Colors.white54, 'Goal'),
            ],
          ),
        const SizedBox(height: 14),
        if (_chartLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: CircularProgressIndicator(),
          )
        else
          _ChartCard(
            title: metricTitle,
            barColor: metricColor,
            series: series,
            subtitle: subtitle,
            chartType: _chartType,
          ),
      ],
    );
  }

  List<_ChartPoint> _buildSeriesForRange({
    required _ChartMetric metric,
    required DateTime start,
    required DateTime end,
  }) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final profile = _profile;

    final points = <_ChartPoint>[];
    var cursor = s;
    while (!cursor.isAfter(e)) {
      final day = DateTime(cursor.year, cursor.month, cursor.day);
      final meals = _chartMealsByDate[day] ?? const <MealItemIsar>[];

      final activeGoal = profile?.activeGoalForDate(day);
      final targets = profile?.calculateDailyTargets(forDate: day);

      final caloriesTarget = ((activeGoal?.targetCalories ?? 0) > 0)
          ? activeGoal!.targetCalories!.toDouble()
          : ((targets?['dailyCalories'] as num?)?.toDouble() ?? 2500);

      final proteinTarget = ((activeGoal?.targetProteinGrams ?? 0) > 0)
          ? activeGoal!.targetProteinGrams!.toDouble()
          : ((targets?['proteinGrams'] as num?)?.toDouble() ?? 150);

      final burnTarget = ((activeGoal?.targetBurnCalories ?? 0) > 0)
          ? activeGoal!.targetBurnCalories!.toDouble()
          : _estimateBurnTargetFromActivityLevel(profile?.activityLevel ?? 3)
              .toDouble();

      final waterTarget = ((activeGoal?.targetWaterMl ?? 0) > 0)
          ? activeGoal!.targetWaterMl!.toDouble()
          : ((targets?['waterMl'] as num?)?.toDouble() ?? 2500);

      final caloriesActual = meals.fold<int>(0, (sum, m) => sum + m.calories);
      final proteinActual = meals.fold<double>(0, (sum, m) => sum + m.protein);

      final burnedActual = (_chartBurnedByDate[day] ?? 0).toDouble();
      final waterActual = (_chartWaterByDayKey[_dayKey(day)] ?? 0).toDouble();

      final actual = metric == _ChartMetric.calories
          ? caloriesActual.toDouble()
          : metric == _ChartMetric.protein
              ? proteinActual
              : metric == _ChartMetric.burn
                  ? burnedActual
                  : waterActual;

      final goal = metric == _ChartMetric.calories
          ? caloriesTarget
          : metric == _ChartMetric.protein
              ? proteinTarget
              : metric == _ChartMetric.burn
                  ? burnTarget
                  : waterTarget;

      points.add(_ChartPoint(day: day, actual: actual, goal: goal));
      cursor = cursor.add(const Duration(days: 1));
    }
    return points;
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDayHistory(DateTime day) {
    final meals = _getMealsForDay(day);
    final activitiesCount = _getActivitiesCountForDay(day);
    final dateStr = DateFormat('EEEE, MMMM d, y').format(day);
    final waterMl = _dayKey(day) == _dayKey(_selectedDay ?? day)
        ? _selectedWaterMl
        : (_waterByDayKey[_dayKey(day)] ?? 0);
    final events = _dayKey(day) == _dayKey(_selectedDay ?? day)
        ? _selectedEvents
        : const <Map<String, dynamic>>[];

    final activeGoalForDay = _profile?.activeGoalForDate(day);
    final dailyTargets = _profile?.calculateDailyTargets(forDate: day);
    final burnTarget = ((activeGoalForDay?.targetBurnCalories ?? 0) > 0)
        ? (activeGoalForDay!.targetBurnCalories!).toInt()
        : _estimateBurnTargetFromActivityLevel(_profile?.activityLevel ?? 3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Text(
            dateStr,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (dailyTargets != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeGoalForDay != null
                        ? 'Goal: ${activeGoalForDay.goalType}'
                        : 'Day targets',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (activeGoalForDay != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'From: ${activeGoalForDay.fromDate.toIso8601String().split('T').first}  To: ${activeGoalForDay.toDate.toIso8601String().split('T').first}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Goals: ${dailyTargets['dailyCalories']} kcal  •  $burnTarget burn  •  ${(dailyTargets['waterMl'] as int)} ml water',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Meals section
          _historySectionTile(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Meals',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: meals.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MealsListPage(selectedDate: day),
                            ),
                          );
                        },
                  child: Text('View All (${meals.length})'),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                child: meals.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'No meals logged for this day',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          const SizedBox(height: 6),
                          ...meals.map((meal) => _historyMealRow(day, meal)),
                        ],
                      ),
              ),
            ],
          ),

          // Activities section
          _historySectionTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Activities',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: activitiesCount == 0
                      ? null
                      : () => _showActivitiesListSheet(day),
                  child: Text('View All ($activitiesCount)'),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                child: FutureBuilder<List<ActivityIsar>>(
                  future: _storage.getActivitiesForDate(day),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final activities = snapshot.data ?? const <ActivityIsar>[];
                    if (activities.isEmpty) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'No activities logged for this day',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }

                    // Show only top 3 activities
                    final displayActivities = activities.take(3).toList();

                    return Column(
                      children: [
                        const SizedBox(height: 6),
                        ...displayActivities.map((a) => _historyActivityRow(day, a)),
                        if (activities.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+ ${activities.length - 3} more',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          // Water section
          _historySectionTile(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Water',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 24),
                  color: AppColors.secondary,
                  onPressed: () => _addWaterForSelectedDay(),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${(waterMl / 1000).toStringAsFixed(1)} L',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Notes/Events section
          ExpansionTile(
            initiallyExpanded: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Notes',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddEventDialog(day),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
                child: events.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'No notes for this day',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          const SizedBox(height: 12),
                          ...events.map((e) => _buildEventItem(day, e)),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(DateTime day, Map<String, dynamic> e) {
    final title = (e['title'] ?? 'Event').toString();
    final note = (e['note'] ?? '').toString();
    final id = e['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: id.isEmpty ? null : () => _showEditEventDialog(day, e),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (note.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: id.isEmpty
                  ? null
                  : () async {
                      await _storage.deleteCalendarEvent(id);
                      await _loadMonthData(_focusedDay);
                      if (_selectedDay != null) {
                        await _loadSelectedDayExtras(_selectedDay!);
                      }
                    },
              icon: const Icon(Icons.delete_outline),
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditEventDialog(
      DateTime day, Map<String, dynamic> e) async {
    final id = e['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final titleCtrl =
        TextEditingController(text: (e['title'] ?? '').toString());
    final noteCtrl = TextEditingController(text: (e['note'] ?? '').toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Note'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    if (titleCtrl.text.trim().isEmpty) return;

    await _storage.updateCalendarEvent(
      eventId: id,
      title: titleCtrl.text.trim(),
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );

    await _loadMonthData(_focusedDay);
    if (_selectedDay != null) {
      await _loadSelectedDayExtras(_selectedDay!);
    }
  }

  Future<void> _showAddEventDialog(DateTime day) async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    if (titleCtrl.text.trim().isEmpty) return;

    await _storage.addCalendarEvent(
      day: day,
      title: titleCtrl.text.trim(),
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );

    await _loadMonthData(_focusedDay);
    if (_selectedDay != null) {
      await _loadSelectedDayExtras(_selectedDay!);
    }
  }

  Future<void> _showMealDetailsSheet(DateTime day, MealItemIsar meal) async {
    final mealId = meal.uuid;
    if (mealId.trim().isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SafeArea(
            top: false,
            child: FutureBuilder<List<MealItemIsar>>(
              future: _storage.getMealsForDate(day),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final meals = snapshot.data ?? const <MealItemIsar>[];
                MealItemIsar? full;
                for (final m in meals) {
                  if (m.uuid == mealId) {
                    full = m;
                    break;
                  }
                }

                final name = meal.name;
                final calories = meal.calories;
                final protein = meal.protein;
                final carbs = meal.carbs;
                final fat = meal.fat;
                final fiber = meal.fiber;
                final sodium = meal.sodium;
                final sugar = meal.addedSugar;
                final imageUrl = meal.imageUrl;
                final note = full?.note ?? '';

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$calories kcal',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Protein: ${protein.toStringAsFixed(1)}g\nCarbs: ${carbs.toStringAsFixed(1)}g\nFat: ${fat.toStringAsFixed(1)}g\nFiber: ${fiber.toStringAsFixed(1)}g\nSodium: ${sodium}mg\nAdded sugar: ${sugar.toStringAsFixed(1)}g',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (note.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Note',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          note,
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                      if (imageUrl != null && imageUrl.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Image',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(DateTime day, ActivityIsar a,
      {VoidCallback? onEdited, VoidCallback? onDeleted}) {
    final type = a.activityType;
    final note = a.note ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${a.caloriesBurned} kcal • ${a.durationMinutes} min • ${a.distanceKm.toStringAsFixed(2)} km',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (note.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: null,
              icon: const Icon(Icons.delete_outline),
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActivitiesListSheet(DateTime day) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: FutureBuilder<List<ActivityIsar>>(
                    future: _storage.getActivitiesForDate(day),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = snapshot.data ?? const <ActivityIsar>[];
                      if (items.isEmpty) {
                        return const Center(
                          child: Text(
                            'No activities for this day',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final a = items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child:
                                _buildActivityItem(day, a, onEdited: () async {
                              await _loadMonthData(_focusedDay);
                              if (_selectedDay != null) {
                                await _loadSelectedDayExtras(_selectedDay!);
                              }
                              setModalState(() {});
                            }, onDeleted: () async {
                              await _loadMonthData(_focusedDay);
                              if (_selectedDay != null) {
                                await _loadSelectedDayExtras(_selectedDay!);
                              }
                              setModalState(() {});
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showExportCsvDialog() async {
    final range = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data (CSV)'),
        content: const Text('Choose a date range to export:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'month'),
            child: const Text('This month'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, '90'),
            child: const Text('Last 90 days'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('All time'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (range == null) return;

    if (!UserSubscriptionService.instance.hasAdvancedAnalytics &&
        (range == '90' || range == 'all')) {
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
              'Unlock ${range == '90' ? 'Last 90 Days' : 'All Data'} Export'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose how to unlock this feature:'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop('ad'),
                icon: const Icon(Icons.play_circle),
                label: const Text('Watch Ad (24-hour access)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop('premium'),
                icon: const Icon(Icons.diamond),
                label: const Text('Upgrade to Premium'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == 'ad') {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        final unlocked = range == '90'
            ? await showRewardedAdForCsv90Days(
                messenger: messenger,
              )
            : await showRewardedAdForCsvAllTime(
                messenger: messenger,
              );
        if (!mounted) return;
        if (!unlocked) return;
        await _storage
            .setTempPremiumUntil(DateTime.now().add(const Duration(hours: 24)));
        await ThemeController.instance.load();
        if (!mounted) return;
        setState(() {});
      } else if (choice == 'premium') {
        if (!mounted) return;
        _openPremium();
        return;
      } else {
        return;
      }
    }
    final now = DateTime.now();
    late final DateTime start;
    late final DateTime end;
    if (range == 'month') {
      start = DateTime(_selectedYear, _selectedMonth, 1);
      end = DateTime(_selectedYear, _selectedMonth + 1, 0);
    } else if (range == '90') {
      start = now.subtract(const Duration(days: 90));
      end = now;
    } else {
      start = DateTime(2020, 1, 1);
      end = now;
    }
    await _exportCsv(start, end);
  }

  Future<void> _exportCsv(DateTime start, DateTime end) async {
    // Ask action before exporting
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Options'),
        content: const Text('Choose export action:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'download'),
            child: const Text('Download Only'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'download_and_delete'),
            child: const Text('Download & Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (action == null || action == 'cancel') return;

    setState(() => _isExporting = true);
    try {
      final meals = await _storage.getMealsInRange(start, end);
      final activities = await _storage.getActivitiesInRange(start, end);
      final waterMap = await _storage.getWaterByDayInRange(start, end);
      final events = await _storage.getEventsInRange(start, end);

      String row(List<String> cells) {
        final escaped = cells.map(_csvEscape).toList();
        return escaped.join(',');
      }

      final header = [
        'Date',
        'Type',
        'Name',
        'Calories',
        'Protein',
        'Carbs',
        'Fat',
        'Fiber',
        'Sodium',
        'AddedSugar',
        'DistanceKm',
        'DurationMinutes',
        'BurnedCalories',
        'WaterMl',
        'EventTitle',
        'EventNote',
      ];

      final lines = <String>[row(header)];

      for (final m in meals) {
        lines.add(row([
          m.createdAt.toIso8601String(),
          'Meal',
          m.name,
          m.calories.toString(),
          m.protein.toString(),
          m.carbs.toString(),
          m.fat.toString(),
          m.fiber.toString(),
          m.sodium.toString(),
          m.addedSugar.toString(),
          '',
          '',
          '',
          '',
          '',
          '',
        ]));
      }

      for (final a in activities) {
        lines.add(row([
          a.createdAt.toIso8601String(),
          'Activity',
          a.activityType,
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          a.distanceKm.toString(),
          a.durationMinutes.toString(),
          a.caloriesBurned.toString(),
          '',
          '',
          a.note ?? '',
        ]));
      }

      for (final e in events) {
        lines.add(row([
          e.createdAt.toIso8601String(),
          'Event',
          e.title,
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          e.title,
          e.note ?? '',
        ]));
      }

      for (final entry in waterMap.entries) {
        final y = int.tryParse(entry.key.substring(0, 4));
        final m = int.tryParse(entry.key.substring(4, 6));
        final d = int.tryParse(entry.key.substring(6, 8));
        if (y == null || m == null || d == null) continue;
        final date = DateTime(y, m, d);
        lines.add(row([
          date.toIso8601String(),
          'Water',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          entry.value.toString(),
          '',
          '',
        ]));
      }

      final csv = lines.join('\n');

      final fileName =
          'vervestride_export_${DateTime.now().toIso8601String().split('T').first}.csv';
      if (kIsWeb) {
        await FileSaver.saveText(fileName: fileName, content: csv);
      } else {
        // Mobile: Save to temporary file and share
        final filePath =
            await FileSaver.saveText(fileName: fileName, content: csv);

        // Share the file
        await Share.shareXFiles(
          [XFile(filePath, name: fileName)],
          text: 'Here is your VerveStride data export',
        );
      }

      if (!mounted) return;
      if (action == 'download_and_delete') {
        await _storage.deleteInRange(start, end);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exported & old data deleted from app')),
        );
        await _loadMonthData(_focusedDay);
        await _checkOldData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export downloaded')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _showExportExcelDialog() async {
    final range = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data (Excel)'),
        content: const Text('Choose a date range to export:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'month'),
            child: const Text('This month'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, '90'),
            child: const Text('Last 90 days'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('All time'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (range == null) return;

    if (!UserSubscriptionService.instance.hasAdvancedAnalytics &&
        (range == '90' || range == 'all')) {
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
              'Unlock ${range == '90' ? 'Last 90 Days' : 'All Data'} Export'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose how to unlock this feature:'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop('ad'),
                icon: const Icon(Icons.play_circle),
                label: const Text('Watch Ad (24-hour access)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop('premium'),
                icon: const Icon(Icons.diamond),
                label: const Text('Upgrade to Premium'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (choice == 'ad') {
        final messenger = ScaffoldMessenger.of(context);
        final unlocked = range == '90'
            ? await showRewardedAdForExcel90Days(
                messenger: messenger,
              )
            : await showRewardedAdForExcelAllTime(
                messenger: messenger,
              );
        if (!mounted) return;
        if (!unlocked) return;
        await _storage
            .setTempPremiumUntil(DateTime.now().add(const Duration(hours: 24)));
        await ThemeController.instance.load();
        if (!mounted) return;
        setState(() {}); // Ensure UI refreshes
      } else if (choice == 'premium') {
        _openPremium();
        return;
      } else {
        return;
      }
    }
    final now = DateTime.now();
    late final DateTime start;
    late final DateTime end;
    if (range == 'month') {
      start = DateTime(_selectedYear, _selectedMonth, 1);
      end = DateTime(_selectedYear, _selectedMonth + 1, 0);
    } else if (range == '90') {
      start = now.subtract(const Duration(days: 90));
      end = now;
    } else {
      start = DateTime(2020, 1, 1);
      end = now;
    }
    await _exportExcel(start, end);
  }

  Future<void> _exportExcel(DateTime start, DateTime end) async {
    setState(() => _isExporting = true);
    try {
      final meals = await _storage.getMealsInRange(start, end);
      final activities = await _storage.getActivitiesInRange(start, end);
      final waterMap = await _storage.getWaterByDayInRange(start, end);
      final events = await _storage.getEventsInRange(start, end);
      final profileJson = await _storage.getUserProfile();
      final profile =
          profileJson != null ? UserProfile.fromJson(profileJson) : null;

      final excel = xl.Excel.createExcel();
      excel.delete('Sheet1');

      final dailySummarySheet = excel['Daily Summary'];
      final detailsSheet = excel['Details'];
      final mealsSheet = excel['Meals'];
      final activitiesSheet = excel['Activities'];
      final waterSheet = excel['Water'];
      final eventsSheet = excel['Events'];

      final headerStyle = _headerStyle();

      // Daily Summary headers
      final dailySummaryHeaders = [
        'Date',
        'GoalSet',
        'GoalType',
        'GoalFrom',
        'GoalTo',
        'TargetCalories',
        'TargetProtein',
        'TargetCarbs',
        'TargetFat',
        'TargetWaterMl',
        'TargetFiber',
        'TargetSodium',
        'TargetAddedSugar',
        'TotalCalories',
        'TotalProtein',
        'TotalCarbs',
        'TotalFat',
        'TotalFiber',
        'TotalSodium',
        'TotalAddedSugar',
        'TotalBurnedCalories',
        'TotalDistanceKm',
        'TotalDurationMinutes',
        'TotalWaterMl',
        'MetCalories',
        'MetProtein',
        'MetWater',
        'MetBurn',
      ];
      for (int i = 0; i < dailySummaryHeaders.length; i++) {
        final cell = dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(dailySummaryHeaders[i]);
        cell.cellStyle = headerStyle;
      }

      // Details headers (CSV-style)
      final detailsHeaders = [
        'Date',
        'Type',
        'Name',
        'SubType',
        'Calories',
        'Protein',
        'Carbs',
        'Fat',
        'Fiber',
        'Sodium',
        'AddedSugar',
        'DistanceKm',
        'DurationMinutes',
        'BurnedCalories',
        'WaterMl',
        'EventTitle',
        'EventNote',
        'Note',
        'RouteData',
        'MapLink',
      ];
      for (int i = 0; i < detailsHeaders.length; i++) {
        final cell = detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(detailsHeaders[i]);
        cell.cellStyle = headerStyle;
      }

      // Meals sheet
      final mealsHeaders = [
        'Date',
        'MealType',
        'Name',
        'Calories',
        'Protein',
        'Carbs',
        'Fat',
        'Fiber',
        'Sodium',
        'AddedSugar',
        'Note'
      ];
      for (int i = 0; i < mealsHeaders.length; i++) {
        final cell = mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(mealsHeaders[i]);
        cell.cellStyle = headerStyle;
      }
      for (int row = 0; row < meals.length; row++) {
        final m = meals[row];
        final createdAt = m.createdAt;

        // Details sheet row (Meal)
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: row + 1))
            .value = xl.TextCellValue(createdAt.toIso8601String());
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: row + 1))
            .value = xl.TextCellValue('Meal');
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 2, rowIndex: row + 1))
            .value = xl.TextCellValue(m.name);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 3, rowIndex: row + 1))
            .value = xl.TextCellValue(m.mealTypeKey);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 3, rowIndex: row + 1))
            .value = xl.IntCellValue(m.calories);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 4, rowIndex: row + 1))
            .value = xl.DoubleCellValue(m.protein);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 5, rowIndex: row + 1))
            .value = xl.DoubleCellValue(m.carbs);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 6, rowIndex: row + 1))
            .value = xl.DoubleCellValue(m.fat);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 7, rowIndex: row + 1))
            .value = xl.DoubleCellValue(m.fiber);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 8, rowIndex: row + 1))
            .value = xl.IntCellValue(m.sodium);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 9, rowIndex: row + 1))
            .value = xl.DoubleCellValue(m.addedSugar);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 17, rowIndex: row + 1))
            .value = xl.TextCellValue(m.note ?? '');

        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: row + 1))
            .value = xl.TextCellValue(m.createdAt.toIso8601String());
        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: row + 1))
            .value = xl.TextCellValue(m.mealTypeKey);
        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 2, rowIndex: row + 1))
            .value = xl.TextCellValue(m.name);
        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 3, rowIndex: row + 1))
            .value = xl.IntCellValue(m.calories);
        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 4, rowIndex: row + 1))
            .value = xl.DoubleCellValue(m.protein);
        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 5, rowIndex: row + 1))
            .value = xl.DoubleCellValue(m.carbs);
        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 6, rowIndex: row + 1))
            .value = xl.DoubleCellValue(m.fat);
        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 7, rowIndex: row + 1))
            .value = xl.DoubleCellValue(m.fiber);
        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 8, rowIndex: row + 1))
            .value = xl.IntCellValue(m.sodium);
        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 9, rowIndex: row + 1))
            .value = xl.DoubleCellValue(m.addedSugar);
        mealsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 10, rowIndex: row + 1))
            .value = xl.TextCellValue(m.note ?? '');
      }

      // Activities sheet
      final activitiesHeaders = [
        'Date',
        'ActivityType',
        'DistanceKm',
        'DurationMinutes',
        'CaloriesBurned',
        'Note',
        'RouteData',
        'MapLink',
      ];
      for (int i = 0; i < activitiesHeaders.length; i++) {
        final cell = activitiesSheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(activitiesHeaders[i]);
        cell.cellStyle = headerStyle;
      }

      String generateGoogleMapsLinkFromRouteData(String routeData) {
        try {
          final parsed = jsonDecode(routeData);
          if (parsed is Map) {
            final route = <Map<String, double>>[];
            final polyline = parsed['route_polyline']?.toString();
            if (polyline != null && polyline.isNotEmpty) {
              route.addAll(PolylineCodec.decodeRoute(polyline));
            } else if (parsed['route_points'] is List) {
              final points = parsed['route_points'] as List;
              for (final p in points) {
                if (p is Map && p['lat'] != null && p['lng'] != null) {
                  final lat = (p['lat'] as num).toDouble();
                  final lng = (p['lng'] as num).toDouble();
                  route.add({'lat': lat, 'lng': lng});
                }
              }
            }
            if (route.isEmpty) return '';
            if (route.length == 1) {
              final lat = route.first['lat'];
              final lng = route.first['lng'];
              return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
            }
            final origin = '${route.first['lat']},${route.first['lng']}';
            final destination = '${route.last['lat']},${route.last['lng']}';
            var waypoints = '';
            if (route.length > 2) {
              const maxWaypoints = 8;
              final inner = route.sublist(1, route.length - 1);
              final picked = <Map<String, double>>[];
              if (inner.length <= maxWaypoints) {
                picked.addAll(inner);
              } else {
                final step = inner.length / maxWaypoints;
                for (var i = 0; i < maxWaypoints; i++) {
                  final idx = (i * step).floor().clamp(0, inner.length - 1);
                  picked.add(inner[idx]);
                }
              }
              final waypointList =
                  picked.map((pt) => '${pt['lat']},${pt['lng']}').join('|');
              waypoints = '&waypoints=${Uri.encodeComponent(waypointList)}';
            }
            return 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination$waypoints';
          }
        } catch (_) {
          // ignore
        }
        return '';
      }

      for (int row = 0; row < activities.length; row++) {
        final a = activities[row];
        final createdAt = a.createdAt;
        final mapLink = generateGoogleMapsLinkFromRouteData(a.routeData);

        // Details sheet row (Activity)
        final detailsRowIndex = meals.length + row + 1;
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue(createdAt.toIso8601String());
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue('Activity');
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 2, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue(a.activityType);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 18, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue(a.routeData);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 19, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue(mapLink);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 10, rowIndex: detailsRowIndex))
            .value = xl.DoubleCellValue(a.distanceKm);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 11, rowIndex: detailsRowIndex))
            .value = xl.IntCellValue(a.durationMinutes);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 12, rowIndex: detailsRowIndex))
            .value = xl.IntCellValue(a.caloriesBurned);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 16, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue(a.note ?? '');

        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 17, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue(a.note ?? '');

        activitiesSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: row + 1))
            .value = xl.TextCellValue(a.createdAt.toIso8601String());
        activitiesSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: row + 1))
            .value = xl.TextCellValue(a.activityType);
        activitiesSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 2, rowIndex: row + 1))
            .value = xl.DoubleCellValue(a.distanceKm);
        activitiesSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 3, rowIndex: row + 1))
            .value = xl.IntCellValue(a.durationMinutes);
        activitiesSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 4, rowIndex: row + 1))
            .value = xl.IntCellValue(a.caloriesBurned);
        activitiesSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 5, rowIndex: row + 1))
            .value = xl.TextCellValue(a.note ?? '');
        activitiesSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 6, rowIndex: row + 1))
            .value = xl.TextCellValue(a.routeData);
        activitiesSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 7, rowIndex: row + 1))
            .value = xl.TextCellValue(mapLink);
      }

      // Water sheet
      final waterHeaders = ['Date', 'WaterMl'];
      for (int i = 0; i < waterHeaders.length; i++) {
        final cell = waterSheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(waterHeaders[i]);
        cell.cellStyle = headerStyle;
      }
      int waterRow = 1;
      var detailsWaterRow = meals.length + activities.length + 1;
      for (final entry in waterMap.entries) {
        final y = int.tryParse(entry.key.substring(0, 4));
        final m = int.tryParse(entry.key.substring(4, 6));
        final d = int.tryParse(entry.key.substring(6, 8));
        if (y == null || m == null || d == null) continue;
        final date = DateTime(y, m, d);

        // Details sheet row (Water)
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: detailsWaterRow))
            .value = xl.TextCellValue(date.toIso8601String());
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: detailsWaterRow))
            .value = xl.TextCellValue('Water');
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 13, rowIndex: detailsWaterRow))
            .value = xl.IntCellValue(entry.value);
        detailsWaterRow++;

        waterSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: waterRow))
            .value = xl.TextCellValue(date.toIso8601String());
        waterSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: waterRow))
            .value = xl.IntCellValue(entry.value);
        waterRow++;
      }

      // Events sheet
      final eventsHeaders = ['Date', 'Title', 'Note'];
      for (int i = 0; i < eventsHeaders.length; i++) {
        final cell = eventsSheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(eventsHeaders[i]);
        cell.cellStyle = headerStyle;
      }
      for (int row = 0; row < events.length; row++) {
        final e = events[row];

        // Details sheet row (Event)
        final detailsRowIndex = detailsWaterRow + row;
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue(e.createdAt.toIso8601String());
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue('Event');
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 14, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue(e.title);
        detailsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 15, rowIndex: detailsRowIndex))
            .value = xl.TextCellValue(e.note ?? '');

        eventsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: row + 1))
            .value = xl.TextCellValue(e.createdAt.toIso8601String());
        eventsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: row + 1))
            .value = xl.TextCellValue(e.title);
        eventsSheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 2, rowIndex: row + 1))
            .value = xl.TextCellValue(e.note ?? '');
      }

      // Daily Summary rows (1 row per day)
      final mealsByDay = <DateTime, List<MealItemIsar>>{};
      for (final meal in meals) {
        final dt = meal.createdAt;
        final day = DateTime(dt.year, dt.month, dt.day);
        (mealsByDay[day] ??= <MealItemIsar>[]).add(meal);
      }
      final activitiesByDay = <DateTime, List<ActivityIsar>>{};
      for (final act in activities) {
        final dt = act.createdAt;
        final day = DateTime(dt.year, dt.month, dt.day);
        (activitiesByDay[day] ??= <ActivityIsar>[]).add(act);
      }

      String dayKeyString(DateTime day) {
        final y = day.year.toString().padLeft(4, '0');
        final m = day.month.toString().padLeft(2, '0');
        final d = day.day.toString().padLeft(2, '0');
        return '$y$m$d';
      }

      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      var summaryRow = 1;
      for (var day = startDay;
          !day.isAfter(endDay);
          day = day.add(const Duration(days: 1))) {
        final dayMeals = mealsByDay[day] ?? const <MealItemIsar>[];
        final dayActs = activitiesByDay[day] ?? const <ActivityIsar>[];

        final totalCalories =
            dayMeals.fold<int>(0, (sum, m) => sum + m.calories);
        final totalProtein =
            dayMeals.fold<double>(0.0, (sum, m) => sum + m.protein);
        final totalCarbs =
            dayMeals.fold<double>(0.0, (sum, m) => sum + m.carbs);
        final totalFat = dayMeals.fold<double>(0.0, (sum, m) => sum + m.fat);
        final totalFiber =
            dayMeals.fold<double>(0.0, (sum, m) => sum + m.fiber);
        final totalSodium = dayMeals.fold<int>(0, (sum, m) => sum + m.sodium);
        final totalAddedSugar =
            dayMeals.fold<double>(0.0, (sum, m) => sum + m.addedSugar);

        final totalBurnedCalories =
            dayActs.fold<int>(0, (sum, a) => sum + a.caloriesBurned);
        final totalDistanceKm =
            dayActs.fold<double>(0.0, (sum, a) => sum + a.distanceKm);
        final totalDurationMinutes =
            dayActs.fold<int>(0, (sum, a) => sum + a.durationMinutes);

        final waterKey = dayKeyString(day);
        final totalWaterMl = waterMap[waterKey] ?? 0;

        final activeGoal = profile?.activeGoalForDate(day);
        final targets = profile?.calculateDailyTargets(forDate: day);

        final goalSet = activeGoal != null;
        final goalType = activeGoal?.goalType ?? 'maintain';
        final goalFrom = activeGoal?.fromDate;
        final goalTo = activeGoal?.toDate;

        final targetCalories = (targets?['dailyCalories'] as int?) ?? 0;
        final targetProtein = (targets?['proteinGrams'] as int?) ?? 0;
        final targetCarbs = (targets?['carbGrams'] as int?) ?? 0;
        final targetFat = (targets?['fatGrams'] as int?) ?? 0;
        final targetWater = (targets?['waterMl'] as int?) ?? 0;
        final targetFiber =
            (targets?['fiberTarget'] as num?)?.toDouble() ?? 0.0;
        final targetSodium =
            (targets?['sodiumTarget'] as num?)?.toDouble() ?? 0.0;
        final targetAddedSugar =
            (targets?['addedSugarTarget'] as num?)?.toDouble() ?? 0.0;
        final targetBurn = activeGoal?.targetBurnCalories ?? 0;

        final metCalories = goalSet ? totalCalories <= targetCalories : false;
        final metProtein = goalSet ? totalProtein >= targetProtein : false;
        final metWater = goalSet ? totalWaterMl >= targetWater : false;
        final metBurn = goalSet ? totalBurnedCalories >= targetBurn : false;

        final dateStr = day.toIso8601String().split('T').first;
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: summaryRow))
            .value = xl.TextCellValue(dateStr);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: summaryRow))
            .value = xl.TextCellValue(goalSet ? 'Yes' : 'No');
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 2, rowIndex: summaryRow))
            .value = xl.TextCellValue(goalType);
        dailySummarySheet
                .cell(xl.CellIndex.indexByColumnRow(
                    columnIndex: 3, rowIndex: summaryRow))
                .value =
            xl.TextCellValue(
                goalFrom?.toIso8601String().split('T').first ?? '');
        dailySummarySheet
                .cell(xl.CellIndex.indexByColumnRow(
                    columnIndex: 4, rowIndex: summaryRow))
                .value =
            xl.TextCellValue(goalTo?.toIso8601String().split('T').first ?? '');

        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 5, rowIndex: summaryRow))
            .value = xl.IntCellValue(targetCalories);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 6, rowIndex: summaryRow))
            .value = xl.IntCellValue(targetProtein);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 7, rowIndex: summaryRow))
            .value = xl.IntCellValue(targetCarbs);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 8, rowIndex: summaryRow))
            .value = xl.IntCellValue(targetFat);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 9, rowIndex: summaryRow))
            .value = xl.IntCellValue(targetWater);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 10, rowIndex: summaryRow))
            .value = xl.DoubleCellValue(targetFiber);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 11, rowIndex: summaryRow))
            .value = xl.DoubleCellValue(targetSodium);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 12, rowIndex: summaryRow))
            .value = xl.DoubleCellValue(targetAddedSugar);

        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 13, rowIndex: summaryRow))
            .value = xl.IntCellValue(totalCalories);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 14, rowIndex: summaryRow))
            .value = xl.DoubleCellValue(totalProtein);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 15, rowIndex: summaryRow))
            .value = xl.DoubleCellValue(totalCarbs);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 16, rowIndex: summaryRow))
            .value = xl.DoubleCellValue(totalFat);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 17, rowIndex: summaryRow))
            .value = xl.DoubleCellValue(totalFiber);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 18, rowIndex: summaryRow))
            .value = xl.IntCellValue(totalSodium);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 19, rowIndex: summaryRow))
            .value = xl.DoubleCellValue(totalAddedSugar);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 20, rowIndex: summaryRow))
            .value = xl.IntCellValue(totalBurnedCalories);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 21, rowIndex: summaryRow))
            .value = xl.DoubleCellValue(totalDistanceKm);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 22, rowIndex: summaryRow))
            .value = xl.IntCellValue(totalDurationMinutes);
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 23, rowIndex: summaryRow))
            .value = xl.IntCellValue(totalWaterMl);

        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 24, rowIndex: summaryRow))
            .value = xl.TextCellValue(metCalories ? 'Yes' : 'No');
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 25, rowIndex: summaryRow))
            .value = xl.TextCellValue(metProtein ? 'Yes' : 'No');
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 26, rowIndex: summaryRow))
            .value = xl.TextCellValue(metWater ? 'Yes' : 'No');
        dailySummarySheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: 27, rowIndex: summaryRow))
            .value = xl.TextCellValue(metBurn ? 'Yes' : 'No');

        summaryRow++;
      }

      final fileName =
          'VerveStride_Data_Export_${DateTime.now().toIso8601String().split('T').first}.xlsx';
      final bytes = excel.save();

      if (kIsWeb) {
        await FileSaver.saveBytes(fileName: fileName, bytes: bytes!);
      } else {
        // Mobile: Save to temporary file and share
        final filePath =
            await FileSaver.saveBytes(fileName: fileName, bytes: bytes!);

        // Share the file
        await Share.shareXFiles(
          [XFile(filePath, name: fileName)],
          text: 'VerveStride data export',
        );
      }

      if (!mounted) return;
      final delete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete exported data?'),
          content: Text(
              'Remove exported records from the app to free storage?\n\nExported ${meals.length} meals, ${activities.length} activities, ${waterMap.length} water entries, ${events.length} events.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (delete == true) {
        await _storage.deleteInRange(start, end);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Old data deleted from app')),
        );
        await _loadMonthData(_focusedDay);
        await _checkOldData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel exported & kept in app')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel export failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

class _MiniRingDayCell extends StatelessWidget {
  final DateTime day;
  final double percent;
  final bool isToday;
  final bool isSelected;
  final bool hasData;

  const _MiniRingDayCell({
    required this.day,
    required this.percent,
    required this.isToday,
    required this.isSelected,
    required this.hasData,
  });

  Color _colorForPercent(double p) {
    if (!hasData) return Colors.white.withOpacity(0.18);
    return p >= 1.0 ? AppColors.accent : AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = _colorForPercent(percent);
    final borderColor = isSelected
        ? AppColors.primary
        : isToday
            ? Colors.white.withOpacity(0.55)
            : Colors.transparent;

    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (hasData)
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  value: percent.clamp(0.0, 1.0),
                  strokeWidth: 2.5,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                ),
              ),
            Text(
              '${day.day}',
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Removed _MiniTripleRingPainter as we're using CircularProgressIndicator now
