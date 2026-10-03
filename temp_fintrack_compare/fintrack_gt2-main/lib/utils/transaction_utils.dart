import '../models/models.dart';

class TransactionUtils {
  static bool isPerformanceTransaction(
    TransactionRecord tx,
    Map<String, Category> categoriesById,
  ) {
    final category = categoriesById[tx.categoryId];
    final icon = category?.icon ?? '';
    final note = tx.note.toLowerCase();
    
    // Basado en el icono de la categoria o palabras clave en la nota
    return icon == 'local_gas_station' ||
        icon == 'bolt' ||
        icon == 'school' ||
        note.startsWith('carga ') ||
        note.contains('combustible') ||
        note.contains('electricidad');
  }
}
