import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import '../features/routes/route_option.dart';
import 'applerouteservice.dart';
import 'co2service.dart';
import 'transitrouteservice.dart';

class RouteOptionsService {
  final AppleRouteService _appleRouteService;
  final TransitRouteService _transitRouteService;
  final Co2Service _co2Service;

  const RouteOptionsService({
    AppleRouteService appleRouteService = const AppleRouteService(),
    TransitRouteService transitRouteService = const TransitRouteService(),
    Co2Service co2Service = const Co2Service(),
  })  : _appleRouteService = appleRouteService,
        _transitRouteService = transitRouteService,
        _co2Service = co2Service;

  Future<List<RouteOption>> buildOptions({
    required LatLng? origin,
    required LatLng destination,
  }) async {
    if (origin == null) return const [];

    final options = <RouteOption>[];

    final walking = await _appleRouteService.getWalkingRoute(
      origin: origin,
      destination: destination,
    );

    if (walking != null) {
      options.add(
        RouteOption(
          mode: 'Walk',
          tag: 'Lowest CO₂',
          durationMinutes: walking.durationMinutes,
          distanceMeters: walking.distanceMeters,
          estimatedCost: 0.0,
          co2Kg: _co2Service.walkingKg(walking.distanceMeters),
          description: 'Route data from Apple Maps.',
          source: 'Apple Maps',
        ),
      );
    }

    final driving = await _appleRouteService.getDrivingRoute(
      origin: origin,
      destination: destination,
    );

    if (driving != null) {
      options.add(
        RouteOption(
          mode: 'Drive',
          tag: 'Route-based',
          durationMinutes: driving.durationMinutes,
          distanceMeters: driving.distanceMeters,
          estimatedCost: null,
          co2Kg: _co2Service.drivingKg(driving.distanceMeters),
          description: 'Driving time and distance from Apple Maps.',
          source: 'Apple Maps',
        ),
      );
    }

    final transit = await _transitRouteService.getTransitRoute(
      origin: origin,
      destination: destination,
    );

    if (transit != null) {
      options.add(
        RouteOption(
          mode: 'Public Transport',
          tag: 'Lower CO₂',
          durationMinutes: transit.durationMinutes,
          distanceMeters: transit.distanceMeters,
          estimatedCost: transit.fareGbp,
          co2Kg: _co2Service.publicTransportKg(transit.distanceMeters),
          description: 'Transit data from connected provider.',
          source: 'Transit API',
        ),
      );
    }

    return options;
  }
}