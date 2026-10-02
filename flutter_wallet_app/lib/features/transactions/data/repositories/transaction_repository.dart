import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/utils/financial_period_helper.dart';
import '../models/transaction_model.dart';

/// Contrato del Repositorio de Transacciones (Domain Layer)
abstract class ITransactionRepository {
  /// Escucha en tiempo real las transacciones del usuario (/users/{userId}/transactions)
  Stream<List<TransactionModel>> watchUserTransactions({
    required String userId,
    String? periodId,
    int limit = 100,
  });

  /// 1, 2 y 3. Guarda una transacción (Gasto, Ingreso o Transferencia) mediante `runTransaction`:
  /// - Gasto (Expense): Resta `amount` a `currentBalance` de `accountId` y suma a `totalExpense` en `/summaries/{periodId}`.
  /// - Ingreso (Income): Suma `amount` a `currentBalance` de `accountId` y suma a `totalIncome` en `/summaries/{periodId}`.
  /// - Transferencia (Transfer): Resta `amount` a `accountId` (origen) y SUMA `amount` a `toAccountId` (destino) en el MISMO bloque atómico.
  Future<void> saveTransactionWithRunTransaction({
    required TransactionModel transaction,
    FinancialPeriodHelper periodHelper = const FinancialPeriodHelper(),
  });

  /// 4. Edición Atómica: Calcula la diferencia matemática exacta entre la transacción original
  /// y la transacción editada (incluyendo cambios de monto, tipo, cuenta origen/destino o fecha/período)
  /// y cuadra `currentBalance` en todas las cuentas implicadas sin descuadres.
  Future<void> updateTransactionAtomic({
    required TransactionModel originalTx,
    required TransactionModel updatedTx,
    FinancialPeriodHelper periodHelper = const FinancialPeriodHelper(),
  });

  /// 4. Eliminación Atómica: Revierte matemáticamente el impacto de la transacción eliminada
  /// sobre `currentBalance` de la cuenta origen (y cuenta destino si era transferencia) y sobre `/summaries/{periodId}`.
  Future<void> deleteTransactionAtomic(TransactionModel transaction);
}

/// Implementación en Cloud Firestore: TransactionRepository
class TransactionRepository implements ITransactionRepository {
  final FirebaseFirestore _firestore;

  const TransactionRepository(this._firestore);

  CollectionReference<TransactionModel> _transactionsRef(String userId) {
    return _firestore
        .collection(FirestorePaths.transactions(userId))
        .withConverter<TransactionModel>(
          fromFirestore: TransactionModel.fromFirestore,
          toFirestore: (TransactionModel tx, _) => tx.toFirestore(),
        );
  }

  @override
  Stream<List<TransactionModel>> watchUserTransactions({
    required String userId,
    String? periodId,
    int limit = 100,
  }) {
    if (userId.isEmpty) return const Stream.empty();

    Query<TransactionModel> query =
        _transactionsRef(userId).where('userId', isEqualTo: userId);

    if (periodId != null && periodId.isNotEmpty) {
      query = query.where('periodId', isEqualTo: periodId);
    }

    return query
        .orderBy('dateIso', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Helper interno: Acumula deltas de saldo por `accountId` en un mapa en memoria
  /// para aplicar una sola escritura consolidada por cuenta dentro de `runTransaction`.
  void _accumulateAccountDelta(
    Map<String, double> accountDeltas,
    TransactionModel tx, {
    required double multiplier, // +1.0 para aplicar, -1.0 para revertir
  }) {
    final double amt = tx.amount.abs() * multiplier;

    if (tx.type == TransactionType.income) {
      // Ingreso: suma a cuenta origen
      accountDeltas[tx.accountId] = (accountDeltas[tx.accountId] ?? 0.0) + amt;
    } else if (tx.type == TransactionType.expense) {
      // Gasto: resta a cuenta origen
      accountDeltas[tx.accountId] = (accountDeltas[tx.accountId] ?? 0.0) - amt;
    } else if (tx.type == TransactionType.transfer) {
      // Transferencia: resta a cuenta origen y suma a cuenta destino
      accountDeltas[tx.accountId] = (accountDeltas[tx.accountId] ?? 0.0) - amt;
      if (tx.toAccountId != null && tx.toAccountId!.isNotEmpty) {
        accountDeltas[tx.toAccountId!] =
            (accountDeltas[tx.toAccountId!] ?? 0.0) + amt;
      }
    }
  }

  @override
  Future<void> saveTransactionWithRunTransaction({
    required TransactionModel transaction,
    FinancialPeriodHelper periodHelper = const FinancialPeriodHelper(),
  }) async {
    final String userId = transaction.userId;
    if (userId.isEmpty) {
      throw ArgumentError('El userId no puede estar vacío');
    }

    if (transaction.type == TransactionType.transfer &&
        (transaction.toAccountId == null ||
            transaction.toAccountId!.isEmpty ||
            transaction.toAccountId == transaction.accountId)) {
      throw ArgumentError(
        'Para una transferencia debes especificar una cuenta destino (toAccountId) distinta a la cuenta de origen.',
      );
    }

    // Calculamos el periodId dinámico según la configuración del ciclo financiero (ej. "period_2026_11")
    final String computedPeriodId =
        periodHelper.getFirestorePeriodId(transaction.date);
    final TransactionModel normalizedTx = transaction.copyWith(
      yearMonth: computedPeriodId,
      periodId: computedPeriodId,
    );

    final DocumentReference<Map<String, dynamic>> txDocRef = _firestore.doc(
      FirestorePaths.transactionDoc(userId, normalizedTx.id),
    );
    final DocumentReference<Map<String, dynamic>> summaryDocRef = _firestore.doc(
      FirestorePaths.summaryDoc(userId, computedPeriodId),
    );

    // Determinamos las cuentas afectadas (1 cuenta para Ingreso/Gasto, 2 cuentas para Transferencia)
    final Map<String, double> accountDeltas = {};
    _accumulateAccountDelta(accountDeltas, normalizedTx, multiplier: 1.0);

    await _firestore.runTransaction((Transaction firestoreTx) async {
      // =======================================================================
      // FASE 1: LECTURAS ATÓMICAS (Todas las lecturas antes de cualquier escritura)
      // =======================================================================
      final Map<String, DocumentSnapshot<Map<String, dynamic>>> accountSnaps =
          {};
      for (final accId in accountDeltas.keys) {
        final accRef = _firestore.doc(FirestorePaths.accountDoc(userId, accId));
        final snap = await firestoreTx.get(accRef);
        if (!snap.exists) {
          throw StateError('La cuenta ($accId) no existe en /accounts');
        }
        accountSnaps[accId] = snap;
      }

      final DocumentSnapshot<Map<String, dynamic>> summarySnap =
          await firestoreTx.get(summaryDocRef);

      // =======================================================================
      // FASE 2: ESCRITURA DE LA TRANSACCIÓN Y CUADRE DE SALDOS EN /accounts
      // =======================================================================
      firestoreTx.set(txDocRef, normalizedTx.toFirestore(isNew: true));

      for (final entry in accountDeltas.entries) {
        final String accId = entry.key;
        final double delta = entry.value;
        final Map<String, dynamic> accData = accountSnaps[accId]!.data()!;
        final double previousBalance = ((accData['currentBalance'] ??
                    accData['balance'] ??
                    0.0) as num)
            .toDouble();
        final double updatedBalance =
            double.parse((previousBalance + delta).toStringAsFixed(2));

        final accRef = _firestore.doc(FirestorePaths.accountDoc(userId, accId));
        firestoreTx.update(accRef, {
          'currentBalance': updatedBalance,
          'balance': updatedBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // =======================================================================
      // FASE 3: ACTUALIZACIÓN DEL RESUMEN DEL PERÍODO (/summaries/{periodId})
      // =======================================================================
      final double incomeDelta = normalizedTx.type == TransactionType.income
          ? normalizedTx.amount.abs()
          : 0.0;
      final double expenseDelta = normalizedTx.type == TransactionType.expense
          ? normalizedTx.amount.abs()
          : 0.0;

      double newTotalIncome = incomeDelta;
      double newTotalExpense = expenseDelta;

      if (summarySnap.exists && summarySnap.data() != null) {
        final sumData = summarySnap.data()!;
        final prevInc = ((sumData['totalIncome'] ?? 0.0) as num).toDouble();
        final prevExp = ((sumData['totalExpense'] ?? 0.0) as num).toDouble();
        newTotalIncome =
            double.parse((prevInc + incomeDelta).toStringAsFixed(2));
        newTotalExpense =
            double.parse((prevExp + expenseDelta).toStringAsFixed(2));
      }

      final double newNetCashFlow =
          double.parse((newTotalIncome - newTotalExpense).toStringAsFixed(2));
      final double newSavingsRate = newTotalIncome > 0
          ? double.parse(
              ((newNetCashFlow / newTotalIncome) * 100).toStringAsFixed(1),
            )
          : 0.0;

      if (summarySnap.exists) {
        firestoreTx.update(summaryDocRef, {
          'yearMonth': computedPeriodId,
          'periodId': computedPeriodId,
          'totalIncome': newTotalIncome,
          'totalExpense': newTotalExpense,
          'netCashFlow': newNetCashFlow,
          'savingsRate': newSavingsRate,
          'currency': normalizedTx.currency,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        firestoreTx.set(summaryDocRef, {
          'userId': userId,
          'yearMonth': computedPeriodId,
          'periodId': computedPeriodId,
          'totalIncome': newTotalIncome,
          'totalExpense': newTotalExpense,
          'netCashFlow': newNetCashFlow,
          'savingsRate': newSavingsRate,
          'currency': normalizedTx.currency,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Future<void> updateTransactionAtomic({
    required TransactionModel originalTx,
    required TransactionModel updatedTx,
    FinancialPeriodHelper periodHelper = const FinancialPeriodHelper(),
  }) async {
    final String userId = updatedTx.userId;
    final String newPeriodId =
        periodHelper.getFirestorePeriodId(updatedTx.date);
    final TransactionModel normalizedUpdated = updatedTx.copyWith(
      yearMonth: newPeriodId,
      periodId: newPeriodId,
    );

    // 1. Calculamos el delta neto sobre todas las cuentas implicadas (antiguas y nuevas)
    // Revertimos el impacto de `originalTx` (multiplier: -1.0) y aplicamos `normalizedUpdated` (multiplier: +1.0)
    final Map<String, double> accountDeltas = {};
    _accumulateAccountDelta(accountDeltas, originalTx, multiplier: -1.0);
    _accumulateAccountDelta(accountDeltas, normalizedUpdated, multiplier: 1.0);

    // Filtramos cuentas cuyo delta neto sea 0 para optimizar lecturas/escrituras
    accountDeltas.removeWhere((_, delta) => delta.abs() < 0.001);

    final DocumentReference<Map<String, dynamic>> txDocRef = _firestore.doc(
      FirestorePaths.transactionDoc(userId, normalizedUpdated.id),
    );
    final DocumentReference<Map<String, dynamic>> summaryDocRef = _firestore.doc(
      FirestorePaths.summaryDoc(userId, newPeriodId),
    );

    await _firestore.runTransaction((Transaction firestoreTx) async {
      // FASE 1: LECTURAS
      final Map<String, DocumentSnapshot<Map<String, dynamic>>> accountSnaps =
          {};
      for (final accId in accountDeltas.keys) {
        final accRef = _firestore.doc(FirestorePaths.accountDoc(userId, accId));
        final snap = await firestoreTx.get(accRef);
        if (snap.exists) {
          accountSnaps[accId] = snap;
        }
      }

      final summarySnap = await firestoreTx.get(summaryDocRef);

      // FASE 2: ACTUALIZACIÓN DEL DOCUMENTO EN /transactions
      firestoreTx.update(txDocRef, normalizedUpdated.toFirestore(isNew: false));

      // FASE 3: AJUSTE ATÓMICO DE `currentBalance` EN LAS CUENTAS IMPLICADAS
      for (final entry in accountDeltas.entries) {
        final snap = accountSnaps[entry.key];
        if (snap != null && snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final double currentBal =
              ((data['currentBalance'] ?? data['balance'] ?? 0.0) as num)
                  .toDouble();
          final double adjustedBal =
              double.parse((currentBal + entry.value).toStringAsFixed(2));

          firestoreTx.update(snap.reference, {
            'currentBalance': adjustedBal,
            'balance': adjustedBal,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // FASE 4: AJUSTE DEL RESUMEN DEL PERÍODO
      if (summarySnap.exists && summarySnap.data() != null) {
        final sumData = summarySnap.data()!;
        final double oldInc = originalTx.type == TransactionType.income
            ? originalTx.amount.abs()
            : 0.0;
        final double oldExp = originalTx.type == TransactionType.expense
            ? originalTx.amount.abs()
            : 0.0;
        final double newInc = normalizedUpdated.type == TransactionType.income
            ? normalizedUpdated.amount.abs()
            : 0.0;
        final double newExp = normalizedUpdated.type == TransactionType.expense
            ? normalizedUpdated.amount.abs()
            : 0.0;

        final double prevInc =
            ((sumData['totalIncome'] ?? 0.0) as num).toDouble();
        final double prevExp =
            ((sumData['totalExpense'] ?? 0.0) as num).toDouble();

        final double updatedInc = double.parse(
          (prevInc - oldInc + newInc).clamp(0.0, double.infinity).toStringAsFixed(2),
        );
        final double updatedExp = double.parse(
          (prevExp - oldExp + newExp).clamp(0.0, double.infinity).toStringAsFixed(2),
        );
        final double updatedNet =
            double.parse((updatedInc - updatedExp).toStringAsFixed(2));
        final double updatedRate = updatedInc > 0
            ? double.parse(((updatedNet / updatedInc) * 100).toStringAsFixed(1))
            : 0.0;

        firestoreTx.update(summaryDocRef, {
          'totalIncome': updatedInc,
          'totalExpense': updatedExp,
          'netCashFlow': updatedNet,
          'savingsRate': updatedRate,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Future<void> deleteTransactionAtomic(TransactionModel transaction) async {
    final String userId = transaction.userId;
    final txDocRef = _firestore.doc(
      FirestorePaths.transactionDoc(userId, transaction.id),
    );
    final summaryDocRef = _firestore.doc(
      FirestorePaths.summaryDoc(userId, transaction.periodId),
    );

    // Calculamos deltas inversos (-1.0) para revertir cuenta origen y cuenta destino (si era transferencia)
    final Map<String, double> accountDeltas = {};
    _accumulateAccountDelta(accountDeltas, transaction, multiplier: -1.0);

    await _firestore.runTransaction((Transaction firestoreTx) async {
      // 1. Lecturas atómicas primero
      final Map<String, DocumentSnapshot<Map<String, dynamic>>> accountSnaps =
          {};
      for (final accId in accountDeltas.keys) {
        final accRef = _firestore.doc(FirestorePaths.accountDoc(userId, accId));
        final snap = await firestoreTx.get(accRef);
        if (snap.exists) {
          accountSnaps[accId] = snap;
        }
      }
      final summarySnap = await firestoreTx.get(summaryDocRef);

      // 2. Revertir currentBalance en cada cuenta implicada
      for (final entry in accountDeltas.entries) {
        final snap = accountSnaps[entry.key];
        if (snap != null && snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final double currentBal =
              ((data['currentBalance'] ?? data['balance'] ?? 0.0) as num)
                  .toDouble();
          final double revertedBal =
              double.parse((currentBal + entry.value).toStringAsFixed(2));

          firestoreTx.update(snap.reference, {
            'currentBalance': revertedBal,
            'balance': revertedBal,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 3. Revertir impacto en el resumen del período (/summaries/{periodId})
      if (summarySnap.exists && summarySnap.data() != null) {
        final sumData = summarySnap.data()!;
        final double prevInc =
            ((sumData['totalIncome'] ?? 0.0) as num).toDouble();
        final double prevExp =
            ((sumData['totalExpense'] ?? 0.0) as num).toDouble();

        final double revInc = transaction.type == TransactionType.income
            ? (prevInc - transaction.amount.abs()).clamp(0.0, double.infinity)
            : prevInc;
        final double revExp = transaction.type == TransactionType.expense
            ? (prevExp - transaction.amount.abs()).clamp(0.0, double.infinity)
            : prevExp;
        final double revNet = double.parse((revInc - revExp).toStringAsFixed(2));
        final double revRate = revInc > 0
            ? double.parse(((revNet / revInc) * 100).toStringAsFixed(1))
            : 0.0;

        firestoreTx.update(summaryDocRef, {
          'totalIncome': double.parse(revInc.toStringAsFixed(2)),
          'totalExpense': double.parse(revExp.toStringAsFixed(2)),
          'netCashFlow': revNet,
          'savingsRate': revRate,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. Eliminar documento en /transactions
      firestoreTx.delete(txDocRef);
    });
  }
}
