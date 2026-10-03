import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../providers/dashboard_providers.dart';

/// Pantalla Principal DashboardScreen (Clon exacto de Google Stitch - Imagen 3)
/// Incluye:
/// 1. AppBar con Drawer, título "Inicio", campana de notificaciones con badge y avatar "FE".
/// 2. Tabs superiores ("Cuentas" | "Presupuestos y Objetivos").
/// 3. Tarjeta Hero "PATRIMONIO NETO TOTAL" (GTQ 12,450.00, badge +4.2% y mini sparkline).
/// 4. Lista horizontal de cuentas ("Mis cuentas en Wallet": Efectivo, BAC Tarjeta Crédito, BI).
/// 5. Chips de acceso rápido ("Detalle de la cuenta", "Registros", "Presupuestos") y Banner Premium.
/// 6. Tarjeta "Estructura de gastos (ÚLTIMOS 30 DÍAS)" con Donut Chart y botones (- Gasto, + Ingreso, Transferir).
/// 7. Lista de "Últimos registros" con íconos circulares y montos tabulares en GTQ.
/// 8. FloatingActionButton (+) en esquina inferior derecha.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedTopTab = 0; // 0: Cuentas, 1: Presupuestos y Objetivos
  final NumberFormat _currencyFmt = NumberFormat('#,##0.00', 'en_US');

  String _formatGtq(double amount, {bool showSign = false}) {
    final absVal = _currencyFmt.format(amount.abs());
    if (showSign) {
      return amount >= 0 ? '+GTQ $absVal' : '-GTQ $absVal';
    }
    return amount < 0 ? '-GTQ $absVal' : 'GTQ $absVal';
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardNotifierProvider);

    return Scaffold(
      backgroundColor: ObsidianFlowColors.canvasBase,
      appBar: _buildStitchAppBar(context),
      body: dashboardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: ObsidianFlowColors.primaryContainer,
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error al sincronizar con Cloud Firestore:\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ObsidianFlowColors.outflowCrimson),
            ),
          ),
        ),
        data: (dashboard) => RefreshIndicator(
          color: ObsidianFlowColors.primaryContainer,
          backgroundColor: ObsidianFlowColors.elevation1,
          onRefresh: () async {
            ref.invalidate(userAccountsNotifierProvider);
            ref.invalidate(userTransactionsNotifierProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Sub-tabs: Cuentas | Presupuestos y Objetivos
                      _buildTopTabSelector(),
                      const SizedBox(height: 16),

                      // 2. Tarjeta de Patrimonio Neto Total
                      _buildNetWorthHeroCard(dashboard),
                      const SizedBox(height: 24),

                      // 3. Cabecera y Lista Horizontal de Cuentas
                      _buildAccountsHeader(context),
                      const SizedBox(height: 12),
                      _buildHorizontalAccountsList(dashboard.accounts),
                      const SizedBox(height: 14),

                      // Botón "Seleccionar todo" y fila de Chips de navegación rápida
                      Center(
                        child: TextButton(
                          onPressed: () => context.go(AppRoutes.accounts),
                          child: const Text(
                            'Seleccionar todo',
                            style: TextStyle(
                              color: Color(0xFF00B4D8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildQuickActionPills(context),
                      const SizedBox(height: 18),

                      // 4. Club Premium Card (Diseño Stitch)
                      _buildPremiumBannerCard(),
                      const SizedBox(height: 18),

                      // 5. Tarjeta "Estructura de gastos" con Donut Chart y botones rápidos
                      _buildExpenseStructureCard(context, dashboard),
                      const SizedBox(height: 18),

                      // 6. Tarjeta "Últimos registros"
                      _buildRecentTransactionsCard(
                        context,
                        dashboard.recentTransactions,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // 7. Floating Action Button (+) idéntico a la captura
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('${AppRoutes.newTransaction}?type=expense'),
        backgroundColor: const Color(0xFF00BFA5),
        foregroundColor: Colors.black,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, size: 30, weight: 700),
      ),
    );
  }

  /// AppBar superior con icono hamburguesa, "Inicio", campana con punto rojo y avatar "FE"
  PreferredSizeWidget _buildStitchAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: ObsidianFlowColors.canvasBase,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
        onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
      ),
      title: const Text(
        'Inicio',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 26,
              ),
              onPressed: () {},
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ObsidianFlowColors.outflowCrimson,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF003926),
              shape: BoxShape.circle,
              border: Border.all(
                color: ObsidianFlowColors.primaryContainer,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'FE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Selector de pestañas superior ("Cuentas" | "Presupuestos y Objetivos")
  Widget _buildTopTabSelector() {
    return Row(
      children: [
        _buildTabItem(title: 'Cuentas', index: 0),
        const SizedBox(width: 24),
        _buildTabItem(title: 'Presupuestos y Objetivos', index: 1),
      ],
    );
  }

  Widget _buildTabItem({required String title, required int index}) {
    final bool isSelected = _selectedTopTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTopTab = index);
        if (index == 1) {
          context.go(AppRoutes.budgets);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : ObsidianFlowColors.textSecondary,
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: isSelected ? 64 : 0,
            decoration: BoxDecoration(
              color: ObsidianFlowColors.primaryContainer,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  /// 1. Tarjeta de Saldo Total ("PATRIMONIO NETO TOTAL")
  Widget _buildNetWorthHeroCard(DashboardWalletState state) {
    final displayBalance =
        state.accounts.isEmpty ? 12450.00 : state.netWorthTotal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A2420),
            Color(0xFF161918),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ObsidianFlowColors.primaryContainer.withOpacity(0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PATRIMONIO NETO TOTAL',
                style: TextStyle(
                  color: ObsidianFlowColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ObsidianFlowColors.primaryContainer.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: ObsidianFlowColors.primaryContainer.withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      color: ObsidianFlowColors.primaryContainer,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '+4.2%',
                      style: TextStyle(
                        color: ObsidianFlowColors.primaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatGtq(displayBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF262E2A), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Actualizado hace 2 min',
                style: TextStyle(
                  color: ObsidianFlowColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              SizedBox(
                width: 90,
                height: 20,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    color: ObsidianFlowColors.primaryContainer,
                    hasMovements: state.recentTransactions.isNotEmpty && state.netWorthTotal != 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cabecera "Mis cuentas en Wallet >"
  Widget _buildAccountsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Mis cuentas en Wallet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          onPressed: () => context.go(AppRoutes.accounts),
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: ObsidianFlowColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 2. Lista Horizontal de Cuentas (Efectivo, BAC Tarjeta Crédito, Banco Industrial)
  Widget _buildHorizontalAccountsList(List<AccountModel> accounts) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final acc = accounts[index];
          final bool isCash = acc.isCash;
          final bool isNegative = acc.isNegative;

          return Container(
            width: 195,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isCash
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00B4D8), Color(0xFF007791)],
                    )
                  : null,
              color: isCash ? null : ObsidianFlowColors.elevation1,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(isCash ? 0.15 : 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCash
                              ? Icons.payments_outlined
                              : acc.isCreditCard
                                  ? Icons.credit_card_rounded
                                  : Icons.account_balance_rounded,
                          size: 18,
                          color: isCash
                              ? Colors.white
                              : acc.isCreditCard
                                  ? ObsidianFlowColors.outflowCrimson
                                  : const Color(0xFF00B4D8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          acc.name,
                          style: TextStyle(
                            color: isCash
                                ? Colors.white
                                : const Color(0xFFE0E0E0),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (acc.isCreditCard)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: ObsidianFlowColors.outflowCrimson,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      acc.isCreditCard
                          ? 'TARJETA CRÉDITO'
                          : 'SALDO DISPONIBLE',
                      style: TextStyle(
                        color: isCash
                            ? Colors.white.withOpacity(0.8)
                            : ObsidianFlowColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatGtq(acc.balance),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCash
                            ? Colors.white
                            : isNegative
                                ? ObsidianFlowColors.outflowCrimson
                                : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
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

  /// Píldoras de navegación rápida ("Detalle de la cuenta", "Registros", "Presupuestos")
  Widget _buildQuickActionPills(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildActionChip(
            icon: Icons.receipt_long_outlined,
            iconColor: const Color(0xFF00B4D8),
            label: 'Detalle de la cuenta',
            onTap: () => context.go(AppRoutes.accounts),
          ),
          const SizedBox(width: 10),
          _buildActionChip(
            icon: Icons.filter_list_rounded,
            iconColor: ObsidianFlowColors.primaryContainer,
            label: 'Registros',
            onTap: () => context.go(AppRoutes.transactions),
          ),
          const SizedBox(width: 10),
          _buildActionChip(
            icon: Icons.pie_chart_outline_rounded,
            iconColor: const Color(0xFFFFB300),
            label: 'Presupuestos',
            onTap: () => context.go(AppRoutes.budgets),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ObsidianFlowColors.elevation1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta Promocional Club Premium
  Widget _buildPremiumBannerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1924),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFCA28),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Únete a nuestro club Premium!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Maximiza tu potencial financiero. Wallet hará el trabajo duro. Cancela cuando quieras.',
                      style: TextStyle(
                        color: ObsidianFlowColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAA00FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'Obtener Wallet Premium',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Tarjeta "Estructura de gastos" con Donut Chart y botones (- Gasto, + Ingreso, Transferir)
  Widget _buildExpenseStructureCard(
    BuildContext context,
    DashboardWalletState state,
  ) {
    final totalExp = state.totalExpenses;
    final sortedExpenses = state.expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final hasExpenses = totalExp > 0 && sortedExpenses.isNotEmpty;

    const palette = [
      ObsidianFlowColors.outflowCrimson,
      Color(0xFF00B4D8),
      Color(0xFFFFB300),
      Color(0xFF75FF9E),
      Color(0xFFB388FF),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ObsidianFlowColors.elevation1,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estructura de gastos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => context.go(AppRoutes.analytics),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: ObsidianFlowColors.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            state.filterMode == PeriodFilterMode.fullPeriod
                ? 'ESTE PERÍODO'
                : state.currentSubPeriodLabel.toUpperCase(),
            style: const TextStyle(
              color: ObsidianFlowColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatGtq(totalExp),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Estado',
                    style: TextStyle(
                      color: ObsidianFlowColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    hasExpenses ? 'En tiempo real' : 'Sin movimientos',
                    style: TextStyle(
                      color: hasExpenses
                          ? ObsidianFlowColors.primaryContainer
                          : ObsidianFlowColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Donut Chart CustomPainter dinámico
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(108, 108),
                      painter: _ExpenseDonutPainter(
                        expensesByCategory: state.expensesByCategory,
                        totalExpenses: totalExp,
                      ),
                    ),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          color: ObsidianFlowColors.textSecondary,
                          size: 20,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'GASTOS',
                          style: TextStyle(
                            color: ObsidianFlowColors.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Leyenda de Categorías dinámica
              Expanded(
                child: hasExpenses
                    ? Column(
                        children: [
                          for (int i = 0; i < sortedExpenses.take(3).length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _buildLegendRow(
                              color: palette[i % palette.length],
                              label: sortedExpenses[i].key,
                              amount: _formatGtq(sortedExpenses[i].value),
                            ),
                          ],
                        ],
                      )
                    : const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sin gastos registrados',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Los gastos de este período aparecerán aquí agrupados.',
                            style: TextStyle(
                              color: ObsidianFlowColors.textSecondary,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Botones de acción rápida: - Gasto | + Ingreso | Transferir
          Row(
            children: [
              Expanded(
                child: _buildQuickTxButton(
                  label: 'Gasto',
                  icon: Icons.remove_circle_outline_rounded,
                  color: ObsidianFlowColors.outflowCrimson,
                  onTap: () =>
                      context.push('${AppRoutes.newTransaction}?type=expense'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickTxButton(
                  label: 'Ingreso',
                  icon: Icons.add_circle_outline_rounded,
                  color: ObsidianFlowColors.primaryContainer,
                  onTap: () =>
                      context.push('${AppRoutes.newTransaction}?type=income'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickTxButton(
                  label: 'Transferir',
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFF00B4D8),
                  onTap: () =>
                      context.push('${AppRoutes.newTransaction}?type=transfer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow({
    required Color color,
    required String label,
    required String amount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 12),
            ),
          ],
        ),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTxButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: ObsidianFlowColors.elevation2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 4. Resumen de "Últimos registros"
  Widget _buildRecentTransactionsCard(
    BuildContext context,
    List<TransactionModel> transactions,
  ) {
    final visibleList = transactions.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ObsidianFlowColors.elevation1,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Últimos registros',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.transactions),
                child: const Text(
                  'Ver todos',
                  style: TextStyle(
                    color: ObsidianFlowColors.primaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (visibleList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No hay transacciones recientes en este período.',
                style: TextStyle(color: ObsidianFlowColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final tx = visibleList[index];
                final bool isIncome = tx.isIncome;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isIncome
                                  ? ObsidianFlowColors.primaryContainer
                                      .withOpacity(0.12)
                                  : ObsidianFlowColors.outflowCrimson
                                      .withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _resolveCategoryIcon(tx.categoryIcon),
                              color: isIncome
                                  ? ObsidianFlowColors.primaryContainer
                                  : const Color(0xFFFFB300),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isIncome
                                            ? ObsidianFlowColors.primaryContainer
                                            : const Color(0xFF00B4D8),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        '${tx.accountName} • ${DateFormat('dd MMM, h:mm a').format(tx.date)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: ObsidianFlowColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatGtq(tx.signedAmount, showSign: true),
                      style: TextStyle(
                        color: isIncome
                            ? ObsidianFlowColors.primaryContainer
                            : ObsidianFlowColors.outflowCrimson,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  IconData _resolveCategoryIcon(String iconName) {
    switch (iconName) {
      case 'shopping_cart':
        return Icons.shopping_cart_outlined;
      case 'fuel':
        return Icons.local_gas_station_outlined;
      case 'briefcase':
        return Icons.south_west_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }
}

/// CustomPainter para la curva Sparkline de la tarjeta de Patrimonio Neto
class _SparklinePainter extends CustomPainter {
  final Color color;
  final bool hasMovements;
  const _SparklinePainter({required this.color, this.hasMovements = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = hasMovements ? color : color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (!hasMovements) {
      // Línea horizontal neutra cuando no hay movimientos
      path.moveTo(0, size.height * 0.5);
      path.lineTo(size.width, size.height * 0.5);
    } else {
      path.moveTo(0, size.height * 0.85);
      path.quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.45,
        size.width * 0.5,
        size.height * 0.65,
      );
      path.quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.85,
        size.width * 0.9,
        size.height * 0.15,
      );
      path.lineTo(size.width, size.height * 0.25);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.hasMovements != hasMovements || oldDelegate.color != color;
}

/// CustomPainter para el gráfico Donut de Estructura de Gastos dinámico
class _ExpenseDonutPainter extends CustomPainter {
  final Map<String, double> expensesByCategory;
  final double totalExpenses;

  const _ExpenseDonutPainter({
    required this.expensesByCategory,
    required this.totalExpenses,
  });

  static const List<Color> _palette = [
    ObsidianFlowColors.outflowCrimson,
    Color(0xFF00B4D8),
    Color(0xFFFFB300),
    Color(0xFF75FF9E),
    Color(0xFFB388FF),
    Color(0xFFFF8A80),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 14) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = const Color(0xFF2C2C2C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11;

    canvas.drawCircle(center, radius, trackPaint);

    if (totalExpenses <= 0 || expensesByCategory.isEmpty) {
      // Solo pinta el track circular vacío sin arcos ficticios
      return;
    }

    final sortedEntries = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    double startAngle = -math.pi / 2;
    int colorIdx = 0;

    for (final entry in sortedEntries) {
      final sweepRatio = (entry.value / totalExpenses).clamp(0.0, 1.0);
      if (sweepRatio <= 0.001) continue;

      final paint = Paint()
        ..color = _palette[colorIdx % _palette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = sortedEntries.length == 1 ? StrokeCap.round : StrokeCap.butt;

      final sweepAngle = sweepRatio * 2 * math.pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
      colorIdx++;
    }
  }

  @override
  bool shouldRepaint(covariant _ExpenseDonutPainter oldDelegate) =>
      oldDelegate.totalExpenses != totalExpenses ||
      oldDelegate.expensesByCategory != expensesByCategory;
}
