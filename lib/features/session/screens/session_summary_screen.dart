import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/swim_session.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/session_notifier.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  final SwimSession session;

  const SessionSummaryScreen({super.key, required this.session});

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
      final service = ref.read(firestoreServiceProvider);
      await service.saveSession(widget.session);
      setState(() {
        _saving = false;
        _saved = true;
      });
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        ref.read(sessionProvider.notifier).reset();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
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
      appBar: AppBar(title: const Text('Résumé de session')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Métriques principales
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.timer_outlined,
                      label: 'Durée',
                      value: s.formattedDuration,
                      color: SwimColors.wave,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.straighten_outlined,
                      label: 'Distance',
                      value: s.formattedDistance,
                      color: SwimColors.waterBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.favorite_outline,
                      label: 'FC moyenne',
                      value: s.heartRateAvg != null
                          ? '${s.heartRateAvg!.round()} bpm'
                          : '—',
                      color: SwimColors.heartRate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Calories',
                      value: s.calories != null
                          ? '${s.calories!.round()} kcal'
                          : '—',
                      color: SwimColors.calories,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.monitor_heart_outlined,
                      label: 'FC max',
                      value: s.heartRateMax != null
                          ? '${s.heartRateMax!.round()} bpm'
                          : '—',
                      color: SwimColors.heartRate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.thermostat_outlined,
                      label: 'Temp. eau',
                      value: s.waterTempCelsius != null
                          ? '${s.waterTempCelsius!.toStringAsFixed(1)}°C'
                          : '—',
                      color: SwimColors.waterBlue,
                    ),
                  ),
                ],
              ),

              if (s.jellyfishAlert) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SwimColors.dangerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: SwimColors.danger.withOpacity(0.4),
                        width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_outlined,
                          color: SwimColors.danger, size: 18),
                      const SizedBox(width: 8),
                      const Text('Méduses signalées pendant cette session',
                          style: TextStyle(
                              color: SwimColors.danger, fontSize: 13)),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Boutons
              ElevatedButton.icon(
                onPressed: _saving || _saved ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : _saved
                        ? const Icon(Icons.check)
                        : const Icon(Icons.save_outlined),
                label: Text(_saving
                    ? 'Sauvegarde…'
                    : _saved
                        ? 'Sauvegardé !'
                        : 'Sauvegarder'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _saving ? null : _discard,
                child: const Text('Ignorer cette session',
                    style: TextStyle(color: SwimColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
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
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: color,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: SwimColors.textMuted)),
        ],
      ),
    );
  }
}
