// lib/features/routes/route_option.dart
import 'package:flutter/foundation.dart';

@immutable
class RouteOptionAction {
  final String label;
  final Uri uri;

  const RouteOptionAction({
    required this.label,
    required this.uri,
  });
}

@immutable
class RouteOption {
  final String mode;
  final String tag;
  final int durationMinutes;
  final double distanceMeters;
  final double? estimatedCost; // keep for exact costs (walk=0, etc.)
  final String? costText; // use for ranges like "£6.00–£22.00"
  final double co2Kg;
  final String description;
  final String source;

  final RouteOptionAction? primaryAction;
  final RouteOptionAction? secondaryAction;

  const RouteOption({
    required this.mode,
    required this.tag,
    required this.durationMinutes,
    required this.distanceMeters,
    required this.estimatedCost,
    required this.co2Kg,
    required this.description,
    required this.source,
    this.costText,
    this.primaryAction,
    this.secondaryAction,
  });
}