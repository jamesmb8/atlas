import 'dart:async';

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:atlas/app/screens/route_options_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/routes/directions.dart';
import '../../features/search/place_search.dart';


class AtlasPalette {
  static const background = Color(0xFFF7F6F2);
  static const primaryText = Color(0xFF1F1F1F);
  static const secondaryText = Color(0xFF6B6E6A);
  static const accent = Color(0xFF9FC8B2);
  static const divider = Color(0xFFE3E4DE);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppleMapController? _mapController;

  String? _selectedPlaceName;
  LatLng? _selectedPlaceLatLng;

  LatLng? _userLatLng;
  bool _locLoading = true;

  final Set<Annotation> _annotations = {}; // we’ll keep empty if you dislike pins
  final Set<Polyline> _polylines = {};

  static const _fallbackCamera = CameraPosition(
    target: LatLng(53.3811, -1.4701), // Sheffield fallback
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    // Don't call _loadUserLocation() here because _mapController isn't ready yet.
    // We'll call it inside onMapCreated.
  }

  Future<void> _loadUserLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _userLatLng = LatLng(pos.latitude, pos.longitude);

      final ctrl = _mapController;
      if (ctrl != null) {
        await ctrl.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _userLatLng!, zoom: 14),
          ),
        );
      }
    } catch (_) {
      // leave fallback
    } finally {
      if (mounted) setState(() => _locLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtlasPalette.background,
      body: Stack(
        children: [
          AppleMap(
            initialCameraPosition: _fallbackCamera,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapType: MapType.standard,
            annotations: _annotations,
            polylines: _polylines,
            onMapCreated: (c) {
              _mapController = c;
              _loadUserLocation();
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _SearchPill(
                placeholder: _selectedPlaceName ?? "Where to?",
                onPressed: _openPlacePicker,
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 210,
            child: _RoundIconButton(
              icon: Icons.my_location,
              onPressed: _recenterToUser,
            ),
          ),

          _HomeBottomSheet(
            selectedPlaceName: _selectedPlaceName,
            onFindPlace: _openPlacePicker,
            onGo: (_selectedPlaceLatLng != null) ? () => _goToOptions(context) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _recenterToUser() async {
    final ctrl = _mapController;
    final user = _userLatLng;
    if (ctrl == null) return;

    if (user != null) {
      await ctrl.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: user, zoom: 14)),
      );
    } else {
      await ctrl.animateCamera(CameraUpdate.newCameraPosition(_fallbackCamera));
    }
  }

  Future<void> _openPlacePicker() async {
    final result = await Navigator.push<ResolvedPlace>(
      context,
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );

    if (result == null) return;
    await _setDestination(name: result.title, latLng: result.latLng);
  }

  /// Sets destination, then draws a *real road-following polyline* using MKDirections.
  Future<void> _setDestination({required String name, required LatLng latLng}) async {
    setState(() {
      _selectedPlaceName = name;
      _selectedPlaceLatLng = latLng;

      // Remove pin if you dislike it:
      _annotations.clear();

      _polylines.clear();
    });

    final origin = _userLatLng;

    // If we don’t have user location yet, just zoom to the destination.
    if (origin == null) {
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 14)),
      );
      return;
    }

    // Get route points from MapKit
    final points = await MapKitDirections.route(
      origin: origin,
      destination: latLng,
      transport: 'walking', // change to 'automobile' if you want driving by default
    );

    if (!mounted) return;

    final routePoints = points.isNotEmpty ? points : [origin, latLng];

    setState(() {
      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: PolylineId('route'),
            points: routePoints,
            width: 6,
          ),
        );
    });

    await _zoomToPolyline(routePoints);
  }

  Future<void> _zoomToPolyline(List<LatLng> pts) async {
    final ctrl = _mapController;
    if (ctrl == null || pts.isEmpty) return;

    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;

    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  void _goToOptions(BuildContext context) {
    final dest = _selectedPlaceLatLng!;
    final name = _selectedPlaceName ?? "Destination";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteOptionsScreen(
          destinationName: name,
          destination: dest,
        ),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final String placeholder;
  final VoidCallback onPressed;

  const _SearchPill({
    required this.placeholder,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.78),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AtlasPalette.divider),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AtlasPalette.secondaryText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AtlasPalette.primaryText,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: AtlasPalette.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AtlasPalette.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: AtlasPalette.primaryText),
        ),
      ),
    );
  }
}
class _HomeBottomSheet extends StatelessWidget {
  final String? selectedPlaceName;
  final VoidCallback onFindPlace;
  final VoidCallback? onGo;

  const _HomeBottomSheet({
    required this.selectedPlaceName,
    required this.onFindPlace,
    required this.onGo,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.26,
      minChildSize: 0.18,
      maxChildSize: 0.68,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AtlasPalette.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                offset: Offset(0, -8),
                color: Color(0x14000000),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AtlasPalette.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedPlaceName == null ? "Plan a journey" : "Destination",
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.1,
                          fontWeight: FontWeight.w400,
                          color: AtlasPalette.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  selectedPlaceName == null
                      ? "Choose a place to see the best options."
                      : selectedPlaceName!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w400,
                    color: AtlasPalette.secondaryText,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _PrimaryButton(
                        label: selectedPlaceName == null ? "Find a place" : "Change destination",
                        onPressed: onFindPlace,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      child: _PrimaryButton(
                        label: "Go",
                        onPressed: onGo,
                        isDisabledWhenNull: true,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: AtlasPalette.divider),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: const [
                    Text(
                      "Recents",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AtlasPalette.secondaryText,
                      ),
                    ),
                    SizedBox(height: 10),
                    _RecentRow(title: "University", subtitle: "Sheffield Hallam"),
                    SizedBox(height: 10),
                    _RecentRow(title: "Gym", subtitle: "Nearest location"),
                    SizedBox(height: 10),
                    _RecentRow(title: "Home", subtitle: "Saved place"),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isDisabledWhenNull;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isDisabledWhenNull = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isDisabledWhenNull && onPressed == null;

    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AtlasPalette.accent,
          disabledBackgroundColor: AtlasPalette.divider,
          foregroundColor: AtlasPalette.primaryText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final String title;
  final String subtitle;

  const _RecentRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        border: Border.all(color: AtlasPalette.divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, color: AtlasPalette.secondaryText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AtlasPalette.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AtlasPalette.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AtlasPalette.secondaryText),
        ],
      ),
    );
  }
}

// Keep your existing _HomeBottomSheet / _PrimaryButton / _RecentRow
// (You can paste them as-is below this point)
