import 'package:flutter/material.dart';

import '../app_state.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'import_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _pages = <Widget>[
    DashboardScreen(),
    ImportScreen(),
    AlertsScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appState.tab,
      builder: (context, selectedIndex, _) {
        final index = selectedIndex.clamp(0, _pages.length - 1);

        return Scaffold(
          body: IndexedStack(
            index: index,
            children: _pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: appState.goTo,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.file_upload_outlined),
                selectedIcon: Icon(Icons.file_upload),
                label: 'Import',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
            ],
          ),
        );
      },
    );
  }
}
