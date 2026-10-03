import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/firestore_providers.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_picker_field.dart';

class VehiclesTab extends ConsumerWidget {
  const VehiclesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesStreamProvider);
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      appBar: AppBar(
        title: const Text('Mis Rendimientos'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Agregar rendimiento',
            onPressed: () => _showAddPerformanceDialog(context, ref),
            icon: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
          ),
        ],
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return _EmptyVehicles(isDark: isDark);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: vehicles.length,
            itemBuilder: (context, i) =>
                _VehicleCard(vehicle: vehicles[i], isDark: isDark, ref: ref),
          );
        },
      ),
    );
  }

  // ignore: unused_element
  void _showAddFuelDialog(BuildContext context, WidgetRef ref,
      {required List<Vehicle> vehicles}) {
    // Implementado en _VehicleCard
  }

  void _showAddPerformanceDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final measureCtrl = TextEditingController(text: '0');
    final unitCtrl = TextEditingController(text: 'km');
    final fuelBrandCtrl = TextEditingController();
    String? defaultCategoryId;
    String kind = 'vehicle';
    String vehicleType = 'car';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final isVehicle = kind == 'vehicle';
            final measureLabel = _measureLabelForKind(kind);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Nuevo rendimiento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: kind,
                      items: const [
                        DropdownMenuItem(
                            value: 'vehicle', child: Text('Vehículo')),
                        DropdownMenuItem(
                            value: 'energy', child: Text('Energía')),
                        DropdownMenuItem(
                            value: 'study', child: Text('Estudio')),
                      ],
                      onChanged: (v) => setLocal(() {
                        kind = v ?? 'vehicle';
                        unitCtrl.text = kind == 'energy'
                            ? 'kWh'
                            : kind == 'study'
                                ? 'cr'
                                : 'km';
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (isVehicle) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: vehicleType,
                        items: const [
                          DropdownMenuItem(
                              value: 'car', child: Text('Carro')),
                          DropdownMenuItem(
                              value: 'motorcycle', child: Text('Moto')),
                        ],
                        onChanged: (v) =>
                            setLocal(() => vehicleType = v ?? 'car'),
                        decoration: const InputDecoration(
                          labelText: 'Subtipo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: measureCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '$measureLabel actual',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitCtrl,
                      enabled: !isVehicle,
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (isVehicle) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: fuelBrandCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Gasolinera habitual (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ref.watch(categoriesStreamProvider).when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (categories) {
                        final filtered = categories
                            .where((c) => c.type == CategoryType.expense)
                            .toList();
                        defaultCategoryId ??=
                            filtered.isNotEmpty ? filtered.first.id : null;
                        return CategoryPickerField(
                          label: 'Categoria por defecto',
                          categories: filtered,
                          value: defaultCategoryId,
                          onChanged: (v) =>
                              setLocal(() => defaultCategoryId = v),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final measure =
                        double.tryParse(measureCtrl.text) ?? 0.0;
                    final user = ref.read(currentUserProvider);
                    if (user == null) return;
                    final svc = ref.read(firestoreServiceProvider);
                    final unitText = unitCtrl.text.trim().isEmpty
                        ? (kind == 'energy'
                            ? 'kWh'
                            : kind == 'study'
                                ? 'cr'
                                : 'km')
                        : unitCtrl.text.trim();
                    await svc.addVehicle(
                      user.uid,
                      Vehicle(
                        id: '',
                        name: name,
                        type: isVehicle ? vehicleType : kind,
                        kind: kind,
                        measureUnit: unitText,
                        odometer: measure,
                        fuelBrand: fuelBrandCtrl.text.trim(),
                        defaultCategoryId: defaultCategoryId,
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EmptyVehicles extends StatelessWidget {
  final bool isDark;
  const _EmptyVehicles({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_filled_rounded,
              size: 72,
              color: AppTheme.primaryColor.withValues(alpha: 0.8)),
          const SizedBox(height: 24),
          const Text('Aún no tienes rendimientos',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(
            'Registra tus rendimientos para llevar control\nde vehículos, energía, estudios y más.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? const Color(0xFF7B7F9E) : Colors.grey.shade500, fontSize: 15),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Usa el botón “Agregar rendimiento”')),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Agregar rendimiento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends ConsumerStatefulWidget {
  final Vehicle vehicle;
  final bool isDark;
  final WidgetRef ref;

  const _VehicleCard({
    required this.vehicle,
    required this.isDark,
    required this.ref,
  });

  @override
  ConsumerState<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends ConsumerState<_VehicleCard> {
  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final fuelAsync = ref.watch(fuelRecordsProvider(v.id));
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final isVehicle = v.isVehicle;
    final isCar = v.type == 'car';
    final cardBg = widget.isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final measureLabel = _measureLabelForKind(v.kind);
    final measureText = _formatMeasure(v.odometer, v.measureUnit);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.panelAlt(context),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconForKind(v.kind, isCar),
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.name,
                        style: TextStyle(
                            color: AppTheme.textPrimary(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                      if (v.fuelBrand.isNotEmpty)
                        Text(v.fuelBrand,
                            style: TextStyle(
                                color: AppTheme.textMuted(context), fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(measureLabel,
                        style: TextStyle(
                            color: AppTheme.textMuted(context), fontSize: 11)),
                    Text(
                      '$measureText ${v.measureUnit}',
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => _showEditPerformanceDialog(context, v),
                  icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryColor),
                  tooltip: 'Editar rendimiento',
                ),
              ],
            ),
          ),

          // Registros de combustible (solo vehículo)
          if (isVehicle)
            fuelAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryColor),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (records) {
                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sin registros de combustible',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              v.fuelBrand.isNotEmpty
                                  ? v.fuelBrand
                                  : (isCar
                                      ? 'Gasolina Shell/Puma'
                                      : '~38 km/litro estimado'),
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                        _addFuelButton(context, v),
                      ],
                    ),
                  );
                }

                final lastRecord = records.first;
              final avgKmL = records
                  .where((r) => r.kmPerLiter != null)
                  .map((r) => r.kmPerLiter!)
                  .fold<double>(0, (s, v) => s + v);
              final avgCount =
                  records.where((r) => r.kmPerLiter != null).length;
              final avg = avgCount > 0 ? avgKmL / avgCount : null;
              final unitLabel = lastRecord.unit;

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                        _statBox('Rendimiento promedio',
                            avg != null
                                ? '${avg.toStringAsFixed(1)} km/$unitLabel'
                                : 'N/A',
                            AppTheme.primaryColor),
                        _statBox(
                            'Última carga',
                            '${lastRecord.liters.toStringAsFixed(1)} $unitLabel',
                            AppTheme.primaryColor),
                          _addFuelButton(context, v),
                        ],
                      ),
                      if (lastRecord.stationName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Gasolinera: ${lastRecord.stationName}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statBox('Medida actual',
                      '$measureText ${v.measureUnit}', AppTheme.primaryColor),
                  OutlinedButton.icon(
                    onPressed: () => _showUpdateMeasureDialog(context, v),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Actualizar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          if (v.defaultCategoryId != null)
            categoriesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (cats) {
                final cat = cats.firstWhere(
                  (c) => c.id == v.defaultCategoryId,
                  orElse: () => Category(
                    id: '',
                    name: 'Sin categoría',
                    type: CategoryType.expense,
                    colorHex: 'FF7B7F9E',
                  ),
                );
                if (cat.id.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Categoría por defecto: ${cat.name}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }

  Widget _addFuelButton(BuildContext context, Vehicle v) {
    return OutlinedButton.icon(
      onPressed: () => _showFuelDialog(context, v),
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Cargar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        side: const BorderSide(color: AppTheme.primaryColor),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showFuelDialog(BuildContext context, Vehicle v) {
    final litersCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final odomCtrl =
        TextEditingController(text: v.odometer.toStringAsFixed(0));
    final stationCtrl = TextEditingController();
    String unit = 'L';
    String? accountId;
    String? categoryId;
    TransactionType txType = TransactionType.expense;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final accountsAsync = ref.watch(accountsStreamProvider);
          final categoriesAsync = ref.watch(categoriesStreamProvider);
          final period = ref.read(activePeriodProvider).value;
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('Registrar carga — ${v.name}'),
            content: SizedBox(
              width: 320,
              child: ListView(
                shrinkWrap: true,
                children: [
                  TextField(
                    controller: litersCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      prefixIcon: Icon(Icons.local_gas_station),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: unit,
                    items: const [
                      DropdownMenuItem(value: 'L', child: Text('Litros')),
                      DropdownMenuItem(value: 'gal', child: Text('Galones')),
                    ],
                    onChanged: (v) => setLocal(() => unit = v ?? 'L'),
                    decoration: const InputDecoration(
                      labelText: 'Unidad',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Precio por unidad (Q)',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: odomCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Odómetro actual (km)',
                      prefixIcon: Icon(Icons.speed),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Gasolinera (opcional)',
                      prefixIcon: Icon(Icons.storefront_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  accountsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (accounts) {
                      final sources = accounts;
                      accountId ??=
                          sources.isNotEmpty ? sources.first.id : null;
                      return DropdownButtonFormField<String>(
                        value: accountId,
                        items: sources
                            .map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.name),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setLocal(() => accountId = v),
                        decoration: const InputDecoration(
                          labelText: 'Cuenta afectada',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TransactionType>(
                    value: txType,
                    items: const [
                      DropdownMenuItem(
                          value: TransactionType.expense,
                          child: Text('Salida')),
                      DropdownMenuItem(
                          value: TransactionType.income,
                          child: Text('Ingreso')),
                    ],
                    onChanged: (v) =>
                        setLocal(() => txType = v ?? TransactionType.expense),
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (categories) {
                      final filtered = categories
                          .where((c) => c.type == (txType == TransactionType.expense
                              ? CategoryType.expense
                              : CategoryType.income))
                          .toList();
                      categoryId ??=
                          filtered.isNotEmpty ? filtered.first.id : null;
                      return CategoryPickerField(
                        label: 'Categoria',
                        categories: filtered,
                        value: categoryId,
                        onChanged: (v) =>
                            setLocal(() => categoryId = v),
                      );
                    },
                  ),
                  if (period == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'No hay período activo',
                      style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor),
                onPressed: () async {
                  final liters = double.tryParse(litersCtrl.text) ?? 0;
                  final price = double.tryParse(priceCtrl.text) ?? 0;
                  final odom = double.tryParse(odomCtrl.text) ?? 0;
                  if (liters <= 0 || price <= 0) return;
                  if (period == null) return;
                  if (accountId == null || categoryId == null) return;

                  final user = ref.read(currentUserProvider);
                  if (user == null) return;

                  final total = liters * price;
                  final svc = ref.read(firestoreServiceProvider);
                  await svc.addFuelRecord(
                    user.uid,
                    v.id,
                    FuelRecord(
                      id: '',
                      vehicleId: v.id,
                      date: DateTime.now(),
                      liters: liters,
                      pricePerLiter: price,
                      odometerAtFill: odom,
                      previousOdometer: v.odometer > 0 ? v.odometer : null,
                      stationName: stationCtrl.text.trim(),
                      unit: unit,
                      accountId: accountId,
                      categoryId: categoryId,
                      txType: txType,
                      amount: total,
                    ),
                  );
                  await svc.addTransaction(
                    user.uid,
                    TransactionRecord(
                      id: '',
                      amount: total,
                      type: txType,
                      accountId: accountId!,
                      categoryId: categoryId!,
                      periodId: period.id,
                      date: DateTime.now(),
                      note: 'Carga ${v.name} (${unit})',
                      paymentMethod: PaymentMethod.card,
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpdateMeasureDialog(BuildContext context, Vehicle v) {
    final valueCtrl =
        TextEditingController(text: v.odometer.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Actualizar ${_measureLabelForKind(v.kind)}'),
        content: TextField(
          controller: valueCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Nuevo valor (${v.measureUnit})',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final value = double.tryParse(valueCtrl.text) ?? v.odometer;
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              final svc = ref.read(firestoreServiceProvider);
              await svc.updateVehicle(user.uid, v.id, {
                'odometer': value,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditPerformanceDialog(BuildContext context, Vehicle v) {
    final nameCtrl = TextEditingController(text: v.name);
    final fuelBrandCtrl = TextEditingController(text: v.fuelBrand);
    String? defaultCategoryId = v.defaultCategoryId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Editar rendimiento'),
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
                  if (v.isVehicle) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: fuelBrandCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Gasolinera habitual (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ref.watch(categoriesStreamProvider).when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (categories) {
                          final filtered = categories
                              .where((c) => c.type == CategoryType.expense)
                              .toList();
                          defaultCategoryId ??=
                              filtered.isNotEmpty ? filtered.first.id : null;
                          return CategoryPickerField(
                            label: 'Categoria por defecto',
                            categories: filtered,
                            value: defaultCategoryId,
                            onChanged: (v) =>
                                setLocal(() => defaultCategoryId = v),
                          );
                        },
                      ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor),
                onPressed: () async {
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;
                  final svc = ref.read(firestoreServiceProvider);
                  await svc.updateVehicle(user.uid, v.id, {
                    'name': nameCtrl.text.trim(),
                    'fuelBrand': fuelBrandCtrl.text.trim(),
                    'defaultCategoryId': defaultCategoryId,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _measureLabelForKind(String kind) {
  switch (kind) {
    case 'energy':
      return 'Energía';
    case 'study':
      return 'Créditos';
    default:
      return 'Odómetro';
  }
}

IconData _iconForKind(String kind, bool isCar) {
  switch (kind) {
    case 'energy':
      return Icons.bolt_rounded;
    case 'study':
      return Icons.school_rounded;
    default:
      return isCar ? Icons.directions_car : Icons.two_wheeler;
  }
}

String _formatMeasure(double value, String unit) {
  if (unit == 'km') return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
