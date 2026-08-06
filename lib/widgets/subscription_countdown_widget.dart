import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/user_subscription_service.dart';

/// Shows a live countdown to subscription expiry.
/// Updates every minute. Hidden for permanent/lifetime plans.
class SubscriptionCountdownWidget extends StatefulWidget {
  const SubscriptionCountdownWidget({super.key});

  @override
  State<SubscriptionCountdownWidget> createState() =>
      _SubscriptionCountdownWidgetState();
}

class _SubscriptionCountdownWidgetState
    extends State<SubscriptionCountdownWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh every minute so the countdown ticks
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserSubscriptionService.instance,
      builder: (context, _) {
        final sub = UserSubscriptionService.instance;
        final expiresAt = sub.expiresAt;

        // Hide for free users or permanent plans
        if (sub.isFree || expiresAt == null) return const SizedBox.shrink();

        final diff = expiresAt.difference(DateTime.now());
        if (diff.isNegative) {
          return _chip('Expired', Colors.red);
        }

        final days = diff.inDays;
        final hours = diff.inHours % 24;
        final minutes = diff.inMinutes % 60;

        final isWarning = days <= 7;
        final color = isWarning ? Colors.orange : AppColors.accent;

        final label = days > 0
            ? '${days}d ${hours}h left'
            : '${hours}h ${minutes}m left';

        return _chip(label, color);
      },
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
