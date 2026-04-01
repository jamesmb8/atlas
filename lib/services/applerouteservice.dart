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
  MethodChannel('atlas/mapkit_directions');

  Future<AppleRouteResult?> getWalkingRoute({
    required LatLng origin,
    required LatLng destination,
  }) {
    return _getRoute(
      origin: origin,
      destination: destination,
      transport: 'walking',
    );
  }

  Future<AppleRouteResult?> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) {
    return _getRoute(
      origin: origin,
      destination: destination,
      transport: 'automobile',
    );
  }

  Future<AppleRouteResult?> _getRoute({
    required LatLng origin,
    required LatLng destination,
    required String transport,
  }) async {
    try {
      final result = await _channel.invokeMethod<dynamic>('summary', {
        'originLat': origin.latitude,
        'originLng': origin.longitude,
        'destLat': destination.latitude,
        'destLng': destination.longitude,
        'transport': transport,
      });

      if (result == null) {
        return null;
      }

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