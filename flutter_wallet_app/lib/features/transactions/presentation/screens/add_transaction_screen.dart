import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../accounts/data/models/account_model.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../data/models/transaction_model.dart';

/// Modelo ligero para las Categorías del carrusel horizontal (Imagen 5 / Imagen 6)
class TransactionCategoryOption {
  final String id;
  final String name;
  final IconData icon;
  final String iconName;
  final String colorHex;
  final TransactionType type;
  final List<String> subcategories;

  const TransactionCategoryOption({
    required this.id,
    required this.name,
    required this.icon,
    required this.iconName,
    required this.colorHex,
    this.type = TransactionType.expense,
    this.subcategories = const [],
  });
}

const List<TransactionCategoryOption> kDefaultCategories = [
  // --- GASTOS ---
  TransactionCategoryOption(
    id: 'cat_restaurante',
    name: 'Comida',
    icon: Icons.restaurant_rounded,
    iconName: 'utensils',
    colorHex: '#00ACC1',
    type: TransactionType.expense,
    subcategories: ['Almuerzo Ejecutivo', 'Cena', 'Comida Rápida', 'Cafetería', 'Delivery'],
  ),
  TransactionCategoryOption(
    id: 'cat_mercado',
    name: 'Supermercado',
    icon: Icons.shopping_cart_outlined,
    iconName: 'shopping_cart',
    colorHex: '#FFB300',
    type: TransactionType.expense,
    subcategories: ['Abarrotes y Despensa', 'Frutas y Verduras', 'Carnes y Lácteos', 'Limpieza del Hogar', 'Bebidas'],
  ),
  TransactionCategoryOption(
    id: 'cat_gasolina',
    name: 'Transporte',
    icon: Icons.local_gas_station_outlined,
    iconName: 'fuel',
    colorHex: '#FF5252',
    type: TransactionType.expense,
    subcategories: ['Gasolina / Diésel', 'Uber / Taxi', 'Peajes', 'Taller / Mantenimiento', 'Parqueos'],
  ),
  TransactionCategoryOption(
    id: 'cat_servicios',
    name: 'Servicios',
    icon: Icons.bolt_rounded,
    iconName: 'wifi',
    colorHex: '#00DCF5',
    type: TransactionType.expense,
    subcategories: ['Alquiler / Hipoteca', 'Electricidad', 'Internet / Fibra', 'Agua Potable', 'Gas Propano'],
  ),
  TransactionCategoryOption(
    id: 'cat_ocio',
    name: 'Entretenimiento',
    icon: Icons.movie_creation_outlined,
    iconName: 'film',
    colorHex: '#9C27B0',
    type: TransactionType.expense,
    subcategories: ['Streaming', 'Cine y Eventos', 'Salidas y Fiestas', 'Videojuegos y Hobbies'],
  ),
  TransactionCategoryOption(
    id: 'cat_salud',
    name: 'Salud',
    icon: Icons.medical_services_outlined,
    iconName: 'heart_pulse',
    colorHex: '#FF5252',
    type: TransactionType.expense,
    subcategories: ['Farmacia y Medicinas', 'Consultas Médicas', 'Laboratorios', 'Cuidado Personal'],
  ),
  // --- INGRESOS ---
  TransactionCategoryOption(
    id: 'cat_salario',
    name: 'Salario',
    icon: Icons.account_balance_wallet_outlined,
    iconName: 'briefcase',
    colorHex: '#00E676',
    type: TransactionType.income,
    subcategories: ['Sueldo Quincenal', 'Sueldo Fin de Mes', 'Bono 14', 'Aguinaldo', 'Horas Extras'],
  ),
  TransactionCategoryOption(
    id: 'cat_negocio',
    name: 'Negocio',
    icon: Icons.storefront_outlined,
    iconName: 'shopping_cart',
    colorHex: '#00DCF5',
    type: TransactionType.income,
    subcategories: ['Venta de Productos', 'Servicios Prestados', 'Comisiones', 'Cobro de Facturas'],
  ),
  TransactionCategoryOption(
    id: 'cat_inversiones',
    name: 'Inversiones',
    icon: Icons.trending_up_rounded,
    iconName: 'trending_up',
    colorHex: '#FFB300',
    type: TransactionType.income,
    subcategories: ['Dividendos', 'Intereses Bancarios', 'Cripto / Acciones', 'Rentas Cobradas'],
  ),
  TransactionCategoryOption(
    id: 'cat_otros_ingresos',
    name: 'Otros Ingresos',
    icon: Icons.card_giftcard_rounded,
    iconName: 'gift',
    colorHex: '#AB47BC',
    type: TransactionType.income,
    subcategories: ['Regalos y Donaciones', 'Reembolsos', 'Premios', 'Préstamos'],
  ),
];

/// Widget AddTransactionScreen (Clon exacto de "NUEVA TRANSACCIÓN" - Google Stitch)
/// Incluye:
/// 1. Header turquesa (#00ACC1) con botones X y Check, y selector segmentado:
///    [INGRESOS | GASTO | TRANSFERENCIA].
/// 2. Visor numérico grande "- 150.00 GTQ" con tabulación monoespaciada y botón lateral "<".
/// 3. Selectores rápidos de CUENTA (Efectivo) y CATEGORÍA (Almuerzo / Restaurante).
/// 4. Barra de "PLANTILLAS" (#0097A7).
/// 5. Carrusel horizontal "SELECCIONAR CATEGORÍA" con avatares circulares.
/// 6. Selector de Fecha/Hora y campo de Nota/Descripción.
/// 7. Teclado numérico calculador personalizado 4x4 (7 8 9 ÷ / 4 5 6 × / 1 2 3 − / . 0 ⌫ +).
/// 8. Botón inferior "Guardar Transacción" que invoca `saveTransactionWithRunTransaction`.
class AddTransactionScreen extends ConsumerStatefulWidget {
  final String initialType;

  const AddTransactionScreen({
    super.key,
    this.initialType = 'expense',
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TransactionType _selectedType;
  String _expression = '150.00';
  bool _isDefaultValue = true;

  String? _selectedAccountId;
  late TransactionCategoryOption _selectedCategory;
  bool _isCategoryChosen = false;
  String? _selectedSubcategory;
  DateTime _selectedDateTime = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = TransactionType.fromString(widget.initialType);
    _selectedCategory = kDefaultCategories.firstWhere(
      (c) => c.type == _selectedType,
      orElse: () => kDefaultCategories.first,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Evalúa expresiones aritméticas ingresadas en el teclado numérico (+, -, *, /)
  double _evaluateExpression(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.+\-*/]'), '');
    if (cleaned.isEmpty) return 0.0;

    final safeExpr = cleaned.replaceAll(RegExp(r'[+\-*/.]$'), '');
    if (safeExpr.isEmpty) return 0.0;

    final RegExp tokenRegex = RegExp(r'(\d+\.?\d*|[+\-*/])');
    final tokens =
        tokenRegex.allMatches(safeExpr).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) return 0.0;

    double result = double.tryParse(tokens.first) ?? 0.0;
    for (int i = 1; i < tokens.length - 1; i += 2) {
      final op = tokens[i];
      final nextVal = double.tryParse(tokens[i + 1]) ?? 0.0;
      switch (op) {
        case '+':
          result += nextVal;
          break;
        case '-':
          result -= nextVal;
          break;
        case '*':
          result *= nextVal;
          break;
        case '/':
          if (nextVal != 0) result /= nextVal;
          break;
      }
    }
    return result.abs();
  }

  void _onKeyTap(String key) {
    HapticFeedback.lightImpact();
    setState(() {
      if (key == 'backspace') {
        if (_expression.length > 1) {
          _expression = _expression.substring(0, _expression.length - 1);
        } else {
          _expression = '0';
          _isDefaultValue = true;
        }
        return;
      }

      if (key == '=') {
        final evaluated = _evaluateExpression(_expression);
        _expression = evaluated.toStringAsFixed(2);
        _isDefaultValue = true;
        return;
      }

      if (['+', '-', '*', '/'].contains(key)) {
        _isDefaultValue = false;
        if (['+', '-', '*', '/'].any((op) => _expression.endsWith(op))) {
          _expression =
              _expression.substring(0, _expression.length - 1) + key;
        } else {
          _expression += key;
        }
        return;
      }

      if (key == '.') {
        final parts = _expression.split(RegExp(r'[+\-*/]'));
        if (!parts.last.contains('.')) {
          _expression += '.';
          _isDefaultValue = false;
        }
        return;
      }

      // Dígito numérico 0-9
      if (_isDefaultValue || _expression == '0') {
        _expression = key;
        _isDefaultValue = false;
      } else if (_expression.length < 12) {
        _expression += key;
      }
    });
  }

  Future<void> _handleSaveTransaction(List<AccountModel> accounts) async {
    if (_isSubmitting) return;

    final double amount = _evaluateExpression(_expression);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un monto mayor a 0.00 GTQ'),
          backgroundColor: Color(0xFFFF5252),
        ),
      );
      return;
    }

    final userId = ref.read(currentUserIdProvider).valueOrNull ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para guardar en Cloud Firestore'),
          backgroundColor: Color(0xFFFF5252),
        ),
      );
      return;
    }

    final AccountModel selectedAccount = accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => accounts.isNotEmpty
          ? accounts.first
          : AccountModel(
              id: 'acc_efectivo',
              userId: userId,
              name: 'Efectivo',
              type: AccountType.cash,
              currentBalance: 4990.90,
              currency: 'GTQ',
              colorHex: '#00ACC1',
              iconName: 'payments',
              subtitle: 'SALDO DISPONIBLE',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
    );

    setState(() => _isSubmitting = true);

    try {
      final now = _selectedDateTime;
      final yearMonth = '${now.year}_${now.month.toString().padLeft(2, '0')}';
      final txId = 'tx_${DateTime.now().millisecondsSinceEpoch}';

      final newTx = TransactionModel(
        id: txId,
        userId: userId,
        accountId: selectedAccount.id,
        accountName: selectedAccount.name,
        categoryId: _selectedCategory.id,
        categoryName: _selectedCategory.name,
        categoryIcon: _selectedCategory.iconName,
        categoryColor: _selectedCategory.colorHex,
        subcategory: _selectedSubcategory,
        type: _selectedType,
        amount: amount,
        currency: selectedAccount.currency,
        note: _noteController.text.trim().isEmpty
            ? '${_selectedCategory.name}${_selectedSubcategory != null ? " · $_selectedSubcategory" : ""} · ${selectedAccount.name}'
            : _noteController.text.trim(),
        date: now,
        yearMonth: yearMonth,
        periodId: 'period_$yearMonth',
        createdAt: now,
        updatedAt: now,
      );

      // Ejecuta la Transacción Atómica de Firestore (runTransaction)
      await ref
          .read(transactionRepositoryProvider)
          .saveTransactionWithRunTransaction(transaction: newTx);

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en transacción atómica: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(userAccountsNotifierProvider);
    final accounts = accountsAsync.valueOrNull ?? const [];

    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    final AccountModel? activeAccount = accounts.isEmpty
        ? null
        : accounts.firstWhere(
            (a) => a.id == _selectedAccountId,
            orElse: () => accounts.first,
          );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. HEADER SUPERIOR (#00ACC1) CON TABS Y VISOR DE MONTO
            _buildCyanHeaderSection(context, accounts, activeAccount),

            // 2. BARRA DE PLANTILLAS (#0097A7)
            _buildTemplatesBar(),

            // 3. CONTENIDO CENTRAL: CARRUSEL DE CATEGORÍAS + FECHA y NOTA
            Expanded(
              child: Column(
                children: [
                  _buildCategoryHorizontalSlider(),
                  _buildDateAndNoteSection(context),
                  // 4. TECLADO NUMÉRICO PERSONALIZADO 4x4
                  Expanded(
                    child: _buildCustomCalculatorKeypad(),
                  ),
                ],
              ),
            ),

            // 5. BOTÓN INFERIOR DE CONFIRMACIÓN
            _buildBottomSaveAction(accounts),
          ],
        ),
      ),
    );
  }

  /// Header Turquesa (#00ACC1) con botones X / Check, pestañas de tipo y visor "- 150.00 GTQ"
  Widget _buildCyanHeaderSection(
    BuildContext context,
    List<AccountModel> accounts,
    AccountModel? activeAccount,
  ) {
    const Color headerCyan = Color(0xFF00ACC1);

    return Container(
      color: headerCyan,
      child: Column(
        children: [
          // Top Action Bar: X | NUEVA TRANSACCIÓN | Check
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
                const Text(
                  'NUEVA TRANSACCIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _handleSaveTransaction(accounts),
                  icon: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          // Selector de Tipo: INGRESOS | GASTO | TRANSFERENCIA
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.black.withOpacity(0.12)),
              ),
            ),
            child: Row(
              children: [
                _buildTypeTab(
                  label: 'INGRESOS',
                  type: TransactionType.income,
                ),
                _buildTypeTab(
                  label: 'GASTO',
                  type: TransactionType.expense,
                ),
                _buildTypeTab(
                  label: 'TRANSFERENCIA',
                  type: TransactionType.transfer,
                ),
              ],
            ),
          ),

          // Visor de Monto Principal "- 150.00 GTQ"
          Stack(
            alignment: Alignment.centerRight,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _selectedType == TransactionType.income
                              ? '+'
                              : _selectedType == TransactionType.expense
                                  ? '-'
                                  : '⇄',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _expression,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -1.5,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'GTQ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(color: Colors.white.withOpacity(0.2), height: 1),
                    const SizedBox(height: 10),

                    // Píldoras de CUENTA y CATEGORÍA en el Header
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showAccountPickerModal(accounts),
                            child: Column(
                              children: [
                                Text(
                                  'CUENTA',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        (activeAccount?.name ?? 'EFECTIVO')
                                            .toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'CATEGORÍA',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _selectedCategory.icon,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _selectedCategory.name.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Botón flotante blanco en el borde derecho "<"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(999),
                  ),
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: headerCyan,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required String label,
    required TransactionType type,
  }) {
    final bool isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedType = type;
          _isCategoryChosen = false;
          final available = kDefaultCategories.where((c) => c.type == type).toList();
          if (available.isNotEmpty) {
            _selectedCategory = available.first;
            _selectedSubcategory = available.first.subcategories.isNotEmpty
                ? available.first.subcategories.first
                : null;
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.black.withOpacity(0.12)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3.5,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(isSelected ? 1.0 : 0.78),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  /// Barra de Plantillas Rápidas (#0097A7)
  Widget _buildTemplatesBar() {
    return InkWell(
      onTap: () {
        setState(() {
          _expression = '50.00';
          _noteController.text = 'Almuerzo ejecutivo';
          _isDefaultValue = false;
        });
      },
      child: Container(
        width: double.infinity,
        color: const Color(0xFF0097A7),
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border_rounded, color: Colors.white, size: 15),
            SizedBox(width: 6),
            Text(
              'PLANTILLAS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Selector de Categoría y Subcategorías Hijas (Flujo Google Stitch)
  Widget _buildCategoryHorizontalSlider() {
    final availableCategories =
        kDefaultCategories.where((c) => c.type == _selectedType).toList();

    return Container(
      color: const Color(0xFF181818),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isCategoryChosen) ...[
            // PASO 1: MOSTRAR CATEGORÍAS DISPONIBLES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '1. SELECCIONAR CATEGORÍA',
                  style: TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                Text(
                  '${availableCategories.length} disponibles',
                  style: const TextStyle(
                    color: Color(0xFF26C6DA),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final cat = availableCategories[index];
                  final bool isSelected = _selectedCategory.id == cat.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                        _selectedSubcategory = cat.subcategories.isNotEmpty
                            ? cat.subcategories.first
                            : null;
                        _isCategoryChosen = true; // Oculta las demás categorías
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF00ACC1).withOpacity(0.18)
                                : const Color(0xFF262626),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00ACC1)
                                  : const Color(0xFF383838),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            cat.icon,
                            color: isSelected
                                ? const Color(0xFF00ACC1)
                                : const Color(0xFFD4D4D4),
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cat.name,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF4DD0E1)
                                : const Color(0xFF9E9E9E),
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            // PASO 2: CATEGORÍA SELECCIONADA CON BOTÓN REGRESAR Y SUBCATEGORÍAS HIJAS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00ACC1).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_selectedCategory.icon,
                            color: const Color(0xFF00ACC1), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CATEGORÍA SELECCIONADA',
                            style: TextStyle(
                              color: Color(0xFFB0BEC5),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            _selectedCategory.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => setState(() => _isCategoryChosen = false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F2F2F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back_rounded,
                              size: 13, color: Color(0xFF26C6DA)),
                          SizedBox(width: 4),
                          Text(
                            'Regresar',
                            style: TextStyle(
                              color: Color(0xFF26C6DA),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Subcategorías Hijas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.label_outline_rounded,
                          size: 13, color: Color(0xFF00E676)),
                      const SizedBox(width: 5),
                      Text(
                        'SUBCATEGORÍAS HIJAS DE ${_selectedCategory.name.toUpperCase()}:',
                        style: const TextStyle(
                          color: Color(0xFFB0BEC5),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Opción General
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: const Text('General'),
                            selected: _selectedSubcategory == null ||
                                _selectedSubcategory!.isEmpty,
                            onSelected: (_) {
                              setState(() => _selectedSubcategory = null);
                            },
                            selectedColor: const Color(0xFF00E676),
                            backgroundColor: const Color(0xFF2C2C2C),
                            labelStyle: TextStyle(
                              color: (_selectedSubcategory == null ||
                                      _selectedSubcategory!.isEmpty)
                                  ? const Color(0xFF003918)
                                  : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                          ),
                        ),
                        // Subcategorías de la categoría seleccionada
                        ..._selectedCategory.subcategories.map((sub) {
                          final isSubSelected = _selectedSubcategory == sub;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(sub),
                              selected: isSubSelected,
                              onSelected: (_) {
                                setState(() => _selectedSubcategory = sub);
                              },
                              selectedColor: const Color(0xFF00ACC1),
                              backgroundColor: const Color(0xFF2C2C2C),
                              labelStyle: TextStyle(
                                color: isSubSelected
                                    ? Colors.black
                                    : Colors.white70,
                                fontSize: 11,
                                fontWeight: isSubSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Campos de Fecha ("Hoy, 10:30 AM") y Nota / Descripción
  Widget _buildDateAndNoteSection(BuildContext context) {
    final formattedTime = DateFormat('h:mm a').format(_selectedDateTime);

    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          // Selector de Fecha y Hora
          InkWell(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDateTime,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedDateTime = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    _selectedDateTime.hour,
                    _selectedDateTime.minute,
                  );
                });
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF00ACC1),
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Hoy, $formattedTime',
                        style: const TextStyle(
                          color: Color(0xFFE0E0E0),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF757575),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Campo de Nota / Descripción
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2C2C2C)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF9E9E9E),
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      hintText:
                          'Nota / Descripción (ej. Almuerzo con clientes)',
                      hintStyle: TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Teclado Numérico Personalizado 4x4 (Estilo Wallet by BudgetBakers)
  Widget _buildCustomCalculatorKeypad() {
    final rows = [
      ['7', '8', '9', '/'],
      ['4', '5', '6', '*'],
      ['1', '2', '3', '-'],
      ['.', '0', 'backspace', '+'],
    ];

    return Container(
      color: const Color(0xFF181818),
      child: Column(
        children: rows.map((rowKeys) {
          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rowKeys.map((key) {
                final bool isOperator = ['/', '*', '-', '+'].contains(key);
                return Expanded(
                  child: InkWell(
                    onTap: () => _onKeyTap(key),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isOperator
                            ? const Color(0xFF141414)
                            : const Color(0xFF181818),
                        border: Border.all(
                          color: const Color(0xFF242424),
                          width: 0.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: key == 'backspace'
                          ? const Icon(
                              Icons.backspace_outlined,
                              color: Color(0xFFD4D4D4),
                              size: 20,
                            )
                          : Text(
                              key == '/'
                                  ? '÷'
                                  : key == '*'
                                      ? '×'
                                      : key == '-'
                                          ? '−'
                                          : key,
                              style: TextStyle(
                                color: isOperator
                                    ? const Color(0xFF9E9E9E)
                                    : const Color(0xFFE5E5E5),
                                fontSize: isOperator ? 22 : 24,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Botón inferior "Guardar Transacción"
  Widget _buildBottomSaveAction(List<AccountModel> accounts) {
    return Container(
      color: const Color(0xFF141414),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed:
              _isSubmitting ? null : () => _handleSaveTransaction(accounts),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00ACC1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 20),
          label: Text(
            _isSubmitting ? 'Guardando...' : 'Guardar Transacción',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _showAccountPickerModal(List<AccountModel> accounts) {
    if (accounts.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Seleccionar Cuenta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...accounts.map((acc) {
                return ListTile(
                  leading: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF00ACC1),
                  ),
                  title: Text(
                    acc.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Text(
                    '${acc.currentBalance.toStringAsFixed(2)} ${acc.currency}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  onTap: () {
                    setState(() => _selectedAccountId = acc.id);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
