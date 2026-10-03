import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/firestore_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/icon_utils.dart';
import '../../utils/transaction_utils.dart';
import '../../widgets/filters_card.dart';
import '../transactions_screen.dart';

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedMaster; // Drill-down state
  
  // UI Filter states
  String? _accountId;
  String? _periodId;
  String? _categoryId;
  String _masterFilter = 'Todos';
  MovementFilterKind _movementKind = MovementFilterKind.expense;
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
    final txAsync = ref.watch(allTransactionsStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final periodsAsync = ref.watch(periodsStreamProvider);
    final prefs =
        ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final currency = prefs.currencyFormat();

    if (!_prefsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _prefsLoaded) return;
        _loadPersistedFilters();
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: const Text('Reportes'),
        centerTitle: true,
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) => periodsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (periods) => categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (categories) => txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (txs) {
                final filtered = _applyFilters(txs, accounts, periods, categories);
                
                final chartRows = _selectedMaster == null
                    ? _getCategoryTotals(
                        txs: filtered,
                        categories: categories,
                        kind: _movementKind,
                        accountId: _accountId,
                        isMaster: true,
                      )
                    : _getCategoryTotals(
                        txs: filtered,
                        categories: categories,
                        kind: _movementKind,
                        accountId: _accountId,
                        isMaster: false,
                        masterName: _selectedMaster,
                      );

                final totalAmount = chartRows.fold<double>(0.0, (sum, row) => sum + row.amount);

                final transactionList = filtered.where((tx) {
                  if (_selectedMaster != null) {
                    final cat = categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => categories.first);
                    if (cat.master != _selectedMaster) return false;
                  }
                  return true; 
                }).toList();

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      sliver: SliverToBoxAdapter(
                        child: _HeaderCard(
                          resultCount: filtered.length,
                          totalAmount: totalAmount,
                          currency: currency,
                          activeFilters: _buildFilterSummary(),
                          kind: _movementKind,
                        ),
                      ),
                    ),
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _SectionTitle(
                          title: 'Filtros Avanzados',
                          subtitle: 'Personaliza tu reporte',
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: FiltersCard(
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
                          onSearchChanged: (v) => _updateFilters(() {}),
                          onAccountChanged: (v) => _updateFilters(() => _accountId = v),
                          onPeriodChanged: (v) => _updateFilters(() => _periodId = v),
                          onCategoryChanged: (v) => _updateFilters(() => _categoryId = v),
                          onMasterChanged: (v) => _updateFilters(() {
                            _masterFilter = v;
                            _categoryId = null;
                            _selectedMaster = null; 
                          }),
                          onMovementKindChanged: (v) => _updateFilters(() {
                            _movementKind = v;
                            _selectedMaster = null;
                          }),
                          onSortOrderChanged: (v) => _updateFilters(() => _sortOrder = v),
                          onLimitChanged: (v) => _updateFilters(() => _limit = v),
                          onRangeChanged: (v) => _updateFilters(() => _range = v),
                          onTagsChanged: (v) => _updateFilters(() => _selectedTags = v),
                          onTagFilterModeChanged: (v) => _updateFilters(() => _tagFilterMode = v),
                          onToggleExpanded: () => setState(() => _filtersExpanded = !_filtersExpanded),
                          onClear: () => _updateFilters(() {
                            _accountId = null;
                            _periodId = null;
                            _categoryId = null;
                            _masterFilter = 'Todos';
                            _selectedMaster = null;
                            _movementKind = MovementFilterKind.expense;
                            _sortOrder = MovementSortOrder.newest;
                            _limit = 0;
                            _range = null;
                            _selectedTags = [];
                            _tagFilterMode = 'OR';
                            _searchController.clear();
                          }),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionTitle(
                              title: _selectedMaster ?? 'Categorías Maestras',
                              subtitle: _selectedMaster == null
                                  ? 'Resumen por grupo'
                                  : 'Detalle de subcategorías',
                            ),
                            if (_selectedMaster != null)
                              TextButton.icon(
                                onPressed: () => _updateFilters(() {
                                  _selectedMaster = null;
                                  _masterFilter = 'Todos';
                                }),
                                icon: const Icon(Icons.arrow_back, size: 16),
                                label: const Text('Volver'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    if (chartRows.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: _EmptyReports(
                            message: 'No hay datos para mostrar con los filtros actuales.',
                          ),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _BarChartCard(
                            rows: chartRows,
                            totalAmount: totalAmount,
                            currency: currency,
                            onRowTap: (name) {
                              if (_selectedMaster == null) {
                                setState(() {
                                  _selectedMaster = name;
                                  _masterFilter = name;
                                });
                                _persistFilters();
                              }
                            },
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _SectionTitle(
                          title: 'Movimientos',
                          subtitle: 'Detalle transaccional filtrado',
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    if (transactionList.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: _EmptyReports(message: 'Sin movimientos registrados.'),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final tx = transactionList[index];
                              final cat = categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => categories.first);
                              final acc = accounts.firstWhere((a) => a.id == tx.accountId, orElse: () => accounts.first);
                              return InkWell(
                                onTap: () {
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
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: _TransactionTile(
                                  tx: tx,
                                  category: cat,
                                  account: acc,
                                  currency: currency,
                                  isNegative: tx.type == TransactionType.expense || 
                                             (tx.isTransfer && tx.type == TransactionType.expense),
                                ),
                              );
                            },
                            childCount: transactionList.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadPersistedFilters() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _prefsLoaded = true);
      return;
    }
    final svc = ref.read(firestoreServiceProvider);
    final map = await svc.getScreenState(user.uid, 'reports');

    if (!mounted) return;
    setState(() {
      _accountId = map['f_account'];
      _periodId = map['f_period'];
      _categoryId = map['f_category'];
      _masterFilter = map['f_master'] ?? 'Todos';
      _movementKind = _movementKindFromName(map['f_kind'] ?? 'expense');
      _sortOrder = _sortOrderFromName(map['f_sort'] ?? 'newest');
      _limit = map['f_limit'] ?? 0;
      _selectedTags = List<String>.from(map['f_tags'] ?? []);
      _tagFilterMode = map['f_tag_mode'] ?? 'OR';
      _filtersExpanded = map['f_expanded'] ?? false;
      final start = map['f_range_start'];
      final end = map['f_range_end'];
      if (start is Timestamp && end is Timestamp) {
        _range = DateTimeRange(start: start.toDate(), end: end.toDate());
      } else if (start is String && end is String) {
        _range = DateTimeRange(start: DateTime.parse(start), end: DateTime.parse(end));
      }
      _prefsLoaded = true;
    });
  }

  Future<void> _persistFilters() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    await ref.read(firestoreServiceProvider).saveScreenState(uid, 'reports', {
      'f_account': _accountId,
      'f_period': _periodId,
      'f_category': _categoryId,
      'f_master': _masterFilter,
      'f_kind': _movementKind.name,
      'f_sort': _sortOrder.name,
      'f_limit': _limit,
      'f_range_start': _range?.start,
      'f_range_end': _range?.end,
      'f_tags': _selectedTags,
      'f_tag_mode': _tagFilterMode,
      'f_expanded': _filtersExpanded,
    });
  }

  void _updateFilters(VoidCallback update) {
    setState(update);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _persistFilters();
    });
  }

  MovementFilterKind _movementKindFromName(String value) {
    return MovementFilterKind.values.firstWhere((kind) => kind.name == value, orElse: () => MovementFilterKind.all);
  }

  MovementSortOrder _sortOrderFromName(String value) {
    return MovementSortOrder.values.firstWhere((kind) => kind.name == value, orElse: () => MovementSortOrder.newest);
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
            if (_accountId == null && t.isTransfer) return false;
            return t.type == TransactionType.income;
          case MovementFilterKind.expense: 
            if (_accountId == null && t.isTransfer) return false;
            return t.type == TransactionType.expense;
          case MovementFilterKind.performance: 
            return TransactionUtils.isPerformanceTransaction(t, categoriesById);
          case MovementFilterKind.transfer: return t.isTransfer;
          default: return true;
        }
      }).toList();
    }
    if (_accountId != null) list = list.where((t) => t.accountId == _accountId).toList();
    if (_periodId != null) list = list.where((t) => t.periodId == _periodId).toList();
    if (_masterFilter != 'Todos') {
      final allowed = categories.where((c) => c.master == _masterFilter).map((c) => c.id).toSet();
      list = list.where((t) => allowed.contains(t.categoryId)).toList();
    }
    if (_categoryId != null) list = list.where((t) => t.categoryId == _categoryId).toList();
    if (_range != null) {
      list = list.where((t) => !t.date.isBefore(_range!.start) && !t.date.isAfter(_range!.end)).toList();
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
        final categoryName = (categoriesById[t.categoryId]?.name ?? '').toLowerCase();
        final accountName = (accountsById[t.accountId]?.name ?? '').toLowerCase();
        final note = t.note.toLowerCase();
        return categoryName.contains(query) || accountName.contains(query) || note.contains(query);
      }).toList();
    }

    list.sort((a, b) => _sortOrder == MovementSortOrder.newest ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    if (_limit > 0 && list.length > _limit) list = list.take(_limit).toList();

    return list;
  }

  List<String> _buildFilterSummary() {
    final active = <String>[];
    if (_searchController.text.isNotEmpty) active.add('Búsqueda');
    if (_accountId != null) active.add('Cuenta');
    if (_periodId != null) active.add('Periodo');
    if (_masterFilter != 'Todos') active.add(_masterFilter);
    if (_range != null) active.add('Fechas');
    if (_selectedTags.isNotEmpty) active.add('Etiquetas');
    return active;
  }
}

class _CategorySpendRow {
  final String name;
  final double amount;
  final Color color;
  _CategorySpendRow({required this.name, required this.amount, required this.color});
}

List<_CategorySpendRow> _getCategoryTotals({
  required List<TransactionRecord> txs,
  required List<Category> categories,
  required MovementFilterKind kind,
  required String? accountId,
  required bool isMaster,
  String? masterName,
}) {
  final totals = <String, double>{};
  final colors = <String, Color>{};

  for (final tx in txs) {
    final cat = categories.firstWhere(
      (c) => c.id == tx.categoryId,
      orElse: () => Category(
        id: 'no-cat',
        name: 'Sin categoría',
        type: CategoryType.expense,
        colorHex: 'FF9E9E9E',
      ),
    );

    if (!isMaster && cat.master != masterName) continue;

    final key = isMaster ? cat.master : cat.name;
    totals.update(key, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    colors.putIfAbsent(
      key,
      () => Color(int.parse(cat.colorHex, radix: 16)),
    );
  }

  final result = totals.entries.map((e) {
    return _CategorySpendRow(
      name: e.key,
      amount: e.value,
      color: colors[e.key] ?? AppTheme.primaryColor,
    );
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  // Aplicar matices si es vista de subcategorías
  if (!isMaster && result.isNotEmpty && masterName != null) {
    for (int i = 0; i < result.length; i++) {
      final hsl = HSLColor.fromColor(result[i].color);
      // Generar variante variando luminosidad y saturación basada en el índice
      final lightness = (hsl.lightness - (0.08 * i)).clamp(0.2, 0.8);
      final saturation = (hsl.saturation + (0.05 * i)).clamp(0.3, 1.0);
      result[i] = _CategorySpendRow(
        name: result[i].name,
        amount: result[i].amount,
        color: hsl.withLightness(lightness).withSaturation(saturation).toColor(),
      );
    }
  }

  return result;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.resultCount,
    required this.totalAmount,
    required this.currency,
    required this.activeFilters,
    required this.kind,
  });

  final int resultCount;
  final double totalAmount;
  final NumberFormat currency;
  final List<String> activeFilters;
  final MovementFilterKind kind;

  @override
  Widget build(BuildContext context) {
    String label = 'Resumen';
    switch (kind) {
      case MovementFilterKind.income: label = 'Total Entradas'; break;
      case MovementFilterKind.expense: label = 'Total Salidas'; break;
      case MovementFilterKind.performance: label = 'Rendimiento'; break;
      case MovementFilterKind.transfer: label = 'Transferencias'; break;
      default: label = 'Movimientos'; break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analítica de flujo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$label: ${currency.format(totalAmount)}',
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            '$resultCount movimientos filtrados',
            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (activeFilters.isEmpty)
                _FilterChip(label: 'Sin filtros activos'),
              for (final item in activeFilters) _FilterChip(label: item),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary(context),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textMuted(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: AppTheme.textMuted(context)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted(context)),
          ),
        ],
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({
    required this.rows,
    required this.totalAmount,
    required this.currency,
    required this.onRowTap,
  });

  final List<_CategorySpendRow> rows;
  final double totalAmount;
  final NumberFormat currency;
  final Function(String name) onRowTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                onTap: () => onRowTap(row.name),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary(context),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          currency.format(row.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.border(context).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: totalAmount <= 0
                              ? 0
                              : (row.amount / totalAmount).clamp(0, 1),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  row.color,
                                  row.color.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: row.color.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalAmount <= 0 ? 0 : ((row.amount / totalAmount) * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tx,
    required this.category,
    required this.account,
    required this.currency,
    this.isNegative = true,
  });

  final TransactionRecord tx;
  final Category category;
  final Account account;
  final NumberFormat currency;
  final bool isNegative;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(int.parse(category.colorHex, radix: 16)).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIconData(category.icon),
              color: Color(int.parse(category.colorHex, radix: 16)),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                Text(
                  account.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isNegative ? '-' : '+'} ${currency.format(tx.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isNegative ? AppTheme.errorColor : AppTheme.successColor,
                  fontSize: 15,
                ),
              ),
              Text(
                DateFormat('dd MMM').format(tx.date),
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String name) => AppIcons.getIcon(name);
}
