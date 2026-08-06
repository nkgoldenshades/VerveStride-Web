import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FloatingQuickAdd extends StatelessWidget {
  const FloatingQuickAdd({
    super.key,
    required this.onAddMeal,
    required this.onAddWater,
    required this.onAddActivity,
  });

  final VoidCallback onAddMeal;
  final VoidCallback onAddWater;
  final VoidCallback onAddActivity;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Don't show floating buttons on web - use existing UI
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick water add
        FloatingActionButton(
          heroTag: "water",
          onPressed: onAddWater,
          backgroundColor: Colors.blue.withOpacity(0.8),
          mini: true,
          child: const Icon(Icons.water_drop, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 8),
        // Quick activity add
        FloatingActionButton(
          heroTag: "activity",
          onPressed: onAddActivity,
          backgroundColor: Colors.orange.withOpacity(0.8),
          mini: true,
          child: const Icon(Icons.directions_run, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 8),
        // Quick meal add
        FloatingActionButton(
          heroTag: "meal",
          onPressed: onAddMeal,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
          child: const Icon(Icons.restaurant, color: Colors.white, size: 16),
        ),
      ],
    );
  }
}

class ExpandableFloatingQuickAdd extends StatefulWidget {
  const ExpandableFloatingQuickAdd({
    super.key,
    required this.onAddMeal,
    required this.onAddWater,
    required this.onAddActivity,
  });

  final VoidCallback onAddMeal;
  final VoidCallback onAddWater;
  final VoidCallback onAddActivity;

  @override
  State<ExpandableFloatingQuickAdd> createState() => _ExpandableFloatingQuickAddState();
}

class _ExpandableFloatingQuickAddState extends State<ExpandableFloatingQuickAdd>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotateAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 0.75,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded buttons
        ScaleTransition(
          scale: _expandAnimation,
          child: FadeTransition(
            opacity: _expandAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "water_expanded",
                  onPressed: () {
                    widget.onAddWater();
                    _toggle();
                  },
                  backgroundColor: Colors.blue,
                  mini: true,
                  child: const Icon(Icons.water_drop, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "activity_expanded",
                  onPressed: () {
                    widget.onAddActivity();
                    _toggle();
                  },
                  backgroundColor: Colors.orange,
                  mini: true,
                  child: const Icon(Icons.directions_run, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "meal_expanded",
                  onPressed: () {
                    widget.onAddMeal();
                    _toggle();
                  },
                  backgroundColor: Theme.of(context).primaryColor,
                  mini: true,
                  child: const Icon(Icons.restaurant, color: Colors.white),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // Main button
        FloatingActionButton(
          heroTag: "main",
          onPressed: _toggle,
          backgroundColor: Theme.of(context).primaryColor,
          child: AnimatedBuilder(
            animation: _rotateAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnimation.value * 2.0 * 3.14159265359,
                child: const Icon(Icons.add, color: Colors.white),
              );
            },
          ),
        ),
      ],
    );
  }
}
