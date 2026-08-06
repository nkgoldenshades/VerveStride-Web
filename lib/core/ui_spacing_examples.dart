import 'package:flutter/material.dart';
import 'ui_spacing.dart';

/// Examples of how to use the spacing system consistently
/// Copy these patterns for all your screens

class SpacingExamples {
  
  /// Example: Professional card layout with proper spacing
  static Widget buildProfessionalCard({
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onButtonPressed,
    String buttonText = 'Primary Action',
  }) {
    return CardLayout.build(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title section
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.textSpacingS),
          
          // Subtitle section  
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.textSpacingM),
          
          // Description section
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.textSpacingXL),
          
          // Button section - full width and properly aligned
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeightL,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              onPressed: onButtonPressed,
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Example: Screen layout with proper section spacing
  static Widget buildScreenWithSections({
    required Widget header,
    required Widget mainContent,
    required Widget cardContent,
  }) {
    return Padding(
      padding: AppSpacing.screenPaddingAll,
      child: Column(
        children: [
          // Header section
          header,
          const SizedBox(height: AppSpacing.sectionSpacing),
          
          // Main content section
          mainContent,
          const SizedBox(height: AppSpacing.sectionSpacing),
          
          // Card section with breathing room
          CardLayout.build(
            child: cardContent,
          ),
        ],
      ),
    );
  }
  
  /// Example: Form with proper field spacing
  static Widget buildFormSection({
    required Widget title,
    required List<Widget> fields,
    required Widget submitButton,
  }) {
    return CardLayout.build(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: AppSpacing.textSpacingM),
          
          // Form fields with consistent spacing
          ...fields.asMap().entries.map((entry) {
            final index = entry.key;
            final field = entry.value;
            
            return Column(
              children: [
                if (index > 0) const SizedBox(height: AppSpacing.fieldSpacing),
                field,
              ],
            );
          }).toList(),
          
          const SizedBox(height: AppSpacing.buttonSpacing),
          submitButton,
        ],
      ),
    );
  }
  
  /// Example: List with proper item spacing
  static Widget buildListSection({
    required Widget title,
    required List<Widget> items,
  }) {
    return CardLayout.build(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: AppSpacing.textSpacingM),
          
          // List items with consistent spacing
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            
            return Column(
              children: [
                if (index > 0) const SizedBox(height: AppSpacing.listItemSpacing),
                item,
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}

/// QUICK REFERENCE CHEAT SHEET
/// 
/// SCREEN LAYOUT:
/// Padding: AppSpacing.screenPaddingAll (16px all around)
/// Between sections: LayoutSpacing.section (24px)
/// 
/// CARD LAYOUT:
/// Padding: AppSpacing.cardPaddingAll (20px inside)
/// Margin: AppSpacing.cardMarginHorizontal (16px outside)
/// 
/// TEXT HIERARCHY:
/// Title → subtitle: TextSpacing.s (6px)
/// Subtitle → description: TextSpacing.m (8px)  
/// Description → button: TextSpacing.xl (16px)
/// 
/// BUTTONS:
/// Height: AppSpacing.buttonHeightL (52px for primary)
/// Spacing above: ButtonSpacing.m (16px)
/// Full width: width: double.infinity
/// 
/// FORMS:
/// Between fields: AppSpacing.fieldSpacing (16px)
/// Field to button: ButtonSpacing.m (16px)
/// 
/// LISTS:
/// Between items: AppSpacing.listItemSpacing (12px)
/// 
/// VISUAL HIERARCHY RULE:
/// Inside card spacing < Section spacing < Screen padding
/// 6-8-16px inside cards, 24px between sections, 16px screen edges
