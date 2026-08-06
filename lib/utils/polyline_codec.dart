class PolylineCodec {
  static String encodeRoute(List<Map<String, double>> route) {
    if (route.isEmpty) return '';
    final points = <List<double>>[];
    for (final p in route) {
      final lat = p['lat'];
      final lng = p['lng'];
      if (lat == null || lng == null) continue;
      points.add([lat, lng]);
    }
    return encode(points);
  }

  static List<Map<String, double>> decodeRoute(String polyline) {
    final decoded = decode(polyline);
    return decoded
        .map((p) => <String, double>{'lat': p[0], 'lng': p[1]})
        .toList();
  }

  static String encode(List<List<double>> points) {
    var lastLat = 0;
    var lastLng = 0;
    final buffer = StringBuffer();

    for (final p in points) {
      final lat = (p[0] * 1e5).round();
      final lng = (p[1] * 1e5).round();

      final dLat = lat - lastLat;
      final dLng = lng - lastLng;

      _encodeValue(dLat, buffer);
      _encodeValue(dLng, buffer);

      lastLat = lat;
      lastLng = lng;
    }

    return buffer.toString();
  }

  static List<List<double>> decode(String polyline) {
    final points = <List<double>>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < polyline.length) {
      final dLat = _decodeValue(polyline, refIndex: () => index,
          setIndex: (v) => index = v);
      final dLng = _decodeValue(polyline, refIndex: () => index,
          setIndex: (v) => index = v);

      lat += dLat;
      lng += dLng;

      points.add([lat / 1e5, lng / 1e5]);
    }

    return points;
  }

  static void _encodeValue(int value, StringBuffer buffer) {
    var v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      buffer.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    buffer.writeCharCode(v + 63);
  }

  static int _decodeValue(
    String polyline, {
    required int Function() refIndex,
    required void Function(int) setIndex,
  }) {
    var result = 0;
    var shift = 0;
    var b = 0;
    var index = refIndex();

    while (index < polyline.length) {
      b = polyline.codeUnitAt(index) - 63;
      index++;
      result |= (b & 0x1f) << shift;
      shift += 5;
      if (b < 0x20) break;
    }

    setIndex(index);

    final isNegative = (result & 1) == 1;
    result >>= 1;
    return isNegative ? ~result : result;
  }
}
