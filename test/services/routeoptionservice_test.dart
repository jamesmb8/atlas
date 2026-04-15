// test/services/routeoptionservice_test.dart

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas/features/routes/route_option.dart';
import 'package:atlas/services/applerouteservice.dart';
import 'package:atlas/services/routeservice.dart';
import 'package:atlas/services/transitrouteservice.dart';

import 'routeoptionservice_test.dart';


typedef TestAppleRoute = AppleRouteResult;

void main() {
  group('RouteOptionsService', () {
    test(
      'returns empty options and null public transport result when origin is null',
          () async {
        final service = RouteOptionsService();

        final result = await service.buildOptions(
          origin: null,
          destination: const LatLng(53.5, -1.0),
          destinationName: 'Test destination',
        );

        expect(result.options, isEmpty);
        expect(result.publicTransportResult, isNull);
      },
    );

    test(
      'builds drive and walk options when Apple routes are available and transit is empty',
          () async {
        final service = RouteOptionsService(
          appleRouteService: FakeAppleRouteService(
            walkingRoute: const FakeAppleRoute(
              durationMinutes: 18,
              distanceMeters: 1400,
            ),
            drivingRoute: const FakeAppleRoute(
              durationMinutes: 6,
              distanceMeters: 3200,
            ),
          ),
          transitRouteService: FakeTransitRouteService.empty(),
        );

        final result = await service.buildOptions(
          origin: const LatLng(53.39, -1.10),
          destination: const LatLng(53.52, -1.00),
          destinationName: 'Doncaster',
        );

        expect(result.options.length, 2);

        final drive = _optionByMode(result.options, 'Drive');
        final walk = _optionByMode(result.options, 'Walk');

        expect(drive.durationMinutes, 6);
        expect(drive.distanceMeters, 3200);
        expect(drive.source, 'Apple Maps');
        expect(drive.co2Kg, 0.52);

        expect(walk.durationMinutes, 18);
        expect(walk.distanceMeters, 1400);
        expect(walk.costText, '£0.00');
        expect(walk.co2Kg, 0.0);
      },
    );

    test(
      'returns only drive and walk when no public transport is recommended',
          () async {
        final service = RouteOptionsService(
          appleRouteService: FakeAppleRouteService(
            walkingRoute: const FakeAppleRoute(
              durationMinutes: 12,
              distanceMeters: 900,
            ),
            drivingRoute: const FakeAppleRoute(
              durationMinutes: 4,
              distanceMeters: 2100,
            ),
          ),
          transitRouteService: FakeTransitRouteService.empty(),
        );

        final result = await service.buildOptions(
          origin: const LatLng(53.39, -1.10),
          destination: const LatLng(53.52, -1.00),
          destinationName: 'Test',
        );

        expect(
          result.options.where((o) => o.mode == 'Public Transport'),
          isEmpty,
        );
        expect(result.options.any((o) => o.mode == 'Drive'), isTrue);
        expect(result.options.any((o) => o.mode == 'Walk'), isTrue);
      },
    );

    test(
      'pushes long walk to the bottom of the results',
          () async {
        final service = RouteOptionsService(
          appleRouteService: FakeAppleRouteService(
            walkingRoute: const FakeAppleRoute(
              durationMinutes: 45,
              distanceMeters: 3600,
            ),
            drivingRoute: const FakeAppleRoute(
              durationMinutes: 8,
              distanceMeters: 3000,
            ),
          ),
          transitRouteService: FakeTransitRouteService.empty(),
        );

        final result = await service.buildOptions(
          origin: const LatLng(53.39, -1.10),
          destination: const LatLng(53.52, -1.00),
          destinationName: 'Test',
        );

        expect(result.options.last.mode, 'Walk');
        expect(result.options.last.sortPriority, 99);
      },
    );

    test(
      'builds featured bus public transport option with Timetable action',
          () async {
        final recommended = FakeTransitPairResult(
          mode: PublicTransportMode.bus,
          fromOrigin: _busPoint(),
          toDestination: _destinationPoint(),
          totalJourneyDistanceMeters: 6200,
          accessDistanceMeters: 400,
        );

        final transportResult = FakePublicTransportResult(
          recommended: recommended,
          recommendedMode: PublicTransportMode.bus,
        );

        final service = RouteOptionsService(
          appleRouteService: FakeAppleRouteService(
            walkingRoute: const FakeAppleRoute(
              durationMinutes: 20,
              distanceMeters: 1600,
            ),
            drivingRoute: const FakeAppleRoute(
              durationMinutes: 7,
              distanceMeters: 3100,
            ),
          ),
          transitRouteService: FakeTransitRouteService(transportResult),
        );

        final result = await service.buildOptions(
          origin: const LatLng(53.39, -1.10),
          destination: const LatLng(53.52, -1.00),
          destinationName: 'Test',
        );

        final publicTransport = _optionByMode(result.options, 'Public Transport');

        expect(publicTransport.isFeatured, isTrue);
        expect(publicTransport.tag, 'Bus recommended');
        expect(publicTransport.primaryAction?.label, 'Timetable');
        expect(
          publicTransport.primaryAction?.uri.toString(),
          'https://example.com/bus',
        );
        expect(publicTransport.co2Kg, 0.22);
      },
    );

    test(
      'builds featured train public transport option with Tickets action',
          () async {
        final recommended = FakeTransitPairResult(
          mode: PublicTransportMode.train,
          fromOrigin: _trainPoint(),
          toDestination: _destinationPoint(),
          totalJourneyDistanceMeters: 12000,
          accessDistanceMeters: 500,
        );

        final transportResult = FakePublicTransportResult(
          recommended: recommended,
          recommendedMode: PublicTransportMode.train,
        );

        final service = RouteOptionsService(
          appleRouteService: FakeAppleRouteService(
            walkingRoute: const FakeAppleRoute(
              durationMinutes: 22,
              distanceMeters: 1700,
            ),
            drivingRoute: const FakeAppleRoute(
              durationMinutes: 9,
              distanceMeters: 4000,
            ),
          ),
          transitRouteService: FakeTransitRouteService(transportResult),
        );

        final result = await service.buildOptions(
          origin: const LatLng(53.39, -1.10),
          destination: const LatLng(53.52, -1.00),
          destinationName: 'Test',
        );

        final publicTransport = _optionByMode(result.options, 'Public Transport');

        expect(publicTransport.isFeatured, isTrue);
        expect(publicTransport.tag, 'Train recommended');
        expect(publicTransport.primaryAction?.label, 'Tickets');
        expect(
          publicTransport.primaryAction?.uri.toString(),
          'https://example.com/train',
        );
        expect(publicTransport.co2Kg, 0.42);
      },
    );

    test(
      'sorts recommended transit, alternative transit, drive, then walk',
          () async {
        final recommended = FakeTransitPairResult(
          mode: PublicTransportMode.train,
          fromOrigin: _trainPoint(),
          toDestination: _destinationPoint(),
          totalJourneyDistanceMeters: 10000,
        );

        final alternative = FakeTransitPairResult(
          mode: PublicTransportMode.bus,
          fromOrigin: _busPoint(),
          toDestination: _destinationPoint(),
          totalJourneyDistanceMeters: 7000,
        );

        final transportResult = FakePublicTransportResult(
          recommended: recommended,
          alternative: alternative,
          recommendedMode: PublicTransportMode.train,
        );

        final service = RouteOptionsService(
          appleRouteService: FakeAppleRouteService(
            walkingRoute: const FakeAppleRoute(
              durationMinutes: 15,
              distanceMeters: 1100,
            ),
            drivingRoute: const FakeAppleRoute(
              durationMinutes: 5,
              distanceMeters: 2800,
            ),
          ),
          transitRouteService: FakeTransitRouteService(transportResult),
        );

        final result = await service.buildOptions(
          origin: const LatLng(53.39, -1.10),
          destination: const LatLng(53.52, -1.00),
          destinationName: 'Test',
        );

        expect(result.options[0].mode, 'Public Transport');
        expect(result.options[0].tag, 'Train recommended');

        expect(result.options[1].mode, 'Public Transport');
        expect(result.options[1].tag, 'Bus alternative');

        expect(result.options[2].mode, 'Drive');
        expect(result.options[3].mode, 'Walk');
      },
    );

    test(
      'builds alternative public transport option when alternative exists',
          () async {
        final recommended = FakeTransitPairResult(
          mode: PublicTransportMode.bus,
          fromOrigin: _busPoint(),
          toDestination: _destinationPoint(),
          totalJourneyDistanceMeters: 6500,
        );

        final alternative = FakeTransitPairResult(
          mode: PublicTransportMode.train,
          fromOrigin: _trainPoint(),
          toDestination: _destinationPoint(),
          totalJourneyDistanceMeters: 11000,
        );

        final transportResult = FakePublicTransportResult(
          recommended: recommended,
          alternative: alternative,
          recommendedMode: PublicTransportMode.bus,
        );

        final service = RouteOptionsService(
          appleRouteService: FakeAppleRouteService(
            walkingRoute: const FakeAppleRoute(
              durationMinutes: 16,
              distanceMeters: 1200,
            ),
            drivingRoute: const FakeAppleRoute(
              durationMinutes: 6,
              distanceMeters: 3000,
            ),
          ),
          transitRouteService: FakeTransitRouteService(transportResult),
        );

        final result = await service.buildOptions(
          origin: const LatLng(53.39, -1.10),
          destination: const LatLng(53.52, -1.00),
          destinationName: 'Test',
        );

        final ptOptions = result.options
            .where((o) => o.mode == 'Public Transport')
            .toList();

        expect(ptOptions.length, 2);
        expect(ptOptions[0].tag, 'Bus recommended');
        expect(ptOptions[1].tag, 'Train alternative');
        expect(ptOptions[1].isFeatured, isFalse);
        expect(ptOptions[1].primaryAction?.label, 'Tickets');
      },
    );
  });
}

RouteOption _optionByMode(List<RouteOption> options, String mode) {
  return options.firstWhere((option) => option.mode == mode);
}

class FakeAppleRoute implements TestAppleRoute {
  @override
  final int durationMinutes;

  @override
  final double distanceMeters;

  const FakeAppleRoute({
    required this.durationMinutes,
    required this.distanceMeters,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAppleRouteService implements AppleRouteService {
  final TestAppleRoute? walkingRoute;
  final TestAppleRoute? drivingRoute;

  FakeAppleRouteService({
    this.walkingRoute,
    this.drivingRoute,
  });

  @override
  Future<TestAppleRoute?> getWalkingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return walkingRoute;
  }

  @override
  Future<TestAppleRoute?> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return drivingRoute;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTransitRouteService implements TransitRouteService {
  final PublicTransportResult result;

  FakeTransitRouteService(this.result);

  factory FakeTransitRouteService.empty() {
    return FakeTransitRouteService(const FakePublicTransportResult());
  }

  @override
  Future<PublicTransportResult> getPublicTransportSummary({
    required String destinationName,
    required LatLng origin,
    required LatLng destination,
    DateTime? departureTime,
  }) async {
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePublicTransportResult implements PublicTransportResult {
  @override
  final TransitPairResult? recommended;

  @override
  final TransitPairResult? alternative;

  @override
  final PublicTransportMode? recommendedMode;

  const FakePublicTransportResult({
    this.recommended,
    this.alternative,
    this.recommendedMode,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTransitPairResult implements TransitPairResult {
  @override
  final PublicTransportMode mode;

  @override
  final TransitAccessPoint? fromOrigin;

  @override
  final TransitAccessPoint? toDestination;

  @override
  final double? totalJourneyDistanceMeters;

  @override
  final double? accessDistanceMeters;

  const FakeTransitPairResult({
    required this.mode,
    required this.fromOrigin,
    required this.toDestination,
    this.totalJourneyDistanceMeters,
    this.accessDistanceMeters,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TransitAccessPoint _busPoint() {
  return const TransitAccessPoint(
    name: 'Bus stop A',
    distanceMeters: 400,
    latLng: LatLng(53.3901, -1.1001),
    hasCoordinates: true,
    detailsUrl: 'https://example.com/bus',
    mode: PublicTransportMode.bus,
    isReal: true,
    code: '370010001',
    servedLines: ['21'],
  );
}

TransitAccessPoint _trainPoint() {
  return const TransitAccessPoint(
    name: 'Doncaster',
    distanceMeters: 500,
    latLng: LatLng(53.5228, -1.1398),
    hasCoordinates: true,
    detailsUrl: 'https://example.com/train',
    mode: PublicTransportMode.train,
    isReal: true,
    code: 'DON',
    servedLines: ['Northern'],
  );
}

TransitAccessPoint _destinationPoint() {
  return const TransitAccessPoint(
    name: 'Destination stop',
    distanceMeters: 300,
    latLng: LatLng(53.5200, -1.0000),
    hasCoordinates: true,
    detailsUrl: 'https://example.com/destination',
    mode: PublicTransportMode.bus,
    isReal: true,
    code: 'DST',
    servedLines: ['99'],
  );
}