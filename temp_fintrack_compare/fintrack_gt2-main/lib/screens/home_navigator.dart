import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/firestore_providers.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/accounts_tab.dart';
import 'tabs/vehicles_tab.dart';
import 'tabs/budget_tab.dart';
import 'add_transaction_screen.dart';

class HomeNavigator extends ConsumerStatefulWidget {
  const HomeNavigator({super.key});

  @override
  ConsumerState<HomeNavigator> createState() => _HomeNavigatorState();
}

class _HomeNavigatorState extends ConsumerState<HomeNavigator> {

  static const _tabs = [
    DashboardTab(),
    ReportsTab(),
    AccountsTab(),
    VehiclesTab(),
    BudgetTab(),
  ];

  static const _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home_rounded, color: Colors.black),
      label: 'Inicio',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_outlined),
      activeIcon: Icon(Icons.bar_chart_rounded, color: Colors.black),
      label: 'Reportes',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.credit_card_outlined),
      activeIcon: Icon(Icons.credit_card, color: Colors.black),
      label: 'Cuentas',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.directions_car_outlined),
      activeIcon: Icon(Icons.directions_car, color: Colors.black),
      label: 'Rendimientos',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_wallet_outlined),
      activeIcon: Icon(Icons.account_balance_wallet_rounded, color: Colors.black),
      label: 'Presupuesto',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    
    final currentIndex = ref.watch(navigationProvider);
    
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _tabs,
      ),

      // ── FAB con glow violeta y su diseño original ───────────────────────
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AddTransactionScreen(),
                fullscreenDialog: true,
              ),
            );
          },
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      // Ubicación personalizada para que esté alineado pero sobrepuesto
      floatingActionButtonLocation: const _EndCenteredFabLocation(),

      // ── Bottom nav ───────────────────────────────────────────────────────
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.navBackground(context),
        elevation: 16,
        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              ..._buildNavItems(0, 5, isDark, currentIndex),
              const SizedBox(width: 60), // Espacio para el FAB
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNavItems(int from, int to, bool isDark, int currentIndex) {
    return List.generate(to - from, (i) {
      final index = from + i;
      final item = _navItems[index];
      final isSelected = currentIndex == index;
      final inactiveColor = AppTheme.textMuted(context);

      return Expanded(
        child: InkWell(
          onTap: () => ref.read(navigationProvider.notifier).setIndex(index),
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? null
                    : Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? item.activeIcon
                        : IconTheme(
                            data: IconThemeData(color: inactiveColor, size: 24),
                            child: item.icon,
                          ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.black : inactiveColor,
                    ),
                    child: Text(item.label ?? '', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

// Ubicación personalizada para el FAB: al final y centrado verticalmente con la barra
class _EndCenteredFabLocation extends FloatingActionButtonLocation {
  const _EndCenteredFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // Posición X: Al final con un margen de 12px
    final double fabX = scaffoldGeometry.scaffoldSize.width - 
                        scaffoldGeometry.floatingActionButtonSize.width - 12;
    
    // Posición Y: Calculamos el centro de la barra inferior (que mide 60px)
    // El 'contentBottom' nos indica dónde termina el contenido principal y empieza la barra.
    final double barTop = scaffoldGeometry.contentBottom;
    // Si la barra está pegada al fondo, su centro está a ~30px del top de la barra.
    // Usamos un ajuste basado en la altura del FAB (generalmente 56px).
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    
    // Al utilizar un SizedBox de 60px en el BottomAppBar, su centro vertical está en:
    // barTop + (60 / 2) - (fabHeight / 2)
    // Sin embargo, para que se alinee visualmente perfecto con los iconos (que tienen padding),
    // a veces requiere un pequeño offset adicional.
    final double fabY = barTop + (60 / 2) - (fabHeight / 2) + 2; 

    return Offset(fabX, fabY);
  }
}
