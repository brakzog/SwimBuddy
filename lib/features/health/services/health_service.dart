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
      // Récupère les workouts
      final workouts = await _health.getHealthDataFromTypes(
        startTime: from,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );

      // Filtre uniquement la natation
    /*  final swimmingWorkouts = workouts.where((w) {
        final value = w.value;
        if (value is WorkoutHealthValue) {
          return value.workoutActivityType == HealthWorkoutActivityType.SWIMMING ||
              value.workoutActivityType == HealthWorkoutActivityType.SWIMMING_OPEN_WATER ||
              value.workoutActivityType == HealthWorkoutActivityType.SWIMMING_POOL;
        }
        return false;
      }).toList();*/
      final swimmingWorkouts = workouts.where((w) {
        return w.value is WorkoutHealthValue;
      }).toList();

// Debug — à supprimer après
      for (final w in swimmingWorkouts) {
        final v = w.value as WorkoutHealthValue;
        print('🏋️ Workout: ${v.workoutActivityType} — ${w.dateFrom}');
      }

      if (swimmingWorkouts.isEmpty) return [];

      // Pour chaque workout, récupère FC + calories + distance
      final List<SwimSession> sessions = [];

      for (final workout in swimmingWorkouts) {
        final wValue = workout.value as WorkoutHealthValue;
        final wFrom = workout.dateFrom;
        final wTo = workout.dateTo;

        // Récupère les données détaillées sur la plage du workout
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

        final hrAvg = hrPoints.isNotEmpty
            ? hrPoints.reduce((a, b) => a + b) / hrPoints.length
            : null;
        final hrMax = hrPoints.isNotEmpty
            ? hrPoints.reduce((a, b) => a > b ? a : b)
            : null;
        final totalCal = calPoints.isNotEmpty
            ? calPoints.reduce((a, b) => a + b)
            : wValue.totalEnergyBurned?.toDouble();
        final totalDist = distPoints.isNotEmpty
            ? distPoints.reduce((a, b) => a + b)
            : wValue.totalDistance?.toDouble() ?? 0;

        sessions.add(SwimSession(
          startedAt: wFrom,
          endedAt: wTo,
          durationSeconds: wTo.difference(wFrom).inSeconds,
          distanceMeters: totalDist,
          heartRateAvg: hrAvg,
          heartRateMax: hrMax,
          calories: totalCal,
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
