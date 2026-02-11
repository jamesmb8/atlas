import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/services.dart';

class MapKitDirections {
  static const _channel = MethodChannel('atlas/mapkit_directions');

  static Future<List<LatLng>> route({
    required LatLng origin,
    required LatLng destination,
    String transport = 'walking', // 'walking' or 'automobile'
  }) async {
    final res = await _channel.invokeMethod<List<dynamic>>('route', {
      'originLat': origin.latitude,
      'originLng': origin.longitude,
      'destLat': destination.latitude,
      'destLng': destination.longitude,
      'transport': transport,
    });

    final list = (res ?? const [])
        .cast<Map<dynamic, dynamic>>()
        .map((m) => LatLng(
      (m['lat'] as num).toDouble(),
      (m['lng'] as num).toDouble(),
    ))
        .toList();

    return list;
  }
}
