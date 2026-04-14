import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/services/co2service.dart';

void main() {
  group('Co2Service', () {
    const service = Co2Service();

    test('walking always returns 0.0', () {
      expect(service.walkingKg(0), 0.0);
      expect(service.walkingKg(1000), 0.0);
      expect(service.walkingKg(5000), 0.0);
    });

    test('driving returns correct CO2 for 1000m', () {
      expect(service.drivingKg(1000), 0.16);
    });

    test('driving rounds to 2 decimal places', () {
      expect(service.drivingKg(1500), 0.24);
    });

    test('public transport returns correct CO2 for 1000m', () {
      expect(service.publicTransportKg(1000), 0.04);
    });

    test('public transport rounds to 2 decimal places', () {
      expect(service.publicTransportKg(1500), 0.05);
    });

    test('zero distance returns zero for all modes', () {
      expect(service.walkingKg(0), 0.0);
      expect(service.drivingKg(0), 0.0);
      expect(service.publicTransportKg(0), 0.0);
    });
  });
}