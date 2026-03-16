import 'package:apple_maps_flutter/apple_maps_flutter.dart';

class AppleRouteResult {
  final double distanceMeters;
  final int durationMinutes;

  const AppleRouteResult({
    required this.distanceMeters,
    required this.durationMinutes,
  });
}

class AppleRouteService {
  const AppleRouteService();

  Future<AppleRouteResult?> getWalkingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // TODO:
    // Replace with real Apple / MapKit route call that returns:
    // - route distance
    // - expected travel time
    return null;
  }

  Future<AppleRouteResult?> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // TODO:
    // Replace with real Apple / MapKit route call that returns:
    // - route distance
    // - expected travel time
    return null;
  }
}