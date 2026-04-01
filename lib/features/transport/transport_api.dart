import 'dart:convert';
import 'package:http/http.dart' as http;

class TransportApi {
  final String appId;
  final String appKey;
  final http.Client _client;

  TransportApi({
    required this.appId,
    required this.appKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://transportapi.com/v3/uk';

  Future<Map<String, dynamic>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    required String type,
    int maxResults = 5,
  }) async {
    final uri = Uri.parse('$_baseUrl/places.json').replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'type': type,
        'max_results': maxResults.toString(),
        'app_id': appId,
        'app_key': appKey,
      },
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'TransportAPI places request failed (${response.statusCode}): ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> searchNearbyPlacesList({
    required double latitude,
    required double longitude,
    required String type,
    int maxResults = 5,
  }) async {
    final decoded = await searchNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      type: type,
      maxResults: maxResults,
    );

    final members = decoded['member'];
    if (members is List) {
      return members.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    final results = decoded['results'];
    if (results is List) {
      return results.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    return const [];
  }
}