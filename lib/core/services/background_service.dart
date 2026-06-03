import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'location_service.dart';
import 'notification_service.dart';
import '../../features/jellyfish/services/jellyfish_service.dart';

/// Vérifié au lancement et au retour en premier plan.
/// Pas besoin de service natif Android — on utilise AppLifecycleListener.
class BackgroundService {
  final LocationService _locationService;

  BackgroundService(this._locationService);

  Future<void> checkAndNotify() async {
    final service = JellyfishService(Dio(), _locationService);
    final data = await service.fetchNearbyJellyfish();

    if (data.hasAlert &&
        data.nearestKm != null &&
        data.hoursAgo != null) {
      await NotificationService.showJellyfishAlert(
        count: data.reportCount,
        km: data.nearestKm!,
        hoursAgo: data.hoursAgo!,
      );
    }
  }
}

final backgroundServiceProvider = Provider<BackgroundService>((ref) {
  return BackgroundService(ref.read(locationServiceProvider));
});
