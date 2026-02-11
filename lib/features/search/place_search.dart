import 'dart:async';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AtlasPalette {
  static const background = Color(0xFFF7F6F2);
  static const primaryText = Color(0xFF1F1F1F);
  static const secondaryText = Color(0xFF6B6E6A);
  static const accent = Color(0xFF9FC8B2);
  static const divider = Color(0xFFE3E4DE);
}

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
    // Autofocus
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
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
      if (!mounted) return;

      if (q.isEmpty) {
        setState(() => _suggestions = []);
        return;
      }

      setState(() => _loading = true);
      try {
        final results = await MapKitSearch.autocomplete(q);
        if (!mounted) return;
        setState(() => _suggestions = results);
      } catch (_) {
        if (!mounted) return;
        setState(() => _suggestions = []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _selectSuggestion(_PlaceSuggestion s) async {
    setState(() => _loading = true);
    try {
      final resolved = await MapKitSearch.resolve(s.title, s.subtitle);
      if (!mounted) return;
      Navigator.pop(context, resolved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't find that place. Try another.")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AtlasPalette.background,
      appBar: AppBar(
        backgroundColor: AtlasPalette.background,
        surfaceTintColor: AtlasPalette.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AtlasPalette.primaryText),
        title: const Text(
          "Search",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AtlasPalette.primaryText,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AtlasPalette.divider),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            // Search field (same vibe as your _AtlasTextField)
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: AtlasPalette.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: "Where to?",
                hintStyle: TextStyle(
                  color: AtlasPalette.secondaryText.withOpacity(0.7),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.45),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AtlasPalette.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AtlasPalette.accent, width: 1.4),
                ),
                prefixIcon: const Icon(Icons.search, color: AtlasPalette.secondaryText),
                suffixIcon: _loading
                    ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : (_controller.text.isEmpty
                    ? null
                    : IconButton(
                  onPressed: () => _controller.clear(),
                  icon: const Icon(Icons.close, color: AtlasPalette.secondaryText),
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
    return Center(
      child: Text(
        "Start typing to search nearby places.",
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AtlasPalette.secondaryText,
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
            const Icon(Icons.place_outlined, color: AtlasPalette.secondaryText),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AtlasPalette.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

/// What Flutter receives from autocomplete()
class _PlaceSuggestion {
  final String title;
  final String subtitle;
  const _PlaceSuggestion({required this.title, required this.subtitle});

  factory _PlaceSuggestion.fromMap(Map<dynamic, dynamic> m) {
    return _PlaceSuggestion(
      title: (m['title'] as String?) ?? '',
      subtitle: (m['subtitle'] as String?) ?? '',
    );
  }
}

/// What Flutter returns to Home after resolve()
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

    final list = (res ?? const [])
        .cast<Map<dynamic, dynamic>>()
        .map(_PlaceSuggestion.fromMap)
        .where((s) => s.title.isNotEmpty)
        .toList();

    return list;
  }

  static Future<ResolvedPlace> resolve(String title, String subtitle) async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'resolve',
      {'title': title, 'subtitle': subtitle},
    );

    if (res == null) throw Exception('resolve returned null');

    final lat = (res['lat'] as num).toDouble();
    final lng = (res['lng'] as num).toDouble();

    return ResolvedPlace(
      title: (res['title'] as String?) ?? title,
      subtitle: (res['subtitle'] as String?) ?? subtitle,
      latLng: LatLng(lat, lng),
    );
  }
}
