import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/location_service.dart';

class JellyfishData {
  final int reportCount;
  final double? nearestKm;
  final int? hoursAgo;
  final bool hasAlert;
  final String? error;

  const JellyfishData({
    this.reportCount = 0,
    this.nearestKm,
    this.hoursAgo,
    this.hasAlert = false,
    this.error,
  });
}

class JellyfishService {
  final Dio _dio;
  final LocationService _locationService;

  JellyfishService(this._dio, this._locationService);

  Future<JellyfishData> fetchNearbyJellyfish() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      return const JellyfishData(error: 'Position GPS indisponible');
    }

    try {
      // iNaturalist API — observations de méduses dans un rayon de 50km
      // Taxon IDs pour les méduses communes (Medusozoa)
      final response = await _dio.get(
        'https://api.inaturalist.org/v1/observations',
        queryParameters: {
          'taxon_id': '51508', // Medusozoa
          'lat': position.latitude,
          'lng': position.longitude,
          'radius': 50, // km
          'd1': _daysAgo(2), // dernières 48h
          'order': 'created_at',
          'order_by': 'desc',
          'per_page': 10,
          'quality_grade': 'needs_id,research',
        },
      );

      final results = response.data['results'] as List? ?? [];
      if (results.isEmpty) return const JellyfishData();

      // Calcule la distance au signalement le plus proche
      final now = DateTime.now();
      double? nearestKm;
      int? hoursAgo;

      for (final obs in results) {
        final coords = obs['location']?.split(',');
        if (coords != null && coords.length == 2) {
          final obsLat = double.tryParse(coords[0]);
          final obsLon = double.tryParse(coords[1]);
          if (obsLat != null && obsLon != null) {
            final dist = _haversineKm(
              position.latitude, position.longitude,
              obsLat, obsLon,
            );
            if (nearestKm == null || dist < nearestKm) {
              nearestKm = dist;
              final createdAt = DateTime.tryParse(
                  obs['created_at'] ?? '');
              if (createdAt != null) {
                hoursAgo = now.difference(createdAt).inHours;
              }
            }
          }
        }
      }

      return JellyfishData(
        reportCount: results.length,
        nearestKm: nearestKm,
        hoursAgo: hoursAgo,
        hasAlert: results.isNotEmpty && (nearestKm ?? 999) < 10,
      );
    } on DioException catch (e) {
      return JellyfishData(error: 'Erreur réseau: ${e.message}');
    } catch (e) {
      return JellyfishData(error: 'Erreur: $e');
    }
  }

  // Distance haversine entre deux points GPS (en km)
  double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = _sin2(dLat / 2) +
        _cos(_toRad(lat1)) * _cos(_toRad(lat2)) * _sin2(dLon / 2);
    return r * 2 * _asin(_sqrt(a));
  }

  double _toRad(double d) => d * 3.141592653589793 / 180;
  double _sin2(double x) => _sin(x) * _sin(x);
  double _sin(double x) => x - x * x * x / 6;
  double _cos(double x) => 1 - x * x / 2;
  double _asin(double x) => x + x * x * x / 6;
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 10; i++) r = (r + x / r) / 2;
    return r;
  }

  String _daysAgo(int days) {
    final d = DateTime.now().subtract(Duration(days: days));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

final jellyfishServiceProvider = Provider<JellyfishService>((ref) {
  return JellyfishService(Dio(), ref.read(locationServiceProvider));
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
}

final jellyfishProvider =
    AsyncNotifierProvider<JellyfishNotifier, JellyfishData>(
        JellyfishNotifier.new);
