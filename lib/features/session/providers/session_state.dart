import 'package:flutter/foundation.dart';

enum SessionStatus { idle, running, finished }

@immutable
class SessionState {
  final SessionStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final Duration elapsed;

  const SessionState({
    this.status = SessionStatus.idle,
    this.startedAt,
    this.endedAt,
    this.elapsed = Duration.zero,
  });

  bool get isRunning => status == SessionStatus.running;
  bool get isFinished => status == SessionStatus.finished;
  bool get isIdle => status == SessionStatus.idle;

  String get formattedElapsed {
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  SessionState copyWith({
    SessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? elapsed,
  }) =>
      SessionState(
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        elapsed: elapsed ?? this.elapsed,
      );
}
