import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/transactions/presentation/screens/new_transaction_modal.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../widgets/adaptive_shell_scaffold.dart';

/// Nombres de rutas tipados para navegación declarativa en Wallet
abstract class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/panel';
  static const String accounts = '/cuentas';
  static const String transactions = '/registros';
  static const String analytics = '/analitica';
  static const String budgets = '/presupuestos';
  static const String newTransaction = '/nueva-transaccion';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateStreamProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isGoingToLogin = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isGoingToLogin) {
        return AppRoutes.login;
      }
      if (isLoggedIn && isGoingToLogin) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      // Pantalla de Autenticación (Split-Screen Web / Mobile Onboarding)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Shell Adaptativo (Top Nav en Web >= 1024px / Bottom NavigationBar + Drawer en Móvil)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdaptiveShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Rama 0: Panel / Inicio (Gauges, Tendencia, Estructura, Últimos Registros)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                name: 'dashboard',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: DashboardScreen(),
                ),
              ),
            ],
          ),

          // Rama 1: Cuentas (Efectivo, BAC Credomatic, Banco Industrial BI)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.accounts,
                name: 'accounts',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AccountsScreen(),
                ),
              ),
            ],
          ),

          // Rama 2: Registros / Historial agrupado por fecha con filtros
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                name: 'transactions',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: TransactionsScreen(),
                ),
              ),
            ],
          ),

          // Rama 3: Analítica y Reportes (Flujo de Caja 31 días, Estructura Donut, Tabla)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.analytics,
                name: 'analytics',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AnalyticsScreen(),
                ),
              ),
            ],
          ),

          // Rama 4: Presupuestos y Metas
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.budgets,
                name: 'budgets',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: BudgetsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // Ruta Modal de Pantalla Completa: Calculadora de Nueva Transacción (#00ACC1)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.newTransaction,
        name: 'newTransaction',
        pageBuilder: (context, state) {
          final initialType = state.uri.queryParameters['type'] ?? 'expense';
          return CustomTransitionPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: NewTransactionModal(initialType: initialType),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              final tween = Tween(begin: begin, end: end)
                  .chain(CurveTween(curve: Curves.easeOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
    ],
  );
});
