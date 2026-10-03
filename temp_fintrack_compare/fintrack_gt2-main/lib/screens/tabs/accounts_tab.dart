import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/firestore_providers.dart';
import '../../theme/app_theme.dart';
import '../edit_account_screen.dart';

class AccountsTab extends ConsumerWidget {
  const AccountsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final isDark = AppTheme.isDark(context);
    final prefs = ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final currencyFormat = prefs.currencyFormat();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: accountsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return _NoAccountsPlaceholder(isDark: isDark);
          }
          final balances = ref.watch(accountBalancesProvider);
          return _AccountsBody(
            accounts: accounts,
            balances: balances,
            isDark: isDark,
            currencyFormat: currencyFormat,
          );
        },
      ),
    );
  }
}

class _NoAccountsPlaceholder extends StatelessWidget {
  final bool isDark;
  const _NoAccountsPlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off_rounded,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.8)),
          const SizedBox(height: 24),
          Text(
            'Registra tus tarjetas o efectivo para\ncomenzar a organizar tu dinero.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 15),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EditAccountScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Agregar mi primera cuenta',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY CON DATOS
// ─────────────────────────────────────────────────────────────────────────────

class _AccountsBody extends StatelessWidget {
  final List<Account> accounts;
  final Map<String, double> balances;
  final bool isDark;
  final NumberFormat currencyFormat;

  const _AccountsBody({
    required this.accounts,
    required this.balances,
    required this.isDark,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final creditCards =
        accounts.where((a) => a.type == AccountType.creditCard).toList();
    final savingsAccounts =
        accounts.where((a) => a.type == AccountType.savings).toList();
    final cashAccounts =
        accounts.where((a) => a.type == AccountType.cash).toList();

    final totalDebt = creditCards.fold<double>(0.0, (sum, a) {
      final debt = balances[a.id] ?? a.currentDebt;
      return sum + debt;
    });

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, totalDebt, currencyFormat),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              _sectionLabel(context, 'TARJETAS DE CRÉDITO'),
              const SizedBox(height: 8),
              ...creditCards.map((acc) => _AccountCard(
                  account: acc,
                  balance: balances[acc.id],
                  isDark: isDark,
                  currencyFormat: currencyFormat)),
              if (savingsAccounts.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionLabel(context, 'AHORRO'),
                const SizedBox(height: 8),
                ...savingsAccounts.map((acc) => _AccountCard(
                    account: acc,
                    balance: balances[acc.id],
                    isDark: isDark,
                    currencyFormat: currencyFormat)),
              ],
              const SizedBox(height: 20),
              _sectionLabel(context, 'EFECTIVO'),
              const SizedBox(height: 8),
              ...cashAccounts.map((acc) => _AccountCard(
                  account: acc,
                  balance: balances[acc.id],
                  isDark: isDark,
                  currencyFormat: currencyFormat)),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppTheme.textMuted(context),
      ),
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, double totalDebt, NumberFormat currency) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppTheme.navBackground(context),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            color: AppTheme.navBackground(context),
            border: Border(
              bottom: BorderSide(color: AppTheme.border(context)),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Total en tarjetas',
                  style: TextStyle(
                    color: AppTheme.textMuted(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currency.format(totalDebt),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      title: const Text(
        'Mis Cuentas',
        style: TextStyle(color: AppTheme.textPrimaryDark, fontWeight: FontWeight.w700),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded, color: AppTheme.textPrimaryDark),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EditAccountScreen(),
                fullscreenDialog: true,
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE CUENTA
// ─────────────────────────────────────────────────────────────────────────────

class _AccountCard extends ConsumerStatefulWidget {
  final Account account;
  final double? balance;
  final bool isDark;
  final NumberFormat currencyFormat;

  const _AccountCard(
      {required this.account,
      required this.balance,
      required this.isDark,
      required this.currencyFormat});

  @override
  ConsumerState<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<_AccountCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final acc = widget.account;
    final isCashLike = acc.type != AccountType.creditCard;
    final daysLeft = isCashLike ? 999 : acc.daysUntilPayment();
    final trafficColor = _trafficColor(daysLeft, isCashLike);
    final rawAmount = widget.balance ?? acc.currentDebt;
    final currentAmount = rawAmount.toDouble();
    final currency = widget.currencyFormat;
    final cardBg = widget.isDark ? AppTheme.surfaceDarkHigh : AppTheme.surfaceLight;

    final isCard = acc.type == AccountType.creditCard;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: trafficColor.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: acc.installments.isNotEmpty
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _mainRow(acc, isCashLike, daysLeft, trafficColor, currency,
                    currentAmount),
                if (_expanded && acc.installments.isNotEmpty) ...[
                  const Divider(height: 24),
                  _installmentsList(acc, currency),
                ],
                if (isCard) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showPaymentDialog(context, ref, acc, currentAmount),
                          icon: const Icon(Icons.payments_rounded, size: 18),
                          label: const Text('Pagar tarjeta'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: acc.installments.isEmpty
                              ? null
                              : () => _showInstallmentsDialog(context, ref, acc),
                          icon: const Icon(Icons.credit_card_rounded, size: 18),
                          label: const Text('Pagar cuotas'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mainRow(
    Account acc,
    bool isCash,
    int daysLeft,
    Color trafficColor,
    NumberFormat currency,
    double currentAmount,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Indicador semáforo ────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 5,
          height: 60,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: trafficColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: trafficColor.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),

        // ── Info cuenta ────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _bankChip(acc.bankName),
                  const SizedBox(width: 8),
                  if (acc.installments.isNotEmpty)
                    const Icon(Icons.expand_more, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                acc.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              if (acc.nickname.isNotEmpty)
                Text(
                  '\"${acc.nickname}\"',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (!isCash) ...[
                const SizedBox(height: 6),
                Text(
                  'Corte: día ${acc.cutDay}  •  Pago: día ${acc.paymentDay}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),

        // ── Deuda y días ───────────────────────────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _AccountMenuButton(account: acc, currentAmount: currentAmount),
            const SizedBox(height: 6),
            if (!isCash)
              _daysChip(daysLeft, trafficColor)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  acc.type == AccountType.savings ? 'Ahorro' : 'Efectivo',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              currency.format(currentAmount),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
            Text(
              isCash ? 'saldo actual' : 'deuda actual',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _installmentsList(Account acc, NumberFormat currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cuotas fijas de esta tarjeta',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        ...acc.installments.map(
          (inst) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inst.description,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${currency.format(inst.monthlyAmount)} • Cuotas ${inst.totalMonths - inst.remainingMonths}/${inst.totalMonths} • Restantes ${inst.remainingMonths}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total ${currency.format(inst.totalValue)} • Pendiente ${currency.format(inst.remainingValue)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Total cuotas: ${currency.format(acc.monthlyInstallmentsTotal)}/mes',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Total ${currency.format(acc.installmentsTotalValue)} • Pendiente ${currency.format(acc.installmentsRemainingValue)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        if (acc.installments.any((i) => i.endDate != null)) ...[
          const SizedBox(height: 6),
          Text(
            'Última finaliza: ${_latestEndDate(acc)}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _bankChip(String bankName) {
    if (bankName.isEmpty) return const SizedBox.shrink();
    final (bg, fg) = _bankColors(bankName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        bankName,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  (Color, Color) _bankColors(String bank) {
    switch (bank.toUpperCase()) {
      case 'BI':
        return (const Color(0xFF003D82), Colors.white);
      case 'BAC':
        return (const Color(0xFFE60026), Colors.white);
      case 'BANRURAL':
        return (const Color(0xFF00723E), Colors.white);
      default:
        return (AppTheme.primaryColor, Colors.black);
    }
  }

  Widget _daysChip(int days, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_trafficIcon(days), size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            days == 0
                ? '¡HOY!'
                : days == 1
                    ? '1 día'
                    : '$days días',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _trafficColor(int days, bool isCash) {
    if (isCash) return AppTheme.accentColor;
    if (days > 20) return const Color(0xFF4CAF50);
    if (days >= 10) return const Color(0xFFFFB300);
    return const Color(0xFFEF5350);
  }

  IconData _trafficIcon(int days) {
    if (days > 20) return Icons.check_circle;
    if (days >= 10) return Icons.schedule;
    return Icons.warning_rounded;
  }
}

String _latestEndDate(Account acc) {
  DateTime? latest;
  for (final i in acc.installments) {
    final end = i.endDate;
    if (end == null) continue;
    if (latest == null || end.isAfter(latest)) latest = end;
  }
  if (latest == null) return '-';
  final fmt = DateFormat('dd/MM/yyyy');
  return fmt.format(latest);
}

class _AccountMenuButton extends ConsumerWidget {
  final Account account;
  final double currentAmount;

  const _AccountMenuButton({required this.account, required this.currentAmount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.panelAlt(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 16,
          color: AppTheme.textMuted(context),
        ),
      ),
      onSelected: (value) async {
        if (value == 'edit') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EditAccountScreen(account: account),
              fullscreenDialog: true,
            ),
          );
          return;
        }
        if (value == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Eliminar cuenta'),
              content: Text('¿Seguro que deseas eliminar \"${account.name}\"?'),
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
          await svc.deleteAccount(user.uid, account.id);
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'edit', child: Text('Editar')),
        const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
      ],
    );
  }
}

enum _PaymentKind { full, minimum, custom }

Future<void> _showPaymentDialog(BuildContext context, WidgetRef ref,
    Account account, double currentAmount) async {
  if (currentAmount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay deuda para pagar')),
    );
    return;
  }

  final period = ref.read(activePeriodProvider).value;
  if (period == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay período activo')),
    );
    return;
  }

  final amountCtrl = TextEditingController();
  _PaymentKind kind = _PaymentKind.full;

  final minAmount = (currentAmount * 0.1);
  amountCtrl.text = currentAmount.toStringAsFixed(2);

  String? sourceId;
  await showDialog(
    context: context,
    builder: (ctx) {
      return Consumer(
        builder: (ctx, ref, _) {
          final accountsAsync = ref.watch(accountsStreamProvider);
          return accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const AlertDialog(content: Text('Error al cargar cuentas')),
            data: (accounts) {
              final sources = accounts.where((a) => a.id != account.id).toList();
              sourceId ??= sources.isNotEmpty ? sources.first.id : null;
              return StatefulBuilder(
                builder: (ctx, setLocal) {
                  return AlertDialog(
                    title: const Text('Registrar pago'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: sourceId,
                          items: sources
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name),
                                  ))
                              .toList(),
                          onChanged: (v) => setLocal(() => sourceId = v),
                          decoration: const InputDecoration(
                            labelText: 'Cuenta de origen',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<_PaymentKind>(
                          value: kind,
                          items: const [
                            DropdownMenuItem(
                              value: _PaymentKind.full,
                              child: Text('Contado'),
                            ),
                            DropdownMenuItem(
                              value: _PaymentKind.minimum,
                              child: Text('Mínimo'),
                            ),
                            DropdownMenuItem(
                              value: _PaymentKind.custom,
                              child: Text('Personalizado'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setLocal(() => kind = v);
                            if (v == _PaymentKind.full) {
                              amountCtrl.text = currentAmount.toStringAsFixed(2);
                            } else if (v == _PaymentKind.minimum) {
                              amountCtrl.text = minAmount.toStringAsFixed(2);
                            }
                          },
                          decoration: const InputDecoration(labelText: 'Tipo'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(labelText: 'Monto'),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final amount = double.tryParse(amountCtrl.text) ?? 0;
                          if (amount <= 0 || sourceId == null) return;
                          final user = ref.read(currentUserProvider);
                          if (user == null) return;
                          final svc = ref.read(firestoreServiceProvider);
                          final transferCats =
                              await svc.ensureTransferCategories(user.uid);
                          final transferId =
                              DateTime.now().microsecondsSinceEpoch.toString();
                          final outTx = TransactionRecord(
                            id: '',
                            amount: amount,
                            type: TransactionType.expense,
                            accountId: sourceId!,
                            categoryId: transferCats.expenseId,
                            periodId: period.id,
                            date: DateTime.now(),
                            note: 'Pago tarjeta ${account.name}',
                            paymentMethod: PaymentMethod.transfer,
                            isTransfer: true,
                            transferAccountId: account.id,
                            transferGroupId: transferId,
                          );
                          final inTx = TransactionRecord(
                            id: '',
                            amount: amount,
                            type: TransactionType.income,
                            accountId: account.id,
                            categoryId: transferCats.incomeId,
                            periodId: period.id,
                            date: DateTime.now(),
                            note: 'Pago recibido',
                            paymentMethod: PaymentMethod.transfer,
                            isTransfer: true,
                            transferAccountId: sourceId,
                            transferGroupId: transferId,
                          );
                          await svc.addTransaction(user.uid, outTx);
                          await svc.addTransaction(user.uid, inTx);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                        child: const Text('Registrar'),
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
  );
}

Future<void> _showInstallmentsDialog(
    BuildContext context, WidgetRef ref, Account account) async {
  final prefs =
      ref.read(userPreferencesProvider).value ?? const UserPreferences();
  final currency = prefs.currencyFormat();
  final period = ref.read(activePeriodProvider).value;
  if (period == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay período activo')),
    );
    return;
  }

  if (account.installments.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hay cuotas registradas')),
    );
    return;
  }

  String? sourceAccountId;
  final selected = <int>{
    for (var i = 0; i < account.installments.length; i++) i
  };

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final accountsAsync = ref.watch(accountsStreamProvider);
          return AlertDialog(
            title: const Text('Registrar cuotas'),
            content: SizedBox(
              width: 300,
              child: ListView(
                shrinkWrap: true,
                children: [
                  accountsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (accounts) {
                      final sources =
                          accounts.where((a) => a.id != account.id).toList();
                      sourceAccountId ??=
                          sources.isNotEmpty ? sources.first.id : null;
                      return DropdownButtonFormField<String>(
                        value: sourceAccountId,
                        items: sources
                            .map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.name),
                                ))
                            .toList(),
                        onChanged: (v) => setLocal(() => sourceAccountId = v),
                        decoration: const InputDecoration(
                          labelText: 'Cuenta de origen',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ...account.installments.asMap().entries.map((entry) {
                    final i = entry.key;
                    final inst = entry.value;
                    final checked = selected.contains(i);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            selected.add(i);
                          } else {
                            selected.remove(i);
                          }
                        });
                      },
                      title: Text(inst.description),
                      subtitle: Text(
                          '${currency.format(inst.monthlyAmount)} • Cuotas ${inst.totalMonths - inst.remainingMonths}/${inst.totalMonths} • Restantes ${inst.remainingMonths}\n'
                          'Total ${currency.format(inst.totalValue)} • Pendiente ${currency.format(inst.remainingValue)}'),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  if (selected.isEmpty) return;
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;
                  final svc = ref.read(firestoreServiceProvider);
                  final catId = await svc.ensureInstallmentsCategory(user.uid);
                  final transferCats =
                      await svc.ensureTransferCategories(user.uid);
                  final now = DateTime.now();
                  final updated = [...account.installments];
                  if (sourceAccountId == null) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Selecciona cuenta de origen')),
                      );
                    }
                    return;
                  }
                  final txs = <TransactionRecord>[];
                  for (final i in selected) {
                    final inst = account.installments[i];
                    final instId = inst.id.isNotEmpty
                        ? inst.id
                        : DateTime.now().microsecondsSinceEpoch.toString();
                    final groupId =
                        DateTime.now().microsecondsSinceEpoch.toString();
                    final nextRemaining =
                        inst.remainingMonths > 0 ? inst.remainingMonths - 1 : 0;
                    updated[i] = Installment(
                      id: instId,
                      description: inst.description,
                      monthlyAmount: inst.monthlyAmount,
                      totalMonths: inst.totalMonths,
                      remainingMonths: nextRemaining,
                      startDate: inst.startDate,
                    );
                    // Egreso desde cuenta origen (categoría cuotas)
                    txs.add(TransactionRecord(
                      id: '',
                      amount: inst.monthlyAmount,
                      type: TransactionType.expense,
                      accountId: sourceAccountId!,
                      categoryId: catId,
                      periodId: period.id,
                      date: now,
                      note: 'Cuota ${inst.description}',
                      paymentMethod: PaymentMethod.transfer,
                      isInstallment: true,
                      installmentId: instId,
                      transferGroupId: groupId,
                    ));
                    // Ingreso a tarjeta (reduce deuda)
                    txs.add(TransactionRecord(
                      id: '',
                      amount: inst.monthlyAmount,
                      type: TransactionType.income,
                      accountId: account.id,
                      categoryId: transferCats.incomeId,
                      periodId: period.id,
                      date: now,
                      note: 'Pago cuota ${inst.description}',
                      paymentMethod: PaymentMethod.transfer,
                      isTransfer: true,
                      transferAccountId: sourceAccountId,
                      transferGroupId: groupId,
                    ));
                  }
                  await svc.addTransactionsBatch(user.uid, txs);
                  await svc.updateAccount(
                      user.uid, account.id, account.copyWith(installments: updated).toMap());
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                },
                child: const Text('Registrar'),
              ),
            ],
          );
        },
      );
    },
  );
}
