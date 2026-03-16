class RouteOption {
  final String mode;
  final String tag;
  final int durationMinutes;
  final double distanceMeters;
  final double? estimatedCost;
  final double co2Kg;
  final String description;
  final String source;

  const RouteOption({
    required this.mode,
    required this.tag,
    required this.durationMinutes,
    required this.distanceMeters,
    required this.estimatedCost,
    required this.co2Kg,
    required this.description,
    required this.source,
  });
}