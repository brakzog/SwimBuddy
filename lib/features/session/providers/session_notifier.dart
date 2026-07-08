import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_state.dart';

class SessionNotifier extends Notifier<SessionState> {
  Timer? _timer;

  @override
  SessionState build() => const SessionState();

  void start() {
    final now = DateTime.now();
    state = SessionState(
      status: SessionStatus.running,
      startedAt: now,
      elapsed: Duration.zero,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        elapsed: DateTime.now().difference(state.startedAt!),
      );
    });
  }

  void stop() {
    _timer?.cancel();
    state = state.copyWith(
      status: SessionStatus.finished,
      endedAt: DateTime.now(),
    );
  }

  void reset() {
    _timer?.cancel();
    state = const SessionState();
  }

  @override
  bool updateShouldNotify(SessionState previous, SessionState next) => true;
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
