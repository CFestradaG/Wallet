import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum AccountType { creditCard, cash, savings }
enum TransactionType { income, expense }
enum CategoryType { income, expense }
enum PaymentMethod { card, cash, transfer }
enum MovementFilterKind { all, income, expense, performance, transfer }
enum MovementSortOrder { newest, oldest }

// ─── ACCOUNT ────────────────────────────────────────────────────────────────

class Account {
  final String id;
  final String name;
  final String nickname;
  final AccountType type;
  final double? creditLimit;
  final int? cutDay;
  final int? paymentDay;
  final int? graceDays;
  final double currentDebt;
  final String bankName;
  final List<Installment> installments;
  final double minimumPaymentPercent;

  Account({
    required this.id,
    required this.name,
    this.nickname = '',
    required this.type,
    this.creditLimit,
    this.cutDay,
    this.paymentDay,
    this.graceDays,
    this.currentDebt = 0.0,
    this.bankName = '',
    this.installments = const [],
    this.minimumPaymentPercent = 0.05,
  });

  Account copyWith({
    String? name,
    String? nickname,
    AccountType? type,
    double? creditLimit,
    int? cutDay,
    int? paymentDay,
    int? graceDays,
    double? currentDebt,
    String? bankName,
    List<Installment>? installments,
    double? minimumPaymentPercent,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      type: type ?? this.type,
      creditLimit: creditLimit ?? this.creditLimit,
      cutDay: cutDay ?? this.cutDay,
      paymentDay: paymentDay ?? this.paymentDay,
      graceDays: graceDays ?? this.graceDays,
      currentDebt: currentDebt ?? this.currentDebt,
      bankName: bankName ?? this.bankName,
      installments: installments ?? this.installments,
      minimumPaymentPercent:
          minimumPaymentPercent ?? this.minimumPaymentPercent,
    );
  }

  factory Account.fromMap(String id, Map<String, dynamic> map) {
    final rawInstallments = map['installments'] as List<dynamic>? ?? [];
    return Account(
      id: id,
      name: map['name'] ?? '',
      nickname: map['nickname'] ?? '',
      type: AccountType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AccountType.cash,
      ),
      creditLimit: (map['creditLimit'] as num?)?.toDouble(),
      cutDay: map['cutDay'] as int?,
      paymentDay: map['paymentDay'] as int?,
      graceDays: map['graceDays'] as int?,
      currentDebt: (map['currentDebt'] as num?)?.toDouble() ?? 0.0,
      bankName: map['bankName'] ?? '',
      installments: rawInstallments
          .map((e) => Installment.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nickname': nickname,
      'type': type.name,
      'creditLimit': creditLimit,
      'cutDay': cutDay,
      'paymentDay': paymentDay,
      'graceDays': graceDays,
      'currentDebt': currentDebt,
      'bankName': bankName,
      'installments': installments.map((e) => e.toMap()).toList(),
    };
  }

  /// Días restantes hasta el próximo pago (basado en la fecha actual)
  int daysUntilPayment() {
    if (type != AccountType.creditCard || paymentDay == null) return 999;
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, paymentDay!);
    final nextMonth = DateTime(now.year, now.month + 1, paymentDay!);
    final target = now.isBefore(thisMonth) ? thisMonth : nextMonth;
    return target.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Total de cuotas fijas mensuales
  double get monthlyInstallmentsTotal =>
      installments.fold(0.0, (sum, i) => sum + i.monthlyAmount);

  /// Total del valor original de todas las cuotas
  double get installmentsTotalValue =>
      installments.fold(0.0, (sum, i) => sum + i.totalValue);

  /// Total del valor pendiente de todas las cuotas
  double get installmentsRemainingValue =>
      installments.fold(0.0, (sum, i) => sum + i.remainingValue);

  /// Total del valor ya pagado de todas las cuotas
  double get installmentsPaidValue =>
      installmentsTotalValue - installmentsRemainingValue;
}

// ─── INSTALLMENT ─────────────────────────────────────────────────────────────

class Installment {
  final String id;
  final String description;
  final double monthlyAmount;
  final int totalMonths;
  final int remainingMonths;
  final DateTime? startDate;

  Installment({
    this.id = '',
    required this.description,
    required this.monthlyAmount,
    required this.totalMonths,
    required this.remainingMonths,
    this.startDate,
  });

  factory Installment.fromMap(Map<String, dynamic> map) {
    return Installment(
      id: map['id'] ?? '',
      description: map['description'] ?? '',
      monthlyAmount: (map['monthlyAmount'] as num?)?.toDouble() ?? 0.0,
      totalMonths: map['totalMonths'] as int? ??
          (map['remainingMonths'] as int? ?? 0),
      remainingMonths: map['remainingMonths'] as int? ??
          (map['totalMonths'] as int? ?? 0),
      startDate: map['startDate'] is Timestamp
          ? (map['startDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'monthlyAmount': monthlyAmount,
        'totalMonths': totalMonths,
        'remainingMonths': remainingMonths,
        'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      };

  double get totalValue => monthlyAmount * totalMonths;
  double get remainingValue => monthlyAmount * remainingMonths;
  double get paidValue => totalValue - remainingValue;

  DateTime? get endDate {
    if (startDate == null || totalMonths <= 0) return null;
    final s = startDate!;
    return DateTime(s.year, s.month + totalMonths, s.day);
  }
}

// ─── CATEGORY ─────────────────────────────────────────────────────────────────

class Category {
  final String id;
  final String name;
  final CategoryType type;
  final String colorHex;
  final String icon;
  final String master; // categoría madre
  final double? budgetAmount;
  final PaymentMethod? defaultPaymentMethod;
  final bool isFixed;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.colorHex,
    this.icon = 'category',
    this.master = 'Otros',
    this.budgetAmount,
    this.defaultPaymentMethod,
    this.isFixed = false,
  });

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] ?? '',
      type: CategoryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CategoryType.expense,
      ),
      colorHex: map['colorHex'] ?? 'FF5B4FE8',
      icon: map['icon'] ?? 'category',
      master: _normalizeMaster(map['master'] ?? 'Otros'),
      budgetAmount: (map['budgetAmount'] as num?)?.toDouble(),
      defaultPaymentMethod: map['defaultPaymentMethod'] != null
          ? PaymentMethod.values.firstWhere(
              (e) => e.name == map['defaultPaymentMethod'],
              orElse: () => PaymentMethod.card,
            )
          : null,
      isFixed: map['isFixed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.name,
        'colorHex': colorHex,
        'icon': icon,
        'master': master,
        'budgetAmount': budgetAmount,
        'defaultPaymentMethod': defaultPaymentMethod?.name,
        'isFixed': isFixed,
      };

  static String _normalizeMaster(String raw) {
    switch (raw) {
      case 'Alimentacion':
        return 'Alimentación';
      case 'Educacion':
        return 'Educación';
      default:
        return raw;
    }
  }
}

// ─── USER PROFILE & PREFERENCES ──────────────────────────────────────────────

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String photoURL;
  final DateTime? createdAt;

  UserProfile({
    required this.uid,
    this.email = '',
    this.displayName = '',
    this.photoURL = '',
    this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        uid: map['uid'] ?? '',
        email: map['email'] ?? '',
        displayName: map['displayName'] ?? '',
        photoURL: map['photoURL'] ?? '',
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : null,
      );
}

class UserPreferences {
  final String themeMode; // system | light | dark
  final String currencySymbol; // e.g. Q, $, €
  final List<String> availableTags;

  const UserPreferences({
    this.themeMode = 'system',
    this.currencySymbol = 'Q',
    this.availableTags = const [],
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) => UserPreferences(
        themeMode: map['themeMode'] ?? 'system',
        currencySymbol: map['currencySymbol'] ?? 'Q',
        availableTags: List<String>.from(map['availableTags'] ?? []),
      );

  Map<String, dynamic> toMap() => {
        'themeMode': themeMode,
        'currencySymbol': currencySymbol,
        'availableTags': availableTags,
      };

  ThemeMode toThemeMode() {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  NumberFormat currencyFormat({int decimalDigits = 2}) =>
      NumberFormat.currency(symbol: currencySymbol, decimalDigits: decimalDigits);
}

// ─── PERIOD ───────────────────────────────────────────────────────────────────

class Period {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final List<Subperiod> subperiods;
  final Map<String, double> budgets;
  final bool isActive;

  Period({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.subperiods = const [],
    this.budgets = const {},
    this.isActive = true,
  });

  Period copyWithId(String newId) => Period(
        id: newId,
        name: name,
        startDate: startDate,
        endDate: endDate,
        subperiods: subperiods,
        budgets: budgets,
        isActive: isActive,
      );

  factory Period.fromMap(String id, Map<String, dynamic> map) {
    final rawSubs = map['subperiods'] as List<dynamic>? ?? [];
    return Period(
      id: id,
      name: map['name'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      subperiods: rawSubs
          .map((e) => Subperiod.fromMap(e as Map<String, dynamic>))
          .toList(),
      budgets: (map['budgets'] as Map?)?.cast<String, dynamic>().map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'subperiods': subperiods.map((e) => e.toMap()).toList(),
        'budgets': budgets,
        'isActive': isActive,
      };
}

class Subperiod {
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  Subperiod({
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  factory Subperiod.fromMap(Map<String, dynamic> map) => Subperiod(
        name: map['name'] ?? '',
        startDate: (map['startDate'] as Timestamp).toDate(),
        endDate: (map['endDate'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
      };
}

// ─── TRANSACTION ──────────────────────────────────────────────────────────────

class TransactionRecord {
  final String id;
  final double amount;
  final TransactionType type;
  final String accountId;
  final String categoryId;
  final String periodId;
  final DateTime date;
  final String note;
  final PaymentMethod paymentMethod;
  final bool isTransfer;
  final String? transferAccountId;
  final String? transferGroupId;
  final bool isInstallment;
  final String? installmentId;
  final String? linkedPerformanceId;
  final List<String> tags;

  TransactionRecord({
    required this.id,
    required this.amount,
    required this.type,
    required this.accountId,
    required this.categoryId,
    required this.periodId,
    required this.date,
    this.note = '',
    this.paymentMethod = PaymentMethod.card,
    this.isTransfer = false,
    this.transferAccountId,
    this.transferGroupId,
    this.isInstallment = false,
    this.installmentId,
    this.linkedPerformanceId,
    this.tags = const [],
  });

  factory TransactionRecord.fromMap(String id, Map<String, dynamic> map) {
    return TransactionRecord(
      id: id,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      accountId: map['accountId'] ?? '',
      categoryId: map['categoryId'] ?? '',
      periodId: map['periodId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'] ?? '',
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['paymentMethod'],
        orElse: () => PaymentMethod.card,
      ),
      isTransfer: map['isTransfer'] as bool? ?? false,
      transferAccountId: map['transferAccountId'] as String?,
      transferGroupId: map['transferGroupId'] as String?,
      isInstallment: map['isInstallment'] as bool? ?? false,
      installmentId: map['installmentId'] as String?,
      linkedPerformanceId: map['linkedPerformanceId'] as String?,
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'type': type.name,
        'accountId': accountId,
        'categoryId': categoryId,
        'periodId': periodId,
        'date': Timestamp.fromDate(date),
        'note': note,
        'paymentMethod': paymentMethod.name,
        'isTransfer': isTransfer,
        'transferAccountId': transferAccountId,
        'transferGroupId': transferGroupId,
        'isInstallment': isInstallment,
        'installmentId': installmentId,
        'linkedPerformanceId': linkedPerformanceId,
        'tags': tags,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

// ─── VEHICLE ──────────────────────────────────────────────────────────────────

class Vehicle {
  final String id;
  final String name;
  final String type; // 'car' | 'motorcycle' | 'energy' | 'study'
  final String kind; // 'vehicle' | 'energy' | 'study'
  final String measureUnit; // 'km' | 'kWh' | 'cr'
  final double odometer; // medida actual (odómetro/energía/créditos)
  final String fuelBrand;
  final String? defaultCategoryId;

  Vehicle({
    required this.id,
    required this.name,
    required this.type,
    required this.kind,
    required this.measureUnit,
    this.odometer = 0.0,
    this.fuelBrand = '',
    this.defaultCategoryId,
  });

  factory Vehicle.fromMap(String id, Map<String, dynamic> map) {
    final rawType = map['type'] ?? 'car';
    final kind = map['kind'] ??
        (rawType == 'energy' || rawType == 'study' ? rawType : 'vehicle');
    final unit = map['measureUnit'] ?? _defaultUnitForKind(kind);
    return Vehicle(
      id: id,
      name: map['name'] ?? '',
      type: rawType,
      kind: kind,
      measureUnit: unit,
      odometer: (map['odometer'] as num?)?.toDouble() ?? 0.0,
      fuelBrand: map['fuelBrand'] ?? '',
      defaultCategoryId: map['defaultCategoryId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'kind': kind,
        'measureUnit': measureUnit,
        'odometer': odometer,
        'fuelBrand': fuelBrand,
        'defaultCategoryId': defaultCategoryId,
      };

  bool get isVehicle => kind == 'vehicle';

  static String _defaultUnitForKind(String kind) {
    switch (kind) {
      case 'energy':
        return 'kWh';
      case 'study':
        return 'cr';
      default:
        return 'km';
    }
  }
}

class FuelRecord {
  final String id;
  final String vehicleId;
  final DateTime date;
  final double liters; // cantidad (litros/galones)
  final double pricePerLiter; // precio por unidad
  final double odometerAtFill;
  final double? previousOdometer;
  final String stationName;
  final String unit; // 'L' | 'gal' | etc
  final String? accountId;
  final String? categoryId;
  final TransactionType? txType;
  final double? amount;

  FuelRecord({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.liters,
    required this.pricePerLiter,
    required this.odometerAtFill,
    this.previousOdometer,
    this.stationName = '',
    this.unit = 'L',
    this.accountId,
    this.categoryId,
    this.txType,
    this.amount,
  });

  double get totalCost => liters * pricePerLiter;

  double? get kmPerLiter {
    if (previousOdometer == null || liters == 0) return null;
    return (odometerAtFill - previousOdometer!) / liters;
  }

  factory FuelRecord.fromMap(String id, Map<String, dynamic> map) => FuelRecord(
        id: id,
        vehicleId: map['vehicleId'] ?? '',
        date: (map['date'] as Timestamp).toDate(),
        liters: (map['liters'] as num).toDouble(),
        pricePerLiter: (map['pricePerLiter'] as num).toDouble(),
        odometerAtFill: (map['odometerAtFill'] as num).toDouble(),
        previousOdometer: (map['previousOdometer'] as num?)?.toDouble(),
        stationName: map['stationName'] ?? '',
        unit: map['unit'] ?? 'L',
        accountId: map['accountId'] as String?,
        categoryId: map['categoryId'] as String?,
        txType: map['txType'] != null
            ? TransactionType.values.firstWhere(
                (e) => e.name == map['txType'],
                orElse: () => TransactionType.expense,
              )
            : null,
        amount: (map['amount'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'vehicleId': vehicleId,
        'date': Timestamp.fromDate(date),
        'liters': liters,
        'pricePerLiter': pricePerLiter,
        'odometerAtFill': odometerAtFill,
        'previousOdometer': previousOdometer,
        'stationName': stationName,
        'unit': unit,
        'accountId': accountId,
        'categoryId': categoryId,
        'txType': txType?.name,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
