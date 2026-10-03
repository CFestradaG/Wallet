import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardNotifierProvider);
    return Scaffold(
      backgroundColor: ObsidianFlowColors.canvasBase,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No se pudo cargar la analítica: $error')),
        data: (data) {
          final expenses = data.totalExpenses;
          final income = data.totalIncome;
          final categories = data.expensesByCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Período ${data.activePeriodName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _MetricTile(
                label: 'Ingresos',
                amount: income,
                color: ObsidianFlowColors.primary,
              ),
              _MetricTile(
                label: 'Gastos',
                amount: expenses,
                color: ObsidianFlowColors.secondary,
              ),
              _MetricTile(
                label: 'Flujo neto',
                amount: income - expenses,
                color: ObsidianFlowColors.tertiary,
              ),
              const SizedBox(height: 18),
              Text(
                'Gastos por categoría',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No hay gastos para este período.'),
                  ),
                )
              else
                for (final item in categories)
                  Card(
                    child: ListTile(
                      title: Text(item.key),
                      trailing: Text(
                        'GTQ ${NumberFormat('#,##0.00', 'en_US').format(item.value)}',
                      ),
                      subtitle: LinearProgressIndicator(
                        value: expenses == 0
                            ? 0
                            : (item.value / expenses).clamp(0.0, 1.0),
                        color: ObsidianFlowColors.primaryContainer,
                        backgroundColor:
                            ObsidianFlowColors.surfaceContainerHighest,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(label),
      trailing: Text(
        'GTQ ${NumberFormat('#,##0.00', 'en_US').format(amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
