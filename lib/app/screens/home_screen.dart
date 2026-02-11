import 'dart:async';

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:atlas/app/screens/route_options_screen.dart';
import 'package:flutter/material.dart';

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

  // MVP: selected destination (later we’ll use MapKit autocomplete + real place model)
  String? _selectedPlaceName;
  LatLng? _selectedPlaceLatLng;

  final Set<Annotation> _annotations = {};
  final Set<Polyline> _polylines = {};

  static const _initialCamera = CameraPosition(
    target: LatLng(53.3811, -1.4701), // Sheffield-ish fallback
    zoom: 12,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtlasPalette.background,
      body: Stack(
        children: [
          // Map layer
          AppleMap(
            initialCameraPosition: _initialCamera,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapType: MapType.standard,
            annotations: _annotations,
            polylines: _polylines,
            onMapCreated: (c) => _mapController = c,
            onTap: (latLng) {
              // Optional: tap to pick a point quickly (MVP)
              _setDestination(
                name: "Pinned location",
                latLng: latLng,
              );
            },
          ),

          // Top “Where to?” search pill
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _SearchPill(
                placeholder: _selectedPlaceName ?? "Where to?",
                onPressed: _openPlacePicker,
              ),
            ),
          ),

          // Floating location button (bottom-right)
          Positioned(
            right: 16,
            bottom: 210,
            child: _RoundIconButton(
              icon: Icons.my_location,
              onPressed: _recenter,
            ),
          ),

          // Bottom pull-up sheet
          _HomeBottomSheet(
            selectedPlaceName: _selectedPlaceName,
            onFindPlace: _openPlacePicker,
            onGo: (_selectedPlaceLatLng != null)
                ? () => _goToOptions(context)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _recenter() async {
    // If you want true recenter to user location later, we’ll wire geolocator.
    // For now, just animate to initial region.
    final ctrl = _mapController;
    if (ctrl == null) return;
    await ctrl.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
  }

  Future<void> _openPlacePicker() async {
    final result = await Navigator.push<ResolvedPlace>(
      context,
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );

    if (result == null) return;
    _setDestination(name: result.title, latLng: result.latLng);
  }


  void _setDestination({required String name, required LatLng latLng}) {
    setState(() {
      _selectedPlaceName = name;
      _selectedPlaceLatLng = latLng;

      _annotations
        ..clear()
        ..add(
          Annotation(
            annotationId: AnnotationId('dest'),
            position: latLng,
            infoWindow: InfoWindow(title: name),
          ),
        );

      // MVP polyline: simple straight line (placeholder).
      // Later: MKDirections route polyline.
      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: PolylineId('mvp_line'),
            points: [
              _initialCamera.target, // placeholder “origin”
              latLng,
            ],
            width: 4,
          ),
        );
    });

    // Zoom to fit both points (simple heuristic)
    unawaited(_zoomToRoutePreview(latLng));
  }

  Future<void> _zoomToRoutePreview(LatLng dest) async {
    final ctrl = _mapController;
    if (ctrl == null) return;

    final swLat = (dest.latitude < _initialCamera.target.latitude)
        ? dest.latitude
        : _initialCamera.target.latitude;
    final swLng = (dest.longitude < _initialCamera.target.longitude)
        ? dest.longitude
        : _initialCamera.target.longitude;

    final neLat = (dest.latitude > _initialCamera.target.latitude)
        ? dest.latitude
        : _initialCamera.target.latitude;
    final neLng = (dest.longitude > _initialCamera.target.longitude)
        ? dest.longitude
        : _initialCamera.target.longitude;

    final bounds = LatLngBounds(
      southwest: LatLng(swLat, swLng),
      northeast: LatLng(neLat, neLng),
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
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.my_location, color: AtlasPalette.primaryText),
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
                        selectedPlaceName == null
                            ? "Plan a journey"
                            : "Destination",
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
                        label: selectedPlaceName == null
                            ? "Find a place"
                            : "Change destination",
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

class _PlacePickResult {
  final String name;
  final LatLng latLng;
  const _PlacePickResult(this.name, this.latLng);
}

class _PlacePickerSheet extends StatelessWidget {
  const _PlacePickerSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AtlasPalette.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: AtlasPalette.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Pick a place (MVP)",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: AtlasPalette.primaryText,
                ),
              ),
            ),
            const SizedBox(height: 10),

            _PickTile(
              title: "Sheffield Station",
              subtitle: "Rail station",
              onTap: () => Navigator.pop(
                context,
                const _PlacePickResult("Sheffield Station", LatLng(53.3771, -1.4632)),
              ),
            ),
            const SizedBox(height: 10),
            _PickTile(
              title: "Meadowhall",
              subtitle: "Shopping centre",
              onTap: () => Navigator.pop(
                context,
                const _PlacePickResult("Meadowhall", LatLng(53.4155, -1.4125)),
              ),
            ),
            const SizedBox(height: 10),
            _PickTile(
              title: "Peak District",
              subtitle: "National park",
              onTap: () => Navigator.pop(
                context,
                const _PlacePickResult("Peak District", LatLng(53.3400, -1.7600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PickTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.45),
          border: Border.all(color: AtlasPalette.divider),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AtlasPalette.secondaryText),
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
            const Icon(Icons.north_west, color: AtlasPalette.secondaryText),
          ],
        ),
      ),
    );
  }
}
