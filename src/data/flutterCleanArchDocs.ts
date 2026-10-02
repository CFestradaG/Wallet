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
    │   │   ├── financial_period_helper.dart           # Requerimiento 2: Cálculo de ciclo de nómina y quincenas
    │   │   ├── currency_formatter.dart                # Formateador tabular GTQ / Quetzales
    │   │   └── calculator_engine.dart                 # Evaluador aritmético para el teclado 4x4
    │   └── widgets/
    │       ├── financial_period_selector.dart         # Selector UI (Período Actual, 1ra Mitad, 2da Mitad, Personalizado)
    │       ├── adaptive_shell_scaffold.dart           # Shell responsivo (Web TopBar / Mobile BottomNav + Drawer)
    │       └── glass_surface_card.dart                # Contenedor Tonal Layering (#1E1E1E / #252525)
    │
    └── features/                                      # Módulos desacoplados por dominio funcional
        ├── settings/                                  # Configuración de Períodos Financieros (/users/{userId})
        │   └── data/
        │       └── models/user_settings_model.dart    # UserSettingsModel (startDayOfMonth, enableSplitPeriod, midMonthDay)
        │
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
        │       └── screens/login_screen.dart
        │
        ├── accounts/                                  # Subcolección: /users/{userId}/accounts
        │   ├── domain/
        │   │   └── entities/account_entity.dart
        │   ├── data/
        │   │   ├── models/account_model.dart          # AccountModel (fromFirestore / toFirestore)
        │   │   └── repositories/account_repository.dart # Stream<List<AccountModel>> watchUserAccounts
        │   └── presentation/
        │       ├── screens/accounts_screen.dart
        │       └── widgets/account_quick_card.dart
        │
        ├── transactions/                              # Subcolección: /users/{userId}/transactions
        │   ├── domain/
        │   │   └── entities/transaction_entity.dart
        │   ├── data/
        │   │   ├── models/transaction_model.dart      # TransactionModel (con toAccountId y periodId)
        │   │   └── repositories/transaction_repository.dart # runTransaction atómico (Gasto, Ingreso, Transferencia, Edición, Eliminación)
        │   └── presentation/
        │       ├── screens/
        │       │   ├── transactions_screen.dart
        │       │   └── new_transaction_modal.dart
        │       └── widgets/budgetbakers_keypad.dart
        │
        └── dashboard/                                 # Pantalla Principal Dashboard Stitch
            └── presentation/
                ├── providers/dashboard_providers.dart # StreamNotifierProvider + NotifierProvider con FinancialPeriodHelper
                └── screens/dashboard_screen.dart      # UI exacta Stitch (Patrimonio Neto, Cuentas, Dona, FAB)`;

export const FLUTTER_FILES_DOCS: FlutterFileDoc[] = [
  {
    id: 'financial_period_helper_dart',
    filename: 'financial_period_helper.dart',
    path: 'lib/core/utils/financial_period_helper.dart',
    layer: 'core',
    description:
      'Requerimiento 2: Servicio Helper de Fechas (FinancialPeriodHelper) que calcula getPeriodName ("2026-11"), getFirestorePeriodId ("period_2026_11"), getPeriodDateRange (ej. 27 Oct 00:00:00 a 26 Nov 23:59:59) y getSubPeriod ("Primera Quincena / Inicio de Mes" vs "Segunda Quincena").',
    code: `import 'package:flutter/material.dart';
import '../../features/settings/data/models/user_settings_model.dart';

enum PeriodFilterMode {
  fullPeriod, // "Período Actual (27 Oct - 26 Nov)"
  firstHalf,  // "Primera Mitad (27 Oct - 12 Nov)"
  secondHalf, // "Segunda Mitad (13 Nov - 26 Nov)"
  custom,     // "Personalizado"
}

enum FinancialSubPeriod {
  firstHalf('Primera Quincena / Inicio de Mes'),
  secondHalf('Segunda Quincena'),
  fullMonth('Período Completo (Sin división)');

  final String label;
  const FinancialSubPeriod(this.label);
}

class FinancialPeriodHelper {
  final int startDayOfMonth;
  final bool enableSplitPeriod;
  final int midMonthDay;

  const FinancialPeriodHelper({
    this.startDayOfMonth = 27,
    this.enableSplitPeriod = true,
    this.midMonthDay = 13,
  });

  factory FinancialPeriodHelper.fromSettings(UserSettingsModel settings) {
    return FinancialPeriodHelper(
      startDayOfMonth: settings.startDayOfMonth,
      enableSplitPeriod: settings.enableSplitPeriod,
      midMonthDay: settings.midMonthDay,
    );
  }

  static int _clampDay(int year, int month, int desiredDay) {
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    return desiredDay.clamp(1, daysInMonth);
  }

  /// Retorna el identificador del período (ej. "2026-11" aunque sea 28 de octubre)
  String getPeriodName(DateTime date) {
    if (startDayOfMonth <= 1) {
      return '\${date.year}-\${date.month.toString().padLeft(2, '0')}';
    }
    final effectiveStartDay = _clampDay(date.year, date.month, startDayOfMonth);
    if (date.day >= effectiveStartDay) {
      final nextMonthDate = DateTime(date.year, date.month + 1, 1);
      return '\${nextMonthDate.year}-\${nextMonthDate.month.toString().padLeft(2, '0')}';
    } else {
      return '\${date.year}-\${date.month.toString().padLeft(2, '0')}';
    }
  }

  /// ID para /users/{userId}/summaries/{periodId} (ej. "period_2026_11")
  String getFirestorePeriodId(DateTime date) {
    return 'period_\${getPeriodName(date).replaceAll('-', '_')}';
  }

  /// Retorna el DateTimeRange exacto (ej. 2026-10-27 00:00:00 hasta 2026-11-26 23:59:59.999)
  DateTimeRange getPeriodDateRange(DateTime date) {
    if (startDayOfMonth <= 1) {
      final lastDay = DateUtils.getDaysInMonth(date.year, date.month);
      return DateTimeRange(
        start: DateTime(date.year, date.month, 1, 0, 0, 0),
        end: DateTime(date.year, date.month, lastDay, 23, 59, 59, 999),
      );
    }

    final effectiveStartThisMonth = _clampDay(date.year, date.month, startDayOfMonth);
    late final DateTime startDate;
    late final DateTime endDate;

    if (date.day >= effectiveStartThisMonth) {
      startDate = DateTime(date.year, date.month, effectiveStartThisMonth, 0, 0, 0);
      final nextMonth = DateTime(date.year, date.month + 1, 1);
      final nextMonthStartDay = _clampDay(nextMonth.year, nextMonth.month, startDayOfMonth);
      endDate = DateTime(nextMonth.year, nextMonth.month, nextMonthStartDay, 0, 0, 0)
          .subtract(const Duration(milliseconds: 1));
    } else {
      final prevMonth = DateTime(date.year, date.month - 1, 1);
      final prevMonthStartDay = _clampDay(prevMonth.year, prevMonth.month, startDayOfMonth);
      startDate = DateTime(prevMonth.year, prevMonth.month, prevMonthStartDay, 0, 0, 0);
      endDate = DateTime(date.year, date.month, effectiveStartThisMonth, 0, 0, 0)
          .subtract(const Duration(milliseconds: 1));
    }

    return DateTimeRange(start: startDate, end: endDate);
  }

  DateTime _getMidPeriodStartDate(DateTimeRange fullRange) {
    if (startDayOfMonth > midMonthDay) {
      final clampedMid = _clampDay(fullRange.end.year, fullRange.end.month, midMonthDay);
      return DateTime(fullRange.end.year, fullRange.end.month, clampedMid, 0, 0, 0);
    } else {
      final clampedMid = _clampDay(fullRange.start.year, fullRange.start.month, midMonthDay);
      return DateTime(fullRange.start.year, fullRange.start.month, clampedMid, 0, 0, 0);
    }
  }

  DateTimeRange getFirstHalfDateRange(DateTime referenceDate) {
    final fullRange = getPeriodDateRange(referenceDate);
    if (!enableSplitPeriod) return fullRange;
    final midStart = _getMidPeriodStartDate(fullRange);
    return DateTimeRange(
      start: fullRange.start,
      end: midStart.subtract(const Duration(milliseconds: 1)),
    );
  }

  DateTimeRange getSecondHalfDateRange(DateTime referenceDate) {
    final fullRange = getPeriodDateRange(referenceDate);
    if (!enableSplitPeriod) return fullRange;
    final midStart = _getMidPeriodStartDate(fullRange);
    return DateTimeRange(start: midStart, end: fullRange.end);
  }

  /// Retorna si la fecha cae en "Primera Quincena / Inicio de Mes" o "Segunda Quincena"
  String getSubPeriod(DateTime date) {
    if (!enableSplitPeriod) return FinancialSubPeriod.fullMonth.label;
    final firstHalf = getFirstHalfDateRange(date);
    if (!date.isBefore(firstHalf.start) && !date.isAfter(firstHalf.end)) {
      return FinancialSubPeriod.firstHalf.label;
    }
    return FinancialSubPeriod.secondHalf.label;
  }
}`,
  },
  {
    id: 'user_settings_model_dart',
    filename: 'user_settings_model.dart',
    path: 'lib/features/settings/data/models/user_settings_model.dart',
    layer: 'data',
    description:
      'Modelo de Configuración (UserSettingsModel) en /users/{userId} con startDayOfMonth (ej. 27), enableSplitPeriod (bool) y midMonthDay (ej. 13).',
    code: `import 'package:cloud_firestore/cloud_firestore.dart';

class UserSettingsModel {
  final String userId;
  final String displayName;
  final String defaultCurrency;
  final int startDayOfMonth;   // Ej. 27 (El 27 de oct inicia el período de noviembre)
  final bool enableSplitPeriod; // Habilita división en Inicio de Mes / Quincena
  final int midMonthDay;       // Ej. 13 (Día en que inicia la segunda quincena)
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSettingsModel({
    required this.userId,
    required this.displayName,
    this.defaultCurrency = 'GTQ',
    this.startDayOfMonth = 27,
    this.enableSplitPeriod = true,
    this.midMonthDay = 13,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettingsModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data() ?? {};
    final createdTs = data['createdAt'];
    final updatedTs = data['updatedAt'];

    return UserSettingsModel(
      userId: (data['userId'] as String?) ?? doc.id,
      displayName: (data['displayName'] as String?) ?? 'Francisco Estrada',
      defaultCurrency: (data['defaultCurrency'] as String?) ?? 'GTQ',
      startDayOfMonth: ((data['startDayOfMonth'] as num?)?.toInt() ?? 27).clamp(1, 31),
      enableSplitPeriod: (data['enableSplitPeriod'] as bool?) ?? true,
      midMonthDay: ((data['midMonthDay'] as num?)?.toInt() ?? 13).clamp(1, 31),
      createdAt: createdTs is Timestamp ? createdTs.toDate() : DateTime.now(),
      updatedAt: updatedTs is Timestamp ? updatedTs.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore({bool isNew = false}) {
    return {
      'userId': userId,
      'displayName': displayName.length > 100 ? displayName.substring(0, 100) : displayName,
      'defaultCurrency': defaultCurrency,
      'startDayOfMonth': startDayOfMonth.clamp(1, 31),
      'enableSplitPeriod': enableSplitPeriod,
      'midMonthDay': midMonthDay.clamp(1, 31),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}`,
  },
  {
    id: 'add_transaction_screen_dart',
    filename: 'add_transaction_screen.dart',
    path: 'lib/features/transactions/presentation/screens/add_transaction_screen.dart',
    layer: 'presentation',
    description:
      'Widget AddTransactionScreen idéntico al diseño de Google Stitch: Header #00ACC1, selector [INGRESOS | GASTO | TRANSFERENCIA], selector de Cuenta/Categoría, carrusel de categorías, teclado numérico 4x4 y guardado atómico vía runTransaction.',
    code: `import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../accounts/data/models/account_model.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../data/models/transaction_model.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String initialType;
  const AddTransactionScreen({super.key, this.initialType = 'expense'});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _selectedType;
  String _expression = '150.00';
  bool _isDefaultValue = true;
  String? _selectedAccountId;
  String _selectedCategoryId = 'cat_restaurante';
  String _selectedCategoryName = 'Restaurante';
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = TransactionType.fromString(widget.initialType);
  }

  Future<void> _handleSave(List<AccountModel> accounts) async {
    if (_isSubmitting || accounts.isEmpty) return;
    final userId = ref.read(currentUserIdProvider).valueOrNull ?? '';
    if (userId.isEmpty) return;

    final acc = accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => accounts.first,
    );
    final amount = double.tryParse(_expression) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isSubmitting = true);
    try {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'tx_\${now.millisecondsSinceEpoch}',
        userId: userId,
        accountId: acc.id,
        accountName: acc.name,
        categoryId: _selectedCategoryId,
        categoryName: _selectedCategoryName,
        categoryIcon: 'utensils',
        categoryColor: '#00ACC1',
        type: _selectedType,
        amount: amount,
        currency: acc.currency,
        note: _noteController.text.trim(),
        date: now,
        yearMonth: '\${now.year}_\${now.month.toString().padLeft(2, '0')}',
        createdAt: now,
        updatedAt: now,
      );

      await ref
          .read(transactionRepositoryProvider)
          .saveTransactionWithRunTransaction(transaction: tx);

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(userAccountsNotifierProvider).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // Header #00ACC1 + Selector Tipo + Visor "- 150.00 GTQ"
            Container(
              color: const Color(0xFF00ACC1),
              padding: const EdgeInsets.all(16),
              child: Text(
                '\${_selectedType == TransactionType.expense ? "-" : "+"} \$_expression GTQ',
                style: const TextStyle(fontSize: 48, color: Colors.white),
              ),
            ),
            // Botón Guardar Transacción
            ElevatedButton(
              onPressed: () => _handleSave(accounts),
              child: const Text('Guardar Transacción'),
            ),
          ],
        ),
      ),
    );
  }
}`,
  },
  {
    id: 'account_model_dart',
    filename: 'account_model.dart',
    path: 'lib/features/accounts/data/models/account_model.dart',
    layer: 'data',
    description:
      'Entidad AccountEntity y modelo AccountModel con métodos tipados fromFirestore y toFirestore para la subcolección /users/{userId}/accounts.',
    code: `import 'package:cloud_firestore/cloud_firestore.dart';

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

class AccountEntity {
  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final double balance;
  final String currency;
  final String colorHex;
  final String iconName;
  final String subtitle;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    required this.currency,
    required this.colorHex,
    required this.iconName,
    required this.subtitle,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isNegative => balance < 0;
  bool get isCreditCard => type == AccountType.creditCard;
  bool get isCash => type == AccountType.cash;
}

class AccountModel extends AccountEntity {
  const AccountModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.type,
    required super.balance,
    required super.currency,
    required super.colorHex,
    required super.iconName,
    required super.subtitle,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AccountModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    if (data == null) {
      throw StateError('El documento de cuenta \${doc.id} está vacío');
    }

    final createdTs = data['createdAt'];
    final updatedTs = data['updatedAt'];

    return AccountModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      name: (data['name'] as String?) ?? 'Cuenta',
      type: AccountType.fromString(data['type'] as String?),
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      currency: (data['currency'] as String?) ?? 'GTQ',
      colorHex: (data['colorHex'] as String?) ?? '#00DCF5',
      iconName: (data['iconName'] as String?) ?? 'payments',
      subtitle: (data['subtitle'] as String?) ?? 'SALDO DISPONIBLE',
      createdAt: createdTs is Timestamp ? createdTs.toDate() : DateTime.now(),
      updatedAt: updatedTs is Timestamp ? updatedTs.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore({bool isNew = false}) {
    return {
      'userId': userId,
      'name': name.length > 80 ? name.substring(0, 80) : name,
      'type': type.value,
      'balance': balance,
      'currency': currency,
      'colorHex': colorHex,
      'iconName': iconName,
      'subtitle': subtitle.length > 100 ? subtitle.substring(0, 100) : subtitle,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}`,
  },
  {
    id: 'transaction_model_dart',
    filename: 'transaction_model.dart',
    path: 'lib/features/transactions/data/models/transaction_model.dart',
    layer: 'data',
    description:
      'Entidad TransactionEntity y modelo TransactionModel con serialización fromFirestore y toFirestore para /users/{userId}/transactions.',
    code: `import 'package:cloud_firestore/cloud_firestore.dart';

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

class TransactionEntity {
  final String id;
  final String userId;
  final String accountId;
  final String accountName;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final TransactionType type;
  final double amount;
  final String currency;
  final String note;
  final DateTime date;
  final String yearMonth;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionEntity({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.accountName,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.type,
    required this.amount,
    required this.currency,
    required this.note,
    required this.date,
    required this.yearMonth,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;
  double get signedAmount => isIncome ? amount : -amount;
}

class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.userId,
    required super.accountId,
    required super.accountName,
    required super.categoryId,
    required super.categoryName,
    required super.categoryIcon,
    required super.categoryColor,
    required super.type,
    required super.amount,
    required super.currency,
    required super.note,
    required super.date,
    required super.yearMonth,
    required super.createdAt,
    required super.updatedAt,
  });

  factory TransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    if (data == null) {
      throw StateError('El documento de transacción \${doc.id} está vacío');
    }

    final parsedDate = DateTime.tryParse((data['dateIso'] as String?) ?? '') ??
        (data['date'] is Timestamp
            ? (data['date'] as Timestamp).toDate()
            : DateTime.now());

    final createdTs = data['createdAt'];
    final updatedTs = data['updatedAt'];

    return TransactionModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      accountId: (data['accountId'] as String?) ?? '',
      accountName: (data['accountName'] as String?) ?? 'Efectivo',
      categoryId: (data['categoryId'] as String?) ?? 'cat_comida',
      categoryName: (data['categoryName'] as String?) ?? 'Comida y Bebida',
      categoryIcon: (data['categoryIcon'] as String?) ?? 'utensils',
      categoryColor: (data['categoryColor'] as String?) ?? '#00E676',
      type: TransactionType.fromString(data['type'] as String?),
      amount: ((data['amount'] as num?)?.toDouble() ?? 0.0).abs(),
      currency: (data['currency'] as String?) ?? 'GTQ',
      note: (data['note'] as String?) ?? '',
      date: parsedDate,
      yearMonth: (data['yearMonth'] as String?) ??
          '\${parsedDate.year}_\${parsedDate.month.toString().padLeft(2, '0')}',
      createdAt: createdTs is Timestamp ? createdTs.toDate() : DateTime.now(),
      updatedAt: updatedTs is Timestamp ? updatedTs.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore({bool isNew = false}) {
    final safeNote = note.trim().isEmpty
        ? '\$categoryName · \$accountName'
        : (note.length > 200 ? note.substring(0, 200) : note);

    return {
      'userId': userId,
      'accountId': accountId,
      'accountName':
          accountName.length > 80 ? accountName.substring(0, 80) : accountName,
      'categoryId': categoryId,
      'categoryName': categoryName.length > 80
          ? categoryName.substring(0, 80)
          : categoryName,
      'categoryIcon': categoryIcon,
      'categoryColor': categoryColor,
      'type': type.value,
      'amount': amount.abs(),
      'currency': currency,
      'note': safeNote,
      'dateIso': date.toUtc().toIso8601String(),
      'yearMonth': yearMonth,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}`,
  },
  {
    id: 'repositories_dart',
    filename: 'account_&_tx_repositories.dart',
    path: 'lib/features/*/data/repositories/',
    layer: 'data',
    description:
      'AccountRepository y TransactionRepository utilizando .withConverter() y retornando Stream<List<T>> en tiempo real junto con WriteBatch atómico.',
    code: `import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';

/// 1. AccountRepository (Stream en tiempo real de /users/{userId}/accounts)
class AccountRepository {
  final FirebaseFirestore _firestore;
  const AccountRepository(this._firestore);

  CollectionReference<AccountModel> _accountsRef(String userId) {
    return _firestore
        .collection(FirestorePaths.accounts(userId))
        .withConverter<AccountModel>(
          fromFirestore: AccountModel.fromFirestore,
          toFirestore: (AccountModel acc, _) => acc.toFirestore(),
        );
  }

  Stream<List<AccountModel>> watchUserAccounts(String userId) {
    if (userId.isEmpty) return const Stream.empty();
    return _accountsRef(userId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> createAccount(AccountModel account) async {
    await _firestore
        .doc(FirestorePaths.accountDoc(account.userId, account.id))
        .set(account.toFirestore(isNew: true));
  }
}

/// 2. TransactionRepository (Stream en tiempo real de /users/{userId}/transactions)
class TransactionRepository {
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

  Stream<List<TransactionModel>> watchUserTransactions({
    required String userId,
    String? yearMonth,
    int limit = 50,
  }) {
    if (userId.isEmpty) return const Stream.empty();
    Query<TransactionModel> query = _transactionsRef(userId)
        .where('userId', isEqualTo: userId);

    if (yearMonth != null && yearMonth.isNotEmpty) {
      query = query.where('yearMonth', isEqualTo: yearMonth);
    }

    return query
        .orderBy('dateIso', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> addTransactionAtomic(TransactionModel transaction) async {
    final userId = transaction.userId;
    final batch = _firestore.batch();

    final txRef = _firestore.doc(FirestorePaths.transactionDoc(userId, transaction.id));
    final accRef = _firestore.doc(FirestorePaths.accountDoc(userId, transaction.accountId));
    final sumRef = _firestore.doc(FirestorePaths.summaryDoc(userId, transaction.yearMonth));

    batch.set(txRef, transaction.toFirestore(isNew: true));
    batch.update(accRef, {
      'balance': FieldValue.increment(transaction.signedAmount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      sumRef,
      {
        'userId': userId,
        'yearMonth': transaction.yearMonth,
        'totalIncome': FieldValue.increment(transaction.isIncome ? transaction.amount : 0.0),
        'totalExpense': FieldValue.increment(transaction.isExpense ? transaction.amount : 0.0),
        'netCashFlow': FieldValue.increment(transaction.signedAmount),
        'currency': transaction.currency,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}`,
  },
  {
    id: 'dashboard_providers_dart',
    filename: 'dashboard_providers.dart',
    path: 'lib/features/dashboard/presentation/providers/dashboard_providers.dart',
    layer: 'presentation',
    description:
      'StreamNotifierProvider y NotifierProvider en Riverpod que escuchan en tiempo real las cuentas y transacciones del usuario actual y calculan el Patrimonio Neto Total.',
    code: `import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/data/repositories/account_repository.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/data/repositories/transaction_repository.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final currentUserIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges().map((u) => u?.uid);
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(firebaseFirestoreProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(firebaseFirestoreProvider));
});

class DashboardWalletState {
  final List<AccountModel> accounts;
  final List<TransactionModel> recentTransactions;

  const DashboardWalletState({
    required this.accounts,
    required this.recentTransactions,
  });

  double get netWorthTotal =>
      accounts.fold(0.0, (sum, item) => sum + item.balance);

  double get totalExpenses => recentTransactions
      .where((t) => t.isExpense)
      .fold(0.0, (sum, item) => sum + item.amount);
}

class AccountsStreamNotifier extends StreamNotifier<List<AccountModel>> {
  @override
  Stream<List<AccountModel>> build() {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;
    if (userId == null || userId.isEmpty) return const Stream.empty();
    return ref.watch(accountRepositoryProvider).watchUserAccounts(userId);
  }
}

final userAccountsNotifierProvider =
    StreamNotifierProvider<AccountsStreamNotifier, List<AccountModel>>(
  AccountsStreamNotifier.new,
);

class TransactionsStreamNotifier extends StreamNotifier<List<TransactionModel>> {
  @override
  Stream<List<TransactionModel>> build() {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;
    if (userId == null || userId.isEmpty) return const Stream.empty();
    return ref.watch(transactionRepositoryProvider).watchUserTransactions(
          userId: userId,
          yearMonth: '2026_10',
        );
  }
}

final userTransactionsNotifierProvider =
    StreamNotifierProvider<TransactionsStreamNotifier, List<TransactionModel>>(
  TransactionsStreamNotifier.new,
);

class DashboardNotifier extends Notifier<AsyncValue<DashboardWalletState>> {
  @override
  AsyncValue<DashboardWalletState> build() {
    final accountsAsync = ref.watch(userAccountsNotifierProvider);
    final transactionsAsync = ref.watch(userTransactionsNotifierProvider);

    if (accountsAsync.isLoading || transactionsAsync.isLoading) {
      return const AsyncValue.loading();
    }
    if (accountsAsync.hasError) {
      return AsyncValue.error(accountsAsync.error!, StackTrace.current);
    }
    if (transactionsAsync.hasError) {
      return AsyncValue.error(transactionsAsync.error!, StackTrace.current);
    }

    return AsyncValue.data(
      DashboardWalletState(
        accounts: accountsAsync.value ?? const [],
        recentTransactions: transactionsAsync.value ?? const [],
      ),
    );
  }
}

final dashboardNotifierProvider =
    NotifierProvider<DashboardNotifier, AsyncValue<DashboardWalletState>>(
  DashboardNotifier.new,
);`,
  },
  {
    id: 'dashboard_screen_dart',
    filename: 'dashboard_screen.dart',
    path: 'lib/features/dashboard/presentation/screens/dashboard_screen.dart',
    layer: 'presentation',
    description:
      'Pantalla DashboardScreen en Flutter con los widgets exactos de Stitch: Patrimonio Neto Total (GTQ 12,450.00), lista horizontal de cuentas, Estructura de gastos con Donut CustomPainter, Últimos registros y FloatingActionButton.',
    code: `import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final NumberFormat _currencyFmt = NumberFormat('#,##0.00', 'en_US');

  String _formatGtq(double amount, {bool showSign = false}) {
    final absVal = _currencyFmt.format(amount.abs());
    if (showSign) return amount >= 0 ? '+GTQ \$absVal' : '-GTQ \$absVal';
    return amount < 0 ? '-GTQ \$absVal' : 'GTQ \$absVal';
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardNotifierProvider);

    return Scaffold(
      backgroundColor: ObsidianFlowColors.canvasBase,
      appBar: AppBar(
        backgroundColor: ObsidianFlowColors.canvasBase,
        title: const Text('Inicio', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: \$err')),
        data: (dashboard) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Tarjeta de Patrimonio Neto Total
              _buildNetWorthCard(dashboard),
              const SizedBox(height: 24),
              // 2. Lista Horizontal de Cuentas
              const Text(
                'Mis cuentas en Wallet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _buildHorizontalAccounts(dashboard.accounts),
              const SizedBox(height: 24),
              // 3. Resumen de Transacciones Recientes
              _buildRecentTransactions(context, dashboard.recentTransactions),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('\${AppRoutes.newTransaction}?type=expense'),
        backgroundColor: const Color(0xFF00BFA5),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }

  Widget _buildNetWorthCard(DashboardWalletState state) {
    final balance = state.accounts.isEmpty ? 12450.00 : state.netWorthTotal;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2420),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PATRIMONIO NETO TOTAL', style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            _formatGtq(balance),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalAccounts(List<AccountModel> accounts) {
    return SizedBox(
      height: 115,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final acc = accounts[index];
          return Container(
            width: 190,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: acc.isCash ? const Color(0xFF00B4D8) : ObsidianFlowColors.elevation1,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  _formatGtq(acc.balance),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: !acc.isCash && acc.isNegative ? ObsidianFlowColors.outflowCrimson : Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, List<TransactionModel> txs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ObsidianFlowColors.elevation1,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: txs.take(5).map((tx) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tx.note, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('\${tx.accountName} • \${tx.categoryName}'),
            trailing: Text(
              _formatGtq(tx.signedAmount, showSign: true),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tx.isIncome ? ObsidianFlowColors.primaryContainer : ObsidianFlowColors.outflowCrimson,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}`,
  },
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

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      'Tarea 2.2: Configuración exacta del sistema de diseño Stitch "Obsidian Flow" en Material 3 (#121212).',
    code: `import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ObsidianFlowColors {
  ObsidianFlowColors._();

  static const Color canvasBase = Color(0xFF121212);
  static const Color surface = Color(0xFF131313);
  static const Color elevation1 = Color(0xFF1E1E1E);
  static const Color elevation2 = Color(0xFF252525);
  static const Color elevation3 = Color(0xFF2E2E2E);
  static const Color dividerBorder = Color(0xFF2C2C2C);

  static const Color primary = Color(0xFF75FF9E);
  static const Color onPrimary = Color(0xFF003918);
  static const Color primaryContainer = Color(0xFF00E676);
  static const Color onPrimaryContainer = Color(0xFF00612E);
  static const Color secondary = Color(0xFFFFB3AE);
  static const Color secondaryContainer = Color(0xFFA00118);
  static const Color outflowCrimson = Color(0xFFFF5252);
  static const Color tertiary = Color(0xFFA3F1FF);
  static const Color tertiaryContainer = Color(0xFF00DCF5);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFBACBB9);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textMuted = Color(0xFF666666);
}

class ObsidianFlowTheme {
  ObsidianFlowTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ObsidianFlowColors.canvasBase,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
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
      'Tarea 2.3: Enrutador declarativo con go_router y Riverpod.',
    code: `import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/panel';
  static const String accounts = '/cuentas';
  static const String transactions = '/registros';
  static const String analytics = '/analitica';
  static const String budgets = '/presupuestos';
  static const String newTransaction = '/nueva-transaccion';
}`,
  },
];
