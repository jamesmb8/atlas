// lib/services/transitrouteservice.dart
import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart';

import '../app/config/transportkeys.dart';
import '../features/transport/transport_api.dart';

enum PublicTransportMode {
  bus,
  train,
}

enum TransitLegType {
  walk,
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
  final List<String> servedLines;
  final bool isReal;

  const TransitAccessPoint({
    required this.name,
    required this.distanceMeters,
    required this.latLng,
    required this.hasCoordinates,
    required this.detailsUrl,
    required this.mode,
    required this.isReal,
    this.code,
    this.servedLines = const [],
  });

  String get displayNameWithCode {
    final trimmedCode = code?.trim();
    if (trimmedCode == null || trimmedCode.isEmpty) {
      return name;
    }
    return '$name ($trimmedCode)';
  }
}

class TransitJourneyLeg {
  final TransitLegType type;
  final double distanceMeters;
  final int durationMinutes;
  final String instruction;
  final String? routeCode;
  final String? routeName;
  final String? fromStopName;
  final String? fromStopCode;
  final String? toStopName;
  final String? toStopCode;

  const TransitJourneyLeg({
    required this.type,
    required this.distanceMeters,
    required this.durationMinutes,
    required this.instruction,
    this.routeCode,
    this.routeName,
    this.fromStopName,
    this.fromStopCode,
    this.toStopName,
    this.toStopCode,
  });

  bool get isTransit => type == TransitLegType.bus || type == TransitLegType.train;

  String get label {
    switch (type) {
      case TransitLegType.walk:
        return 'Walk';
      case TransitLegType.bus:
        final code = routeCode?.trim();
        return (code != null && code.isNotEmpty) ? 'Bus $code' : 'Bus';
      case TransitLegType.train:
        final code = routeCode?.trim();
        if (code != null &&
            code.isNotEmpty &&
            !RegExp(r'^\d{5,}$').hasMatch(code) &&
            code.length <= 5) {
          return 'Train $code';
        }
        return 'Train';
    }
  }

  String get chipLabel {
    if (type == TransitLegType.walk) {
      final minutes = durationMinutes <= 0 ? 1 : durationMinutes;
      return '$minutes';
    }

    final trimmedCode = routeCode?.trim();
    if (trimmedCode != null && trimmedCode.isNotEmpty) {
      return trimmedCode;
    }

    return type == TransitLegType.train ? 'Rail' : 'Bus';
  }
}

class TransitJourneyDisplayStep {
  final TransitLegType type;
  final String title;
  final String? subtitle;
  final double distanceMeters;

  const TransitJourneyDisplayStep({
    required this.type,
    required this.title,
    required this.distanceMeters,
    this.subtitle,
  });
}

class TransitJourneyPlan {
  final PublicTransportMode mode;
  final List<TransitJourneyLeg> legs;
  final int durationMinutes;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
  final String? statusText;

  const TransitJourneyPlan({
    required this.mode,
    required this.legs,
    required this.durationMinutes,
    this.departureTime,
    this.arrivalTime,
    this.statusText,
  });

  bool get hasLegs => legs.isNotEmpty;

  int get transitLegCount => legs.where((e) => e.isTransit).length;

  int get busLegCount => legs.where((e) => e.type == TransitLegType.bus).length;

  int get trainLegCount => legs.where((e) => e.type == TransitLegType.train).length;

  int get interchangeCount => transitLegCount > 0 ? transitLegCount - 1 : 0;

  bool get hasTrain => trainLegCount > 0;

  bool get hasBus => busLegCount > 0;

  bool get hasSchedule =>
      departureTime != null &&
          arrivalTime != null &&
          arrivalTime!.isAfter(departureTime!);

  int get effectiveDurationMinutes {
    if (hasSchedule) {
      return arrivalTime!.difference(departureTime!).inMinutes;
    }
    return durationMinutes;
  }

  double get totalDistanceMeters =>
      legs.fold(0.0, (sum, leg) => sum + leg.distanceMeters);

  double get totalWalkingDistanceMeters => legs
      .where((e) => e.type == TransitLegType.walk)
      .fold(0.0, (sum, leg) => sum + leg.distanceMeters);

  double get totalTransitDistanceMeters => legs
      .where((e) => e.isTransit)
      .fold(0.0, (sum, leg) => sum + leg.distanceMeters);

  double get estimatedCo2Kg {
    var total = 0.0;

    for (final leg in legs) {
      final km = leg.distanceMeters / 1000.0;
      switch (leg.type) {
        case TransitLegType.walk:
          total += 0.0;
          break;
        case TransitLegType.bus:
          total += km * 0.082;
          break;
        case TransitLegType.train:
          total += km * 0.036;
          break;
      }
    }

    return total;
  }

  TransitJourneyLeg? get firstTransitLeg {
    for (final leg in legs) {
      if (leg.isTransit) {
        return leg;
      }
    }
    return null;
  }

  TransitJourneyLeg? get lastTransitLeg {
    for (final leg in legs.reversed) {
      if (leg.isTransit) {
        return leg;
      }
    }
    return null;
  }

  String? get departureStopLabel {
    final leg = firstTransitLeg;
    if (leg == null) {
      return null;
    }
    return _stopDisplay(leg.fromStopName, leg.fromStopCode);
  }

  String? get arrivalStopLabel {
    final leg = lastTransitLeg;
    if (leg == null) {
      return null;
    }
    return _stopDisplay(leg.toStopName, leg.toStopCode);
  }

  String get routeHeadline {
    final transitLabels = displayLegs
        .where((e) => e.isTransit)
        .map((e) => e.label)
        .toList(growable: false);

    if (transitLabels.isEmpty) {
      return compactSummary;
    }

    return transitLabels.join('  •  ');
  }

  String get compactSummary {
    final parts = <String>[];

    for (final leg in displayLegs) {
      if (leg.type == TransitLegType.walk) {
        parts.add('Walk ${_formatMeters(leg.distanceMeters)}');
        continue;
      }

      final from = _stopDisplay(leg.fromStopName, leg.fromStopCode);
      final to = _stopDisplay(leg.toStopName, leg.toStopCode);

      if (from.isNotEmpty && to.isNotEmpty) {
        parts.add('${leg.label}: $from → $to');
      } else {
        parts.add(leg.label);
      }
    }

    return parts.join('  →  ');
  }

  List<TransitJourneyLeg> get displayLegs {
    final result = <TransitJourneyLeg>[];

    for (final leg in legs) {
      if (result.isNotEmpty && _isSameDisplayLeg(result.last, leg)) {
        continue;
      }
      result.add(leg);
    }

    return result;
  }

  List<TransitJourneyDisplayStep> get displaySteps {
    final steps = <TransitJourneyDisplayStep>[];

    for (final leg in displayLegs) {
      if (leg.type == TransitLegType.walk) {
        final from = _stopDisplay(leg.fromStopName, leg.fromStopCode);
        final to = _stopDisplay(leg.toStopName, leg.toStopCode);
        final subtitle = to.isNotEmpty
            ? (from.isNotEmpty ? '$from → $to' : 'to $to')
            : (from.isNotEmpty ? 'from $from' : null);

        steps.add(
          TransitJourneyDisplayStep(
            type: leg.type,
            title: 'Walk ${_formatMeters(leg.distanceMeters)}',
            subtitle: subtitle,
            distanceMeters: leg.distanceMeters,
          ),
        );
        continue;
      }

      final from = _stopDisplay(leg.fromStopName, leg.fromStopCode);
      final to = _stopDisplay(leg.toStopName, leg.toStopCode);

      steps.add(
        TransitJourneyDisplayStep(
          type: leg.type,
          title: 'Take ${leg.label}',
          subtitle: (from.isNotEmpty && to.isNotEmpty) ? '$from → $to' : null,
          distanceMeters: leg.distanceMeters,
        ),
      );
    }

    return steps;
  }

  static bool _isSameDisplayLeg(TransitJourneyLeg a, TransitJourneyLeg b) {
    String normalize(String? value) {
      return (value ?? '')
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    }

    return a.type == b.type &&
        normalize(a.routeCode) == normalize(b.routeCode) &&
        normalize(a.fromStopName) == normalize(b.fromStopName) &&
        normalize(a.toStopName) == normalize(b.toStopName);
  }

  static String _stopDisplay(String? name, String? code) {
    final n = (name ?? '').trim();
    final c = (code ?? '').trim();
    if (n.isEmpty) {
      return '';
    }
    if (c.isEmpty) {
      return n;
    }
    return '$n ($c)';
  }

  static String _formatMeters(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}

class TransitJourneyOption {
  final TransitJourneyPlan plan;
  final FareEstimate fareEstimate;
  final double score;
  final String tag;

  const TransitJourneyOption({
    required this.plan,
    required this.fareEstimate,
    required this.score,
    required this.tag,
  });

  String get modeLabel {
    if (plan.hasTrain && plan.hasBus) {
      return 'Bus + train';
    }
    if (plan.hasTrain) {
      return 'Train';
    }
    return 'Bus';
  }

  TransitJourneyOption copyWith({
    TransitJourneyPlan? plan,
    FareEstimate? fareEstimate,
    double? score,
    String? tag,
  }) {
    return TransitJourneyOption(
      plan: plan ?? this.plan,
      fareEstimate: fareEstimate ?? this.fareEstimate,
      score: score ?? this.score,
      tag: tag ?? this.tag,
    );
  }
}

class TransitPairResult {
  final TransitAccessPoint? fromOrigin;
  final TransitAccessPoint? toDestination;
  final PublicTransportMode mode;
  final TransitJourneyPlan? journeyPlan;
  final bool isRealData;

  const TransitPairResult({
    required this.fromOrigin,
    required this.toDestination,
    required this.mode,
    required this.isRealData,
    this.journeyPlan,
  });

  bool get hasBoth => fromOrigin != null && toDestination != null;

  double? get accessDistanceMeters {
    if (!hasBoth) {
      return null;
    }
    return fromOrigin!.distanceMeters + toDestination!.distanceMeters;
  }

  double? get lineDistanceMeters {
    final a = fromOrigin;
    final b = toDestination;
    if (a == null || b == null) {
      return null;
    }
    if (!a.hasCoordinates || !b.hasCoordinates) {
      return null;
    }
    return _haversineMeters(a.latLng, b.latLng);
  }

  double? get totalJourneyDistanceMeters {
    if (journeyPlan != null && journeyPlan!.hasLegs) {
      return journeyPlan!.totalDistanceMeters;
    }
    final line = lineDistanceMeters;
    final access = accessDistanceMeters;
    if (line == null || access == null) {
      return null;
    }
    return line + access;
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
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
  final TransitPairResult? bus;
  final TransitPairResult? train;
  final PublicTransportMode? recommendedMode;
  final FareEstimate? recommendedFare;
  final FareEstimate? alternativeFare;
  final List<TransitJourneyOption> journeyOptions;
  final String? debugReason;

  const PublicTransportResult({
    required this.bus,
    required this.train,
    required this.recommendedMode,
    required this.recommendedFare,
    required this.alternativeFare,
    this.journeyOptions = const [],
    this.debugReason,
  });

  bool get hasAnyData =>
      bus != null || train != null || journeyOptions.isNotEmpty;

  TransitPairResult? get recommended {
    switch (recommendedMode) {
      case PublicTransportMode.bus:
        return bus;
      case PublicTransportMode.train:
        return train;
      case null:
        return null;
    }
  }

  TransitPairResult? get alternative {
    switch (recommendedMode) {
      case PublicTransportMode.bus:
        return train;
      case PublicTransportMode.train:
        return bus;
      case null:
        return train ?? bus;
    }
  }
}

class TransitRouteService {
  final TransportApi _transportApi;

  TransitRouteService({TransportApi? transportApi})
      : _transportApi = transportApi ??
      TransportApi(
        appId: transportApiAppId,
        appKey: transportApiAppKey,
      );

  bool get _hasApiCredentials =>
      transportApiAppId.trim().isNotEmpty &&
          transportApiAppKey.trim().isNotEmpty;

  Future<PublicTransportResult> getPublicTransportSummary({
    required String destinationName,
    required LatLng origin,
    required LatLng destination,
    DateTime? departureTime,
  }) async {
    if (!_hasApiCredentials) {
      return const PublicTransportResult(
        bus: null,
        train: null,
        recommendedMode: null,
        recommendedFare: null,
        alternativeFare: null,
        journeyOptions: [],
        debugReason: 'Missing Transport API credentials',
      );
    }

    Map<String, dynamic>? journeyData;
    String? debugReason;

    try {
      journeyData = await _transportApi.publicJourney(
        fromLat: origin.latitude,
        fromLon: origin.longitude,
        toLat: destination.latitude,
        toLon: destination.longitude,
        dateTime: departureTime,
      );
    } catch (e) {
      debugReason = 'public_journey failed: $e';
    }

    TransitPairResult? bus;
    TransitPairResult? train;
    List<TransitJourneyOption> journeyOptions = const [];

    if (journeyData != null) {
      bus = _extractBestJourneyPlan(
        data: journeyData,
        targetMode: PublicTransportMode.bus,
      );

      train = _extractBestJourneyPlan(
        data: journeyData,
        targetMode: PublicTransportMode.train,
      );

      journeyOptions = _extractJourneyOptions(
        data: journeyData,
        origin: origin,
        destination: destination,
      );

      if (bus == null && train == null && journeyOptions.isEmpty) {
        final apiReason = _extractApiReason(journeyData);
        debugReason = _appendDebugReason(
          debugReason,
          apiReason ?? 'public_journey returned no usable routes',
        );
      }
    }

    var recommendedMode = _chooseRecommendedMode(bus, train);
    if (recommendedMode == null && journeyOptions.isNotEmpty) {
      recommendedMode = journeyOptions.first.plan.mode;
    }

    final recommendedPair =
    recommendedMode == PublicTransportMode.train ? train : bus;
    final alternativePair =
    recommendedMode == PublicTransportMode.train ? bus : train;

    final recommendedFare =
        _estimateFareForMode(recommendedMode, recommendedPair) ??
            (journeyOptions.isNotEmpty ? journeyOptions.first.fareEstimate : null);

    final alternativeFare =
        _estimateFareForMode(
          recommendedMode == PublicTransportMode.train
              ? PublicTransportMode.bus
              : PublicTransportMode.train,
          alternativePair,
        ) ??
            (journeyOptions.length > 1 ? journeyOptions[1].fareEstimate : null);

    if (recommendedMode == null && journeyOptions.isEmpty) {
      debugReason = _appendDebugReason(
        debugReason,
        'No usable public transport result returned',
      );
    }

    return PublicTransportResult(
      bus: bus,
      train: train,
      recommendedMode: recommendedMode,
      recommendedFare: recommendedFare,
      alternativeFare: alternativeFare,
      journeyOptions: journeyOptions,
      debugReason: debugReason,
    );
  }

  String _appendDebugReason(String? current, String next) {
    if (current == null || current.trim().isEmpty) {
      return next;
    }
    return '$current | $next';
  }

  List<TransitJourneyOption> _extractJourneyOptions({
    required Map<String, dynamic> data,
    required LatLng origin,
    required LatLng destination,
  }) {
    final rawRoutes = data['routes'] ?? data['journeys'];
    if (rawRoutes is! List) {
      return const [];
    }

    final directDistanceMeters =
    TransitPairResult._haversineMeters(origin, destination);
    final candidates = <TransitJourneyOption>[];
    final seenSignatures = <String>{};

    for (final rawRoute in rawRoutes) {
      final route = _asMap(rawRoute);
      if (route == null) {
        continue;
      }

      final plan = _parseJourneyPlan(route);
      if (plan == null || !plan.hasLegs || plan.transitLegCount == 0) {
        continue;
      }

      final signature = _planSignature(plan);
      if (seenSignatures.contains(signature)) {
        continue;
      }
      seenSignatures.add(signature);

      final score = _scoreJourneyPlan(
        plan,
        directDistanceMeters: directDistanceMeters,
      );

      candidates.add(
        TransitJourneyOption(
          plan: plan,
          fareEstimate: _estimateFareForPlan(plan),
          score: score,
          tag: 'Option',
        ),
      );
    }

    candidates.sort(_compareJourneyOptions);

    return _applyJourneyTags(candidates);
  }

  int _compareJourneyOptions(TransitJourneyOption a, TransitJourneyOption b) {
    final aDeparture = a.plan.departureTime;
    final bDeparture = b.plan.departureTime;

    if (aDeparture != null && bDeparture != null) {
      final departureCompare = aDeparture.compareTo(bDeparture);
      if (departureCompare != 0) {
        return departureCompare;
      }
    }

    final durationCompare =
    a.plan.effectiveDurationMinutes.compareTo(b.plan.effectiveDurationMinutes);
    if (durationCompare != 0) {
      return durationCompare;
    }

    final aArrival = a.plan.arrivalTime;
    final bArrival = b.plan.arrivalTime;

    if (aArrival != null && bArrival != null) {
      final arrivalCompare = aArrival.compareTo(bArrival);
      if (arrivalCompare != 0) {
        return arrivalCompare;
      }
    }

    final changesCompare =
    a.plan.interchangeCount.compareTo(b.plan.interchangeCount);
    if (changesCompare != 0) {
      return changesCompare;
    }

    final carbonCompare =
    a.plan.estimatedCo2Kg.compareTo(b.plan.estimatedCo2Kg);
    if (carbonCompare != 0) {
      return carbonCompare;
    }

    return a.score.compareTo(b.score);
  }

  List<TransitJourneyOption> _applyJourneyTags(
      List<TransitJourneyOption> options,
      ) {
    if (options.isEmpty) {
      return const [];
    }

    final tagged = List<TransitJourneyOption>.from(options);
    final tags = List<String>.filled(tagged.length, 'Option');

    var quickestIndex = 0;
    var lowestCo2Index = 0;
    var fewestChangesIndex = 0;

    for (var i = 1; i < tagged.length; i++) {
      if (tagged[i].plan.effectiveDurationMinutes <
          tagged[quickestIndex].plan.effectiveDurationMinutes) {
        quickestIndex = i;
      }

      if (tagged[i].plan.estimatedCo2Kg <
          tagged[lowestCo2Index].plan.estimatedCo2Kg) {
        lowestCo2Index = i;
      }

      final changesCompare = tagged[i].plan.interchangeCount
          .compareTo(tagged[fewestChangesIndex].plan.interchangeCount);

      if (changesCompare < 0 ||
          (changesCompare == 0 &&
              tagged[i].plan.effectiveDurationMinutes <
                  tagged[fewestChangesIndex].plan.effectiveDurationMinutes)) {
        fewestChangesIndex = i;
      }
    }

    tags[quickestIndex] = 'Quickest';

    if (tags[lowestCo2Index] == 'Option') {
      tags[lowestCo2Index] = 'Lowest CO₂';
    }

    if (tags[fewestChangesIndex] == 'Option') {
      tags[fewestChangesIndex] = 'Fewer changes';
    }

    return List<TransitJourneyOption>.generate(
      tagged.length,
          (index) => tagged[index].copyWith(tag: tags[index]),
      growable: false,
    );
  }

  String _planSignature(TransitJourneyPlan plan) {
    String normalize(String? value) {
      return (value ?? '')
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    }

    final departureKey = plan.departureTime?.toIso8601String() ?? '';

    return [
      departureKey,
      ...plan.displayLegs.map(
            (leg) => [
          leg.type.name,
          normalize(leg.routeCode),
          normalize(leg.fromStopName),
          normalize(leg.toStopName),
          (leg.distanceMeters / 100).round().toString(),
        ].join(':'),
      ),
    ].join('|');
  }

  TransitPairResult? _extractBestJourneyPlan({
    required Map<String, dynamic> data,
    required PublicTransportMode targetMode,
  }) {
    final rawRoutes = data['routes'] ?? data['journeys'];
    if (rawRoutes is! List) {
      return null;
    }

    TransitPairResult? best;
    double? bestScore;

    for (final rawRoute in rawRoutes) {
      final route = _asMap(rawRoute);
      if (route == null) {
        continue;
      }

      final plan = _parseJourneyPlan(route);
      if (plan == null || plan.mode != targetMode || !plan.hasLegs) {
        continue;
      }

      final transitLegs =
      plan.legs.where((leg) => leg.isTransit).toList(growable: false);
      if (transitLegs.isEmpty) {
        continue;
      }

      final firstTransit = transitLegs.first;
      final lastTransit = transitLegs.last;

      final fromName = _nullIfBlank(firstTransit.fromStopName) ?? '';
      final toName = _nullIfBlank(lastTransit.toStopName) ?? '';
      if (fromName.isEmpty || toName.isEmpty) {
        continue;
      }

      final servedLines = <String>[
        if (_nullIfBlank(firstTransit.routeCode) != null)
          firstTransit.routeCode!.trim(),
        if (_nullIfBlank(lastTransit.routeCode) != null &&
            lastTransit.routeCode!.trim() != firstTransit.routeCode?.trim())
          lastTransit.routeCode!.trim(),
      ];

      final fromPoint = TransitAccessPoint(
        name: fromName,
        distanceMeters: _firstWalkDistance(plan),
        latLng: const LatLng(0, 0),
        hasCoordinates: false,
        detailsUrl: targetMode == PublicTransportMode.train
            ? _buildTrainTicketUrl(fromName)
            : _buildBusTimetableUrl(fromName),
        mode: targetMode,
        isReal: true,
        code: _nullIfBlank(firstTransit.fromStopCode),
        servedLines: servedLines,
      );

      final toPoint = TransitAccessPoint(
        name: toName,
        distanceMeters: _lastWalkDistance(plan),
        latLng: const LatLng(0, 0),
        hasCoordinates: false,
        detailsUrl: targetMode == PublicTransportMode.train
            ? _buildTrainTicketUrl(toName)
            : _buildBusTimetableUrl(toName),
        mode: targetMode,
        isReal: true,
        code: _nullIfBlank(lastTransit.toStopCode),
        servedLines: servedLines,
      );

      final pair = TransitPairResult(
        fromOrigin: fromPoint,
        toDestination: toPoint,
        mode: targetMode,
        journeyPlan: plan,
        isRealData: true,
      );

      final score = _scoreJourneyPlan(plan);
      if (best == null || bestScore == null || score < bestScore) {
        best = pair;
        bestScore = score;
      }
    }

    return best;
  }

  TransitJourneyPlan? _parseJourneyPlan(Map<String, dynamic> route) {
    final rawParts = route['route_parts'] ?? route['legs'];
    if (rawParts is! List || rawParts.isEmpty) {
      return null;
    }

    final legs = <TransitJourneyLeg>[];
    var sawBus = false;
    var sawTrain = false;

    for (final rawPart in rawParts) {
      final part = _asMap(rawPart);
      if (part == null) {
        continue;
      }

      final modeText = _readFirstString(
        part,
        const ['mode', 'type', 'travel_mode', 'transport_mode'],
      ).toLowerCase();

      final distanceMeters = _readDistanceMeters(part) ?? 0.0;
      final durationMinutes =
          _readDurationMinutes(part) ??
              _estimateLegDurationMinutes(
                type: _looksLikeWalk(modeText)
                    ? TransitLegType.walk
                    : (_looksLikeTrain(modeText, part)
                    ? TransitLegType.train
                    : TransitLegType.bus),
                distanceMeters: distanceMeters,
              );

      if (_looksLikeWalk(modeText)) {
        legs.add(
          TransitJourneyLeg(
            type: TransitLegType.walk,
            distanceMeters: distanceMeters,
            durationMinutes: durationMinutes,
            instruction: 'Walk',
            fromStopName: _readPlaceName(
              part,
              const [
                'from_point_name',
                'from_name',
                'origin_name',
                'departure_name',
                'from',
              ],
            ),
            toStopName: _readPlaceName(
              part,
              const [
                'to_point_name',
                'to_name',
                'destination_name',
                'arrival_name',
                'to',
              ],
            ),
          ),
        );
        continue;
      }

      final isTrain = _looksLikeTrain(modeText, part);
      final isBus = _looksLikeBus(modeText, part);

      if (!isTrain && !isBus) {
        continue;
      }

      if (isTrain) {
        sawTrain = true;
      }
      if (isBus) {
        sawBus = true;
      }

      final fromName = _readPlaceName(
        part,
        const [
          'from_point_name',
          'from_name',
          'origin_name',
          'departure_name',
          'from',
        ],
      );

      final toName = _readPlaceName(
        part,
        const [
          'to_point_name',
          'to_name',
          'destination_name',
          'arrival_name',
          'to',
        ],
      );

      final fromCode = _readFirstString(
        part,
        const [
          'from_station_code',
          'from_atcocode',
          'from_naptan_code',
          'from_code',
          'origin_code',
          'departure_code',
        ],
      );

      final toCode = _readFirstString(
        part,
        const [
          'to_station_code',
          'to_atcocode',
          'to_naptan_code',
          'to_code',
          'destination_code',
          'arrival_code',
        ],
      );

      final routeCode = _readFirstString(
        part,
        const [
          'line',
          'line_name',
          'service',
          'service_name',
          'route_code',
          'route',
          'number',
        ],
      );

      final routeName = _readFirstString(
        part,
        const [
          'route_name',
          'line_name',
          'description',
          'operator_name',
          'operator',
        ],
      );

      legs.add(
        TransitJourneyLeg(
          type: isTrain ? TransitLegType.train : TransitLegType.bus,
          distanceMeters: distanceMeters,
          durationMinutes: durationMinutes,
          instruction: isTrain ? 'Take the train' : 'Take the bus',
          routeCode: _nullIfBlank(routeCode),
          routeName: _nullIfBlank(routeName),
          fromStopName: _nullIfBlank(fromName),
          fromStopCode: _nullIfBlank(fromCode),
          toStopName: _nullIfBlank(toName),
          toStopCode: _nullIfBlank(toCode),
        ),
      );
    }

    if (legs.isEmpty) {
      return null;
    }

    final mode = sawTrain && !sawBus
        ? PublicTransportMode.train
        : sawBus && !sawTrain
        ? PublicTransportMode.bus
        : _dominantJourneyMode(legs);

    final departureTime = _readRouteDepartureTime(route, rawParts);
    final arrivalTime = _readRouteArrivalTime(route, rawParts);
    final durationMinutes =
        _readDurationMinutes(route) ?? _estimatePlanDurationMinutes(legs);

    return TransitJourneyPlan(
      mode: mode,
      legs: legs,
      durationMinutes: durationMinutes,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      statusText: _readJourneyStatus(route),
    );
  }

  DateTime? _readRouteDepartureTime(
      Map<String, dynamic> route,
      List<dynamic> rawParts,
      ) {
    final routeTime = _tryParseDateTime(
      route['departure_time'] ??
          route['depart_at'] ??
          route['departure'] ??
          route['departure_datetime'],
    );

    if (routeTime != null) {
      return routeTime;
    }

    for (final rawPart in rawParts) {
      final part = _asMap(rawPart);
      if (part == null) {
        continue;
      }

      final partTime = _tryParseDateTime(
        part['departure_time'] ??
            part['depart_at'] ??
            part['departure'] ??
            part['departure_datetime'],
      );

      if (partTime != null) {
        return partTime;
      }
    }

    return null;
  }

  DateTime? _readRouteArrivalTime(
      Map<String, dynamic> route,
      List<dynamic> rawParts,
      ) {
    final routeTime = _tryParseDateTime(
      route['arrival_time'] ??
          route['arrive_at'] ??
          route['arrival'] ??
          route['arrival_datetime'],
    );

    if (routeTime != null) {
      return routeTime;
    }

    for (final rawPart in rawParts.reversed) {
      final part = _asMap(rawPart);
      if (part == null) {
        continue;
      }

      final partTime = _tryParseDateTime(
        part['arrival_time'] ??
            part['arrive_at'] ??
            part['arrival'] ??
            part['arrival_datetime'],
      );

      if (partTime != null) {
        return partTime;
      }
    }

    return null;
  }

  String? _readJourneyStatus(Map<String, dynamic> route) {
    final delayed = route['delayed'];
    if (delayed == true) {
      return 'Delayed';
    }

    return _nullIfBlank(
      _readFirstString(
        route,
        const ['status', 'warning', 'remarks', 'note', 'notes', 'message'],
      ),
    );
  }

  PublicTransportMode _dominantJourneyMode(List<TransitJourneyLeg> legs) {
    final busDistance = legs
        .where((e) => e.type == TransitLegType.bus)
        .fold<double>(0.0, (sum, leg) => sum + leg.distanceMeters);

    final trainDistance = legs
        .where((e) => e.type == TransitLegType.train)
        .fold<double>(0.0, (sum, leg) => sum + leg.distanceMeters);

    return trainDistance > busDistance
        ? PublicTransportMode.train
        : PublicTransportMode.bus;
  }

  double _firstWalkDistance(TransitJourneyPlan plan) {
    if (plan.legs.isEmpty) {
      return 0;
    }
    final first = plan.legs.first;
    return first.type == TransitLegType.walk ? first.distanceMeters : 0;
  }

  double _lastWalkDistance(TransitJourneyPlan plan) {
    if (plan.legs.isEmpty) {
      return 0;
    }
    final last = plan.legs.last;
    return last.type == TransitLegType.walk ? last.distanceMeters : 0;
  }

  double _scoreJourneyPlan(
      TransitJourneyPlan plan, {
        double? directDistanceMeters,
      }) {
    var score = plan.effectiveDurationMinutes > 0
        ? plan.effectiveDurationMinutes * 1000.0
        : plan.totalDistanceMeters;

    score += plan.interchangeCount * 9000;
    score += plan.totalWalkingDistanceMeters * 3.0;
    score += plan.estimatedCo2Kg * 1200.0;

    if (plan.hasTrain) {
      score += _railFeederPenalty(plan);
    }

    if (directDistanceMeters != null && directDistanceMeters > 60000) {
      if (!plan.hasTrain) {
        score += 30000;
      }

      if (plan.totalTransitDistanceMeters > 0) {
        final ratio = plan.totalTransitDistanceMeters / directDistanceMeters;
        if (ratio > 1.8) {
          score += (ratio - 1.8) * 18000;
        }
      }
    }

    return score;
  }

  double _railFeederPenalty(TransitJourneyPlan plan) {
    final transitLegs =
    plan.legs.where((leg) => leg.isTransit).toList(growable: false);
    final firstTrainIndex =
    transitLegs.indexWhere((leg) => leg.type == TransitLegType.train);

    if (firstTrainIndex == -1) {
      return 0;
    }

    final lastTrainIndex =
    transitLegs.lastIndexWhere((leg) => leg.type == TransitLegType.train);

    final busesBefore = transitLegs
        .take(firstTrainIndex)
        .where((leg) => leg.type == TransitLegType.bus)
        .length;

    final busesAfter = transitLegs
        .skip(lastTrainIndex + 1)
        .where((leg) => leg.type == TransitLegType.bus)
        .length;

    final totalBusLegs =
        transitLegs.where((leg) => leg.type == TransitLegType.bus).length;

    var penalty = 0.0;

    if (busesBefore > 1) {
      penalty += (busesBefore - 1) * 12000;
    }
    if (busesAfter > 1) {
      penalty += (busesAfter - 1) * 9000;
    }
    if (totalBusLegs > 2) {
      penalty += (totalBusLegs - 2) * 7000;
    }

    return penalty;
  }

  PublicTransportMode? _chooseRecommendedMode(
      TransitPairResult? bus,
      TransitPairResult? train,
      ) {
    final busOk = _isUsablePair(bus);
    final trainOk = _isUsablePair(train);

    if (!busOk && !trainOk) {
      return null;
    }
    if (busOk && !trainOk) {
      return PublicTransportMode.bus;
    }
    if (trainOk && !busOk) {
      return PublicTransportMode.train;
    }

    final busScore = _scoreTransitPair(bus!, PublicTransportMode.bus);
    final trainScore = _scoreTransitPair(train!, PublicTransportMode.train);

    return trainScore < busScore
        ? PublicTransportMode.train
        : PublicTransportMode.bus;
  }

  bool _isUsablePair(TransitPairResult? pair) {
    if (pair == null || !pair.hasBoth || !pair.isRealData) {
      return false;
    }

    final a = pair.fromOrigin!;
    final b = pair.toDestination!;

    if (!a.isReal || !b.isReal) {
      return false;
    }
    if (a.name.trim().isEmpty || b.name.trim().isEmpty) {
      return false;
    }
    if (_sameAccessPoint(a, b)) {
      return false;
    }

    final plan = pair.journeyPlan;
    if (plan != null && !plan.hasLegs) {
      return false;
    }

    return true;
  }

  bool _sameAccessPoint(TransitAccessPoint a, TransitAccessPoint b) {
    final ac = a.code?.trim();
    final bc = b.code?.trim();

    if (ac != null && bc != null && ac.isNotEmpty && bc.isNotEmpty) {
      return ac.toLowerCase() == bc.toLowerCase();
    }

    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

    return norm(a.name) == norm(b.name);
  }

  double _scoreTransitPair(TransitPairResult pair, PublicTransportMode mode) {
    final journey = pair.journeyPlan;
    if (journey != null && journey.hasLegs) {
      return _scoreJourneyPlan(journey);
    }

    final access = pair.accessDistanceMeters ?? 999999;
    final line = pair.lineDistanceMeters ?? 999999;

    var score = access + line;

    if (mode == PublicTransportMode.train) {
      if (line >= 12000) {
        score -= 2500;
      }
      if (access > 2500) {
        score += 1500;
      }
    } else {
      if (line >= 12000) {
        score += 3000;
      }
      if (access <= 800) {
        score -= 800;
      }
    }

    return score;
  }

  FareEstimate? _estimateFareForMode(
      PublicTransportMode? mode,
      TransitPairResult? pair,
      ) {
    if (mode == null || pair == null || !_isUsablePair(pair)) {
      return null;
    }
    return mode == PublicTransportMode.train
        ? _estimateTrainFare(pair)
        : _estimateBusFare(pair);
  }

  FareEstimate _estimateFareForPlan(TransitJourneyPlan plan) {
    return plan.hasTrain
        ? _estimateTrainFareForMeters(plan.totalTransitDistanceMeters)
        : _estimateBusFareForMeters(plan.totalTransitDistanceMeters);
  }

  FareEstimate _estimateTrainFare(TransitPairResult pair) {
    final meters =
        pair.journeyPlan?.totalTransitDistanceMeters ?? pair.lineDistanceMeters ?? 0;
    return _estimateTrainFareForMeters(meters);
  }

  FareEstimate _estimateBusFare(TransitPairResult pair) {
    final meters =
        pair.journeyPlan?.totalTransitDistanceMeters ?? pair.lineDistanceMeters ?? 0;
    return _estimateBusFareForMeters(meters);
  }

  FareEstimate _estimateTrainFareForMeters(double meters) {
    final km = meters / 1000.0;

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

  FareEstimate _estimateBusFareForMeters(double meters) {
    final km = meters / 1000.0;

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

  String? _extractApiReason(Map<String, dynamic> data) {
    final routes = data['routes'];
    if (routes is List && routes.isNotEmpty) {
      return null;
    }

    final explicitError =
    _nullIfBlank(_readFirstString(data, const ['error', 'message']));
    if (explicitError != null) {
      return explicitError;
    }

    final identification = _asMap(data['identification']);
    final fromOptions =
    identification == null ? null : _asMap(identification['from_options']);
    final toOptions =
    identification == null ? null : _asMap(identification['to_options']);

    final fromError =
    fromOptions == null ? null : _nullIfBlank(_readFirstString(fromOptions, const ['error']));
    final toError =
    toOptions == null ? null : _nullIfBlank(_readFirstString(toOptions, const ['error']));

    if (fromError != null || toError != null) {
      return 'Journey planner could not resolve from/to: '
          'from=${fromError ?? 'ok'}, to=${toError ?? 'ok'}';
    }

    return null;
  }

  double? _readDistanceMeters(Map<String, dynamic> item) {
    const keys = [
      'distance',
      'distance_meters',
      'dist',
      'walking_distance',
      'distance_from_origin',
      'distance_to_destination',
    ];

    for (final key in keys) {
      final value = item[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    final distanceMap = _asMap(item['distance']);
    if (distanceMap != null) {
      final meters = distanceMap['meters'];
      if (meters is num) {
        return meters.toDouble();
      }
      if (meters is String) {
        return double.tryParse(meters);
      }
    }

    return null;
  }

  int? _readDurationMinutes(Map<String, dynamic> item) {
    const keys = [
      'duration_minutes',
      'duration',
      'total_time',
      'travel_time',
      'journey_time',
      'time',
      'total_duration',
    ];

    for (final key in keys) {
      final parsed = _parseDurationValue(item[key]);
      if (parsed != null) {
        return parsed;
      }
    }

    final durationMap = _asMap(item['duration']);
    if (durationMap != null) {
      for (final key in const ['minutes', 'mins', 'seconds', 'value']) {
        final parsed = _parseDurationValue(durationMap[key]);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    final departure = _tryParseDateTime(item['departure_time'] ?? item['depart_at']);
    final arrival = _tryParseDateTime(item['arrival_time'] ?? item['arrive_at']);
    if (departure != null && arrival != null && arrival.isAfter(departure)) {
      return arrival.difference(departure).inMinutes;
    }

    return null;
  }

  int? _parseDurationValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final numeric = value.toDouble();
      if (numeric <= 0) {
        return null;
      }
      if (numeric > 720) {
        return (numeric / 60).round();
      }
      return numeric.round();
    }

    if (value is! String) {
      return null;
    }

    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }

    if (RegExp(r'^\d+$').hasMatch(text)) {
      final numeric = double.tryParse(text);
      if (numeric == null || numeric <= 0) {
        return null;
      }
      if (numeric > 720) {
        return (numeric / 60).round();
      }
      return numeric.round();
    }

    final hhmm = RegExp(r'^(\d+):(\d{2})(?::(\d{2}))?$').firstMatch(text);
    if (hhmm != null) {
      final hours = int.parse(hhmm.group(1)!);
      final minutes = int.parse(hhmm.group(2)!);
      final seconds = int.tryParse(hhmm.group(3) ?? '0') ?? 0;
      return (hours * 60) + minutes + (seconds >= 30 ? 1 : 0);
    }

    final iso = RegExp(
      r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (iso != null) {
      final hours = int.tryParse(iso.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(iso.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(iso.group(3) ?? '0') ?? 0;
      return (hours * 60) + minutes + (seconds >= 30 ? 1 : 0);
    }

    final verbose = RegExp(
      r'(?:(\d+)\s*h(?:ours?)?)?\s*(?:(\d+)\s*m(?:in(?:utes?)?)?)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (verbose != null) {
      final hours = int.tryParse(verbose.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(verbose.group(2) ?? '0') ?? 0;
      final total = (hours * 60) + minutes;
      if (total > 0) {
        return total;
      }
    }

    return null;
  }

  DateTime? _tryParseDateTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.trim())?.toLocal();
  }

  int _estimatePlanDurationMinutes(List<TransitJourneyLeg> legs) {
    final total = legs.fold<int>(
      0,
          (sum, leg) => sum + math.max(1, leg.durationMinutes),
    );
    return math.max(1, total);
  }

  int _estimateLegDurationMinutes({
    required TransitLegType type,
    required double distanceMeters,
  }) {
    if (distanceMeters <= 0) {
      return type == TransitLegType.walk ? 4 : 8;
    }

    final speedMetersPerMinute = switch (type) {
      TransitLegType.walk => 80.0,
      TransitLegType.bus => 350.0,
      TransitLegType.train => 1000.0,
    };

    final base = distanceMeters / speedMetersPerMinute;
    final boarding = type == TransitLegType.walk ? 0 : 3;
    return math.max(1, (base + boarding).round());
  }

  String _readFirstString(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }

      final nested = _asMap(value);
      if (nested != null) {
        final nestedName =
            nested['name'] ?? nested['code'] ?? nested['id'] ?? nested['value'];
        if (nestedName is String && nestedName.trim().isNotEmpty) {
          return nestedName.trim();
        }
        if (nestedName is num) {
          return nestedName.toString();
        }
      }
    }
    return '';
  }

  String _readPlaceName(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      final nested = _asMap(value);
      if (nested != null) {
        final candidates = [
          nested['name'],
          nested['description'],
          nested['station_name'],
          nested['stop_name'],
          nested['title'],
        ];

        for (final candidate in candidates) {
          if (candidate is String && candidate.trim().isNotEmpty) {
            return candidate.trim();
          }
        }
      }
    }
    return '';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return value.map(
            (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  bool _looksLikeWalk(String modeText) {
    return modeText.contains('walk') ||
        modeText.contains('foot') ||
        modeText == 'walking';
  }

  bool _looksLikeTrain(String modeText, Map<String, dynamic> leg) {
    if (modeText.contains('train') ||
        modeText.contains('rail') ||
        modeText.contains('tube') ||
        modeText.contains('tram') ||
        modeText.contains('underground')) {
      return true;
    }

    final route = _readFirstString(
      leg,
      const ['route_name', 'line_name', 'description', 'operator_name', 'line'],
    ).toLowerCase();

    return route.contains('rail') ||
        route.contains('train') ||
        route.contains('tube') ||
        route.contains('tram');
  }

  bool _looksLikeBus(String modeText, Map<String, dynamic> leg) {
    if (modeText.contains('bus') || modeText.contains('coach')) {
      return true;
    }

    final route = _readFirstString(
      leg,
      const ['route_name', 'line_name', 'description', 'operator_name', 'line'],
    ).toLowerCase();

    return route.contains('bus') || route.contains('coach');
  }

  String? _nullIfBlank(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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