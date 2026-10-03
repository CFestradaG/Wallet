import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme.dart';

class AdaptiveShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AdaptiveShellScaffold({super.key, required this.navigationShell});

  static const _destinations = [
    (
      label: 'Panel',
      icon: Icons.dashboard_outlined,
      selected: Icons.dashboard_rounded,
    ),
    (
      label: 'Cuentas',
      icon: Icons.account_balance_wallet_outlined,
      selected: Icons.account_balance_wallet_rounded,
    ),
    (
      label: 'Registros',
      icon: Icons.receipt_long_outlined,
      selected: Icons.receipt_long_rounded,
    ),
    (
      label: 'Analítica',
      icon: Icons.insights_outlined,
      selected: Icons.insights_rounded,
    ),
    (
      label: 'Presupuestos',
      icon: Icons.pie_chart_outline_rounded,
      selected: Icons.pie_chart_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    return Scaffold(
      backgroundColor: ObsidianFlowColors.canvasBase,
      appBar: AppBar(
        title: Text(_destinations[index].label),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (nextIndex) => navigationShell.goBranch(
          nextIndex,
          initialLocation: nextIndex == index,
        ),
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              label: destination.label,
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selected),
            ),
        ],
      ),
    );
  }
}
