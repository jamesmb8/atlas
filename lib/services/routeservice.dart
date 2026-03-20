// lib/services/routeservice.dart
import 'dart:math' as math;

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

  bool _sameStation(NearbyTrainInfo a, NearbyTrainInfo b) {
    final ac = a.stationCode?.trim();
    final bc = b.stationCode?.trim();
    if (ac != null && bc != null && ac.isNotEmpty && bc.isNotEmpty) {
      return ac.toLowerCase() == bc.toLowerCase();
    }

    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return norm(a.stationName) == norm(b.stationName);
  }

  bool _isUsableStation(NearbyTrainInfo s) {
    // avoids “Nearest station” placeholder / missing coords situations
    if (s.stationName.trim().isEmpty) return false;
    if (s.stationName.toLowerCase() == 'nearest station') return false;
    if (!s.hasCoordinates) return false;
    return true;
  }

  ({double min, double max}) _estimateTrainFareRange(double stationToStationMeters) {
    final km = stationToStationMeters / 1000.0;
    if (km <= 5) return (min: 1.20, max: 4.60);
    if (km <= 20) return (min: 3.50, max: 10.00);
    if (km <= 60) return (min: 6.00, max: 22.00);
    return (min: 10.00, max: 45.00);
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
          costText: '£0.00',
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

    final transport = await _transitRouteService.getPublicTransportSummary(
      destinationName: destinationName,
      origin: origin,
      destination: destination,
    );

    if (!transport.hasAnyData) return options;

    final bus = transport.bus;
    final trainA = transport.trainBetween.fromOrigin;
    final trainB = transport.trainBetween.toDestination;

    final canShowTrain = trainA != null &&
        trainB != null &&
        _isUsableStation(trainA) &&
        _isUsableStation(trainB) &&
        !_sameStation(trainA, trainB);

    if (canShowTrain) {
      final stationToStationMeters = transport.trainBetween.stationsDistanceMeters ?? 0;
      if (stationToStationMeters > 0) {
        final fare = _estimateTrainFareRange(stationToStationMeters);

        final lines = <String>[
          'Start → ${trainA.stationName}: ${trainA.distanceMiles.toStringAsFixed(1)} miles',
          'Destination → ${trainB.stationName}: ${trainB.distanceMiles.toStringAsFixed(1)} miles',
          '${trainA.stationName} → ${trainB.stationName}: ${(stationToStationMeters / 1609.344).toStringAsFixed(1)} miles',
        ];

        options.add(
          RouteOption(
            mode: 'Public Transport',
            tag: 'Train',
            durationMinutes: 0,
            distanceMeters: stationToStationMeters,
            estimatedCost: null,
            costText: '£${fare.min.toStringAsFixed(2)}–£${fare.max.toStringAsFixed(2)}',
            co2Kg: _co2Service.publicTransportKg(stationToStationMeters),
            description: lines.join('\n'),
            source: 'Atlas transport info',
            primaryAction: RouteOptionAction(
              label: 'Tickets',
              uri: Uri.parse(trainA.ticketUrl),
            ),
          ),
        );
      }
    }

    // If we skipped train (same station / invalid), show bus if present
    if (bus != null) {
      options.add(
        RouteOption(
          mode: 'Public Transport',
          tag: 'Bus',
          durationMinutes: 0,
          distanceMeters: bus.distanceMeters,
          estimatedCost: null,
          costText: null, // your UI will show heuristic range for bus
          co2Kg: _co2Service.publicTransportKg(bus.distanceMeters),
          description: 'Destination → ${bus.title}: ${bus.distanceMiles.toStringAsFixed(1)} miles',
          source: 'Atlas transport info',
          secondaryAction: RouteOptionAction(
            label: 'Timetable',
            uri: Uri.parse(bus.timetableUrl),
          ),
        ),
      );
    }

    return options;
  }
}