import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Categoría en Flutter Clean Architecture
/// Subcolección Firestore: /users/{userId}/categories/{categoryId}
class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String subtitle;
  final String iconName;
  final String colorHex;
  final String type; // 'expense' | 'income'
  final List<String> subcategories;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.subtitle,
    required this.iconName,
    required this.colorHex,
    required this.type,
    this.subcategories = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  factory CategoryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdTs = data['createdAt'];
    final updatedTs = data['updatedAt'];

    return CategoryModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      subtitle: (data['subtitle'] as String?) ?? '',
      iconName: (data['iconName'] as String?) ?? 'utensils',
      colorHex: (data['colorHex'] as String?) ?? '#00E676',
      type: (data['type'] as String?) ?? 'expense',
      subcategories: List<String>.from((data['subcategories'] as List<dynamic>?) ?? []),
      createdAt: createdTs is Timestamp ? createdTs.toDate() : DateTime.now(),
      updatedAt: updatedTs is Timestamp ? updatedTs.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore({bool isNew = false}) {
    return {
      'userId': userId,
      'name': name.length > 60 ? name.substring(0, 60) : name,
      'subtitle': subtitle.length > 120 ? subtitle.substring(0, 120) : subtitle,
      'iconName': iconName,
      'colorHex': colorHex,
      'type': type,
      'subcategories': subcategories,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
