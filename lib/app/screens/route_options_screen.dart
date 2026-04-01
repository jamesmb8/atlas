import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/routes/route_option.dart';
import '../../services/routeservice.dart';


class RouteOptionsScreen extends StatefulWidget {
  final String destinationName;
  final LatLng destination;
  final LatLng? origin;

  const RouteOptionsScreen({
    super.key,
    required this.destinationName,
    required this.destination,
    required this.origin,
  });

  @override
  State<RouteOptionsScreen> createState() => _RouteOptionsScreenState();
}

class _RouteOptionsScreenState extends State<RouteOptionsScreen> {
  final RouteOptionsService _routeOptionsService = RouteOptionsService();

  bool _loading = true;
  List<RouteOption> _options = [];
  String? _error;

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
      final options = await _routeOptionsService.buildOptions(
        origin: widget.origin,
        destination: widget.destination,
        destinationName: widget.destinationName,
      );

      if (!mounted) return;

      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
              '${widget.destination.latitude.toStringAsFixed(5)}, ${widget.destination.longitude.toStringAsFixed(5)}',
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
                  child: _RouteOptionCard(option: option),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  final RouteOption option;

  const _RouteOptionCard({required this.option});

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

  bool _shouldShowTime(RouteOption option) {
    if (option.mode.toLowerCase() == 'public transport') return false;
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

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);
    const accent = Color(0xFF9FC8B2);
    const featuredAccent = Color(0xFFE8F3EC);
    const border = Color(0xFFE3E4DE);

    final showTime = _shouldShowTime(option);

    final metrics = <Widget>[
      if (showTime) Metric(label: 'Time', value: '${option.durationMinutes} min'),
      Metric(label: 'Cost', value: _formatCost(option)),
      Metric(label: 'CO₂', value: '${option.co2Kg.toStringAsFixed(2)} kg'),
      Metric(label: 'Distance', value: _formatDistance(option.distanceMeters)),
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
                  option.tag,
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
          Text(
            option.description,
            style: TextStyle(
              fontSize: option.isFeatured ? 15 : 14,
              fontWeight: FontWeight.w400,
              color: secondaryText,
              height: 1.45,
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
          if (actions.isNotEmpty) ...[
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