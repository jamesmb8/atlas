// lib/services/routeoptionsservice.dart
// Replace only the transit duration/tag parts inside buildOptions.

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

    print(
      'Transport summary => '
          'bus:${transport.bus != null}, '
          'train:${transport.train != null}, '
          'recommended:${transport.recommendedMode}, '
          'journeyOptions:${transport.journeyOptions.length}, '
          'debug:${transport.debugReason}',
    );

    final recommended = transport.recommended;
    final alternative = transport.alternative;

    if (recommended != null) {
      final fare = transport.recommendedFare;
      final plan = recommended.journeyPlan;
      final isMixed = plan?.hasBus == true && plan?.hasTrain == true;
      final isTrainOnly = recommended.mode == PublicTransportMode.train && !isMixed;
      final totalDistance =
          recommended.totalJourneyDistanceMeters ??
              (recommended.accessDistanceMeters ?? 0);

      options.add(
        RouteOption(
          mode: 'Public Transport',
          tag: isMixed
              ? 'Bus + train'
              : isTrainOnly
              ? 'Train recommended'
              : 'Bus recommended',
          durationMinutes: plan?.effectiveDurationMinutes ?? 0,
          distanceMeters: totalDistance,
          estimatedCost: null,
          costText: fare?.formatted,
          co2Kg: _co2Service.publicTransportKg(totalDistance),
          description: _buildTransitDescription(
            pair: recommended,
            title: isMixed
                ? 'Recommended mixed transit route'
                : isTrainOnly
                ? 'Recommended rail route'
                : 'Recommended bus route',
          ),
          source: 'Atlas transport info',
          isFeatured: true,
          sortPriority: 0,
          primaryAction: RouteOptionAction(
            label: isTrainOnly || isMixed ? 'Tickets' : 'Timetable',
            uri: Uri.parse(recommended.fromOrigin!.detailsUrl),
          ),
          secondaryAction: alternative != null
              ? RouteOptionAction(
            label: ((alternative.journeyPlan?.hasBus == true &&
                alternative.journeyPlan?.hasTrain == true) ||
                alternative.mode == PublicTransportMode.train)
                ? 'See rail alternative'
                : 'See bus alternative',
            uri: Uri.parse(alternative.fromOrigin!.detailsUrl),
          )
              : null,
        ),
      );
    }

    if (alternative != null) {
      final fare = transport.alternativeFare;
      final plan = alternative.journeyPlan;
      final isMixed = plan?.hasBus == true && plan?.hasTrain == true;
      final isTrainOnly = alternative.mode == PublicTransportMode.train && !isMixed;
      final totalDistance =
          alternative.totalJourneyDistanceMeters ??
              (alternative.accessDistanceMeters ?? 0);

      options.add(
        RouteOption(
          mode: 'Public Transport',
          tag: isMixed
              ? 'Bus + train alternative'
              : isTrainOnly
              ? 'Train alternative'
              : 'Bus alternative',
          durationMinutes: plan?.effectiveDurationMinutes ?? 0,
          distanceMeters: totalDistance,
          estimatedCost: null,
          costText: fare?.formatted,
          co2Kg: _co2Service.publicTransportKg(totalDistance),
          description: _buildTransitDescription(
            pair: alternative,
            title: isMixed
                ? 'Alternative mixed transit route'
                : isTrainOnly
                ? 'Alternative rail route'
                : 'Alternative bus route',
          ),
          source: 'Atlas transport info',
          isFeatured: false,
          sortPriority: 1,
          primaryAction: RouteOptionAction(
            label: isTrainOnly || isMixed ? 'Tickets' : 'Timetable',
            uri: Uri.parse(alternative.fromOrigin!.detailsUrl),
          ),
        ),
      );
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

  String _buildTransitDescription({
    required TransitPairResult pair,
    required String title,
  }) {
    final plan = pair.journeyPlan;
    final isTrain = pair.mode == PublicTransportMode.train;
    final lines = <String>[title];

    if (plan != null && plan.hasLegs) {
      lines.add('');
      lines.add(plan.compactSummary);
      lines.add('');

      for (final leg in plan.legs) {
        switch (leg.type) {
          case TransitLegType.walk:
            lines.add('• Walk ${_formatMeters(leg.distanceMeters)}');
            break;
          case TransitLegType.bus:
          case TransitLegType.train:
            final from = _stopDisplay(leg.fromStopName, leg.fromStopCode);
            final to = _stopDisplay(leg.toStopName, leg.toStopCode);
            if (from.isNotEmpty && to.isNotEmpty) {
              lines.add('• ${leg.label}: $from → $to');
            } else {
              lines.add('• ${leg.label}');
            }
            break;
        }
      }

      lines.add('');
      lines.add('Walking total: ${_formatMeters(plan.totalWalkingDistanceMeters)}');
      lines.add('${isTrain ? 'Rail' : 'Transit'} total: ${_formatMeters(plan.totalTransitDistanceMeters)}');
      return lines.join('\n');
    }

    final from = pair.fromOrigin;
    final to = pair.toDestination;

    if (from != null) {
      lines.add('');
      lines.add('• Board at: ${from.displayNameWithCode}');
      lines.add('• Walk to start: ${_formatMeters(from.distanceMeters)}');
    }

    if (to != null) {
      lines.add('• Get off at: ${to.displayNameWithCode}');
      lines.add('• Walk to destination: ${_formatMeters(to.distanceMeters)}');
    }

    return lines.join('\n');
  }

  String _stopDisplay(String? name, String? code) {
    final n = (name ?? '').trim();
    final c = (code ?? '').trim();
    if (n.isEmpty) return '';
    if (c.isEmpty) return n;
    return '$n ($c)';
  }

  String _formatMeters(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.toStringAsFixed(0)} m';
  }
}