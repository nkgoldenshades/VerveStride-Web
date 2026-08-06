import 'dart:convert';
import 'dart:html' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/file_saver.dart';

class CsvService {
  static Future<void> exportToCsv(
      List<List<String>> data, String fileName) async {
    final csv = const ListToCsvConverter().convert(data);

    if (kIsWeb) {
      // Web download
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile: Save to temporary file and share
      final bytes = utf8.encode(csv);
      final tempDir =
          await FileSaver.saveBytes(fileName: fileName, bytes: bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(tempDir, name: fileName)],
        text: 'VerveStride CSV export',
      );
    }
  }

  static Future<void> exportHistoryToCsv({
    required List<Map<String, dynamic>> meals,
    required List<Map<String, dynamic>> activities,
    required Map<String, int> waterData,
    String? fileName,
  }) async {
    final List<List<String>> csvData = [];

    // Add header
    csvData.add([
      'Date',
      'Type',
      'Name/Activity',
      'Calories',
      'Protein (g)',
      'Carbs (g)',
      'Fat (g)',
      'Fiber (g)',
      'Sodium (mg)',
      'Sugar (g)',
      'Duration (min)',
      'Distance (km)',
      'Water (ml)',
      'Notes'
    ]);

    // Add meals
    for (final meal in meals) {
      csvData.add([
        meal['date'] ?? '',
        'Meal',
        meal['name'] ?? '',
        meal['calories']?.toString() ?? '',
        meal['protein']?.toString() ?? '',
        meal['carbs']?.toString() ?? '',
        meal['fat']?.toString() ?? '',
        meal['fiber']?.toString() ?? '',
        meal['sodium']?.toString() ?? '',
        meal['addedSugar']?.toString() ?? '',
        '', '', '', // Activity-specific fields
        meal['notes']?.toString() ?? '',
      ]);
    }

    // Add activities
    for (final activity in activities) {
      csvData.add([
        activity['date'] ?? '',
        'Activity',
        activity['activityType'] ?? '',
        activity['caloriesBurned']?.toString() ?? '',
        '', '', '', '', '', '', // Meal-specific fields
        activity['durationMinutes']?.toString() ?? '',
        activity['distanceKm']?.toString() ?? '',
        '', // Water field
        activity['notes']?.toString() ?? '',
      ]);
    }

    // Add water
    for (final entry in waterData.entries) {
      csvData.add([
        entry.key, // Date
        'Water',
        '', '', '', '', '', '', '', '', // Meal/Activity fields
        '', '', // Duration/Distance
        entry.value.toString(), // Water amount
        '', // Notes
      ]);
    }

    final finalFileName = fileName ??
        'Vervestride_history_${DateTime.now().millisecondsSinceEpoch}.csv';
    await exportToCsv(csvData, finalFileName);
  }
}
