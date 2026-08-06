import 'package:cloud_firestore/cloud_firestore.dart';

enum SwimTemperatureSource {
  watch,
  oceanApi,
  manual,
}

extension SwimTemperatureSourceLabel on SwimTemperatureSource {
  String get storageValue => name;

  String get label {
    switch (this) {
      case SwimTemperatureSource.watch:
        return 'Mesurée par la montre';
      case SwimTemperatureSource.oceanApi:
        return 'Conditions au début de la séance';
      case SwimTemperatureSource.manual:
        return 'Saisie manuellement';
    }
  }

  static SwimTemperatureSource? fromStorage(String? value) {
    for (final source in SwimTemperatureSource.values) {
      if (source.name == value) return source;
    }
    return null;
  }
}

class SwimSession {
  final String? id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double? heartRateAvg;
  final double? heartRateMax;
  final double? calories;
  final double? waterTempCelsius;
  final SwimTemperatureSource? waterTemperatureSource;
  final double? airTempCelsius;
  final String? locationLabel;
  final bool jellyfishAlert;

  const SwimSession({
    this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    this.heartRateAvg,
    this.heartRateMax,
    this.calories,
    this.waterTempCelsius,
    this.waterTemperatureSource,
    this.airTempCelsius,
    this.locationLabel,
    this.jellyfishAlert = false,
  });

  // Durée formatée ex: "32:14"
  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Distance formatée ex: "2.34 km"
  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  // Sérialisation → Firestore
  Map<String, dynamic> toFirestore() => {
        'started_at': Timestamp.fromDate(startedAt),
        'ended_at': Timestamp.fromDate(endedAt),
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
        if (heartRateAvg != null) 'heart_rate_avg': heartRateAvg,
        if (heartRateMax != null) 'heart_rate_max': heartRateMax,
        if (calories != null) 'calories': calories,
        if (waterTempCelsius != null) 'water_temp_celsius': waterTempCelsius,
        if (waterTemperatureSource != null)
          'water_temperature_source': waterTemperatureSource!.storageValue,
        if (airTempCelsius != null) 'air_temp_celsius': airTempCelsius,
        if (locationLabel != null) 'location_label': locationLabel,
        'jellyfish_alert': jellyfishAlert,
        'created_at': FieldValue.serverTimestamp(),
      };

  // Désérialisation ← Firestore
  factory SwimSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return SwimSession(
      id: doc.id,
      startedAt: (d['started_at'] as Timestamp).toDate(),
      endedAt: (d['ended_at'] as Timestamp).toDate(),
      durationSeconds: d['duration_seconds'] as int,
      distanceMeters: (d['distance_meters'] as num).toDouble(),
      heartRateAvg: (d['heart_rate_avg'] as num?)?.toDouble(),
      heartRateMax: (d['heart_rate_max'] as num?)?.toDouble(),
      calories: (d['calories'] as num?)?.toDouble(),
      waterTempCelsius: (d['water_temp_celsius'] as num?)?.toDouble(),
      waterTemperatureSource: SwimTemperatureSourceLabel.fromStorage(
        d['water_temperature_source'] as String?,
      ),
      airTempCelsius: (d['air_temp_celsius'] as num?)?.toDouble(),
      locationLabel: d['location_label'] as String?,
      jellyfishAlert: d['jellyfish_alert'] as bool? ?? false,
    );
  }

  SwimTemperatureSource? get effectiveWaterTemperatureSource {
    if (waterTempCelsius == null) return null;
    return waterTemperatureSource ?? SwimTemperatureSource.oceanApi;
  }

  SwimSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    double? distanceMeters,
    double? heartRateAvg,
    double? heartRateMax,
    double? calories,
    double? waterTempCelsius,
    SwimTemperatureSource? waterTemperatureSource,
    double? airTempCelsius,
    String? locationLabel,
    bool? jellyfishAlert,
  }) =>
      SwimSession(
        id: id ?? this.id,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        heartRateAvg: heartRateAvg ?? this.heartRateAvg,
        heartRateMax: heartRateMax ?? this.heartRateMax,
        calories: calories ?? this.calories,
        waterTempCelsius: waterTempCelsius ?? this.waterTempCelsius,
        waterTemperatureSource:
            waterTemperatureSource ?? this.waterTemperatureSource,
        airTempCelsius: airTempCelsius ?? this.airTempCelsius,
        locationLabel: locationLabel ?? this.locationLabel,
        jellyfishAlert: jellyfishAlert ?? this.jellyfishAlert,
      );
}
