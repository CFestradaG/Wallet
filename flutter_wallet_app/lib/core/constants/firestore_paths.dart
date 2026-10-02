/// Rutas tipadas para las subcolecciones en Cloud Firestore
/// Garantiza consistencia con las reglas de seguridad (firestore.rules)
class FirestorePaths {
  const FirestorePaths._();

  /// Documento raíz del usuario y configuración: /users/{userId}
  static String userDoc(String userId) => 'users/$userId';

  /// Subcolección de cuentas: /users/{userId}/accounts
  static String accounts(String userId) => 'users/$userId/accounts';
  static String accountDoc(String userId, String accountId) =>
      'users/$userId/accounts/$accountId';

  /// Subcolección de transacciones: /users/{userId}/transactions
  static String transactions(String userId) => 'users/$userId/transactions';
  static String transactionDoc(String userId, String transactionId) =>
      'users/$userId/transactions/$transactionId';

  /// Subcolección de categorías: /users/{userId}/categories
  static String categories(String userId) => 'users/$userId/categories';
  static String categoryDoc(String userId, String categoryId) =>
      'users/$userId/categories/$categoryId';

  /// Subcolección de presupuestos: /users/{userId}/budgets
  static String budgets(String userId) => 'users/$userId/budgets';
  static String budgetDoc(String userId, String budgetId) =>
      'users/$userId/budgets/$budgetId';

  /// Subcolección de resúmenes por período financiero: /users/{userId}/summaries/{periodId}
  /// Ejemplo de periodId: 'period_2026_11'
  static String summaries(String userId) => 'users/$userId/summaries';
  static String summaryDoc(String userId, String periodId) =>
      'users/$userId/summaries/$periodId';
}
