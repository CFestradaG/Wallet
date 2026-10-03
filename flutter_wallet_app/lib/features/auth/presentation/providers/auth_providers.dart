import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../categories/data/models/category_model.dart';

final authStateStreamProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

Future<UserCredential> signInWithGoogle() async {
  final auth = FirebaseAuth.instance;
  final provider = GoogleAuthProvider()..addScope('email');
  final credential = kIsWeb
      ? await auth.signInWithPopup(provider)
      : await auth.signInWithProvider(provider);
  final user = credential.user;
  if (user != null) await ensureUserSeeded(user);
  return credential;
}

Future<void> ensureUserSeeded(User user) async {
  final firestore = FirebaseFirestore.instance;
  final userRef = firestore.doc(FirestorePaths.userDoc(user.uid));
  final userSnapshot = await userRef.get();
  final accountsRef = firestore.collection(FirestorePaths.accounts(user.uid));
  final categoriesRef = firestore.collection(
    FirestorePaths.categories(user.uid),
  );
  final accountsSnapshot = await accountsRef.limit(1).get();
  final categoriesSnapshot = await categoriesRef.get();
  final existingCategoryIds = categoriesSnapshot.docs
      .map((doc) => doc.id)
      .toSet();
  final now = DateTime.now();
  final batch = firestore.batch();
  var hasWrites = false;

  if (!userSnapshot.exists) {
    batch.set(userRef, {
      'userId': user.uid,
      'displayName': (user.displayName ?? 'Mi Usuario').substring(
        0,
        (user.displayName ?? 'Mi Usuario').length.clamp(0, 100),
      ),
      'defaultCurrency': 'GTQ',
      'startDayOfMonth': 27,
      'enableSplitPeriod': true,
      'midMonthDay': 13,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    hasWrites = true;
  }

  if (accountsSnapshot.docs.isEmpty) {
    for (final account in [
      {
        'id': 'acc_efectivo',
        'name': 'Efectivo',
        'type': 'cash',
        'colorHex': '#00DCF5',
        'iconName': 'payments',
        'subtitle': 'Billetera / Efectivo disponible',
      },
      {
        'id': 'acc_banco',
        'name': 'Cuenta Bancaria',
        'type': 'bank',
        'colorHex': '#00E676',
        'iconName': 'account_balance',
        'subtitle': 'Cuenta monetaria o ahorros',
      },
    ]) {
      batch.set(accountsRef.doc(account['id']), {
        ...account,
        'userId': user.uid,
        'balance': 0.0,
        'currentBalance': 0.0,
        'currency': 'GTQ',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    hasWrites = true;
  }

  for (final category in _defaultCategories(user.uid, now)) {
    if (existingCategoryIds.add(category.id)) {
      batch.set(
        categoriesRef.doc(category.id),
        category.toFirestore(isNew: true),
      );
      hasWrites = true;
    }
  }

  if (hasWrites) await batch.commit();
}

List<CategoryModel> _defaultCategories(String userId, DateTime now) => [
  _category(
    userId,
    now,
    'cat_comida',
    'Comida y Bebida',
    'Restaurantes, cafeterías y delivery',
    'utensils',
    '#00E676',
    'expense',
    [
      'Restaurantes',
      'Cafeterías',
      'Comida Rápida',
      'Delivery / Pedidos',
      'Almuerzo Trabajo',
    ],
  ),
  _category(
    userId,
    now,
    'cat_mercado',
    'Supermercado',
    'Abarrotes y despensa del hogar',
    'shopping_cart',
    '#FFB300',
    'expense',
    [
      'Abarrotes y Despensa',
      'Frutas y Verduras',
      'Carnes y Embutidos',
      'Limpieza y Hogar',
      'Bebidas',
    ],
  ),
  _category(
    userId,
    now,
    'cat_servicios',
    'Vivienda y Servicios',
    'Alquiler, Luz, Agua, Fibra, Gas',
    'wifi',
    '#00DCF5',
    'expense',
    [
      'Alquiler / Hipoteca',
      'Electricidad',
      'Internet / Fibra Óptica',
      'Agua Potable',
      'Gas Propano',
      'Mantenimiento',
    ],
  ),
  _category(
    userId,
    now,
    'cat_transporte',
    'Transporte y Gasolina',
    'Combustible, peajes, parqueo, taller',
    'fuel',
    '#FF5252',
    'expense',
    [
      'Gasolina / Combustible',
      'Uber / Taxi / Indrive',
      'Peajes (VAS/Palín)',
      'Mantenimiento / Taller',
      'Parqueos',
      'Transporte Público',
    ],
  ),
  _category(
    userId,
    now,
    'cat_ocio',
    'Entretenimiento y Ocio',
    'Streaming, cine, salidas, hobbies',
    'film',
    '#9C27B0',
    'expense',
    [
      'Streaming (Netflix/Spotify)',
      'Cine y Eventos',
      'Salidas y Fiestas',
      'Videojuegos y Hobbies',
      'Vacaciones',
    ],
  ),
  _category(
    userId,
    now,
    'cat_salud',
    'Salud y Farmacia',
    'Medicamentos, consultas médicas',
    'heart_pulse',
    '#FF5252',
    'expense',
    [
      'Farmacia y Medicinas',
      'Consultas Médicas',
      'Laboratorios y Exámenes',
      'Cuidado Personal y Óptica',
      'Seguro Médico',
    ],
  ),
  _category(
    userId,
    now,
    'cat_educacion',
    'Educación y Cursos',
    'Universidad, cursos y certificaciones',
    'briefcase',
    '#26A69A',
    'expense',
    [
      'Colegiatura / Universidad',
      'Cursos y Certificaciones',
      'Libros y Materiales',
      'Plataformas Educativas',
    ],
  ),
  _category(
    userId,
    now,
    'cat_compras',
    'Compras y Ropa',
    'Ropa, calzado, gadgets y hogar',
    'shopping_cart',
    '#EC407A',
    'expense',
    [
      'Ropa y Calzado',
      'Electrónica / Gadgets',
      'Accesorios',
      'Hogar y Decoración',
    ],
  ),
  _category(
    userId,
    now,
    'cat_salario',
    'Salario y Nómina',
    'Sueldo quincenal, mensual y bonos',
    'briefcase',
    '#00E676',
    'income',
    [
      'Sueldo Quincenal',
      'Sueldo Fin de Mes',
      'Bono 14',
      'Aguinaldo',
      'Horas Extras',
    ],
  ),
  _category(
    userId,
    now,
    'cat_negocio',
    'Negocio y Ventas',
    'Ventas, clientes y servicios independientes',
    'shopping_cart',
    '#00DCF5',
    'income',
    [
      'Venta de Productos',
      'Servicios Prestados',
      'Comisiones',
      'Cobro de Facturas',
    ],
  ),
  _category(
    userId,
    now,
    'cat_inversiones',
    'Inversiones y Rendimientos',
    'Dividendos, intereses y rentas',
    'briefcase',
    '#FFB300',
    'income',
    [
      'Dividendos',
      'Intereses Bancarios',
      'Cripto / Acciones',
      'Alquileres Cobrados',
    ],
  ),
  _category(
    userId,
    now,
    'cat_otros_ingresos',
    'Otros Ingresos',
    'Regalos, reembolsos y varios',
    'heart_pulse',
    '#AB47BC',
    'income',
    [
      'Regalos y Donaciones',
      'Reembolsos',
      'Premios y Sorteos',
      'Préstamos Recibidos',
    ],
  ),
];

CategoryModel _category(
  String userId,
  DateTime now,
  String id,
  String name,
  String subtitle,
  String icon,
  String color,
  String type,
  List<String> subcategories,
) => CategoryModel(
  id: id,
  userId: userId,
  name: name,
  subtitle: subtitle,
  iconName: icon,
  colorHex: color,
  type: type,
  subcategories: subcategories,
  createdAt: now,
  updatedAt: now,
);
