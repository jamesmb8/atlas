import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import '../features/transport/transport_api.dart';

const _transportApiAppId = String.fromEnvironment('TRANSPORT_API_APP_ID');
const _transportApiAppKey = String.fromEnvironment('TRANSPORT_API_APP_KEY');

enum PublicTransportMode {
  bus,
  train,
}

class TransitAccessPoint {
  final String name;
  final double distanceMeters;
  final LatLng latLng;
  final bool hasCoordinates;
  final String? code;
  final String detailsUrl;
  final PublicTransportMode mode;

  const TransitAccessPoint({
    required this.name,
    required this.distanceMeters,
    required this.latLng,
    required this.hasCoordinates,
    required this.detailsUrl,
    required this.mode,
    this.code,
  });

  double get distanceMiles => distanceMeters / 1609.344;
  double get distanceKm => distanceMeters / 1000.0;
}

class TransitPairResult {
  final TransitAccessPoint? fromOrigin;
  final TransitAccessPoint? toDestination;
  final PublicTransportMode mode;

  const TransitPairResult({
    required this.fromOrigin,
    required this.toDestination,
    required this.mode,
  });

  bool get hasBoth => fromOrigin != null && toDestination != null;

  double? get accessDistanceMeters {
    if (!hasBoth) return null;
    return (fromOrigin!.distanceMeters + toDestination!.distanceMeters);
  }

  double? get lineDistanceMeters {
    final a = fromOrigin?.latLng;
    final b = toDestination?.latLng;
    if (a == null || b == null) return null;
    return _haversineMeters(a, b);
  }

  double? get totalJourneyDistanceMeters {
    final line = lineDistanceMeters;
    final access = accessDistanceMeters;
    if (line == null || access == null) return null;
    return line + access;
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

class FareEstimate {
  final double min;
  final double max;
  final String label;

  const FareEstimate({
    required this.min,
    required this.max,
    required this.label,
  });

  String get formatted {
    if ((max - min).abs() < 0.01) {
      return '£${min.toStringAsFixed(2)}';
    }
    return '£${min.toStringAsFixed(2)}–£${max.toStringAsFixed(2)}';
  }
}

class PublicTransportResult {
  final TransitPairResult bus;
  final TransitPairResult train;
  final PublicTransportMode? recommendedMode;
  final FareEstimate? recommendedFare;
  final FareEstimate? alternativeFare;

  const PublicTransportResult({
    required this.bus,
    required this.train,
    required this.recommendedMode,
    required this.recommendedFare,
    required this.alternativeFare,
  });

  bool get hasAnyData =>
      bus.fromOrigin != null ||
          bus.toDestination != null ||
          train.fromOrigin != null ||
          train.toDestination != null;

  TransitPairResult? get recommended {
    switch (recommendedMode) {
      case PublicTransportMode.bus:
        return bus.hasBoth ? bus : null;
      case PublicTransportMode.train:
        return train.hasBoth ? train : null;
      case null:
        return null;
    }
  }

  TransitPairResult? get alternative {
    switch (recommendedMode) {
      case PublicTransportMode.bus:
        return train.hasBoth ? train : null;
      case PublicTransportMode.train:
        return bus.hasBoth ? bus : null;
      case null:
        if (train.hasBoth) return train;
        if (bus.hasBoth) return bus;
        return null;
    }
  }
}

class TransitRouteService {
  final TransportApi _transportApi;

  TransitRouteService({TransportApi? transportApi})
      : _transportApi = transportApi ??
      TransportApi(
        appId: _transportApiAppId,
        appKey: _transportApiAppKey,
      );

  bool get _hasApiCredentials =>
      _transportApiAppId.trim().isNotEmpty && _transportApiAppKey.trim().isNotEmpty;

  Future<PublicTransportResult> getPublicTransportSummary({
    required String destinationName,
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (!_hasApiCredentials) {
      return _fallbackResult(
        destinationName: destinationName,
        origin: origin,
        destination: destination,
      );
    }

    try {
      final results = await Future.wait([
        _getNearestTransitPair(
          destinationName: destinationName,
          origin: origin,
          destination: destination,
          mode: PublicTransportMode.bus,
        ),
        _getNearestTransitPair(
          destinationName: destinationName,
          origin: origin,
          destination: destination,
          mode: PublicTransportMode.train,
        ),
      ]);

      final bus = results[0];
      final train = results[1];
      final recommendedMode = _chooseRecommendedMode(bus, train);
      final recommendedFare = _estimateFareForMode(
        recommendedMode,
        recommendedMode == PublicTransportMode.train ? train : bus,
      );
      final alternativeFare = _estimateFareForMode(
        recommendedMode == PublicTransportMode.train
            ? PublicTransportMode.bus
            : PublicTransportMode.train,
        recommendedMode == PublicTransportMode.train ? bus : train,
      );

      return PublicTransportResult(
        bus: bus,
        train: train,
        recommendedMode: recommendedMode,
        recommendedFare: recommendedFare,
        alternativeFare: alternativeFare,
      );
    } catch (e) {
      print('TransitRouteService error: $e');
      return _fallbackResult(
        destinationName: destinationName,
        origin: origin,
        destination: destination,
      );
    }
  }

  PublicTransportResult _fallbackResult({
    required String destinationName,
    required LatLng origin,
    required LatLng destination,
  }) {
    final bus = TransitPairResult(
      mode: PublicTransportMode.bus,
      fromOrigin: TransitAccessPoint(
        name: 'Nearest bus stop',
        distanceMeters: 280,
        latLng: origin,
        hasCoordinates: false,
        detailsUrl: _buildBusTimetableUrl('Nearest bus stop'),
        mode: PublicTransportMode.bus,
      ),
      toDestination: TransitAccessPoint(
        name: '$destinationName Bus Stop',
        distanceMeters: 320,
        latLng: destination,
        hasCoordinates: false,
        detailsUrl: _buildBusTimetableUrl('$destinationName Bus Stop'),
        mode: PublicTransportMode.bus,
      ),
    );

    final train = TransitPairResult(
      mode: PublicTransportMode.train,
      fromOrigin: TransitAccessPoint(
        name: 'Nearest station',
        distanceMeters: 1200,
        latLng: origin,
        hasCoordinates: false,
        code: null,
        detailsUrl: _buildTrainTicketUrl('Nearest station'),
        mode: PublicTransportMode.train,
      ),
      toDestination: TransitAccessPoint(
        name: '$destinationName Station',
        distanceMeters: 1100,
        latLng: destination,
        hasCoordinates: false,
        code: null,
        detailsUrl: _buildTrainTicketUrl('$destinationName Station'),
        mode: PublicTransportMode.train,
      ),
    );

    return PublicTransportResult(
      bus: bus,
      train: train,
      recommendedMode: PublicTransportMode.bus,
      recommendedFare: _estimateBusFare(bus),
      alternativeFare: _estimateTrainFare(train),
    );
  }

  Future<TransitPairResult> _getNearestTransitPair({
    required String destinationName,
    required LatLng origin,
    required LatLng destination,
    required PublicTransportMode mode,
  }) async {
    final type = mode == PublicTransportMode.train ? 'train_station' : 'bus_stop';

    final points = await Future.wait([
      _getNearestTransitPoint(
        destinationName: destinationName,
        point: origin,
        mode: mode,
        type: type,
      ),
      _getNearestTransitPoint(
        destinationName: destinationName,
        point: destination,
        mode: mode,
        type: type,
      ),
    ]);

    return TransitPairResult(
      mode: mode,
      fromOrigin: points[0],
      toDestination: points[1],
    );
  }

  Future<TransitAccessPoint?> _getNearestTransitPoint({
    required String destinationName,
    required LatLng point,
    required PublicTransportMode mode,
    required String type,
  }) async {
    final data = await _transportApi.searchNearbyPlacesList(
      latitude: point.latitude,
      longitude: point.longitude,
      type: type,
      maxResults: 1,
    );

    if (data.isEmpty) return null;
    final member = data.first;

    final fallbackName =
    mode == PublicTransportMode.train ? '$destinationName Station' : 'Nearest bus stop';

    final name = (member['name'] ?? member['station_name'] ?? member['description'] ?? fallbackName)
        .toString()
        .trim();

    final code = (member['station_code'] ?? member['atcocode'])?.toString();

    final lat = _readDouble(member, ['latitude', 'lat', 'y']);
    final lon = _readDouble(member, ['longitude', 'lon', 'lng', 'x']);
    final hasCoords = lat != null && lon != null;

    return TransitAccessPoint(
      name: name.isEmpty ? fallbackName : name,
      distanceMeters: _readDistanceMeters(member) ?? 0,
      latLng: hasCoords ? LatLng(lat!, lon!) : point,
      hasCoordinates: hasCoords,
      code: code,
      detailsUrl: mode == PublicTransportMode.train
          ? _buildTrainTicketUrl(name.isEmpty ? fallbackName : name)
          : _buildBusTimetableUrl(name.isEmpty ? fallbackName : name),
      mode: mode,
    );
  }

  PublicTransportMode? _chooseRecommendedMode(
      TransitPairResult bus,
      TransitPairResult train,
      ) {
    final busOk = _isUsablePair(bus);
    final trainOk = _isUsablePair(train);

    if (!busOk && !trainOk) return null;
    if (busOk && !trainOk) return PublicTransportMode.bus;
    if (trainOk && !busOk) return PublicTransportMode.train;

    final busScore = _scoreTransitPair(bus, PublicTransportMode.bus);
    final trainScore = _scoreTransitPair(train, PublicTransportMode.train);

    return trainScore < busScore ? PublicTransportMode.train : PublicTransportMode.bus;
  }

  bool _isUsablePair(TransitPairResult pair) {
    if (!pair.hasBoth) return false;
    final a = pair.fromOrigin!;
    final b = pair.toDestination!;
    if (a.name.trim().isEmpty || b.name.trim().isEmpty) return false;
    if (_sameAccessPoint(a, b)) return false;
    return true;
  }

  bool _sameAccessPoint(TransitAccessPoint a, TransitAccessPoint b) {
    final ac = a.code?.trim();
    final bc = b.code?.trim();
    if (ac != null && bc != null && ac.isNotEmpty && bc.isNotEmpty) {
      return ac.toLowerCase() == bc.toLowerCase();
    }

    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return norm(a.name) == norm(b.name);
  }

  double _scoreTransitPair(TransitPairResult pair, PublicTransportMode mode) {
    final access = pair.accessDistanceMeters ?? 999999;
    final line = pair.lineDistanceMeters ?? 999999;

    var score = access + line;

    if (mode == PublicTransportMode.train) {
      if (line >= 12000) score -= 2500;
      if (access > 2500) score += 1500;
    } else {
      if (line >= 12000) score += 3000;
      if (access <= 800) score -= 800;
    }

    return score;
  }

  FareEstimate? _estimateFareForMode(
      PublicTransportMode? mode,
      TransitPairResult pair,
      ) {
    if (mode == null || !_isUsablePair(pair)) return null;
    return mode == PublicTransportMode.train ? _estimateTrainFare(pair) : _estimateBusFare(pair);
  }

  FareEstimate _estimateTrainFare(TransitPairResult pair) {
    final lineMeters = pair.lineDistanceMeters ?? 0;
    final km = lineMeters / 1000.0;

    if (km <= 5) {
      return const FareEstimate(min: 2.80, max: 6.50, label: 'Estimated train fare');
    }
    if (km <= 20) {
      return const FareEstimate(min: 5.20, max: 12.90, label: 'Estimated train fare');
    }
    if (km <= 60) {
      return const FareEstimate(min: 9.50, max: 24.50, label: 'Estimated train fare');
    }
    if (km <= 120) {
      return const FareEstimate(min: 16.00, max: 42.00, label: 'Estimated train fare');
    }
    return const FareEstimate(min: 24.00, max: 75.00, label: 'Estimated train fare');
  }

  FareEstimate _estimateBusFare(TransitPairResult pair) {
    final lineMeters = pair.lineDistanceMeters ?? 0;
    final km = lineMeters / 1000.0;

    if (km <= 3) {
      return const FareEstimate(min: 1.80, max: 2.50, label: 'Estimated bus fare');
    }
    if (km <= 8) {
      return const FareEstimate(min: 2.00, max: 3.50, label: 'Estimated bus fare');
    }
    if (km <= 20) {
      return const FareEstimate(min: 2.50, max: 5.50, label: 'Estimated bus fare');
    }
    return const FareEstimate(min: 4.00, max: 8.50, label: 'Estimated bus fare');
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