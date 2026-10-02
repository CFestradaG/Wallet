import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de Configuración de Períodos Financieros del Usuario
/// Almacenado en el documento raíz: /users/{userId}
class UserSettingsModel {
  final String userId;
  final String displayName;
  final String defaultCurrency;

  /// Día del mes en que inicia el nuevo período financiero (1..31, ej. 27).
  /// Si pagan el 27, el 27 de octubre inicia el período financiero de Noviembre ("2026-11").
  final int startDayOfMonth;

  /// Habilita la división interna del período en dos fases (Inicio de mes / Quincena).
  final bool enableSplitPeriod;

  /// Día del mes en que inicia la segunda fase o quincena (1..31, ej. 13).
  final int midMonthDay;

  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSettingsModel({
    required this.userId,
    required this.displayName,
    this.defaultCurrency = 'GTQ',
    this.startDayOfMonth = 27,
    this.enableSplitPeriod = true,
    this.midMonthDay = 13,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettingsModel.defaults(String userId, {String? displayName}) {
    final now = DateTime.now();
    return UserSettingsModel(
      userId: userId,
      displayName: displayName ?? 'Francisco Estrada',
      defaultCurrency: 'GTQ',
      startDayOfMonth: 27,
      enableSplitPeriod: true,
      midMonthDay: 13,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory UserSettingsModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data();
    if (data == null) {
      return UserSettingsModel.defaults(doc.id);
    }

    final createdTs = data['createdAt'];
    final updatedTs = data['updatedAt'];

    return UserSettingsModel(
      userId: (data['userId'] as String?) ?? doc.id,
      displayName: (data['displayName'] as String?) ?? 'Francisco Estrada',
      defaultCurrency: (data['defaultCurrency'] as String?) ?? 'GTQ',
      startDayOfMonth:
          ((data['startDayOfMonth'] as num?)?.toInt() ?? 27).clamp(1, 31),
      enableSplitPeriod: (data['enableSplitPeriod'] as bool?) ?? true,
      midMonthDay: ((data['midMonthDay'] as num?)?.toInt() ?? 13).clamp(1, 31),
      createdAt: createdTs is Timestamp ? createdTs.toDate() : DateTime.now(),
      updatedAt: updatedTs is Timestamp ? updatedTs.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore({bool isNew = false}) {
    return {
      'userId': userId,
      'displayName':
          displayName.length > 100 ? displayName.substring(0, 100) : displayName,
      'defaultCurrency': defaultCurrency,
      'startDayOfMonth': startDayOfMonth.clamp(1, 31),
      'enableSplitPeriod': enableSplitPeriod,
      'midMonthDay': midMonthDay.clamp(1, 31),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserSettingsModel copyWith({
    String? displayName,
    String? defaultCurrency,
    int? startDayOfMonth,
    bool? enableSplitPeriod,
    int? midMonthDay,
    DateTime? updatedAt,
  }) {
    return UserSettingsModel(
      userId: userId,
      displayName: displayName ?? this.displayName,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      startDayOfMonth: startDayOfMonth ?? this.startDayOfMonth,
      enableSplitPeriod: enableSplitPeriod ?? this.enableSplitPeriod,
      midMonthDay: midMonthDay ?? this.midMonthDay,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
