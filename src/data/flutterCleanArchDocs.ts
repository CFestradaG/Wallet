export interface FlutterFileDoc {
  id: string;
  filename: string;
  path: string;
  layer: 'core' | 'domain' | 'data' | 'presentation' | 'root';
  description: string;
  code: string;
}

export const FLUTTER_FOLDER_TREE = `wallet_budgetbakers_flutter/
├── pubspec.yaml
├── firebase.json
├── firestore.rules
└── lib/
    ├── main.dart                                      # Tarea 2.1: Firebase.initializeApp + ProviderScope
    ├── firebase_options.dart                          # Configuración generada por FlutterFire CLI
    │
    ├── core/                                          # Capa transversal compartida
    │   ├── constants/
    │   │   ├── firestore_paths.dart                   # Rutas tipadas: /users/{userId}/accounts, etc.
    │   │   └── app_constants.dart                     # Monedas ISO (GTQ, USD) y límites
    │   ├── errors/
    │   │   ├── failures.dart                          # Jerarquía Failure (ServerFailure, AuthFailure)
    │   │   └── exceptions.dart                        # Excepciones de capa Data
    │   ├── providers/
    │   │   └── firebase_providers.dart                # Providers globales de FirebaseAuth y FirebaseFirestore
    │   ├── router/
    │   │   └── app_router.dart                        # Tarea 2.3: GoRouter + StatefulShellRoute.indexedStack
    │   ├── theme/
    │   │   └── theme.dart                             # Tarea 2.2: Paleta exacta Stitch "Obsidian Flow" M3
    │   ├── utils/
    │   │   ├── currency_formatter.dart                # Formateador tabular GTQ / Quetzales
    │   │   └── calculator_engine.dart                 # Evaluador aritmético para el teclado 4x4
    │   └── widgets/
    │       ├── adaptive_shell_scaffold.dart           # Shell responsivo (Web TopBar / Mobile BottomNav + Drawer)
    │       └── glass_surface_card.dart                # Contenedor Tonal Layering (#1E1E1E / #252525)
    │
    └── features/                                      # Módulos desacoplados por dominio funcional
        ├── auth/
        │   ├── domain/
        │   │   ├── entities/user_entity.dart
        │   │   ├── repositories/auth_repository.dart
        │   │   └── usecases/sign_in_with_google.dart
        │   ├── data/
        │   │   ├── models/user_model.dart
        │   │   ├── datasources/auth_remote_datasource.dart
        │   │   └── repositories/auth_repository_impl.dart
        │   └── presentation/
        │       ├── providers/auth_providers.dart
        │       └── screens/login_screen.dart          # Split-screen Web / Mobile Onboarding
        │
        ├── accounts/                                  # Subcolección: /users/{userId}/accounts
        │   ├── domain/
        │   │   ├── entities/account_entity.dart
        │   │   ├── repositories/account_repository.dart
        │   │   └── usecases/
        │   │       ├── watch_accounts.dart
        │   │       └── create_or_update_account.dart
        │   ├── data/
        │   │   ├── models/account_model.dart
        │   │   ├── datasources/account_firestore_datasource.dart
        │   │   └── repositories/account_repository_impl.dart
        │   └── presentation/
        │       ├── providers/accounts_provider.dart
        │       ├── screens/accounts_screen.dart
        │       └── widgets/account_quick_card.dart    # Tarjetas Efectivo, BAC Credomatic, BI
        │
        ├── transactions/                              # Subcolección: /users/{userId}/transactions
        │   ├── domain/
        │   │   ├── entities/transaction_entity.dart
        │   │   ├── repositories/transaction_repository.dart
        │   │   └── usecases/
        │   │       ├── watch_monthly_transactions.dart
        │   │       ├── add_transaction_atomic.dart    # WriteBatch: tx + account balance + summary
        │   │       └── delete_transaction_atomic.dart
        │   ├── data/
        │   │   ├── models/transaction_model.dart
        │   │   ├── datasources/transaction_firestore_datasource.dart
        │   │   └── repositories/transaction_repository_impl.dart
        │   └── presentation/
        │       ├── providers/
        │       │   ├── transactions_provider.dart
        │       │   └── calculator_keypad_notifier.dart
        │       ├── screens/
        │       │   ├── transactions_screen.dart       # Historial agrupado por día + filtros
        │       │   └── new_transaction_modal.dart     # Modal Calculadora #00ACC1
        │       └── widgets/
        │           ├── category_slider_selector.dart
        │           └── budgetbakers_keypad.dart
        │
        ├── categories/                                # Subcolección: /users/{userId}/categories
        │   ├── domain/
        │   │   ├── entities/category_entity.dart
        │   │   └── repositories/category_repository.dart
        │   ├── data/
        │   │   ├── models/category_model.dart
        │   │   └── repositories/category_repository_impl.dart
        │   └── presentation/
        │       └── providers/categories_provider.dart
        │
        ├── budgets/                                   # Subcolección: /users/{userId}/budgets
        │   ├── domain/
        │   │   ├── entities/budget_entity.dart
        │   │   ├── repositories/budget_repository.dart
        │   │   └── usecases/watch_active_budgets.dart
        │   ├── data/
        │   │   ├── models/budget_model.dart
        │   │   └── repositories/budget_repository_impl.dart
        │   └── presentation/
        │       ├── providers/budgets_provider.dart
        │       ├── screens/budgets_screen.dart
        │       └── widgets/budget_progress_card.dart  # Supermercado 70%, Gasolina 25%, Servicios 90%
        │
        └── analytics/                                 # Subcolección: /users/{userId}/summaries/{year_month}
            ├── domain/
            │   ├── entities/monthly_summary_entity.dart
            │   ├── repositories/summary_repository.dart
            │   └── usecases/watch_monthly_summary.dart
            ├── data/
            │   ├── models/monthly_summary_model.dart
            │   └── repositories/summary_repository_impl.dart
            └── presentation/
                ├── providers/analytics_provider.dart
                ├── screens/
                │   ├── dashboard_screen.dart          # Panel principal con 3 velocímetros y tendencia
                │   └── analytics_screen.dart          # Flujo de Caja 31 días, Estructura Donut y Rubros
                └── widgets/
                    ├── tachometer_gauges_card.dart
                    ├── daily_cashflow_bar_chart.dart
                    └── spending_donut_chart.dart`;

export const FLUTTER_FILES_DOCS: FlutterFileDoc[] = [
  {
    id: 'main_dart',
    filename: 'main.dart',
    path: 'lib/main.dart',
    layer: 'root',
    description:
      'Tarea 2.1: Punto de entrada de la aplicación con inicialización de Firebase (Auth + Cloud Firestore con persistencia offline) y configuración raíz de Riverpod (ProviderScope).',
    code: `import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/theme/theme.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración de barra de estado inmersiva para Obsidian Flow (#121212)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Inicialización de Firebase con opciones de plataforma (Web / iOS / Android)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Habilitar persistencia offline ilimitada en Cloud Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    const ProviderScope(
      child: WalletApp(),
    ),
  );
}

class WalletApp extends ConsumerWidget {
  const WalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Wallet by BudgetBakers',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ObsidianFlowTheme.darkTheme,
      routerConfig: router,
    );
  }
}`,
  },
  {
    id: 'theme_dart',
    filename: 'theme.dart',
    path: 'lib/core/theme/theme.dart',
    layer: 'core',
    description:
      'Tarea 2.2: Configuración exacta del sistema de diseño Stitch "Obsidian Flow" en Material 3 (Canvas #121212, Surface #131313, Primary Emerald #00E676 / #75FF9E, Outflow Crimson #FF5252 / #FFB3AE, Analytics Cyan #00DCF5 y números tabulares Inter).',
    code: `import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de Diseño "Obsidian Flow" — Stitch Material 3 Dark Theme
class ObsidianFlowColors {
  ObsidianFlowColors._();

  // Canvas & Surface Hierarchy (Obsidian Flow Spec)
  static const Color canvasBase = Color(0xFF121212);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceDim = Color(0xFF131313);
  static const Color surfaceBright = Color(0xFF393939);
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353534);

  // Elevations & Borders
  static const Color elevation1 = Color(0xFF1E1E1E);
  static const Color elevation2 = Color(0xFF252525);
  static const Color elevation3 = Color(0xFF2E2E2E);
  static const Color dividerBorder = Color(0xFF2C2C2C);

  // Semantic Accents (Material 3 Tokens + Stitch Spec)
  static const Color primary = Color(0xFF75FF9E);
  static const Color onPrimary = Color(0xFF003918);
  static const Color primaryContainer = Color(0xFF00E676); // Inflow Emerald
  static const Color onPrimaryContainer = Color(0xFF00612E);
  static const Color primaryFixed = Color(0xFF62FF96);
  static const Color primaryFixedDim = Color(0xFF00E475);

  static const Color secondary = Color(0xFFFFB3AE);
  static const Color onSecondary = Color(0xFF68000C);
  static const Color secondaryContainer = Color(0xFFA00118);
  static const Color onSecondaryContainer = Color(0xFFFFA8A3);
  static const Color outflowCrimson = Color(0xFFFF5252); // Outflow Accent

  static const Color tertiary = Color(0xFFA3F1FF);
  static const Color onTertiary = Color(0xFF00363D);
  static const Color tertiaryContainer = Color(0xFF00DCF5);
  static const Color onTertiaryContainer = Color(0xFF005D68);
  static const Color analyticsCyan = Color(0xFF00E5FF); // Analytics Accent
  static const Color calculatorHeaderCyan = Color(0xFF00ACC1);

  static const Color categoryViolet = Color(0xFF9C27B0); // Quaternary Accent

  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // Typography & Foregrounds
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFBACBB9);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textMuted = Color(0xFF666666);
  static const Color outline = Color(0xFF859585);
  static const Color outlineVariant = Color(0xFF3B4A3D);
}

class ObsidianFlowTheme {
  ObsidianFlowTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ObsidianFlowColors.primary,
      onPrimary: ObsidianFlowColors.onPrimary,
      primaryContainer: ObsidianFlowColors.primaryContainer,
      onPrimaryContainer: ObsidianFlowColors.onPrimaryContainer,
      secondary: ObsidianFlowColors.secondary,
      onSecondary: ObsidianFlowColors.onSecondary,
      secondaryContainer: ObsidianFlowColors.secondaryContainer,
      onSecondaryContainer: ObsidianFlowColors.onSecondaryContainer,
      tertiary: ObsidianFlowColors.tertiary,
      onTertiary: ObsidianFlowColors.onTertiary,
      tertiaryContainer: ObsidianFlowColors.tertiaryContainer,
      onTertiaryContainer: ObsidianFlowColors.onTertiaryContainer,
      error: ObsidianFlowColors.error,
      onError: ObsidianFlowColors.onError,
      errorContainer: ObsidianFlowColors.errorContainer,
      onErrorContainer: ObsidianFlowColors.onErrorContainer,
      surface: ObsidianFlowColors.canvasBase,
      onSurface: ObsidianFlowColors.onSurface,
      surfaceContainerHighest: ObsidianFlowColors.surfaceContainerHighest,
      onSurfaceVariant: ObsidianFlowColors.onSurfaceVariant,
      outline: ObsidianFlowColors.outline,
      outlineVariant: ObsidianFlowColors.outlineVariant,
      surfaceTint: ObsidianFlowColors.primaryFixedDim,
      inverseSurface: Color(0xFFE5E2E1),
      onInverseSurface: Color(0xFF313030),
      inversePrimary: Color(0xFF006D35),
    );

    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ObsidianFlowColors.canvasBase,
      colorScheme: colorScheme,
      dividerColor: ObsidianFlowColors.dividerBorder,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 40,
          height: 48 / 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: ObsidianFlowColors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 34, // currency-display
          height: 42 / 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          color: ObsidianFlowColors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          height: 36 / 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.28,
          color: ObsidianFlowColors.onSurface,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.22,
          color: ObsidianFlowColors.onSurface,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w600,
          color: ObsidianFlowColors.onSurface,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          height: 22 / 16,
          fontWeight: FontWeight.w600,
          color: ObsidianFlowColors.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w400,
          color: ObsidianFlowColors.onSurface,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
          color: ObsidianFlowColors.onSurface,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w400,
          color: ObsidianFlowColors.textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          height: 18 / 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.14,
          color: ObsidianFlowColors.onSurface,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.24,
          color: ObsidianFlowColors.onSurfaceVariant,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          height: 14 / 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: ObsidianFlowColors.onSurfaceVariant,
        ),
      ),
      cardTheme: CardTheme(
        color: ObsidianFlowColors.elevation1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
    );
  }
}`,
  },
  {
    id: 'app_router_dart',
    filename: 'app_router.dart',
    path: 'lib/core/router/app_router.dart',
    layer: 'core',
    description:
      'Tarea 2.3: Enrutador declarativo con go_router y Riverpod. Incluye redirección reactiva según FirebaseAuth, navegación shell con preservación de estado (StatefulShellRoute.indexedStack) y ruta modal para la calculadora de Nueva Transacción.',
    code: `import 'package:flutter/material.dart';
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
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isGoingToLogin = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isGoingToLogin) return AppRoutes.login;
      if (isLoggedIn && isGoingToLogin) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdaptiveShellScaffold(navigationShell: navigationShell);
        },
        branches: [
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
              final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
          );
        },
      ),
    ],
  );
});`,
  },
  {
    id: 'firestore_paths_dart',
    filename: 'firestore_paths.dart',
    path: 'lib/core/constants/firestore_paths.dart',
    layer: 'core',
    description:
      'Centraliza exactamente las subcolecciones requeridas por usuario en Cloud Firestore: /users/{userId}/accounts, /transactions, /categories, /budgets y /summaries/{year_month}.',
    code: `/// Centralizador de rutas tipadas para Cloud Firestore
class FirestorePaths {
  FirestorePaths._();

  static String userDoc(String userId) => 'users/\$userId';

  static String accounts(String userId) => 'users/\$userId/accounts';
  static String accountDoc(String userId, String accountId) =>
      'users/\$userId/accounts/\$accountId';

  static String transactions(String userId) => 'users/\$userId/transactions';
  static String transactionDoc(String userId, String txId) =>
      'users/\$userId/transactions/\$txId';

  static String categories(String userId) => 'users/\$userId/categories';
  static String categoryDoc(String userId, String categoryId) =>
      'users/\$userId/categories/\$categoryId';

  static String budgets(String userId) => 'users/\$userId/budgets';
  static String budgetDoc(String userId, String budgetId) =>
      'users/\$userId/budgets/\$budgetId';

  static String summaries(String userId) => 'users/\$userId/summaries';
  static String summaryDoc(String userId, String yearMonth) =>
      'users/\$userId/summaries/\$yearMonth';
}`,
  },
  {
    id: 'transaction_repository_impl_dart',
    filename: 'transaction_repository_impl.dart',
    path: 'lib/features/transactions/data/repositories/transaction_repository_impl.dart',
    layer: 'data',
    description:
      'Implementación del repositorio en la capa Data que ejecuta WriteBatch atómico en Cloud Firestore para registrar una transacción, actualizar el saldo de la cuenta y sincronizar /summaries/{year_month}.',
    code: `import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../models/transaction_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final FirebaseFirestore _firestore;

  const TransactionRepositoryImpl(this._firestore);

  @override
  Stream<List<TransactionEntity>> watchTransactions({
    required String userId,
    required String yearMonth,
  }) {
    return _firestore
        .collection(FirestorePaths.transactions(userId))
        .where('userId', isEqualTo: userId)
        .where('yearMonth', isEqualTo: yearMonth)
        .orderBy('dateIso', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> addTransactionAtomic({
    required String userId,
    required TransactionEntity transaction,
  }) async {
    final batch = _firestore.batch();

    final txRef = _firestore.doc(
      FirestorePaths.transactionDoc(userId, transaction.id),
    );
    final accRef = _firestore.doc(
      FirestorePaths.accountDoc(userId, transaction.accountId),
    );
    final summaryRef = _firestore.doc(
      FirestorePaths.summaryDoc(userId, transaction.yearMonth),
    );

    // 1. Insertar documento en /users/{userId}/transactions/{txId}
    batch.set(txRef, TransactionModel.fromEntity(transaction).toFirestore());

    // 2. Actualizar saldo en /users/{userId}/accounts/{accountId}
    final delta = transaction.type == 'income'
        ? transaction.amount
        : -transaction.amount;
    batch.update(accRef, {
      'balance': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3. Actualizar resumen mensual en /users/{userId}/summaries/{year_month}
    batch.set(
      summaryRef,
      {
        'userId': userId,
        'yearMonth': transaction.yearMonth,
        'totalIncome': FieldValue.increment(
          transaction.type == 'income' ? transaction.amount : 0,
        ),
        'totalExpense': FieldValue.increment(
          transaction.type == 'expense' ? transaction.amount : 0,
        ),
        'netCashFlow': FieldValue.increment(delta),
        'currency': transaction.currency,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}`,
  },
];
