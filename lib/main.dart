import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_service.dart';
import 'core/services/prefs_service.dart';
import 'core/services/observability_service.dart';
import 'firebase_options.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/app_shell.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  ObservabilityService.installGlobalCrashHandlers();

  await NotificationService.initialize();
  await NotificationService.requestPermission();

  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        prefsServiceProvider.overrideWithValue(PrefsService(sharedPrefs)),
      ],
      child: const SwimTrackerApp(),
    ),
  );
}

class SwimTrackerApp extends ConsumerStatefulWidget {
  const SwimTrackerApp({super.key});

  @override
  ConsumerState<SwimTrackerApp> createState() => _SwimTrackerAppState();
}

class _SwimTrackerAppState extends ConsumerState<SwimTrackerApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkJellyfish();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkJellyfish();
  }

  Future<void> _checkJellyfish() async {
    final notifsEnabled = ref.read(prefsProvider)['notifs'] as bool? ?? true;
    if (!notifsEnabled) return;
    await ref.read(backgroundServiceProvider).checkAndNotify();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwimTracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fr')],
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Firebase error: $e'))),
      data: (user) {
        if (user == null) return const LoginScreen();
        return const AppShell();
      },
    );
  }
}
