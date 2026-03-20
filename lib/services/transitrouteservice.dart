// lib/services/transitrouteservice.dart
import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import '../features/transport/transport_api.dart';

const _transportApiAppId = String.fromEnvironment('TRANSPORT_API_APP_ID');
const _transportApiAppKey = String.fromEnvironment('TRANSPORT_API_APP_KEY');

class NearbyTrainInfo {
  final String stationName;
  final double distanceMeters; // distance from queried point -> station
  final String? stationCode;
  final String ticketUrl;
  final LatLng stationLatLng;
  final bool hasCoordinates;


  const NearbyTrainInfo({
    required this.stationName,
    required this.distanceMeters,
    required this.stationLatLng,
    required this.hasCoordinates,
    this.stationCode,
    required this.ticketUrl,
  });

  double get distanceMiles => distanceMeters / 1609.344;
}

class NearbyBusInfo {
  final String title;
  final double distanceMeters;
  final String timetableUrl;

  const NearbyBusInfo({
    required this.title,
    required this.distanceMeters,
    required this.timetableUrl,
  });

  double get distanceMiles => distanceMeters / 1609.344;
}

class TrainBetweenResult {
  final NearbyTrainInfo? fromOrigin;
  final NearbyTrainInfo? toDestination;

  const TrainBetweenResult({
    required this.fromOrigin,
    required this.toDestination,
  });

  bool get hasBoth => fromOrigin != null && toDestination != null;

  double? get stationsDistanceMeters {
    final a = fromOrigin?.stationLatLng;
    final b = toDestination?.stationLatLng;
    if (a == null || b == null) return null;
    return _haversineMeters(a, b);
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return r * c;
  }

  static double _degToRad(double d) => d * (math.pi / 180.0);
}

class PublicTransportResult {
  final TrainBetweenResult trainBetween;
  final NearbyBusInfo? bus;

  const PublicTransportResult({
    required this.trainBetween,
    required this.bus,
  });

  bool get hasAnyData => trainBetween.fromOrigin != null || trainBetween.toDestination != null || bus != null;
}

class TransitRouteService {
  final TransportApi _transportApi;

  TransitRouteService({TransportApi? transportApi})
      : _transportApi = transportApi ??
      TransportApi(
        appId: _transportApiAppId,
        appKey: _transportApiAppKey,
      );

  Future<PublicTransportResult> getPublicTransportSummary({
    required String destinationName,
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final trainBetween = await _getTrainBetween(
        destinationName: destinationName,
        origin: origin,
        destination: destination,
      );

      final bus = await _getNearbyBus(
        destinationName: destinationName,
        destination: destination,
      );

      return PublicTransportResult(
        trainBetween: trainBetween,
        bus: bus,
      );
    } catch (e) {
      // ignore: avoid_print
      print('TransitRouteService error: $e');

      // Safe fallback
      return PublicTransportResult(
        trainBetween: TrainBetweenResult(
          fromOrigin: NearbyTrainInfo(
            stationName: 'Nearest station',
            distanceMeters: 1200,
            stationLatLng: origin,
            hasCoordinates: false,

            stationCode: null,
            ticketUrl: _buildTrainTicketUrl('Nearest station'),
          ),
          toDestination: NearbyTrainInfo(
            stationName: '$destinationName Station',
            distanceMeters: 1200,
            stationLatLng: destination,
            hasCoordinates: false,
            stationCode: null,
            ticketUrl: _buildTrainTicketUrl('$destinationName Station'),
          ),
        ),
        bus: NearbyBusInfo(
          title: 'Bus journeys nearby',
          distanceMeters: 350,
          timetableUrl: _buildBusTimetableUrl(destinationName),
        ),
      );
    }
  }

  Future<TrainBetweenResult> _getTrainBetween({
    required String destinationName,
    required LatLng origin,
    required LatLng destination,
  }) async {
    final fromOrigin = await _getNearestTrain(
      destinationName: destinationName,
      point: origin,
    );

    final toDestination = await _getNearestTrain(
      destinationName: destinationName,
      point: destination,
    );

    return TrainBetweenResult(fromOrigin: fromOrigin, toDestination: toDestination);
  }

  Future<NearbyTrainInfo?> _getNearestTrain({
    required String destinationName,
    required LatLng point,
  }) async {
    final data = await _transportApi.searchNearbyPlaces(
      latitude: point.latitude,
      longitude: point.longitude,
      type: 'train_station',
      maxResults: 1,
    );

    final member = _extractFirstPlace(data);
    if (member == null) return null;

    final name =
    (member['name'] ?? member['station_name'] ?? '$destinationName Station')
        .toString();

    final stationCode = member['station_code']?.toString();
    final distanceMeters = _readDistanceMeters(member) ?? 0;

    final lat = _readDouble(member, ['latitude', 'lat', 'y']);
    final lon = _readDouble(member, ['longitude', 'lon', 'lng', 'x']);
    final hasCoords = lat != null && lon != null;

    return NearbyTrainInfo(
      stationName: name,
      distanceMeters: distanceMeters,
      stationLatLng: hasCoords ? LatLng(lat!, lon!) : point,
      hasCoordinates: hasCoords,
      stationCode: stationCode,
      ticketUrl: _buildTrainTicketUrl(name),
    );
  }

  Future<NearbyBusInfo?> _getNearbyBus({
    required String destinationName,
    required LatLng destination,
  }) async {
    final data = await _transportApi.searchNearbyPlaces(
      latitude: destination.latitude,
      longitude: destination.longitude,
      type: 'bus_stop',
      maxResults: 1,
    );

    final member = _extractFirstPlace(data);
    if (member == null) return null;

    final stopName = (member['name'] ?? member['description'] ?? 'Bus journeys nearby').toString();
    final distanceMeters = _readDistanceMeters(member) ?? 0;

    return NearbyBusInfo(
      title: stopName.isEmpty ? 'Bus journeys nearby' : stopName,
      distanceMeters: distanceMeters,
      timetableUrl: _buildBusTimetableUrl(stopName.isEmpty ? destinationName : stopName),
    );
  }

  Map<String, dynamic>? _extractFirstPlace(Map<String, dynamic> data) {
    final members = data['member'];
    if (members is List && members.isNotEmpty && members.first is Map<String, dynamic>) {
      return members.first as Map<String, dynamic>;
    }

    final results = data['results'];
    if (results is List && results.isNotEmpty && results.first is Map<String, dynamic>) {
      return results.first as Map<String, dynamic>;
    }

    return null;
  }

  double? _readDistanceMeters(Map<String, dynamic> item) {
    final raw = item['distance'] ?? item['distance_meters'] ?? item['dist'];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  double? _readDouble(Map<String, dynamic> item, List<String> keys) {
    for (final k in keys) {
      final v = item[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String _buildTrainTicketUrl(String stationName) {
    final encoded = Uri.encodeComponent(stationName);
    return 'https://www.thetrainline.com/search?searchTerm=$encoded';
  }

  String _buildBusTimetableUrl(String placeName) {
    final encoded = Uri.encodeComponent(placeName);
    return 'https://www.google.com/search?q=bus+timetable+$encoded';
  }
}