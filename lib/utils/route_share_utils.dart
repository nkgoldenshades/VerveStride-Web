import 'dart:math' as math;

class RouteShareUtils {
  static String buildGoogleMapsRouteUrl(
    List<Map<String, double>> route, {
    int maxWaypoints = 8,
    int maxUrlLength = 1800,
    double simplifyToleranceMeters = 15,
    int simplifyMaxPoints = 120,
  }) {
    if (route.isEmpty) return '';
    if (route.length == 1) {
      final lat = route.first['lat'];
      final lng = route.first['lng'];
      return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    }

    final simplified = _simplifyRoute(
      route,
      toleranceMeters: simplifyToleranceMeters,
      maxPoints: simplifyMaxPoints,
    );

    final origin = '${simplified.first['lat']},${simplified.first['lng']}';
    final destination = '${simplified.last['lat']},${simplified.last['lng']}';

    String buildUrlWithPicked(List<Map<String, double>> pickedInner) {
      var waypoints = '';
      if (pickedInner.isNotEmpty) {
        final waypointList =
            pickedInner.map((p) => '${p['lat']},${p['lng']}').join('|');
        waypoints = '&waypoints=${Uri.encodeComponent(waypointList)}';
      }
      return 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination$waypoints';
    }

    final inner = simplified.length > 2
        ? simplified.sublist(1, simplified.length - 1)
        : const <Map<String, double>>[];

    if (inner.isEmpty) return buildUrlWithPicked(const []);

    final picked = _pickWaypoints(inner, maxWaypoints: maxWaypoints);

    var url = buildUrlWithPicked(picked);

    if (url.length <= maxUrlLength) {
      return url;
    }

    for (var wp = maxWaypoints - 1; wp >= 0; wp--) {
      final reduced = _pickWaypoints(inner, maxWaypoints: wp);
      url = buildUrlWithPicked(reduced);
      if (url.length <= maxUrlLength) {
        return url;
      }
    }

    return buildUrlWithPicked(const []);
  }

  static List<Map<String, double>> _pickWaypoints(
    List<Map<String, double>> inner, {
    required int maxWaypoints,
  }) {
    if (maxWaypoints <= 0) return const [];
    if (inner.length <= maxWaypoints) return List<Map<String, double>>.from(inner);

    final picked = <Map<String, double>>[];
    final step = inner.length / maxWaypoints;
    for (var i = 0; i < maxWaypoints; i++) {
      final idx = (i * step).floor().clamp(0, inner.length - 1);
      picked.add(inner[idx]);
    }
    return picked;
  }

  static List<Map<String, double>> _simplifyRoute(
    List<Map<String, double>> route, {
    required double toleranceMeters,
    required int maxPoints,
  }) {
    final cleaned = route
        .where(
          (p) =>
              p['lat'] != null &&
              p['lng'] != null &&
              p['lat']! >= -90 &&
              p['lat']! <= 90 &&
              p['lng']! >= -180 &&
              p['lng']! <= 180,
        )
        .map((p) => <String, double>{'lat': p['lat']!, 'lng': p['lng']!})
        .toList();

    if (cleaned.length <= 2) return cleaned;

    var simplified = _douglasPeucker(cleaned, toleranceMeters);

    if (simplified.length > maxPoints) {
      simplified = _resampleEvenly(simplified, maxPoints);
    }

    return simplified;
  }

  static List<Map<String, double>> _resampleEvenly(
    List<Map<String, double>> points,
    int maxPoints,
  ) {
    if (maxPoints <= 2) {
      return [points.first, points.last];
    }
    if (points.length <= maxPoints) return points;

    final out = <Map<String, double>>[];
    out.add(points.first);

    final innerCount = maxPoints - 2;
    final inner = points.sublist(1, points.length - 1);
    final step = inner.length / innerCount;
    for (var i = 0; i < innerCount; i++) {
      final idx = (i * step).floor().clamp(0, inner.length - 1);
      out.add(inner[idx]);
    }

    out.add(points.last);
    return out;
  }

  static List<Map<String, double>> _douglasPeucker(
    List<Map<String, double>> points,
    double toleranceMeters,
  ) {
    if (points.length <= 2) return points;

    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    final stack = <List<int>>[
      [0, points.length - 1]
    ];

    while (stack.isNotEmpty) {
      final range = stack.removeLast();
      final start = range[0];
      final end = range[1];

      var maxDist = 0.0;
      var idx = -1;

      for (var i = start + 1; i < end; i++) {
        final d = _perpendicularDistanceMeters(points[i], points[start], points[end]);
        if (d > maxDist) {
          maxDist = d;
          idx = i;
        }
      }

      if (idx != -1 && maxDist > toleranceMeters) {
        keep[idx] = true;
        stack.add([start, idx]);
        stack.add([idx, end]);
      }
    }

    final out = <Map<String, double>>[];
    for (var i = 0; i < points.length; i++) {
      if (keep[i]) out.add(points[i]);
    }
    return out;
  }

  static double _perpendicularDistanceMeters(
    Map<String, double> p,
    Map<String, double> a,
    Map<String, double> b,
  ) {
    final ax = a['lat']!;
    final ay = a['lng']!;
    final bx = b['lat']!;
    final by = b['lng']!;
    final px = p['lat']!;
    final py = p['lng']!;

    final meanLatRad = ((ax + bx + px) / 3.0) * (math.pi / 180.0);
    final mx = 111320.0;
    final my = 111320.0 * math.cos(meanLatRad);

    final axm = ax * mx;
    final aym = ay * my;
    final bxm = bx * mx;
    final bym = by * my;
    final pxm = px * mx;
    final pym = py * my;

    final dx = bxm - axm;
    final dy = bym - aym;

    if (dx == 0.0 && dy == 0.0) {
      final ex = pxm - axm;
      final ey = pym - aym;
      return math.sqrt(ex * ex + ey * ey);
    }

    final t = ((pxm - axm) * dx + (pym - aym) * dy) / (dx * dx + dy * dy);
    final tt = t.clamp(0.0, 1.0);

    final projX = axm + tt * dx;
    final projY = aym + tt * dy;

    final ex = pxm - projX;
    final ey = pym - projY;

    return math.sqrt(ex * ex + ey * ey);
  }
}
