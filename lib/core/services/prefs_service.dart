import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _keyName = 'user_name';
  static const _keyUnits = 'units_miles';
  static const _keyJellyRadius = 'jellyfish_radius_km';
  static const _keyJellyfishTimeWindowHours = 'jellyfish_time_window_hours';
  static const _keyNotifs = 'notifications_enabled';
  static const _keyActiveSession = 'active_swim_session';

  final SharedPreferences _prefs;
  PrefsService(this._prefs);

  // Nom
  String get userName => _prefs.getString(_keyName) ?? '';
  Future<void> setUserName(String v) => _prefs.setString(_keyName, v);

  // Unités
  bool get useMiles => _prefs.getBool(_keyUnits) ?? false;
  Future<void> setUseMiles(bool v) => _prefs.setBool(_keyUnits, v);

  // Seuil méduses (défaut 10 km)
  double get jellyfishRadiusKm => _prefs.getDouble(_keyJellyRadius) ?? 10.0;
  Future<void> setJellyfishRadiusKm(double v) =>
      _prefs.setDouble(_keyJellyRadius, v);

  // Fenêtre temporelle méduses (défaut 72 h)
  int get jellyfishTimeWindowHours =>
      _prefs.getInt(_keyJellyfishTimeWindowHours) ?? 72;
  Future<void> setJellyfishTimeWindowHours(int v) =>
      _prefs.setInt(_keyJellyfishTimeWindowHours, v);


  Map<String, dynamic>? get activeSession {
    final raw = _prefs.getString(_keyActiveSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveActiveSession(Map<String, dynamic> value) =>
      _prefs.setString(_keyActiveSession, jsonEncode(value));

  Future<void> clearActiveSession() => _prefs.remove(_keyActiveSession);

  // Notifications
  bool get notificationsEnabled => _prefs.getBool(_keyNotifs) ?? true;
  Future<void> setNotificationsEnabled(bool v) =>
      _prefs.setBool(_keyNotifs, v);
}

// Provider initialisé au démarrage
final prefsServiceProvider = Provider<PrefsService>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

// Providers réactifs pour chaque préférence
class PrefsNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
    final prefs = ref.read(prefsServiceProvider);
    return {
      'name': prefs.userName,
      'useMiles': prefs.useMiles,
      'jellyfishRadius': prefs.jellyfishRadiusKm,
      'jellyfishTimeWindowHours': prefs.jellyfishTimeWindowHours,
      'notifs': prefs.notificationsEnabled,
    };
  }

  Future<void> setName(String v) async {
    await ref.read(prefsServiceProvider).setUserName(v);
    state = {...state, 'name': v};
  }

  Future<void> setUseMiles(bool v) async {
    await ref.read(prefsServiceProvider).setUseMiles(v);
    state = {...state, 'useMiles': v};
  }

  Future<void> setJellyfishRadius(double v) async {
    await ref.read(prefsServiceProvider).setJellyfishRadiusKm(v);
    state = {...state, 'jellyfishRadius': v};
  }

  Future<void> setJellyfishTimeWindowHours(int v) async {
    await ref.read(prefsServiceProvider).setJellyfishTimeWindowHours(v);
    state = {...state, 'jellyfishTimeWindowHours': v};
  }

  Future<void> setNotifs(bool v) async {
    await ref.read(prefsServiceProvider).setNotificationsEnabled(v);
    state = {...state, 'notifs': v};
  }
}

final prefsProvider =
    NotifierProvider<PrefsNotifier, Map<String, dynamic>>(PrefsNotifier.new);
