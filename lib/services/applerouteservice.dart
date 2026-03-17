import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/services.dart';

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

  static const MethodChannel _channel =
  MethodChannel('com.james.atlas/apple_route');

  Future<AppleRouteResult?> getWalkingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return _getRoute(
      origin: origin,
      destination: destination,
      transportType: 'walking',
    );
  }

  Future<AppleRouteResult?> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return _getRoute(
      origin: origin,
      destination: destination,
      transportType: 'driving',
    );
  }

  Future<AppleRouteResult?> _getRoute({
    required LatLng origin,
    required LatLng destination,
    required String transportType,
  }) async {
    try {
      final result = await _channel.invokeMethod<dynamic>('getRoute', {
        'originLat': origin.latitude,
        'originLng': origin.longitude,
        'destinationLat': destination.latitude,
        'destinationLng': destination.longitude,
        'transportType': transportType,
      });

      if (result == null) return null;

      final map = Map<dynamic, dynamic>.from(result as Map);

      return AppleRouteResult(
        distanceMeters: (map['distanceMeters'] as num).toDouble(),
        durationMinutes: (map['durationMinutes'] as num).toInt(),
      );
    } on PlatformException catch (e) {
      print('Apple route platform error: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      print('Apple route unknown error: $e');
      return null;
    }
  }
}