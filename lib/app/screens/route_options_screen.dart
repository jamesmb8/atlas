import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';

class RouteOptionsScreen extends StatelessWidget {
  final String destinationName;
  final LatLng destination;

  const RouteOptionsScreen({
    super.key,
    required this.destinationName,
    required this.destination,
  });

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
              "LatLng: ${destination.latitude.toStringAsFixed(5)}, ${destination.longitude.toStringAsFixed(5)}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 18),

            // Placeholder cards
            _OptionCard(title: "Walking", subtitle: "— min • — kg CO₂"),
            const SizedBox(height: 12),
            _OptionCard(title: "Driving", subtitle: "— min • — kg CO₂"),
            const SizedBox(height: 12),
            _OptionCard(title: "Public transport", subtitle: "— min • — kg CO₂"),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _OptionCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    const primaryText = Color(0xFF1F1F1F);
    const secondaryText = Color(0xFF6B6E6A);
    const border = Color(0xFFE3E4DE);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: secondaryText),
        ],
      ),
    );
  }
}
