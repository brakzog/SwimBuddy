import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/swim_session.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../health/services/health_service.dart';
import '../../ocean/services/ocean_service.dart';
import '../../jellyfish/models/jellyfish_report.dart';
import '../../jellyfish/services/jellyfish_service.dart';
import '../../../core/services/prefs_service.dart';
import '../providers/session_notifier.dart';
import '../providers/session_state.dart';
import '../../settings/screens/settings_screen.dart';
import 'session_summary_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(session.isRunning ? 'Session en cours' : 'SwimTracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          if (!session.isRunning)
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Actualiser',
              onPressed: () {
                ref.read(oceanProvider.notifier).refresh();
                ref.read(jellyfishProvider.notifier).refresh();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: session.isRunning
            ? _RunningView(session: session)
            : const _IdleView(),
      ),
    );
  }
}

// ─── Vue REPOS ────────────────────────────────────────────────────────────────

class _IdleView extends ConsumerWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oceanAsync = ref.watch(oceanProvider);
    final jellyfishAsync = ref.watch(jellyfishProvider);
    final sessionsAsync = ref.watch(sessionsStreamProvider);

    final lastSession = sessionsAsync.maybeWhen(
      data: (s) => s.isNotEmpty ? s.first : null,
      orElse: () => null,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting
          _GreetingHeader(ocean: oceanAsync.value),
          const SizedBox(height: 16),

          // Pills météo
          oceanAsync.when(
            loading: () => const _WeatherPillsLoading(),
            error: (_, __) => const _WeatherPillsError(),
            data: (ocean) => _WeatherPills(ocean: ocean),
          ),
          const SizedBox(height: 12),

          // Card méduses
          jellyfishAsync.when(
            loading: () => const _JellyfishCardLoading(),
            error: (_, __) => const _JellyfishCardError(),
            data: (jelly) => _JellyfishCard(data: jelly),
          ),
          const SizedBox(height: 12),

          // Dernière session
          if (lastSession != null) ...[
            _LastSessionCard(session: lastSession),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),

          // Bouton démarrer
          ElevatedButton.icon(
            onPressed: () => _startSession(context, ref),
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Démarrer la session'),
          ),
        ],
      ),
    );
  }

  Future<void> _startSession(BuildContext context, WidgetRef ref) async {
    final healthService = ref.read(healthServiceProvider);
    final hasPerms = await healthService.hasPermissions();
    if (!hasPerms) {
      await healthService.requestPermissions();
    }
    ref.read(sessionProvider.notifier).start();
  }
}

// ─── Greeting ────────────────────────────────────────────────────────────────

class _GreetingHeader extends ConsumerWidget {
  final OceanData? ocean;
  const _GreetingHeader({this.ocean});

  String _greeting(String name) {
    final h = DateTime.now().hour;
    final suffix = name.isNotEmpty ? ' $name' : '';
    if (h < 12) return 'Bonjour$suffix';
    if (h < 18) return 'Bon après-midi$suffix';
    return 'Bonsoir$suffix';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(prefsProvider)['name'] as String? ?? '';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(name),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: SwimColors.textPrimary)),
              if (ocean?.locationLabel != null)
                Text(ocean!.locationLabel!,
                    style: const TextStyle(
                        fontSize: 12, color: SwimColors.textSecondary)),
            ],
          ),
        ),
        // Avatar initiales
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: SwimColors.surfaceLight,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: const Text('JR',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: SwimColors.textSecondary)),
        ),
      ],
    );
  }
}

// ─── Pills météo ──────────────────────────────────────────────────────────────

class _WeatherPills extends StatelessWidget {
  final OceanData ocean;
  const _WeatherPills({required this.ocean});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Pill(
            label: 'Mer',
            value: ocean.formattedSeaTemp,
            valueColor: SwimColors.waterBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            label: 'Air',
            value: ocean.formattedAirTemp,
            valueColor: SwimColors.textPrimary,
          ),
        ),
        if (ocean.waveHeight != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _Pill(
              label: 'Vagues',
              value: '${ocean.waveHeight!.toStringAsFixed(1)}m',
              valueColor: SwimColors.wave,
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _Pill(
      {required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: SwimColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SwimColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: valueColor)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: SwimColors.textMuted)),
        ],
      ),
    );
  }
}

class _WeatherPillsLoading extends StatelessWidget {
  const _WeatherPillsLoading();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (_) => Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            height: 62,
            decoration: BoxDecoration(
              color: SwimColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SwimColors.border, width: 0.5),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: SwimColors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherPillsError extends StatelessWidget {
  const _WeatherPillsError();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SwimColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SwimColors.border, width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_off_outlined,
              color: SwimColors.textMuted, size: 16),
          SizedBox(width: 8),
          Text('Position GPS requise pour la météo marine',
              style: TextStyle(
                  color: SwimColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Card méduses ─────────────────────────────────────────────────────────────

class _JellyfishCard extends ConsumerWidget {
  final JellyfishData data;
  const _JellyfishCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAlert = data.hasAlert;
    final bgColor =
        isAlert ? const Color(0xFF1A0808) : const Color(0xFF041A0E);
    final borderColor = isAlert
        ? SwimColors.danger.withOpacity(0.4)
        : SwimColors.wave.withOpacity(0.3);
    final iconColor = isAlert ? SwimColors.danger : SwimColors.wave;
    final titleColor =
        isAlert ? const Color(0xFFF09595) : const Color(0xFF9FE1CB);
    final icon =
        isAlert ? Icons.warning_amber_outlined : Icons.check_circle_outline;
    final title = isAlert
        ? '${data.alertReportCount} signalement(s) alerte'
        : 'Zone OK';
    final periodLabel = _periodLabel(data.timeWindowHours);
    final latestReport = data.reports.isEmpty
        ? null
        : data.reports.reduce((a, b) =>
            a.reportedAt.isAfter(b.reportedAt) ? a : b);
    final subtitle = isAlert && data.nearestKm != null
        ? '${data.alertReportCount} alerte(s) sur $periodLabel · plus proche ${data.nearestKm!.toStringAsFixed(1)} km · ${_ageLabel(data.hoursAgo)}'
        : data.safeReportCount > 0
            ? '${data.safeReportCount} signalement(s) OK sur $periodLabel · dernier ${_ageLabel(_hoursAgo(latestReport))}'
            : data.externalReportCount > 0
                ? '${data.externalReportCount} observation(s) ACRI/iNaturalist sur $periodLabel'
                : 'Aucun signalement sur $periodLabel dans votre rayon';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: titleColor)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: SwimColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(isAlert ? 'Alerte' : 'OK',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: iconColor)),
              ),
            ],
          ),
          if (data.reports.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...data.reports.take(3).map(_ReportSummary.new),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showReportDialog(context, ref),
            icon: const Icon(Icons.add_location_alt_outlined, size: 17),
            label: const Text('Signaler la zone'),
          ),
        ],
      ),
    );
  }

  String _periodLabel(int hours) {
    if (hours < 24) return '${hours}h';
    final days = hours ~/ 24;
    return days == 1 ? '24h' : '$days jours';
  }

  int? _hoursAgo(JellyfishReport? report) {
    if (report == null) return null;
    return DateTime.now().difference(report.reportedAt).inHours;
  }

  String _ageLabel(int? hours) {
    if (hours == null) return 'date inconnue';
    if (hours <= 0) return 'à l’instant';
    if (hours < 24) return 'il y a ${hours}h';
    final days = hours ~/ 24;
    return days == 1 ? 'hier' : 'il y a $days jours';
  }

  Future<void> _showReportDialog(BuildContext context, WidgetRef ref) async {
    final type = await showModalBottomSheet<JellyfishReportType>(
      context: context,
      backgroundColor: SwimColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Que veux-tu signaler ?',
                style: TextStyle(
                  color: SwimColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _ReportTile(
                icon: Icons.check_circle_outline,
                label: JellyfishReportType.none.label,
                type: JellyfishReportType.none,
              ),
              _ReportTile(
                icon: Icons.water_outlined,
                label: JellyfishReportType.few.label,
                type: JellyfishReportType.few,
              ),
              _ReportTile(
                icon: Icons.warning_amber_outlined,
                label: JellyfishReportType.many.label,
                type: JellyfishReportType.many,
              ),
              _ReportTile(
                icon: Icons.personal_injury_outlined,
                label: JellyfishReportType.sting.label,
                type: JellyfishReportType.sting,
              ),
            ],
          ),
        ),
      ),
    );

    if (type == null) return;

    try {
      await ref.read(jellyfishProvider.notifier).submitReport(type);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signalement envoyé, merci !')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signalement impossible: $e')),
        );
      }
    }
  }
}

class _ReportSummary extends StatelessWidget {
  final JellyfishReport report;
  const _ReportSummary(this.report);

  @override
  Widget build(BuildContext context) {
    final isAlert = report.type.isAlert;
    final hours = DateTime.now().difference(report.reportedAt).inHours;
    final age = hours < 24
        ? 'il y a ${hours <= 0 ? 0 : hours}h'
        : 'il y a ${hours ~/ 24}j';
    final distance = report.distanceKm == null
        ? 'distance inconnue'
        : '${report.distanceKm!.toStringAsFixed(1)} km';
    final source = switch (report.source) {
      JellyfishReportSource.acri => 'ACRI',
      JellyfishReportSource.inaturalist => 'iNaturalist',
      JellyfishReportSource.user => 'SwimBuddy',
      JellyfishReportSource.meduseo => 'Meduseo',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isAlert ? Icons.water_outlined : Icons.check_circle_outline,
            color: isAlert ? SwimColors.warning : SwimColors.wave,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${report.type.label} · $distance · $age · $source',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: SwimColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final JellyfishReportType type;

  const _ReportTile({
    required this.icon,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: type == JellyfishReportType.none
            ? SwimColors.wave
            : SwimColors.warning,
      ),
      title: Text(
        label,
        style: const TextStyle(color: SwimColors.textPrimary),
      ),
      onTap: () => Navigator.of(context).pop(type),
    );
  }
}

class _JellyfishCardLoading extends StatelessWidget {
  const _JellyfishCardLoading();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SwimColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SwimColors.border, width: 0.5),
      ),
      child: const Row(
        children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: SwimColors.textMuted)),
          SizedBox(width: 12),
          Text('Vérification méduses en cours…',
              style:
                  TextStyle(fontSize: 12, color: SwimColors.textSecondary)),
        ],
      ),
    );
  }
}

class _JellyfishCardError extends StatelessWidget {
  const _JellyfishCardError();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SwimColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SwimColors.border, width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              color: SwimColors.textMuted, size: 16),
          SizedBox(width: 8),
          Text('Vérification indisponible',
              style:
                  TextStyle(fontSize: 12, color: SwimColors.textMuted)),
        ],
      ),
    );
  }
}

// ─── Dernière session ─────────────────────────────────────────────────────────

class _LastSessionCard extends StatelessWidget {
  final SwimSession session;
  const _LastSessionCard({required this.session});

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inHours < 24) return 'Aujourd\'hui';
    if (diff.inHours < 48) return 'Hier';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SwimColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SwimColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: SwimColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history_outlined,
                    color: SwimColors.textSecondary, size: 15),
              ),
              const SizedBox(width: 8),
              Text('Dernière session · ${_formatDate(session.startedAt)}',
                  style: const TextStyle(
                      fontSize: 12, color: SwimColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(
                value: session.formattedDistance,
                label: 'distance',
                color: SwimColors.wave,
              ),
              const SizedBox(width: 12),
              _StatChip(
                value: session.formattedDuration,
                label: 'durée',
                color: SwimColors.textPrimary,
              ),
              if (session.heartRateAvg != null) ...[
                const SizedBox(width: 12),
                _StatChip(
                  value: '${session.heartRateAvg!.round()} bpm',
                  label: 'FC moy.',
                  color: SwimColors.heartRate,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatChip(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: SwimColors.textMuted)),
      ],
    );
  }
}

// ─── Vue SESSION EN COURS ─────────────────────────────────────────────────────

class _RunningView extends ConsumerWidget {
  final SessionState session;
  const _RunningView({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oceanAsync = ref.watch(oceanProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chrono
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    session.formattedElapsed,
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w500,
                      color: SwimColors.wave,
                      letterSpacing: -4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: SwimColors.wave,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Session en cours',
                          style: TextStyle(
                              color: SwimColors.wave, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Infos live
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SwimColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SwimColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                _LiveStat(
                  icon: Icons.watch_outlined,
                  label: 'Montre',
                  value: 'Synchro',
                  color: SwimColors.wave,
                ),
                _divider(),
                _LiveStat(
                  icon: Icons.water_outlined,
                  label: 'Mer',
                  value: oceanAsync.maybeWhen(
                    data: (o) => o.formattedSeaTemp,
                    orElse: () => '—',
                  ),
                  color: SwimColors.waterBlue,
                ),
                _divider(),
                _LiveStat(
                  icon: Icons.favorite_outline,
                  label: 'FC',
                  value: '—',
                  color: SwimColors.heartRate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwimColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _stopSession(context, ref),
            icon: const Icon(Icons.stop_outlined),
            label: const Text('Terminer la session'),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 0.5,
        height: 40,
        color: SwimColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );

  Future<void> _stopSession(BuildContext context, WidgetRef ref) async {
    ref.read(sessionProvider.notifier).stop();
    final sessionState = ref.read(sessionProvider);
    final healthService = ref.read(healthServiceProvider);
    final oceanData = ref.read(oceanProvider).value;
    final jellyfishData = ref.read(jellyfishProvider).value;

    final healthData = await healthService.fetchSessionData(
      from: sessionState.startedAt!,
      to: sessionState.endedAt!,
    );

    final swimSession = SwimSession(
      startedAt: sessionState.startedAt!,
      endedAt: sessionState.endedAt!,
      durationSeconds: sessionState.elapsed.inSeconds,
      distanceMeters: healthData.distanceMeters ?? 0,
      heartRateAvg: healthData.heartRateAvg,
      heartRateMax: healthData.heartRateMax,
      calories: healthData.calories,
      waterTempCelsius: oceanData?.seaTempCelsius,
      airTempCelsius: oceanData?.airTempCelsius,
      locationLabel: oceanData?.locationLabel,
      jellyfishAlert: jellyfishData?.hasAlert ?? false,
    );

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SessionSummaryScreen(session: swimSession),
        ),
      );
    }
  }
}

class _LiveStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _LiveStat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: SwimColors.textMuted)),
        ],
      ),
    );
  }
}
// Extension greeting avec prénom
extension _GreetingExt on String {
  String get greeting {
    final h = DateTime.now().hour;
    final name = isNotEmpty ? ' $this' : '';
    if (h < 12) return 'Bonjour$name';
    if (h < 18) return 'Bon après-midi$name';
    return 'Bonsoir$name';
  }
}
