import 'dart:async';

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:atlas/features/themes/atlas_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounce;
  bool _loading = false;

  List<_PlaceSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final q = _controller.text.trim();
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) {
        return;
      }

      if (q.isEmpty) {
        setState(() => _suggestions = []);
        return;
      }

      setState(() => _loading = true);

      try {
        final results = await MapKitSearch.autocomplete(q);
        if (!mounted) {
          return;
        }
        setState(() => _suggestions = results);
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() => _suggestions = []);
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    });
  }

  Future<void> _selectSuggestion(_PlaceSuggestion s) async {
    setState(() => _loading = true);

    try {
      final resolved = await MapKitSearch.resolve(s.title, s.subtitle);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, resolved);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't find that place. Try another."),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: atlas.background,
      appBar: AppBar(
        backgroundColor: atlas.background,
        surfaceTintColor: atlas.background,
        elevation: 0,
        iconTheme: IconThemeData(color: atlas.textPrimary),
        title: Text(
          'Search',
          style: tt.titleLarge?.copyWith(
            color: atlas.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: atlas.border),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              style: tt.bodyLarge?.copyWith(
                color: atlas.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Where to?',
                hintStyle: tt.bodyMedium?.copyWith(
                  color: atlas.textSecondary.withOpacity(0.7),
                ),
                filled: true,
                fillColor: atlas.surface.withOpacity(0.55),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: atlas.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: atlas.brandPrimary,
                    width: 1.4,
                  ),
                ),
                prefixIcon: Icon(Icons.search, color: atlas.textSecondary),
                suffixIcon: _loading
                    ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: atlas.brandPrimary,
                    ),
                  ),
                )
                    : (_controller.text.isEmpty
                    ? null
                    : IconButton(
                  onPressed: () => _controller.clear(),
                  icon: Icon(
                    Icons.close,
                    color: atlas.textSecondary,
                  ),
                )),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _suggestions.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final s = _suggestions[i];
                  return _SuggestionTile(
                    title: s.title,
                    subtitle: s.subtitle,
                    onTap: () => _selectSuggestion(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Text(
        'Start typing to search nearby places.',
        style: tt.bodySmall?.copyWith(
          fontSize: 14,
          color: atlas.textSecondary,
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: atlas.surface.withOpacity(0.5),
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
              Icon(Icons.place_outlined, color: atlas.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontSize: 15,
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
              Icon(Icons.chevron_right, color: atlas.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSuggestion {
  final String title;
  final String subtitle;

  const _PlaceSuggestion({
    required this.title,
    required this.subtitle,
  });

  factory _PlaceSuggestion.fromMap(Map<dynamic, dynamic> m) {
    return _PlaceSuggestion(
      title: (m['title'] as String?) ?? '',
      subtitle: (m['subtitle'] as String?) ?? '',
    );
  }
}

class ResolvedPlace {
  final String title;
  final String subtitle;
  final LatLng latLng;

  const ResolvedPlace({
    required this.title,
    required this.subtitle,
    required this.latLng,
  });
}

class MapKitSearch {
  static const _channel = MethodChannel('atlas/mapkit_search');

  static Future<List<_PlaceSuggestion>> autocomplete(String query) async {
    final res = await _channel.invokeMethod<List<dynamic>>(
      'autocomplete',
      {'query': query},
    );

    return (res ?? const [])
        .cast<Map<dynamic, dynamic>>()
        .map(_PlaceSuggestion.fromMap)
        .where((s) => s.title.isNotEmpty)
        .toList();
  }

  static Future<ResolvedPlace> resolve(String title, String subtitle) async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'resolve',
      {'title': title, 'subtitle': subtitle},
    );

    if (res == null) {
      throw Exception('resolve returned null');
    }

    final lat = (res['lat'] as num).toDouble();
    final lng = (res['lng'] as num).toDouble();

    return ResolvedPlace(
      title: (res['title'] as String?) ?? title,
      subtitle: (res['subtitle'] as String?) ?? subtitle,
      latLng: LatLng(lat, lng),
    );
  }
}