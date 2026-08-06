import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/swim_session.dart';
import '../../../core/services/prefs_service.dart';
import 'session_state.dart';

class SessionNotifier extends Notifier<SessionState> {
  Timer? _timer;

  @override
  SessionState build() {
    ref.onDispose(() => _timer?.cancel());
    final persisted = ref.read(prefsServiceProvider).activeSession;
    final restored = persisted == null
        ? const SessionState()
        : SessionState.fromPersistedJson(persisted);
    if (restored.isRunning) _startTicker();
    return restored;
  }

  Future<void> start({
    double? waterTempCelsius,
    double? airTempCelsius,
    double? waveHeightMeters,
    String? locationLabel,
    double? latitude,
    double? longitude,
    required SwimZoneStatus zoneStatus,
  }) async {
    if (state.isRunning) return;
    final now = DateTime.now();
    state = SessionState(
      status: SessionStatus.running,
      startedAt: now,
      elapsed: Duration.zero,
      waterTempCelsius: waterTempCelsius,
      airTempCelsius: airTempCelsius,
      waveHeightMeters: waveHeightMeters,
      locationLabel: locationLabel,
      latitude: latitude,
      longitude: longitude,
      conditionsCapturedAt: now,
      zoneStatus: zoneStatus,
    );
    await ref.read(prefsServiceProvider).saveActiveSession(
          state.toPersistedJson(),
        );
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = state.startedAt;
      if (startedAt == null || !state.isRunning) return;
      state = state.copyWith(elapsed: DateTime.now().difference(startedAt));
    });
  }

  Future<void> stop() async {
    if (!state.isRunning) return;

    _timer?.cancel();

    final startedAt = state.startedAt;
    if (startedAt == null) {
      await ref.read(prefsServiceProvider).clearActiveSession();
      state = const SessionState();
      return;
    }

    final endedAt = DateTime.now();
    state = state.copyWith(
      status: SessionStatus.finished,
      endedAt: endedAt,
      elapsed: endedAt.difference(startedAt),
    );

    await ref.read(prefsServiceProvider).clearActiveSession();
  }

  Future<void> reset() async {
    _timer?.cancel();
    await ref.read(prefsServiceProvider).clearActiveSession();
    state = const SessionState();
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
