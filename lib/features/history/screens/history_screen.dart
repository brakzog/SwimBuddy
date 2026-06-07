import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/swim_session.dart';
import '../../../core/services/firestore_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../health/services/health_service.dart';

// ─── Filtre période ───────────────────────────────────────────────────────────

enum PeriodFilter { week, month, threeMonths, all }

extension PeriodFilterLabel on PeriodFilter {
  String get label {
    switch (this) {
      case PeriodFilter.week: return '7 jours';
      case PeriodFilter.month: return 'Ce mois';
      case PeriodFilter.threeMonths: return '3 mois';
      case PeriodFilter.all: return 'Tout';
    }
  }

  DateTime? get since {
    final now = DateTime.now();
    switch (this) {
      case PeriodFilter.week: return now.subtract(const Duration(days: 7));
      case PeriodFilter.month: return DateTime(now.year, now.month, 1);
      case PeriodFilter.threeMonths: return now.subtract(const Duration(days: 90));
      case PeriodFilter.all: return null;
    }
  }
}

class _PeriodNotifier extends Notifier<PeriodFilter> {
  @override
  PeriodFilter build() => PeriodFilter.month;
  void set(PeriodFilter f) => state = f;
}
final periodFilterProvider = NotifierProvider<_PeriodNotifier, PeriodFilter>(_PeriodNotifier.new);

// ─── Sessions filtrées ────────────────────────────────────────────────────────

final filteredSessionsProvider = Provider<List<SwimSession>>((ref) {
  final all = ref.watch(sessionsStreamProvider).value ?? [];
  final filter = ref.watch(periodFilterProvider);
  final since = filter.since;
  if (since == null) return all;
  return all.where((s) => s.startedAt.isAfter(since)).toList();
});

// ─── Stats agrégées ───────────────────────────────────────────────────────────

class _AggStats {
  final double totalKm;
  final int sessionCount;
  final double totalCalories;
  final Duration totalDuration;
  final double? maxDistance;
  final double? maxHeartRate;
  final double? maxCalories;

  const _AggStats({
    required this.totalKm,
    required this.sessionCount,
    required this.totalCalories,
    required this.totalDuration,
    this.maxDistance,
    this.maxHeartRate,
    this.maxCalories,
  });

  factory _AggStats.from(List<SwimSession> sessions) {
    if (sessions.isEmpty) {
      return const _AggStats(
        totalKm: 0, sessionCount: 0,
        totalCalories: 0, totalDuration: Duration.zero,
      );
    }
    final totalM = sessions.fold(0.0, (s, e) => s + e.distanceMeters);
    final totalCal = sessions.fold(0.0, (s, e) => s + (e.calories ?? 0));
    final totalSec = sessions.fold(0, (s, e) => s + e.durationSeconds);
    final maxDist = sessions.map((s) => s.distanceMeters).reduce((a, b) => a > b ? a : b);
    final hrSessions = sessions.where((s) => s.heartRateMax != null).toList();
    final maxHr = hrSessions.isNotEmpty
        ? hrSessions.map((s) => s.heartRateMax!).reduce((a, b) => a > b ? a : b)
        : null;
    final calSessions = sessions.where((s) => s.calories != null).toList();
    final maxCal = calSessions.isNotEmpty
        ? calSessions.map((s) => s.calories!).reduce((a, b) => a > b ? a : b)
        : null;

    return _AggStats(
      totalKm: totalM / 1000,
      sessionCount: sessions.length,
      totalCalories: totalCal,
      totalDuration: Duration(seconds: totalSec),
      maxDistance: maxDist / 1000,
      maxHeartRate: maxHr,
      maxCalories: maxCal,
    );
  }

  String get formattedDuration {
    final h = totalDuration.inHours;
    final m = totalDuration.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }
}

// ─── Écran principal ──────────────────────────────────────────────────────────

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final filtered = ref.watch(filteredSessionsProvider);
    final stats = _AggStats.from(filtered);
    final filter = ref.watch(periodFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Importer depuis Apple Watch',
            onPressed: () => _showImportDialog(context, ref),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Une erreur est survenue.')),
        data: (_) => filtered.isEmpty && sessionsAsync.value!.isEmpty
            ? const _EmptyState()
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Filtres
                          _PeriodFilterRow(current: filter),
                          const SizedBox(height: 14),

                          // Stats globales
                          if (filtered.isNotEmpty) ...[
                            _StatsGrid(stats: stats),
                            const SizedBox(height: 14),

                            // Graphique
                            _DistanceChart(sessions: filtered),
                            const SizedBox(height: 14),

                            // Records
                            _RecordsRow(stats: stats),
                            const SizedBox(height: 16),
                          ],

                          // Titre liste
                          Text(
                            filtered.isEmpty
                                ? 'Aucune session sur cette période'
                                : 'Sessions (${filtered.length})',
                            style: const TextStyle(
                                fontSize: 12,
                                color: SwimColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // Liste des sessions
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SessionItem(session: filtered[i]),
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwimColors.surface,
        title: const Text('Importer depuis Apple Watch',
            style: TextStyle(color: SwimColors.textPrimary)),
        content: const Text(
          'Importer vos nages des 30 derniers jours depuis HealthKit ?',
          style: TextStyle(color: SwimColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: SwimColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Affiche un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final healthService = ref.read(healthServiceProvider);
      final firestoreService = ref.read(firestoreServiceProvider);

      final workouts = await healthService.fetchSwimmingWorkouts(days: 90);

// Debug temporaire — à supprimer après
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workouts trouvés: ${workouts.length}')),
        );
        await Future.delayed(const Duration(seconds: 2));
      }

      // Récupère les sessions existantes pour éviter les doublons
      final existing = await firestoreService.fetchRecentSessions(limit: 100);
      final existingDates = existing.map((s) => s.startedAt.toIso8601String()).toSet();

      int imported = 0;
      for (final workout in workouts) {
        if (!existingDates.contains(workout.startedAt.toIso8601String())) {
          await firestoreService.saveSession(workout);
          imported++;
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // ferme le loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imported > 0
                ? '$imported session(s) importée(s) !'
                : 'Aucune nouvelle session à importer.'),
            backgroundColor: SwimColors.wave,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'import'),
            backgroundColor: SwimColors.danger,
          ),
        );
      }
    }
  }
}

// ─── Filtres période ──────────────────────────────────────────────────────────

class _PeriodFilterRow extends ConsumerWidget {
  final PeriodFilter current;
  const _PeriodFilterRow({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: PeriodFilter.values.map((f) {
        final isActive = f == current;
        return Expanded(
          child: GestureDetector(
            onTap: () => ref.read(periodFilterProvider.notifier).set(f),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? SwimColors.surfaceLight : SwimColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? SwimColors.waterBlue.withOpacity(0.6)
                      : SwimColors.border,
                  width: 0.5,
                ),
              ),
              child: Text(
                f.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? SwimColors.waterBlue
                      : SwimColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Stats globales ───────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final _AggStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        _StatCard(
          value: '${stats.totalKm.toStringAsFixed(1)} km',
          label: 'Distance totale',
          color: SwimColors.wave,
        ),
        _StatCard(
          value: '${stats.sessionCount}',
          label: 'Sessions',
          color: SwimColors.textPrimary,
        ),
        _StatCard(
          value: '${stats.totalCalories.round()} kcal',
          label: 'Calories',
          color: SwimColors.calories,
        ),
        _StatCard(
          value: stats.formattedDuration,
          label: 'Temps total',
          color: SwimColors.waterBlue,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SwimColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SwimColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: SwimColors.textMuted)),
        ],
      ),
    );
  }
}

// ─── Graphique barres ─────────────────────────────────────────────────────────

class _DistanceChart extends StatelessWidget {
  final List<SwimSession> sessions;
  const _DistanceChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();

    // Prend les 10 dernières sessions max
    final displayed = sessions.take(10).toList().reversed.toList();
    final maxDist = displayed
        .map((s) => s.distanceMeters)
        .reduce((a, b) => a > b ? a : b);

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
          const Text('Distance par session',
              style: TextStyle(fontSize: 11, color: SwimColors.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: displayed.map((s) {
                final ratio = maxDist > 0 ? s.distanceMeters / maxDist : 0.0;
                final isLast = s == displayed.last;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: ratio.clamp(0.05, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isLast
                                    ? SwimColors.wave
                                    : SwimColors.surfaceLight,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s.startedAt.day}/${s.startedAt.month}',
                          style: const TextStyle(
                              fontSize: 8, color: SwimColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Records perso ────────────────────────────────────────────────────────────

class _RecordsRow extends StatelessWidget {
  final _AggStats stats;
  const _RecordsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Records personnels',
            style: TextStyle(fontSize: 12, color: SwimColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RecordCard(
                value: stats.maxDistance != null
                    ? '${stats.maxDistance!.toStringAsFixed(1)} km'
                    : '—',
                label: 'Distance max',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RecordCard(
                value: stats.maxHeartRate != null
                    ? '${stats.maxHeartRate!.round()} bpm'
                    : '—',
                label: 'FC max',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RecordCard(
                value: stats.maxCalories != null
                    ? '${stats.maxCalories!.round()} kcal'
                    : '—',
                label: 'Calories max',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  final String value;
  final String label;
  const _RecordCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF041A0E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: SwimColors.wave.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: SwimColors.wave)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 9, color: SwimColors.textMuted)),
        ],
      ),
    );
  }
}

// ─── Item session ─────────────────────────────────────────────────────────────

class _SessionItem extends StatelessWidget {
  final SwimSession session;
  const _SessionItem({required this.session});

  String _formatDate(DateTime d) {
    const months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${d.day} ${months[d.month - 1]}';
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
          // Header
          Row(
            children: [
              Text(
                _formatDate(session.startedAt),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: SwimColors.textPrimary),
              ),
              if (session.locationLabel != null) ...[
                const SizedBox(width: 6),
                Text(
                  '· ${session.locationLabel}',
                  style: const TextStyle(
                      fontSize: 12, color: SwimColors.textSecondary),
                ),
              ],
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: session.jellyfishAlert
                      ? const Color(0xFF1A0808)
                      : const Color(0xFF041A0E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  session.jellyfishAlert ? 'Méduses' : 'Zone OK',
                  style: TextStyle(
                      fontSize: 10,
                      color: session.jellyfishAlert
                          ? SwimColors.danger
                          : SwimColors.wave),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stats
          Row(
            children: [
              _MiniStat(
                value: session.formattedDistance,
                label: 'distance',
                color: SwimColors.wave,
              ),
              const SizedBox(width: 16),
              _MiniStat(
                value: session.formattedDuration,
                label: 'durée',
                color: SwimColors.textPrimary,
              ),
              if (session.heartRateAvg != null) ...[
                const SizedBox(width: 16),
                _MiniStat(
                  value: '${session.heartRateAvg!.round()} bpm',
                  label: 'FC moy.',
                  color: SwimColors.heartRate,
                ),
              ],
              if (session.calories != null) ...[
                const SizedBox(width: 16),
                _MiniStat(
                  value: '${session.calories!.round()} kcal',
                  label: 'cal.',
                  color: SwimColors.calories,
                ),
              ],
              if (session.waterTempCelsius != null) ...[
                const SizedBox(width: 16),
                _MiniStat(
                  value: '${session.waterTempCelsius!.toStringAsFixed(1)}°',
                  label: 'mer',
                  color: SwimColors.waterBlue,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: SwimColors.textMuted)),
      ],
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.water_outlined,
              size: 48, color: SwimColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('Aucune session pour l\'instant.',
              style: TextStyle(
                  color: SwimColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('À l\'eau !',
              style: TextStyle(color: SwimColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
