import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class NutritionService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/cgi/search.pl';

  static Future<Map<String, dynamic>?> searchFood(String query) async {
    if (query.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'search_terms': query.trim(),
        'search_simple': '1',
        'json': '1',
        'page_size': '20',
      });
      debugPrint('Searching nutrition database: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('Response body: ${response.body}');
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final products = data['products'] as List<dynamic>?;
      if (products == null || products.isEmpty) {
        debugPrint('No products found');
        return null;
      }
      Map<String, dynamic>? selected;
      Map<String, dynamic>? nutriments;
      for (final item in products) {
        if (item is! Map<String, dynamic>) continue;
        final n = item['nutriments'] as Map<String, dynamic>?;
        if (n != null && n.isNotEmpty) {
          selected = item;
          nutriments = n;
          break;
        }
      }
      if (selected == null || nutriments == null) {
        debugPrint('No nutriments found');
        return null;
      }
      final productName =
          (selected['product_name'] as String?)?.trim() ?? query;
      final servingSize = selected['serving_size'] as String? ?? '100g';
      
      final result = {
        'name': productName,
        'servingSize': servingSize,
        'calories': _parseNum(nutriments['energy-kcal_100g']),
        'protein': _parseNum(nutriments['proteins_100g']),
        'carbs': _parseNum(nutriments['carbohydrates_100g']),
        'fat': _parseNum(nutriments['fat_100g']),
        'fiber': _parseNum(nutriments['fiber_100g'] ?? nutriments['fibres_100g']),
        'sodium': _parseNum(nutriments['sodium_100g'] ?? nutriments['salt_100g']), // mg
        'addedSugar': _parseNum(nutriments['sugars_100g']), // g (approximation for added sugar)
      };
      debugPrint('Nutrition result (per 100g): $result');
      return result;
    } catch (e, stackTrace) {
      debugPrint('Nutrition search error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> searchFoodCandidates(
      String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'search_terms': query.trim(),
        'search_simple': '1',
        'json': '1',
        'page_size': '50',
        'lc': 'en',
      });
      debugPrint('Searching food candidates: $uri');

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent':
              'NandaNutritionApp/1.0 (Flutter; contact: nanda@example.com)',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('HTTP error: ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final products = data['products'] as List<dynamic>? ?? [];

      final List<Map<String, dynamic>> candidates = [];
      for (final item in products) {
        if (item is! Map<String, dynamic>) continue;
        final nutriments = item['nutriments'] as Map<String, dynamic>?;
        if (nutriments == null || nutriments.isEmpty) continue;

        final calories = _parseNum(
            nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal']);
        if (calories <= 0) continue;

        final name = (item['product_name_en'] as String?)?.trim() ??
            (item['product_name'] as String?)?.trim() ??
            '';

        if (name.isEmpty) continue;

        final brand = (item['brands'] as String?)?.trim() ?? 'Generic';

        final imageUrl = item['image_front_url'] as String? ??
            item['image_front_small_url'] as String? ??
            item['image_url'] as String?;

        candidates.add({
          'name': name,
          'brand': brand,
          'image_url': imageUrl,
          'serving_size':
              (item['serving_size'] as String?)?.trim() ?? '100g',
          'nutriments': nutriments,
          'full_item': item,
        });

        if (candidates.length >= 20) break;
      }

      debugPrint('Found ${candidates.length} viable candidates');
      return candidates;
    } catch (e, stackTrace) {
      debugPrint('Search error: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  static Map<String, dynamic> candidateToNutritionData(
      Map<String, dynamic> candidate) {
    final nutriments = candidate['nutriments'] as Map<String, dynamic>;
    return {
      'name': candidate['name'] as String? ?? 'Unknown',
      'brand': candidate['brand'] as String? ?? 'Generic',
      'servingSize': candidate['serving_size'] as String? ?? '100g',
      'calories': _parseNum(
          nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal']),
      'protein': _parseNum(nutriments['proteins_100g'] ?? nutriments['proteins']),
      'carbs': _parseNum(
          nutriments['carbohydrates_100g'] ?? nutriments['carbohydrates']),
      'fat': _parseNum(nutriments['fat_100g'] ?? nutriments['fat']),
      'fiber': _parseNum(
          nutriments['fiber_100g'] ?? nutriments['fibres_100g'] ?? 0),
      'sodium': _parseNum(nutriments['sodium_100g'] ?? 0) * 1000,
      'addedSugar': _parseNum(nutriments['sugars_100g'] ?? 0),
    };
  }

  static double _parseNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
