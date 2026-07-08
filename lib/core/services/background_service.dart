import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'location_service.dart';
import 'notification_service.dart';
import 'prefs_service.dart';
import '../../features/jellyfish/services/jellyfish_service.dart';

/// Vérifié au lancement et au retour en premier plan.
/// Pas besoin de service natif Android — on utilise AppLifecycleListener.
class BackgroundService {
  final JellyfishService _jellyfishService;

  BackgroundService(this._jellyfishService);

  Future<void> checkAndNotify() async {
    final data = await _jellyfishService.fetchNearbyJellyfish();

    if (data.hasAlert && data.nearestKm != null && data.hoursAgo != null) {
      await NotificationService.showJellyfishAlert(
        count: data.alertReportCount,
        km: data.nearestKm!,
        hoursAgo: data.hoursAgo!,
      );
    }
  }
}

final backgroundServiceProvider = Provider<BackgroundService>((ref) {
  final jellyfishService = JellyfishService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    ref.read(locationServiceProvider),
    ref.read(prefsServiceProvider),
  );
  return BackgroundService(jellyfishService);
});
