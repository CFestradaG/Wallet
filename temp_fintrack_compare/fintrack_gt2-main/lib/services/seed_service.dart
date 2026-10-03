import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';

/// Seeds minimum per-user data only when missing.
/// - Standard categories are created only if user has no categories.
/// - Cash account is created only if user has no accounts.
/// - Vehicles/performance data are never auto-created.
class SeedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> seedIfNeeded(User user) async {
    final userDoc = _db.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();
    final exists = snapshot.exists;
    final alreadySeeded = (snapshot.data()?['seeded'] as bool?) ?? false;

    await userDoc.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (alreadySeeded) return;

    await _seedCategoriesIfEmpty(user.uid);
    await _seedCashAccountIfEmpty(user.uid);

    await userDoc.set({'seeded': true}, SetOptions(merge: true));
  }

  Future<void> _seedCashAccountIfEmpty(String uid) async {
    final col = _db.collection('users').doc(uid).collection('accounts');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final cashAccount = Account(
      id: 'efectivo',
      name: 'Efectivo',
      nickname: 'Cash',
      type: AccountType.cash,
      bankName: '',
      currentDebt: 0.0,
    );

    await col.doc(cashAccount.id).set(cashAccount.toMap());
  }

  Future<void> _seedCategoriesIfEmpty(String uid) async {
    final col = _db.collection('users').doc(uid).collection('categories');
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _db.batch();
    final categories = <Category>[
      _cat(
        'planilla',
        'Planilla / Sueldo',
        CategoryType.income,
        'FF4CAF50',
        'payments',
        11200.0,
        PaymentMethod.transfer,
        true,
        'Ingresos',
      ),
      _cat(
        'hipoteca',
        'Hipoteca',
        CategoryType.expense,
        'FF5B4FE8',
        'home',
        2997.0,
        PaymentMethod.transfer,
        true,
        'Hogar',
      ),
      _cat(
        'despensa',
        'Despensa + Carne',
        CategoryType.expense,
        'FF66BB6A',
        'shopping_cart',
        1300.0,
        PaymentMethod.card,
        false,
        'Alimentación',
      ),
      _cat(
        'transporte',
        'Transporte',
        CategoryType.expense,
        'FFEF5350',
        'directions_car',
        400.0,
        PaymentMethod.card,
        false,
        'Transporte',
      ),
      _cat(
        'servicios',
        'Servicios',
        CategoryType.expense,
        'FF29B6F6',
        'receipt_long',
        700.0,
        PaymentMethod.card,
        true,
        'Servicios',
      ),
      _cat(
        'ocio',
        'Ocio / Comida fuera',
        CategoryType.expense,
        'FFAB47BC',
        'restaurant',
        800.0,
        PaymentMethod.card,
        false,
        'Ocio',
      ),
      _cat(
        'ahorro',
        'Ahorro',
        CategoryType.expense,
        'FF00E5C3',
        'savings',
        600.0,
        PaymentMethod.transfer,
        false,
        'Finanzas',
      ),
    ];

    for (final category in categories) {
      batch.set(col.doc(category.id), category.toMap());
    }

    await batch.commit();
  }

  Category _cat(
    String id,
    String name,
    CategoryType type,
    String colorHex,
    String icon,
    double budget,
    PaymentMethod method,
    bool isFixed, [
    String master = 'Otros',
  ]) {
    return Category(
      id: id,
      name: name,
      type: type,
      colorHex: colorHex,
      icon: icon,
      master: master,
      budgetAmount: budget,
      defaultPaymentMethod: method,
      isFixed: isFixed,
    );
  }
}
