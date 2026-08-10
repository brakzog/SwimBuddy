import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Point central de remontée des erreurs de production.
///
/// Ne jamais ajouter ici de coordonnées GPS, e-mail, nom ou autre donnée
/// personnelle. Les informations envoyées doivent rester purement techniques.
class ObservabilityService {
  ObservabilityService._();

  static final Map<String, DateTime> _lastNonFatalReport = {};

  /// Active la remontée des erreurs Flutter et des erreurs asynchrones non
  /// interceptées vers Firebase Crashlytics.
  static void installGlobalCrashHandlers() {
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: true,
        reason: 'uncaught_async_error',
      );
      return true;
    };
  }

  /// Ajoute un breadcrumb technique qui sera joint à un prochain rapport.
  static Future<void> log(String message) {
    return FirebaseCrashlytics.instance.log(message);
  }

  /// Enregistre une erreur non fatale, avec limitation pour éviter de saturer
  /// Crashlytics lorsqu'un service externe reste indisponible.
  static Future<void> recordNonFatal(
    Object error,
    StackTrace stack, {
    required String key,
    required String reason,
    Map<String, Object?> context = const {},
    Duration throttle = const Duration(minutes: 30),
  }) async {
    final now = DateTime.now();
    final previous = _lastNonFatalReport[key];

    if (previous != null && now.difference(previous) < throttle) {
      return;
    }
    _lastNonFatalReport[key] = now;

    final information = <Object>[
      for (final entry in context.entries)
        if (entry.value != null) '${entry.key}=${entry.value}',
    ];

    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      information: information,
      fatal: false,
    );
  }
}
