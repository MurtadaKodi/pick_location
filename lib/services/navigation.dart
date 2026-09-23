import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NavigationService {
  static double calculateBearingBetweenPoints(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final deltaLon = (to.longitude - from.longitude) * math.pi / 180;

    final y = math.sin(deltaLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);

    final angle = math.atan2(y, x) * 180 / math.pi;
    return (angle + 360) % 360;
  }

  static List<LatLng> buildDirectRoute(LatLng from, LatLng to) {
    return [from, to];
  }

  static List<LatLng> parseRouteGeometry(Map<String, dynamic> payload) {
    final routes = payload['routes'];
    if (routes is! List || routes.isEmpty) {
      return const [];
    }

    final geometry = routes.first['geometry'];
    if (geometry is! Map<String, dynamic>) {
      return const [];
    }

    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.isEmpty) {
      return const [];
    }

    final points = <LatLng>[];
    for (final item in coordinates) {
      if (item is! List || item.length < 2) {
        continue;
      }

      final longitude = (item[0] as num?)?.toDouble();
      final latitude = (item[1] as num?)?.toDouble();
      if (longitude == null || latitude == null) {
        continue;
      }

      points.add(LatLng(latitude, longitude));
    }

    return points;
  }

  static Future<List<LatLng>> fetchRoadRoute(LatLng from, LatLng to) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?geometries=geojson&overview=full&alternatives=false',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return buildDirectRoute(from, to);
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return buildDirectRoute(from, to);
      }

      final points = parseRouteGeometry(decoded);
      return points.isEmpty ? buildDirectRoute(from, to) : points;
    } catch (_) {
      return buildDirectRoute(from, to);
    }
  }
}
