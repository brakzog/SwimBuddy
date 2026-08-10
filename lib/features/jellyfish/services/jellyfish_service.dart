import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/observability_service.dart';
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
  final int timeWindowHours;
  final bool hasAlert;
  final String? error;
  final List<JellyfishReport> reports;
  final DateTime? fetchedAt;

  const JellyfishData({
    this.reportCount = 0,
    this.safeReportCount = 0,
    this.alertReportCount = 0,
    this.communityReportCount = 0,
    this.externalReportCount = 0,
    this.nearestKm,
    this.hoursAgo,
    this.timeWindowHours = 72,
    this.hasAlert = false,
    this.error,
    this.reports = const [],
    this.fetchedAt,
  });
}

class JellyfishService {
  static const _collection = 'jellyfish_reports';
  static const _acriBaseUrl = 'https://meduse.acri.fr/api/v1';
  static const _inaturalistTaxonId = 48332; // Scyphozoa, true jellyfish.
  static const _inaturalistBaseUrl = 'https://api.inaturalist.org/v1';
  static const _obisBaseUrl = 'https://api.obis.org/v3';
  static const _gbifBaseUrl = 'https://api.gbif.org/v1';
  static const _scyphozoaScientificName = 'Scyphozoa';
  static const _externalTimeout = Duration(seconds: 6);

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

    final trace =
        FirebasePerformance.instance.newTrace('jellyfish_fetch');
    await trace.start();

    try {
      final radiusKm = _prefsService.jellyfishRadiusKm;
      final timeWindowHours = _prefsService.jellyfishTimeWindowHours;
      final now = DateTime.now();
      final since = now.subtract(Duration(hours: timeWindowHours));

      final communityReports = await _fetchCommunityReports(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: radiusKm,
        now: now,
        since: since,
      );

      // Les signalements SwimTracker sont toujours conservés en parallèle.
      // Pour les sources externes, on utilise un vrai fallback de disponibilité :
      // ACRI -> iNaturalist -> OBIS -> GBIF.
      //
      // Important : une réponse HTTP valide mais vide n'est PAS considérée
      // comme une panne. Dans ce cas on respecte la source principale et on
      // n'interroge pas inutilement les fallbacks.
      final acriResult = await _fetchAcriReports(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: radiusKm,
        now: now,
        since: since,
      );

      _ExternalFetchResult externalResult = acriResult;

      if (!externalResult.succeeded) {
        trace.incrementMetric('fallback_count', 1);
        await ObservabilityService.log(
          'Jellyfish fallback: ACRI -> iNaturalist',
        );
        externalResult = await _fetchINaturalistReports(
          lat: position.latitude,
          lng: position.longitude,
          radiusKm: radiusKm,
          now: now,
        );
      }

      if (!externalResult.succeeded) {
        trace.incrementMetric('fallback_count', 1);
        await ObservabilityService.log(
          'Jellyfish fallback: iNaturalist -> OBIS',
        );
        externalResult = await _fetchObisReports(
          lat: position.latitude,
          lng: position.longitude,
          radiusKm: radiusKm,
          now: now,
          since: since,
        );
      }

      if (!externalResult.succeeded) {
        trace.incrementMetric('fallback_count', 1);
        await ObservabilityService.log(
          'Jellyfish fallback: OBIS -> GBIF',
        );
        externalResult = await _fetchGbifReports(
          lat: position.latitude,
          lng: position.longitude,
          radiusKm: radiusKm,
          now: now,
          since: since,
        );
      }

      if (!externalResult.succeeded) {
        trace.putAttribute('external_status', 'all_unavailable');
        await ObservabilityService.recordNonFatal(
          StateError('All external jellyfish providers are unavailable'),
          StackTrace.current,
          key: 'jellyfish_all_external_sources_unavailable',
          reason: 'jellyfish_all_external_sources_unavailable',
        );
      } else {
        trace.putAttribute('external_status', 'available');
      }

      final externalReports = externalResult.reports;
      trace.setMetric('community_reports', communityReports.length);
      trace.setMetric('external_reports', externalReports.length);

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
        timeWindowHours: timeWindowHours,
        hasAlert: alertReports.isNotEmpty,
        reports: nearbyReports,
        fetchedAt: DateTime.now(),
      );
    } on FirebaseException catch (e, st) {
      await ObservabilityService.recordNonFatal(
        e,
        st,
        key: 'jellyfish_firestore_failure',
        reason: 'jellyfish_firestore_failure',
        context: {'code': e.code},
      );
      return JellyfishData(error: 'Erreur Firestore: ${e.message}');
    } catch (e, st) {
      await ObservabilityService.recordNonFatal(
        e,
        st,
        key: 'jellyfish_fetch_failure',
        reason: 'jellyfish_fetch_failure',
      );
      return JellyfishData(error: 'Erreur: $e');
    } finally {
      await trace.stop();
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

  Future<void> _recordExternalProviderFailure(
    String provider,
    Object error,
    StackTrace stack,
  ) async {
    int? httpStatus;
    String errorType = error.runtimeType.toString();

    if (error is DioException) {
      httpStatus = error.response?.statusCode;
      errorType = error.type.name;
    }

    await ObservabilityService.recordNonFatal(
      error,
      stack,
      key: 'jellyfish_provider_${provider.toLowerCase()}',
      reason: 'jellyfish_provider_unavailable',
      context: {
        'provider': provider,
        'http_status': httpStatus,
        'error_type': errorType,
      },
    );
  }

  Future<_ExternalFetchResult> _fetchAcriReports({
    required double lat,
    required double lng,
    required double radiusKm,
    required DateTime now,
    required DateTime since,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_acriBaseUrl/campaigns/meduse/observations',
        queryParameters: {
          'campaign': 'meduse',
          'filter': "observation_date ge '${_formatIsoUtc(since)}'",
          'count': true,
          'limit': 300,
        },
        options: Options(
          sendTimeout: _externalTimeout,
          receiveTimeout: _externalTimeout,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'SwimTracker/1.1 (ACRI Meduse lookup)',
          },
        ),
      );

      final values = response.data?['value'];
      if (values is! List) return const _ExternalFetchResult.success([]);

      final reports = values
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

      return _ExternalFetchResult.success(reports);
    } catch (e, st) {
      await _recordExternalProviderFailure('ACRI', e, st);
      return const _ExternalFetchResult.failure();
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

  Future<_ExternalFetchResult> _fetchINaturalistReports({
    required double lat,
    required double lng,
    required double radiusKm,
    required DateTime now,
  }) async {
    try {
      final since = now.subtract(
        Duration(hours: _prefsService.jellyfishTimeWindowHours),
      );
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
          sendTimeout: _externalTimeout,
          receiveTimeout: _externalTimeout,
          headers: {
            'User-Agent': 'SwimTracker/1.1 (jellyfish lookup; iNaturalist API)',
          },
        ),
      );

      final results = response.data?['results'];
      if (results is! List) return const _ExternalFetchResult.success([]);

      final reports = results
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

      return _ExternalFetchResult.success(reports);
    } catch (e, st) {
      await _recordExternalProviderFailure('iNaturalist', e, st);
      return const _ExternalFetchResult.failure();
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

  Future<_ExternalFetchResult> _fetchObisReports({
    required double lat,
    required double lng,
    required double radiusKm,
    required DateTime now,
    required DateTime since,
  }) async {
    try {
      // OBIS accepte une géométrie WKT. On utilise une bounding box légère,
      // puis le rayon exact est contrôlé localement avec Haversine.
      final bounds = _boundingBox(lat, lng, radiusKm);
      final polygon = _wktPolygon(bounds);

      final response = await _dio.get<Map<String, dynamic>>(
        '$_obisBaseUrl/occurrence',
        queryParameters: {
          'scientificname': _scyphozoaScientificName,
          'startdate': _formatDate(since),
          'enddate': _formatDate(now),
          'geometry': polygon,
          'limit': 100,
        },
        options: Options(
          sendTimeout: _externalTimeout,
          receiveTimeout: _externalTimeout,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'SwimTracker/1.1 (jellyfish lookup; OBIS API)',
          },
        ),
      );

      final results = response.data?['results'];
      if (results is! List) {
        return const _ExternalFetchResult.success([]);
      }

      final reports = results
          .whereType<Map<String, dynamic>>()
          .map((json) => _reportFromObis(json, now))
          .whereType<JellyfishReport>()
          .where((report) => report.reportedAt.isAfter(since))
          .map((report) => report.copyWithDistance(_haversineKm(
                lat,
                lng,
                report.lat,
                report.lng,
              )))
          .where((report) => (report.distanceKm ?? double.infinity) <= radiusKm)
          .toList();

      return _ExternalFetchResult.success(reports);
    } catch (e, st) {
      await _recordExternalProviderFailure('OBIS', e, st);
      return const _ExternalFetchResult.failure();
    }
  }

  JellyfishReport? _reportFromObis(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final id = json['id'] ?? json['occurrenceID'] ?? json['catalogNumber'];
    final lat = _readDouble(json['decimalLatitude']);
    final lng = _readDouble(json['decimalLongitude']);
    if (id == null || lat == null || lng == null) return null;

    final observedAt = _readDate(json['eventDate']) ??
        _readDate(json['date_mid']) ??
        _readDate(json['date_start']) ??
        now;
    final species = (json['scientificName'] ??
        json['species'] ??
        json['acceptedNameUsage']) as String?;

    return JellyfishReport(
      id: 'obis_$id',
      type: JellyfishReportType.few,
      source: JellyfishReportSource.obis,
      lat: lat,
      lng: lng,
      reportedAt: observedAt,
      expiresAt: observedAt.add(const Duration(days: 7)),
      species: species,
      locationLabel: 'Observation OBIS',
    );
  }

  Future<_ExternalFetchResult> _fetchGbifReports({
    required double lat,
    required double lng,
    required double radiusKm,
    required DateTime now,
    required DateTime since,
  }) async {
    try {
      // Résolution dynamique du taxon : on évite de figer un taxonKey GBIF
      // susceptible d'évoluer avec leurs référentiels taxonomiques.
      final matchResponse = await _dio.get<Map<String, dynamic>>(
        '$_gbifBaseUrl/species/match',
        queryParameters: {'name': _scyphozoaScientificName},
        options: Options(
          sendTimeout: _externalTimeout,
          receiveTimeout: _externalTimeout,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'SwimTracker/1.1 (jellyfish lookup; GBIF API)',
          },
        ),
      );

      final taxonKey = matchResponse.data?['usageKey'] ??
          matchResponse.data?['taxonKey'] ??
          matchResponse.data?['key'];
      if (taxonKey == null) {
        return const _ExternalFetchResult.failure();
      }

      final bounds = _boundingBox(lat, lng, radiusKm);
      final response = await _dio.get<Map<String, dynamic>>(
        '$_gbifBaseUrl/occurrence/search',
        queryParameters: {
          'taxonKey': taxonKey,
          'hasCoordinate': true,
          'occurrenceStatus': 'PRESENT',
          'eventDate':
              '${_formatDate(since)},${_formatDate(now)}',
          'decimalLatitude': '${bounds.south},${bounds.north}',
          'decimalLongitude': '${bounds.west},${bounds.east}',
          'limit': 100,
        },
        options: Options(
          sendTimeout: _externalTimeout,
          receiveTimeout: _externalTimeout,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'SwimTracker/1.1 (jellyfish lookup; GBIF API)',
          },
        ),
      );

      final results = response.data?['results'];
      if (results is! List) {
        return const _ExternalFetchResult.success([]);
      }

      final reports = results
          .whereType<Map<String, dynamic>>()
          .map((json) => _reportFromGbif(json, now))
          .whereType<JellyfishReport>()
          .where((report) => report.reportedAt.isAfter(since))
          .map((report) => report.copyWithDistance(_haversineKm(
                lat,
                lng,
                report.lat,
                report.lng,
              )))
          .where((report) => (report.distanceKm ?? double.infinity) <= radiusKm)
          .toList();

      return _ExternalFetchResult.success(reports);
    } catch (e, st) {
      await _recordExternalProviderFailure('GBIF', e, st);
      return const _ExternalFetchResult.failure();
    }
  }

  JellyfishReport? _reportFromGbif(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final id = json['key'] ?? json['gbifID'] ?? json['occurrenceID'];
    final lat = _readDouble(json['decimalLatitude']);
    final lng = _readDouble(json['decimalLongitude']);
    if (id == null || lat == null || lng == null) return null;

    final observedAt = _readDate(json['eventDate']) ??
        _dateFromParts(json['year'], json['month'], json['day']) ??
        now;
    final species = (json['scientificName'] ??
        json['species'] ??
        json['acceptedScientificName']) as String?;

    return JellyfishReport(
      id: 'gbif_$id',
      type: JellyfishReportType.few,
      source: JellyfishReportSource.gbif,
      lat: lat,
      lng: lng,
      reportedAt: observedAt,
      expiresAt: observedAt.add(const Duration(days: 7)),
      species: species,
      locationLabel: 'Observation GBIF',
    );
  }

  double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  DateTime? _dateFromParts(Object? year, Object? month, Object? day) {
    final y = year is num ? year.toInt() : int.tryParse('$year');
    if (y == null) return null;
    final m = month is num ? month.toInt() : int.tryParse('$month') ?? 1;
    final d = day is num ? day.toInt() : int.tryParse('$day') ?? 1;
    try {
      return DateTime.utc(y, m, d);
    } catch (_) {
      return null;
    }
  }

  _GeoBounds _boundingBox(double lat, double lng, double radiusKm) {
    final latDelta = radiusKm / 111.32;
    final cosLat = math.cos(_toRad(lat)).abs().clamp(0.01, 1.0);
    final lngDelta = radiusKm / (111.32 * cosLat);
    return _GeoBounds(
      south: (lat - latDelta).clamp(-90.0, 90.0),
      north: (lat + latDelta).clamp(-90.0, 90.0),
      west: (lng - lngDelta).clamp(-180.0, 180.0),
      east: (lng + lngDelta).clamp(-180.0, 180.0),
    );
  }

  String _wktPolygon(_GeoBounds b) {
    return 'POLYGON(('
        '${b.west} ${b.south},'
        '${b.east} ${b.south},'
        '${b.east} ${b.north},'
        '${b.west} ${b.north},'
        '${b.west} ${b.south}'
        '))';
  }

  Future<void> submitUserReport(JellyfishReportType type) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Utilisateur non connecté');

    final position = await _locationService.getCurrentPositionOrThrow();

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

class _ExternalFetchResult {
  final bool succeeded;
  final List<JellyfishReport> reports;

  const _ExternalFetchResult.success(this.reports) : succeeded = true;
  const _ExternalFetchResult.failure()
      : succeeded = false,
        reports = const [];
}

class _GeoBounds {
  final double south;
  final double north;
  final double west;
  final double east;

  const _GeoBounds({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
  });
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
