import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/firestore_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/category_picker_field.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _perfQtyController = TextEditingController();
  final _perfOdomController = TextEditingController();
  final _perfStationController = TextEditingController();
  final _perfMeasureController = TextEditingController();

  _EntryKind _kind = _EntryKind.expense;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  String? _selectedCategoryId;
  String? _selectedPerformanceId;
  bool _recordPerformanceData = false;
  String _perfUnit = 'L';
  List<Vehicle> _vehiclesCache = const [];
  DateTime _date = DateTime.now();
  List<String> _selectedTags = [];
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _perfQtyController.dispose();
    _perfOdomController.dispose();
    _perfStationController.dispose();
    _perfMeasureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final vehiclesAsync = ref.watch(vehiclesStreamProvider);
    final isDark = AppTheme.isDark(context);
    final prefs = ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final currencySymbol = prefs.currencySymbol;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: const Text('Nuevo Movimiento'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Tipo ───────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppTheme.panel(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border(context)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                   _typeButton(_EntryKind.expense, 'Egreso',
                      Icons.arrow_upward_rounded),
                  _typeButton(_EntryKind.income, 'Ingreso',
                      Icons.arrow_downward_rounded),
                  _typeButton(_EntryKind.transfer, 'Transferencia',
                      Icons.swap_horiz_rounded),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Monto ──────────────────────────────────────────────────────
            _buildAmountSection(currencySymbol),
            const SizedBox(height: 14),

            // ── Cuenta ─────────────────────────────────────────────────────
            if (_kind != _EntryKind.transfer)
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (accounts) => _buildDropdown(
                  label: 'Cuenta',
                  icon: Icons.credit_card_rounded,
                  value: _selectedAccountId,
                  items: accounts
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              a.type == AccountType.creditCard
                                  ? '${a.name} — ${a.nickname}'
                                  : a.name,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                  isDark: isDark,
                ),
              ),

            if (_kind == _EntryKind.transfer) ...[
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (accounts) => _buildDropdown(
                  label: 'Cuenta origen',
                  icon: Icons.call_made_rounded,
                  value: _selectedAccountId,
                  items: accounts
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              a.type == AccountType.creditCard
                                  ? '${a.name} — ${a.nickname}'
                                  : a.name,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 14),
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (accounts) => _buildDropdown(
                  label: 'Cuenta destino',
                  icon: Icons.call_received_rounded,
                  value: _selectedToAccountId,
                  items: accounts
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              a.type == AccountType.creditCard
                                  ? '${a.name} — ${a.nickname}'
                                  : a.name,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedToAccountId = v),
                  isDark: isDark,
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Categoría ──────────────────────────────────────────────────
            if (_kind != _EntryKind.transfer)
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (categories) {
                  final filtered = categories
                      .where((c) => c.type.name == _kind.asTransactionType().name)
                      .toList();
                  return _buildField(
                    isDark: isDark,
                    child: CategoryPickerField(
                      label: 'Categoria',
                      categories: filtered,
                      value: _selectedCategoryId,
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                  );
                },
              ),

            const SizedBox(height: 14),

            // ── Rendimiento ────────────────────────────────────────────────
            if (_kind != _EntryKind.transfer)
              vehiclesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (vehicles) {
                  _vehiclesCache = vehicles;
                  return _buildDropdown(
                    label: 'Relacionar rendimiento (opcional)',
                    icon: Icons.track_changes_rounded,
                    value: _selectedPerformanceId ?? 'none',
                    items: [
                      const DropdownMenuItem(
                        value: 'none',
                        child: Text('Sin rendimiento'),
                      ),
                      ...vehicles.map((v) => DropdownMenuItem(
                            value: v.id,
                            child: Text(v.name),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedPerformanceId = v == 'none' ? null : v;
                        if (_selectedPerformanceId == null) {
                          _recordPerformanceData = false;
                        } else if (_recordPerformanceData) {
                          _prefillPerformance(_selectedPerformanceId, vehicles);
                        }
                      });
                    },
                    isDark: isDark,
                  );
                },
              ),

            if (_kind != _EntryKind.transfer && _selectedPerformanceId != null)
              _buildField(
                isDark: isDark,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _recordPerformanceData,
                  onChanged: (value) {
                    setState(() {
                      _recordPerformanceData = value;
                      if (value) {
                        _prefillPerformance(
                          _selectedPerformanceId,
                          _vehiclesCache,
                        );
                      }
                    });
                  },
                  title: const Text(
                    'Registrar datos del rendimiento',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Activalo solo si quieres guardar medida, litros u odometro.',
                    style: TextStyle(color: AppTheme.textMuted(context)),
                  ),
                ),
              ),

            if (_kind != _EntryKind.transfer &&
                _selectedPerformanceId != null &&
                _recordPerformanceData) ...[
              const SizedBox(height: 14),
              _buildPerformanceFields(isDark),
            ],

            const SizedBox(height: 14),

            // ── Fecha ──────────────────────────────────────────────────────
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
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2027),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AppTheme.primaryColor,
                          onSurface: Colors.white,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            ),

            const SizedBox(height: 14),

            // ── Etiquetas ──────────────────────────────────────────────────
            _buildField(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.sell_outlined, size: 20, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('Etiquetas', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (prefs.availableTags.isEmpty)
                    Text(
                      'Sin etiquetas disponibles. Agrégalas en Configuración.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: prefs.availableTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : null)),
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

            const SizedBox(height: 14),

            // ── Nota ───────────────────────────────────────────────────────
            _buildField(
              isDark: isDark,
              child: TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Nota o descripción (opcional)',
                  prefixIcon: Icon(Icons.notes_rounded,
                      color: AppTheme.primaryColor),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Boton Guardar ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => _onPressSave(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        _saving ? 'Guardando...' : 'Guardar movimiento',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _typeButton(_EntryKind kind, String label, IconData icon) {
    final isSelected = _kind == kind;
    final color = kind == _EntryKind.expense
        ? const Color(0xFFEF5350)
        : kind == _EntryKind.income
            ? const Color(0xFF4CAF50)
            : AppTheme.primaryColor;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _kind = kind;
              _selectedCategoryId = null;
              if (_kind == _EntryKind.transfer) {
                _selectedPerformanceId = null;
                _recordPerformanceData = false;
              }
            });
          },
          icon: Icon(icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade500),
          label: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountSection(String currencySymbol) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.panel(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(
                '$currencySymbol ',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00 (ej. 100+50*(2))',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Calcular',
                icon: const Icon(
                  Icons.calculate_rounded,
                  color: AppTheme.primaryColor,
                ),
                onPressed: () {
                  final value = _parseAmount(_amountController.text);
                  if (value == null) {
                    _showSnack('Expresion invalida');
                    return;
                  }
                  _amountController.text = value.toStringAsFixed(2);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final token in const ['+', '-', '*', '/', '(', ')'])
              _operatorChip(token),
            OutlinedButton.icon(
              onPressed: _backspaceAmount,
              icon: const Icon(Icons.backspace_outlined, size: 16),
              label: const Text('Borrar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _operatorChip(String value) {
    return OutlinedButton(
      onPressed: () => _insertAmountToken(value),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        side: const BorderSide(color: AppTheme.primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  void _insertAmountToken(String token) {
    final value = _amountController.value;
    final text = value.text;
    final start = value.selection.start >= 0 ? value.selection.start : text.length;
    final end = value.selection.end >= 0 ? value.selection.end : text.length;
    final newText = text.replaceRange(start, end, token);
    final cursor = start + token.length;
    _amountController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  void _backspaceAmount() {
    final value = _amountController.value;
    final text = value.text;
    if (text.isEmpty) return;
    final start = value.selection.start >= 0 ? value.selection.start : text.length;
    final end = value.selection.end >= 0 ? value.selection.end : text.length;

    if (start != end) {
      final newText = text.replaceRange(start, end, '');
      _amountController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
      return;
    }

    if (start == 0) return;
    final newText = text.replaceRange(start - 1, start, '');
    _amountController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start - 1),
    );
  }

  Widget _buildField({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDarkHigh : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: child,
    );
  }

  void _prefillPerformance(String? id, List<Vehicle> vehicles) {
    final v = vehicles.firstWhere(
      (e) => e.id == id,
      orElse: () => Vehicle(
        id: '',
        name: '',
        type: 'car',
        kind: 'vehicle',
        measureUnit: 'km',
      ),
    );
    if (v.id.isEmpty) return;
    if (v.isVehicle) {
      _perfUnit = _perfUnit == 'gal' ? 'gal' : 'L';
      _perfOdomController.text = v.odometer.toStringAsFixed(0);
    } else {
      _perfMeasureController.text = v.odometer.toStringAsFixed(1);
    }
  }

  Widget _buildPerformanceFields(bool isDark) {
    final v = _vehiclesCache.firstWhere(
      (e) => e.id == _selectedPerformanceId,
      orElse: () => Vehicle(
        id: '',
        name: '',
        type: 'car',
        kind: 'vehicle',
        measureUnit: 'km',
      ),
    );
    if (v.id.isEmpty) return const SizedBox.shrink();

    if (v.isVehicle) {
      return Column(
        children: [
          const SizedBox(height: 14),
          _buildField(
            isDark: isDark,
            child: TextField(
              controller: _perfQtyController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: InputBorder.none,
                labelText: 'Cantidad de combustible',
                prefixIcon:
                    Icon(Icons.local_gas_station, color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildDropdown(
            label: 'Unidad',
            icon: Icons.straighten,
            value: _perfUnit,
            items: const [
              DropdownMenuItem(value: 'L', child: Text('Litros')),
              DropdownMenuItem(value: 'gal', child: Text('Galones')),
            ],
            onChanged: (v) => setState(() => _perfUnit = v ?? 'L'),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildField(
            isDark: isDark,
            child: TextField(
              controller: _perfOdomController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                labelText: 'Odómetro actual (km)',
                prefixIcon: Icon(Icons.speed, color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildField(
            isDark: isDark,
            child: TextField(
              controller: _perfStationController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                labelText: 'Gasolinera (opcional)',
                prefixIcon:
                    Icon(Icons.storefront_rounded, color: AppTheme.primaryColor),
              ),
            ),
          ),
        ],
      );
    }

    final label = v.kind == 'energy' ? 'Energía' : 'Créditos';
    return Column(
      children: [
        const SizedBox(height: 14),
        _buildField(
          isDark: isDark,
          child: TextField(
            controller: _perfMeasureController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: '$label actual (${v.measureUnit})',
              prefixIcon:
                  const Icon(Icons.track_changes, color: AppTheme.primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDarkHigh : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items,
        onChanged: enabled ? onChanged : null,
        isExpanded: true,
        dropdownColor: isDark ? AppTheme.surfaceDarkHigh : AppTheme.surfaceLight,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  void _onPressSave() async {
    final periods = ref.read(periodsStreamProvider).value ?? [];
    if (periods.isEmpty) {
      _showSnack('No hay periodos configurados.');
      return;
    }

    Period? targetPeriod;
    try {
      final sortedPeriods = [...periods]
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

      targetPeriod = sortedPeriods.firstWhere(
        (p) => (_date.isAfter(p.startDate) || _date.isAtSameMomentAs(p.startDate)) &&
               (_date.isBefore(p.endDate) || _date.isAtSameMomentAs(p.endDate)),
      );
    } catch (_) {
      targetPeriod = null;
    }

    if (targetPeriod != null) {
      _save(targetPeriod);
      return;
    }

    final lastPeriod = periods.isNotEmpty 
        ? (List<Period>.from(periods)..sort((a, b) => b.endDate.compareTo(a.endDate))).first 
        : null;

    if (lastPeriod == null) {
      _showSnack('No se encontró un periodo para esta fecha y no hay base para crear uno nuevo.');
      return;
    }

    // Proponer creación inteligente
    final newPeriod = await _showCreatePeriodDialog(context, _date, lastPeriod);
    if (newPeriod != null) {
      _save(newPeriod);
    }
  }

  Future<Period?> _showCreatePeriodDialog(BuildContext context, DateTime targetDate, Period lastPeriod) async {
    final duration = lastPeriod.endDate.difference(lastPeriod.startDate);
    final newEndDate = targetDate.add(duration);
    
    final monthName = DateFormat('MMMM yyyy', 'es').format(targetDate);
    final suggestedName = 'Periodo $monthName';

    return showDialog<Period?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear nuevo periodo'),
        content: Text(
          'No existe un periodo para el ${DateFormat('dd/MM/yyyy').format(targetDate)}.\n\n'
          '¿Deseas crear uno nuevo automáticamente?\n'
          'Sugerido: $suggestedName\n'
          'Desde: ${DateFormat('dd/MM/yyyy').format(targetDate)}\n'
          'Hasta: ${DateFormat('dd/MM/yyyy').format(newEndDate)}'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              final svc = ref.read(firestoreServiceProvider);
              
              final p = Period(
                id: '',
                name: suggestedName,
                startDate: targetDate,
                endDate: newEndDate,
                isActive: false,
                budgets: {},
              );
              
              final newId = await svc.addPeriod(user.uid, p);
              if (ctx.mounted) {
                Navigator.pop(ctx, p.copyWithId(newId));
              }
            },
            child: const Text('Crear y Guardar'),
          ),
        ],
      ),
    );
  }

  void _save(Period period) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnack('Ingresa un monto');
      return;
    }
    final amount = _parseAmount(amountText);
    if (amount == null) {
      _showSnack('Monto inválido');
      return;
    }

    if (_selectedAccountId == null) {
      _showSnack('Selecciona una cuenta');
      return;
    }

    if (_kind != _EntryKind.transfer && _selectedCategoryId == null) {
      _showSnack('Selecciona una categoría');
      return;
    }

    if (_kind == _EntryKind.transfer && _selectedToAccountId == null) {
      _showSnack('Selecciona cuenta destino');
      return;
    }

    setState(() => _saving = true);
    final user = ref.read(currentUserProvider);
    final svc = ref.read(firestoreServiceProvider);

    try {
      if (user == null) throw 'No user';

      if (_kind == _EntryKind.transfer) {
        final group = 'transfer_${DateTime.now().millisecondsSinceEpoch}';
        final cats = await svc.ensureTransferCategories(user.uid);

        // Salida
        await svc.addTransaction(
          user.uid,
          TransactionRecord(
            id: '',
            accountId: _selectedAccountId!,
            categoryId: cats.expenseId,
            amount: amount,
            date: _date,
            note: _noteController.text,
            type: TransactionType.expense,
            isTransfer: true,
            transferAccountId: _selectedToAccountId,
            transferGroupId: group,
            periodId: period.id,
            tags: _selectedTags,
          ),
        );
        // Entrada
        await svc.addTransaction(
          user.uid,
          TransactionRecord(
            id: '',
            accountId: _selectedToAccountId!,
            categoryId: cats.incomeId,
            amount: amount,
            date: _date,
            note: _noteController.text,
            type: TransactionType.income,
            isTransfer: true,
            transferAccountId: _selectedAccountId,
            transferGroupId: group,
            periodId: period.id,
            tags: _selectedTags,
          ),
        );
      } else {
        final tx = TransactionRecord(
          id: '',
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId!,
          amount: amount,
          date: _date,
          note: _noteController.text,
          type: _kind.asTransactionType(),
          periodId: period.id,
          tags: _selectedTags,
          linkedPerformanceId: _selectedPerformanceId,
        );
        await svc.addTransaction(user.uid, tx);

        // Rendimiento
        if (_selectedPerformanceId != null && _recordPerformanceData) {
          final odometer = double.tryParse(_perfOdomController.text) ?? 
                          double.tryParse(_perfMeasureController.text) ?? 0;
          final qty = double.tryParse(_perfQtyController.text) ?? 0;
          
          await svc.addFuelRecord(
            user.uid,
            _selectedPerformanceId!,
            FuelRecord(
              id: '',
              vehicleId: _selectedPerformanceId!,
              date: _date,
              liters: qty,
              unit: _perfUnit,
              odometerAtFill: odometer,
              stationName: _perfStationController.text,
              pricePerLiter: (qty > 0) ? (amount / qty) : 0,
            ),
          );
        }
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showSnack('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double? _parseAmount(String val) {
    if (val.isEmpty) return null;
    try {
      final clean = val.replaceAll(',', '').trim();
      if (double.tryParse(clean) != null) return double.parse(clean);

      final tokens = _tokenize(clean);
      if (tokens == null) return null;
      final rpn = _toRpn(tokens);
      if (rpn == null) return null;
      return _evalRpn(rpn);
    } catch (_) {
      return null;
    }
  }

  List<String>? _tokenize(String s) {
    final tokens = <String>[];
    int i = 0;
    while (i < s.length) {
      final ch = s[i];
      if (ch == ' ') { i++; continue; }
      if (_isDigit(ch) || ch == '.') {
        var numStr = '';
        while (i < s.length && (_isDigit(s[i]) || s[i] == '.')) {
          numStr += s[i];
          i++;
        }
        tokens.add(numStr);
        continue;
      }
      if (_isOperator(ch) || ch == '(' || ch == ')') {
        tokens.add(ch);
        i++;
        continue;
      }
      return null;
    }
    return tokens;
  }

  List<String>? _toRpn(List<String> tokens) {
    final output = <String>[];
    final ops = <String>[];
    for (final t in tokens) {
      if (_isNumber(t)) {
        output.add(t);
      } else if (_isOperator(t)) {
        while (ops.isNotEmpty && _isOperator(ops.last) && _precedence(ops.last) >= _precedence(t)) {
          output.add(ops.removeLast());
        }
        ops.add(t);
      } else if (t == '(') {
        ops.add(t);
      } else if (t == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          output.add(ops.removeLast());
        }
        if (ops.isEmpty) return null;
        ops.removeLast();
      }
    }
    while (ops.isNotEmpty) {
      if (ops.last == '(') return null;
      output.add(ops.removeLast());
    }
    return output;
  }

  double? _evalRpn(List<String> rpn) {
    final stack = <double>[];
    for (final t in rpn) {
      if (_isNumber(t)) {
        stack.add(double.parse(t));
      } else {
        if (stack.length < 2) return null;
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (t) {
          case '+': stack.add(a + b); break;
          case '-': stack.add(a - b); break;
          case '*': stack.add(a * b); break;
          case '/': stack.add(b == 0 ? 0 : a / b); break;
        }
      }
    }
    return stack.isEmpty ? null : stack.last;
  }

  bool _isDigit(String s) => RegExp(r'[0-9]').hasMatch(s);
  bool _isOperator(String s) => s == '+' || s == '-' || s == '*' || s == '/';
  bool _isNumber(String s) => double.tryParse(s) != null;
  int _precedence(String op) => (op == '+' || op == '-') ? 1 : 2;
}

enum _EntryKind { expense, income, transfer }

extension on _EntryKind {
  TransactionType asTransactionType() {
    switch (this) {
      case _EntryKind.income: return TransactionType.income;
      case _EntryKind.expense: return TransactionType.expense;
      case _EntryKind.transfer: return TransactionType.expense;
    }
  }
}
