import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/location_service.dart';

class OceanData {
  final double? seaTempCelsius;
  final double? airTempCelsius;
  final double? waveHeight;
  final String? locationLabel;
  final String? error;

  const OceanData({
    this.seaTempCelsius,
    this.airTempCelsius,
    this.waveHeight,
    this.locationLabel,
    this.error,
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
    // 1. Récupère la position GPS
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      return const OceanData(error: 'Position GPS indisponible');
    }

    final lat = position.latitude;
    final lon = position.longitude;

    try {
      // 2. Appel Open-Meteo Marine API (gratuit, pas de clé requise)
      final marineResponse = await _dio.get(
        'https://marine-api.open-meteo.com/v1/marine',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current': 'sea_surface_temperature,wave_height',
        },
      );

      // 3. Appel Open-Meteo Weather pour la température air
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

      final seaTemp = (marineData['current']?['sea_surface_temperature']
          as num?)
          ?.toDouble();
      final waveHeight =
          (marineData['current']?['wave_height'] as num?)?.toDouble();
      final airTemp =
          (weatherData['current']?['temperature_2m'] as num?)?.toDouble();

      return OceanData(
        seaTempCelsius: seaTemp,
        airTempCelsius: airTemp,
        waveHeight: waveHeight,
        locationLabel:
            '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}',
      );
    } on DioException catch (e) {
      return OceanData(
          error: 'Erreur réseau: ${e.message}');
    } catch (e) {
      return OceanData(error: 'Erreur: $e');
    }
  }
}

// Providers
final oceanServiceProvider = Provider<OceanService>((ref) {
  return OceanService(
    Dio(),
    ref.read(locationServiceProvider),
  );
});

// AsyncNotifier qui charge les données au démarrage
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
