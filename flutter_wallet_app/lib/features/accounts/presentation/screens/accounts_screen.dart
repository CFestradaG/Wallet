import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../data/models/account_model.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar cuenta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final userId = ref.read(currentUserIdProvider).valueOrNull;
    if (userId == null) return;
    final now = DateTime.now();
    await ref
        .read(accountRepositoryProvider)
        .createAccount(
          AccountModel(
            id: 'acc_${now.microsecondsSinceEpoch}',
            userId: userId,
            name: name,
            type: AccountType.bank,
            currentBalance: 0,
            currency: 'GTQ',
            colorHex: '#00E676',
            iconName: 'account_balance',
            subtitle: 'Cuenta bancaria',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(userAccountsNotifierProvider);
    return Scaffold(
      backgroundColor: ObsidianFlowColors.canvasBase,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addAccount(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No se pudieron cargar las cuentas: $error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Aún no tienes cuentas.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final account = items[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ObsidianFlowColors.primaryContainer
                            .withValues(alpha: .15),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: ObsidianFlowColors.primary,
                        ),
                      ),
                      title: Text(account.name),
                      subtitle: Text(account.subtitle),
                      trailing: Text(
                        '${account.currentBalance.toStringAsFixed(2)} ${account.currency}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
