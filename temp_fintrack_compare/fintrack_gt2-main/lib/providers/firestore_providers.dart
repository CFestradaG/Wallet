import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

// ─── Firestore instance ───────────────────────────────────────────────────────

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ─── Current user UID ─────────────────────────────────────────────────────────

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.asData?.value;
});

// Provider para controlar el índice de navegación global
class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}
final navigationProvider = NotifierProvider<NavigationNotifier, int>(NavigationNotifier.new);

// ─── USER PROFILE ────────────────────────────────────────────────────────────

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final db = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return db
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) => doc.data() == null
              ? null
              : UserProfile.fromMap(doc.data()!));
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ─── USER PREFERENCES ────────────────────────────────────────────────────────

final userPreferencesProvider = StreamProvider<UserPreferences>((ref) {
  final db = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(const UserPreferences());
      return db
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) {
        final data = doc.data();
        final prefs =
            (data?['preferences'] as Map?)?.cast<String, dynamic>() ?? {};
        return UserPreferences.fromMap(prefs);
      });
    },
    loading: () => Stream.value(const UserPreferences()),
    error: (_, __) => Stream.value(const UserPreferences()),
  );
});

final userPreferencesMapProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final db = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(const <String, dynamic>{});
      return db.collection('users').doc(user.uid).snapshots().map((doc) {
        final data = doc.data();
        return (data?['preferences'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
      });
    },
    loading: () => Stream.value(const <String, dynamic>{}),
    error: (_, __) => Stream.value(const <String, dynamic>{}),
  );
});

// ─── ACCOUNTS ─────────────────────────────────────────────────────────────────

final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return db
          .collection('users')
          .doc(user.uid)
          .collection('accounts')
          .snapshots()
          .map((snap) => snap.docs
              .map((doc) => Account.fromMap(doc.id, doc.data()))
              .toList()
            ..sort((a, b) {
              if (a.type == b.type) return a.name.compareTo(b.name);
              if (a.type == AccountType.creditCard) return -1;
              if (b.type == AccountType.creditCard) return 1;
              if (a.type == AccountType.savings) return -1;
              if (b.type == AccountType.savings) return 1;
              return 0;
            }));
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ─── ACTIVE PERIOD ────────────────────────────────────────────────────────────

final activePeriodProvider = StreamProvider<Period?>((ref) {
  final db = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return db
          .collection('users')
          .doc(user.uid)
          .collection('periods')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) return null;
        final doc = snap.docs.first;
        return Period.fromMap(doc.id, doc.data());
      });
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ─── CATEGORIES ───────────────────────────────────────────────────────────────

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return db
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .snapshots()
          .map((snap) => snap.docs
              .map((doc) => Category.fromMap(doc.id, doc.data()))
              .toList());
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ─── PERIODS (ALL) ────────────────────────────────────────────────────────────

final periodsStreamProvider = StreamProvider<List<Period>>((ref) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) return const Stream.empty();

  return db
      .collection('users')
      .doc(user.uid)
      .collection('periods')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Period.fromMap(doc.id, doc.data()))
          .toList());
});

// ─── TRANSACTIONS for a period ────────────────────────────────────────────────

final transactionsForPeriodProvider =
    StreamProvider.family<List<TransactionRecord>, String>((ref, periodId) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) return const Stream.empty();

  return db
      .collection('users')
      .doc(user.uid)
      .collection('transactions')
      .where('periodId', isEqualTo: periodId)
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((doc) => TransactionRecord.fromMap(doc.id, doc.data()))
            .toList();
        // Ordenamiento local (descendente) para evitar índice compuesto
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });
});

// ─── ALL TRANSACTIONS ─────────────────────────────────────────────────────────

final allTransactionsStreamProvider =
    StreamProvider<List<TransactionRecord>>((ref) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) return const Stream.empty();

  return db
      .collection('users')
      .doc(user.uid)
      .collection('transactions')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => TransactionRecord.fromMap(doc.id, doc.data()))
          .toList());
});

/// Mapa de accountId -> balance calculado centralizado
final accountBalancesProvider = Provider<Map<String, double>>((ref) {
  final accounts = ref.watch(accountsStreamProvider).value ?? [];
  final transactions = ref.watch(allTransactionsStreamProvider).value ?? [];

  final byId = {for (final a in accounts) a.id: a};
  final balances = {for (final a in accounts) a.id: a.currentDebt};

  for (final tx in transactions) {
    final acc = byId[tx.accountId];
    if (acc == null) continue;
    final current = balances[acc.id] ?? 0.0;
    if (acc.type == AccountType.creditCard) {
      balances[acc.id] = tx.type == TransactionType.expense
          ? current + tx.amount
          : current - tx.amount;
    } else {
      balances[acc.id] = tx.type == TransactionType.income
          ? current + tx.amount
          : current - tx.amount;
    }
  }
  return balances;
});

// Estructura para estadísticas de presupuesto
class BudgetStat {
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColorHex;
  final String master;
  final double budget;
  final double actual;

  BudgetStat({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColorHex,
    required this.master,
    required this.budget,
    required this.actual,
  });

  double get percent => budget > 0 ? (actual / budget) : 0;
  double get remaining => budget - actual;
}

/// Provider derivado para estadísticas de presupuesto por período
final budgetStatsProvider = Provider.family<List<BudgetStat>, String>((ref, periodId) {
  final categories = ref.watch(categoriesStreamProvider).value ?? [];
  final allTxs = ref.watch(allTransactionsStreamProvider).value ?? [];
  final periods = ref.watch(periodsStreamProvider).value ?? [];

  final period = periods.firstWhere((p) => p.id == periodId,
      orElse: () => throw StateError('Period not found'));
  final periodTxs = allTxs.where((t) => t.periodId == periodId).toList();

  final stats = <BudgetStat>[];
  for (final cat in categories) {
    if (cat.type != CategoryType.expense) continue;

    final budget = period.budgets[cat.id] ?? cat.budgetAmount ?? 0.0;
    final actual = periodTxs
        .where((t) => t.categoryId == cat.id && !t.isTransfer)
        .fold(0.0, (sum, t) => sum + t.amount);

    if (budget > 0 || actual > 0) {
      stats.add(BudgetStat(
        categoryId: cat.id,
        categoryName: cat.name,
        categoryIcon: cat.icon,
        categoryColorHex: cat.colorHex,
        master: cat.master,
        budget: budget,
        actual: actual,
      ));
    }
  }

  // Ordenar por master y luego por nombre
  stats.sort((a, b) {
    final m = a.master.compareTo(b.master);
    if (m != 0) return m;
    return a.categoryName.compareTo(b.categoryName);
  });

  return stats;
});

// ─── PERIOD BALANCE ───────────────────────────────────────────────────────────

class PeriodBalance {
  final double income;
  final double expense;
  double get available => income - expense;

  PeriodBalance({required this.income, required this.expense});
}

final periodBalanceProvider =
    Provider.family<PeriodBalance, List<TransactionRecord>>((ref, transactions) {
  double income = 0;
  double expense = 0;
  for (final t in transactions) {
    if (t.isTransfer) continue;
    if (t.type == TransactionType.income) {
      income += t.amount;
    } else {
      expense += t.amount;
    }
  }
  return PeriodBalance(income: income, expense: expense);
});

// ─── VEHICLES ─────────────────────────────────────────────────────────────────

final vehiclesStreamProvider = StreamProvider<List<Vehicle>>((ref) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) return const Stream.empty();

  return db
      .collection('users')
      .doc(user.uid)
      .collection('vehicles')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Vehicle.fromMap(doc.id, doc.data()))
          .toList());
});

// ─── FUEL RECORDS for a vehicle ───────────────────────────────────────────────

final fuelRecordsProvider =
    StreamProvider.family<List<FuelRecord>, String>((ref, vehicleId) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) return const Stream.empty();

  return db
      .collection('users')
      .doc(user.uid)
      .collection('vehicles')
      .doc(vehicleId)
      .collection('fuel_records')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => FuelRecord.fromMap(doc.id, doc.data()))
          .toList());
});

// ─── FIRESTORE SERVICE ────────────────────────────────────────────────────────

final firestoreServiceProvider = Provider<FirestoreDataService>((ref) {
  final db = ref.watch(firestoreProvider);
  return FirestoreDataService(db);
});

class FirestoreDataService {
  final FirebaseFirestore _db;
  FirestoreDataService(this._db);

  Future<void> saveUserIfNotExists(User user) async {
    final userDoc = _db.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<Map<String, dynamic>> getScreenFilters(String uid, String screen) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('screen_state')
        .doc(screen)
        .get();
    return snap.data() ?? {};
  }

  Future<void> saveScreenFilters(
      String uid, String screen, Map<String, dynamic> filters) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('screen_state')
        .doc(screen)
        .set(filters, SetOptions(merge: true));
  }

  Future<void> addTransaction(
      String uid, TransactionRecord transaction) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .add(transaction.toMap());
  }

  Future<void> updateTransaction(
      String uid, String transactionId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(transactionId)
        .update(data);
  }

  Future<void> deleteTransaction(String uid, String transactionId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(transactionId)
        .delete();
  }

  Future<void> addAccount(String uid, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .add(data);
  }

  Future<void> updateAccount(String uid, String accountId,
      Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .doc(accountId)
        .update(data);
  }


  Future<void> deleteAccount(String uid, String accountId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .doc(accountId)
        .delete();
  }

  Future<void> addCategory(String uid, Category category) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .add(category.toMap());
  }

  Future<void> updateCategory(
      String uid, String categoryId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .update(data);
  }

  Future<void> deleteCategory(String uid, String categoryId) async {
    final txSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();
    if (txSnap.docs.isNotEmpty) {
      throw StateError(
          'No se puede eliminar una categoria que ya tiene movimientos.');
    }

    await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .delete();
  }

  Future<({String expenseId, String incomeId})> ensureTransferCategories(
      String uid) async {
    final col = _db.collection('users').doc(uid).collection('categories');

    final outRef = col.doc('transfer_out');
    final inRef = col.doc('transfer_in');

    final snap = await _db.runTransaction((tx) async {
      final outSnap = await tx.get(outRef);
      final inSnap = await tx.get(inRef);

      if (!outSnap.exists) {
        tx.set(outRef, {
          'name': 'Transferencia (salida)',
          'type': CategoryType.expense.name,
          'colorHex': 'FF5B4FE8',
          'icon': 'swap_horiz',
          'budgetAmount': null,
          'defaultPaymentMethod': PaymentMethod.transfer.name,
          'isFixed': false,
        });
      }

      if (!inSnap.exists) {
        tx.set(inRef, {
          'name': 'Transferencia (ingreso)',
          'type': CategoryType.income.name,
          'colorHex': 'FF00E5C3',
          'icon': 'swap_horiz',
          'budgetAmount': null,
          'defaultPaymentMethod': PaymentMethod.transfer.name,
          'isFixed': false,
        });
      }

      return (expenseId: outRef.id, incomeId: inRef.id);
    });

    return snap;
  }

  Future<String> ensureInstallmentsCategory(String uid) async {
    final col = _db.collection('users').doc(uid).collection('categories');
    final ref = col.doc('fixed_installments');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'name': 'Cuotas fijas',
          'type': CategoryType.expense.name,
          'colorHex': 'FF5B4FE8',
          'icon': 'credit_card',
          'budgetAmount': null,
          'defaultPaymentMethod': PaymentMethod.card.name,
          'isFixed': true,
        });
      }
    });

    return ref.id;
  }

  Future<void> addTransactionsBatch(
      String uid, List<TransactionRecord> transactions) async {
    if (transactions.isEmpty) return;
    final col = _db.collection('users').doc(uid).collection('transactions');
    final batch = _db.batch();
    for (final tx in transactions) {
      batch.set(col.doc(), tx.toMap());
    }
    await batch.commit();
  }

  // ─── SCREEN STATE (UI Persistence) ──────────────────────────────────────────

  Future<Map<String, dynamic>> getScreenState(
      String uid, String screenId) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('screen_state')
        .doc(screenId)
        .get();
    return doc.data() ?? {};
  }

  Future<void> saveScreenState(
      String uid, String screenId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('screen_state')
        .doc(screenId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> deleteTransferGroup(String uid, String groupId) async {
    final col = _db.collection('users').doc(uid).collection('transactions');
    final snap = await col
        .where('transferGroupId', isEqualTo: groupId)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> updateTransferGroup({
    required String uid,
    required String groupId,
    required String sourceAccountId,
    required String destAccountId,
    required double amount,
    required DateTime date,
    required String note,
  }) async {
    final col = _db.collection('users').doc(uid).collection('transactions');
    final snap = await col
        .where('transferGroupId', isEqualTo: groupId)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      final data = doc.data();
      final type = data['type'] as String? ?? 'expense';
      final isExpense = type == TransactionType.expense.name;
      batch.update(doc.reference, {
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'note': note,
        'paymentMethod': PaymentMethod.transfer.name,
        'isTransfer': true,
        'transferAccountId': isExpense ? destAccountId : sourceAccountId,
        'accountId': isExpense ? sourceAccountId : destAccountId,
      });
    }
    await batch.commit();
  }

  Future<String> addPeriod(String uid, Period period) async {
    final ref = await _db
        .collection('users')
        .doc(uid)
        .collection('periods')
        .add(period.toMap());
    return ref.id;
  }

  Future<void> updatePeriod(String uid, String periodId,
      Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('periods')
        .doc(periodId)
        .update(data);
  }

  Future<void> deletePeriod(String uid, String periodId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('periods')
        .doc(periodId)
        .delete();
  }

  Future<void> setActivePeriod(String uid, String periodId) async {
    final col = _db.collection('users').doc(uid).collection('periods');
    final snap = await col.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'isActive': doc.id == periodId,
      });
    }
    await batch.commit();
  }

  Future<void> addFuelRecord(
      String uid, String vehicleId, FuelRecord record) async {
    final vehicleRef = _db
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .doc(vehicleId);

    final batch = _db.batch();
    final fuelRef = vehicleRef.collection('fuel_records').doc();
    batch.set(fuelRef, record.toMap());
    // Actualizar odómetro del vehículo
    batch.update(vehicleRef, {'odometer': record.odometerAtFill});
    await batch.commit();
  }

  Future<void> addVehicle(String uid, Vehicle vehicle) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .add(vehicle.toMap());
  }

  Future<void> updateVehicle(
      String uid, String vehicleId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .doc(vehicleId)
        .update(data);
  }

  Future<void> resetUserData(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    // Delete nested fuel records first.
    final vehiclesSnap = await userRef.collection('vehicles').get();
    for (final vehicleDoc in vehiclesSnap.docs) {
      await _deleteCollectionInBatches(vehicleDoc.reference.collection('fuel_records'));
    }

    // Delete user subcollections.
    await _deleteCollectionInBatches(userRef.collection('transactions'));
    await _deleteCollectionInBatches(userRef.collection('accounts'));
    await _deleteCollectionInBatches(userRef.collection('categories'));
    await _deleteCollectionInBatches(userRef.collection('periods'));
    await _deleteCollectionInBatches(userRef.collection('vehicles'));

    // Keep profile document, but reset preferences marker/seed flags.
    await userRef.set({
      'preferences': const <String, dynamic>{},
      'seeded': false,
    }, SetOptions(merge: true));
  }

  Future<void> _deleteCollectionInBatches(
      CollectionReference<Map<String, dynamic>> col) async {
    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> updatePeriodBudgets(
      String uid, String periodId, Map<String, double> budgets) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('periods')
        .doc(periodId)
        .update({'budgets': budgets});
  }

  Future<void> updateUserPreferences(
      String uid, Map<String, dynamic> data) async {
    final updates = <String, dynamic>{};
    data.forEach((key, value) {
      updates['preferences.$key'] = value;
    });
    await _db
        .collection('users')
        .doc(uid)
        .update(updates);
  }
}
