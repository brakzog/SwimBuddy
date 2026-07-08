import 'package:cloud_firestore/cloud_firestore.dart';

enum JellyfishReportType {
  none,
  few,
  many,
  sting;

  static JellyfishReportType fromString(String value) {
    return JellyfishReportType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => JellyfishReportType.few,
    );
  }

  bool get isAlert => this != JellyfishReportType.none;

  String get label => switch (this) {
        JellyfishReportType.none => 'Pas de méduse observée',
        JellyfishReportType.few => 'Quelques méduses',
        JellyfishReportType.many => 'Beaucoup de méduses',
        JellyfishReportType.sting => 'Piqûre / brûlure constatée',
      };
}

enum JellyfishReportSource {
  user,
  inaturalist,
  meduseo,
  acri;

  static JellyfishReportSource fromString(String value) {
    return JellyfishReportSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => JellyfishReportSource.user,
    );
  }
}

class JellyfishReport {
  final String id;
  final JellyfishReportType type;
  final JellyfishReportSource source;
  final double lat;
  final double lng;
  final DateTime reportedAt;
  final DateTime expiresAt;
  final String? createdBy;
  final String? locationLabel;
  final String? species;
  final double? distanceKm;

  const JellyfishReport({
    required this.id,
    required this.type,
    required this.source,
    required this.lat,
    required this.lng,
    required this.reportedAt,
    required this.expiresAt,
    this.createdBy,
    this.locationLabel,
    this.species,
    this.distanceKm,
  });

  factory JellyfishReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final geoPoint = data['position'] as GeoPoint?;

    return JellyfishReport(
      id: doc.id,
      type: JellyfishReportType.fromString(data['type'] as String? ?? 'few'),
      source: JellyfishReportSource.fromString(
        data['source'] as String? ?? 'user',
      ),
      lat: (data['lat'] as num?)?.toDouble() ?? geoPoint?.latitude ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? geoPoint?.longitude ?? 0,
      reportedAt: _readTimestamp(data['reportedAt']) ?? DateTime.now(),
      expiresAt: _readTimestamp(data['expiresAt']) ?? DateTime.now(),
      createdBy: data['createdBy'] as String?,
      locationLabel: data['locationLabel'] as String?,
      species: data['species'] as String?,
    );
  }

  JellyfishReport copyWithDistance(double distanceKm) {
    return JellyfishReport(
      id: id,
      type: type,
      source: source,
      lat: lat,
      lng: lng,
      reportedAt: reportedAt,
      expiresAt: expiresAt,
      createdBy: createdBy,
      locationLabel: locationLabel,
      species: species,
      distanceKm: distanceKm,
    );
  }

  static DateTime? _readTimestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
