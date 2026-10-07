import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'chispahorro.db');

    final db = await openDatabase(
      pathString,
      version: 6, // 🚀 EVOLUCIÓN A VERSIÓN 6: Incorporación nativa de real_price para congelar cálculos
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );

    // Ejecuta de forma automática la poda de datos antiguos al levantar la conexión
    await purgeOldHistory(db);
    return db;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Tabla 1: Alacena Activa (Potenciada con real_price v6)
    batch.execute('''
      CREATE TABLE pantry_items (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        estimated_price REAL NOT NULL DEFAULT 0.0,
        real_price REAL, -- 🚀 SOPORTE v6: Almacena de forma aislada el precio capturado en góndola
        quantity REAL NOT NULL DEFAULT 1.0,
        unit TEXT NOT NULL,
        category TEXT NOT NULL,
        is_checked INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        last_price_paid REAL NOT NULL DEFAULT 0.0,
        supermarket_id TEXT NOT NULL DEFAULT 'Casa'
      )
    ''');

    // Tabla 2: Búnker Perpetuo de la IA (Historial Acumulativo de Hábitos)
    batch.execute('''
      CREATE TABLE purchase_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_name TEXT NOT NULL,
        category TEXT NOT NULL,
        price_paid REAL NOT NULL,
        quantity_bought REAL NOT NULL,
        unit_concept TEXT NOT NULL,
        store_id TEXT NOT NULL,
        purchase_date TEXT NOT NULL
      )
    ''');

    // Tabla 3: Ticket Temporal de la Sesión (Volátil por compra)
    batch.execute('''
      CREATE TABLE current_session_ticket (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_name TEXT NOT NULL,
        category TEXT NOT NULL,
        price_paid REAL NOT NULL,
        quantity_bought REAL NOT NULL,
        unit_concept TEXT NOT NULL,
        store_id TEXT NOT NULL,
        purchase_date TEXT NOT NULL
      )
    ''');

    // Tabla 4: Catálogo Local de Tiendas (Gestionado por Entorno)
    batch.execute('''
      CREATE TABLE stores_catalog (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL
      )
    ''');

    await batch.commit();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final batch = db.batch();

    if (oldVersion < 4) {
      try {
        await db.execute("ALTER TABLE pantry_items ADD COLUMN supermarket_id TEXT NOT NULL DEFAULT 'Casa';");
      } catch (_) {}
    }

    if (oldVersion < 5) {
      batch.execute('DROP TABLE IF EXISTS barcodes_catalog;');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS current_session_ticket (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_name TEXT NOT NULL,
          category TEXT NOT NULL,
          price_paid REAL NOT NULL,
          quantity_bought REAL NOT NULL,
          unit_concept TEXT NOT NULL,
          store_id TEXT NOT NULL,
          purchase_date TEXT NOT NULL
        )
      ''');
    }

    // 🚀 MIGRACIÓN EN CALIENTE VERSIÓN 6: Inyecta la columna real_price sin comprometer los datos del búnker
    if (oldVersion < 6) {
      try {
        await db.execute("ALTER TABLE pantry_items ADD COLUMN real_price REAL;");
        debugPrint('🛠️ MIGRACIÓN COMPLETADA: Columna real_price inyectada con éxito a pantry_items.');
      } catch (_) {}
    }

    await batch.commit();
  }

  Future<void> purgeOldHistory(Database db) async {
    try {
      final rowsDeleted = await db.delete(
        'purchase_history',
        where: "DATE(purchase_date) < DATE('now', '-90 days')",
      );
      if (rowsDeleted > 0) {
        debugPrint('🧹 IA Auto-Clean: Se purgaron $rowsDeleted registros obsoletos (+90 días) del búnker.');
      }
    } catch (e) {
      debugPrint('⚠️ Error en la autolimpieza cronológica de la base de datos: $e');
    }
  }

  Future<int> insertStore(Map<String, dynamic> storeMap) async {
    final db = await database;
    return await db.insert(
      'stores_catalog',
      storeMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllStores() async {
    final db = await database;
    return await db.query('stores_catalog', orderBy: 'name ASC');
  }

  Future<int> deleteStore(String id) async {
    final db = await database;
    return await db.delete(
      'stores_catalog',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> executeAbsoluteBatchCleanup() async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('current_session_ticket');
      batch.delete('pantry_items', where: 'is_checked = 1');
      batch.execute("DELETE FROM sqlite_sequence WHERE name = 'current_session_ticket';");
      await batch.commit(noResult: true);
    });
    debugPrint('🧼 Batch Cleanup: Desinfección transaccional de la sesión completada con éxito en disco duro.');
  }
}
