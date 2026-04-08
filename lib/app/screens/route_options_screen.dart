// lib/screens/routes/route_options_screen.dart
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/routes/route_option.dart';
import '../../features/themes/atlas_theme.dart';
import '../../services/routeservice.dart';
import '../../services/transitrouteservice.dart';

class RouteOptionsScreen extends StatefulWidget {
  final String destinationName;
  final LatLng destination;
  final LatLng? origin;
  final DateTime? departureTime;

  const RouteOptionsScreen({
    super.key,
    required this.destinationName,
    required this.destination,
    required this.origin,
    this.departureTime,
  });

  @override
  State<RouteOptionsScreen> createState() => _RouteOptionsScreenState();
}

class _RouteOptionsScreenState extends State<RouteOptionsScreen> {
  final RouteOptionsService _routeOptionsService = RouteOptionsService();

  bool _loading = true;
  List<RouteOption> _options = [];
  PublicTransportResult? _publicTransportResult;
  String? _error;

  double? get _drivingCo2Kg {
    for (final option in _options) {
      if (option.mode.toLowerCase() == 'drive') {
        return option.co2Kg;
      }
    }
    return null;
  }

  double? get _bestPublicTransportCo2Kg {
    final journeys = _publicTransportResult?.journeyOptions;
    if (journeys == null || journeys.isEmpty) {
      return null;
    }

    var best = journeys.first.plan.estimatedCo2Kg;
    for (final journey in journeys.skip(1)) {
      if (journey.plan.estimatedCo2Kg < best) {
        best = journey.plan.estimatedCo2Kg;
      }
    }
    return best;
  }

  double? get _lowestMotorisedCo2Kg {
    double? best;

    for (final option in _options) {
      if (_isWalkMode(option.mode)) {
        continue;
      }

      final candidate = option.co2Kg;
      if (best == null || candidate < best) {
        best = candidate;
      }
    }

    final transitBest = _bestPublicTransportCo2Kg;
    if (!_containsPublicTransportOption(_options) && transitBest != null) {
      if (best == null || transitBest < best) {
        best = transitBest;
      }
    }

    return best;
  }

  bool get _publicTransportIsEcoBest {
    final transitCo2 = _bestPublicTransportCo2Kg;
    final lowestMotorisedCo2 = _lowestMotorisedCo2Kg;

    if (transitCo2 == null || lowestMotorisedCo2 == null) {
      return false;
    }

    return transitCo2 <= lowestMotorisedCo2 + 0.0001;
  }

  bool _isWalkMode(String mode) {
    return mode.trim().toLowerCase() == 'walk';
  }

  bool _isPublicTransportMode(String mode) {
    final normalized = mode.trim().toLowerCase();
    return normalized == 'public transport' || normalized == 'transit';
  }

  bool _containsPublicTransportOption(List<RouteOption> options) {
    return options.any((option) => _isPublicTransportMode(option.mode));
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _routeOptionsService.buildOptions(
        origin: widget.origin,
        destination: widget.destination,
        destinationName: widget.destinationName,
        departureTime: widget.departureTime,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _options = result.options;
        _publicTransportResult = result.publicTransportResult;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDepartureContext() {
    final selected = widget.departureTime;
    if (selected == null) {
      return 'Leave now';
    }

    final hour = selected.hour.toString().padLeft(2, '0');
    final minute = selected.minute.toString().padLeft(2, '0');
    return 'Leave $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    final hasEmbeddedTransitOption = _containsPublicTransportOption(_options);
    final showStandaloneTransitCard =
        !hasEmbeddedTransitOption &&
            widget.origin != null &&
            _publicTransportResult != null;

    return Scaffold(
      backgroundColor: atlas.background,
      appBar: AppBar(
        backgroundColor: atlas.background,
        foregroundColor: atlas.textPrimary,
        elevation: 0,
        surfaceTintColor: atlas.background,
        title: Text(
          widget.destinationName,
          style: tt.titleLarge?.copyWith(
            color: atlas.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: atlas.border),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? Center(
          child: CircularProgressIndicator(color: atlas.brandPrimary),
        )
            : _error != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: atlas.surface,
                border: Border.all(color: atlas.border),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                _error!,
                style: tt.bodyMedium?.copyWith(
                  color: atlas.danger,
                  height: 1.4,
                ),
              ),
            ),
          ),
        )
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _ResultsHeaderCard(
              title: 'Journey options',
              subtitle:
              'Compare time, cost and environmental impact before you go.',
              departureLabel: _formatDepartureContext(),
              countLabel: _options.isEmpty && !showStandaloneTransitCard
                  ? 'No options yet'
                  : '${_options.length + (showStandaloneTransitCard ? 1 : 0)} options',
            ),
            const SizedBox(height: 18),
            if (_options.isEmpty && !showStandaloneTransitCard)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: atlas.surface,
                  border: Border.all(color: atlas.border),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'No route options available yet.',
                  style: tt.bodyMedium?.copyWith(
                    color: atlas.textSecondary,
                    height: 1.4,
                  ),
                ),
              )
            else ...[
              ..._options.map(
                    (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RouteOptionCard(
                    destinationName: widget.destinationName,
                    destination: widget.destination,
                    origin: widget.origin,
                    option: option,
                    publicTransportResult: _isPublicTransportMode(option.mode)
                        ? _publicTransportResult
                        : null,
                    drivingCo2Kg: _drivingCo2Kg,
                    showBestForEnvironmentSticker:
                    _isPublicTransportMode(option.mode) &&
                        _publicTransportIsEcoBest,
                  ),
                ),
              ),
              if (showStandaloneTransitCard)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StandalonePublicTransportCard(
                    destinationName: widget.destinationName,
                    result: _publicTransportResult!,
                    drivingCo2Kg: _drivingCo2Kg,
                    showBestForEnvironmentSticker:
                    _publicTransportIsEcoBest,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultsHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String departureLabel;
  final String countLabel;

  const _ResultsHeaderCard({
    required this.title,
    required this.subtitle,
    required this.departureLabel,
    required this.countLabel,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: atlas.surfaceFeatured,
        border: Border.all(color: atlas.border),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 8),
            color: Color(0x10000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.headlineSmall?.copyWith(
              color: atlas.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: tt.bodyMedium?.copyWith(
              color: atlas.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                icon: Icons.schedule_rounded,
                label: departureLabel,
              ),
              _InfoPill(
                icon: Icons.route_rounded,
                label: countLabel,
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;

  const _InfoPill({
    required this.icon,
    required this.label,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: filled
            ? atlas.brandHighlight.withOpacity(0.95)
            : atlas.surface.withOpacity(0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: atlas.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: atlas.textPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: atlas.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  final String destinationName;
  final LatLng destination;
  final LatLng? origin;
  final RouteOption option;
  final PublicTransportResult? publicTransportResult;
  final double? drivingCo2Kg;
  final bool showBestForEnvironmentSticker;

  const _RouteOptionCard({
    required this.destinationName,
    required this.destination,
    required this.origin,
    required this.option,
    this.publicTransportResult,
    this.drivingCo2Kg,
    this.showBestForEnvironmentSticker = false,
  });

  bool _isPublicTransportMode(String mode) {
    final normalized = mode.trim().toLowerCase();
    return normalized == 'public transport' || normalized == 'transit';
  }

  bool _isWalkMode(String mode) {
    return mode.trim().toLowerCase() == 'walk';
  }

  bool _supportsAppleMaps(String mode) {
    final normalized = mode.trim().toLowerCase();
    return normalized == 'walk' || normalized == 'drive';
  }

  IconData _iconForMode(String mode) {
    switch (mode.trim().toLowerCase()) {
      case 'walk':
        return Icons.directions_walk_rounded;
      case 'drive':
        return Icons.directions_car_filled_rounded;
      case 'public transport':
      case 'transit':
        return Icons.directions_transit_rounded;
      default:
        return Icons.route_rounded;
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;

    if (hours <= 0) {
      return '$minutes min';
    }
    if (remainder == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainder}m';
  }

  bool _shouldShowTime(RouteOption option) {
    if (_isPublicTransportMode(option.mode)) {
      return false;
    }
    return option.durationMinutes > 0;
  }

  String _formatPublicTransportFareRange(double distanceMeters) {
    final km = distanceMeters / 1000.0;

    double minFare;
    double maxFare;

    if (km <= 3) {
      minFare = 1.80;
      maxFare = 2.50;
    } else if (km <= 8) {
      minFare = 2.00;
      maxFare = 3.50;
    } else if (km <= 20) {
      minFare = 2.50;
      maxFare = 5.50;
    } else {
      minFare = 4.00;
      maxFare = 8.50;
    }

    return '£${minFare.toStringAsFixed(2)}–£${maxFare.toStringAsFixed(2)}';
  }

  String _formatCost(RouteOption option) {
    if (option.costText != null && option.costText!.trim().isNotEmpty) {
      return option.costText!;
    }

    if (option.estimatedCost != null) {
      return '£${option.estimatedCost!.toStringAsFixed(2)}';
    }

    if (_isPublicTransportMode(option.mode)) {
      return _formatPublicTransportFareRange(option.distanceMeters);
    }

    return '—';
  }

  Future<void> _launchExternal(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<String> _descriptionLines(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  TransitJourneyOption? _quickestOption(List<TransitJourneyOption> options) {
    if (options.isEmpty) {
      return null;
    }

    var best = options.first;
    for (final option in options.skip(1)) {
      if (option.plan.effectiveDurationMinutes <
          best.plan.effectiveDurationMinutes) {
        best = option;
      }
    }
    return best;
  }

  TransitJourneyOption? _greenestOption(List<TransitJourneyOption> options) {
    if (options.isEmpty) {
      return null;
    }

    var best = options.first;
    for (final option in options.skip(1)) {
      if (option.plan.estimatedCo2Kg < best.plan.estimatedCo2Kg) {
        best = option;
      }
    }
    return best;
  }

  Uri _appleMapsUri() {
    final normalized = option.mode.trim().toLowerCase();
    final dirflg = normalized == 'walk' ? 'w' : 'd';

    return Uri.https(
      'maps.apple.com',
      '/',
      <String, String>{
        'daddr': '${destination.latitude},${destination.longitude}',
        'dirflg': dirflg,
        'q': destinationName,
        if (origin != null) 'saddr': '${origin!.latitude},${origin!.longitude}',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    final showJourneyList =
        option.isFeatured && publicTransportResult?.journeyOptions.isNotEmpty == true;

    final transitOptions = showJourneyList
        ? publicTransportResult!.journeyOptions.take(3).toList()
        : const <TransitJourneyOption>[];

    final quickestTransitOption = _quickestOption(transitOptions);
    final greenestTransitOption = _greenestOption(transitOptions);
    final firstTransitOption =
    transitOptions.isEmpty ? null : transitOptions.first;

    final displayCo2Kg = showJourneyList && greenestTransitOption != null
        ? greenestTransitOption.plan.estimatedCo2Kg
        : option.co2Kg;

    final showTime = _shouldShowTime(option);
    final primaryTagLabel = showJourneyList ? 'Next 3 journeys' : option.tag;

    final metrics = <Widget>[
      if (showJourneyList && firstTransitOption != null)
        _MetricTile(
          label: 'Next',
          value: _formatClock(firstTransitOption.plan.departureTime) ?? 'Live',
        )
      else if (showTime)
        _MetricTile(label: 'Time', value: '${option.durationMinutes} min'),
      _MetricTile(
        label: showJourneyList ? 'Fastest' : 'Cost',
        value: showJourneyList && quickestTransitOption != null
            ? _formatMinutes(quickestTransitOption.plan.effectiveDurationMinutes)
            : _formatCost(option),
      ),
      _MetricTile(
        label: showJourneyList ? 'Lowest CO₂' : 'CO₂',
        value: _formatCo2Value(displayCo2Kg),
      ),
      _MetricTile(
        label: 'Distance',
        value: _formatDistance(
          quickestTransitOption?.plan.totalDistanceMeters ?? option.distanceMeters,
        ),
      ),
    ];

    final actions = <RouteOptionAction>[
      if (option.primaryAction != null) option.primaryAction!,
      if (option.secondaryAction != null) option.secondaryAction!,
    ];

    final hasAppleMapsAction = _supportsAppleMaps(option.mode);

    return Container(
      padding: EdgeInsets.all(option.isFeatured ? 20 : 16),
      decoration: BoxDecoration(
        color: option.isFeatured
            ? atlas.surfaceFeatured
            : atlas.surface.withOpacity(0.88),
        border: Border.all(
          color: showBestForEnvironmentSticker
              ? atlas.brandHighlight.withOpacity(0.95)
              : atlas.border,
          width: showBestForEnvironmentSticker
              ? 1.6
              : option.isFeatured
              ? 1.4
              : 1,
        ),
        borderRadius: BorderRadius.circular(option.isFeatured ? 26 : 22),
        boxShadow: option.isFeatured
            ? const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          ),
        ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: option.isFeatured ? 44 : 40,
                height: option.isFeatured ? 44 : 40,
                decoration: BoxDecoration(
                  color: atlas.brandTertiary.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _iconForMode(option.mode),
                  color: atlas.textPrimary,
                  size: option.isFeatured ? 24 : 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.mode,
                      style: tt.titleLarge?.copyWith(
                        color: atlas.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: option.isFeatured ? 20 : 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (primaryTagLabel.trim().isNotEmpty)
                          _TagChip(
                            label: primaryTagLabel,
                            filled: option.isFeatured,
                          ),
                        if (showBestForEnvironmentSticker)
                          const _EcoStickerChip(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: option.isFeatured ? 18 : 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metrics
                .map(
                  (metric) => SizedBox(
                width: option.isFeatured ? 148 : 132,
                child: metric,
              ),
            )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          _EnvironmentalImpactCard(
            co2Kg: displayCo2Kg,
            drivingCo2Kg: drivingCo2Kg,
            isDriving: option.mode.trim().toLowerCase() == 'drive',
            isWalking: _isWalkMode(option.mode),
            highlightBest: showBestForEnvironmentSticker,
          ),
          SizedBox(height: option.isFeatured ? 16 : 14),
          if (showJourneyList)
            _PublicTransportJourneyList(
              destinationName: destinationName,
              result: publicTransportResult!,
              drivingCo2Kg: drivingCo2Kg,
            )
          else
            ..._descriptionLines(option.description).map(
                  (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line,
                  style: tt.bodyMedium?.copyWith(
                    color: atlas.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 14,
                color: atlas.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  option.source,
                  style: tt.bodySmall?.copyWith(
                    color: atlas.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (showJourneyList) ...[
            const SizedBox(height: 14),
            _ActionButton(
              label: 'Buy tickets',
              icon: Icons.confirmation_num_outlined,
              filled: true,
              onPressed: () => _launchExternal(
                _ticketWebsiteUriForResult(publicTransportResult!),
              ),
            ),
          ] else if (actions.isNotEmpty || hasAppleMapsAction) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (hasAppleMapsAction)
                  _ActionButton(
                    label: 'Open in Apple Maps',
                    icon: Icons.map_outlined,
                    filled: true,
                    onPressed: () => _launchExternal(_appleMapsUri()),
                  ),
                ...actions.map(
                      (action) => _ActionButton(
                    label: action.label,
                    icon: Icons.open_in_new_rounded,
                    onPressed: () => _launchExternal(action.uri),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StandalonePublicTransportCard extends StatelessWidget {
  final String destinationName;
  final PublicTransportResult result;
  final double? drivingCo2Kg;
  final bool showBestForEnvironmentSticker;

  const _StandalonePublicTransportCard({
    required this.destinationName,
    required this.result,
    required this.drivingCo2Kg,
    this.showBestForEnvironmentSticker = false,
  });

  TransitJourneyOption? _quickestOption(List<TransitJourneyOption> options) {
    if (options.isEmpty) {
      return null;
    }

    var best = options.first;
    for (final option in options.skip(1)) {
      if (option.plan.effectiveDurationMinutes <
          best.plan.effectiveDurationMinutes) {
        best = option;
      }
    }
    return best;
  }

  TransitJourneyOption? _greenestOption(List<TransitJourneyOption> options) {
    if (options.isEmpty) {
      return null;
    }

    var best = options.first;
    for (final option in options.skip(1)) {
      if (option.plan.estimatedCo2Kg < best.plan.estimatedCo2Kg) {
        best = option;
      }
    }
    return best;
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;

    if (hours <= 0) {
      return '$minutes min';
    }
    if (remainder == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainder}m';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _message() {
    final reason = result.debugReason?.trim();
    if (reason != null && reason.isNotEmpty) {
      return 'No public transport journey was returned.\n$reason';
    }
    return 'No public transport journey was returned for this trip.';
  }

  Future<void> _launchExternal(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    final transitOptions = result.journeyOptions.take(3).toList(growable: false);
    final hasJourneys = transitOptions.isNotEmpty;
    final firstTransitOption = hasJourneys ? transitOptions.first : null;
    final quickestTransitOption = _quickestOption(transitOptions);
    final greenestTransitOption = _greenestOption(transitOptions);
    final displayCo2Kg = greenestTransitOption?.plan.estimatedCo2Kg;

    final metrics = <Widget>[
      if (hasJourneys && firstTransitOption != null)
        _MetricTile(
          label: 'Next',
          value: _formatClock(firstTransitOption.plan.departureTime) ?? 'Live',
        )
      else
        const _MetricTile(label: 'Status', value: 'Unavailable'),
      _MetricTile(
        label: hasJourneys ? 'Fastest' : 'Cost',
        value: hasJourneys && quickestTransitOption != null
            ? _formatMinutes(quickestTransitOption.plan.effectiveDurationMinutes)
            : '—',
      ),
      _MetricTile(
        label: hasJourneys ? 'Lowest CO₂' : 'CO₂',
        value: hasJourneys && displayCo2Kg != null
            ? _formatCo2Value(displayCo2Kg)
            : '—',
      ),
      _MetricTile(
        label: 'Distance',
        value: hasJourneys && quickestTransitOption != null
            ? _formatDistance(quickestTransitOption.plan.totalDistanceMeters)
            : '—',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: atlas.surface.withOpacity(0.88),
        border: Border.all(
          color: showBestForEnvironmentSticker
              ? atlas.brandHighlight.withOpacity(0.95)
              : atlas.border,
          width: showBestForEnvironmentSticker ? 1.6 : 1,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: atlas.brandTertiary.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.directions_transit_rounded,
                  color: atlas.textPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Public transport',
                      style: tt.titleLarge?.copyWith(
                        color: atlas.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TagChip(
                          label: hasJourneys ? 'Next 3 journeys' : 'Unavailable',
                        ),
                        if (showBestForEnvironmentSticker)
                          const _EcoStickerChip(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metrics
                .map(
                  (metric) => SizedBox(
                width: 132,
                child: metric,
              ),
            )
                .toList(growable: false),
          ),
          if (hasJourneys && displayCo2Kg != null) ...[
            const SizedBox(height: 14),
            _EnvironmentalImpactCard(
              co2Kg: displayCo2Kg,
              drivingCo2Kg: drivingCo2Kg,
              isDriving: false,
              isWalking: false,
              highlightBest: showBestForEnvironmentSticker,
            ),
          ],
          const SizedBox(height: 14),
          if (hasJourneys)
            _PublicTransportJourneyList(
              destinationName: destinationName,
              result: result,
              drivingCo2Kg: drivingCo2Kg,
            )
          else
            Text(
              _message(),
              style: tt.bodyMedium?.copyWith(
                color: atlas.textSecondary,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 14,
                color: atlas.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'TransportAPI',
                  style: tt.bodySmall?.copyWith(color: atlas.textSecondary),
                ),
              ),
            ],
          ),
          if (hasJourneys) ...[
            const SizedBox(height: 14),
            _ActionButton(
              label: 'Buy tickets',
              icon: Icons.confirmation_num_outlined,
              filled: true,
              onPressed: () => _launchExternal(_ticketWebsiteUriForResult(result)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublicTransportJourneyList extends StatelessWidget {
  final String destinationName;
  final PublicTransportResult result;
  final double? drivingCo2Kg;

  const _PublicTransportJourneyList({
    required this.destinationName,
    required this.result,
    required this.drivingCo2Kg,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    final options = result.journeyOptions.take(3).toList(growable: false);

    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transit is surfaced clearly here because it usually cuts emissions sharply compared with driving.',
          style: tt.bodySmall?.copyWith(
            color: atlas.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        ...List<Widget>.generate(
          options.length,
              (index) => Padding(
            padding: EdgeInsets.only(bottom: index == options.length - 1 ? 0 : 10),
            child: _TransitJourneyRow(
              destinationName: destinationName,
              option: options[index],
              drivingCo2Kg: drivingCo2Kg,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransitJourneyRow extends StatelessWidget {
  final String destinationName;
  final TransitJourneyOption option;
  final double? drivingCo2Kg;

  const _TransitJourneyRow({
    required this.destinationName,
    required this.option,
    required this.drivingCo2Kg,
  });

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;

    if (hours <= 0) {
      return '${minutes}m';
    }
    if (remainder == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainder}m';
  }

  String _footerText() {
    final parts = <String>[];

    final stop = option.plan.departureStopLabel;
    if (stop != null && stop.isNotEmpty) {
      parts.add('From $stop');
    }

    if (drivingCo2Kg != null && drivingCo2Kg! > 0) {
      final saved = drivingCo2Kg! - option.plan.estimatedCo2Kg;
      if (saved > 0) {
        final percent = ((saved / drivingCo2Kg!) * 100).round();
        parts.add(
          'Saves ${_formatCo2Value(saved)} CO₂ vs drive (${percent}% less)',
        );
      }
    }

    if (parts.isEmpty) {
      parts.add('Atlas eco estimate: ${_formatCo2Value(option.plan.estimatedCo2Kg)} CO₂');
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    final displayLegs = option.plan.displayLegs;

    return Material(
      color: atlas.surface.withOpacity(0.82),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransitJourneyDetailsScreen(
                destinationName: destinationName,
                option: option,
                drivingCo2Kg: drivingCo2Kg,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            border: Border.all(color: atlas.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatMinutes(option.plan.effectiveDurationMinutes),
                      style: tt.headlineSmall?.copyWith(
                        color: atlas.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total',
                      style: tt.labelSmall?.copyWith(
                        color: atlas.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _timeRangeLabel(option.plan),
                      style: tt.titleMedium?.copyWith(
                        color: atlas.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      children: _buildLegWidgets(displayLegs),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (option.tag != 'Option')
                          _InlinePill(
                            label: option.tag,
                            filled: option.tag == 'Lowest CO₂',
                          ),
                        _InlinePill(
                          label: 'CO₂ ${_formatCo2Value(option.plan.estimatedCo2Kg)}',
                        ),
                        _InlinePill(
                          label: option.plan.interchangeCount == 1
                              ? '1 change'
                              : '${option.plan.interchangeCount} changes',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _footerText(),
                      style: tt.bodySmall?.copyWith(
                        color: atlas.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLegWidgets(List<TransitJourneyLeg> legs) {
    final widgets = <Widget>[];

    for (var i = 0; i < legs.length; i++) {
      widgets.add(_JourneyLegChip(leg: legs[i]));

      if (i != legs.length - 1) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '›',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B6E6A),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  String _timeRangeLabel(TransitJourneyPlan plan) {
    final departure = _formatClock(plan.departureTime);
    final arrival = _formatClock(plan.arrivalTime);

    if (departure != null && arrival != null) {
      return '$departure - $arrival';
    }

    return '${plan.effectiveDurationMinutes} min total';
  }
}

class TransitJourneyDetailsScreen extends StatelessWidget {
  final String destinationName;
  final TransitJourneyOption option;
  final double? drivingCo2Kg;

  const TransitJourneyDetailsScreen({
    super.key,
    required this.destinationName,
    required this.option,
    required this.drivingCo2Kg,
  });

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _ecoInsight() {
    if (drivingCo2Kg == null || drivingCo2Kg! <= 0) {
      return 'Atlas eco estimate: this journey produces around ${_formatCo2Value(option.plan.estimatedCo2Kg)} CO₂.';
    }

    final saved = drivingCo2Kg! - option.plan.estimatedCo2Kg;
    if (saved <= 0) {
      return 'Atlas eco estimate: this journey is around ${_formatCo2Value(option.plan.estimatedCo2Kg)} CO₂.';
    }

    final percent = ((saved / drivingCo2Kg!) * 100).round();
    return 'Atlas eco estimate: this saves about ${_formatCo2Value(saved)} CO₂ compared with driving (${percent}% less).';
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;
    final steps = option.plan.displaySteps;

    return Scaffold(
      backgroundColor: atlas.background,
      appBar: AppBar(
        backgroundColor: atlas.background,
        foregroundColor: atlas.textPrimary,
        elevation: 0,
        surfaceTintColor: atlas.background,
        title: Text(
          destinationName,
          style: tt.titleLarge?.copyWith(
            color: atlas.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: atlas.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: atlas.surfaceFeatured,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: atlas.border),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  color: Color(0x12000000),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _TopMetric(
                      label: 'Time',
                      value: _timeRangeLabel(option.plan),
                    ),
                    _TopMetric(
                      label: 'CO₂',
                      value: _formatCo2Value(option.plan.estimatedCo2Kg),
                    ),
                    _TopMetric(
                      label: 'Distance',
                      value: _formatDistance(option.plan.totalDistanceMeters),
                    ),
                    _TopMetric(
                      label: 'Cost',
                      value: option.fareEstimate.formatted,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  option.plan.routeHeadline,
                  style: tt.titleLarge?.copyWith(
                    color: atlas.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _ecoInsight(),
                  style: tt.bodyMedium?.copyWith(
                    color: atlas.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                ...List<Widget>.generate(
                  steps.length,
                      (index) => Padding(
                    padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 12),
                    child: _TransportStepTile(
                      stepNumber: index + 1,
                      step: steps[index],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeRangeLabel(TransitJourneyPlan plan) {
    final departure = _formatClock(plan.departureTime);
    final arrival = _formatClock(plan.arrivalTime);

    if (departure != null && arrival != null) {
      return '$departure - $arrival';
    }

    final minutes = plan.effectiveDurationMinutes;
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;

    if (hours <= 0) {
      return '$minutes min';
    }
    if (remainder == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainder}m';
  }
}

class _JourneyLegChip extends StatelessWidget {
  final TransitJourneyLeg leg;

  const _JourneyLegChip({
    required this.leg,
  });

  IconData _iconForStep(TransitLegType type) {
    switch (type) {
      case TransitLegType.walk:
        return Icons.directions_walk_rounded;
      case TransitLegType.bus:
        return Icons.directions_bus_rounded;
      case TransitLegType.train:
        return Icons.train_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    final filled = leg.type != TransitLegType.walk;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: filled ? 10 : 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: filled
            ? atlas.brandTertiary.withOpacity(0.24)
            : atlas.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: atlas.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconForStep(leg.type),
            size: 17,
            color: atlas.textPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            leg.chipLabel,
            style: tt.labelLarge?.copyWith(
              fontSize: 13,
              color: atlas.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlinePill extends StatelessWidget {
  final String label;
  final bool filled;

  const _InlinePill({
    required this.label,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: filled
            ? atlas.brandHighlight.withOpacity(0.95)
            : atlas.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: atlas.border),
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(
          color: atlas.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TopMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TopMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return _MetricTile(label: label, value: value);
  }
}

class _TransportStepTile extends StatelessWidget {
  final int stepNumber;
  final TransitJourneyDisplayStep step;

  const _TransportStepTile({
    required this.stepNumber,
    required this.step,
  });

  IconData _iconForStep(TransitLegType type) {
    switch (type) {
      case TransitLegType.walk:
        return Icons.directions_walk_rounded;
      case TransitLegType.bus:
        return Icons.directions_bus_rounded;
      case TransitLegType.train:
        return Icons.train_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: atlas.surface.withOpacity(0.88),
        border: Border.all(color: atlas.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: atlas.brandTertiary.withOpacity(0.28),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: tt.labelLarge?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: atlas.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            _iconForStep(step.type),
            size: 22,
            color: atlas.textPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next step',
                  style: tt.labelMedium?.copyWith(
                    color: atlas.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.title,
                  style: tt.titleMedium?.copyWith(
                    color: atlas.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (step.subtitle != null && step.subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    step.subtitle!,
                    style: tt.bodySmall?.copyWith(
                      color: atlas.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: atlas.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: atlas.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: atlas.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              color: atlas.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool filled;

  const _TagChip({
    required this.label,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: filled
            ? atlas.brandHighlight.withOpacity(0.95)
            : atlas.brandTertiary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: atlas.border),
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(
          color: atlas.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EcoStickerChip extends StatelessWidget {
  const _EcoStickerChip();

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: atlas.brandHighlight.withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: atlas.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.eco_rounded,
            size: 15,
            color: atlas.textPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            'Best for environment',
            style: tt.labelMedium?.copyWith(
              color: atlas.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentalImpactCard extends StatelessWidget {
  final double co2Kg;
  final double? drivingCo2Kg;
  final bool isDriving;
  final bool isWalking;
  final bool highlightBest;

  const _EnvironmentalImpactCard({
    required this.co2Kg,
    required this.drivingCo2Kg,
    required this.isDriving,
    required this.isWalking,
    this.highlightBest = false,
  });

  double? _ratioToDriving() {
    if (drivingCo2Kg == null || drivingCo2Kg! <= 0) {
      return null;
    }

    final raw = co2Kg / drivingCo2Kg!;
    if (raw < 0) {
      return 0;
    }
    if (raw > 1) {
      return 1;
    }
    return raw;
  }

  String _comparisonCopy() {
    if (isWalking) {
      return 'No direct tailpipe emissions for this option.';
    }

    if (drivingCo2Kg == null || drivingCo2Kg! <= 0) {
      if (highlightBest) {
        return 'Lowest-carbon motorised option on this screen.';
      }
      return 'Atlas eco estimate for this journey.';
    }

    if (isDriving) {
      return 'Driving is the comparison baseline for the lower-carbon options.';
    }

    final saved = drivingCo2Kg! - co2Kg;
    final percent = ((saved.abs() / drivingCo2Kg!) * 100).round();

    if (saved > 0) {
      final prefix = highlightBest
          ? 'Lowest-carbon motorised option here. '
          : '';
      return '${prefix}Saves ${_formatCo2Value(saved)} CO₂ vs driving (${percent}% less).';
    }

    if (saved < 0) {
      return '${_formatCo2Value(saved.abs())} more CO₂ than driving (${percent}% more).';
    }

    return 'About the same CO₂ as driving.';
  }

  String? _ratioLabel() {
    if (drivingCo2Kg == null || drivingCo2Kg! <= 0) {
      return null;
    }

    if (isDriving) {
      return '100% of driving emissions';
    }

    final percent = ((co2Kg / drivingCo2Kg!) * 100).round();
    return '$percent% of driving emissions';
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;
    final ratio = _ratioToDriving();
    final ratioLabel = _ratioLabel();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: atlas.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlightBest
              ? atlas.brandHighlight.withOpacity(0.95)
              : atlas.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.eco_outlined,
                size: 18,
                color: atlas.textPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Environmental impact',
                  style: tt.labelLarge?.copyWith(
                    color: atlas.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatCo2Value(co2Kg),
                style: tt.titleLarge?.copyWith(
                  color: atlas.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _comparisonCopy(),
            style: tt.bodyMedium?.copyWith(
              color: atlas.textSecondary,
              height: 1.35,
            ),
          ),
          if (ratio != null && ratioLabel != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 8,
                color: atlas.border,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      color: atlas.brandHighlight.withOpacity(0.95),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ratioLabel,
              style: tt.bodySmall?.copyWith(
                color: atlas.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        height: 40,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

Uri _ticketWebsiteUriForResult(PublicTransportResult result) {
  final hasTrain = result.journeyOptions.any(
        (option) => option.plan.displayLegs.any(
          (leg) => leg.type == TransitLegType.train,
    ),
  );

  if (hasTrain) {
    return Uri.https('www.nationalrail.co.uk', '/journey-planner/');
  }

  return Uri.https('www.traveline.info', '/');
}

String? _formatClock(DateTime? value) {
  if (value == null) {
    return null;
  }
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatCo2Value(double value) {
  if (value < 1) {
    return '${(value * 1000).round()} g';
  }
  if (value >= 10) {
    return '${value.toStringAsFixed(1)} kg';
  }
  return '${value.toStringAsFixed(2)} kg';
}