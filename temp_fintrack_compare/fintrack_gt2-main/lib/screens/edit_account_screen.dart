import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/firestore_providers.dart';
import '../theme/app_theme.dart';

class EditAccountScreen extends ConsumerStatefulWidget {
  final Account? account;

  const EditAccountScreen({super.key, this.account});

  @override
  ConsumerState<EditAccountScreen> createState() =>
      _EditAccountScreenState();
}

class _EditAccountScreenState extends ConsumerState<EditAccountScreen> {
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _bankController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _cutDayController = TextEditingController();
  final _paymentDayController = TextEditingController();
  final _graceDaysController = TextEditingController();
  final _currentDebtController = TextEditingController();

  late AccountType _type;
  bool _saving = false;
  late List<Installment> _installments;

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _type = acc?.type ?? AccountType.cash;
    _installments = List<Installment>.from(acc?.installments ?? const []);
    if (acc != null) {
      _nameController.text = acc.name;
      _nicknameController.text = acc.nickname;
      _bankController.text = acc.bankName;
      if (acc.creditLimit != null) {
        _creditLimitController.text = acc.creditLimit!.toString();
      }
      if (acc.cutDay != null) {
        _cutDayController.text = acc.cutDay!.toString();
      }
      if (acc.paymentDay != null) {
        _paymentDayController.text = acc.paymentDay!.toString();
      }
      if (acc.graceDays != null) {
        _graceDaysController.text = acc.graceDays!.toString();
      }
      if (acc.currentDebt != 0) {
        _currentDebtController.text = acc.currentDebt.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _bankController.dispose();
    _creditLimitController.dispose();
    _cutDayController.dispose();
    _paymentDayController.dispose();
    _graceDaysController.dispose();
    _currentDebtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final prefs = ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final currency = prefs.currencyFormat();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: Text(widget.account == null
            ? 'Nueva Cuenta'
            : 'Editar Cuenta'),
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
            _buildField(
              isDark: isDark,
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Nombre',
                  prefixIcon:
                      Icon(Icons.account_balance_wallet_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildField(
              isDark: isDark,
              child: TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Alias (opcional)',
                  prefixIcon: Icon(Icons.short_text_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildDropdown(
              label: 'Tipo de cuenta',
              icon: Icons.category_rounded,
              value: _type,
              items: const [
                DropdownMenuItem(
                  value: AccountType.creditCard,
                  child: Text('Tarjeta de crédito'),
                ),
                DropdownMenuItem(
                  value: AccountType.savings,
                  child: Text('Ahorro'),
                ),
                DropdownMenuItem(
                  value: AccountType.cash,
                  child: Text('Efectivo'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _type = v);
              },
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            _buildField(
              isDark: isDark,
              child: TextField(
                controller: _bankController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Banco (opcional)',
                  prefixIcon: Icon(Icons.account_balance_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildField(
              isDark: isDark,
              child: TextField(
                controller: _currentDebtController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  labelText: _type == AccountType.creditCard
                      ? 'Deuda actual'
                      : 'Saldo actual',
                  prefixIcon: const Icon(Icons.payments_rounded),
                ),
              ),
            ),
            if (_type == AccountType.creditCard) ...[
              const SizedBox(height: 14),
              _buildField(
                isDark: isDark,
                child: TextField(
                  controller: _creditLimitController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: 'Límite de crédito (opcional)',
                    prefixIcon: Icon(Icons.credit_card_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildField(
                isDark: isDark,
                child: TextField(
                  controller: _cutDayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: 'Día de corte',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildField(
                isDark: isDark,
                child: TextField(
                  controller: _paymentDayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: 'Día de pago',
                    prefixIcon: Icon(Icons.event_available_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildField(
                isDark: isDark,
                child: TextField(
                  controller: _graceDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: 'Días de gracia (opcional)',
                    prefixIcon: Icon(Icons.timelapse_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _buildInstallmentsSection(isDark),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, color: Colors.white),
                label: Text(
                  _saving ? 'Guardando...' : 'Guardar cuenta',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required AccountType value,
    required List<DropdownMenuItem<AccountType>> items,
    required ValueChanged<AccountType?> onChanged,
    required bool isDark,
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
      child: DropdownButtonFormField<AccountType>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        dropdownColor: isDark ? AppTheme.surfaceDarkHigh : AppTheme.surfaceLight,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        ),
      ),
    );
  }

  Widget _buildInstallmentsSection(bool isDark) {
    final prefs =
        ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final currency = prefs.currencyFormat();
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_rounded,
                  color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Cuotas fijas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addInstallment,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar'),
              ),
            ],
          ),
          if (_installments.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'No hay cuotas registradas.',
              style: TextStyle(
                color: isDark ? const Color(0xFF7B7F9E) : Colors.grey,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            ..._installments.asMap().entries.map((entry) {
              final i = entry.key;
              final inst = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F0F1A)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inst.description,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${currency.format(inst.monthlyAmount)}  •  Cuotas ${inst.totalMonths - inst.remainingMonths}/${inst.totalMonths} • Restantes ${inst.remainingMonths}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF7B7F9E)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total ${currency.format(inst.totalValue)} • Pendiente ${currency.format(inst.remainingValue)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF7B7F9E)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (inst.endDate != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Finaliza: ${DateFormat('dd/MM/yyyy').format(inst.endDate!)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF7B7F9E)
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editInstallment(i),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                    ),
                    IconButton(
                      onPressed: () => _removeInstallment(i),
                      icon: const Icon(Icons.delete_rounded, size: 18),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _addInstallment() async {
    final inst = await _showInstallmentDialog();
    if (inst == null) return;
    setState(() => _installments.add(inst));
  }

  Future<void> _editInstallment(int index) async {
    final inst = await _showInstallmentDialog(
        initial: _installments[index]);
    if (inst == null) return;
    setState(() => _installments[index] = inst);
  }

  void _removeInstallment(int index) {
    setState(() => _installments.removeAt(index));
  }

  Future<Installment?> _showInstallmentDialog({Installment? initial}) {
    final descCtrl = TextEditingController(text: initial?.description ?? '');
    final amountCtrl = TextEditingController(
        text: initial?.monthlyAmount.toString() ?? '');
    final totalCtrl =
        TextEditingController(text: initial?.totalMonths.toString() ?? '');
    final remainingCtrl =
        TextEditingController(text: initial?.remainingMonths.toString() ?? '');
    DateTime? startDate = initial?.startDate ?? DateTime.now();

    return showDialog<Installment>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title:
                  Text(initial == null ? 'Nueva cuota' : 'Editar cuota'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Descripción'),
                  ),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Monto mensual'),
                  ),
                  TextField(
                    controller: totalCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Cuotas totales'),
                  ),
                  TextField(
                    controller: remainingCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Cuotas restantes'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setLocal(() => startDate = picked);
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(startDate == null
                        ? 'Seleccionar fecha de inicio'
                        : 'Inicio: ${DateFormat('dd/MM/yyyy').format(startDate!)}'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final desc = descCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    final total = int.tryParse(totalCtrl.text) ?? 0;
                    var remaining = int.tryParse(remainingCtrl.text) ?? 0;
                    if (remaining == 0 && total > 0) remaining = total;
                    if (desc.isEmpty ||
                        amount <= 0 ||
                        total <= 0 ||
                        remaining <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Completa descripción, monto y cuotas válidas')),
                      );
                      return;
                    }
                    if (remaining > total) {
                      remaining = total;
                    }
                    Navigator.of(ctx).pop(Installment(
                      id: initial?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      description: desc,
                      monthlyAmount: amount,
                      totalMonths: total,
                      remainingMonths: remaining,
                      startDate: startDate,
                    ));
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Ingresa un nombre');
      return;
    }

    final creditLimit = double.tryParse(_creditLimitController.text);
    final currentDebt = double.tryParse(_currentDebtController.text) ?? 0.0;
    final cutDay = int.tryParse(_cutDayController.text);
    final paymentDay = int.tryParse(_paymentDayController.text);
    final graceDays = int.tryParse(_graceDaysController.text);

    if (_type == AccountType.creditCard) {
      if (cutDay != null && (cutDay < 1 || cutDay > 31)) {
        _showSnack('Día de corte inválido');
        return;
      }
      if (paymentDay != null && (paymentDay < 1 || paymentDay > 31)) {
        _showSnack('Día de pago inválido');
        return;
      }
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final svc = ref.read(firestoreServiceProvider);

    setState(() => _saving = true);

    try {
      final normalizedInstallments = _installments.map((i) {
        if (i.id.isNotEmpty) return i;
        return Installment(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          description: i.description,
          monthlyAmount: i.monthlyAmount,
          totalMonths: i.totalMonths,
          remainingMonths: i.remainingMonths,
          startDate: i.startDate,
        );
      }).toList();
      final data = Account(
        id: widget.account?.id ?? '',
        name: name,
        nickname: _nicknameController.text.trim(),
        type: _type,
        creditLimit: _type == AccountType.creditCard ? creditLimit : null,
        cutDay: _type == AccountType.creditCard ? cutDay : null,
        paymentDay: _type == AccountType.creditCard ? paymentDay : null,
        graceDays: _type == AccountType.creditCard ? graceDays : null,
        currentDebt: currentDebt,
        bankName: _bankController.text.trim(),
        installments: normalizedInstallments,
      ).toMap();

      if (widget.account == null) {
        await svc.addAccount(user.uid, data);
      } else {
        await svc.updateAccount(user.uid, widget.account!.id, data);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showSnack('Error al guardar: $e');
      setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
