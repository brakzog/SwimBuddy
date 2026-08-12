import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/observability_service.dart';

class OceanData {
  final double? seaTempCelsius;
  final double? airTempCelsius;
  final double? waveHeight;
  final String? locationLabel;
  final String? error;
  final DateTime? fetchedAt;
  final double? latitude;
  final double? longitude;

  const OceanData({
    this.seaTempCelsius,
    this.airTempCelsius,
    this.waveHeight,
    this.locationLabel,
    this.error,
    this.fetchedAt,
    this.latitude,
    this.longitude,
  });

  bool get hasData => seaTempCelsius != null;

  String get formattedSeaTemp => seaTempCelsius != null
      ? '${seaTempCelsius!.toStringAsFixed(1)}°C'
      : '—';

  String get formattedAirTemp => airTempCelsius != null
      ? '${airTempCelsius!.toStringAsFixed(1)}°C'
      : '—';
}

class OceanService {
  final Dio _dio;
  final LocationService _locationService;

  OceanService(this._dio, this._locationService);

  Future<OceanData> fetchOceanData() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      return const OceanData(error: 'Position GPS indisponible');
    }
    final lat = position.latitude;
    final lon = position.longitude;

    try {
      final marineResponse = await _dio.get(
        'https://marine-api.open-meteo.com/v1/marine',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': 'sea_surface_temperature,wave_height',
        },
      );

      final weatherResponse = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': 'temperature_2m',
        },
      );

      final marineData = marineResponse.data;
      final weatherData = weatherResponse.data;

      final seaTemp = (marineData['current']?['sea_surface_temperature'] as num?)?.toDouble();
      final waveHeight = (marineData['current']?['wave_height'] as num?)?.toDouble();
      final airTemp = (weatherData['current']?['temperature_2m'] as num?)?.toDouble();

      String? locationLabel;
      try {
        final placemarks = await placemarkFromCoordinates(lat, lon);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = [
            if (place.locality?.isNotEmpty == true) place.locality,
            if (place.thoroughfare?.isNotEmpty == true) place.thoroughfare,
          ];
          locationLabel = parts.isNotEmpty
              ? parts.join(', ')
              : '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
        }
      } catch (_) {
        locationLabel = '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
      }

      return OceanData(
        seaTempCelsius: seaTemp,
        airTempCelsius: airTemp,
        waveHeight: waveHeight,
        locationLabel: locationLabel,
        fetchedAt: DateTime.now(),
        latitude: lat,
        longitude: lon,
      );
    } on DioException catch (e, st) {
  final sanitizedError = Exception(
    'Ocean API failure: '
    'status=${e.response?.statusCode ?? 'unknown'}, '
    'type=${e.type.name}',
  );

  await ObservabilityService.recordNonFatal(
    sanitizedError,
    st,
    key: 'ocean_api_failure',
    reason: 'ocean_api_failure',
    context: {
      'http_status': e.response?.statusCode,
      'error_type': e.type.name,
    },
  );

  return OceanData(error: 'Erreur réseau: ${e.message}');
}
      return OceanData(error: 'Erreur réseau: ${e.message}');
    } catch (e, st) {
      await ObservabilityService.recordNonFatal(
        e,
        st,
        key: 'ocean_fetch_failure',
        reason: 'ocean_fetch_failure',
      );
      return OceanData(error: 'Erreur: $e');
    }
  }
} // ← accolade fermante de OceanService

// Providers — EN DEHORS de la classe
final oceanServiceProvider = Provider<OceanService>((ref) {
  return OceanService(
    Dio(),
    ref.read(locationServiceProvider),
  );
});

class OceanNotifier extends AsyncNotifier<OceanData> {
  @override
  Future<OceanData> build() => _fetch();

  Future<OceanData> _fetch() =>
      ref.read(oceanServiceProvider).fetchOceanData();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final oceanProvider =
    AsyncNotifierProvider<OceanNotifier, OceanData>(OceanNotifier.new);