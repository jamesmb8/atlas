// lib/services/routeservice.dart
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import '../features/routes/route_option.dart';
import 'applerouteservice.dart';
import 'co2service.dart';
import 'transitrouteservice.dart';

class RouteOptionsService {
  final AppleRouteService _appleRouteService;
  final TransitRouteService _transitRouteService;
  final Co2Service _co2Service;

  RouteOptionsService({
    AppleRouteService? appleRouteService,
    TransitRouteService? transitRouteService,
    Co2Service? co2Service,
  })  : _appleRouteService = appleRouteService ?? const AppleRouteService(),
        _transitRouteService = transitRouteService ?? TransitRouteService(),
        _co2Service = co2Service ?? const Co2Service();

  Uri _appleMapsDirectionsUrl({
    required LatLng origin,
    required LatLng destination,
    required String modeFlag, // 'w' walking, 'd' driving
  }) {
    return Uri.parse(
      'http://maps.apple.com/?'
          'saddr=${origin.latitude},${origin.longitude}'
          '&daddr=${destination.latitude},${destination.longitude}'
          '&dirflg=$modeFlag',
    );
  }

  Future<List<RouteOption>> buildOptions({
    required LatLng? origin,
    required LatLng destination,
    required String destinationName,
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
          primaryAction: RouteOptionAction(
            label: 'Open in Maps',
            uri: _appleMapsDirectionsUrl(
              origin: origin,
              destination: destination,
              modeFlag: 'w',
            ),
          ),
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
          primaryAction: RouteOptionAction(
            label: 'Open in Maps',
            uri: _appleMapsDirectionsUrl(
              origin: origin,
              destination: destination,
              modeFlag: 'd',
            ),
          ),
        ),
      );
    }

    final transport = await _transitRouteService.getPublicTransportSummary(
      destinationName: destinationName,
      destination: destination,
    );

    if (transport.hasAnyData) {
      final train = transport.train;
      final bus = transport.bus;

      final lines = <String>[];

      RouteOptionAction? primary;
      RouteOptionAction? secondary;

      if (train != null) {
        lines.add(
          'Train station: ${train.stationName} '
              '(${train.distanceMiles.toStringAsFixed(1)} miles away)',
        );
        primary = RouteOptionAction(
          label: 'Tickets',
          uri: Uri.parse(train.ticketUrl),
        );
      }

      if (bus != null) {
        lines.add(
          'Bus stop: ${bus.title} '
              '(${bus.distanceMiles.toStringAsFixed(1)} miles away)',
        );
        secondary = RouteOptionAction(
          label: 'Timetable',
          uri: Uri.parse(bus.timetableUrl),
        );
      }

      final transportDistanceMeters =
          train?.distanceMeters ?? bus?.distanceMeters ?? 0;

      options.add(
        RouteOption(
          mode: 'Public Transport',
          tag: 'Nearby',
          durationMinutes: 0,
          distanceMeters: transportDistanceMeters,
          estimatedCost: null,
          co2Kg: _co2Service.publicTransportKg(transportDistanceMeters),
          description: lines.join('\n'),
          source: 'Atlas transport info',
          primaryAction: primary,
          secondaryAction: secondary,
        ),
      );
    }

    return options;
  }
}