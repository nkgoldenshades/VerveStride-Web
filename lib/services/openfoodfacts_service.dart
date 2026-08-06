import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:openfoodfacts/openfoodfacts.dart';

class OpenFoodFactsService {
  // Search foods using CGI endpoint (more reliable)
  static Future<List<Product>> searchFood(String query,
      {int pageSize = 50, int page = 1}) async {
    try {
      final uri = Uri.parse('https://world.openfoodfacts.org/cgi/search.pl')
          .replace(queryParameters: {
        'search_terms': query,
        'page_size': pageSize.toString(),
        'page': page.toString(),
        'json': '1',
        'fields':
            'product_name,brands,image_front_url,nutriments,serving_size,barcode,categories,nutriscore_grade,ecoscore_grade'
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final products = <Product>[];

      if (data['products'] != null) {
        for (final productData in data['products']) {
          // Convert CGI response to Product object
          final product = Product.fromJson(productData);
          products.add(product);
        }
      }

      debugPrint('Search found ${products.length} products for "$query"');
      return products;
    } catch (e) {
      debugPrint('Nutrition search error: $e');
      if (kIsWeb) {
        // On web, returning [] hides the real reason (CORS/rate limit/etc.)
        // and the UI misleadingly shows "No nutrition data found".
        rethrow;
      }
      return []; // Non-web: Return empty list on error to trigger fallback
    }
  }

  // Get product details (v3 structure)
  static Future<Product?> getFoodDetails(String barcode) async {
    final ProductQueryConfiguration config = ProductQueryConfiguration(
      barcode,
      language: OpenFoodFactsLanguage.ENGLISH,
      fields: [
        ProductField.ALL,
      ],
      version: ProductQueryVersion.v3,
    );

    final ProductResultV3 result = await OpenFoodAPIClient.getProductV3(config);

    if (result.status == ProductResultV3.statusSuccess) {
      return result.product;
    }
    return null;
  }

  // Helper method to convert Product to Map for easier UI integration
  static Map<String, dynamic> productToMap(Product product) {
    return {
      'name': product.productName ?? 'Unknown',
      'brand': product.brands ?? 'Generic',
      'serving_size': product.servingSize ?? '100g',
      'barcode': product.barcode ?? '',
      'image_url': product.imageFrontUrl ?? '',
      'categories': product.categories ?? [],
      'nutri_score': product.nutriscore?.toUpperCase() ?? 'Unknown',
      'eco_score': product.ecoscoreGrade ?? 'Unknown',
      'ingredients': product.ingredientsText ?? 'Not available',
      'labels': product.labels ?? '',
      'countries': product.countries ?? '',
      // Nutrients - simplified for now
      'nutrients': product.nutriments?.toJson() ?? {},
    };
  }

  static Map<String, dynamic> productToNutritionData(Product product) {
    final nutriments =
        product.nutriments?.toJson() ?? const <String, dynamic>{};
    return {
      'name': (product.productName ?? 'Unknown').trim().isEmpty
          ? 'Unknown'
          : (product.productName ?? 'Unknown').trim(),
      'servingSize': (product.servingSize ?? '100g').trim(),
      'calories': _parseNum(
          nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal']),
      'protein':
          _parseNum(nutriments['proteins_100g'] ?? nutriments['proteins']),
      'carbs': _parseNum(
          nutriments['carbohydrates_100g'] ?? nutriments['carbohydrates']),
      'fat': _parseNum(nutriments['fat_100g'] ?? nutriments['fat']),
      'fiber': _parseNum(nutriments['fiber_100g'] ??
          nutriments['fibres_100g'] ??
          nutriments['fiber']),
      'sodium': _parseNum(nutriments['sodium_100g'] ??
          nutriments['salt_100g'] ??
          nutriments['sodium']),
      'addedSugar':
          _parseNum(nutriments['sugars_100g'] ?? nutriments['sugars']),
    };
  }

  static double _parseNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
