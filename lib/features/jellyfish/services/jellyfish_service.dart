import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/prefs_service.dart';
import '../models/jellyfish_report.dart';

class JellyfishData {
  final int reportCount;
  final int safeReportCount;
  final int alertReportCount;
  final double? nearestKm;
  final int? hoursAgo;
  final bool hasAlert;
  final String? error;
  final List<JellyfishReport> reports;

  const JellyfishData({
    this.reportCount = 0,
    this.safeReportCount = 0,
    this.alertReportCount = 0,
    this.nearestKm,
    this.hoursAgo,
    this.hasAlert = false,
    this.error,
    this.reports = const [],
  });
}

class JellyfishService {
  static const _collection = 'jellyfish_reports';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LocationService _locationService;
  final PrefsService _prefsService;

  JellyfishService(
    this._firestore,
    this._auth,
    this._locationService,
    this._prefsService,
  );

  Future<JellyfishData> fetchNearbyJellyfish() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      return const JellyfishData(error: 'Position GPS indisponible');
    }

    try {
      final radiusKm = _prefsService.jellyfishRadiusKm;
      final now = DateTime.now();
      final since = now.subtract(const Duration(hours: 48));

      // Une seule clause Firestore volontairement : pas besoin d'index composite
      // pour la V1, on filtre ensuite localement sur reportedAt et la distance.
      final snapshot = await _firestore
          .collection(_collection)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiresAt')
          .limit(300)
          .get();

      final nearbyReports = snapshot.docs
          .map(JellyfishReport.fromDoc)
          .where((report) => report.reportedAt.isAfter(since))
          .map((report) => report.copyWithDistance(_haversineKm(
                position.latitude,
                position.longitude,
                report.lat,
                report.lng,
              )))
          .where((report) => (report.distanceKm ?? double.infinity) <= radiusKm)
          .toList()
        ..sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));

      final alertReports = nearbyReports.where((r) => r.type.isAlert).toList();
      final safeReports = nearbyReports.where((r) => !r.type.isAlert).toList();
      final nearestAlert = alertReports.isEmpty ? null : alertReports.first;

      return JellyfishData(
        reportCount: nearbyReports.length,
        safeReportCount: safeReports.length,
        alertReportCount: alertReports.length,
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
