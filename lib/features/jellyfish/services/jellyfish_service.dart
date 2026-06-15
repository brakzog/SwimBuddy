import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/prefs_service.dart';
import '../models/jellyfish_report.dart';

class JellyfishData {
  final int reportCount;
  final int safeReportCount;
  final int alertReportCount;
  final int communityReportCount;
  final int externalReportCount;
  final double? nearestKm;
  final int? hoursAgo;
  final bool hasAlert;
  final String? error;
  final List<JellyfishReport> reports;

  const JellyfishData({
    this.reportCount = 0,
    this.safeReportCount = 0,
    this.alertReportCount = 0,
    this.communityReportCount = 0,
    this.externalReportCount = 0,
    this.nearestKm,
    this.hoursAgo,
    this.hasAlert = false,
    this.error,
    this.reports = const [],
  });
}

class JellyfishService {
  static const _collection = 'jellyfish_reports';
  static const _acriBaseUrl = 'https://meduse.acri.fr/api/v1';
  static const _inaturalistTaxonId = 48332; // Scyphozoa, true jellyfish.
  static const _inaturalistBaseUrl = 'https://api.inaturalist.org/v1';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LocationService _locationService;
  final PrefsService _prefsService;
  final Dio _dio;

  JellyfishService(
    this._firestore,
    this._auth,
    this._locationService,
    this._prefsService, {
    Dio? dio,
  }) : _dio = dio ?? Dio();

  Future<JellyfishData> fetchNearbyJellyfish() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      return const JellyfishData(error: 'Position GPS indisponible');
    }

    try {
      final radiusKm = _prefsService.jellyfishRadiusKm;
      final now = DateTime.now();
      final since = now.subtract(const Duration(hours: 48));

      final communityReports = await _fetchCommunityReports(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: radiusKm,
        now: now,
        since: since,
      );

      final acriReports = await _fetchAcriReports(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: radiusKm,
        now: now,
      );

      // iNaturalist reste un fallback légal/gratuit, mais ACRI est bien plus
      // pertinent pour la France car il gère aussi les observations "none".
      final inaturalistReports = acriReports.isEmpty
          ? await _fetchINaturalistReports(
              lat: position.latitude,
              lng: position.longitude,
              radiusKm: radiusKm,
              now: now,
            )
          : const <JellyfishReport>[];

      final externalReports = [...acriReports, ...inaturalistReports];
      final nearbyReports = [...communityReports, ...externalReports]
        ..sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));

      final alertReports = nearbyReports.where((r) => r.type.isAlert).toList();
      final safeReports = nearbyReports.where((r) => !r.type.isAlert).toList();
      final nearestAlert = alertReports.isEmpty ? null : alertReports.first;

      return JellyfishData(
        reportCount: nearbyReports.length,
        safeReportCount: safeReports.length,
        alertReportCount: alertReports.length,
        communityReportCount: communityReports.length,
        externalReportCount: externalReports.length,
        nearestKm: nearestAlert?.distanceKm,
        hoursAgo: nearestAlert == null
            ? null
            : now.difference(nearestAlert.reportedAt).inHours,
        hasAlert: alertReports.isNotEmpty,
        reports: nearbyReports,
      );
    } on FirebaseException catch (e) {
      return JellyfishData(error: 'Erreur Firestore: ${e.message}');
    } catch (e) {
      return JellyfishData(error: 'Erreur: $e');
    }
  }

  Future<List<JellyfishReport>> _fetchCommunityReports({
    required double lat,
    required double lng,
    required double radiusKm,
    required DateTime now,
    required DateTime since,
  }) async {
    // Une seule clause Firestore volontairement : pas besoin d'index composite
    // pour la V1, on filtre ensuite localement sur reportedAt et la distance.
    final snapshot = await _firestore
        .collection(_collection)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt')
        .limit(300)
        .get();

    return snapshot.docs
        .map(JellyfishReport.fromDoc)
        .where((report) => report.reportedAt.isAfter(since))
        .map((report) => report.copyWithDistance(_haversineKm(
              lat,
              lng,
              report.lat,
              report.lng,
            )))
        .where((report) => (report.distanceKm ?? double.infinity) <= radiusKm)
        .toList();
  }

  Future<List<JellyfishReport>> _fetchAcriReports({
    required double lat,
    required double lng,
    required double radiusKm,
    required DateTime now,
  }) async {
    try {
      final since = now.toUtc().subtract(const Duration(hours: 72));
      final response = await _dio.get<Map<String, dynamic>>(
        '$_acriBaseUrl/campaigns/meduse/observations',
        queryParameters: {
          'campaign': 'meduse',
          'filter': "observation_date ge '${_formatIsoUtc(since)}'",
          'count': true,
          'limit': 300,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'SwimBuddy/1.0 (ACRI Meduse public API lookup)',
          },
        ),
      );

      final values = response.data?['value'];
      if (values is! List) return const [];

      return values
          .whereType<Map<String, dynamic>>()
          .map((json) => _reportFromAcri(json, now))
          .whereType<JellyfishReport>()
          .map((report) => report.copyWithDistance(_haversineKm(
                lat,
                lng,
                report.lat,
                report.lng,
              )))
          .where((report) => (report.distanceKm ?? double.infinity) <= radiusKm)
          .toList();
    } catch (_) {
      // ACRI est la source externe principale, mais elle reste externe :
      // si elle répond mal, l'app continue avec Firestore puis iNaturalist.
      return const [];
    }
  }

  JellyfishReport? _reportFromAcri(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final id = json['id'];
    final location = json['location'];
    if (id == null || location is! List || location.length < 2) return null;

    final lat = (location[0] as num?)?.toDouble();
    final lng = (location[1] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final data = json['data'] as Map<String, dynamic>?;
    final quantity = data?['quantity'] as String?;
    final observedAt = _readDate(json['observation_date']) ?? now;
    final species = data?['species'] as String?;
    final comment = data?['comment'] as String?;

    return JellyfishReport(
      id: 'acri_$id',
      type: _typeFromAcriQuantity(quantity),
      source: JellyfishReportSource.acri,
      lat: lat,
      lng: lng,
      reportedAt: observedAt,
      expiresAt: observedAt.add(const Duration(days: 3)),
      species: species,
      locationLabel: comment == null || comment.trim().isEmpty
          ? 'Observation ACRI Méduse'
          : comment.trim(),
    );
  }

  JellyfishReportType _typeFromAcriQuantity(String? quantity) {
    return switch (quantity) {
      'none' => JellyfishReportType.none,
      'one' => JellyfishReportType.few,
      'several' => JellyfishReportType.many,
      'many' => JellyfishReportType.many,
      'lots' => JellyfishReportType.many,
      _ => JellyfishReportType.few,
    };
  }

  Future<List<JellyfishReport>> _fetchINaturalistReports({
    required double lat,
    required double lng,
    required double radiusKm,
    required DateTime now,
  }) async {
    try {
      final since = now.subtract(const Duration(days: 7));
      final response = await _dio.get<Map<String, dynamic>>(
        '$_inaturalistBaseUrl/observations',
        queryParameters: {
          'taxon_id': _inaturalistTaxonId,
          'lat': lat,
          'lng': lng,
          'radius': radiusKm.clamp(1, 50),
          'd1': _formatDate(since),
          'd2': _formatDate(now),
          'has[]': 'geo',
          'quality_grade': 'research,needs_id',
          'order_by': 'observed_on',
          'order': 'desc',
          'per_page': 50,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'User-Agent': 'SwimBuddy/1.0 (jellyfish lookup; iNaturalist API)',
          },
        ),
      );

      final results = response.data?['results'];
      if (results is! List) return const [];

      return results
          .whereType<Map<String, dynamic>>()
          .map((json) => _reportFromINaturalist(json, now))
          .whereType<JellyfishReport>()
          .map((report) => report.copyWithDistance(_haversineKm(
                lat,
                lng,
                report.lat,
                report.lng,
              )))
          .where((report) => (report.distanceKm ?? double.infinity) <= radiusKm)
          .toList();
    } catch (_) {
      // L'API externe est un bonus : si elle répond mal ou pas du tout,
      // l'app reste utilisable avec les signalements communautaires Firestore.
      return const [];
    }
  }

  JellyfishReport? _reportFromINaturalist(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final id = json['id'];
    final coords = _readCoordinates(json);
    if (id == null || coords == null) return null;

    final observedAt = _readDate(json['time_observed_at']) ??
        _readDate(json['observed_on']) ??
        now;
    final taxon = json['taxon'] as Map<String, dynamic>?;
    final species = taxon == null
        ? null
        : (taxon['preferred_common_name'] ?? taxon['name']) as String?;

    return JellyfishReport(
      id: 'inaturalist_$id',
      type: JellyfishReportType.few,
      source: JellyfishReportSource.inaturalist,
      lat: coords.$1,
      lng: coords.$2,
      reportedAt: observedAt,
      expiresAt: observedAt.add(const Duration(days: 7)),
      species: species,
      locationLabel: 'Observation iNaturalist',
    );
  }

  (double, double)? _readCoordinates(Map<String, dynamic> json) {
    final geojson = json['geojson'] as Map<String, dynamic>?;
    final coordinates = geojson?['coordinates'];
    if (coordinates is List && coordinates.length >= 2) {
      final lng = (coordinates[0] as num?)?.toDouble();
      final lat = (coordinates[1] as num?)?.toDouble();
      if (lat != null && lng != null) return (lat, lng);
    }

    final location = json['location'] as String?;
    if (location == null || !location.contains(',')) return null;
    final parts = location.split(',');
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }

  Future<void> submitUserReport(JellyfishReportType type) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Utilisateur non connecté');

    final position = await _locationService.getCurrentPosition();
    if (position == null) throw StateError('Position GPS indisponible');

    final now = DateTime.now();
    await _firestore.collection(_collection).add({
      'type': type.name,
      'source': JellyfishReportSource.user.name,
      'lat': position.latitude,
      'lng': position.longitude,
      'position': GeoPoint(position.latitude, position.longitude),
      'reportedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
    });
  }

  DateTime? _readDate(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatIsoUtc(DateTime date) {
    return date.toUtc().toIso8601String();
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double degrees) => degrees * math.pi / 180;
}

final jellyfishServiceProvider = Provider<JellyfishService>((ref) {
  return JellyfishService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    ref.read(locationServiceProvider),
    ref.read(prefsServiceProvider),
  );
});

class JellyfishNotifier extends AsyncNotifier<JellyfishData> {
  @override
  Future<JellyfishData> build() => _fetch();

  Future<JellyfishData> _fetch() =>
      ref.read(jellyfishServiceProvider).fetchNearbyJellyfish();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> submitReport(JellyfishReportType type) async {
    await ref.read(jellyfishServiceProvider).submitUserReport(type);
    await refresh();
  }
}

final jellyfishProvider =
    AsyncNotifierProvider<JellyfishNotifier, JellyfishData>(
        JellyfishNotifier.new);
