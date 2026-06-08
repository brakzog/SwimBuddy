import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/swim_session.dart';

class NativeHealthService {
  static const _channel = MethodChannel('com.jro.swimtracker/health');

  Future<List<SwimSession>> fetchSwimmingWorkouts({int days = 90}) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod(
        'getSwimmingWorkouts',
        days,
      );

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final startedAt = DateTime.fromMillisecondsSinceEpoch(
            (map['startedAt'] as double).toInt());
        final endedAt = DateTime.fromMillisecondsSinceEpoch(
            (map['endedAt'] as double).toInt());

        return SwimSession(
          startedAt: startedAt,
          endedAt: endedAt,
          durationSeconds: map['durationSeconds'] as int,
          distanceMeters: (map['distanceMeters'] as num).toDouble(),
          heartRateAvg: (map['heartRateAvg'] as num?)?.toDouble(),
          heartRateMax: (map['heartRateMax'] as num?)?.toDouble(),
          calories: (map['calories'] as num?)?.toDouble(),
          locationLabel: 'Importé depuis Apple Watch',
        );
      }).toList();
    } on PlatformException catch (e) {
      print('NativeHealthService error: ${e.message}');
      return [];
    }
  }
}

final nativeHealthServiceProvider =
    Provider<NativeHealthService>((ref) => NativeHealthService());