import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';

import '../../../services/applerouteservice.dart';


class AppleRouteTestScreen extends StatefulWidget {
  const AppleRouteTestScreen({super.key});

  @override
  State<AppleRouteTestScreen> createState() => _AppleRouteTestScreenState();
}

class _AppleRouteTestScreenState extends State<AppleRouteTestScreen> {
  final AppleRouteService _appleRouteService = const AppleRouteService();

  String _status = 'Press a button to test Apple MapKit routing.';
  bool _loading = false;

  final LatLng _origin = const LatLng(53.3811, -1.4701);
  final LatLng _destination = const LatLng(53.3780, -1.4620);

  Future<void> _testWalking() async {
    setState(() {
      _loading = true;
      _status = 'Testing walking route...';
    });

    final result = await _appleRouteService.getWalkingRoute(
      origin: _origin,
      destination: _destination,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      _status = result == null
          ? 'Walking route failed or returned null.'
          : 'Walking route worked.\n\nDistance: ${result.distanceMeters.toStringAsFixed(0)} m\nDuration: ${result.durationMinutes} min';
    });
  }

  Future<void> _testDriving() async {
    setState(() {
      _loading = true;
      _status = 'Testing driving route...';
    });

    final result = await _appleRouteService.getDrivingRoute(
      origin: _origin,
      destination: _destination,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      _status = result == null
          ? 'Driving route failed or returned null.'
          : 'Driving route worked.\n\nDistance: ${result.distanceMeters.toStringAsFixed(0)} m\nDuration: ${result.durationMinutes} min';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apple Route Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _status,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading) ...[
              ElevatedButton(
                onPressed: _testWalking,
                child: const Text('Test Walking Route'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _testDriving,
                child: const Text('Test Driving Route'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}