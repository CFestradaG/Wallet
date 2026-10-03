import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Presupuesto en Flutter Clean Architecture
/// Subcolección Firestore: /users/{userId}/budgets/{budgetId}
class BudgetModel {
  final String id;
  final String userId;
  final String name;
  final String categoryId;
  final double limitAmount;
  final double spentAmount;
  final String currency;
  final String period; // ej. 'period_2026_11'
  final String iconName;
  final String colorHex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.categoryId,
    required this.limitAmount,
    required this.spentAmount,
    required this.currency,
    required this.period,
    required this.iconName,
    required this.colorHex,
    required this.createdAt,
    required this.updatedAt,
  });

  double get percentage =>
      limitAmount > 0 ? (spentAmount / limitAmount).clamp(0.0, 1.0) : 0.0;

  /// Calcula el gasto real derivado directamente de las transacciones (Single Source of Truth)
  double calculateSpentFromTransactions(List<dynamic> transactions) {
    double total = 0.0;
    for (final tx in transactions) {
      final isExp = tx.isExpense ?? (tx.type == 'expense');
      final catId = tx.categoryId;
      if (isExp && catId == categoryId) {
        total += (tx.amount as num).toDouble();
      }
    }
    return total;
  }

  /// Porcentaje derivado directamente de las transacciones
  double calculatePercentage(List<dynamic> transactions) {
    if (limitAmount <= 0) return 0.0;
    final spent = calculateSpentFromTransactions(transactions);
    return (spent / limitAmount).clamp(0.0, 1.0);
  }

  factory BudgetModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdTs = data['createdAt'];
    final updatedTs = data['updatedAt'];

    return BudgetModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      categoryId: (data['categoryId'] as String?) ?? '',
      limitAmount: ((data['limitAmount'] as num?)?.toDouble() ?? 1000.0),
      spentAmount: ((data['spentAmount'] as num?)?.toDouble() ?? 0.0),
      currency: (data['currency'] as String?) ?? 'GTQ',
      period: (data['period'] as String?) ?? '',
      iconName: (data['iconName'] as String?) ?? 'shopping_cart',
      colorHex: (data['colorHex'] as String?) ?? '#00DCF5',
      createdAt: createdTs is Timestamp ? createdTs.toDate() : DateTime.now(),
      updatedAt: updatedTs is Timestamp ? updatedTs.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore({bool isNew = false}) {
    return {
      'userId': userId,
      'name': name.length > 80 ? name.substring(0, 80) : name,
      'categoryId': categoryId,
      'limitAmount': limitAmount,
      'spentAmount': spentAmount,
      'currency': currency,
      'period': period,
      'iconName': iconName,
      'colorHex': colorHex,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
