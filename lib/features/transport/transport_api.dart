// lib/features/transport/transport_api.dart

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

  Future<Map<String, dynamic>> publicJourney({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    DateTime? dateTime,
    String service = 'traveline',
    bool groupByRoute = false,
    bool showCallingPoints = false,
  }) async {
    final when = (dateTime ?? DateTime.now()).toLocal();

    final uri = Uri.parse('$_baseUrl/public_journey.json').replace(
      queryParameters: {
        'from': _toLonLat(fromLon, fromLat),
        'to': _toLonLat(toLon, toLat),
        'date': _formatDate(when),
        'time': _formatTime(when),
        'service': service,
        'group_by_route': groupByRoute.toString(),
        'show_calling_points': showCallingPoints.toString(),
        'app_id': appId,
        'app_key': appKey,
      },
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'TransportAPI public_journey request failed (${response.statusCode}): ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _toLonLat(double lon, double lat) {
    return 'lonlat:$lon,$lat';
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}