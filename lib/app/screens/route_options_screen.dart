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
  final RouteOptionsService _routeOptionsService = const RouteOptionsService();

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

  Future<void> _openInAppleMaps() async {
    final lat = widget.destination.latitude;
    final lng = widget.destination.longitude;

    final uri = Uri.parse('http://maps.apple.com/?daddr=$lat,$lng');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF7F6F2);
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);
    const accent = Color(0xFF9FC8B2);
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
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
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  )
                else if (_options.isEmpty)
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _openInAppleMaps,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: primaryText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Open in Apple Maps',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }
  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);
    const accent = Color(0xFF9FC8B2);
    const border = Color(0xFFE3E4DE);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForMode(option.mode), color: primaryText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.mode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: primaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  option.tag,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(label: 'Time', value: '${option.durationMinutes} min'),
              _Metric(
                label: 'Cost',
                value: option.estimatedCost == null
                    ? '—'
                    : '£${option.estimatedCost!.toStringAsFixed(2)}',
              ),
              _Metric(label: 'CO₂', value: '${option.co2Kg.toStringAsFixed(2)} kg'),
            ],
          ),
          const SizedBox(height: 10),
          _Metric(label: 'Distance', value: _formatDistance(option.distanceMeters)),
          const SizedBox(height: 12),
          Text(
            option.description,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: secondaryText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            option.source,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);

    return Expanded(
      child: Column(
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
              fontWeight: FontWeight.w400,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }
}