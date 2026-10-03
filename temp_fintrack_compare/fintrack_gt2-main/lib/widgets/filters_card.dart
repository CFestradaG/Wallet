import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class FiltersCard extends StatelessWidget {
  final bool isDark;
  final TextEditingController searchController;
  final List<Account> accounts;
  final List<Period> periods;
  final List<Category> categories;
  final String? accountId;
  final String? periodId;
  final String? categoryId;
  final String masterFilter;
  final MovementFilterKind movementKind;
  final MovementSortOrder sortOrder;
  final int limit;
  final DateTimeRange? range;
  final bool isExpanded;
  final int resultCount;
  final List<String> availableTags;
  final List<String> selectedTags;
  final String tagFilterMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String?> onPeriodChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onMasterChanged;
  final ValueChanged<MovementFilterKind> onMovementKindChanged;
  final ValueChanged<MovementSortOrder> onSortOrderChanged;
  final ValueChanged<int> onLimitChanged;
  final ValueChanged<DateTimeRange?> onRangeChanged;
  final ValueChanged<List<String>> onTagsChanged;
  final ValueChanged<String> onTagFilterModeChanged;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClear;

  const FiltersCard({
    super.key,
    required this.isDark,
    required this.searchController,
    required this.accounts,
    required this.periods,
    required this.categories,
    required this.accountId,
    required this.periodId,
    required this.categoryId,
    required this.masterFilter,
    required this.movementKind,
    required this.sortOrder,
    required this.limit,
    required this.range,
    required this.isExpanded,
    required this.resultCount,
    required this.availableTags,
    required this.selectedTags,
    required this.tagFilterMode,
    required this.onSearchChanged,
    required this.onAccountChanged,
    required this.onPeriodChanged,
    required this.onCategoryChanged,
    required this.onMasterChanged,
    required this.onMovementKindChanged,
    required this.onSortOrderChanged,
    required this.onLimitChanged,
    required this.onRangeChanged,
    required this.onTagsChanged,
    required this.onTagFilterModeChanged,
    required this.onToggleExpanded,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final rangeText = range == null
        ? 'Todas las fechas'
        : '${dateFmt.format(range!.start)} - ${dateFmt.format(range!.end)}';
    final activeFilters = [
      if (searchController.text.trim().isNotEmpty) 'Texto',
      if (movementKind != MovementFilterKind.all)
        _movementKindLabel(movementKind),
      if (sortOrder != MovementSortOrder.newest) 'Orden',
      if (limit > 0) 'Top $limit',
      if (accountId != null) 'Cuenta',
      if (periodId != null) 'Periodo',
      if (masterFilter != 'Todos') masterFilter,
      if (categoryId != null) 'Categoria',
      if (range != null) 'Fecha',
      if (selectedTags.isNotEmpty) 'Etiquetas (${selectedTags.length})',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDarkHigh : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggleExpanded,
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Filtros',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$resultCount movimientos',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Limpiar'),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textMuted(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (activeFilters.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.panelAlt(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Sin filtros activos',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted(context),
                    ),
                  ),
                ),
              for (final item in activeFilters)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (isExpanded) ...[
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Buscar texto',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<MovementSortOrder>(
                  value: sortOrder,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: MovementSortOrder.newest,
                      child: Text('Mas nuevos'),
                    ),
                    DropdownMenuItem(
                      value: MovementSortOrder.oldest,
                      child: Text('Mas viejos'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) onSortOrderChanged(v);
                  },
                  decoration: const InputDecoration(labelText: 'Orden'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: limit,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Todos')),
                    DropdownMenuItem(value: 10, child: Text('Top 10')),
                    DropdownMenuItem(value: 20, child: Text('Top 20')),
                    DropdownMenuItem(value: 50, child: Text('Top 50')),
                  ],
                  onChanged: (v) {
                    if (v != null) onLimitChanged(v);
                  },
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<MovementFilterKind>(
            value: movementKind,
            isExpanded: true,
            items: MovementFilterKind.values
                .map(
                  (kind) => DropdownMenuItem(
                    value: kind,
                    child: Text(_movementKindLabel(kind)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onMovementKindChanged(v);
            },
            decoration: const InputDecoration(labelText: 'Tipo'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: accountId,
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todas las cuentas'),
              ),
              ...accounts.map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name),
                  )),
            ],
            onChanged: onAccountChanged,
            decoration: const InputDecoration(labelText: 'Cuenta'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: periodId,
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todos los períodos'),
              ),
              ...periods.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name),
                  )),
            ],
            onChanged: onPeriodChanged,
            decoration: const InputDecoration(labelText: 'Período'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: [
              'Todos',
              'Hogar',
              'Transporte',
              'Alimentación',
              'Servicios',
              'Salud',
              'Educación',
              'Finanzas',
              'Ocio',
              'Ingresos',
              'Otros'
            ].contains(masterFilter)
                ? masterFilter
                : 'Todos',
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'Todos', child: Text('Todos')),
              DropdownMenuItem(value: 'Hogar', child: Text('Hogar')),
              DropdownMenuItem(value: 'Transporte', child: Text('Transporte')),
              DropdownMenuItem(
                  value: 'Alimentación', child: Text('Alimentación')),
              DropdownMenuItem(value: 'Servicios', child: Text('Servicios')),
              DropdownMenuItem(value: 'Salud', child: Text('Salud')),
              DropdownMenuItem(value: 'Educación', child: Text('Educación')),
              DropdownMenuItem(value: 'Finanzas', child: Text('Finanzas')),
              DropdownMenuItem(value: 'Ocio', child: Text('Ocio')),
              DropdownMenuItem(value: 'Ingresos', child: Text('Ingresos')),
              DropdownMenuItem(value: 'Otros', child: Text('Otros')),
            ],
            onChanged: (v) => onMasterChanged(v ?? 'Todos'),
            decoration: const InputDecoration(labelText: 'Master'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: categories.any((c) => c.id == categoryId) ? categoryId : null,
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todas las categorías'),
              ),
              ...categories
                  .where((c) =>
                      masterFilter == 'Todos' || c.master == masterFilter)
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
            ],
            onChanged: onCategoryChanged,
            decoration: const InputDecoration(labelText: 'Categoría'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 3),
                lastDate: DateTime(now.year + 3),
                initialDateRange: range,
              );
              if (picked != null) onRangeChanged(picked);
            },
            icon: const Icon(Icons.date_range_rounded),
            label: Text(rangeText),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtrar por Etiquetas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  const Text('Lógica:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: tagFilterMode,
                    underline: const SizedBox(),
                    items: const [
                       DropdownMenuItem(value: 'OR', child: Text('O', style: TextStyle(fontWeight: FontWeight.bold))),
                       DropdownMenuItem(value: 'AND', child: Text('Y', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (v) {
                       if (v != null) onTagFilterModeChanged(v);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (availableTags.isEmpty)
            Text(
              'No hay etiquetas disponibles.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
            )
          else
            Wrap(
              spacing: 8,
              children: availableTags.map((tag) {
                final isSelected = selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : null)),
                  selected: isSelected,
                  onSelected: (val) {
                    final newList = List<String>.from(selectedTags);
                    if (val) {
                      newList.add(tag);
                    } else {
                      newList.remove(tag);
                    }
                    onTagsChanged(newList);
                  },
                  selectedColor: AppTheme.primaryColor,
                  checkmarkColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _movementKindLabel(MovementFilterKind kind) {
    switch (kind) {
      case MovementFilterKind.all:
        return 'Todos';
      case MovementFilterKind.income:
        return 'Ingresos';
      case MovementFilterKind.expense:
        return 'Egresos';
      case MovementFilterKind.performance:
        return 'Rendimientos';
      case MovementFilterKind.transfer:
        return 'Transferencias';
    }
  }
}
