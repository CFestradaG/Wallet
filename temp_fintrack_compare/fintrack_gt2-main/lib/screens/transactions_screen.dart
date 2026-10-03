import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../providers/firestore_providers.dart';
import 'add_transaction_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/category_picker_field.dart';
import '../widgets/filters_card.dart';
import '../utils/icon_utils.dart';
import '../utils/transaction_utils.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _accountId;
  String? _periodId;
  String? _categoryId;
  String _masterFilter = 'Todos';
  MovementFilterKind _movementKind = MovementFilterKind.all;
  MovementSortOrder _sortOrder = MovementSortOrder.newest;
  DateTimeRange? _range;
  int _limit = 0;
  List<String> _selectedTags = [];
  String _tagFilterMode = 'OR';
  bool _filtersExpanded = false;
  bool _prefsLoaded = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final periodsAsync = ref.watch(periodsStreamProvider);
    final txAsync = ref.watch(allTransactionsStreamProvider);
    final prefs =
        ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final currencyFormat = prefs.currencyFormat();

    if (!_prefsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _prefsLoaded) return;
        _loadPersistedFilters();
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: const Text('Movimientos'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Agregar movimiento',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddTransactionScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppTheme.primaryColor)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          return categoriesAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryColor)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (categories) {
              return periodsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (periods) {
                  return txAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryColor)),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (txs) {
                      final filtered = _applyFilters(
                        txs,
                        accounts,
                        periods,
                        categories,
                      );
                      final totals = _computeTotals(filtered);
                      return Column(
                         children: [
                          FiltersCard(
                            isDark: isDark,
                            searchController: _searchController,
                            accounts: accounts,
                            periods: periods,
                            categories: categories,
                            accountId: _accountId,
                            periodId: _periodId,
                            categoryId: _categoryId,
                            masterFilter: _masterFilter,
                            movementKind: _movementKind,
                            sortOrder: _sortOrder,
                            limit: _limit,
                            range: _range,
                            isExpanded: _filtersExpanded,
                            resultCount: filtered.length,
                            availableTags: prefs.availableTags,
                            selectedTags: _selectedTags,
                            tagFilterMode: _tagFilterMode,
                            onSearchChanged: (_) => _updateFilters(() {}),
                            onAccountChanged: (v) =>
                                _updateFilters(() => _accountId = v),
                            onPeriodChanged: (v) =>
                                _updateFilters(() => _periodId = v),
                            onMovementKindChanged: (v) =>
                                _updateFilters(() => _movementKind = v),
                            onSortOrderChanged: (v) =>
                                _updateFilters(() => _sortOrder = v),
                            onLimitChanged: (v) =>
                                _updateFilters(() => _limit = v),
                            onMasterChanged: (v) => _updateFilters(() {
                              _masterFilter = v;
                              final valid = _filteredCategories(
                                      categories, _masterFilter)
                                  .map((c) => c.id)
                                  .toSet();
                              if (_categoryId != null &&
                                  !valid.contains(_categoryId)) {
                                _categoryId = null;
                              }
                            }),
                            onCategoryChanged: (v) =>
                                _updateFilters(() => _categoryId = v),
                            onRangeChanged: (v) =>
                                _updateFilters(() => _range = v),
                            onTagsChanged: (v) =>
                                _updateFilters(() => _selectedTags = v),
                            onTagFilterModeChanged: (v) =>
                                _updateFilters(() => _tagFilterMode = v),
                            onToggleExpanded: () => setState(
                                () => _filtersExpanded = !_filtersExpanded),
                            onClear: () => _updateFilters(() {
                              _accountId = null;
                              _periodId = null;
                              _categoryId = null;
                              _masterFilter = 'Todos';
                              _movementKind = MovementFilterKind.all;
                              _sortOrder = MovementSortOrder.newest;
                              _limit = 0;
                              _range = null;
                              _searchController.clear();
                            }),
                          ),
                          const SizedBox(height: 8),
                          _TotalsBar(
                            totals: totals,
                            isDark: isDark,
                            currencyFormat: currencyFormat,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _TransactionsList(
                              transactions: filtered,
                              accounts: accounts,
                              categories: categories,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _loadPersistedFilters() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _prefsLoaded = true);
      return;
    }

    final prefs = await ref.read(firestoreServiceProvider).getScreenState(user.uid, 'movement_history');

    if (!mounted) return;
    setState(() {
      _accountId = _stringOrNull(prefs['accountId']);
      _periodId = _stringOrNull(prefs['periodId']);
      _categoryId = _stringOrNull(prefs['categoryId']);
      _masterFilter = (prefs['masterFilter'] as String?) ?? 'Todos';
      _movementKind = _movementKindFromName(
        (prefs['movementKind'] as String?) ?? 'all',
      );
      _sortOrder = _sortOrderFromName(
        (prefs['sortOrder'] as String?) ?? 'newest',
      );
      _limit = (prefs['limit'] as int?) ?? 0;
      _filtersExpanded =
          prefs['filtersExpanded'] as bool? ?? false;
      _searchController.text =
          (prefs['searchQuery'] as String?) ?? '';
      _selectedTags = List<String>.from(prefs['selectedTags'] ?? []);
      _tagFilterMode = prefs['tagFilterMode'] ?? 'OR';

      final start = prefs['startDate'];
      final end = prefs['endDate'];
      if (start is Timestamp && end is Timestamp) {
        _range = DateTimeRange(start: start.toDate(), end: end.toDate());
      } else {
        _range = null;
      }
      _prefsLoaded = true;
    });
  }

  Future<void> _persistFilters() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(firestoreServiceProvider).saveScreenState(user.uid, 'movement_history', {
      'accountId': _accountId ?? '',
      'periodId': _periodId ?? '',
      'categoryId': _categoryId ?? '',
      'masterFilter': _masterFilter,
      'movementKind': _movementKind.name,
      'searchQuery': _searchController.text.trim(),
      'sortOrder': _sortOrder.name,
      'limit': _limit,
      'filtersExpanded': _filtersExpanded,
      'selectedTags': _selectedTags,
      'tagFilterMode': _tagFilterMode,
      'startDate': _range?.start == null
          ? null
          : Timestamp.fromDate(_range!.start),
      'endDate':
          _range?.end == null ? null : Timestamp.fromDate(_range!.end),
    });
  }

  void _updateFilters(VoidCallback update) {
    setState(update);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _persistFilters();
    });
  }

  String? _stringOrNull(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  MovementFilterKind _movementKindFromName(String value) {
    return MovementFilterKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => MovementFilterKind.all,
    );
  }

  MovementSortOrder _sortOrderFromName(String value) {
    return MovementSortOrder.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => MovementSortOrder.newest,
    );
  }

  List<TransactionRecord> _applyFilters(
    List<TransactionRecord> txs,
    List<Account> accounts,
    List<Period> periods,
    List<Category> categories,
  ) {
    var list = [...txs];
    final categoriesById = {for (final c in categories) c.id: c};
    final accountsById = {for (final a in accounts) a.id: a};
    if (_movementKind != MovementFilterKind.all) {
      list = list.where((t) {
        switch (_movementKind) {
          case MovementFilterKind.income:
            return !t.isTransfer && t.type == TransactionType.income;
          case MovementFilterKind.expense:
            return !t.isTransfer && t.type == TransactionType.expense;
          case MovementFilterKind.performance:
            return TransactionUtils.isPerformanceTransaction(t, categoriesById);
          case MovementFilterKind.transfer:
            return t.isTransfer;
          case MovementFilterKind.all:
            return true;
        }
      }).toList();
    }
    if (_accountId != null) {
      list = list.where((t) => t.accountId == _accountId).toList();
    }
    if (_periodId != null) {
      list = list.where((t) => t.periodId == _periodId).toList();
    }
    if (_masterFilter != 'Todos') {
      final allowed = _filteredCategories(categories, _masterFilter)
          .map((c) => c.id)
          .toSet();
      list = list.where((t) => allowed.contains(t.categoryId)).toList();
    }
    if (_categoryId != null) {
      list = list.where((t) => t.categoryId == _categoryId).toList();
    }
    if (_range != null) {
      list = list
          .where((t) =>
              !t.date.isBefore(_range!.start) &&
              !t.date.isAfter(_range!.end))
          .toList();
    }

    if (_selectedTags.isNotEmpty) {
      list = list.where((t) {
        if (_tagFilterMode == 'OR') {
          return _selectedTags.any((tag) => t.tags.contains(tag));
        } else {
          return _selectedTags.every((tag) => t.tags.contains(tag));
        }
      }).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((t) {
        final categoryName =
            (categoriesById[t.categoryId]?.name ?? '').toLowerCase();
        final accountName = (accountsById[t.accountId]?.name ?? '').toLowerCase();
        final note = t.note.toLowerCase();
        return categoryName.contains(query) ||
            accountName.contains(query) ||
            note.contains(query);
      }).toList();
    }

    list.sort((a, b) => _sortOrder == MovementSortOrder.newest
        ? b.date.compareTo(a.date)
        : a.date.compareTo(b.date));
    if (_limit > 0 && list.length > _limit) {
      list = list.take(_limit).toList();
    }
    return list;
  }

  List<Category> _filteredCategories(
      List<Category> categories, String master) {
    if (master == 'Todos') return categories;
    return categories.where((c) => c.master == master).toList();
  }

  _TxTotals _computeTotals(List<TransactionRecord> txs) {
    double income = 0;
    double expense = 0;
    for (final t in txs) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return _TxTotals(income: income, expense: expense);
  }
}

class _TxTotals {
  final double income;
  final double expense;
  const _TxTotals({required this.income, required this.expense});
  double get net => income - expense;
}

class _TotalsBar extends StatelessWidget {
  final _TxTotals totals;
  final bool isDark;
  final NumberFormat currencyFormat;
  const _TotalsBar({
    required this.totals,
    required this.isDark,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = currencyFormat;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TotalItem(
              label: 'Ingresos',
              amount: totals.income,
              color: const Color(0xFF00E5C3),
              fmt: fmt,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _TotalItem(
              label: 'Egresos',
              amount: totals.expense,
              color: const Color(0xFFFF5252),
              fmt: fmt,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _TotalItem(
              label: 'Neto',
              amount: totals.net,
              color: AppTheme.primaryColor,
              fmt: fmt,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final NumberFormat fmt;

  const _TotalItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            fmt.format(amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionsList extends ConsumerWidget {
  final List<TransactionRecord> transactions;
  final List<Account> accounts;
  final List<Category> categories;
  final bool isDark;

  const _TransactionsList({
    required this.transactions,
    required this.accounts,
    required this.categories,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'No hay movimientos con esos filtros.',
          style: TextStyle(
            color: isDark ? const Color(0xFF7B7F9E) : Colors.grey,
          ),
        ),
      );
    }

    final accountsById = {for (final a in accounts) a.id: a};
    final categoriesById = {for (final c in categories) c.id: c};

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: transactions.length,
      itemBuilder: (ctx, i) {
        final tx = transactions[i];
        final account = accountsById[tx.accountId];
        final category = categoriesById[tx.categoryId];
        return _TransactionTile(
          tx: tx,
          accountName: account?.name ?? 'Cuenta',
          categoryName: category?.name ?? 'Categoría',
          categoryIcon: category?.icon ?? 'category',
          categoryColor: category?.colorHex ?? 'FF7B7F9E',
          isDark: isDark,
        );
      },
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final TransactionRecord tx;
  final String accountName;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final bool isDark;

  const _TransactionTile({
    required this.tx,
    required this.accountName,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = tx.type == TransactionType.income;
    final prefs =
        ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final fmt = prefs.currencyFormat();
    final dateFmt = DateFormat('dd/MM/yyyy');
    final color = Color(int.parse(categoryColor, radix: 16));

    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1F35) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(_getIconForName(categoryIcon), color: color, size: 22),
      ),
      title: Text(categoryName,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('$accountName • ${dateFmt.format(tx.date)}'),
      trailing: Text(
        '${isIncome ? '+' : '-'}${fmt.format(tx.amount)}',
        style: TextStyle(
          color: isIncome
              ? const Color(0xFF00E5C3)
              : (isDark ? Colors.white : Colors.black87),
          fontWeight: FontWeight.w800,
        ),
      ),
      onTap: () => _openEdit(context, ref),
    );
  }

  void _openEdit(BuildContext context, WidgetRef ref) {
    if (tx.isTransfer && tx.transferGroupId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TransferEditScreen(
            transferGroupId: tx.transferGroupId!,
            amount: tx.amount,
            note: tx.note,
            date: tx.date,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TransactionEditScreen(transaction: tx),
        ),
      );
    }
  }
}

IconData _getIconForName(String name) => AppIcons.getIcon(name);

class TransactionEditScreen extends ConsumerStatefulWidget {
  final TransactionRecord transaction;

  const TransactionEditScreen({super.key, required this.transaction});

  @override
  ConsumerState<TransactionEditScreen> createState() =>
      _TransactionEditScreenState();
}

class _TransactionEditScreenState
    extends ConsumerState<TransactionEditScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _accountId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  List<String> _selectedTags = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _amountController.text = t.amount.toStringAsFixed(2);
    _noteController.text = t.note;
    _accountId = t.accountId;
    _categoryId = t.categoryId;
    _date = t.date;
    _selectedTags = List<String>.from(t.tags);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final prefs =
        ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final isInstallment = widget.transaction.isInstallment;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F3FF),
      appBar: AppBar(
        title: const Text('Editar movimiento'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildField(
              isDark: isDark,
              child: TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                readOnly: isInstallment,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Monto',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (accounts) => _buildDropdown(
                label: 'Cuenta',
                icon: Icons.credit_card_rounded,
                value: _accountId,
                items: accounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ))
                    .toList(),
                onChanged: isInstallment
                    ? (_) {}
                    : (v) => setState(() => _accountId = v),
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 14),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (categories) {
                final filtered = categories
                    .where((c) => c.type.name == widget.transaction.type.name)
                    .toList();
                return _buildField(
                  isDark: isDark,
                  child: CategoryPickerField(
                    label: 'Categoria',
                    categories: filtered,
                    value: _categoryId,
                    enabled: !isInstallment,
                    onChanged: isInstallment
                        ? (_) {}
                        : (v) => setState(() => _categoryId = v),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _buildField(
              isDark: isDark,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded,
                    color: AppTheme.primaryColor),
                title: Text(
                  DateFormat('EEEE, dd MMM yyyy', 'es').format(_date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2028),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            ),
            const SizedBox(height: 14),
            _buildField(
              isDark: isDark,
              child: TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Nota',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildField(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.sell_outlined,
                            size: 20, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('Etiquetas',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (prefs.availableTags.isEmpty)
                    Text(
                      'Sin etiquetas disponibles. Agrégalas en Configuración.',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textMuted(context)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: prefs.availableTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.black : null)),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                          selectedColor: AppTheme.primaryColor,
                          checkmarkColor: Colors.black,
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _saving ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD35D5D),
                        side: const BorderSide(color: Color(0xFFD35D5D)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Eliminar'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _saving ? 'Guardando...' : 'Guardar cambios',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    if (_accountId == null || _categoryId == null) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final svc = ref.read(firestoreServiceProvider);

    setState(() => _saving = true);
    final data = <String, dynamic>{
      'date': Timestamp.fromDate(_date),
      'note': _noteController.text.trim(),
      'tags': _selectedTags,
    };
    if (!widget.transaction.isInstallment) {
      data.addAll({
        'amount': amount,
        'accountId': _accountId,
        'categoryId': _categoryId,
      });
    }
    await svc.updateTransaction(user.uid, widget.transaction.id, data);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text('¿Seguro que deseas eliminar este movimiento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final svc = ref.read(firestoreServiceProvider);
    setState(() => _saving = true);
    if (widget.transaction.isInstallment &&
        widget.transaction.installmentId != null) {
      final db = ref.read(firestoreProvider);
      final accSnap = await db
          .collection('users')
          .doc(user.uid)
          .collection('accounts')
          .doc(widget.transaction.accountId)
          .get();
      if (accSnap.exists) {
        final acc = Account.fromMap(accSnap.id, accSnap.data()!);
        final updated = acc.installments.map((i) {
          if (i.id == widget.transaction.installmentId) {
            final nextRemaining =
                i.remainingMonths < i.totalMonths
                    ? i.remainingMonths + 1
                    : i.remainingMonths;
            return Installment(
              id: i.id,
              description: i.description,
              monthlyAmount: i.monthlyAmount,
              totalMonths: i.totalMonths,
              remainingMonths: nextRemaining,
              startDate: i.startDate,
            );
          }
          return i;
        }).toList();
        await svc.updateAccount(user.uid, acc.id, {
          'installments': updated.map((e) => e.toMap()).toList(),
        });
      }
      if (widget.transaction.transferGroupId != null) {
        await svc.deleteTransferGroup(
            user.uid, widget.transaction.transferGroupId!);
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }
    await svc.deleteTransaction(user.uid, widget.transaction.id);
    if (mounted) Navigator.of(context).pop();
  }
}

class TransferEditScreen extends ConsumerStatefulWidget {
  final String transferGroupId;
  final double amount;
  final String note;
  final DateTime date;

  const TransferEditScreen({
    super.key,
    required this.transferGroupId,
    required this.amount,
    required this.note,
    required this.date,
  });

  @override
  ConsumerState<TransferEditScreen> createState() =>
      _TransferEditScreenState();
}

class _TransferEditScreenState extends ConsumerState<TransferEditScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _sourceAccountId;
  String? _destAccountId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _loadingGroup = true;
  bool _installmentGroup = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.amount.toStringAsFixed(2);
    _noteController.text = widget.note;
    _date = widget.date;
    _loadGroup();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F3FF),
      appBar: AppBar(
        title: const Text('Editar transferencia'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: accountsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppTheme.primaryColor)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          _sourceAccountId ??=
              accounts.isNotEmpty ? accounts.first.id : null;
          _destAccountId ??= accounts.length > 1
              ? accounts[1].id
              : _sourceAccountId;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildField(
                  isDark: isDark,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    readOnly: _installmentGroup,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Monto',
                      prefixIcon: Icon(Icons.swap_horiz_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                IgnorePointer(
                  ignoring: _installmentGroup,
                  child: Opacity(
                    opacity: _installmentGroup ? 0.6 : 1,
                    child: _buildDropdown(
                      label: 'Cuenta origen',
                      icon: Icons.call_made_rounded,
                      value: _sourceAccountId,
                      items: accounts
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _sourceAccountId = v),
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                IgnorePointer(
                  ignoring: _installmentGroup,
                  child: Opacity(
                    opacity: _installmentGroup ? 0.6 : 1,
                    child: _buildDropdown(
                      label: 'Cuenta destino',
                      icon: Icons.call_received_rounded,
                      value: _destAccountId,
                      items: accounts
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _destAccountId = v),
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildField(
                  isDark: isDark,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded,
                        color: AppTheme.primaryColor),
                    title: Text(
                      DateFormat('EEEE, dd MMM yyyy', 'es').format(_date),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2028),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _buildField(
                  isDark: isDark,
                  child: TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Nota',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _delete,
                        child: const Text('Eliminar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving || _loadingGroup ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          _saving ? 'Guardando...' : 'Guardar',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadGroup() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final db = ref.read(firestoreProvider);
    final snap = await db
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .where('transferGroupId', isEqualTo: widget.transferGroupId)
        .get();
    if (snap.docs.isEmpty) {
      setState(() => _loadingGroup = false);
      return;
    }
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['isInstallment'] == true) {
        _installmentGroup = true;
      }
      final type = data['type'] as String? ?? 'expense';
      if (type == TransactionType.expense.name) {
        _sourceAccountId = data['accountId'] as String?;
        _destAccountId = data['transferAccountId'] as String?;
      } else {
        _destAccountId = data['accountId'] as String?;
        _sourceAccountId = data['transferAccountId'] as String?;
      }
    }
    setState(() => _loadingGroup = false);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    if (_sourceAccountId == null || _destAccountId == null) return;
    if (_sourceAccountId == _destAccountId) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final svc = ref.read(firestoreServiceProvider);

    setState(() => _saving = true);
    await svc.updateTransferGroup(
      uid: user.uid,
      groupId: widget.transferGroupId,
      sourceAccountId: _sourceAccountId!,
      destAccountId: _destAccountId!,
      amount: amount,
      date: _date,
      note: _noteController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final svc = ref.read(firestoreServiceProvider);
    setState(() => _saving = true);
    await svc.deleteTransferGroup(user.uid, widget.transferGroupId);
    if (mounted) Navigator.of(context).pop();
  }
}

Widget _buildField({required bool isDark, required Widget child}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

Widget _buildDropdown({
  required String label,
  required IconData icon,
  required String? value,
  required List<DropdownMenuItem<String>> items,
  required ValueChanged<String?> onChanged,
  required bool isDark,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      decoration: InputDecoration(
        border: InputBorder.none,
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
      ),
    ),
  );
}
