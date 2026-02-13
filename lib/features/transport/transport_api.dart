import 'package:cloud_functions/cloud_functions.dart';

class TransportProxyService {
  final FirebaseFunctions _functions;

  TransportProxyService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<dynamic> planJourney({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final callable = _functions.httpsCallable('planJourney');

    final res = await callable.call({
      'fromLat': fromLat,
      'fromLng': fromLng,
      'toLat': toLat,
      'toLng': toLng,
    });

    return res.data;
  }
}
