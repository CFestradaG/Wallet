import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/utils/financial_period_helper.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/data/repositories/account_repository.dart';
import '../../../budgets/data/models/budget_model.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../settings/data/models/user_settings_model.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/data/repositories/transaction_repository.dart';

/// 1. Providers de Infraestructura Firebase
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final currentUserIdProvider = StreamProvider<String?>((ref) {
  return ref
      .watch(firebaseAuthProvider)
      .authStateChanges()
      .map((user) => user?.uid);
});

/// 2. StreamNotifier para `UserSettingsModel` (/users/{userId})
class UserSettingsStreamNotifier extends StreamNotifier<UserSettingsModel> {
  @override
  Stream<UserSettingsModel> build() {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;
    if (userId == null || userId.isEmpty) {
      return Stream.value(UserSettingsModel.defaults('demo'));
    }
    final firestore = ref.watch(firebaseFirestoreProvider);
    return firestore
        .doc(FirestorePaths.userDoc(userId))
        .snapshots()
        .map((snap) => UserSettingsModel.fromFirestore(snap));
  }

  /// Actualiza la configuración del ciclo financiero (ej. día de corte 27 y quincena día 13)
  Future<void> updateFinancialCycleSettings({
    required int startDayOfMonth,
    required bool enableSplitPeriod,
    required int midMonthDay,
  }) async {
    final userId = ref.read(currentUserIdProvider).valueOrNull;
    if (userId == null || userId.isEmpty) return;

    final firestore = ref.read(firebaseFirestoreProvider);
    await firestore.doc(FirestorePaths.userDoc(userId)).update({
      'startDayOfMonth': startDayOfMonth.clamp(1, 31),
      'enableSplitPeriod': enableSplitPeriod,
      'midMonthDay': midMonthDay.clamp(1, 31),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final userSettingsProvider =
    StreamNotifierProvider<UserSettingsStreamNotifier, UserSettingsModel>(
      UserSettingsStreamNotifier.new,
    );

/// Provider que expone `FinancialPeriodHelper` sincronizado con la configuración del usuario
final financialPeriodHelperProvider = Provider<FinancialPeriodHelper>((ref) {
  final settings =
      ref.watch(userSettingsProvider).valueOrNull ??
      UserSettingsModel.defaults('demo');
  return FinancialPeriodHelper.fromSettings(settings);
});

/// 3. Estado del Filtro de Período en la UI (Período Actual, Primera Mitad, Segunda Mitad, Personalizado)
class PeriodFilterState {
  final PeriodFilterMode mode;
  final DateTime referenceDate;
  final DateTimeRange? customRange;

  const PeriodFilterState({
    this.mode = PeriodFilterMode.fullPeriod,
    required this.referenceDate,
    this.customRange,
  });

  PeriodFilterState copyWith({
    PeriodFilterMode? mode,
    DateTime? referenceDate,
    DateTimeRange? customRange,
  }) {
    return PeriodFilterState(
      mode: mode ?? this.mode,
      referenceDate: referenceDate ?? this.referenceDate,
      customRange: customRange ?? this.customRange,
    );
  }
}

class PeriodFilterNotifier extends Notifier<PeriodFilterState> {
  @override
  PeriodFilterState build() {
    return PeriodFilterState(referenceDate: DateTime.now());
  }

  void setFilterMode(PeriodFilterMode mode, {DateTimeRange? customRange}) {
    state = state.copyWith(mode: mode, customRange: customRange);
  }

  void setReferenceDate(DateTime date) {
    state = state.copyWith(referenceDate: date);
  }
}

final periodFilterProvider =
    NotifierProvider<PeriodFilterNotifier, PeriodFilterState>(
      PeriodFilterNotifier.new,
    );

/// 4. Providers de Repositorios (Clean Architecture Data Layer)
final accountRepositoryProvider = Provider<IAccountRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return AccountRepository(firestore);
});

final transactionRepositoryProvider = Provider<ITransactionRepository>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return TransactionRepository(firestore);
});

final userCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider).valueOrNull;
  if (userId == null || userId.isEmpty) {
    return Stream.value(const <CategoryModel>[]);
  }
  return ref
      .watch(firebaseFirestoreProvider)
      .collection(FirestorePaths.categories(userId))
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(CategoryModel.fromFirestore).toList(),
      );
});

final userBudgetsProvider = StreamProvider<List<BudgetModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider).valueOrNull;
  if (userId == null || userId.isEmpty) {
    return Stream.value(const <BudgetModel>[]);
  }
  return ref
      .watch(firebaseFirestoreProvider)
      .collection(FirestorePaths.budgets(userId))
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(BudgetModel.fromFirestore).toList());
});

/// 5. Estado Consolidado del Dashboard con Período Financiero Dinámico
class DashboardWalletState {
  final List<AccountModel> accounts;
  final List<TransactionModel> recentTransactions;
  final String activePeriodName; // Ej. "2026-11"
  final String activeFirestoreId; // Ej. "period_2026_11"
  final DateTimeRange activeRange; // Ej. 27 Oct 00:00:00 - 26 Nov 23:59:59
  final String currentSubPeriodLabel;
  final PeriodFilterMode filterMode;

  const DashboardWalletState({
    required this.accounts,
    required this.recentTransactions,
    required this.activePeriodName,
    required this.activeFirestoreId,
    required this.activeRange,
    required this.currentSubPeriodLabel,
    required this.filterMode,
  });

  /// Patrimonio Neto Total sumando `currentBalance` de todas las cuentas activas
  double get netWorthTotal =>
      accounts.fold(0.0, (sum, item) => sum + item.currentBalance);

  /// Total de gastos dentro del rango del período/quincena seleccionada
  double get totalExpenses => recentTransactions
      .where((t) => t.isExpense)
      .fold(0.0, (sum, item) => sum + item.amount);

  /// Total de ingresos dentro del rango del período/quincena seleccionada
  double get totalIncome => recentTransactions
      .where((t) => t.isIncome)
      .fold(0.0, (sum, item) => sum + item.amount);

  /// Agrupación de gastos por categoría para el gráfico de Dona "Estructura de gastos"
  Map<String, double> get expensesByCategory {
    final Map<String, double> map = {};
    for (final tx in recentTransactions.where((t) => t.isExpense)) {
      map[tx.categoryName] = (map[tx.categoryName] ?? 0.0) + tx.amount;
    }
    return map;
  }
}

/// 6. NotifierProvider Reactivo para Cuentas (StreamNotifier)
class AccountsStreamNotifier extends StreamNotifier<List<AccountModel>> {
  @override
  Stream<List<AccountModel>> build() {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;
    if (userId == null || userId.isEmpty) {
      return const Stream.empty();
    }
    final repository = ref.watch(accountRepositoryProvider);
    return repository.watchUserAccounts(userId);
  }
}

final userAccountsNotifierProvider =
    StreamNotifierProvider<AccountsStreamNotifier, List<AccountModel>>(
      AccountsStreamNotifier.new,
    );

/// 7. NotifierProvider Reactivo para Transacciones con Operaciones Atómicas
class TransactionsStreamNotifier
    extends StreamNotifier<List<TransactionModel>> {
  @override
  Stream<List<TransactionModel>> build() {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;
    if (userId == null || userId.isEmpty) {
      return const Stream.empty();
    }
    final repository = ref.watch(transactionRepositoryProvider);
    return repository.watchUserTransactions(userId: userId, limit: 100);
  }

  Future<void> saveTransaction(TransactionModel transaction) async {
    final repository = ref.read(transactionRepositoryProvider);
    final helper = ref.read(financialPeriodHelperProvider);
    await repository.saveTransactionWithRunTransaction(
      transaction: transaction,
      periodHelper: helper,
    );
  }

  Future<void> editTransaction({
    required TransactionModel originalTx,
    required TransactionModel updatedTx,
  }) async {
    final repository = ref.read(transactionRepositoryProvider);
    final helper = ref.read(financialPeriodHelperProvider);
    await repository.updateTransactionAtomic(
      originalTx: originalTx,
      updatedTx: updatedTx,
      periodHelper: helper,
    );
  }

  Future<void> removeTransaction(TransactionModel transaction) async {
    final repository = ref.read(transactionRepositoryProvider);
    await repository.deleteTransactionAtomic(transaction);
  }
}

final userTransactionsNotifierProvider =
    StreamNotifierProvider<TransactionsStreamNotifier, List<TransactionModel>>(
      TransactionsStreamNotifier.new,
    );

/// 8. NotifierProvider Principal del Dashboard que filtra por el Ciclo Financiero Dinámico
class DashboardNotifier extends Notifier<AsyncValue<DashboardWalletState>> {
  @override
  AsyncValue<DashboardWalletState> build() {
    final accountsAsync = ref.watch(userAccountsNotifierProvider);
    final transactionsAsync = ref.watch(userTransactionsNotifierProvider);
    final helper = ref.watch(financialPeriodHelperProvider);
    final filterState = ref.watch(periodFilterProvider);

    if (accountsAsync.isLoading || transactionsAsync.isLoading) {
      return const AsyncValue.loading();
    }

    if (accountsAsync.hasError) {
      return AsyncValue.error(
        accountsAsync.error!,
        accountsAsync.stackTrace ?? StackTrace.current,
      );
    }

    if (transactionsAsync.hasError) {
      return AsyncValue.error(
        transactionsAsync.error!,
        transactionsAsync.stackTrace ?? StackTrace.current,
      );
    }

    final activeRange = helper.getRangeForFilterMode(
      filterState.mode,
      filterState.referenceDate,
      customRange: filterState.customRange,
    );

    final allTx = transactionsAsync.value ?? const [];
    final filteredTx = allTx
        .where((tx) => helper.isDateInRange(tx.date, activeRange))
        .toList();

    return AsyncValue.data(
      DashboardWalletState(
        accounts: accountsAsync.value ?? const [],
        recentTransactions: filteredTx,
        activePeriodName: helper.getPeriodName(filterState.referenceDate),
        activeFirestoreId: helper.getFirestorePeriodId(
          filterState.referenceDate,
        ),
        activeRange: activeRange,
        currentSubPeriodLabel: helper.getSubPeriod(filterState.referenceDate),
        filterMode: filterState.mode,
      ),
    );
  }
}

final dashboardNotifierProvider =
    NotifierProvider<DashboardNotifier, AsyncValue<DashboardWalletState>>(
      DashboardNotifier.new,
    );
