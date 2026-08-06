import 'package:flutter/foundation.dart';
import '../../../core/models/swim_session.dart';

enum SessionStatus { idle, running, finished }

@immutable
class SessionState {
  final SessionStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final Duration elapsed;
  final double? waterTempCelsius;
  final double? airTempCelsius;
  final double? waveHeightMeters;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final DateTime? conditionsCapturedAt;
  final SwimZoneStatus zoneStatus;

  const SessionState({
    this.status = SessionStatus.idle,
    this.startedAt,
    this.endedAt,
    this.elapsed = Duration.zero,
    this.waterTempCelsius,
    this.airTempCelsius,
    this.waveHeightMeters,
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.conditionsCapturedAt,
    this.zoneStatus = SwimZoneStatus.favorable,
  });

  bool get isRunning => status == SessionStatus.running;
  bool get isFinished => status == SessionStatus.finished;
  bool get isIdle => status == SessionStatus.idle;

  String get formattedElapsed {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Map<String, dynamic> toPersistedJson() => {
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (waterTempCelsius != null) 'waterTempCelsius': waterTempCelsius,
        if (airTempCelsius != null) 'airTempCelsius': airTempCelsius,
        if (waveHeightMeters != null) 'waveHeightMeters': waveHeightMeters,
        if (locationLabel != null) 'locationLabel': locationLabel,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (conditionsCapturedAt != null)
          'conditionsCapturedAt': conditionsCapturedAt!.toIso8601String(),
        'zoneStatus': zoneStatus.name,
      };

  factory SessionState.fromPersistedJson(Map<String, dynamic> json) {
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    if (startedAt == null) return const SessionState();
    return SessionState(
      status: SessionStatus.running,
      startedAt: startedAt,
      elapsed: DateTime.now().difference(startedAt),
      waterTempCelsius: (json['waterTempCelsius'] as num?)?.toDouble(),
      airTempCelsius: (json['airTempCelsius'] as num?)?.toDouble(),
      waveHeightMeters: (json['waveHeightMeters'] as num?)?.toDouble(),
      locationLabel: json['locationLabel'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      conditionsCapturedAt: DateTime.tryParse(
        json['conditionsCapturedAt'] as String? ?? '',
      ),
      zoneStatus: SwimZoneStatus.values.firstWhere(
        (value) => value.name == json['zoneStatus'],
        orElse: () => SwimZoneStatus.favorable,
      ),
    );
  }

  SessionState copyWith({
    SessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? elapsed,
  }) =>
      SessionState(
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        elapsed: elapsed ?? this.elapsed,
        waterTempCelsius: waterTempCelsius,
        airTempCelsius: airTempCelsius,
        waveHeightMeters: waveHeightMeters,
        locationLabel: locationLabel,
        latitude: latitude,
        longitude: longitude,
        conditionsCapturedAt: conditionsCapturedAt,
        zoneStatus: zoneStatus,
      );
}
