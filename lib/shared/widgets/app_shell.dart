import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/session/screens/home_screen.dart';
import '../../features/history/screens/history_screen.dart';

class _TabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setTab(int i) => state = i;
}

final currentTabProvider = NotifierProvider<_TabNotifier, int>(_TabNotifier.new);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});
  static const _screens = [HomeScreen(), HistoryScreen()];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    return Scaffold(
      body: IndexedStack(index: currentTab, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (i) => ref.read(currentTabProvider.notifier).setTab(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.water_outlined), selectedIcon: Icon(Icons.water), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Historique'),
        ],
      ),
    );
  }
}
