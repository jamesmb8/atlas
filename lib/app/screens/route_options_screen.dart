

// lib/screens/routes/route_options_screen.dart
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/routes/route_option.dart';
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
  final TransitRouteService _transitRouteService = TransitRouteService();

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
      final optionsFuture = _routeOptionsService.buildOptions(
        origin: widget.origin,
        destination: widget.destination,
        destinationName: widget.destinationName,
      );

      Future<PublicTransportResult?> transportFuture() async {
        if (widget.origin == null) {
          return null;
        }

        try {
          return await _transitRouteService.getPublicTransportSummary(
            destinationName: widget.destinationName,
            origin: widget.origin!,
            destination: widget.destination,
            departureTime: widget.departureTime,
          );
        } catch (_) {
          return null;
        }
      }

      final options = await optionsFuture;
      final publicTransportResult = await transportFuture();

      if (!mounted) {
        return;
      }

      setState(() {
        _options = options;
        _publicTransportResult = publicTransportResult;
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
    const bg = Color(0xFFF7F6F2);
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);
    const border = Color(0xFFE3E4DE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: bg,
        iconTheme: const IconThemeData(color: primaryText),
        title: Text(
          widget.destinationName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: primaryText,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: border),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        )
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Journey options',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDepartureContext(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            if (_options.isEmpty)
              const Text(
                'No route options available yet.',
                style: TextStyle(
                  fontSize: 15,
                  color: secondaryText,
                ),
              )
            else
              ..._options.map(
                    (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RouteOptionCard(
                    destinationName: widget.destinationName,
                    option: option,
                    publicTransportResult:
                    option.mode.toLowerCase() == 'public transport'
                        ? _publicTransportResult
                        : null,
                    drivingCo2Kg: _drivingCo2Kg,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  final String destinationName;
  final RouteOption option;
  final PublicTransportResult? publicTransportResult;
  final double? drivingCo2Kg;

  const _RouteOptionCard({
    required this.destinationName,
    required this.option,
    this.publicTransportResult,
    this.drivingCo2Kg,
  });

  IconData _iconForMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'walk':
        return Icons.directions_walk_rounded;
      case 'drive':
        return Icons.directions_car_filled_rounded;
      case 'public transport':
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
      return '${minutes} min';
    }
    if (remainder == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainder}m';
  }

  String _formatCo2(double value) {
    return '${value.toStringAsFixed(2)} kg';
  }

  bool _shouldShowTime(RouteOption option) {
    if (option.mode.toLowerCase() == 'public transport') {
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

    if (option.mode.toLowerCase() == 'public transport') {
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

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);
    const accent = Color(0xFF9FC8B2);
    const featuredAccent = Color(0xFFE8F3EC);
    const border = Color(0xFFE3E4DE);

    final showJourneyList =
        publicTransportResult?.journeyOptions.isNotEmpty == true;

    final transitOptions =
    showJourneyList ? publicTransportResult!.journeyOptions.take(3).toList() : const <TransitJourneyOption>[];

    final quickestTransitOption = _quickestOption(transitOptions);
    final greenestTransitOption = _greenestOption(transitOptions);
    final firstTransitOption = transitOptions.isEmpty ? null : transitOptions.first;

    final showTime = _shouldShowTime(option);

    final metrics = <Widget>[
      if (showJourneyList && firstTransitOption != null)
        Metric(
          label: 'Next',
          value: _formatClock(firstTransitOption.plan.departureTime) ?? 'Live',
        )
      else if (showTime)
        Metric(label: 'Time', value: '${option.durationMinutes} min'),
      Metric(
        label: showJourneyList ? 'Fastest' : 'Cost',
        value: showJourneyList && quickestTransitOption != null
            ? _formatMinutes(quickestTransitOption.plan.effectiveDurationMinutes)
            : _formatCost(option),
      ),
      Metric(
        label: showJourneyList ? 'Lowest CO₂' : 'CO₂',
        value: showJourneyList && greenestTransitOption != null
            ? _formatCo2(greenestTransitOption.plan.estimatedCo2Kg)
            : '${option.co2Kg.toStringAsFixed(2)} kg',
      ),
      Metric(
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

    return Container(
      padding: EdgeInsets.all(option.isFeatured ? 20 : 16),
      decoration: BoxDecoration(
        color: option.isFeatured ? featuredAccent : Colors.white.withOpacity(0.55),
        border: Border.all(color: border, width: option.isFeatured ? 1.4 : 1),
        borderRadius: BorderRadius.circular(option.isFeatured ? 24 : 20),
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
            children: [
              Icon(
                _iconForMode(option.mode),
                color: primaryText,
                size: option.isFeatured ? 26 : 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.mode,
                  style: TextStyle(
                    fontSize: option.isFeatured ? 20 : 18,
                    fontWeight: FontWeight.w500,
                    color: primaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(option.isFeatured ? 0.32 : 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  showJourneyList ? 'Next 3 journeys' : option.tag,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: primaryText,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: option.isFeatured ? 18 : 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: metrics
                .map(
                  (m) => SizedBox(
                width: option.isFeatured ? 140 : 120,
                child: m,
              ),
            )
                .toList(growable: false),
          ),
          SizedBox(height: option.isFeatured ? 16 : 12),
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
                  style: TextStyle(
                    fontSize: option.isFeatured ? 15 : 14,
                    fontWeight: FontWeight.w400,
                    color: secondaryText,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            option.source,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: secondaryText,
            ),
          ),
          if (actions.isNotEmpty && !showJourneyList) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: actions
                  .map(
                    (a) => SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: () => _launchExternal(a.uri),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryText,
                      side: const BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      a.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
                  .toList(growable: false),
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
    final options = result.journeyOptions.take(3).toList(growable: false);

    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Atlas keeps transit fast, but still surfaces the lower-carbon option clearly.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B6E6A),
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

  String _formatCo2(double value) {
    return '${value.toStringAsFixed(2)} kg';
  }

  String _footerText() {
    final parts = <String>[];

    final stop = option.plan.departureStopLabel;
    if (stop != null && stop.isNotEmpty) {
      parts.add('From $stop');
    }

    if (drivingCo2Kg != null) {
      final saved = drivingCo2Kg! - option.plan.estimatedCo2Kg;
      if (saved > 0) {
        parts.add('Saves ${saved.toStringAsFixed(2)} kg CO₂ vs drive');
      }
    }

    if (parts.isEmpty) {
      parts.add('Atlas eco estimate: ${_formatCo2(option.plan.estimatedCo2Kg)}');
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);
    const border = Color(0xFFE3E4DE);

    final displayLegs = option.plan.displayLegs;

    return Material(
      color: Colors.white.withOpacity(0.7),
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
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  _formatMinutes(option.plan.effectiveDurationMinutes),
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.0,
                    fontWeight: FontWeight.w500,
                    color: primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _timeRangeLabel(option.plan),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: primaryText,
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
                        _InlinePill(label: 'CO₂ ${_formatCo2(option.plan.estimatedCo2Kg)}'),
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
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: secondaryText,
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
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '›',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B6E6A),
            ),
          ),
        ));
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

  String _formatCo2(double value) {
    return '${value.toStringAsFixed(2)} kg';
  }

  String _ecoInsight() {
    if (drivingCo2Kg == null) {
      return 'Atlas eco estimate: this journey produces around ${_formatCo2(option.plan.estimatedCo2Kg)}.';
    }

    final saved = drivingCo2Kg! - option.plan.estimatedCo2Kg;
    if (saved <= 0) {
      return 'Atlas eco estimate: this journey is around ${_formatCo2(option.plan.estimatedCo2Kg)}.';
    }

    return 'Atlas eco estimate: this saves about ${saved.toStringAsFixed(2)} kg CO₂ compared with driving.';
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF7F6F2);
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);
    const border = Color(0xFFE3E4DE);
    const accent = Color(0xFF9FC8B2);

    final steps = option.plan.displaySteps;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: bg,
        iconTheme: const IconThemeData(color: primaryText),
        title: Text(
          destinationName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: primaryText,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _TopMetric(
                      label: 'Time',
                      value: _timeRangeLabel(option.plan),
                    ),
                    _TopMetric(
                      label: 'CO₂',
                      value: _formatCo2(option.plan.estimatedCo2Kg),
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
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _ecoInsight(),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: secondaryText,
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
                      accent: accent,
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
      return '${minutes} min';
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
    const primaryText = Color(0xFF1F1F1F);
    const border = Color(0xFFE3E4DE);
    const accent = Color(0xFF9FC8B2);

    final filled = leg.type != TransitLegType.walk;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: filled ? 10 : 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: filled ? accent.withOpacity(0.22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconForStep(leg.type),
            size: 17,
            color: primaryText,
          ),
          const SizedBox(width: 6),
          Text(
            leg.chipLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: primaryText,
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
    const primaryText = Color(0xFF1F1F1F);
    const border = Color(0xFFE3E4DE);
    const accent = Color(0xFF9FC8B2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? accent.withOpacity(0.24) : Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: primaryText,
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
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);

    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportStepTile extends StatelessWidget {
  final int stepNumber;
  final TransitJourneyDisplayStep step;
  final Color accent;

  const _TransportStepTile({
    required this.stepNumber,
    required this.step,
    required this.accent,
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
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);
    const border = Color(0xFFE3E4DE);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.28),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: primaryText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            _iconForStep(step.type),
            size: 22,
            color: primaryText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next step',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                    height: 1.3,
                  ),
                ),
                if (step.subtitle != null && step.subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    step.subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: secondaryText,
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

class Metric extends StatelessWidget {
  final String label;
  final String value;

  const Metric({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: secondaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: primaryText,
          ),
        ),
      ],
    );
  }
}

String? _formatClock(DateTime? value) {
  if (value == null) {
    return null;
  }
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
