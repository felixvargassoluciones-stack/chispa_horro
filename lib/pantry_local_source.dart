import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'pantry_item_model.dart';

/// Clase encargada de ejecutar las operaciones CRUD físicas en la tabla 'pantry_items'.
class PantryLocalSource {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Inserta o actualiza un artículo en la alacena (Upsert).
  Future<void> savePantryItem(PantryItemModel item) async {
    final db = await _dbHelper.database;
    await db.insert(
      'pantry_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // Si el ID existe, sobrescribe de forma segura
    );
  }

  /// Recupera todos los artículos de la alacena activa.
  Future<List<PantryItemModel>> fetchAllPantryItems() async {
    final db = await _dbHelper.database;
    // Recuperamos las filas ordenadas alfabéticamente por nombre
    final List<Map<String, dynamic>> maps = await db.query(
      'pantry_items',
      orderBy: 'name ASC',
    );

    return maps.map((map) => PantryItemModel.fromMap(map)).toList();
  }

  /// Elimina de forma definitiva un artículo de la alacena por su ID.
  Future<void> deletePantryItem(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'pantry_items',
      where: 'id = ?',
      whereArgs: [id], // Previene ataques de inyección SQL de forma nativa
    );
  }

  /// Cambia el estado del booleano (is_checked) para el control financiero en RAM.
  Future<void> toggleItemCheck(String id, bool isChecked) async {
    final db = await _dbHelper.database;
    await db.update(
      'pantry_items',
      {'is_checked': isChecked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
