import 'package:cloud_firestore/cloud_firestore.dart';

enum SwimTemperatureSource { watch, oceanApi, manual }

enum SwimSessionSource {
  swimTracker,
  appleHealth,
  appleWatch,
  healthConnect,
  wearOs,
}

enum SwimZoneStatus { favorable, vigilance, discouraged }

extension SwimTemperatureSourceX on SwimTemperatureSource {
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

extension SwimSessionSourceX on SwimSessionSource {
  String get storageValue => name;

  String get label {
    switch (this) {
      case SwimSessionSource.swimTracker:
        return 'SwimTracker';
      case SwimSessionSource.appleHealth:
        return 'Apple Santé';
      case SwimSessionSource.appleWatch:
        return 'Apple Watch';
      case SwimSessionSource.healthConnect:
        return 'Health Connect';
      case SwimSessionSource.wearOs:
        return 'Wear OS';
    }
  }

  static SwimSessionSource fromStorage(String? value) {
    for (final source in SwimSessionSource.values) {
      if (source.name == value) return source;
    }
    return SwimSessionSource.swimTracker;
  }
}

extension SwimZoneStatusX on SwimZoneStatus {
  String get storageValue => name;

  String get label {
    switch (this) {
      case SwimZoneStatus.favorable:
        return 'Conditions favorables';
      case SwimZoneStatus.vigilance:
        return 'Vigilance méduses';
      case SwimZoneStatus.discouraged:
        return 'Baignade déconseillée';
    }
  }

  static SwimZoneStatus fromStorage(String? value, {bool jellyfishAlert = false}) {
    for (final status in SwimZoneStatus.values) {
      if (status.name == value) return status;
    }
    return jellyfishAlert
        ? SwimZoneStatus.vigilance
        : SwimZoneStatus.favorable;
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
  final double? waveHeightMeters;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final DateTime? conditionsCapturedAt;
  final SwimZoneStatus zoneStatus;
  final SwimSessionSource source;

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
    this.waveHeightMeters,
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.conditionsCapturedAt,
    this.zoneStatus = SwimZoneStatus.favorable,
    this.source = SwimSessionSource.swimTracker,
  });

  bool get jellyfishAlert => zoneStatus != SwimZoneStatus.favorable;

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

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
        if (waveHeightMeters != null) 'wave_height_meters': waveHeightMeters,
        if (locationLabel != null) 'location_label': locationLabel,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (conditionsCapturedAt != null)
          'conditions_captured_at': Timestamp.fromDate(conditionsCapturedAt!),
        'zone_status': zoneStatus.storageValue,
        'jellyfish_alert': jellyfishAlert,
        'source': source.storageValue,
        'created_at': FieldValue.serverTimestamp(),
      };

  factory SwimSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const <String, dynamic>{};
    final startedAt = _dateFrom(d['started_at']) ?? DateTime.now();
    final endedAt = _dateFrom(d['ended_at']) ?? startedAt;
    final legacyJellyfishAlert = d['jellyfish_alert'] as bool? ?? false;

    return SwimSession(
      id: doc.id,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: (d['duration_seconds'] as num?)?.toInt() ??
          endedAt.difference(startedAt).inSeconds.clamp(0, 1 << 31).toInt(),
      distanceMeters: (d['distance_meters'] as num?)?.toDouble() ?? 0,
      heartRateAvg: (d['heart_rate_avg'] as num?)?.toDouble(),
      heartRateMax: (d['heart_rate_max'] as num?)?.toDouble(),
      calories: (d['calories'] as num?)?.toDouble(),
      waterTempCelsius: (d['water_temp_celsius'] as num?)?.toDouble(),
      waterTemperatureSource: SwimTemperatureSourceX.fromStorage(
        d['water_temperature_source'] as String?,
      ),
      airTempCelsius: (d['air_temp_celsius'] as num?)?.toDouble(),
      waveHeightMeters: (d['wave_height_meters'] as num?)?.toDouble(),
      locationLabel: d['location_label'] as String?,
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      conditionsCapturedAt: _dateFrom(d['conditions_captured_at']),
      zoneStatus: SwimZoneStatusX.fromStorage(
        d['zone_status'] as String?,
        jellyfishAlert: legacyJellyfishAlert,
      ),
      source: SwimSessionSourceX.fromStorage(d['source'] as String?),
    );
  }

  static DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  SwimTemperatureSource? get effectiveWaterTemperatureSource {
    if (waterTempCelsius == null) return null;
    return waterTemperatureSource ?? SwimTemperatureSource.oceanApi;
  }
}
