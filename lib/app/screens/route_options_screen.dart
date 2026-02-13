import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class RouteOptionsScreen extends StatefulWidget {
  final String destinationName;
  final LatLng destination;

  const RouteOptionsScreen({
    super.key,
    required this.destinationName,
    required this.destination,
  });

  @override
  State<RouteOptionsScreen> createState() => _RouteOptionsScreenState();
}

class _RouteOptionsScreenState extends State<RouteOptionsScreen> {
  bool _loading = true;
  dynamic _transportData;

  @override
  void initState() {
    super.initState();
    _testTransportApi();
  }

  Future<void> _testTransportApi() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('planJourney');

      final result = await callable.call({
        'fromLat': 53.5228,
        'fromLng': -1.1285,
        'toLat': 53.3811,
        'toLng': -1.4701,
      });


      if (!mounted) return;

      setState(() {
        _transportData = result.data;
        _loading = false;
      });

      debugPrint('TransportAPI response: ${result.data}');
    } catch (e) {
      debugPrint('TransportAPI error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Journey options (next step)",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "LatLng: ${widget.destination.latitude.toStringAsFixed(5)}, ${widget.destination.longitude.toStringAsFixed(5)}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 18),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_transportData != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _transportData.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )
            else
              const Text("No data returned."),
          ],
        ),
      ),
    );
  }
}
