import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../data/models/transaction_model.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(userTransactionsNotifierProvider);
    return Scaffold(
      backgroundColor: ObsidianFlowColors.canvasBase,
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('${AppRoutes.newTransaction}?type=expense'),
        child: const Icon(Icons.add_rounded),
      ),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No se pudieron cargar los registros: $error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Todavía no hay movimientos.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final transaction = items[index];
                  final isIncome = transaction.type == TransactionType.income;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                          (isIncome
                                  ? ObsidianFlowColors.primaryContainer
                                  : ObsidianFlowColors.outflowCrimson)
                              .withValues(alpha: .15),
                      child: Icon(
                        isIncome
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: isIncome
                            ? ObsidianFlowColors.primary
                            : ObsidianFlowColors.secondary,
                      ),
                    ),
                    title: Text(
                      transaction.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${transaction.categoryName} · ${transaction.accountName} · ${DateFormat('dd/MM/yyyy').format(transaction.date)}',
                    ),
                    trailing: Text(
                      '${isIncome
                          ? '+'
                          : transaction.isTransfer
                          ? '↔ '
                          : '-'}${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
                      style: TextStyle(
                        color: isIncome
                            ? ObsidianFlowColors.primary
                            : ObsidianFlowColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onLongPress: () async {
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminar movimiento'),
                          content: Text(
                            'Se revertirá el saldo de las cuentas asociadas a “${transaction.note}”.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                      if (shouldDelete == true) {
                        await ref
                            .read(userTransactionsNotifierProvider.notifier)
                            .removeTransaction(transaction);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}
