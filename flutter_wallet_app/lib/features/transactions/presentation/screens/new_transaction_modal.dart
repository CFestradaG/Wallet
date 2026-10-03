import 'package:flutter/material.dart';

import 'add_transaction_screen.dart';

class NewTransactionModal extends StatelessWidget {
  final String initialType;

  const NewTransactionModal({super.key, required this.initialType});

  @override
  Widget build(BuildContext context) =>
      AddTransactionScreen(initialType: initialType);
}
