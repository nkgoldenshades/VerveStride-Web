import 'package:flutter/material.dart';
import '../../widgets/gradient_scaffold.dart';
import 'reminders_today_tab.dart';
import 'reminders_upcoming_tab.dart';
import 'reminders_history_tab.dart';

/// Main Reminders Screen with 3 tabs: Today, Upcoming, History
/// 
/// Features:
/// - Today: Current day reminders with completion tracking
/// - Upcoming: Future reminders grouped by date + recurring reminders
/// - History: Calendar view + past reminders with edit capability
class RemindersMainScreen extends StatefulWidget {
  const RemindersMainScreen({super.key});

  @override
  State<RemindersMainScreen> createState() => _RemindersMainScreenState();
}

class _RemindersMainScreenState extends State<RemindersMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'TODAY'),
            Tab(text: 'UPCOMING'),
            Tab(text: 'HISTORY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          RemindersTodayTab(),
          RemindersUpcomingTab(),
          RemindersHistoryTab(),
        ],
      ),
    );
  }
}
