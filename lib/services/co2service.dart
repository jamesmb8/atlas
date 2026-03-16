class Co2Service {
  const Co2Service();

  double walkingKg(double distanceMeters) {
    return 0.0;
  }

  double drivingKg(double distanceMeters) {
    final km = distanceMeters / 1000;

    // TODO: replace with chosen England / UK government factor
    const kgPerKm = 0.171;

    return double.parse((km * kgPerKm).toStringAsFixed(2));
  }

  double publicTransportKg(double distanceMeters) {
    final km = distanceMeters / 1000;

    // TODO: replace with chosen England / UK government factor
    const kgPerKm = 0.041;

    return double.parse((km * kgPerKm).toStringAsFixed(2));
  }
}