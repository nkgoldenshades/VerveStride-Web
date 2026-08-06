import 'package:flutter/material.dart';

/// Shimmer loading effect widget
/// Creates animated skeleton loading states
class ShimmerLoader extends StatefulWidget {
  const ShimmerLoader({
    super.key,
    this.width = double.infinity,
    this.height = 100,
    this.borderRadius = 16,
    this.baseColor = const Color(0xFF102844),
    this.highlightColor = const Color(0xFF1A3A5C),
  });

  final double width;
  final double height;
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer card - for card-shaped skeletons
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    super.key,
    this.width = double.infinity,
    this.height = 120,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      width: width,
      height: height,
      borderRadius: 24,
    );
  }
}

/// Shimmer circle - for avatar/icon skeletons
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({
    super.key,
    this.size = 60,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      width: size,
      height: size,
      borderRadius: size / 2,
    );
  }
}

/// Shimmer list - for loading lists
class ShimmerList extends StatelessWidget {
  const ShimmerList({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 100,
    this.spacing = 16,
  });

  final int itemCount;
  final double itemHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index < itemCount - 1 ? spacing : 0),
          child: ShimmerCard(height: itemHeight),
        ),
      ),
    );
  }
}
