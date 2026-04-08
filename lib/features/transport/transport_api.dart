// lib/features/transport/transport_api.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  // Fast first try, then one rescue try for slower real-device/mobile networks.
  static const List<Duration> _attemptTimeouts = <Duration>[
    Duration(seconds: 10),
    Duration(seconds: 16),
  ];

  static const Duration _retryDelay = Duration(milliseconds: 700);

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

    return _getJsonWithRetry(uri);
  }

  Future<Map<String, dynamic>> _getJsonWithRetry(Uri uri) async {
    Object? lastError;

    for (var attempt = 0; attempt < _attemptTimeouts.length; attempt++) {
      try {
        final response = await _client
            .get(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
          },
        )
            .timeout(_attemptTimeouts[attempt]);

        if (response.statusCode == 200) {
          return _decodeMap(response.body);
        }

        final shouldRetry = _shouldRetryStatus(response.statusCode) &&
            attempt < _attemptTimeouts.length - 1;

        if (shouldRetry) {
          await Future.delayed(_retryDelay);
          continue;
        }

        throw Exception(
          'TransportAPI public_journey request failed '
              '(${response.statusCode}): ${response.body}',
        );
      } on TimeoutException catch (e) {
        lastError = e;

        if (attempt < _attemptTimeouts.length - 1) {
          await Future.delayed(_retryDelay);
          continue;
        }

        throw Exception('TransportAPI public_journey request timed out');
      } on SocketException catch (e) {
        lastError = e;

        if (attempt < _attemptTimeouts.length - 1) {
          await Future.delayed(_retryDelay);
          continue;
        }

        throw Exception('TransportAPI public_journey network error: $e');
      } catch (e) {
        lastError = e;
        rethrow;
      }
    }

    throw Exception('TransportAPI public_journey failed: $lastError');
  }

  bool _shouldRetryStatus(int statusCode) {
    return statusCode == 408 ||
        statusCode == 425 ||
        statusCode == 429 ||
        statusCode >= 500;
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return decoded.map(
            (key, value) => MapEntry(key.toString(), value),
      );
    }

    throw Exception('TransportAPI public_journey returned a non-map JSON body');
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