import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/theme_controller.dart';
import '../core/app_theme.dart';
import '../services/battery_optimization_service.dart';
import 'main/home_screen.dart';
import 'main/calendar_screen.dart';
import 'main/log_screen.dart';
import 'fitness/profile_screen.dart';

class NavigationContainer extends StatefulWidget {
  const NavigationContainer({super.key});

  @override
  State<NavigationContainer> createState() => _NavigationContainerState();
}

class _NavigationContainerState extends State<NavigationContainer> {
  int _currentIndex = 0;

  // Keep screens alive — no rebuilds on tab switch
  late final List<Widget> _screens = [
    const HomeScreen(),
    LogScreen(onCompleted: _goHomeAndRefresh),
    const CalendarScreen(),
    const ProfileScreen(),
  ];

  void _goHomeAndRefresh() {
    setState(() => _currentIndex = 0);
    HomeScreen.globalRefresh();
    CalendarScreen.globalRefresh(); // Also refresh calendar
  }

  @override
  void initState() {
    super.initState();
    // Start listening to premium status changes when user logs in/app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      User? user;
      try {
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {
        user = null;
      }
      if (user != null) {
        ThemeController.instance.load(user.uid);
        ThemeController.instance.listenToPremiumStatus(user.uid);
      }

      // Ask for battery optimization exemption once — critical for alarms on
      // Xiaomi/MIUI, Huawei, OnePlus, Vivo and other OEM devices.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          BatteryOptimizationService.instance.requestIfNeeded(context);
        }
      });
    });
  }

  @override
  void dispose() {
    //Stop listening to avoid memory leaks
    ThemeController.instance.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Keep all screens mounted, just show the active one — instant switching
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.9),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Log',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
