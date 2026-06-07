import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import '../../../core/models/swim_session.dart';

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

  Future<List<SwimSession>> fetchSwimmingWorkouts({int days = 90}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));

    try {
      final workouts = await _health.getHealthDataFromTypes(
        startTime: from,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );

      // Dans health 13.x, workoutType est une String dans workoutSummary
      final swimmingWorkouts = workouts.where((w) {
        final summary = w.workoutSummary;
        if (summary == null) return false;
        final type = summary.workoutType.toUpperCase();
        return type.contains('SWIM');
      }).toList();

      if (swimmingWorkouts.isEmpty) return [];

      final List<SwimSession> sessions = [];
      for (final workout in swimmingWorkouts) {
        final summary = workout.workoutSummary!;
        final wFrom = workout.dateFrom;
        final wTo = workout.dateTo;

        final details = await _health.getHealthDataFromTypes(
          startTime: wFrom.subtract(const Duration(minutes: 2)),
          endTime: wTo.add(const Duration(minutes: 2)),
          types: [
            HealthDataType.HEART_RATE,
            HealthDataType.ACTIVE_ENERGY_BURNED,
            HealthDataType.DISTANCE_DELTA,
          ],
        );

        final hrPoints = details
            .where((p) => p.type == HealthDataType.HEART_RATE)
            .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
            .toList();
        final calPoints = details
            .where((p) => p.type == HealthDataType.ACTIVE_ENERGY_BURNED)
            .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
            .toList();
        final distPoints = details
            .where((p) => p.type == HealthDataType.DISTANCE_DELTA)
            .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
            .toList();

        sessions.add(SwimSession(
          startedAt: wFrom,
          endedAt: wTo,
          durationSeconds: wTo.difference(wFrom).inSeconds,
          distanceMeters: distPoints.isNotEmpty
              ? distPoints.reduce((a, b) => a + b)
              : summary.totalDistance.toDouble(),
          heartRateAvg: hrPoints.isNotEmpty
              ? hrPoints.reduce((a, b) => a + b) / hrPoints.length
              : null,
          heartRateMax: hrPoints.isNotEmpty
              ? hrPoints.reduce((a, b) => a > b ? a : b)
              : null,
          calories: calPoints.isNotEmpty
              ? calPoints.reduce((a, b) => a + b)
              : summary.totalEnergyBurned.toDouble(),
          locationLabel: 'Importé depuis Apple Watch',
        ));
      }
      return sessions;
    } catch (e) {
      return [];
    }
  }
}

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());
