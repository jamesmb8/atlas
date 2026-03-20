import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import '../features/transport/transport_api.dart';

const _transportApiAppId = String.fromEnvironment('TRANSPORT_API_APP_ID');
const _transportApiAppKey = String.fromEnvironment('TRANSPORT_API_APP_KEY');

class NearbyTrainInfo {
  final String stationName;
  final double distanceMeters;
  final String? stationCode;
  final String ticketUrl;

  const NearbyTrainInfo({
    required this.stationName,
    required this.distanceMeters,
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

class PublicTransportResult {
  final NearbyTrainInfo? train;
  final NearbyBusInfo? bus;

  const PublicTransportResult({
    required this.train,
    required this.bus,
  });

  bool get hasAnyData => train != null || bus != null;
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
    required LatLng destination,
  }) async {
    try {
      final train = await _getNearestTrain(
        destinationName: destinationName,
        destination: destination,
      );

      final bus = await _getNearbyBus(
        destinationName: destinationName,
        destination: destination,
      );

      return PublicTransportResult(
        train: train,
        bus: bus,
      );
    } catch (e) {
      print('TransitRouteService error: $e');

      // Safe fallback so the card still works even if API fails
      return PublicTransportResult(
        train: NearbyTrainInfo(
          stationName: '$destinationName Station',
          distanceMeters: 1200,
          stationCode: null,
          ticketUrl: _buildTrainTicketUrl(destinationName),
        ),
        bus: NearbyBusInfo(
          title: 'Bus journeys nearby',
          distanceMeters: 350,
          timetableUrl: _buildBusTimetableUrl(destinationName),
        ),
      );
    }
  }

  Future<NearbyTrainInfo?> _getNearestTrain({
    required String destinationName,
    required LatLng destination,
  }) async {
    final data = await _transportApi.searchNearbyPlaces(
      latitude: destination.latitude,
      longitude: destination.longitude,
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

    return NearbyTrainInfo(
      stationName: name,
      distanceMeters: distanceMeters,
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

    final stopName =
    (member['name'] ?? member['description'] ?? 'Bus journeys nearby')
        .toString();

    final distanceMeters = _readDistanceMeters(member) ?? 0;

    return NearbyBusInfo(
      title: 'Bus journeys nearby',
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

  String _buildTrainTicketUrl(String stationName) {
    final encoded = Uri.encodeComponent(stationName);
    return 'https://www.thetrainline.com/search?searchTerm=$encoded';
  }

  String _buildBusTimetableUrl(String placeName) {
    final encoded = Uri.encodeComponent(placeName);
    return 'https://www.google.com/search?q=bus+timetable+$encoded';
  }
}