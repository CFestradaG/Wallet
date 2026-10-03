import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../providers/firestore_providers.dart';
import '../theme/app_theme.dart';

class PeriodsScreen extends ConsumerStatefulWidget {
  final bool openCreate;

  const PeriodsScreen({super.key, this.openCreate = false});

  @override
  ConsumerState<PeriodsScreen> createState() => _PeriodsScreenState();
}

class _PeriodsScreenState extends ConsumerState<PeriodsScreen> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final periodsAsync = ref.watch(periodsStreamProvider);
    final isDark = AppTheme.isDark(context);

    if (widget.openCreate && !_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const EditPeriodScreen(),
            fullscreenDialog: true,
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: const Text('Períodos'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EditPeriodScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        ],
      ),
      body: periodsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppTheme.primaryColor)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (periods) {
          if (periods.isEmpty) {
            return Center(
              child: Text(
                'No hay períodos registrados.',
                style: TextStyle(
                  color: AppTheme.textMuted(context),
                ),
              ),
            );
          }
          periods.sort((a, b) => b.startDate.compareTo(a.startDate));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (ctx, i) {
              final p = periods[i];
              return _PeriodTile(period: p, allPeriods: periods);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: periods.length,
          );
        },
      ),
    );
  }
}

class _PeriodTile extends ConsumerWidget {
  final Period period;
  final List<Period> allPeriods;

  const _PeriodTile({required this.period, required this.allPeriods});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd/MM/yyyy');
    final isActive = period.isActive;
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : AppTheme.panel(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppTheme.primaryColor : AppTheme.border(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.date_range_rounded,
              color: isActive ? Colors.black : AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.name,
                  style: TextStyle(
                    color:
                        isActive ? Colors.black : AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${fmt.format(period.startDate)} - ${fmt.format(period.endDate)}',
                  style: TextStyle(
                    color: isActive
                        ? Colors.black.withValues(alpha: 0.7)
                        : AppTheme.textMuted(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: isActive ? Colors.black : AppTheme.textMuted(context)),
            onSelected: (v) async {
              if (v == 'edit') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditPeriodScreen(period: period),
                    fullscreenDialog: true,
                  ),
                );
                return;
              }
              if (v == 'active') {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                final svc = ref.read(firestoreServiceProvider);
                await svc.setActivePeriod(user.uid, period.id);
                return;
              }
              if (v == 'delete') {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                final svc = ref.read(firestoreServiceProvider);
                await svc.deletePeriod(user.uid, period.id);
                return;
              }
              if (v == 'replicate') {
                await _replicateYear(context, ref, period, allPeriods);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              const PopupMenuItem(value: 'active', child: Text('Activar')),
              const PopupMenuItem(
                  value: 'replicate', child: Text('Replicar año')),
              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _replicateYear(
  BuildContext context,
  WidgetRef ref,
  Period template,
  List<Period> existing,
) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  final svc = ref.read(firestoreServiceProvider);
  final year = DateTime.now().year;

  final startDay = template.startDate.day;
  final endDay = template.endDate.day;
  final monthOffset = (template.endDate.year - template.startDate.year) * 12 +
      (template.endDate.month - template.startDate.month);

  int created = 0;
  for (var month = 1; month <= 12; month++) {
    final start = _safeDate(year, month, startDay);
    final end = _safeDate(year, month + monthOffset, endDay);
    if (_overlapsAny(start, end, existing)) {
      continue;
    }
    final name = DateFormat('MMMM yyyy', 'es').format(start);
    final period = Period(
      id: '',
      name: _capitalize(name),
      startDate: start,
      endDate: end,
      subperiods: const [],
      isActive: false,
    );
    await svc.addPeriod(user.uid, period);
    created++;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Períodos creados: $created')),
  );
}

bool _overlapsAny(DateTime start, DateTime end, List<Period> existing) {
  for (final p in existing) {
    final overlaps = !end.isBefore(p.startDate) && !start.isAfter(p.endDate);
    if (overlaps) return true;
  }
  return false;
}

DateTime _safeDate(int year, int month, int day) {
  final base = DateTime(year, month, 1);
  final lastDay = DateTime(year, month + 1, 0).day;
  final safeDay = day > lastDay ? lastDay : day;
  return DateTime(year, month, safeDay);
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

class EditPeriodScreen extends ConsumerStatefulWidget {
  final Period? period;

  const EditPeriodScreen({super.key, this.period});

  @override
  ConsumerState<EditPeriodScreen> createState() =>
      _EditPeriodScreenState();
}

class _EditPeriodScreenState extends ConsumerState<EditPeriodScreen> {
  final _nameController = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.period;
    if (p != null) {
      _nameController.text = p.name;
      _start = p.startDate;
      _end = p.endDate;
      _isActive = p.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: Text(widget.period == null
            ? 'Nuevo Período'
            : 'Editar Período'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildField(
              isDark: isDark,
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildField(
              isDark: isDark,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded,
                    color: AppTheme.primaryColor),
                title: Text('Inicio: ${fmt.format(_start)}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setState(() => _start = picked);
                },
              ),
            ),
            const SizedBox(height: 14),
            _buildField(
              isDark: isDark,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_rounded,
                    color: AppTheme.primaryColor),
                title: Text('Fin: ${fmt.format(_end)}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _end,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setState(() => _end = picked);
                },
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('Período activo'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _saving ? 'Guardando...' : 'Guardar',
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_end.isBefore(_start)) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final svc = ref.read(firestoreServiceProvider);
    final existing = ref.read(periodsStreamProvider).value ?? [];
    final hasOverlap = existing.any((p) {
      if (widget.period != null && p.id == widget.period!.id) return false;
      return !_end.isBefore(p.startDate) && !_start.isAfter(p.endDate);
    });
    if (hasOverlap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El período se sobrepone con otro')),
      );
      return;
    }
    setState(() => _saving = true);
    if (widget.period == null) {
      final period = Period(
        id: '',
        name: name,
        startDate: _start,
        endDate: _end,
        subperiods: const [],
        isActive: _isActive,
      );
      final newId = await svc.addPeriod(user.uid, period);
      if (_isActive) {
        await svc.setActivePeriod(user.uid, newId);
      }
    } else {
      await svc.updatePeriod(user.uid, widget.period!.id, {
        'name': name,
        'startDate': Timestamp.fromDate(_start),
        'endDate': Timestamp.fromDate(_end),
        'isActive': _isActive,
      });
      if (_isActive) {
        await svc.setActivePeriod(user.uid, widget.period!.id);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }
}

Widget _buildField({required bool isDark, required Widget child}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.surfaceDarkHigh : AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
      ),
    ),
    child: child,
  );
}
