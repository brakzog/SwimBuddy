import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/swim_session.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/session_notifier.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  final SwimSession session;
  final bool readOnly;

  const SessionSummaryScreen({
    super.key,
    required this.session,
    this.readOnly = false,
  });

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).saveSession(widget.session);
      setState(() {
        _saving = false;
        _saved = true;
      });
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        ref.read(sessionProvider.notifier).reset();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la sauvegarde')),
        );
      }
    }
  }

  void _discard() {
    ref.read(sessionProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? 'Détail de la session' : 'Résumé de session'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SessionHeader(session: s),
              const SizedBox(height: 18),
              const _SectionTitle('Résumé'),
              const SizedBox(height: 10),
              _MetricGrid(session: s),
              const SizedBox(height: 18),
              const _SectionTitle('Conditions'),
              const SizedBox(height: 10),
              _ConditionsCard(session: s),
              const SizedBox(height: 18),
              const _SectionTitle('Santé'),
              const SizedBox(height: 10),
              _HealthCard(session: s),
              if (!widget.readOnly) ...[
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _saving || _saved ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : _saved
                          ? const Icon(Icons.check)
                          : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving
                        ? 'Sauvegarde…'
                        : _saved
                            ? 'Sauvegardé !'
                            : 'Sauvegarder',
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _saving ? null : _discard,
                  child: const Text(
                    'Ignorer cette session',
                    style: TextStyle(color: SwimColors.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  final SwimSession session;
  const _SessionHeader({required this.session});

  @override
  Widget build(BuildContext context) {
    final d = session.startedAt;
    final date = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    final time = '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$date à $time',
          style: const TextStyle(
            color: SwimColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (session.locationLabel != null && session.locationLabel!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: SwimColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  session.locationLabel!,
                  style: const TextStyle(
                    color: SwimColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: SwimColors.textMuted,
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w500,
        ),
      );
}

class _MetricGrid extends StatelessWidget {
  final SwimSession session;
  const _MetricGrid({required this.session});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.timer_outlined,
            label: 'Durée',
            value: session.formattedDuration,
            color: SwimColors.wave,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.straighten_outlined,
            label: 'Distance',
            value: session.formattedDistance,
            color: SwimColors.waterBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.local_fire_department_outlined,
            label: 'Calories',
            value: session.calories != null
                ? '${session.calories!.round()} kcal'
                : '—',
            color: SwimColors.calories,
          ),
        ),
      ],
    );
  }
}

class _ConditionsCard extends StatelessWidget {
  final SwimSession session;
  const _ConditionsCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final hasWater = session.waterTempCelsius != null;
    final hasAir = session.airTempCelsius != null;
    final statusColor = session.jellyfishAlert
        ? SwimColors.warning
        : SwimColors.wave;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SwimColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SwimColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          _ConditionRow(
            icon: Icons.water_outlined,
            label: 'Température de l’eau',
            value: hasWater
                ? '${session.waterTempCelsius!.toStringAsFixed(1)}°C'
                : 'Non disponible',
            subtitle: session.effectiveWaterTemperatureSource?.label,
            color: SwimColors.waterBlue,
          ),
          const Divider(color: SwimColors.border, height: 24),
          _ConditionRow(
            icon: Icons.thermostat_outlined,
            label: 'Température de l’air',
            value: hasAir
                ? '${session.airTempCelsius!.toStringAsFixed(1)}°C'
                : 'Non disponible',
            color: SwimColors.textPrimary,
          ),
          const Divider(color: SwimColors.border, height: 24),
          _ConditionRow(
            icon: session.jellyfishAlert
                ? Icons.warning_amber_outlined
                : Icons.check_circle_outline,
            label: 'État de la zone',
            value: session.jellyfishAlert
                ? 'Vigilance méduses'
                : 'Conditions favorables',
            subtitle: session.jellyfishAlert
                ? 'Des méduses étaient signalées au moment de la séance.'
                : 'Aucune alerte méduse enregistrée au début de la séance.',
            color: statusColor,
          ),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final SwimSession session;
  const _HealthCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.favorite_outline,
            label: 'FC moyenne',
            value: session.heartRateAvg != null
                ? '${session.heartRateAvg!.round()} bpm'
                : '—',
            color: SwimColors.heartRate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.monitor_heart_outlined,
            label: 'FC max',
            value: session.heartRateMax != null
                ? '${session.heartRateMax!.round()} bpm'
                : '—',
            color: SwimColors.heartRate,
          ),
        ),
      ],
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  const _ConditionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: SwimColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: SwimColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

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
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: SwimColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
