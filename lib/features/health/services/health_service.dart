import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import '../../../core/models/swim_session.dart';
import '../../../core/services/observability_service.dart';

class HealthResult {
  final double? heartRateAvg;
  final double? heartRateMax;
  final double? calories;
  final double? distanceMeters;
  final double? waterTemperatureCelsius;

  const HealthResult({
    this.heartRateAvg,
    this.heartRateMax,
    this.calories,
    this.distanceMeters,
    this.waterTemperatureCelsius,
  });

  bool get hasData =>
      heartRateAvg != null ||
          heartRateMax != null ||
          calories != null ||
          distanceMeters != null ||
          waterTemperatureCelsius != null;
}

class HealthService {
  final Health _health = Health();

  static const _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.DISTANCE_SWIMMING,
    HealthDataType.WORKOUT,
    HealthDataType.WATER_TEMPERATURE,
  ];

  // Demande les permissions santé à l'utilisateur
  Future<bool> requestPermissions() async {
    final permissions = _types.map((_) => HealthDataAccess.READ).toList();
    try {
      return await _health.requestAuthorization(_types,
          permissions: permissions);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Health requestPermissions error: $e\n$st');
      }
      await ObservabilityService.recordNonFatal(
        e,
        st,
        key: 'health_permissions_failure',
        reason: 'health_permissions_failure',
      );
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

      final waterTemperaturePoints = data
          .where((p) => p.type == HealthDataType.WATER_TEMPERATURE)
          .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
          .where((value) => value > -5 && value < 50)
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

      final waterTemperature = waterTemperaturePoints.isNotEmpty
          ? waterTemperaturePoints.reduce((a, b) => a + b) /
              waterTemperaturePoints.length
          : null;

      return HealthResult(
        heartRateAvg: heartRateAvg,
        heartRateMax: heartRateMax,
        calories: totalCalories,
        distanceMeters: totalDistance,
        waterTemperatureCelsius: waterTemperature,
      );
    } catch (e, st) {
      await ObservabilityService.recordNonFatal(
        e,
        st,
        key: 'health_session_data_failure',
        reason: 'health_session_data_failure',
      );
      return const HealthResult();
    }
  }

  Future<List<SwimSession>> fetchSwimmingWorkouts({int days = 90}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));

    try {
      final rawWorkouts = await _health.getHealthDataFromTypes(
        startTime: from,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );

      final swimmingWorkouts = rawWorkouts.where((w) {
        final summary = w.workoutSummary;
        if (summary == null) return false;
        return summary.workoutType.toUpperCase().contains('SWIM');
      }).toList();

      if (swimmingWorkouts.isEmpty) return const [];

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
            HealthDataType.WATER_TEMPERATURE,
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
        final waterTemperaturePoints = details
            .where((p) => p.type == HealthDataType.WATER_TEMPERATURE)
            .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
            .where((value) => value > -5 && value < 50)
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
          waterTempCelsius: waterTemperaturePoints.isNotEmpty
              ? waterTemperaturePoints.reduce((a, b) => a + b) /
                  waterTemperaturePoints.length
              : null,
          waterTemperatureSource: waterTemperaturePoints.isNotEmpty
              ? SwimTemperatureSource.watch
              : null,
          source: SwimSessionSource.appleHealth,
        ));
      }
      return sessions;
    } catch (e, st) {
      await ObservabilityService.recordNonFatal(
        e,
        st,
        key: 'health_swim_import_failure',
        reason: 'health_swim_import_failure',
      );
      return const [];
    }
  }
}

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());