import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../providers/firestore_providers.dart';
import '../../models/models.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs =
        ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final user = ref.watch(currentUserProvider);
    final svc = ref.read(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const Divider(),
          ListTile(
            leading:
                const Icon(Icons.palette_outlined, color: AppTheme.primaryColor),
            title: const Text('Tema'),
            subtitle: const Text('Sistema, claro u oscuro'),
          ),
          RadioListTile<String>(
            value: 'system',
            groupValue: prefs.themeMode,
            title: const Text('Sistema'),
            onChanged: user == null
                ? null
                : (_) => svc.updateUserPreferences(
                      user.uid,
                      {'themeMode': 'system'},
                    ),
          ),
          RadioListTile<String>(
            value: 'light',
            groupValue: prefs.themeMode,
            title: const Text('Claro'),
            onChanged: user == null
                ? null
                : (_) => svc.updateUserPreferences(
                      user.uid,
                      {'themeMode': 'light'},
                    ),
          ),
          RadioListTile<String>(
            value: 'dark',
            groupValue: prefs.themeMode,
            title: const Text('Oscuro'),
            onChanged: user == null
                ? null
                : (_) => svc.updateUserPreferences(
                      user.uid,
                      {'themeMode': 'dark'},
                    ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category, color: AppTheme.primaryColor),
            title: const Text('Administrar Categorias'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sell_outlined, color: AppTheme.primaryColor),
            title: const Text('Administrar Etiquetas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TagsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CRUD CATEGORÍAS
// ─────────────────────────────────────────────────────────────────────────────

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String _masterFilter = 'Todos';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final txAsync = ref.watch(allTransactionsStreamProvider);
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        centerTitle: true,
      ),
      body: categoriesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          final usedIds = txAsync.maybeWhen(
            data: (txs) => txs.map((t) => t.categoryId).toSet(),
            orElse: () => <String>{},
          );
          final filtered = (_masterFilter == 'Todos'
                  ? categories
                  : categories.where((c) => c.master == _masterFilter))
              .where((c) {
                final query = _searchQuery.trim().toLowerCase();
                if (query.isEmpty) return true;
                return c.name.toLowerCase().contains(query) ||
                    c.master.toLowerCase().contains(query);
              })
              .toList()
            ..sort((a, b) {
              final masterCompare = a.master.compareTo(b.master);
              if (masterCompare != 0) return masterCompare;
              return a.name.compareTo(b.name);
            });
          if (filtered.isEmpty) {
            return Center(
              child: Text(
                'Aún no hay categorías',
                style: TextStyle(color: AppTheme.textMuted(context)),
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: const InputDecoration(
                        labelText: 'Buscar categoria',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _masterFilter,
                            items: const [
                              DropdownMenuItem(
                                  value: 'Todos', child: Text('Todos')),
                              DropdownMenuItem(value: 'Hogar', child: Text('Hogar')),
                              DropdownMenuItem(
                                  value: 'Transporte',
                                  child: Text('Transporte')),
                              DropdownMenuItem(
                                  value: 'Alimentación',
                                  child: Text('Alimentación')),
                              DropdownMenuItem(
                                  value: 'Servicios', child: Text('Servicios')),
                              DropdownMenuItem(value: 'Salud', child: Text('Salud')),
                              DropdownMenuItem(
                                  value: 'Educación', child: Text('Educación')),
                              DropdownMenuItem(
                                  value: 'Finanzas', child: Text('Finanzas')),
                              DropdownMenuItem(value: 'Ocio', child: Text('Ocio')),
                              DropdownMenuItem(
                                  value: 'Ingresos', child: Text('Ingresos')),
                              DropdownMenuItem(value: 'Otros', child: Text('Otros')),
                            ],
                            onChanged: (v) =>
                                setState(() => _masterFilter = v ?? 'Todos'),
                            decoration: const InputDecoration(
                              labelText: 'Filtrar por master',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: () => _showCategoryDialog(context, ref),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar'),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final category = filtered[i];
                    final showHeader =
                        i == 0 || filtered[i - 1].master != category.master;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                            child: Text(
                              category.master,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textMuted(context),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        _CategoryTile(
                          category: category,
                          usedCategoryIds: usedIds,
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final Category category;
  final Set<String> usedCategoryIds;
  const _CategoryTile({required this.category, required this.usedCategoryIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final color = Color(int.parse(category.colorHex, radix: 16));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getIconForName(category.icon), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    )),
                Text(
                  '${category.master} - ${category.type == CategoryType.income ? 'Ingreso' : 'Egreso'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CategoryActionButton(
            icon: Icons.edit_rounded,
            color: AppTheme.primaryColor,
            onTap: () => _showCategoryDialog(context, ref, initial: category),
          ),
          const SizedBox(width: 6),
          _CategoryActionButton(
            icon: Icons.delete_rounded,
            color: const Color(0xFFD27B64),
            onTap: () async {
              if (usedCategoryIds.contains(category.id)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'No se puede eliminar una categoría con registros')),
                );
                return;
              }
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar categoría'),
                  content: Text(
                      '¿Seguro que deseas eliminar \"${category.name}\"?'),
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
              try {
                await svc.deleteCategory(user.uid, category.id);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se puede eliminar una categoria con movimientos.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

Future<void> _showCategoryDialog(BuildContext context, WidgetRef ref,
    {Category? initial}) async {
  final nameCtrl = TextEditingController(text: initial?.name ?? '');
  CategoryType type = initial?.type ?? CategoryType.expense;
  String colorHex = initial?.colorHex ?? 'FFB68D57';
  String iconName = initial?.icon ?? 'category';
  String master = initial?.master ?? 'Otros';
  final colorOptions = <String>[
    'FFB68D57',
    'FFE7C58F',
    'FFD27B64',
    'FF8F9B7A',
    'FF6D8A96',
    'FF7B7F9E',
    'FFC6A56B',
    'FFB95F5F',
  ];
  if (!colorOptions.contains(colorHex)) {
    colorOptions.insert(0, colorHex);
  }

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(initial == null ? 'Nueva categoría' : 'Editar categoría'),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CategoryType>(
                  value: type,
                  items: const [
                    DropdownMenuItem(
                        value: CategoryType.expense, child: Text('Egreso')),
                    DropdownMenuItem(
                        value: CategoryType.income, child: Text('Ingreso')),
                  ],
                  onChanged: (v) =>
                      setLocal(() => type = v ?? CategoryType.expense),
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: master,
                  items: const [
                    DropdownMenuItem(value: 'Hogar', child: Text('Hogar')),
                    DropdownMenuItem(
                        value: 'Transporte', child: Text('Transporte')),
                    DropdownMenuItem(
                        value: 'Alimentación', child: Text('Alimentación')),
                    DropdownMenuItem(
                        value: 'Servicios', child: Text('Servicios')),
                    DropdownMenuItem(value: 'Salud', child: Text('Salud')),
                    DropdownMenuItem(
                        value: 'Educación', child: Text('Educación')),
                    DropdownMenuItem(
                        value: 'Finanzas', child: Text('Finanzas')),
                    DropdownMenuItem(value: 'Ocio', child: Text('Ocio')),
                    DropdownMenuItem(
                        value: 'Ingresos', child: Text('Ingresos')),
                    DropdownMenuItem(value: 'Otros', child: Text('Otros')),
                  ],
                  onChanged: (v) => setLocal(() => master = v ?? 'Otros'),
                  decoration: const InputDecoration(
                    labelText: 'Categoría master',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: iconName,
                  items: const [
                    DropdownMenuItem(value: 'category', child: Text('Categoría')),
                    DropdownMenuItem(value: 'home', child: Text('Hogar')),
                    DropdownMenuItem(value: 'credit_card', child: Text('Tarjeta')),
                    DropdownMenuItem(value: 'school', child: Text('Estudio')),
                    DropdownMenuItem(value: 'person', child: Text('Persona')),
                    DropdownMenuItem(value: 'phone_android', child: Text('Teléfono')),
                    DropdownMenuItem(value: 'bolt', child: Text('Energía')),
                    DropdownMenuItem(value: 'water_drop', child: Text('Agua')),
                    DropdownMenuItem(value: 'shopping_cart', child: Text('Compras')),
                    DropdownMenuItem(value: 'storefront', child: Text('Tienda')),
                    DropdownMenuItem(value: 'local_gas_station', child: Text('Gasolina')),
                    DropdownMenuItem(value: 'two_wheeler', child: Text('Moto')),
                    DropdownMenuItem(value: 'restaurant', child: Text('Comida')),
                    DropdownMenuItem(value: 'bakery_dining', child: Text('Panadería')),
                    DropdownMenuItem(value: 'directions_bus', child: Text('Transporte')),
                    DropdownMenuItem(value: 'credit_score', child: Text('Crédito')),
                    DropdownMenuItem(value: 'savings', child: Text('Ahorro')),
                    DropdownMenuItem(value: 'payments', child: Text('Pago')),
                    DropdownMenuItem(value: 'swap_horiz', child: Text('Transferencia')),
                  ],
                  onChanged: (v) => setLocal(() => iconName = v ?? 'category'),
                  decoration: const InputDecoration(
                    labelText: 'Ícono',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: colorHex,
                  items: colorOptions
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c == 'FFB68D57'
                                ? 'Oro suave'
                                : c == 'FFE7C58F'
                                    ? 'Arena'
                                    : c == 'FFD27B64'
                                        ? 'Terracota'
                                        : c == 'FF8F9B7A'
                                            ? 'Oliva'
                                            : c == 'FF6D8A96'
                                                ? 'Acero'
                                                : c == 'FF7B7F9E'
                                                    ? 'Pizarra'
                                                    : c == 'FFC6A56B'
                                                        ? 'Miel'
                                                        : c == 'FFB95F5F'
                                                            ? 'Ladrillo'
                                                            : 'Personalizado'),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => colorHex = v ?? 'FFB68D57'),
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    border: OutlineInputBorder(),
                  ),
                ),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                final svc = ref.read(firestoreServiceProvider);
                if (initial == null) {
                  await svc.addCategory(
                    user.uid,
                    Category(
                      id: '',
                      name: name,
                      type: type,
                      colorHex: colorHex,
                      icon: iconName,
                      master: master,
                    ),
                  );
                } else {
                  await svc.updateCategory(user.uid, initial.id, {
                    'name': name,
                    'type': type.name,
                    'colorHex': colorHex,
                    'icon': iconName,
                    'master': master,
                  });
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    ),
  );
}

IconData _getIconForName(String name) {
  switch (name) {
    case 'home':
      return Icons.home_rounded;
    case 'credit_card':
      return Icons.credit_card_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'phone_android':
      return Icons.phone_android_rounded;
    case 'bolt':
      return Icons.bolt_rounded;
    case 'water_drop':
      return Icons.water_drop_rounded;
    case 'shopping_cart':
      return Icons.shopping_cart_rounded;
    case 'storefront':
      return Icons.storefront_rounded;
    case 'local_gas_station':
      return Icons.local_gas_station_rounded;
    case 'two_wheeler':
      return Icons.two_wheeler_rounded;
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'bakery_dining':
      return Icons.bakery_dining_rounded;
    case 'directions_bus':
      return Icons.directions_bus_rounded;
    case 'credit_score':
      return Icons.credit_score_rounded;
    case 'savings':
      return Icons.savings_rounded;
    case 'payments':
      return Icons.payments_rounded;
    case 'swap_horiz':
      return Icons.swap_horiz_rounded;
    default:
      return Icons.category_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CRUD ETIQUETAS
// ─────────────────────────────────────────────────────────────────────────────

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider).value ?? const UserPreferences();
    final user = ref.read(currentUserProvider);
    final svc = ref.read(firestoreServiceProvider);
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etiquetas'),
        centerTitle: true,
      ),
      body: prefs.availableTags.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sell_outlined, size: 64, color: AppTheme.textMuted(context)),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes etiquetas aún',
                    style: TextStyle(color: AppTheme.textMuted(context)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prefs.availableTags.length,
              itemBuilder: (ctx, i) {
                final tag = prefs.availableTags[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.tag_rounded, color: AppTheme.primaryColor),
                    title: Text(tag, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(context, ref, tag, prefs, user, svc),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTagDialog(context, ref, prefs, user, svc),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, WidgetRef ref, UserPreferences prefs, User? user, FirestoreDataService svc) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Etiqueta'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej: Vacaciones, Trabajo...',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isEmpty || user == null) return;
              if (prefs.availableTags.contains(val)) {
                Navigator.pop(ctx);
                return;
              }
              final newTags = [...prefs.availableTags, val];
              await svc.updateUserPreferences(user.uid, {'availableTags': newTags});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String tag, UserPreferences prefs, User? user, FirestoreDataService svc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Etiqueta'),
        content: Text('¿Deseas eliminar la etiqueta "$tag"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (user == null) return;
              final newTags = prefs.availableTags.where((t) => t != tag).toList();
              await svc.updateUserPreferences(user.uid, {'availableTags': newTags});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
