import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class CategoryPickerField extends StatelessWidget {
  const CategoryPickerField({
    super.key,
    required this.label,
    required this.categories,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.icon = Icons.label_outline_rounded,
  });

  final String label;
  final List<Category> categories;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    Category? selected;
    if (value != null) {
      for (final category in categories) {
        if (category.id == value) {
          selected = category;
          break;
        }
      }
    }

    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final picked = await showCategoryPickerSheet(
                context,
                categories: categories,
                selectedId: value,
                title: label,
              );
              if (picked == null) return;
              onChanged(picked.categoryId);
            },
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          suffixIcon: const Icon(Icons.search_rounded),
        ),
        child: Text(
          selected == null ? 'Seleccionar categoria' : selected.name,
          style: TextStyle(
            color: selected == null
                ? AppTheme.textMuted(context)
                : AppTheme.textPrimary(context),
            fontWeight: selected == null ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class CategoryPickerResult {
  const CategoryPickerResult(this.categoryId);

  final String? categoryId;
}

Future<CategoryPickerResult?> showCategoryPickerSheet(
  BuildContext context, {
  required List<Category> categories,
  required String title,
  String? selectedId,
}) {
  final ordered = [...categories]
    ..sort((a, b) {
      final masterCompare = a.master.compareTo(b.master);
      if (masterCompare != 0) return masterCompare;
      return a.name.compareTo(b.name);
    });

  return showModalBottomSheet<CategoryPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.panel(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      final controller = TextEditingController();
      var query = '';

      return StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = ordered.where((category) {
            final needle = query.trim().toLowerCase();
            if (needle.isEmpty) return true;
            return category.name.toLowerCase().contains(needle) ||
                category.master.toLowerCase().contains(needle);
          }).toList();

          final grouped = <String, List<Category>>{};
          for (final category in filtered) {
            grouped.putIfAbsent(category.master, () => []).add(category);
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      onChanged: (value) => setModalState(() => query = value),
                      decoration: const InputDecoration(
                        hintText: 'Buscar categoria o grupo',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No hay categorias para esa busqueda.',
                                style: TextStyle(
                                  color: AppTheme.textMuted(context),
                                ),
                              ),
                            )
                          : ListView(
                              children: [
                                ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  leading: const Icon(Icons.clear_rounded),
                                  title: const Text('Sin categoria'),
                                  selected: selectedId == null,
                                  onTap: () => Navigator.of(context).pop(
                                    const CategoryPickerResult(null),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (final entry in grouped.entries) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      12,
                                      12,
                                      6,
                                    ),
                                    child: Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textMuted(context),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  for (final category in entry.value)
                                    ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      leading: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Color(
                                            int.parse(
                                              category.colorHex,
                                              radix: 16,
                                            ),
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      title: Text(category.name),
                                      subtitle: Text(category.master),
                                      selected: selectedId == category.id,
                                      onTap: () => Navigator.of(context).pop(
                                        CategoryPickerResult(category.id),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
