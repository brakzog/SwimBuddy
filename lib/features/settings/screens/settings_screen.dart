import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/prefs_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(prefsProvider);
    _nameController = TextEditingController(text: prefs['name'] as String);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final notifier = ref.read(prefsProvider.notifier);
    final useMiles = prefs['useMiles'] as bool;
    final jellyfishRadius = prefs['jellyfishRadius'] as double;
    final notifsEnabled = prefs['notifs'] as bool;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Profil ──────────────────────────────────────────────────────
          _SectionHeader(label: 'Profil'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prénom',
                    style: TextStyle(
                        fontSize: 12, color: SwimColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(
                      color: SwimColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Votre prénom',
                    hintStyle: const TextStyle(
                        color: SwimColors.textMuted, fontSize: 15),
                    filled: true,
                    fillColor: SwimColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (v) => notifier.setName(v.trim()),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 8),
                Text(
                  'Utilisé pour le greeting "Bonjour ${_nameController.text.isNotEmpty ? _nameController.text : 'vous'}"',
                  style: const TextStyle(
                      fontSize: 11, color: SwimColors.textMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Affichage ────────────────────────────────────────────────────
          _SectionHeader(label: 'Affichage'),
          _Card(
            child: _SettingRow(
              icon: Icons.straighten_outlined,
              title: 'Unités de distance',
              subtitle: useMiles ? 'Miles (mi)' : 'Kilomètres (km)',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('km',
                      style: TextStyle(
                          fontSize: 12,
                          color: !useMiles
                              ? SwimColors.wave
                              : SwimColors.textMuted)),
                  const SizedBox(width: 8),
                  Switch(
                    value: useMiles,
                    onChanged: (v) => notifier.setUseMiles(v),
                    activeColor: SwimColors.wave,
                    inactiveThumbColor: SwimColors.wave,
                    inactiveTrackColor: SwimColors.surfaceLight,
                  ),
                  const SizedBox(width: 4),
                  Text('mi',
                      style: TextStyle(
                          fontSize: 12,
                          color: useMiles
                              ? SwimColors.wave
                              : SwimColors.textMuted)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Alertes ──────────────────────────────────────────────────────
          _SectionHeader(label: 'Alertes'),
          _Card(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: notifsEnabled
                      ? 'Alertes méduses activées'
                      : 'Notifications désactivées',
                  trailing: Switch(
                    value: notifsEnabled,
                    onChanged: (v) => notifier.setNotifs(v),
                    activeColor: SwimColors.wave,
                    inactiveTrackColor: SwimColors.surfaceLight,
                  ),
                ),
                const Divider(height: 1, color: SwimColors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined,
                        color: SwimColors.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Seuil alerte méduses',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: SwimColors.textPrimary)),
                          Text('Alerter si signalement dans ce rayon',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: SwimColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      '${jellyfishRadius.round()} km',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: SwimColors.wave),
                    ),
                  ],
                ),
                Slider(
                  value: jellyfishRadius,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  activeColor: SwimColors.wave,
                  inactiveColor: SwimColors.surfaceLight,
                  onChanged: (v) => notifier.setJellyfishRadius(v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('1 km',
                        style: TextStyle(
                            fontSize: 10, color: SwimColors.textMuted)),
                    Text('50 km',
                        style: TextStyle(
                            fontSize: 10, color: SwimColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── À propos ─────────────────────────────────────────────────────
          _SectionHeader(label: 'À propos'),
          _Card(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.waves_outlined,
                  title: 'SwimTracker',
                  subtitle: 'Version 1.0.0',
                  trailing: const SizedBox.shrink(),
                ),
                const Divider(height: 1, color: SwimColors.border),
                _SettingRow(
                  icon: Icons.cloud_outlined,
                  title: 'Données météo',
                  subtitle: 'Open-Meteo Marine (gratuit)',
                  trailing: const SizedBox.shrink(),
                ),
                const Divider(height: 1, color: SwimColors.border),
                _SettingRow(
                  icon: Icons.nature_outlined,
                  title: 'Signalements méduses',
                  subtitle: 'iNaturalist API',
                  trailing: const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Compte ──────────────────────────────────────────────────────
          _SectionHeader(label: 'Compte'),
          _Card(
            child: _SettingRow(
              icon: Icons.logout_outlined,
              title: 'Se déconnecter',
              subtitle: 'Retour à l\'écran de connexion',
              trailing: TextButton(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                },
                child: const Text('Déconnexion',
                    style: TextStyle(color: SwimColors.danger, fontSize: 13)),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: SwimColors.textMuted,
              letterSpacing: 0.08)),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SwimColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SwimColors.border, width: 0.5),
      ),
      child: child,
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: SwimColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, color: SwimColors.textPrimary)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: SwimColors.textSecondary)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
