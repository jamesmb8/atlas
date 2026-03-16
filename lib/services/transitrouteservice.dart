import 'package:apple_maps_flutter/apple_maps_flutter.dart';

class TransitRouteResult {
  final double distanceMeters;
  final int durationMinutes;
  final double? fareGbp;

  const TransitRouteResult({
    required this.distanceMeters,
    required this.durationMinutes,
    required this.fareGbp,
  });
}

class TransitRouteService {
  const TransitRouteService();

  Future<TransitRouteResult?> getTransitRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // TODO:
    // Replace with backend / API call for England public transport
    return null;
  }
}