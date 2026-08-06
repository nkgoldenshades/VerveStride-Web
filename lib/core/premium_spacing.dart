import 'package:flutter/material.dart';

/// PREMIUM SPACING SYSTEM
/// Based on the History section that looks professional
/// Use these rules everywhere - no more guessing, no more "off" feeling UI
/// 
/// THE GOLDEN RULE: 8px / 16px / 24px hierarchy
/// - 8px: Small spacing (text hierarchy, tight relationships)
/// - 16px: Medium spacing (content groups, breathing room)  
/// - 24px: Large spacing (major sections, visual separation)

class PremiumSpacing {
  
  // THE THREE MAGIC NUMBERS
  static const double xs = 8.0;   // Small: text relationships, tight groups
  static const double sm = 16.0;  // Medium: content groups, breathing room
  static const double lg = 24.0;  // Large: major sections, visual breaks
  
  // Screen-level padding (16px = comfortable, not cramped)
  static const EdgeInsets screen = EdgeInsets.all(sm);
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets screenVertical = EdgeInsets.symmetric(vertical: sm);
  
  // Card spacing (20px inside for premium feel)
  static const EdgeInsets card = EdgeInsets.all(20.0);
  static const EdgeInsets cardHorizontal = EdgeInsets.symmetric(horizontal: 20.0);
  static const EdgeInsets cardVertical = EdgeInsets.symmetric(vertical: 20.0);
  
  // Card margin (16px outside for breathing room)
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(horizontal: sm);
  
  // Section spacing (24px between major components)
  static const double section = lg;
  
  // Text hierarchy (8px between related text)
  static const double text = xs;
  
  // Button spacing (16px before primary actions)
  static const double button = sm;
  
  // Form spacing (16px between fields)
  static const double field = sm;
  
  // List spacing (12px between items - between xs and sm)
  static const double list = 12.0;
}

/// SPACING WIDGETS - Use these everywhere
/// No more SizedBox(height: 16) scattered randomly
/// Use semantic names that describe the relationship

class Spacing {
  // Text spacing (8px)
  static const SizedBox text = SizedBox(height: PremiumSpacing.text);
  
  // Content spacing (16px) 
  static const SizedBox content = SizedBox(height: PremiumSpacing.sm);
  
  // Section spacing (24px)
  static const SizedBox section = SizedBox(height: PremiumSpacing.lg);
  
  // Button spacing (16px)
  static const SizedBox button = SizedBox(height: PremiumSpacing.button);
  
  // Form field spacing (16px)
  static const SizedBox field = SizedBox(height: PremiumSpacing.field);
  
  // List item spacing (12px)
  static const SizedBox list = SizedBox(height: PremiumSpacing.list);
}

/// LAYOUT PATTERNS - Copy these for professional UI
/// Based on the History section that looks premium

class PremiumLayout {
  
  /// Screen layout with proper vertical rhythm
  /// Header → content → sections with 24px breathing room
  static Widget buildScreen({
    required Widget header,
    required Widget content,
    required List<Widget> sections,
  }) {
    return Padding(
      padding: PremiumSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: PremiumSpacing.lg),
          content,
          const SizedBox(height: PremiumSpacing.lg),
          ...sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;
            
            return Column(
              children: [
                if (index > 0) const SizedBox(height: PremiumSpacing.lg),
                section,
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
  
  /// Premium card layout like History section
  /// 20px padding, 16px margin, left-aligned content
  static Widget buildCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    return Container(
      width: double.infinity,
      margin: margin ?? PremiumSpacing.cardMargin,
      padding: padding ?? PremiumSpacing.card,
      child: child,
    );
  }
  
  /// Text section with proper hierarchy
  /// Title → subtitle → description with 8px spacing
  static Widget buildTextSection({
    required String title,
    String? subtitle,
    String? description,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? descriptionStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        if (subtitle != null) ...[
          const SizedBox(height: PremiumSpacing.xs),
          Text(subtitle, style: subtitleStyle),
        ],
        if (description != null) ...[
          const SizedBox(height: PremiumSpacing.xs),
          Text(description, style: descriptionStyle),
        ],
      ],
    );
  }
  
  /// Action section with proper spacing
  /// Content → 16px breathing → full-width button
  static Widget buildActionSection({
    required Widget content,
    required Widget button,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        const SizedBox(height: PremiumSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: button,
        ),
      ],
    );
  }
  
  /// List section with consistent spacing
  /// Title → 8px → items with 12px spacing
  static Widget buildListSection({
    required String title,
    required List<Widget> items,
    TextStyle? titleStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: PremiumSpacing.xs),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          return Column(
            children: [
              if (index > 0) const SizedBox(height: PremiumSpacing.list),
              item,
            ],
          );
        }).toList(),
      ],
    );
  }
}

/// SPACING VALIDATOR - Call this to check if UI follows the rules
/// I'll use this to call out bad spacing when it appears

class SpacingValidator {
  
  /// Check if spacing follows the 8/16/24 rule
  static bool isValidSpacing(double spacing) {
    return spacing == PremiumSpacing.xs || 
           spacing == PremiumSpacing.sm || 
           spacing == PremiumSpacing.lg ||
           spacing == PremiumSpacing.list; // 12px exception for lists
  }
  
  /// Get spacing category name for debugging
  static String getSpacingCategory(double spacing) {
    if (spacing == PremiumSpacing.xs) return 'text (8px)';
    if (spacing == PremiumSpacing.sm) return 'content (16px)';
    if (spacing == PremiumSpacing.lg) return 'section (24px)';
    if (spacing == PremiumSpacing.list) return 'list (12px)';
    return 'INVALID (${spacing}px)';
  }
  
  /// Validate a widget tree (basic check)
  static List<String> validateWidget(Widget widget) {
    final issues = <String>[];
    
    // This is a simplified check - in real usage, we'd traverse the tree
    // For now, just check if common patterns are used
    
    if (widget is Padding) {
      final padding = widget.padding;
      if (padding is EdgeInsets) {
        if (padding.left != 0 && !isValidSpacing(padding.left)) {
          issues.add('Invalid left padding: ${getSpacingCategory(padding.left)}');
        }
        if (padding.top != 0 && !isValidSpacing(padding.top)) {
          issues.add('Invalid top padding: ${getSpacingCategory(padding.top)}');
        }
        if (padding.right != 0 && !isValidSpacing(padding.right)) {
          issues.add('Invalid right padding: ${getSpacingCategory(padding.right)}');
        }
        if (padding.bottom != 0 && !isValidSpacing(padding.bottom)) {
          issues.add('Invalid bottom padding: ${getSpacingCategory(padding.bottom)}');
        }
      }
    }
    
    return issues;
  }
}

/// QUICK REFERENCE - COPY THIS CHEAT SHEET

/*
SPACING RULES (MEMORIZE THESE):

🎯 GOLDEN HIERARCHY:
8px  → Text relationships, tight groups
16px → Content groups, breathing room  
24px → Major sections, visual breaks

📱 SCREEN LAYOUT:
Padding: PremiumSpacing.screen (16px all around)
Between sections: Spacing.section (24px)

📦 CARD LAYOUT:
Inside: PremiumSpacing.card (20px padding)
Outside: PremiumSpacing.cardMargin (16px horizontal)

📝 TEXT HIERARCHY:
Title → subtitle: Spacing.text (8px)
Subtitle → description: Spacing.text (8px)

🔘 BUTTONS:
Height: 52px (premium feel)
Spacing above: Spacing.button (16px)
Width: double.infinity (primary actions)

📋 FORMS & LISTS:
Between fields: Spacing.field (16px)
Between list items: Spacing.list (12px)

✅ ALIGNMENT RULE:
Left-align everything in cards
Use consistent left edge (no random floating)

❌ WHAT TO AVOID:
- Random spacing numbers (7px, 13px, 19px, etc.)
- Cramped sections (no breathing room)
- Misaligned content (no visual grid)
- Floating elements (no anchor points)

✅ WHAT TO DO:
- Use Spacing widgets (semantic names)
- Follow 8/16/24 hierarchy
- Left-align card content
- Give sections breathing room

WHEN IN DOUBT:
- Use 16px (most versatile)
- Check History section for reference
- Ask: "Does this feel like the History UI?"
*/
