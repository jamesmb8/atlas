class Co2Service {
  const Co2Service();

  double walkingKg(double distanceMeters) {
    return 0.0;
  }

  double drivingKg(double distanceMeters) {
    final km = distanceMeters / 1000;


    const kgPerKm = 0.16272;

    return double.parse((km * kgPerKm).toStringAsFixed(2));
  }

  double publicTransportKg(double distanceMeters) {
    final km = distanceMeters / 1000;


    const kgPerKm = 0.0351;

    return double.parse((km * kgPerKm).toStringAsFixed(2));
  }
}