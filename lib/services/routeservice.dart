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

    final driving = await _appleRouteService.getDrivingRoute(
      origin: origin,
      destination: destination,
    );

    final transport = await _transitRouteService.getPublicTransportSummary(
      destinationName: destinationName,
      origin: origin,
      destination: destination,
    );

    if (transport.hasAnyData) {
      final recommended = transport.recommended;
      final alternative = transport.alternative;

      if (recommended != null) {
        final fare = transport.recommendedFare;
        final isTrain = recommended.mode == PublicTransportMode.train;
        final accessDistance = recommended.accessDistanceMeters ?? 0;
        final lineDistance = recommended.lineDistanceMeters ?? 0;
        final totalDistance =
            recommended.totalJourneyDistanceMeters ?? (accessDistance + lineDistance);
        final from = recommended.fromOrigin!;
        final to = recommended.toDestination!;

        final descriptionLines = <String>[
          isTrain ? 'Recommended rail route' : 'Recommended bus route',
          '',
          'Start access',
          '• Nearest ${isTrain ? 'station' : 'stop'}: ${from.name}',
          '• Walk from start: ${_formatMeters(from.distanceMeters)}',
          '',
          'End access',
          '• Nearest ${isTrain ? 'station' : 'stop'}: ${to.name}',
          '• Walk to destination: ${_formatMeters(to.distanceMeters)}',
          '',
          '${isTrain ? 'Rail' : 'Transit'} segment: ${_formatMeters(lineDistance)}',
          'Access walking total: ${_formatMeters(accessDistance)}',
        ];

        options.add(
          RouteOption(
            mode: 'Public Transport',
            tag: isTrain ? 'Train recommended' : 'Bus recommended',
            durationMinutes: 0,
            distanceMeters: totalDistance,
            estimatedCost: null,
            costText: fare?.formatted,
            co2Kg: _co2Service.publicTransportKg(totalDistance),
            description: descriptionLines.join('\n'),
            source: 'Atlas transport info',
            isFeatured: true,
            sortPriority: 0,
            primaryAction: RouteOptionAction(
              label: isTrain ? 'Tickets' : 'Timetable',
              uri: Uri.parse(from.detailsUrl),
            ),
            secondaryAction: alternative != null
                ? RouteOptionAction(
              label: alternative.mode == PublicTransportMode.train
                  ? 'See train alternative'
                  : 'See bus alternative',
              uri: Uri.parse(alternative.fromOrigin!.detailsUrl),
            )
                : null,
          ),
        );
      }

      if (alternative != null) {
        final fare = transport.alternativeFare;
        final isTrain = alternative.mode == PublicTransportMode.train;
        final accessDistance = alternative.accessDistanceMeters ?? 0;
        final lineDistance = alternative.lineDistanceMeters ?? 0;
        final totalDistance =
            alternative.totalJourneyDistanceMeters ?? (accessDistance + lineDistance);
        final from = alternative.fromOrigin!;
        final to = alternative.toDestination!;

        final descriptionLines = <String>[
          isTrain ? 'Alternative rail route' : 'Alternative bus route',
          'Start → ${from.name}: ${_formatMeters(from.distanceMeters)}',
          'Destination → ${to.name}: ${_formatMeters(to.distanceMeters)}',
          '${isTrain ? 'Rail' : 'Transit'} segment: ${_formatMeters(lineDistance)}',
        ];

        options.add(
          RouteOption(
            mode: 'Public Transport',
            tag: isTrain ? 'Train alternative' : 'Bus alternative',
            durationMinutes: 0,
            distanceMeters: totalDistance,
            estimatedCost: null,
            costText: fare?.formatted,
            co2Kg: _co2Service.publicTransportKg(totalDistance),
            description: descriptionLines.join('\n'),
            source: 'Atlas transport info',
            isFeatured: false,
            sortPriority: 1,
            primaryAction: RouteOptionAction(
              label: isTrain ? 'Tickets' : 'Timetable',
              uri: Uri.parse(from.detailsUrl),
            ),
          ),
        );
      }
    }

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
          sortPriority: 2,
        ),
      );
    }

    if (walking != null) {
      final longWalk = walking.durationMinutes > 30;

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
          sortPriority: longWalk ? 99 : 3,
        ),
      );
    }

    options.sort((a, b) {
      final byPriority = a.sortPriority.compareTo(b.sortPriority);
      if (byPriority != 0) return byPriority;

      if (a.mode == 'Walk' && a.durationMinutes > 30) return 1;
      if (b.mode == 'Walk' && b.durationMinutes > 30) return -1;

      return a.durationMinutes.compareTo(b.durationMinutes);
    });

    return options;
  }

  String _formatMeters(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}