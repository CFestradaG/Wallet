import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/firestore_providers.dart';
import '../../theme/app_theme.dart';

class BudgetTab extends ConsumerStatefulWidget {
  const BudgetTab({super.key});

  @override
  ConsumerState<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends ConsumerState<BudgetTab> {
  bool _isEditing = false;
  final Map<String, double> _tempBudgets = {};
  bool _initialized = false;
  String? _selectedPeriodId;

  String _normalize(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  void _initTempBudgets(Period period, List<Category> categories) {
    if (_initialized) return;
    _tempBudgets.clear();
    
    final masters = <String>{};
    for (final cat in categories) {
      if (cat.type == CategoryType.expense) {
        masters.add(_normalize(cat.master));
      }
    }

    for (final master in masters) {
      _tempBudgets[master] = period.budgets[master] ?? 0.0;
    }
    _initialized = true;
  }

  Future<void> _saveBudgets(Period period) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    try {
      await ref.read(firestoreServiceProvider).updatePeriodBudgets(
            uid,
            period.id,
            _tempBudgets,
          );
      setState(() {
        _isEditing = false;
        _initialized = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Presupuesto actualizado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(allTransactionsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final periodsAsync = ref.watch(periodsStreamProvider);
    final activePeriodAsync = ref.watch(activePeriodProvider);
    final prefs = ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final currency = prefs.currencyFormat();

    return periodsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error al cargar periodos: $e'))),
      data: (periods) {
        // Encontrar el periodo a mostrar
        Period? displayPeriod;
        final activePeriod = activePeriodAsync.value;

        if (_selectedPeriodId != null) {
          displayPeriod = periods.firstWhere((p) => p.id == _selectedPeriodId, orElse: () => activePeriod!);
        } else {
          displayPeriod = activePeriod;
        }

        return Scaffold(
          backgroundColor: AppTheme.pageBackground(context),
          appBar: AppBar(
            title: Text(_isEditing ? 'Editar Presupuesto' : 'Presupuesto'),
            centerTitle: true,
            bottom: _isEditing 
              ? null 
              : PreferredSize(
                  preferredSize: const Size.fromHeight(40),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PeriodSelector(
                      periods: periods,
                      selectedId: displayPeriod?.id,
                      activeId: activePeriod?.id,
                      onChanged: (id) => setState(() {
                        _selectedPeriodId = id;
                        _initialized = false;
                      }),
                    ),
                  ),
                ),
            actions: [
              if (displayPeriod != null)
                IconButton(
                  onPressed: () {
                    if (_isEditing) {
                      _saveBudgets(displayPeriod!);
                    } else {
                      setState(() {
                        _isEditing = true;
                        _initialized = false;
                      });
                    }
                  },
                  icon: Icon(_isEditing ? Icons.save_rounded : Icons.edit_note_rounded),
                  color: _isEditing ? AppTheme.successColor : null,
                ),
              if (_isEditing)
                IconButton(
                  onPressed: () => setState(() => _isEditing = false),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          body: displayPeriod == null
              ? const _EmptyState(message: 'No hay periodos configurados.')
              : categoriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (categories) {
                    if (_isEditing) _initTempBudgets(displayPeriod!, categories);

                    return txAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (txs) {
                        if (_isEditing) {
                          return _buildEditList(categories);
                        }

                        // Filtramos transacciones por el periodo seleccionado/activo
                        final periodTxs = txs.where((t) => t.periodId == displayPeriod!.id).toList();
                        
                        final budgetRows = _getBudgetStats(
                          txs: periodTxs,
                          categories: categories,
                          period: displayPeriod!,
                        );

                        final totalBudget = budgetRows.fold<double>(0.0, (sum, row) => sum + row.budget);
                        final totalActual = budgetRows.fold<double>(0.0, (sum, row) => sum + row.actual);

                        return CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverToBoxAdapter(
                                  child: _BudgetHeaderCard(
                                    periodName: displayPeriod.name,
                                    totalBudget: totalBudget,
                                    totalActual: totalActual,
                                    currency: currency,
                                  ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverToBoxAdapter(
                                child: budgetRows.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.only(top: 40),
                                          child: Text('Sin gastos registrados en este periodo.'),
                                        ),
                                      )
                                    : _BudgetBarChart(
                                        rows: budgetRows,
                                        currency: currency,
                                        onRowTap: (name) {},
                                      ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEditList(List<Category> categories) {
    final masterMap = <String, _MasterInfo>{};
    for (final cat in categories) {
      if (cat.type != CategoryType.expense) continue;
      final norm = _normalize(cat.master);
      if (!masterMap.containsKey(norm)) {
        masterMap[norm] = _MasterInfo(
          displayName: cat.master,
          colorHex: cat.colorHex,
        );
      }
    }

    final sortedItems = masterMap.entries.toList()
      ..sort((a, b) => a.value.displayName.compareTo(b.value.displayName));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const _SectionTitle(
          title: 'Planificación de Gastos',
          subtitle: 'Define metas globales por categoría principal',
        ),
        const SizedBox(height: 20),
        for (final entry in sortedItems)
          _BudgetEditTile(
            masterName: entry.value.displayName,
            colorHex: entry.value.colorHex,
            initialValue: _tempBudgets[entry.key] ?? 0.0,
            onChanged: (val) => _tempBudgets[entry.key] = val,
          ),
      ],
    );
  }

  List<_BudgetRow> _getBudgetStats({
    required List<TransactionRecord> txs,
    required List<Category> categories,
    required Period period,
  }) {
    final spentByCategoryId = <String, double>{};
    for (final tx in txs) {
      if (tx.isTransfer || tx.type != TransactionType.expense) continue;
      spentByCategoryId.update(tx.categoryId, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }

    final masterStats = <String, _MasterStatsAccumulator>{};
    for (final cat in categories) {
      if (cat.type != CategoryType.expense) continue;
      final norm = _normalize(cat.master);
      final spent = spentByCategoryId[cat.id] ?? 0.0;
      
      if (!masterStats.containsKey(norm)) {
        masterStats[norm] = _MasterStatsAccumulator(
          displayName: cat.master,
          colorHex: cat.colorHex,
          budget: period.budgets[norm] ?? 0.0,
        );
      }
      masterStats[norm]!.actualSpent += spent;
    }

    final result = masterStats.values
        .where((s) => s.budget > 0 || s.actualSpent > 0)
        .map((s) => _BudgetRow(
              name: s.displayName,
              budget: s.budget,
              actual: s.actualSpent,
              color: Color(int.parse(s.colorHex, radix: 16)),
            ))
        .toList();

    return result..sort((a, b) => b.percent.compareTo(a.percent));
  }
}

class _PeriodSelector extends StatelessWidget {
  final List<Period> periods;
  final String? selectedId;
  final String? activeId;
  final ValueChanged<String> onChanged;

  const _PeriodSelector({
    required this.periods,
    required this.selectedId,
    required this.activeId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: periods.map((p) {
          final isSelected = p.id == selectedId;
          final isActive = p.id == activeId;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                p.name,
                style: TextStyle(
                  color: isSelected ? Colors.black : AppTheme.textPrimary(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (val) {
                if (val) onChanged(p.id);
              },
              backgroundColor: AppTheme.panel(context),
              selectedColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isActive ? AppTheme.primaryColor : AppTheme.border(context),
                  width: isActive ? 2 : 1,
                ),
              ),
              avatar: isActive 
                ? Icon(Icons.bolt_rounded, size: 16, color: isSelected ? Colors.black : AppTheme.primaryColor)
                : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MasterInfo {
  final String displayName;
  final String colorHex;
  _MasterInfo({required this.displayName, required this.colorHex});
}

class _MasterStatsAccumulator {
  final String displayName;
  final String colorHex;
  final double budget;
  double actualSpent = 0.0;
  _MasterStatsAccumulator({required this.displayName, required this.colorHex, required this.budget});
}

class _BudgetEditTile extends StatefulWidget {
  final String masterName;
  final String colorHex;
  final double initialValue;
  final ValueChanged<double> onChanged;

  const _BudgetEditTile({
    required this.masterName,
    required this.colorHex,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_BudgetEditTile> createState() => _BudgetEditTileState();
}

class _BudgetEditTileState extends State<_BudgetEditTile> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue > 0 ? widget.initialValue.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(int.parse(widget.colorHex, radix: 16)).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.category_rounded,
              size: 14,
              color: Color(int.parse(widget.colorHex, radix: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.masterName,
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary(context)),
            ),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                hintText: '0',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(8),
              ),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 0.0;
                widget.onChanged(d);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow {
  final String name;
  final double budget;
  final double actual;
  final Color color;
  _BudgetRow({required this.name, required this.budget, required this.actual, required this.color});

  double get percent => budget > 0 ? (actual / budget) : (actual > 0 ? 1.1 : 0.0);
}

class _BudgetHeaderCard extends StatelessWidget {
  final String periodName;
  final double totalBudget;
  final double totalActual;
  final NumberFormat currency;

  const _BudgetHeaderCard({
    required this.periodName,
    required this.totalBudget,
    required this.totalActual,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final diff = totalBudget - totalActual;
    final isOver = diff < 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado de Planificación',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary(context)),
                    ),
                    Text(
                      periodName,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeaderStat(label: 'Presupuesto', value: currency.format(totalBudget)),
              _HeaderStat(label: 'Ejecutado', value: currency.format(totalActual)),
              _HeaderStat(
                label: isOver ? 'Excedido' : 'Disponible',
                value: currency.format(diff.abs()),
                color: isOver ? AppTheme.errorColor : AppTheme.successColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _HeaderStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context))),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

class _BudgetBarChart extends StatelessWidget {
  final List<_BudgetRow> rows;
  final NumberFormat currency;
  final Function(String name) onRowTap;

  const _BudgetBarChart({required this.rows, required this.currency, required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        row.name,
                        style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary(context), fontSize: 14),
                      ),
                      Text(
                        '${currency.format(row.actual)} / ${currency.format(row.budget)}',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMuted(context), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _BudgetBar(percent: row.percent),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(row.percent * 100).toStringAsFixed(1)}% de capacidad',
                        style: TextStyle(
                          fontSize: 11, 
                          color: _getStatusColor(row.percent),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (row.budget > 0)
                        Text(
                          row.actual > row.budget 
                            ? 'Déficit de ${currency.format(row.actual - row.budget)}'
                            : 'Faltan ${currency.format(row.budget - row.actual)}',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted(context)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(double p) {
    if (p < 0.7) return AppTheme.successColor;
    if (p < 0.95) return Colors.orange;
    return AppTheme.errorColor;
  }
}

class _BudgetBar extends StatelessWidget {
  final double percent;
  const _BudgetBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    final isCritical = percent > 1.0;
    final color = _getColor(percent);

    return Stack(
      children: [
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.border(context).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        FractionallySizedBox(
          widthFactor: clamped,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
          ),
        ),
        if (isCritical)
          Positioned(
            right: 0,
            child: Icon(Icons.warning_rounded, color: AppTheme.errorColor, size: 12),
          ),
      ],
    );
  }

  Color _getColor(double p) {
    if (p < 0.7) return AppTheme.successColor;
    if (p < 0.95) return Colors.orange;
    return AppTheme.errorColor;
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.panel(context),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin Presupuesto',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted(context),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

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
          ),
        ),
      ],
    );
  }
}
