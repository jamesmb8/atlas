import 'dart:async';
import 'dart:convert';

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:atlas/app/screens/route_options_screen.dart';
import 'package:atlas/features/themes/atlas_theme.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accountpage.dart';
import '../../features/routes/directions.dart';
import '../../features/search/place_search.dart';

class SavedFavorite {
  final String id;
  final String name;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  const SavedFavorite({
    required this.id,
    required this.name,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  String get addressLabel {
    final parts = <String>[
      title.trim(),
      subtitle.trim(),
    ].where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) {
      return 'Saved place';
    }

    return parts.join(', ');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'title': title,
      'subtitle': subtitle,
      'lat': latitude,
      'lng': longitude,
    };
  }

  factory SavedFavorite.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      throw const FormatException('Invalid favourite coordinates');
    }

    return SavedFavorite(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Favourite',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      latitude: lat,
      longitude: lng,
    );
  }

  SavedFavorite copyWith({
    String? id,
    String? name,
    String? title,
    String? subtitle,
    double? latitude,
    double? longitude,
  }) {
    return SavedFavorite(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

enum _SystemFavoriteSlot { home, work }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _favoritesStorageKey = 'atlas_saved_favorites_v1';

  final Completer<AppleMapController> _mapControllerCompleter =
  Completer<AppleMapController>();
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  AppleMapController? _mapController;

  String? _selectedPlaceName;
  LatLng? _selectedPlaceLatLng;

  String? _originPlaceName;
  LatLng? _originLatLng;

  LatLng? _userLatLng;
  bool _locLoading = true;

  bool _favoritesLoading = true;
  SavedFavorite? _homeFavorite;
  SavedFavorite? _workFavorite;
  List<SavedFavorite> _customFavorites = <SavedFavorite>[];

  DateTime? _departureTime;

  final Set<Annotation> _annotations = <Annotation>{};
  final Set<Polyline> _polylines = <Polyline>{};

  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(53.3811, -1.4701),
    zoom: 12,
  );

  static const List<String> _monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

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

  String get _departureLabel {
    final selected = _departureTime;
    if (selected == null) {
      return 'Leave now';
    }

    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final selectedDate = DateUtils.dateOnly(selected);
    final time = _formatClock(selected);

    if (selectedDate == today) {
      return 'Today at $time';
    }
    if (selectedDate == tomorrow) {
      return 'Tomorrow at $time';
    }
    return '${selected.day} ${_monthLabels[selected.month - 1]} at $time';
  }

  @override
  void initState() {
    super.initState();
    _loadSavedFavorites();
  }

  void _openAccountPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountPage()),
    );
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

  Future<void> _pickDepartureTime() async {
    final atlas = context.atlas;
    final baseTheme = Theme.of(context);
    final now = DateTime.now();
    final initial = _departureTime != null && _departureTime!.isAfter(now)
        ? _departureTime!
        : now.add(const Duration(minutes: 15));

    final pickerTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: atlas.brandPrimary,
        onPrimary: Colors.white,
        surface: atlas.background,
        onSurface: atlas.textPrimary,
      ),
      dialogBackgroundColor: atlas.background,
    );

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: pickerTheme,
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: pickerTheme,
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!selected.isAfter(now)) {
      _showSnackBar('Choose a future departure time.');
      return;
    }

    setState(() => _departureTime = selected);
  }

  void _clearDepartureTime() {
    setState(() => _departureTime = null);
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;

    return Scaffold(
      backgroundColor: atlas.background,
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    icon: Icons.person_outline_rounded,
                    onPressed: _openAccountPage,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 260,
            child: _RoundIconButton(
              icon: Icons.my_location,
              onPressed: _recenterToOrigin,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _HomeBottomSheet(
              selectedPlaceName: _selectedPlaceName,
              departureLabel: _departureLabel,
              hasScheduledDeparture: _departureTime != null,
              onDeparturePressed: _pickDepartureTime,
              onDepartureCleared: _clearDepartureTime,
              onFindPlace: _openPlacePicker,
              onGo: (_selectedPlaceLatLng != null && _originToUse != null)
                  ? () => _goToOptions(context)
                  : null,
              favoritesLoading: _favoritesLoading,
              homeFavorite: _homeFavorite,
              workFavorite: _workFavorite,
              customFavorites: _customFavorites,
              onHomePressed: _handleHomePressed,
              onWorkPressed: _handleWorkPressed,
              onSetHomePressed: () => _setSystemFavorite(_SystemFavoriteSlot.home),
              onSetWorkPressed: () => _setSystemFavorite(_SystemFavoriteSlot.work),
              onAddFavoritePressed: _addCustomFavorite,
              onFavoritePressed: _selectFavorite,
              onFavoriteEditPressed: _editCustomFavoriteAddress,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSavedFavorites() async {
    try {
      final raw = await _prefs.getString(_favoritesStorageKey);

      if (raw == null || raw.trim().isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() => _favoritesLoading = false);
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        if (!mounted) {
          return;
        }
        setState(() => _favoritesLoading = false);
        return;
      }

      final data = Map<String, dynamic>.from(decoded as Map);

      final home = _tryParseFavorite(data['home']);
      final work = _tryParseFavorite(data['work']);

      final customRaw = data['custom'];
      final custom = <SavedFavorite>[];

      if (customRaw is List) {
        for (final item in customRaw) {
          final parsed = _tryParseFavorite(item);
          if (parsed != null) {
            custom.add(parsed);
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _homeFavorite = home;
        _workFavorite = work;
        _customFavorites = custom;
        _favoritesLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _favoritesLoading = false);
    }
  }

  SavedFavorite? _tryParseFavorite(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    try {
      return SavedFavorite.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistFavorites() async {
    final payload = <String, dynamic>{
      'home': _homeFavorite?.toJson(),
      'work': _workFavorite?.toJson(),
      'custom': _customFavorites.map((favorite) => favorite.toJson()).toList(),
    };

    await _prefs.setString(_favoritesStorageKey, jsonEncode(payload));
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

  Future<ResolvedPlace?> _pickPlace() async {
    return Navigator.push<ResolvedPlace>(
      context,
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );
  }

  Future<void> _openOriginPicker() async {
    final result = await _pickPlace();
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
    final result = await _pickPlace();
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
            annotationId: AnnotationId('destination'),
            position: latLng,
            infoWindow: InfoWindow(title: name),
          ),
        );

      if (_originToUse != null) {
        _annotations.add(
          Annotation(
            annotationId: AnnotationId('origin'),
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
              polylineId: PolylineId('route'),
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
          departureTime: _departureTime,
        ),
      ),
    );
  }

  Future<void> _handleHomePressed() async {
    final favorite = _homeFavorite;
    if (favorite == null) {
      await _setSystemFavorite(_SystemFavoriteSlot.home);
      return;
    }

    await _setDestination(name: favorite.name, latLng: favorite.latLng);
  }

  Future<void> _handleWorkPressed() async {
    final favorite = _workFavorite;
    if (favorite == null) {
      await _setSystemFavorite(_SystemFavoriteSlot.work);
      return;
    }

    await _setDestination(name: favorite.name, latLng: favorite.latLng);
  }

  Future<void> _setSystemFavorite(_SystemFavoriteSlot slot) async {
    final result = await _pickPlace();
    if (result == null) {
      return;
    }

    final isHome = slot == _SystemFavoriteSlot.home;
    final favorite = SavedFavorite(
      id: isHome ? 'home' : 'work',
      name: isHome ? 'Home' : 'Work',
      title: result.title,
      subtitle: result.subtitle,
      latitude: result.latLng.latitude,
      longitude: result.latLng.longitude,
    );

    setState(() {
      if (isHome) {
        _homeFavorite = favorite;
      } else {
        _workFavorite = favorite;
      }
    });

    await _persistFavorites();
    _showSnackBar('${favorite.name} saved.');
  }

  Future<void> _addCustomFavorite() async {
    final name = await _promptForFavoriteName();
    if (name == null) {
      return;
    }

    if (_isReservedFavoriteName(name)) {
      _showSnackBar('Home and Work are reserved names.');
      return;
    }

    if (_hasCustomFavoriteName(name)) {
      _showSnackBar('You already have a favourite with that name.');
      return;
    }

    final result = await _pickPlace();
    if (result == null) {
      return;
    }

    final favorite = SavedFavorite(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      title: result.title,
      subtitle: result.subtitle,
      latitude: result.latLng.latitude,
      longitude: result.latLng.longitude,
    );

    setState(() {
      _customFavorites = <SavedFavorite>[
        ..._customFavorites,
        favorite,
      ];
    });

    await _persistFavorites();
    _showSnackBar('$name saved.');
  }

  Future<void> _editCustomFavoriteAddress(SavedFavorite favorite) async {
    final result = await _pickPlace();
    if (result == null) {
      return;
    }

    final updated = favorite.copyWith(
      title: result.title,
      subtitle: result.subtitle,
      latitude: result.latLng.latitude,
      longitude: result.latLng.longitude,
    );

    setState(() {
      _customFavorites = _customFavorites
          .map((item) => item.id == favorite.id ? updated : item)
          .toList();
    });

    await _persistFavorites();
    _showSnackBar('${favorite.name} updated.');
  }

  bool _isReservedFavoriteName(String name) {
    final lower = name.trim().toLowerCase();
    return lower == 'home' || lower == 'work';
  }

  bool _hasCustomFavoriteName(String name) {
    final lower = name.trim().toLowerCase();
    return _customFavorites.any(
          (favorite) => favorite.name.trim().toLowerCase() == lower,
    );
  }

  Future<String?> _promptForFavoriteName() async {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;
    final controller = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: atlas.background,
          title: Text(
            'New favourite',
            style: tt.titleLarge?.copyWith(color: atlas.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Name',
              hintStyle: tt.bodyMedium?.copyWith(
                color: atlas.textSecondary.withOpacity(0.8),
              ),
              filled: true,
              fillColor: atlas.surface.withOpacity(0.9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: atlas.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: atlas.brandPrimary),
              ),
            ),
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(trimmed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: tt.labelLarge?.copyWith(color: atlas.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(trimmed);
              },
              child: const Text('Next'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return value?.trim();
  }

  Future<void> _selectFavorite(SavedFavorite favorite) async {
    await _setDestination(name: favorite.name, latLng: favorite.latLng);
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;
    final hasTrailing = trailingIcon != null;

    return Material(
      color: atlas.surface.withOpacity(0.78),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: atlas.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(leadingIcon, color: atlas.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyLarge?.copyWith(
                    color: atlas.textPrimary,
                    fontWeight: FontWeight.w400,
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
                      color: atlas.textSecondary,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: atlas.textSecondary,
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
    final atlas = context.atlas;

    return Material(
      color: atlas.surface.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: atlas.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: atlas.textPrimary),
        ),
      ),
    );
  }
}

class _HomeBottomSheet extends StatelessWidget {
  final String? selectedPlaceName;
  final String departureLabel;
  final bool hasScheduledDeparture;
  final VoidCallback onDeparturePressed;
  final VoidCallback onDepartureCleared;
  final VoidCallback onFindPlace;
  final VoidCallback? onGo;

  final bool favoritesLoading;
  final SavedFavorite? homeFavorite;
  final SavedFavorite? workFavorite;
  final List<SavedFavorite> customFavorites;
  final VoidCallback onHomePressed;
  final VoidCallback onWorkPressed;
  final VoidCallback onSetHomePressed;
  final VoidCallback onSetWorkPressed;
  final VoidCallback onAddFavoritePressed;
  final ValueChanged<SavedFavorite> onFavoritePressed;
  final ValueChanged<SavedFavorite> onFavoriteEditPressed;

  const _HomeBottomSheet({
    required this.selectedPlaceName,
    required this.departureLabel,
    required this.hasScheduledDeparture,
    required this.onDeparturePressed,
    required this.onDepartureCleared,
    required this.onFindPlace,
    required this.onGo,
    required this.favoritesLoading,
    required this.homeFavorite,
    required this.workFavorite,
    required this.customFavorites,
    required this.onHomePressed,
    required this.onWorkPressed,
    required this.onSetHomePressed,
    required this.onSetWorkPressed,
    required this.onAddFavoritePressed,
    required this.onFavoritePressed,
    required this.onFavoriteEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;
    final hasSelection = selectedPlaceName != null;

    return DraggableScrollableSheet(
      expand: false,
      snap: true,
      initialChildSize: 0.34,
      minChildSize: 0.20,
      maxChildSize: 0.78,
      snapSizes: const [0.34, 0.55, 0.78],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: atlas.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: const [
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
                    color: atlas.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hasSelection ? 'Destination' : 'Plan a journey',
                style: tt.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: atlas.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasSelection
                    ? selectedPlaceName!
                    : 'Choose a place to see the best options.',
                style: tt.bodySmall?.copyWith(
                  fontSize: 14,
                  height: 1.25,
                  color: atlas.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              _FavouriteRow(
                title: 'Departure',
                subtitle: departureLabel,
                leadingIcon: Icons.schedule_rounded,
                onTap: onDeparturePressed,
                trailingIcon: hasScheduledDeparture
                    ? Icons.close_rounded
                    : Icons.edit_outlined,
                onTrailingPressed: hasScheduledDeparture
                    ? onDepartureCleared
                    : onDeparturePressed,
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
              Divider(height: 1, color: atlas.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Favourite places',
                      style: tt.labelMedium?.copyWith(
                        fontSize: 13,
                        color: atlas.textSecondary,
                      ),
                    ),
                  ),
                  _HeaderAddButton(onPressed: onAddFavoritePressed),
                ],
              ),
              const SizedBox(height: 10),
              if (favoritesLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else ...[
                _FavouriteRow(
                  title: 'Home',
                  subtitle: homeFavorite?.addressLabel ?? 'Set address',
                  leadingIcon: Icons.home_outlined,
                  onTap: onHomePressed,
                  trailingIcon: Icons.edit_location_alt_outlined,
                  onTrailingPressed: onSetHomePressed,
                ),
                const SizedBox(height: 10),
                _FavouriteRow(
                  title: 'Work',
                  subtitle: workFavorite?.addressLabel ?? 'Set address',
                  leadingIcon: Icons.work_outline_rounded,
                  onTap: onWorkPressed,
                  trailingIcon: Icons.edit_location_alt_outlined,
                  onTrailingPressed: onSetWorkPressed,
                ),
                if (customFavorites.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Saved favourites',
                    style: tt.labelMedium?.copyWith(
                      fontSize: 13,
                      color: atlas.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List<Widget>.generate(customFavorites.length, (index) {
                    final favorite = customFavorites[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == customFavorites.length - 1 ? 0 : 10,
                      ),
                      child: _FavouriteRow(
                        title: favorite.name,
                        subtitle: favorite.addressLabel,
                        leadingIcon: Icons.star_border_rounded,
                        onTap: () => onFavoritePressed(favorite),
                        trailingIcon: Icons.edit_rounded,
                        onTrailingPressed: () => onFavoriteEditPressed(favorite),
                      ),
                    );
                  }),
                ],
              ],
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
    final tt = Theme.of(context).textTheme;
    final atlas = context.atlas;
    final disabled = isDisabledWhenNull && onPressed == null;

    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: atlas.brandPrimary,
          disabledBackgroundColor: atlas.border,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: tt.labelLarge?.copyWith(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HeaderAddButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HeaderAddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;

    return Material(
      color: atlas.surface.withOpacity(0.7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: atlas.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.add_rounded,
            size: 20,
            color: atlas.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _FavouriteRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final VoidCallback onTap;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingPressed;

  const _FavouriteRow({
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.onTap,
    this.trailingIcon,
    this.onTrailingPressed,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme
        .of(context)
        .textTheme;

    return Material(
      color: atlas.surface.withOpacity(0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: atlas.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(leadingIcon, color: atlas.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: atlas.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        fontSize: 13,
                        color: atlas.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingIcon != null && onTrailingPressed != null)
                IconButton(
                  onPressed: onTrailingPressed,
                  splashRadius: 18,
                  icon: Icon(
                    trailingIcon,
                    color: atlas.textSecondary,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: atlas.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}