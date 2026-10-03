import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/firestore_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../transactions_screen.dart';
import '../periods_screen.dart';
import 'package:fintrack_gt/screens/tabs/settings_tab.dart';
import '../../utils/icon_utils.dart';

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodAsync = ref.watch(activePeriodProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.graphite : AppTheme.canvasLight,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openUserPanel(context, ref),
            child: userAsync.when(
              loading: () => const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
              ),
              error: (_, __) => const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
              data: (profile) {
                final photo = profile?.photoURL ?? '';
                if (photo.isNotEmpty) {
                  return CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(photo),
                  );
                }
                final initials = _initials(profile?.displayName ?? '');
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Text(
                    initials.isEmpty ? 'U' : initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        title: const Text(
          'Cifra',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [],
      ),
      body: periodAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (period) {
          if (period == null) {
            return _NoPeriodPlaceholder(isDark: isDark);
          }
          return _DashboardBody(period: period, isDark: isDark);
        },
      ),
    );
  }

  void _openUserPanel(BuildContext context, WidgetRef ref) {
    final profile = ref.read(userProfileProvider).value;
    final prefs =
        ref.read(userPreferencesProvider).value ?? const UserPreferences();
    final user = ref.read(currentUserProvider);
    final svc = ref.read(firestoreServiceProvider);
    final fmt = DateFormat('dd/MM/yyyy');
    final created = profile?.createdAt;
    final activeText = created == null
        ? 'Tiempo activo: -'
        : 'Activo desde ${fmt.format(created)} • ${_daysActive(created)} días';

    String currencySymbol = prefs.currencySymbol;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (ctx, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.15,
                            ),
                            backgroundImage:
                                (profile?.photoURL ?? '').isNotEmpty
                                ? NetworkImage(profile!.photoURL)
                                : null,
                            child: (profile?.photoURL ?? '').isEmpty
                                ? Text(
                                    _initials(profile?.displayName ?? ''),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (profile?.displayName ?? 'Usuario').isEmpty
                                      ? 'Usuario'
                                      : profile!.displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((profile?.email ?? '').isNotEmpty)
                                  Text(
                                    profile!.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  activeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Preferencias',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _themeTile(
                        ctx,
                        label: 'Sistema',
                        selected: prefs.themeMode == 'system',
                        onTap: user == null
                            ? null
                            : () => svc.updateUserPreferences(user.uid, {
                                'themeMode': 'system',
                              }),
                      ),
                      _themeTile(
                        ctx,
                        label: 'Claro',
                        selected: prefs.themeMode == 'light',
                        onTap: user == null
                            ? null
                            : () => svc.updateUserPreferences(user.uid, {
                                'themeMode': 'light',
                              }),
                      ),
                      _themeTile(
                        ctx,
                        label: 'Oscuro',
                        selected: prefs.themeMode == 'dark',
                        onTap: user == null
                            ? null
                            : () => svc.updateUserPreferences(user.uid, {
                                'themeMode': 'dark',
                              }),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Moneda',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: currencySymbol,
                        items: const [
                          DropdownMenuItem(
                            value: 'Q',
                            child: Text('Quetzal (Q)'),
                          ),
                          DropdownMenuItem(
                            value: '\$',
                            child: Text('Dólar (USD)'),
                          ),
                          DropdownMenuItem(
                            value: '€',
                            child: Text('Euro (EUR)'),
                          ),
                          DropdownMenuItem(
                            value: 'L',
                            child: Text('Lempira (L)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null || user == null) return;
                          setLocal(() => currencySymbol = v);
                          svc.updateUserPreferences(user.uid, {
                            'currencySymbol': v,
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Moneda por defecto',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.date_range,
                          color: AppTheme.primaryColor,
                        ),
                        title: const Text('Períodos'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PeriodsScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.category,
                          color: AppTheme.primaryColor,
                        ),
                        title: const Text('Categorías'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CategoriesScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.sell_outlined,
                          color: AppTheme.primaryColor,
                        ),
                        title: const Text('Etiquetas'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TagsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.restart_alt_rounded,
                          color: Colors.orangeAccent,
                        ),
                        title: const Text('Resetear informacion'),
                        subtitle: const Text(
                          'Borra cuentas, categorias, movimientos, periodos y rendimientos',
                        ),
                        onTap: user == null
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dctx) => AlertDialog(
                                    title: const Text('Resetear informacion'),
                                    content: const Text(
                                      'Esta accion borrara toda la informacion del usuario actual. Deseas continuar?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dctx).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(dctx).pop(true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.orangeAccent,
                                        ),
                                        child: const Text('Resetear'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true || user == null) return;
                                await svc.resetUserData(user.uid);
                                if (!context.mounted) return;
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Informacion reseteada correctamente',
                                    ),
                                  ),
                                );
                              },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                        ),
                        title: const Text('Cerrar sesion'),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: const Text('Cerrar sesion'),
                              content: const Text(
                                'Deseas cerrar sesion en este dispositivo?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dctx).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(dctx).pop(true),
                                  child: const Text('Cerrar sesion'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          await ref.read(authServiceProvider).signOut();
                          if (!context.mounted) return;
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _themeTile(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: onTap == null
          ? null
          : () {
              onTap();
              Navigator.of(context).pop();
            },
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '';
  final first = parts.first[0].toUpperCase();
  final second = parts.length > 1 ? parts[1][0].toUpperCase() : '';
  return '$first$second';
}

int _daysActive(DateTime created) {
  final now = DateTime.now();
  return now
      .difference(DateTime(created.year, created.month, created.day))
      .inDays;
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY con período activo
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardBody extends ConsumerStatefulWidget {
  final Period period;
  final bool isDark;

  const _DashboardBody({required this.period, required this.isDark});

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  final Set<String> _selectedAccountIds = {};
  bool _initialized = false;
  String? _selectedPeriodId;
  bool _periodInitialized = false;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final allTxAsync = ref.watch(allTransactionsStreamProvider);
    final periodsAsync = ref.watch(periodsStreamProvider);
    final prefs =
        ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final currencyFormat = prefs.currencyFormat();

    return periodsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (periods) {
        if (periods.isEmpty) {
          return _NoPeriodPlaceholder(isDark: widget.isDark);
        }
        return allTxAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (allTxs) {
            return accountsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (accounts) {
                _initPeriodSelection(periods, widget.period);
                final selectedPeriod = periods.firstWhere(
                  (p) => p.id == _selectedPeriodId,
                  orElse: () => widget.period,
                );
                final periodTxs =
                    allTxs
                        .where((t) => t.periodId == selectedPeriod.id)
                        .toList()
                      ..sort((a, b) => b.date.compareTo(a.date));
                final balance = ref.read(periodBalanceProvider(periodTxs));
                final balances = ref.watch(accountBalancesProvider);
                final selectedAccounts = _selectedAccountIds.isEmpty
                    ? accounts.map((a) => a.id).toSet()
                    : _selectedAccountIds;
                final recentTxs = periodTxs
                    .where((t) => selectedAccounts.contains(t.accountId))
                    .toList();
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ── CARD DE BALANCE O PREMIUM (Gradiente #5B4FE8 -> #00E5C3) ──
                      _buildBalanceCard(
                        context,
                        selectedPeriod,
                        periods,
                        balance,
                        accounts,
                        balances,
                        periodTxs,
                        currencyFormat,
                      ),

                      const SizedBox(height: 24),

                      // ── CUENTAS HORIZONTAL ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Text(
                              'Mis Cuentas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: widget.isDark
                                  ? const Color(0xFF7B7F9E)
                                  : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _HorizontalAccountsList(
                        accounts: accounts,
                        balances: balances,
                        isDark: widget.isDark,
                        onAccountTap: _selectAccount,
                      ),

                      const SizedBox(height: 32),

                      // ── ÚLTIMOS MOVIMIENTOS ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Text(
                              'Últimos Movimientos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                ref.read(navigationProvider.notifier).setIndex(1);
                              },
                              child: const Text('Ver todos'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RecentTransactionsList(
                        transactions: recentTxs,
                        accounts: accounts,
                        periods: periods,
                        isDark: widget.isDark,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    Period period,
    List<Period> periods,
    PeriodBalance balance,
    List<Account> accounts,
    Map<String, double> balances,
    List<TransactionRecord> periodTransactions,
    NumberFormat currencyFormat,
  ) {
    _initSelection(accounts);
    _initPeriodSelection(periods, period);
    final selected = _selectedAccountIds.isEmpty
        ? accounts.map((a) => a.id).toSet()
        : _selectedAccountIds;
    final available = _computeAvailable(selected, accounts, balances);
    final filtered = _filterPeriodBalance(periodTransactions, selected);
    final dateFormat = DateFormat('dd MMM', 'es');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _pickPeriod(context, periods),
                icon: const Icon(Icons.expand_more_rounded, size: 16),
                label: Text(
                  period.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary(context),
                  padding: EdgeInsets.zero,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.panelAlt(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${dateFormat.format(period.startDate)} - ${dateFormat.format(period.endDate)}',
                  style: TextStyle(
                    color: AppTheme.textMuted(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Disponible',
            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textMuted(context),
                padding: EdgeInsets.zero,
              ),
              onPressed: () => _pickAccounts(context, accounts),
              icon: const Icon(Icons.filter_list_rounded, size: 14),
              label: Text(
                _selectedLabel(accounts),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currencyFormat.format(available),
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Ingresos',
                  filtered.income,
                  Colors.white,
                  currencyFormat,
                ),
              ),
              Expanded(
                child: _miniStat(
                  'Egresos',
                  filtered.expense,
                  Colors.white,
                  currencyFormat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double amount, Color color, NumberFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          fmt.format(amount),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  void _initSelection(List<Account> accounts) {
    if (_initialized || accounts.isEmpty) return;
    final cash = accounts.where((a) => a.type == AccountType.cash).toList();
    final defaults = cash.isNotEmpty
        ? cash.map((a) => a.id).toSet()
        : accounts.map((a) => a.id).toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedAccountIds
          ..clear()
          ..addAll(defaults);
        _initialized = true;
      });
    });
  }

  void _initPeriodSelection(List<Period> periods, Period active) {
    if (_periodInitialized || periods.isEmpty) return;
    final initial = periods.any((p) => p.id == active.id)
        ? active.id
        : periods.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedPeriodId = initial;
        _periodInitialized = true;
      });
    });
  }

  void _selectAccount(Account account) {
    setState(() {
      _selectedAccountIds
        ..clear()
        ..add(account.id);
    });
  }

  double _computeAvailable(
    Set<String> selected,
    List<Account> accounts,
    Map<String, double> balances,
  ) {
    double total = 0.0;
    for (final a in accounts) {
      if (!selected.contains(a.id)) continue;
      final bal = balances[a.id] ?? a.currentDebt;
      if (a.type == AccountType.creditCard) {
        total -= bal;
      } else {
        total += bal;
      }
    }
    return total;
  }

  PeriodBalance _filterPeriodBalance(
    List<TransactionRecord> txs,
    Set<String> selected,
  ) {
    double income = 0;
    double expense = 0;
    for (final t in txs) {
      if (t.isTransfer) continue;
      if (!selected.contains(t.accountId)) continue;
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return PeriodBalance(income: income, expense: expense);
  }

  String _selectedLabel(List<Account> accounts) {
    if (_selectedAccountIds.isEmpty ||
        _selectedAccountIds.length == accounts.length) {
      return 'Todas las cuentas';
    }
    if (_selectedAccountIds.length == 1) {
      final acc = accounts.firstWhere((a) => a.id == _selectedAccountIds.first);
      return acc.name;
    }
    return '${_selectedAccountIds.length} cuentas';
  }

  Future<void> _pickAccounts(
    BuildContext context,
    List<Account> accounts,
  ) async {
    final temp = _selectedAccountIds.isEmpty
        ? accounts.map((a) => a.id).toSet()
        : {..._selectedAccountIds};
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Seleccionar cuentas',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: temp.length == accounts.length,
                    onChanged: (v) {
                      setLocal(() {
                        if (v == true) {
                          temp
                            ..clear()
                            ..addAll(accounts.map((a) => a.id));
                        } else {
                          temp.clear();
                        }
                      });
                    },
                    title: const Text('Todas'),
                  ),
                  const Divider(),
                  ...accounts.map((a) {
                    return CheckboxListTile(
                      value: temp.contains(a.id),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            temp.add(a.id);
                          } else {
                            temp.remove(a.id);
                          }
                        });
                      },
                      title: Text(a.name),
                    );
                  }),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _selectedAccountIds
                            ..clear()
                            ..addAll(temp);
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickPeriod(BuildContext context, List<Period> periods) async {
    if (periods.isEmpty) return;
    var temp = _selectedPeriodId ?? periods.first.id;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Seleccionar período',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...periods.map((p) {
                    return RadioListTile<String>(
                      value: p.id,
                      groupValue: temp,
                      onChanged: (v) => setLocal(() => temp = v ?? temp),
                      title: Text(p.name),
                    );
                  }),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() => _selectedPeriodId = temp);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEMÁFORO DE CUENTAS (HORIZONTAL)
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalAccountsList extends StatelessWidget {
  final List<Account> accounts;
  final Map<String, double> balances;
  final bool isDark;
  final void Function(Account account) onAccountTap;

  const _HorizontalAccountsList({
    required this.accounts,
    required this.balances,
    required this.isDark,
    required this.onAccountTap,
  });

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'No hay cuentas registradas',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 16),
        itemBuilder: (ctx, i) => _AccountSemaphoreCard(
          account: accounts[i],
          balance: balances[accounts[i].id],
          isDark: isDark,
          onTap: () => onAccountTap(accounts[i]),
        ),
      ),
    );
  }
}

class _AccountSemaphoreCard extends ConsumerWidget {
  final Account account;
  final double? balance;
  final bool isDark;
  final VoidCallback? onTap;

  const _AccountSemaphoreCard({
    required this.account,
    required this.balance,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCard = account.type == AccountType.creditCard;
    final days = isCard ? account.daysUntilPayment() : 999;
    // Lógica del semáforo
    final color = !isCard
        ? const Color(0xFF00E5C3)
        : days > 20
        ? const Color(0xFF00E5C3) // Verde/Teal
        : days >= 10
        ? const Color(0xFFFFB300) // Amarillo
        : const Color(0xFFEF5350); // Rojo

    final prefs =
        ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final currency = prefs.currencyFormat();
    final currentAmount = balance ?? account.currentDebt;

    final limit = account.creditLimit;
    final available = limit != null
        ? (limit - currentAmount).clamp(0, limit).toDouble()
        : null;
    final summaryParts = <String>[];
    if (isCard) {
      if (available != null) {
        summaryParts.add('Disp ${currency.format(available)}');
      }
      if (account.installments.isNotEmpty) {
        summaryParts.add(
          'Cuotas ${currency.format(account.monthlyInstallmentsTotal)}/mes',
        );
      }
      if (summaryParts.isEmpty &&
          account.cutDay != null &&
          account.paymentDay != null) {
        summaryParts.add(
          'Corte ${account.cutDay} • Pago ${account.paymentDay}',
        );
      }
    } else {
      summaryParts.add(
        account.type == AccountType.savings ? 'Ahorro' : 'Efectivo',
      );
    }
    final summary = summaryParts.join(' • ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1F35) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isCard ? (days == 0 ? '¡Hoy!' : '$days días') : 'Saldo',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                account.nickname.isNotEmpty ? account.nickname : account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currency.format(currentAmount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.primaryColor,
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF7B7F9E)
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ÚLTIMOS MOVIMIENTOS
// ─────────────────────────────────────────────────────────────────────────────

class _RecentTransactionsList extends ConsumerWidget {
  final List<TransactionRecord> transactions;
  final List<Account> accounts;
  final List<Period> periods;
  final bool isDark;

  const _RecentTransactionsList({
    required this.transactions,
    required this.accounts,
    required this.periods,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'No hay movimientos recientes.',
          style: TextStyle(
            color: isDark ? const Color(0xFF7B7F9E) : Colors.grey,
          ),
        ),
      );
    }

    final accountById = {for (final a in accounts) a.id: a};
    final periodById = {for (final p in periods) p.id: p};
    // Tomamos sólo los últimos 5
    final recentTxs = transactions.take(5).toList();
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (categories) {
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: recentTxs.length,
          itemBuilder: (ctx, i) {
            final tx = recentTxs[i];

            // Buscar la categoría para el ícono y color
            final category = categories.firstWhere(
              (c) => c.id == tx.categoryId,
              orElse: () => Category(
                id: 'unknown',
                name: 'Desconocido',
                type: tx.type == TransactionType.income
                    ? CategoryType.income
                    : CategoryType.expense,
                colorHex: 'FF7B7F9E',
              ),
            );

            return _TransactionRowItem(
              transaction: tx,
              category: category,
              accountName: accountById[tx.accountId]?.name ?? 'Cuenta',
              periodName: periodById[tx.periodId]?.name ?? 'Período',
              isDark: isDark,
            );
          },
        );
      },
    );
  }
}

class _TransactionRowItem extends ConsumerWidget {
  final TransactionRecord transaction;
  final Category category;
  final String accountName;
  final String periodName;
  final bool isDark;

  const _TransactionRowItem({
    required this.transaction,
    required this.category,
    required this.accountName,
    required this.periodName,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction.type == TransactionType.income;
    final prefs =
        ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final currencyFormat = prefs.currencyFormat();
    final dateFormat = DateFormat('dd/MM', 'es');

    // Parsear el color hexagónal
    final catColor = Color(int.parse(category.colorHex, radix: 16));

    return InkWell(
      onTap: () => _openEdit(context),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icono
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1F35) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _getIconForName(category.icon),
                color: catColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Detalles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (transaction.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      transaction.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF7B7F9E)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    '$accountName • $periodName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF7B7F9E)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Monto y fecha
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isIncome
                        ? const Color(0xFF00E5C3)
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(transaction.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF7B7F9E)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    if (transaction.isTransfer && transaction.transferGroupId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TransferEditScreen(
            transferGroupId: transaction.transferGroupId!,
            amount: transaction.amount,
            note: transaction.note,
            date: transaction.date,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TransactionEditScreen(transaction: transaction),
        ),
      );
    }
  }

  IconData _getIconForName(String name) => AppIcons.getIcon(name);
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER si no hay período activo
// ─────────────────────────────────────────────────────────────────────────────

class _NoPeriodPlaceholder extends StatelessWidget {
  final bool isDark;
  const _NoPeriodPlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 64,
            color: AppTheme.primaryColor.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bienvenido a Cifra',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'Para comenzar a registrar movimientos,\nnecesitas configurar tu primer período.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0xFF7B7F9E) : Colors.grey.shade500,
              fontSize: 15,
            ),
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
                  builder: (_) => const PeriodsScreen(openCreate: true),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Crear primer período',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
