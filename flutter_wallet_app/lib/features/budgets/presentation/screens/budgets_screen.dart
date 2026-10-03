import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(userBudgetsProvider);
    return Scaffold(
      backgroundColor: ObsidianFlowColors.canvasBase,
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('No se pudieron cargar los presupuestos: $error'),
        ),
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('Aún no tienes presupuestos configurados.'),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final budget = items[index];
                  final progress = budget.percentage;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            budget.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: progress,
                            color: progress >= .9
                                ? ObsidianFlowColors.secondary
                                : ObsidianFlowColors.primary,
                            backgroundColor:
                                ObsidianFlowColors.surfaceContainerHighest,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'GTQ ${budget.spentAmount.toStringAsFixed(2)} de GTQ ${budget.limitAmount.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
