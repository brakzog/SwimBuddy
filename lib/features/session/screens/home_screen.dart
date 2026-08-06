import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/swim_session.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
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
          if (oceanAsync.hasValue || jellyfishAsync.hasValue) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatLastUpdated(
                  oceanAsync.value?.fetchedAt,
                  jellyfishAsync.value?.fetchedAt,
                ),
                style: const TextStyle(
                  fontSize: 10,
                  color: SwimColors.textMuted,
                ),
              ),
            ),
          ],
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

  String _formatLastUpdated(DateTime? oceanAt, DateTime? jellyfishAt) {
    final values = [oceanAt, jellyfishAt].whereType<DateTime>().toList();
    if (values.isEmpty) return 'Actualisation en cours…';
    final latest = values.reduce((a, b) => a.isAfter(b) ? a : b);
    final diff = DateTime.now().difference(latest);
    if (diff.inSeconds < 45) return 'Actualisé à l’instant';
    if (diff.inMinutes < 60) return 'Actualisé il y a ${diff.inMinutes} min';
    return 'Actualisé à ${latest.hour.toString().padLeft(2, '0')}:${latest.minute.toString().padLeft(2, '0')}';
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
            icon: Icons.water_outlined,
            label: 'Mer',
            value: ocean.formattedSeaTemp,
            valueColor: SwimColors.waterBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            icon: Icons.thermostat_outlined,
            label: 'Air',
            value: ocean.formattedAirTemp,
            valueColor: SwimColors.textPrimary,
          ),
        ),
        if (ocean.waveHeight != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _Pill(
              icon: Icons.waves_outlined,
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
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  const _Pill({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: SwimColors.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: SwimColors.textMuted,
                ),
              ),
            ],
          ),
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

enum _ZoneStatus { favorable, vigilance, discouraged }

class _JellyfishCard extends ConsumerStatefulWidget {
  final JellyfishData data;
  const _JellyfishCard({required this.data});

  @override
  ConsumerState<_JellyfishCard> createState() => _JellyfishCardState();
}

class _JellyfishCardState extends ConsumerState<_JellyfishCard> {
  bool _showDetails = false;

  JellyfishData get data => widget.data;

  _ZoneStatus get _status {
    final alertTypes = data.reports
        .where((report) => report.type.isAlert)
        .map((report) => report.type);

    if (alertTypes.any(
      (type) =>
          type == JellyfishReportType.many ||
          type == JellyfishReportType.sting,
    )) {
      return _ZoneStatus.discouraged;
    }
    if (data.hasAlert) return _ZoneStatus.vigilance;
    return _ZoneStatus.favorable;
  }

  JellyfishReport? get _primaryReport {
    final alerts = data.reports.where((report) => report.type.isAlert).toList()
      ..sort((a, b) {
        final severity = _severity(b.type).compareTo(_severity(a.type));
        if (severity != 0) return severity;
        return a.reportedAt.compareTo(b.reportedAt) * -1;
      });
    return alerts.isEmpty ? null : alerts.first;
  }

  int _severity(JellyfishReportType type) => switch (type) {
        JellyfishReportType.sting => 3,
        JellyfishReportType.many => 2,
        JellyfishReportType.few => 1,
        JellyfishReportType.none => 0,
      };

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final primary = _primaryReport;
    final colors = _ZoneStatusColors.from(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(colors.icon, color: colors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      colors.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _decisionMessage(status, primary),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: SwimColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  colors.badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          if (primary != null) ...[
            const SizedBox(height: 16),
            _DecisionFacts(report: primary),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              _favorableDetails(),
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: SwimColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showReportDialog(context),
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Signaler cette zone'),
          ),
          if (data.reports.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _showDetails = !_showDetails),
              icon: Icon(
                _showDetails
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              label: Text(
                _showDetails
                    ? 'Masquer les observations'
                    : 'Voir les observations (${data.reports.length})',
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _showDetails
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const Divider(color: SwimColors.border),
                  const SizedBox(height: 4),
                  ...data.reports.map(_ReportSummary.new),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _decisionMessage(_ZoneStatus status, JellyfishReport? report) {
    return switch (status) {
      _ZoneStatus.favorable =>
        'Aucune observation inquiétante près de votre position.',
      _ZoneStatus.vigilance =>
        'Quelques méduses ont été observées à proximité.',
      _ZoneStatus.discouraged => report?.type == JellyfishReportType.sting
          ? 'Une piqûre a été signalée à proximité. La prudence est recommandée.'
          : 'Une présence importante de méduses a été observée à proximité.',
    };
  }

  String _favorableDetails() {
    final period = _periodLabel(data.timeWindowHours);
    if (data.safeReportCount > 0) {
      return '${data.safeReportCount} observation(s) sans méduse sur $period.';
    }
    return 'Aucune observation de méduse sur $period dans votre rayon.';
  }

  String _periodLabel(int hours) {
    if (hours < 24) return '${hours} h';
    final days = hours ~/ 24;
    return days == 1 ? '24 h' : '$days jours';
  }

  Future<void> _showReportDialog(BuildContext context) async {
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
    } on LocationFailure catch (failure) {
      if (context.mounted) {
        await _showLocationFailure(context, failure.type);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible d’envoyer le signalement. Vérifiez votre connexion puis réessayez.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showLocationFailure(
    BuildContext context,
    LocationFailureType type,
  ) async {
    final locationService = ref.read(locationServiceProvider);

    switch (type) {
      case LocationFailureType.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La localisation est nécessaire pour associer le signalement à votre zone.',
            ),
          ),
        );
        return;
      case LocationFailureType.positionUnavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Position introuvable. Placez-vous à l’extérieur puis réessayez.',
            ),
          ),
        );
        return;
      case LocationFailureType.permissionDeniedForever:
        await _showLocationSettingsDialog(
          context: context,
          title: 'Autorisation de localisation requise',
          message:
              'Autorisez SwimTracker à accéder à votre position dans les réglages du téléphone pour signaler cette zone.',
          actionLabel: 'Ouvrir les réglages',
          onAction: locationService.openAppSettings,
        );
        return;
      case LocationFailureType.serviceDisabled:
        await _showLocationSettingsDialog(
          context: context,
          title: 'Localisation désactivée',
          message:
              'Activez la localisation de votre téléphone pour pouvoir signaler cette zone.',
          actionLabel: 'Activer la localisation',
          onAction: locationService.openLocationSettings,
        );
        return;
    }
  }

  Future<void> _showLocationSettingsDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String actionLabel,
    required Future<bool> Function() onAction,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await onAction();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ZoneStatusColors {
  final Color background;
  final Color border;
  final Color accent;
  final Color titleColor;
  final IconData icon;
  final String title;
  final String badge;

  const _ZoneStatusColors({
    required this.background,
    required this.border,
    required this.accent,
    required this.titleColor,
    required this.icon,
    required this.title,
    required this.badge,
  });

  factory _ZoneStatusColors.from(_ZoneStatus status) => switch (status) {
        _ZoneStatus.favorable => _ZoneStatusColors(
            background: const Color(0xFF041A0E),
            border: SwimColors.wave.withOpacity(0.35),
            accent: SwimColors.wave,
            titleColor: const Color(0xFF9FE1CB),
            icon: Icons.check_circle_outline,
            title: 'Conditions favorables',
            badge: 'OK',
          ),
        _ZoneStatus.vigilance => _ZoneStatusColors(
            background: const Color(0xFF1A1305),
            border: SwimColors.warning.withOpacity(0.45),
            accent: SwimColors.warning,
            titleColor: const Color(0xFFFFD58A),
            icon: Icons.visibility_outlined,
            title: 'Vigilance',
            badge: 'PRUDENCE',
          ),
        _ZoneStatus.discouraged => _ZoneStatusColors(
            background: const Color(0xFF1A0808),
            border: SwimColors.danger.withOpacity(0.45),
            accent: SwimColors.danger,
            titleColor: const Color(0xFFF09595),
            icon: Icons.warning_amber_outlined,
            title: 'Baignade déconseillée',
            badge: 'ALERTE',
          ),
      };
}

class _DecisionFacts extends StatelessWidget {
  final JellyfishReport report;
  const _DecisionFacts({required this.report});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FactChip(
          icon: Icons.water_outlined,
          label: report.type.label,
        ),
        _FactChip(
          icon: Icons.location_on_outlined,
          label: _formatDistance(report.distanceKm),
        ),
        _FactChip(
          icon: Icons.schedule_outlined,
          label: _formatAge(report.reportedAt),
        ),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FactChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SwimColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SwimColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: SwimColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  final JellyfishReport report;
  const _ReportSummary(this.report);

  @override
  Widget build(BuildContext context) {
    final isAlert = report.type.isAlert;
    final source = switch (report.source) {
      JellyfishReportSource.acri => 'ACRI',
      JellyfishReportSource.inaturalist => 'iNaturalist',
      JellyfishReportSource.user => 'SwimTracker',
      JellyfishReportSource.meduseo => 'Meduseo',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAlert ? Icons.water_outlined : Icons.check_circle_outline,
            color: isAlert ? SwimColors.warning : SwimColors.wave,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.type.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SwimColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDistance(report.distanceKm)} · ${_formatAge(report.reportedAt)} · $source',
                  style: const TextStyle(
                    fontSize: 11,
                    color: SwimColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDistance(double? distanceKm) {
  if (distanceKm == null) return 'Distance inconnue';
  if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
  return '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km';
}

String _formatAge(DateTime reportedAt) {
  final difference = DateTime.now().difference(reportedAt);
  if (difference.inMinutes < 5) return 'À l’instant';
  if (difference.inHours < 1) return 'Il y a ${difference.inMinutes} min';
  if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
  if (difference.inHours < 48) return 'Hier';
  return 'Il y a ${difference.inDays} jours';
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

class _JellyfishCardLoading extends StatefulWidget {
  const _JellyfishCardLoading();

  @override
  State<_JellyfishCardLoading> createState() => _JellyfishCardLoadingState();
}

class _JellyfishCardLoadingState extends State<_JellyfishCardLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.35 + (_controller.value * 0.35);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SwimColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SwimColors.border, width: 0.5),
          ),
          child: Opacity(
            opacity: opacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SkeletonBox(width: 52, height: 52, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SkeletonBox(width: 150, height: 18),
                          SizedBox(height: 9),
                          _SkeletonBox(width: double.infinity, height: 12),
                          SizedBox(height: 6),
                          _SkeletonBox(width: 190, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SkeletonBox(width: double.infinity, height: 48, radius: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SwimColors.surfaceLight,
        borderRadius: BorderRadius.circular(radius),
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
