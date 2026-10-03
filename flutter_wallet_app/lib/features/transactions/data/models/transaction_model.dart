import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de transacción soportados en Wallet
enum TransactionType {
  income('income'),
  expense('expense'),
  transfer('transfer');

  final String value;
  const TransactionType(this.value);

  static TransactionType fromString(String? val) {
    return TransactionType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => TransactionType.expense,
    );
  }
}

/// Entidad de Dominio: TransactionEntity (Clean Architecture - Domain Layer)
class TransactionEntity {
  final String id;
  final String userId;
  final String accountId;
  final String accountName;
  final String?
  toAccountId; // Cuenta destino cuando type == TransactionType.transfer
  final String? toAccountName; // Nombre de la cuenta destino en transferencias
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final String? subcategory; // Subcategoría desplegable seleccionada
  final TransactionType type;
  final double amount;
  final String currency;
  final String note;
  final DateTime date;
  final String yearMonth; // Identificador de período o año-mes
  final String
  periodId; // ID del resumen financiero dinámico (ej. 'period_2026_11')
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionEntity({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.accountName,
    this.toAccountId,
    this.toAccountName,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    this.subcategory,
    required this.type,
    required this.amount,
    required this.currency,
    required this.note,
    required this.date,
    required this.yearMonth,
    required this.periodId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;
  bool get isTransfer => type == TransactionType.transfer;
  double get signedAmount => isIncome ? amount.abs() : -amount.abs();

  /// Impacto sobre la cuenta de origen (`accountId`):
  /// - Ingreso: +amount
  /// - Gasto o Transferencia (salida): -amount
  double get originSignedDelta => isIncome ? amount.abs() : -amount.abs();
}

/// Modelo de Datos: TransactionModel (Clean Architecture - Data Layer)
/// Subcolección Firestore: /users/{userId}/transactions/{transactionId}
class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.userId,
    required super.accountId,
    required super.accountName,
    super.toAccountId,
    super.toAccountName,
    required super.categoryId,
    required super.categoryName,
    required super.categoryIcon,
    required super.categoryColor,
    super.subcategory,
    required super.type,
    required super.amount,
    required super.currency,
    required super.note,
    required super.date,
    required super.yearMonth,
    required super.periodId,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Construye un [TransactionModel] desde un DocumentSnapshot de Cloud Firestore
  factory TransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    if (data == null) {
      throw StateError('El documento de transacción ${doc.id} está vacío');
    }

    final parsedDate =
        DateTime.tryParse((data['dateIso'] as String?) ?? '') ??
        (data['date'] is Timestamp
            ? (data['date'] as Timestamp).toDate()
            : DateTime.now());

    final createdTs = data['createdAt'];
    final updatedTs = data['updatedAt'];
    final fallbackYm =
        '${parsedDate.year}_${parsedDate.month.toString().padLeft(2, '0')}';
    final ym = (data['yearMonth'] as String?) ?? fallbackYm;
    final pid =
        (data['periodId'] as String?) ??
        (ym.startsWith('period_') ? ym : 'period_${ym.replaceAll('-', '_')}');

    return TransactionModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      accountId: (data['accountId'] as String?) ?? '',
      accountName: (data['accountName'] as String?) ?? 'Efectivo',
      toAccountId: data['toAccountId'] as String?,
      toAccountName: data['toAccountName'] as String?,
      categoryId: (data['categoryId'] as String?) ?? 'cat_comida',
      categoryName: (data['categoryName'] as String?) ?? 'Comida y Bebida',
      categoryIcon: (data['categoryIcon'] as String?) ?? 'utensils',
      categoryColor: (data['categoryColor'] as String?) ?? '#00E676',
      subcategory: data['subcategory'] as String?,
      type: TransactionType.fromString(data['type'] as String?),
      amount: ((data['amount'] as num?)?.toDouble() ?? 0.0).abs(),
      currency: (data['currency'] as String?) ?? 'GTQ',
      note: (data['note'] as String?) ?? '',
      date: parsedDate,
      yearMonth: ym,
      periodId: pid,
      createdAt: createdTs is Timestamp ? createdTs.toDate() : DateTime.now(),
      updatedAt: updatedTs is Timestamp ? updatedTs.toDate() : DateTime.now(),
    );
  }

  /// Convierte el [TransactionModel] a un Map validado por firestore.rules
  Map<String, dynamic> toFirestore({bool isNew = false}) {
    final safeNote = note.trim().isEmpty
        ? '$categoryName · $accountName'
        : (note.length > 200 ? note.substring(0, 200) : note);

    return {
      'userId': userId,
      'accountId': accountId,
      'accountName': accountName.length > 80
          ? accountName.substring(0, 80)
          : accountName,
      if (toAccountId != null && toAccountId!.isNotEmpty)
        'toAccountId': toAccountId,
      if (toAccountName != null && toAccountName!.isNotEmpty)
        'toAccountName': toAccountName!.length > 80
            ? toAccountName!.substring(0, 80)
            : toAccountName,
      'categoryId': categoryId,
      'categoryName': categoryName.length > 80
          ? categoryName.substring(0, 80)
          : categoryName,
      'categoryIcon': categoryIcon,
      'categoryColor': categoryColor,
      if (subcategory != null && subcategory!.isNotEmpty)
        'subcategory': subcategory!.length > 80
            ? subcategory!.substring(0, 80)
            : subcategory,
      'type': type.value,
      'amount': amount.abs(),
      'currency': currency,
      'note': safeNote,
      'dateIso': date.toUtc().toIso8601String(),
      'yearMonth': yearMonth,
      'periodId': periodId,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TransactionModel copyWith({
    String? accountId,
    String? accountName,
    String? toAccountId,
    String? toAccountName,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    String? subcategory,
    TransactionType? type,
    double? amount,
    String? currency,
    String? note,
    DateTime? date,
    String? yearMonth,
    String? periodId,
  }) {
    return TransactionModel(
      id: id,
      userId: userId,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      toAccountId: toAccountId ?? this.toAccountId,
      toAccountName: toAccountName ?? this.toAccountName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      subcategory: subcategory ?? this.subcategory,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      note: note ?? this.note,
      date: date ?? this.date,
      yearMonth: yearMonth ?? this.yearMonth,
      periodId: periodId ?? this.periodId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
