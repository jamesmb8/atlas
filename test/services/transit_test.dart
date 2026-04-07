// test/services/transitrouteservice_test.dart
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atlas/features/transport/transport_api.dart';
import 'package:atlas/services/transitrouteservice.dart';

class FakeTransportApi extends TransportApi {
  final Map<String, dynamic> response;

  FakeTransportApi(this.response)
      : super(
    appId: 'test_app_id',
    appKey: 'test_app_key',
  );

  @override
  Future<Map<String, dynamic>> publicJourney({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    DateTime? dateTime,
    String service = 'traveline',
    bool groupByRoute = true,
    bool showCallingPoints = false,
  }) async {
    return response;
  }
}

void main() {
  group('TransitRouteService', () {
    test('parses mixed bus and train journey with 99 and Northern', () async {
      final service = TransitRouteService(
        transportApi: FakeTransportApi(_sampleJourneyResponse()),
      );

      final result = await service.getPublicTransportSummary(
        destinationName: 'DN3 1DU',
        origin: const LatLng(53.3900, -1.1000),
        destination: const LatLng(53.5200, -1.0000),
        departureTime: DateTime.parse('2025-10-06T16:58:00'),
      );

      expect(result.journeyOptions, isNotEmpty);

      final fastest = result.journeyOptions.first.plan;

      expect(fastest.hasBus, isTrue);
      expect(fastest.hasTrain, isTrue);
      expect(fastest.effectiveDurationMinutes, 80);

      final routeCodes = fastest.legs
          .where((leg) => leg.isTransit)
          .map((leg) => leg.routeCode)
          .whereType<String>()
          .toList();

      expect(routeCodes, contains('99'));
      expect(routeCodes, contains('Northern'));
      expect(result.recommendedMode, PublicTransportMode.train);
    });

    test('sorts by journey duration before departure time', () async {
      final service = TransitRouteService(
        transportApi: FakeTransportApi(_sampleJourneyResponse()),
      );

      final result = await service.getPublicTransportSummary(
        destinationName: 'DN3 1DU',
        origin: const LatLng(53.3900, -1.1000),
        destination: const LatLng(53.5200, -1.0000),
        departureTime: DateTime.parse('2025-10-06T16:58:00'),
      );

      expect(result.journeyOptions.length, greaterThanOrEqualTo(2));
      expect(result.journeyOptions[0].plan.effectiveDurationMinutes, 80);
      expect(result.journeyOptions[1].plan.effectiveDurationMinutes, 89);
      expect(result.journeyOptions[0].tag, 'Quickest');
    });
  });
}

Map<String, dynamic> _sampleJourneyResponse() {
  return {
    'routes': [
      {
        'departure_time': '2025-10-06T16:59:00+01:00',
        'arrival_time': '2025-10-06T18:19:00+01:00',
        'duration': 80,
        'route_parts': [
          {
            'mode': 'walking',
            'distance': 550,
            'duration': 7,
            'from': 'Your location',
            'to_point_name': 'Doncaster Road/Ingham Road',
          },
          {
            'mode': 'bus',
            'line': '99',
            'operator_name': 'First Bus',
            'from_point_name': 'Doncaster Road/Ingham Road',
            'from_atcocode': '370010001',
            'to_point_name': 'Doncaster Interchange',
            'to_atcocode': '370020002',
            'distance': 4200,
            'duration': 10,
          },
          {
            'mode': 'rail',
            'line': 'Northern',
            'operator_name': 'Northern',
            'from_point_name': 'Doncaster',
            'from_station_code': 'DON',
            'to_point_name': 'Hatfield & Stainforth',
            'to_station_code': 'HFS',
            'distance': 21000,
            'duration': 38,
          },
          {
            'mode': 'walking',
            'distance': 1800,
            'duration': 25,
            'from_point_name': 'Hatfield & Stainforth',
            'to': 'DN3 1DU',
          },
        ],
      },
      {
        'departure_time': '2025-10-06T16:58:00+01:00',
        'arrival_time': '2025-10-06T18:27:00+01:00',
        'duration': 89,
        'route_parts': [
          {
            'mode': 'walking',
            'distance': 500,
            'duration': 7,
            'from': 'Your location',
            'to_point_name': 'Doncaster Road/Ingham Road',
          },
          {
            'mode': 'bus',
            'line': '21',
            'operator_name': 'Stagecoach',
            'from_point_name': 'Doncaster Road/Ingham Road',
            'from_atcocode': '370010001',
            'to_point_name': 'Town Centre Stop A',
            'to_atcocode': '370020010',
            'distance': 6000,
            'duration': 32,
          },
          {
            'mode': 'bus',
            'line': '384',
            'operator_name': 'Stagecoach',
            'from_point_name': 'Town Centre Stop A',
            'from_atcocode': '370020010',
            'to_point_name': 'Green Gate',
            'to_atcocode': '370020099',
            'distance': 15000,
            'duration': 46,
          },
          {
            'mode': 'walking',
            'distance': 300,
            'duration': 4,
            'from_point_name': 'Green Gate',
            'to': 'DN3 1DU',
          },
        ],
      },
      {
        'departure_time': '2025-10-06T17:00:00+01:00',
        'arrival_time': '2025-10-06T20:58:00+01:00',
        'duration': {'value': 14280, 'unit': 'seconds'},
        'route_parts': [
          {
            'mode': 'walking',
            'distance': 400,
            'duration': {'value': 300, 'unit': 'seconds'},
            'from': 'Your location',
            'to_point_name': 'Bawtry, Doncaster Road/North Avenue',
          },
          {
            'mode': 'bus',
            'line': '521',
            'operator_name': 'Bus Operator A',
            'from_point_name': 'Bawtry, Doncaster Road/North Avenue',
            'from_atcocode': '370030001',
            'to_point_name': 'Stop 521 End',
            'to_atcocode': '370030002',
            'distance': 9000,
            'duration': {'value': 3900, 'unit': 'seconds'},
          },
          {
            'mode': 'bus',
            'line': '399',
            'operator_name': 'Bus Operator B',
            'from_point_name': 'Stop 521 End',
            'from_atcocode': '370030002',
            'to_point_name': 'Stop 399 End',
            'to_atcocode': '370030003',
            'distance': 11000,
            'duration': {'value': 4200, 'unit': 'seconds'},
          },
          {
            'mode': 'bus',
            'line': '386',
            'operator_name': 'Bus Operator C',
            'from_point_name': 'Stop 399 End',
            'from_atcocode': '370030003',
            'to_point_name': 'Near Green Gate',
            'to_atcocode': '370030004',
            'distance': 8000,
            'duration': {'value': 4800, 'unit': 'seconds'},
          },
          {
            'mode': 'walking',
            'distance': 350,
            'duration': {'value': 180, 'unit': 'seconds'},
            'from_point_name': 'Near Green Gate',
            'to': 'DN3 1DU',
          },
        ],
      },
    ],
  };
}