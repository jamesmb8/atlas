// lib/screens/home/home_screen.dart
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
  final Completer<AppleMapController> _mapControllerCompleter =
  Completer<AppleMapController>();

  AppleMapController? _mapController;

  String? _selectedPlaceName;
  LatLng? _selectedPlaceLatLng;

  String? _originPlaceName;
  LatLng? _originLatLng;

  LatLng? _userLatLng;
  bool _locLoading = true;

  final Set<Annotation> _annotations = <Annotation>{};
  final Set<Polyline> _polylines = <Polyline>{};

  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(53.3811, -1.4701),
    zoom: 12,
  );

  LatLng? get _originToUse => _originLatLng ?? _userLatLng;

  String get _originPlaceholder {
    if (_originPlaceName != null) {
      return _originPlaceName!;
    }
    if (_locLoading) {
      return 'Current location…';
    }
    return 'Current location';
  }

  Future<AppleMapController?> _getController() async {
    if (_mapController != null) {
      return _mapController;
    }
    try {
      return await _mapControllerCompleter.future;
    } catch (_) {
      return null;
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
            onMapCreated: (controller) {
              _mapController = controller;
              if (!_mapControllerCompleter.isCompleted) {
                _mapControllerCompleter.complete(controller);
              }
              _loadUserLocation();
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SearchPill(
                    placeholder: _originPlaceholder,
                    leadingIcon: Icons.trip_origin_rounded,
                    onPressed: _openOriginPicker,
                    trailingIcon: _originLatLng != null
                        ? Icons.close_rounded
                        : Icons.arrow_forward_ios_rounded,
                    onTrailingPressed:
                    _originLatLng != null ? _clearOriginOverride : null,
                  ),
                  const SizedBox(height: 10),
                  _SearchPill(
                    placeholder: _selectedPlaceName ?? 'Where to?',
                    leadingIcon: Icons.search,
                    onPressed: _openPlacePicker,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 220,
            child: _RoundIconButton(
              icon: Icons.my_location,
              onPressed: _recenterToOrigin,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child:

          _HomeBottomSheet(
            selectedPlaceName: _selectedPlaceName,
            onFindPlace: _openPlacePicker,
            onGo: (_selectedPlaceLatLng != null && _originToUse != null)
                ? () => _goToOptions(context)
                : null,
          ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      _userLatLng = LatLng(pos.latitude, pos.longitude);

      final controller = await _getController();
      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _userLatLng!, zoom: 14),
          ),
        );
      }

      if (_selectedPlaceLatLng != null) {
        await _refreshRouteIfNeeded();
      }
    } catch (_) {
      // Keep fallback camera.
    } finally {
      if (mounted) {
        setState(() => _locLoading = false);
      }
    }
  }

  void _clearOriginOverride() {
    setState(() {
      _originLatLng = null;
      _originPlaceName = null;
    });
    _refreshRouteIfNeeded();
  }

  Future<void> _recenterToOrigin() async {
    final controller = await _getController();
    if (controller == null) {
      return;
    }

    final origin = _originToUse;
    if (origin != null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: origin, zoom: 14),
        ),
      );
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_fallbackCamera),
    );
  }

  Future<void> _openOriginPicker() async {
    final result = await Navigator.push<ResolvedPlace>(
      context,
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _originPlaceName = result.title;
      _originLatLng = result.latLng;
    });

    await _refreshRouteIfNeeded();
  }

  Future<void> _openPlacePicker() async {
    final result = await Navigator.push<ResolvedPlace>(
      context,
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );

    if (result == null) {
      return;
    }

    await _setDestination(
      name: result.title,
      latLng: result.latLng,
    );
  }

  Future<void> _refreshRouteIfNeeded() async {
    final dest = _selectedPlaceLatLng;
    final name = _selectedPlaceName;
    final origin = _originToUse;

    if (dest == null || name == null || origin == null) {
      return;
    }

    await _setDestination(name: name, latLng: dest);
  }

  Future<void> _setDestination({
    required String name,
    required LatLng latLng,
  }) async {
    setState(() {
      _selectedPlaceName = name;
      _selectedPlaceLatLng = latLng;

      _annotations
        ..clear()
        ..add(
          Annotation(
            annotationId:  AnnotationId('destination'),
            position: latLng,
            infoWindow: InfoWindow(title: name),
          ),
        );
      if (_originToUse != null) {
        _annotations.add(
          Annotation(
            annotationId:  AnnotationId('origin'),
            position: _originToUse!,
            infoWindow: const InfoWindow(title: 'Start'),
          ),
        );
      }

      _polylines.clear();
    });

    await _focusOnDestination(latLng);

    final origin = _originToUse;
    if (origin == null) {
      return;
    }

    try {
      final points = await MapKitDirections.route(
        origin: origin,
        destination: latLng,
        transport: 'automobile',
      );

      if (!mounted) {
        return;
      }

      final routePoints = points.isNotEmpty ? points : <LatLng>[origin, latLng];

      setState(() {
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId:  PolylineId('route'),
              points: routePoints,
              width: 6,
            ),
          );
      });

      await _zoomToPolyline(routePoints);
    } catch (e) {
      debugPrint('Route generation failed: $e');
      await _focusOnDestination(latLng);
    }
  }

  Future<void> _focusOnDestination(LatLng latLng) async {
    final controller = await _getController();
    if (controller == null) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15),
      ),
    );
  }

  Future<void> _zoomToPolyline(List<LatLng> points) async {
    final controller = await _getController();
    final origin = _originToUse;
    final destination = _selectedPlaceLatLng;

    if (controller == null) {
      return;
    }

    final allPoints = <LatLng>[
      ...points,
      if (origin != null) origin,
      if (destination != null) destination,
    ];

    if (allPoints.isEmpty) {
      return;
    }

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final point in allPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 110),
    );
  }

  void _goToOptions(BuildContext context) {
    final destination = _selectedPlaceLatLng!;
    final destinationName = _selectedPlaceName ?? 'Destination';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteOptionsScreen(
          destinationName: destinationName,
          destination: destination,
          origin: _originToUse,
        ),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final String placeholder;
  final IconData leadingIcon;
  final VoidCallback onPressed;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingPressed;

  const _SearchPill({
    required this.placeholder,
    required this.leadingIcon,
    required this.onPressed,
    this.trailingIcon,
    this.onTrailingPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasTrailing = trailingIcon != null;

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
              Icon(leadingIcon, color: AtlasPalette.secondaryText),
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
              if (hasTrailing)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTrailingPressed,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      trailingIcon,
                      size: trailingIcon == Icons.close_rounded ? 20 : 16,
                      color: AtlasPalette.secondaryText,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AtlasPalette.secondaryText,
                ),
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
    final hasSelection = selectedPlaceName != null;

    return DraggableScrollableSheet(
      expand: false,
      snap: true,
      initialChildSize: 0.24,
      minChildSize: 0.16,
      maxChildSize: 0.72,
      snapSizes: const [0.26, 0.45, 0.70],
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
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AtlasPalette.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hasSelection ? 'Destination' : 'Plan a journey',
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.1,
                  fontWeight: FontWeight.w400,
                  color: AtlasPalette.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasSelection
                    ? selectedPlaceName!
                    : 'Choose a place to see the best options.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w400,
                  color: AtlasPalette.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              if (!hasSelection)
                Row(
                  children: [
                    Expanded(
                      child: _PrimaryButton(
                        label: 'Find a place',
                        onPressed: onFindPlace,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      child: _PrimaryButton(
                        label: 'Go',
                        onPressed: onGo,
                        isDisabledWhenNull: true,
                      ),
                    ),
                  ],
                )
              else
                _PrimaryButton(
                  label: 'Go',
                  onPressed: onGo,
                  isDisabledWhenNull: true,
                ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AtlasPalette.divider),
              const SizedBox(height: 12),
              const Text(
                'Recents',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AtlasPalette.secondaryText,
                ),
              ),
              const SizedBox(height: 10),
              const _RecentRow(
                title: 'University',
                subtitle: 'Sheffield Hallam',
              ),
              const SizedBox(height: 10),
              const _RecentRow(
                title: 'Gym',
                subtitle: 'Nearest location',
              ),
              const SizedBox(height: 10),
              const _RecentRow(
                title: 'Home',
                subtitle: 'Saved place',
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final String title;
  final String subtitle;

  const _RecentRow({
    required this.title,
    required this.subtitle,
  });

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