import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  // Cache to avoid repeated API calls for same coordinates
  final Map<String, String> _cache = {};

  /// Convert lat/lng to a readable location name
  /// Returns a formatted address or "Unknown Location" if geocoding fails
  Future<String> getLocationName(double latitude, double longitude) async {
    if (kIsWeb) {
      return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    }

    final key = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    
    // Check cache first
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isEmpty) {
        return 'Unknown Location';
      }

      final place = placemarks.first;
      final parts = <String>[];

      // Build a readable address from available components
      if (place.name != null && place.name!.isNotEmpty) {
        parts.add(place.name!);
      }
      if (place.locality != null && place.locality!.isNotEmpty) {
        parts.add(place.locality!);
      }
      if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
        parts.add(place.administrativeArea!);
      }
      if (place.country != null && place.country!.isNotEmpty) {
        parts.add(place.country!);
      }

      final locationName = parts.isEmpty 
          ? 'Unknown Location' 
          : parts.take(2).join(', '); // Use first 2 parts for brevity

      // Cache the result
      _cache[key] = locationName;
      return locationName;
    } catch (e) {
      // Geocoding failed, return coordinates as fallback
      return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    }
  }

  /// Get a short location name (just city/area)
  Future<String> getShortLocationName(double latitude, double longitude) async {
    if (kIsWeb) return 'Unknown';

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isEmpty) {
        return 'Unknown';
      }

      final place = placemarks.first;
      
      // Prefer locality (city), then administrative area (state), then country
      if (place.locality != null && place.locality!.isNotEmpty) {
        return place.locality!;
      }
      if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
        return place.administrativeArea!;
      }
      if (place.country != null && place.country!.isNotEmpty) {
        return place.country!;
      }

      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Clear the cache (useful if memory is a concern)
  void clearCache() {
    _cache.clear();
  }
}
