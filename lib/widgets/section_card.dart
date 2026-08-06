import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.highlighted = false,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: AppDecorations.glassCard(highlighted: highlighted),
      child: title != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                child,
              ],
            )
          : child,
    );
  }
}
