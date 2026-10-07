import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'purchase_record_model.dart';

/// Operaciones relacionales sobre la tabla 'purchase_history'.
/// Diseñado para alimentar el cálculo del desgaste predictivo de la IA.
class HistoryLocalSource {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Inserta una nueva fila de compra cronológica inmutable.
  Future<void> insertPurchaseRecord(PurchaseRecordModel record) async {
    final db = await _dbHelper.database;
    await db.insert(
      'purchase_history',
      record.toMap(),
      // Nunca reemplaza registros históricos, siempre añade filas nuevas incrementalmente
      conflictAlgorithm: ConflictAlgorithm.abort, 
    );
  }

  /// Recupera la bitácora completa de productos comprados de forma descendente.
  Future<List<PurchaseRecordModel>> fetchFullHistory() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchase_history',
      orderBy: 'purchase_date DESC, id DESC',
    );

    return maps.map((map) => PurchaseRecordModel.fromMap(map)).toList();
  }

  /// CORE DE LA IA: Obtiene las últimas 2 filas de compra de un artículo específico.
  /// Sirve para restar las fechas y calcular el hábito dinámico de consumo.
  Future<List<PurchaseRecordModel>> fetchLastTwoPurchases(String cleanProductName) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchase_history',
      where: 'product_name = ?',
      whereArgs: [cleanProductName],
      orderBy: 'purchase_date DESC, id DESC',
      limit: 2, // Límite estricto de dos registros optimizado en memoria
    );

    return maps.map((map) => PurchaseRecordModel.fromMap(map)).toList();
  }

  /// Borra por completo el búnker histórico (Acción del botón de vaciar memoria).
  Future<void> clearHistoryCache() async {
    final db = await _dbHelper.database;
    await db.delete('purchase_history');
  }
}
