import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de cuenta soportados en Wallet
enum AccountType {
  cash('cash'),
  bank('bank'),
  creditCard('credit_card'),
  savings('savings'),
  investment('investment');

  final String value;
  const AccountType(this.value);

  static AccountType fromString(String? val) {
    return AccountType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => AccountType.bank,
    );
  }
}

/// Entidad de Dominio: AccountEntity (Clean Architecture - Domain Layer)
class AccountEntity {
  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final double currentBalance;
  final String currency;
  final String colorHex;
  final String iconName;
  final String subtitle;
  // Tarjetas de crédito
  final double? creditLimit;
  final double? currentDebt;
  final double? availableCredit;
  final int? cutoffDay;
  final int? paymentDay;
  final double? minimumPayment;
  final double? interestRate;
  final int? installments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currentBalance,
    required this.currency,
    required this.colorHex,
    required this.iconName,
    required this.subtitle,
    this.creditLimit,
    this.currentDebt,
    this.availableCredit,
    this.cutoffDay,
    this.paymentDay,
    this.minimumPayment,
    this.interestRate,
    this.installments,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Alias para compatibilidad con widgets que leen [balance] o [currentBalance]
  double get balance => currentBalance;
  bool get isNegative => currentBalance < 0;
  bool get isCreditCard => type == AccountType.creditCard;
  bool get isCash => type == AccountType.cash;

  AccountEntity copyWith({
    String? id,
    String? userId,
    String? name,
    AccountType? type,
    double? currentBalance,
    String? currency,
    String? colorHex,
    String? iconName,
    String? subtitle,
    double? creditLimit,
    double? currentDebt,
    double? availableCredit,
    int? cutoffDay,
    int? paymentDay,
    double? minimumPayment,
    double? interestRate,
    int? installments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      currentBalance: currentBalance ?? this.currentBalance,
      currency: currency ?? this.currency,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      subtitle: subtitle ?? this.subtitle,
      creditLimit: creditLimit ?? this.creditLimit,
      currentDebt: currentDebt ?? this.currentDebt,
      availableCredit: availableCredit ?? this.availableCredit,
      cutoffDay: cutoffDay ?? this.cutoffDay,
      paymentDay: paymentDay ?? this.paymentDay,
      minimumPayment: minimumPayment ?? this.minimumPayment,
      interestRate: interestRate ?? this.interestRate,
      installments: installments ?? this.installments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Modelo de Datos: AccountModel (Clean Architecture - Data Layer)
/// Subcolección Firestore: /users/{userId}/accounts/{accountId}
class AccountModel extends AccountEntity {
  const AccountModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.type,
    required super.currentBalance,
    required super.currency,
    required super.colorHex,
    required super.iconName,
    required super.subtitle,
    super.creditLimit,
    super.currentDebt,
    super.availableCredit,
    super.cutoffDay,
    super.paymentDay,
    super.minimumPayment,
    super.interestRate,
    super.installments,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AccountModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    if (data == null) {
      throw StateError('El documento de cuenta ${doc.id} está vacío');
    }

    final createdTs = data['createdAt'];
    final updatedTs = data['updatedAt'];
    final rawBalance = data['currentBalance'] ?? data['balance'] ?? 0.0;

    return AccountModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      name: (data['name'] as String?) ?? 'Cuenta',
      type: AccountType.fromString(data['type'] as String?),
      currentBalance: (rawBalance as num).toDouble(),
      currency: (data['currency'] as String?) ?? 'GTQ',
      colorHex: (data['colorHex'] as String?) ?? '#00DCF5',
      iconName: (data['iconName'] as String?) ?? 'payments',
      subtitle: (data['subtitle'] as String?) ?? 'SALDO DISPONIBLE',
      creditLimit: (data['creditLimit'] as num?)?.toDouble(),
      currentDebt: (data['currentDebt'] as num?)?.toDouble(),
      availableCredit: (data['availableCredit'] as num?)?.toDouble(),
      cutoffDay: (data['cutoffDay'] as num?)?.toInt(),
      paymentDay: (data['paymentDay'] as num?)?.toInt(),
      minimumPayment: (data['minimumPayment'] as num?)?.toDouble(),
      interestRate: (data['interestRate'] as num?)?.toDouble(),
      installments: (data['installments'] as num?)?.toInt(),
      createdAt: createdTs is Timestamp ? createdTs.toDate() : DateTime.now(),
      updatedAt: updatedTs is Timestamp ? updatedTs.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore({bool isNew = false}) {
    return {
      'userId': userId,
      'name': name.length > 80 ? name.substring(0, 80) : name,
      'type': type.value,
      'currentBalance': currentBalance,
      'balance': currentBalance,
      'currency': currency,
      'colorHex': colorHex,
      'iconName': iconName,
      'subtitle': subtitle.length > 100 ? subtitle.substring(0, 100) : subtitle,
      if (creditLimit != null) 'creditLimit': creditLimit,
      if (currentDebt != null) 'currentDebt': currentDebt,
      if (availableCredit != null) 'availableCredit': availableCredit,
      if (cutoffDay != null) 'cutoffDay': cutoffDay,
      if (paymentDay != null) 'paymentDay': paymentDay,
      if (minimumPayment != null) 'minimumPayment': minimumPayment,
      if (interestRate != null) 'interestRate': interestRate,
      if (installments != null) 'installments': installments,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
