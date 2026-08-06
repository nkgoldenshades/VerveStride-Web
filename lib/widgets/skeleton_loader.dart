import 'package:flutter/material.dart';

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 8,
    this.margin,
  });

  final double? height;
  final double? width;
  final double borderRadius;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
      ),
      child: _shimmer(context),
    );
  }

  Widget _shimmer(BuildContext context) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 1500),
      tween: Tween<double>(begin: -1, end: 2),
      builder: (context, double value, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment(value - 1, 0),
              end: Alignment(value, 0),
              colors: [
                Theme.of(context).colorScheme.surface.withOpacity(0.1),
                Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                Theme.of(context).colorScheme.surface.withOpacity(0.1),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (index) => const SkeletonLoader(height: 60, margin: EdgeInsets.symmetric(vertical: 4))),
    );
  }
}

class SkeletonRing extends StatelessWidget {
  const SkeletonRing({super.key, this.size = 200});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
          width: 12,
        ),
      ),
      child: _shimmer(context),
    );
  }

  Widget _shimmer(BuildContext context) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 1500),
      tween: Tween<double>(begin: -1, end: 2),
      builder: (context, double value, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment(value - 1, 0),
              end: Alignment(value, 0),
              colors: [
                Theme.of(context).colorScheme.surface.withOpacity(0.1),
                Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                Theme.of(context).colorScheme.surface.withOpacity(0.1),
              ],
            ),
          ),
        );
      },
    );
  }
}

