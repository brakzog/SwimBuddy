import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

class HealthResult {
  final double? heartRateAvg;
  final double? heartRateMax;
  final double? calories;
  final double? distanceMeters;

  const HealthResult({
    this.heartRateAvg,
    this.heartRateMax,
    this.calories,
    this.distanceMeters,
  });

  bool get hasData =>
      heartRateAvg != null ||
      heartRateMax != null ||
      calories != null ||
      distanceMeters != null;
}

class HealthService {
  final Health _health = Health();

  static const _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WORKOUT,
  ];

  // Demande les permissions santé à l'utilisateur
  Future<bool> requestPermissions() async {
    final permissions = _types.map((_) => HealthDataAccess.READ).toList();
    try {
      return await _health.requestAuthorization(_types,
          permissions: permissions);
    } catch (e) {
      return false;
    }
  }

  // Vérifie si les permissions sont déjà accordées
  Future<bool> hasPermissions() async {
    try {
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      final result = await _health.hasPermissions(_types,
          permissions: permissions);
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  // Récupère les données de santé pour une plage horaire (la session)
  Future<HealthResult> fetchSessionData({
    required DateTime from,
    required DateTime to,
  }) async {
    try {

      final searchFrom = from.subtract(const Duration(minutes: 30));
      final searchTo = to.add(const Duration(minutes: 30));

      final data = await _health.getHealthDataFromTypes(
        startTime: searchFrom,
        endTime: searchTo,
        types: _types,
      );

      // Sépare les données par type
      final heartPoints = data
          .where((p) => p.type == HealthDataType.HEART_RATE)
          .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
          .toList();

      final caloriesPoints = data
          .where((p) => p.type == HealthDataType.ACTIVE_ENERGY_BURNED)
          .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
          .toList();

      final distancePoints = data
          .where((p) => p.type == HealthDataType.DISTANCE_DELTA)
          .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
          .toList();

      // Calcule les agrégats
      final heartRateAvg = heartPoints.isNotEmpty
          ? heartPoints.reduce((a, b) => a + b) / heartPoints.length
          : null;

      final heartRateMax =
          heartPoints.isNotEmpty ? heartPoints.reduce((a, b) => a > b ? a : b) : null;

      final totalCalories = caloriesPoints.isNotEmpty
          ? caloriesPoints.reduce((a, b) => a + b)
          : null;

      final totalDistance = distancePoints.isNotEmpty
          ? distancePoints.reduce((a, b) => a + b)
          : null;

      return HealthResult(
        heartRateAvg: heartRateAvg,
        heartRateMax: heartRateMax,
        calories: totalCalories,
        distanceMeters: totalDistance,
      );
    } catch (e) {
      return const HealthResult();
    }
  }
}

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());
