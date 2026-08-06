import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vervestride/utils/route_share_utils.dart';

class ExcelService {
  static String _generateGoogleMapsLink(List<Map<String, double>> route) {
    return RouteShareUtils.buildGoogleMapsRouteUrl(route);
  }

  static Future<void> exportActivitiesToExcel(
    List<Map<String, dynamic>> activities,
  ) async {
    try {
      // Create Excel file
      final excel = Excel.createExcel();
      final sheet = excel['Activities'];
      // Add headers
      final headers = [
        'Date',
        'Activity Type',
        'Duration (minutes)',
        'Distance (km)',
        'Calories Burned',
        'Start Time',
        'End Time',
        'Notes',
        'Map Link',
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(
          headers[i],
        );
      }
      // Add data
      for (int i = 0; i < activities.length; i++) {
        final activity = activities[i];
        final rowIndex = i + 1;
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          activity['date']?.toString() ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          activity['activityType']?.toString() ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = IntCellValue(
          activity['durationMinutes'] ?? 0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          activity['distanceKm'] ?? 0.0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = IntCellValue(
          activity['caloriesBurned'] ?? 0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          activity['startTime']?.toString() ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          activity['endTime']?.toString() ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          activity['notes']?.toString() ?? '',
        );
        // Generate Google Maps link from route points
        final mapLink = _generateGoogleMapsLink(
          activity['route'] as List<Map<String, double>>? ?? [],
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          mapLink,
        );
      }
      final fileName =
          'VerveStride_Activities_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final fileBytes = excel.save();
      if (fileBytes == null) {
        debugPrint('Error exporting to Excel: failed to generate file bytes');
        return;
      }

      if (kIsWeb) {
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile: Save to temporary directory and share
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(fileBytes);

        // Share the file
        await Share.shareXFiles(
          [XFile(file.path, name: fileName)],
          text: 'VerveStride activities export',
        );
      }
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
    }
  }

  static Future<void> exportMealsToExcel(
    List<Map<String, dynamic>> meals,
  ) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Meals'];
      // Add headers
      final headers = [
        'Date',
        'Meal Type',
        'Food Item',
        'Calories',
        'Protein (g)',
        'Carbs (g)',
        'Fat (g)',
        'Fiber (g)',
        'Sodium (mg)',
        'Added Sugar (g)',
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(
          headers[i],
        );
      }
      // Add data
      for (int i = 0; i < meals.length; i++) {
        final meal = meals[i];
        final rowIndex = i + 1;
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          meal['date']?.toString() ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          meal['mealType']?.toString() ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          meal['foodItem']?.toString() ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = IntCellValue(
          meal['calories'] ?? 0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          meal['protein'] ?? 0.0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          meal['carbs'] ?? 0.0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          meal['fat'] ?? 0.0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          meal['fiber'] ?? 0.0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
            )
            .value = IntCellValue(
          meal['sodium'] ?? 0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          meal['added_sugar'] ?? 0.0,
        );
      }
      final fileName =
          'VerveStride_Meals_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final fileBytes = excel.save();
      if (fileBytes == null) {
        debugPrint(
            'Error exporting meals to Excel: failed to generate file bytes');
        return;
      }

      if (kIsWeb) {
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile: Save to temporary directory and share
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(fileBytes);

        // Share the file
        await Share.shareXFiles(
          [XFile(file.path, name: fileName)],
          text: 'VerveStride meals export',
        );
      }
    } catch (e) {
      debugPrint('Error exporting meals to Excel: $e');
    }
  }

  static Future<void> exportWeightToExcel(
    List<Map<String, dynamic>> weightData,
  ) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Weight Tracking'];
      // Add headers
      final headers = ['Date', 'Weight (kg)', 'BMI', 'Body Fat %', 'Notes'];
      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(
          headers[i],
        );
      }
      // Add data
      for (int i = 0; i < weightData.length; i++) {
        final data = weightData[i];
        final rowIndex = i + 1;
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          data['date']?.toString() ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          data['weight'] ?? 0.0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          data['bmi'] ?? 0.0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = DoubleCellValue(
          data['bodyFat'] ?? 0.0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          data['notes']?.toString() ?? '',
        );
      }
      final fileName =
          'VerveStride_Weight_Tracking_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final fileBytes = excel.save();
      if (fileBytes == null) {
        debugPrint(
          'Error exporting weight data to Excel: failed to generate file bytes',
        );
        return;
      }

      if (kIsWeb) {
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile: Save to temporary directory and share
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(fileBytes);

        // Share the file
        await Share.shareXFiles(
          [XFile(file.path, name: fileName)],
          text: 'VerveStride weight tracking export',
        );
      }
    } catch (e) {
      debugPrint('Error exporting weight data to Excel: $e');
    }
  }
}
