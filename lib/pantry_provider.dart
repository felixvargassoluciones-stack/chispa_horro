import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // 🚀 SOPORTE WEB: Indispensable para usar kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'grocery_item.dart';
import 'database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
@immutable
class PantryState {
  final List<GroceryItem> items;
  final double budgetLimit;
  final Map<String, double> productLifespans; 
  final List<Map<String, dynamic>> historicalPrices; 
  final String currentSupermarketId; 
  final List<Map<String, dynamic>> savedStores;
  final bool isEnvironmentLocked; 

  const PantryState({
    required this.items,
    this.budgetLimit = 1500.0,
    this.productLifespans = const {}, 
    this.historicalPrices = const [], 
    this.currentSupermarketId = 'Casa', 
    this.savedStores = const [],
    this.isEnvironmentLocked = false,
  });
  double get totalEstimatedExpense {
    return items.fold(0.0, (sum, item) => sum + (item.estimatedPrice * item.quantity));
  }

  String toJsonString() {
    final Map<String, dynamic> data = {
      'items': items.map((item) => item.toMap()).toList(),
      'budgetLimit': budgetLimit,
      'productLifespans': productLifespans,
      'historicalPrices': historicalPrices, 
      'currentSupermarketId': currentSupermarketId,
      'savedStores': savedStores,
      'isEnvironmentLocked': isEnvironmentLocked,
    };
    return jsonEncode(data);
  }
  factory PantryState.fromJsonString(String source) {
    final Map<String, dynamic> decoded = jsonDecode(source) as Map<String, dynamic>;
    final List<dynamic> itemsList = decoded['items'] as List<dynamic>? ?? [];
    
    return PantryState(
      items: itemsList.map((x) => GroceryItem.fromMap(x as Map<String, dynamic>)).toList(),
      budgetLimit: (decoded['budgetLimit'] ?? 1500.0) as double,
      productLifespans: Map<String, double>.from(decoded['productLifespans'] ?? const {}),
      historicalPrices: (decoded['historicalPrices'] as List<dynamic>?)
              ?.map((x) => Map<String, dynamic>.from(x as Map))
              .toList() ?? const [],
      currentSupermarketId: (decoded['currentSupermarketId'] ?? 'Casa') as String,
      savedStores: List<Map<String, dynamic>>.from(decoded['savedStores'] ?? const []),
      isEnvironmentLocked: (decoded['isEnvironmentLocked'] ?? false) as bool,
    );
  }

  PantryState copyWith({
    List<GroceryItem>? items,
    double? budgetLimit,
    Map<String, double>? productLifespans,
    List<Map<String, dynamic>>? historicalPrices, 
    String? currentSupermarketId,
    List<Map<String, dynamic>>? savedStores,
    bool? isEnvironmentLocked,
  }) {
    return PantryState(
      items: items ?? this.items,
      budgetLimit: budgetLimit ?? this.budgetLimit,
      productLifespans: productLifespans ?? this.productLifespans,
      historicalPrices: historicalPrices ?? this.historicalPrices,
      currentSupermarketId: currentSupermarketId ?? this.currentSupermarketId,
      savedStores: savedStores ?? this.savedStores,
      isEnvironmentLocked: isEnvironmentLocked ?? this.isEnvironmentLocked,
    );
  }
}
class PantryNotifier extends AsyncNotifier<PantryState> {
  
  Database? _db;

  Future<Database> _getDatabase() async {
    if (_db != null) return _db!;
    // 🚀 MEJORA DE COMPATIBILIDAD WEB: Usamos directamente el inicializador seguro de DatabaseHelper
    _db = await DatabaseHelper().database;
    return _db!;
  }

  @override
  Future<PantryState> build() async {
    try {
      debugPrint("📦 Local-First Activo: Restaurando alacena e IA predictiva desde SQLite.");
      final PantryState estadoCargado = await _fetchItemsFromLocalDatabase();
      return estadoCargado;
    } catch (e) {
      debugPrint("🚨 Error al decodificar cache relacional local. Iniciando sesion limpia: $e");
    }
    
    return PantryState(
      items: [],
      budgetLimit: 1500.0,
      productLifespans: const {},
      historicalPrices: const [], 
      currentSupermarketId: 'Casa',
      savedStores: const [],
      isEnvironmentLocked: false,
    );
  }
  Future<void> loadSavedStores() async {
    final dbHelper = DatabaseHelper();
    final stores = await dbHelper.getAllStores();
    
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(savedStores: stores));
    }
  }

  Future<void> registerNewStore(String name) async {
    final currentState = state.value;
    if (currentState == null) return;

    final String uniqueId = 'STORE_${DateTime.now().millisecondsSinceEpoch}';
    
    final newStore = {
      'id': uniqueId,
      'name': name,
    };

    final dbHelper = DatabaseHelper();
    await dbHelper.insertStore(newStore);
    
    final updatedStores = await dbHelper.getAllStores();

    state = AsyncData(currentState.copyWith(
      currentSupermarketId: uniqueId,
      savedStores: updatedStores,
    ));
  }
  Future<void> updateStoreName(String id, String newName) async {
    final currentState = state.value;
    if (currentState == null) return;

    final updatedStore = {
      'id': id,
      'name': newName,
    };

    final dbHelper = DatabaseHelper();
    await dbHelper.insertStore(updatedStore);
    final updatedStores = await dbHelper.getAllStores();

    state = AsyncData(currentState.copyWith(
      savedStores: updatedStores,
    ));
  }

  Future<void> removeStore(String id) async {
    final currentState = state.value;
    if (currentState == null) return;

    final dbHelper = DatabaseHelper();
    await dbHelper.deleteStore(id);
    final updatedStores = await dbHelper.getAllStores();

    state = AsyncData(currentState.copyWith(
      currentSupermarketId: currentState.currentSupermarketId == id ? 'Casa' : currentState.currentSupermarketId,
      savedStores: updatedStores,
    ));
  }
  String _removeAccents(String text) {
    var withAccents = 'áéíóúÁÉÍÓÚüÜíí';
    var withoutAccents = 'aeiouAEIOUuUii';
    String clean = text;
    for (int i = 0; i < withAccents.length; i++) {
      clean = clean.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return clean;
  }

    Future<PantryState> _fetchItemsFromLocalDatabase() async {
    final db = await _getDatabase();

    // 🚀 CORRECCIÓN WEB: Ejecutamos las consultas de forma secuencial con await independiente.
    // Esto evita el Deadlock y el error 'unsupported result null' en navegadores.
    final List<Map<String, dynamic>> productsResponse = await db.query('pantry_items');
    final List<Map<String, dynamic>> historyResponse = await db.query('purchase_history', orderBy: 'purchase_date DESC, id DESC');
    final List<Map<String, dynamic>> savedStoresResponse = await db.query('stores_catalog', orderBy: 'name ASC');

    final Map<String, List<DateTime>> purchaseDatesGrouped = {};
    final Map<String, Map<String, dynamic>> lastPurchaseMeta = {};
    
    for (final row in historyResponse) {
      final String productName = (row['product_name'] ?? '').toString();
      final String nameClean = _removeAccents(productName.toLowerCase().trim());
      final String category = (row['category'] ?? 'General').toString().trim();
      
      final String baseKey = 'NAME_${nameClean}_$category';

      if (row['purchase_date'] != null) {
        final DateTime? date = DateTime.tryParse(row['purchase_date'] as String);
        if (date != null) {
          purchaseDatesGrouped.putIfAbsent(baseKey, () => []).add(date);
          
          final double precioPago = (row['price_paid'] ?? 0.0) is int 
              ? (row['price_paid'] as int).toDouble() 
              : (row['price_paid'] ?? 0.0) as double;
          final double cantCompra = (row['quantity_bought'] ?? 1.0) is int 
              ? (row['quantity_bought'] as int).toDouble() 
              : (row['quantity_bought'] ?? 1.0) as double;
          final String unidadMedida = (row['unit_concept'] ?? 'pz') as String;
          final String tiendaId = (row['store_id'] ?? 'Casa') as String;

          final String uiCompositeKey = 'NAME_${nameClean}_CAT:${category}_QTY:${cantCompra}_UNT:${unidadMedida}_STR:${tiendaId}_DATE:${date.day}-${date.month}-${date.year}_PRC:${precioPago}_ID:${date.millisecondsSinceEpoch}';

          lastPurchaseMeta[uiCompositeKey] = {
            'baseKey': baseKey,
            'name': productName,
            'category': category,
            'price': precioPago,
            'unit': unidadMedida,
            'date': date,
          };
        }
      }
    }

    final Map<String, double> computedLifespans = {};
    final Map<String, Map<String, dynamic>> pivotesParaPredictivo = {};

    purchaseDatesGrouped.forEach((baseKey, dates) {
      if (dates.isEmpty) return;
      dates.sort((a, b) => a.compareTo(b));
      
      if (dates.length >= 2) {
        double totalMinutesAcumulado = 0.0;
        int intervalsCount = 0;
        
        for (int i = 0; i < dates.length - 1; i++) {
          final double differenceInMinutes = dates[i + 1].difference(dates[i]).inMinutes.abs().toDouble();
          final double minutosSeguros = differenceInMinutes > 0 ? differenceInMinutes : 1.0;
          totalMinutesAcumulado += minutosSeguros; 
          intervalsCount++;
        }
        if (intervalsCount > 0) {
          computedLifespans[baseKey] = totalMinutesAcumulado / intervalsCount;
        }
      } else {
        computedLifespans[baseKey] = -1.0; 
      }

      final List<MapEntry<String, Map<String, dynamic>>> candidatosDelProducto = lastPurchaseMeta.entries
          .where((entry) => entry.value['baseKey'] == baseKey)
          .toList();

      if (candidatosDelProducto.isNotEmpty) {
        candidatosDelProducto.sort((a, b) {
          final String keyA = a.key;
          final String keyB = b.key;
          final int idIndexA = keyA.lastIndexOf('_ID:');
          final int idIndexB = keyB.lastIndexOf('_ID:');
          
          if (idIndexA != -1 && idIndexB != -1) {
            final int idA = int.tryParse(keyA.substring(idIndexA + 4)) ?? 0;
            final int idB = int.tryParse(keyB.substring(idIndexB + 4)) ?? 0;
            return idB.compareTo(idA); 
          }
          return 0;
        });
        
        final elMasNuevo = candidatosDelProducto.first;
        pivotesParaPredictivo[elMasNuevo.key] = elMasNuevo.value;
      }
    });
    final List<GroceryItem> loadedItems = productsResponse.map((data) {
      final String catClean = (data['category'] ?? 'General').toString().trim();
      final String nameClean = _removeAccents((data['name'] as String).toLowerCase().trim());
      final String searchKey = 'NAME_${nameClean}_$catClean';

      double? historicalPrice;

      for (var entry in pivotesParaPredictivo.entries) {
        if (entry.value['baseKey'] == searchKey) {
          historicalPrice = entry.value['price'] as double?;
          break;
        }
      }

      final int isCheckedRaw = data['is_checked'] is int ? data['is_checked'] as int : int.tryParse(data['is_checked'].toString()) ?? 0;
      final bool isCheckedClean = isCheckedRaw == 1;
      final double realPriceRaw = data['real_price'] != null ? (data['real_price'] as num).toDouble() : 0.0;
      final double estimatedPriceRaw = (data['estimated_price'] ?? 0.0) is int ? (data['estimated_price'] as int).toDouble() : (data['estimated_price'] ?? 0.0) as double;

      return GroceryItem(
        id: data['id'].toString(),
        name: data['name'] as String,
        estimatedPrice: (estimatedPriceRaw == 0.0 && isCheckedClean && realPriceRaw > 0.0) ? realPriceRaw : estimatedPriceRaw,
        realPrice: realPriceRaw > 0.0 ? realPriceRaw : null,
        quantity: (data['quantity'] ?? 1.0) is int ? (data['quantity'] as int).toDouble() : (data['quantity'] ?? 1.0) as double,
        category: catClean,
        isChecked: isCheckedClean,
        aisle: data['aisle']?.toString(),
        unit: (data['unit'] ?? 'pz') as String,
        updatedAt: data['updated_at'] != null ? DateTime.tryParse(data['updated_at'] as String) : null,
        lastPricePaid: historicalPrice ?? (estimatedPriceRaw > 0.0 ? estimatedPriceRaw : null), 
        supermarketId: data['supermarket_id']?.toString() ?? 'Casa',
        fractionLabel: data['fraction_label']?.toString() ?? '1',
      );
    }).toList(growable: true);
    final List<MapEntry<String, Map<String, dynamic>>> sortedMetaEntries = pivotesParaPredictivo.entries.toList()
      ..sort((a, b) {
        final DateTime dateA = a.value['date'] as DateTime;
        final DateTime dateB = b.value['date'] as DateTime;
        return dateB.compareTo(dateA);
      });

    final Set<String> productosYaProcesadosPredictivos = {};

    for (var entry in sortedMetaEntries) {
      final meta = entry.value;
      final String metaName = meta['name'] as String;
      final String cleanNormalName = _removeAccents(metaName.toLowerCase().trim());
      
      if (productosYaProcesadosPredictivos.contains(cleanNormalName)) {
        continue;
      }
      productosYaProcesadosPredictivos.add(cleanNormalName);

      final String metaCategory = meta['category'] as String;
      final DateTime lastDate = meta['date'] as DateTime;
      final double estimatedPrice = meta['price'] as double;
      final String metaUnit = meta['unit'] as String;

      final bool alreadyExists = loadedItems.any((item) {
        return _removeAccents(item.name.toLowerCase().trim()) == cleanNormalName && !item.isAutoInjected;
      });

      if (!alreadyExists) {
        double averageMinutes = computedLifespans[meta['baseKey']] ?? -1.0;
        
        if (averageMinutes < 0.0) {
          continue;
        }

        final double minutesSinceLastPurchase = DateTime.now().difference(lastDate).inMinutes.abs().toDouble();
        final double minutesSegurosSince = minutesSinceLastPurchase > 0 ? minutesSinceLastPurchase : 1.0;

        final String pasilloActualUI = state.hasValue ? state.requireValue.currentSupermarketId : 'Todos';
        
        if ((minutesSegurosSince / averageMinutes) >= 0.8 && 
            (pasilloActualUI == 'Todos' || _removeAccents(metaCategory.toLowerCase().trim()) == _removeAccents(pasilloActualUI.toLowerCase().trim()))) {
          
          loadedItems.add(
            GroceryItem(
              id: 'predictive_${DateTime.now().millisecondsSinceEpoch}_${entry.key.hashCode.abs()}',
              name: metaName,
              estimatedPrice: estimatedPrice, 
              quantity: 1.0,
              category: metaCategory,
              isChecked: false,
              unit: metaUnit,
              isAutoInjected: true, 
              updatedAt: lastDate,
              lastPricePaid: estimatedPrice,
            ),
          );
          debugPrint('🔥 MOTOR IA: ¡Asistente Predictivo programado en Minutos para [$metaName]! Ciclo: $averageMinutes minutos.');
        }
      }
    }
    // 🚀 RESGUARDO ANTI-CRASH WEB: Si corre en Web, evitamos usar SharedPreferences tradicionales de disco
    double existingLimit = 1500.0;
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      existingLimit = prefs.getDouble('presupuesto_guardado') ?? 1500.0;
    }

    final List<Map<String, dynamic>> listaCronologicaHistorial = [];
    lastPurchaseMeta.forEach((compositeKey, value) {
      listaCronologicaHistorial.add({
        'compositeKey': compositeKey,
        'price': value['price'],
        'date': value['date'],
      });
    });

    final List<String> jacalAisleOrder = [
      'Frutas y Verduras',
      'Carnes',
      'Lácteos',
      'Abarrotes',
      'Limpieza',
      'General',
      'Manual',
    ];

    loadedItems.sort((a, b) {
      int indexA = jacalAisleOrder.indexOf(a.category);
      int indexB = jacalAisleOrder.indexOf(b.category);
      if (indexA == -1) indexA = 99;
      if (indexB == -1) indexB = 99;
      return indexA.compareTo(indexB);
    });

    return PantryState(
      items: List<GroceryItem>.from(loadedItems),
      budgetLimit: existingLimit,
      productLifespans: computedLifespans,
      historicalPrices: listaCronologicaHistorial,
      currentSupermarketId: state.hasValue ? state.requireValue.currentSupermarketId : 'Casa',
      savedStores: savedStoresResponse,
      isEnvironmentLocked: state.hasValue ? state.requireValue.isEnvironmentLocked : false,
    );
  }

  Future<void> refreshFromLocal() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchItemsFromLocalDatabase());
  }
  Future<void> addManualItem({
    required String name, 
    required double quantity, 
    required String category,
    String unit = 'pz', 
  }) async {
    final String cleanInputName = name.trim();
    if (cleanInputName.isEmpty) return;

    final currentPantryState = state.value ?? PantryState(items: [], budgetLimit: 1500.0);
    final oldItems = currentPantryState.items;

    final now = DateTime.now();
    final tempId = 'item_${now.millisecondsSinceEpoch}';

    final tempItem = GroceryItem(
      id: tempId,
      name: cleanInputName,
      estimatedPrice: 0.0, 
      quantity: quantity, 
      category: category, 
      isChecked: false, 
      unit: unit,
      updatedAt: now,
      lastPricePaid: 0.0,
      supermarketId: currentPantryState.currentSupermarketId,
    );

    final db = await _getDatabase();
    await db.insert(
      'pantry_items', 
      {
        'id': tempItem.id,
        'name': tempItem.name,
        'estimated_price': tempItem.estimatedPrice,
        'quantity': tempItem.quantity,
        'unit': tempItem.unit,
        'category': tempItem.category, 
        'is_checked': tempItem.isChecked ? 1 : 0,
        'updated_at': now.toIso8601String(),
        'last_price_paid': tempItem.lastPricePaid ?? 0.0,
        'supermarket_id': tempItem.supermarketId ?? 'Casa', 
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final updatedItems = [tempItem, ...oldItems];
    state = AsyncValue.data(currentPantryState.copyWith(items: updatedItems));
  }
  Future<void> moveToCartWithPrice({
    required String id,
    required double realPrice,
    double? updatedQuantity,
    String? updatedName,
  }) async {
    if (state.value == null) return;
    final currentPantryState = state.requireValue;
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final timestampId = 'item_${now.millisecondsSinceEpoch}';

    final oldItem = currentPantryState.items.firstWhere((item) => item.id == id);
    
    final finalName = updatedName ?? oldItem.name;
    final finalQuantity = updatedQuantity ?? oldItem.quantity;
    
    final isPredictive = oldItem.id.startsWith('predictive_');
    final finalId = isPredictive ? timestampId : oldItem.id;

    double precioBaseReferencia = 0.0;
    if (oldItem.estimatedPrice > 0.0) {
      precioBaseReferencia = oldItem.estimatedPrice;
    } else if (oldItem.lastPricePaid != null && oldItem.lastPricePaid! > 0.0) {
      precioBaseReferencia = oldItem.lastPricePaid!;
    } else {
      final String cleanSearchName = _removeAccents(finalName.toLowerCase().trim());
      for (final reg in currentPantryState.historicalPrices) {
        final String composite = reg['compositeKey']?.toString() ?? '';
        if (composite.contains('NAME_${cleanSearchName}_')) {
          precioBaseReferencia = (reg['price'] as num?)?.toDouble() ?? 0.0;
          break; 
        }
      }
    }

    final updatedItem = GroceryItem(
      id: finalId,
      name: finalName,
      estimatedPrice: isPredictive 
          ? (oldItem.estimatedPrice > 0.0 ? oldItem.estimatedPrice : realPrice)
          : (precioBaseReferencia > 0.0 
              ? precioBaseReferencia 
              : (oldItem.estimatedPrice > 0.0 ? oldItem.estimatedPrice : realPrice)),
      realPrice: realPrice,
      quantity: finalQuantity,
      category: oldItem.category,
      isChecked: true,
      aisle: oldItem.aisle,
      unit: oldItem.unit,
      updatedAt: now,
      lastPricePaid: precioBaseReferencia > 0.0 ? precioBaseReferencia : realPrice,
      supermarketId: oldItem.supermarketId,
      isAutoInjected: oldItem.isAutoInjected,
      fractionLabel: oldItem.fractionLabel,
    );

    final db = await _getDatabase();
    if (isPredictive) {
      await db.insert(
        'pantry_items',
        {
          'id': updatedItem.id,
          'name': updatedItem.name,
          'estimated_price': updatedItem.estimatedPrice,
          'real_price': updatedItem.realPrice,
          'quantity': updatedItem.quantity,
          'unit': updatedItem.unit,
          'category': updatedItem.category,
          'is_checked': 1,
          'updated_at': nowStr,
          'last_price_paid': updatedItem.lastPricePaid,
          'supermarket_id': updatedItem.supermarketId ?? 'Casa',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.update(
        'pantry_items',
        {
          'name': finalName,
          'estimated_price': updatedItem.estimatedPrice, 
          'real_price': realPrice, 
          'quantity': finalQuantity,
          'is_checked': 1,
          'updated_at': nowStr,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    final updatedItems = currentPantryState.items.map((item) {
      return item.id == id ? updatedItem : item.copyWith();
    }).toList();

    state = AsyncValue.data(currentPantryState.copyWith(items: updatedItems));
  }
  Future<void> toggleItemCheck(String id, bool isChecked) async {
    if (state.value == null) return;
    final currentPantryState = state.requireValue;
    final nowStr = DateTime.now().toIso8601String();

    final oldItem = currentPantryState.items.firstWhere((item) => item.id == id);

    final double finalEstimatedPrice = isChecked ? oldItem.estimatedPrice : 0.0;
    final double? finalRealPrice = isChecked ? oldItem.realPrice : null;
    final double? finalLastPricePaid = isChecked ? oldItem.lastPricePaid : 0.0;

    final updatedItem = GroceryItem(
      id: oldItem.id,
      name: oldItem.name,
      estimatedPrice: finalEstimatedPrice,
      realPrice: finalRealPrice,
      quantity: oldItem.quantity,
      category: oldItem.category,
      isChecked: isChecked,
      aisle: oldItem.aisle,
      unit: oldItem.unit,
      updatedAt: DateTime.now(),
      lastPricePaid: finalLastPricePaid,
      supermarketId: oldItem.supermarketId,
      isAutoInjected: oldItem.isAutoInjected,
      fractionLabel: oldItem.fractionLabel,
    );

    final db = await _getDatabase();
    await db.update(
      'pantry_items',
      {
        'is_checked': isChecked ? 1 : 0,
        'estimated_price': finalEstimatedPrice,
        'real_price': finalRealPrice ?? 0.0,
        'last_price_paid': finalLastPricePaid ?? 0.0,
        'updated_at': nowStr,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final updatedItems = currentPantryState.items.map((item) {
      return item.id == id ? updatedItem : item.copyWith();
    }).toList();

    state = AsyncValue.data(currentPantryState.copyWith(items: updatedItems));
  }

  Future<void> updateItem({
    required String id, 
    required String newName, 
    required double newPrice, 
    required double newQuantity, 
    String? unit, 
    String? category,
  }) async {
    if (state.value == null) return;
    final currentPantryState = state.requireValue;
    final now = DateTime.now();

    final db = await _getDatabase();
    await db.update(
      'pantry_items',
      {
        'name': newName,
        'estimated_price': newPrice,
        'quantity': newQuantity,
        'unit': unit ?? currentPantryState.items.firstWhere((i) => i.id == id).unit,
        'category': category ?? currentPantryState.items.firstWhere((i) => i.id == id).category,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final updatedItems = currentPantryState.items.map((item) {
      if (item.id == id) {
        return GroceryItem(
          id: item.id,
          name: newName,
          estimatedPrice: newPrice,
          realPrice: item.realPrice,
          quantity: newQuantity,
          category: category ?? item.category,
          isChecked: item.isChecked,
          aisle: item.aisle,
          unit: unit ?? item.unit,
          updatedAt: now,
          lastPricePaid: item.lastPricePaid,
          supermarketId: item.supermarketId,
          isAutoInjected: item.isAutoInjected,
          fractionLabel: item.fractionLabel,
        );
      }
      return item.copyWith();
    }).toList();

    state = AsyncValue.data(currentPantryState.copyWith(items: updatedItems));
  }

  Future<void> deleteItem(String id) async {
    final oldState = state.value;
    if (oldState == null) return;

    final db = await _getDatabase();
    await db.delete('pantry_items', where: 'id = ?', whereArgs: [id]);

    final remainingItems = oldState.items.where((item) => item.id != id).toList();
    state = AsyncValue.data(oldState.copyWith(items: remainingItems));
  }
  void setSupermarketManualmente(String storeName) {
    if (!state.hasValue) return;
    final currentState = state.requireValue;
    const bool shouldLock = false;

    state = AsyncValue.data(currentState.copyWith(
      currentSupermarketId: storeName,
      isEnvironmentLocked: shouldLock, 
    ));
  }

  void updateBudgetLimit(double newLimit) async {
    if (state.hasValue) {
      state = AsyncValue.data(state.requireValue.copyWith(budgetLimit: newLimit));
      if (!kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('presupuesto_guardado', newLimit);
      }
    }
  }

  double getProductDepletionLevel(GroceryItem item) {
    if (item.isAutoInjected) return 1.0;
    if (item.updatedAt == null || !state.hasValue) return 0.0;

    final String name = item.name.toLowerCase().trim();
    final String category = item.category.trim();
    final String key = 'NAME_${_removeAccents(name)}_$category';

    final double averageMinutes = state.requireValue.productLifespans[key] ?? 60.0;
    final double minutesSinceLastPurchase = DateTime.now().difference(item.updatedAt!).inMinutes.abs().toDouble();
    final double minutesSegurosSince = minutesSinceLastPurchase > 0 ? minutesSinceLastPurchase : 0.1;

    if (averageMinutes <= 0) return 1.0;
    return (minutesSegurosSince / averageMinutes).clamp(0.0, 1.0);
  }
  Future<void> procesarBunkerYVaciarCarrito(List<GroceryItem> purchasedItems) async {
    if (state.value == null || purchasedItems.isEmpty) return;
    final currentPantryState = state.requireValue;

    final remainingItems = currentPantryState.items.where((item) => !item.isChecked).toList();
    final List<Map<String, dynamic>> updatedHistoryList = List.from(currentPantryState.historicalPrices);
    final Map<String, double> updatedLifespans = Map.from(currentPantryState.productLifespans);
    
    final DateTime momentoCompra = DateTime.now();
    final String fechaFormatoInmutable = momentoCompra.toIso8601String();
    final String fechaSelloLlave = "${momentoCompra.day}-${momentoCompra.month}-${momentoCompra.year}";
    int microSegundoRAM = momentoCompra.millisecondsSinceEpoch;

    for (final item in purchasedItems) {
      microSegundoRAM++;
      final String cleanName = _removeAccents(item.name.toLowerCase().trim());
      final String tiendaActual = item.supermarketId ?? 'Casa';
      final double precioFinalCobrado = item.realPrice ?? item.estimatedPrice;
      
      final String itemKey = 'NAME_${cleanName}_CAT:${item.category}_QTY:${item.quantity}_UNT:${item.unit}_STR:${tiendaActual}_DATE:${fechaSelloLlave}_PRC:${precioFinalCobrado}_ID:$microSegundoRAM';
      
      updatedHistoryList.insert(0, {
        'compositeKey': itemKey,
        'price': precioFinalCobrado,
        'date': momentoCompra,
      });

      final String baseKey = 'NAME_${cleanName}_${item.category.trim()}';
      updatedLifespans[baseKey] = precioFinalCobrado;
    }

    final db = await _getDatabase();
    await db.transaction((txn) async {
      int idIncrementalSeguro = DateTime.now().millisecondsSinceEpoch;
      
      for (final item in purchasedItems) {
        idIncrementalSeguro++;
        final double precioPersistidoGondola = item.realPrice ?? item.estimatedPrice;

        final Map<String, dynamic> filaHistorial = {
          'id': idIncrementalSeguro,
          'product_name': item.name,
          'category': item.category,
          'price_paid': precioPersistidoGondola,
          'quantity_bought': item.quantity,
          'unit_concept': item.unit,
          'store_id': item.supermarketId ?? 'Casa',
          'purchase_date': fechaFormatoInmutable,
        };

        await txn.insert('purchase_history', filaHistorial, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await txn.delete('pantry_items', where: 'is_checked = 1');
    });

    state = AsyncValue.data(currentPantryState.copyWith(
      items: remainingItems,
      historicalPrices: updatedHistoryList,
      productLifespans: updatedLifespans, 
      isEnvironmentLocked: false,
      currentSupermarketId: 'Casa',
    ));
  }
  Future<void> eliminarRegistroHistorialPorLlave(String compositeKey) async {
    if (!state.hasValue) return;
    final currentPantryState = state.requireValue;

    final matchRef = currentPantryState.historicalPrices.firstWhere(
      (element) => element['compositeKey'] == compositeKey,
      orElse: () => <String, dynamic>{},
    );

    if (matchRef.isEmpty) return;
    
    final DateTime fechaRef = matchRef['date'] as DateTime;
    final double precioRef = matchRef['price'] as double;
    
    String storeId = 'Casa';
    String nombreEnLlave = '';
    
    final int inicioName = compositeKey.indexOf('NAME_');
    final int finName = compositeKey.indexOf('_CAT:');
    if (inicioName != -1 && finName != -1) {
      nombreEnLlave = compositeKey.substring(inicioName + 5, finName);
    }

    final List<String> partes = compositeKey.split('_');
    for (final String parte in partes) {
      if (parte.startsWith('STR:')) {
        storeId = parte.replaceAll('STR:', '');
        if (storeId == 'STORE' && partes.length > partes.indexOf(parte) + 1) {
          storeId = 'STORE_${partes[partes.indexOf(parte) + 1]}';
        }
      }
    }

    final db = await _getDatabase();
    final List<Map<String, dynamic>> filasCandidatas = await db.query(
      'purchase_history',
      where: 'purchase_date = ? AND store_id = ?',
      whereArgs: [fechaRef.toIso8601String(), storeId],
    );

    int? idParaEliminar;
    for (final fila in filasCandidatas) {
      final String nameDbLimpio = _removeAccents((fila['product_name'] ?? '').toString().toLowerCase().trim());
      final double precioDb = (fila['price_paid'] ?? 0.0) is int 
          ? (fila['price_paid'] as int).toDouble() 
          : (fila['price_paid'] ?? 0.0) as double;

      if (nameDbLimpio == nombreEnLlave && precioDb == precioRef) {
        idParaEliminar = fila['id'] as int;
        break;
      }
    }

    if (idParaEliminar != null) {
      await db.delete(
        'purchase_history',
        where: 'id = ?',
        whereArgs: [idParaEliminar],
      );
    }

    final updatedHistoryList = currentPantryState.historicalPrices
        .where((element) => element['compositeKey'] != compositeKey)
        .toList();

    state = AsyncValue.data(currentPantryState.copyWith(
      historicalPrices: updatedHistoryList,
    ));
  }

  Future<void> simularAntiguedadRegistroPorLlave({
    required String compositeKey,
    required int diasAntiguedad,
  }) async {
    if (!state.hasValue) return;
    final currentPantryState = state.requireValue;

    final matchRef = currentPantryState.historicalPrices.firstWhere(
      (element) => element['compositeKey'] == compositeKey,
      orElse: () => <String, dynamic>{},
    );

    if (matchRef.isEmpty) return;
    
    final DateTime fechaRef = matchRef['date'] as DateTime;
    final double precioRef = matchRef['price'] as double;
    
    String storeId = 'Casa';
    String nombreEnLlave = '';
    
    final int inicioName = compositeKey.indexOf('NAME_');
    final int finName = compositeKey.indexOf('_CAT:');
    if (inicioName != -1 && finName != -1) {
      nombreEnLlave = compositeKey.substring(inicioName + 5, finName);
    }

    final List<String> partes = compositeKey.split('_');
    for (final String parte in partes) {
      if (parte.startsWith('STR:')) {
        storeId = parte.replaceAll('STR:', '');
        if (storeId == 'STORE' && partes.length > partes.indexOf(parte) + 1) {
          storeId = 'STORE_${partes[partes.indexOf(parte) + 1]}';
        }
      }
    }

    final db = await _getDatabase();
    final List<Map<String, dynamic>> filasCandidatas = await db.query(
      'purchase_history',
      where: 'purchase_date = ? AND store_id = ?',
      whereArgs: [fechaRef.toIso8601String(), storeId],
    );

    int? idParaModificar;
    for (final fila in filasCandidatas) {
      final String nameDbLimpio = _removeAccents((fila['product_name'] ?? '').toString().toLowerCase().trim());
      final double precioDb = (fila['price_paid'] ?? 0.0) is int 
          ? (fila['price_paid'] as int).toDouble() 
          : (fila['price_paid'] ?? 0.0) as double;

      if (nameDbLimpio == nombreEnLlave && precioDb == precioRef) {
        idParaModificar = fila['id'] as int;
        break;
      }
    }

    if (idParaModificar != null) {
      final DateTime nuevaFechaSimulada = DateTime.now().subtract(Duration(days: diasAntiguedad));
      
      await db.update(
        'purchase_history',
        {
          'purchase_date': nuevaFechaSimulada.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [idParaModificar],
      );
    }

    await refreshFromLocal();
  }

  void limpiarHistorialCompleto() async {
    if (!state.hasValue) return;
    state = AsyncValue.data(state.requireValue.copyWith(historicalPrices: const []));
    final db = await _getDatabase();
    await db.delete('purchase_history');
  }
  Future<void> exportarAuditoriaPDF(BuildContext context, List<GroceryItem> purchasedItems) async {
    try {
      if (purchasedItems.isEmpty) return;

      final List<List<String>> datosTabla = [];
      double costoTotalRealReal = 0.0;
      double costoTotalEsperadoBase = 0.0;
      double totalAhorradoAcumulado = 0.0;
      double totalInflacionAcumulado = 0.0;

      for (final item in purchasedItems) {
        String tienda = item.supermarketId ?? 'Casa';
        if (state.value != null && tienda != 'Casa') {
          final tiendaMatch = state.value!.savedStores.firstWhere(
            (t) => t['id'].toString() == tienda,
            orElse: () => <String, dynamic>{},
          );
          if (tiendaMatch.isNotEmpty && tiendaMatch['name'] != null) {
            tienda = tiendaMatch['name'].toString();
          }
        }

        final DateTime now = DateTime.now();
        final String fechaLimpia = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
        
        final double precioPagadoGondola = item.realPrice ?? item.estimatedPrice;
        final double subtotalReal = precioPagadoGondola * item.quantity;
        costoTotalRealReal += subtotalReal;

        final double precioBaseAnterior = (item.lastPricePaid != null && item.lastPricePaid! > 0.0)
            ? item.lastPricePaid!
            : (item.estimatedPrice > 0.0 ? item.estimatedPrice : precioPagadoGondola);
            
        final double subtotalEsperado = precioBaseAnterior * item.quantity;
        costoTotalEsperadoBase += subtotalEsperado;

        String balanceFilaTexto = "\$0.00";
        if (precioBaseAnterior > 0.0 && precioPagadoGondola != precioBaseAnterior) {
          final double diferenciaUnitaria = precioPagadoGondola - precioBaseAnterior;
          final double diferenciaTotal = diferenciaUnitaria * item.quantity;

          if (diferenciaUnitaria < 0.0) {
            balanceFilaTexto = "-\$${diferenciaTotal.abs().toStringAsFixed(2)}";
            totalAhorradoAcumulado += diferenciaTotal.abs();
          } else if (diferenciaUnitaria > 0.0) {
            balanceFilaTexto = "+\$${diferenciaTotal.toStringAsFixed(2)}";
            totalInflacionAcumulado += diferenciaTotal;
          }
        }

        String cantStr = item.quantity.toString();
        if (cantStr.endsWith('.0')) cantStr = cantStr.substring(0, cantStr.length - 2);

        datosTabla.add([
          fechaLimpia,
          item.name,
          "$cantStr ${item.unit}",
          tienda,
          "\$${precioPagadoGondola.toStringAsFixed(2)}",
          precioBaseAnterior > 0.0 
              ? "\$${precioBaseAnterior.toStringAsFixed(2)}" 
              : "Nuevo",
          balanceFilaTexto,
          "\$${subtotalReal.toStringAsFixed(2)}",
        ]);
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context contextPdf) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CHISPAHORRO INTELIGENTE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('AUDITORÍA DE COMPRA', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Paragraph(
                text: 'Resumen institucional comparativo del ticket actual contra el búnker analítico de precios históricos de la IA.',
              ),
              pw.SizedBox(height: 12),
              
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Producto', 'Cant.', 'Tienda', 'Precio U.', 'Ref. IA', 'Balance', 'Subtotal'],
                data: datosTabla,
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  4: pw.Alignment.centerRight, 
                  5: pw.Alignment.centerRight, 
                  6: pw.Alignment.center, 
                  7: pw.Alignment.centerRight
                },
              ),
              pw.SizedBox(height: 16),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (totalAhorradoAcumulado > 0)
                        pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 6),
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.green100,
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: PdfColors.green400, width: 1),
                          ),
                          child: pw.Text(
                            '¡Dinero Rescatado en esta Compra!: \$${totalAhorradoAcumulado.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.green900),
                          ),
                        ),
                      if (totalInflacionAcumulado > 0)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.red100,
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: PdfColors.red400, width: 1),
                          ),
                          child: pw.Text(
                            'Sobrecosto por Inflación en Tienda: +\$${totalInflacionAcumulado.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red900),
                          ),
                        ),
                    ],
                  ),

                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Total Esperado (IA): ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          pw.Text('\$${costoTotalEsperadoBase.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('TOTAL PAGADO EN CAJA: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                          pw.Text(
                            '\$${costoTotalRealReal.toStringAsFixed(2)}', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.green900),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      if (!kIsWeb) {
        final Directory tempDir = await getTemporaryDirectory();
        final String pathCompleto = "${tempDir.path}/Ticket_Chispahorro.pdf";
        final File archivoPdf = File(pathCompleto);
        
        await archivoPdf.writeAsBytes(await pdf.save(), flush: true);

        if (await archivoPdf.exists()) {
          final shareResult = await SharePlus.instance.share(
            ShareParams(
              text: 'Resguardo Oficial de Compra - CHISPAHORRO INTELIGENTE',
              files: [XFile(pathCompleto)],
            ),
          );

          if (shareResult.status != ShareResultStatus.dismissed) {
            await procesarBunkerYVaciarCarrito(purchasedItems);
          }
        }
      } else {
        await procesarBunkerYVaciarCarrito(purchasedItems);
      }
    } catch (e) {
      debugPrint('🚨 Error al procesar el reporte: $e');
    }
  }

  Future<void> enviarMetricasAnaliticasSheets(List<GroceryItem> purchasedItems) async {
    try {
      final Uri urlAnalitica = Uri.parse('https://google.com');

      final bodyData = jsonEncode({
        'device_hash': 'Device_Local_Anónimo',
        'items': purchasedItems.map((item) {
          String nombreTiendaMapeado = 'Casa';
          final String currentStoreId = item.supermarketId ?? 'Casa';
          
          if (currentStoreId != 'Casa' && state.value != null) {
            final tiendaMatch = state.value!.savedStores.firstWhere(
              (t) => t['id'].toString() == currentStoreId,
              orElse: () => <String, dynamic>{},
            );
            if (tiendaMatch.isNotEmpty && tiendaMatch['name'] != null) {
              nombreTiendaMapeado = tiendaMatch['name'].toString();
            } else {
              nombreTiendaMapeado = currentStoreId; 
            }
          }

          return {
            'tienda_id': nombreTiendaMapeado, 
            'categoria': item.category,
            'producto': _removeAccents(item.name.toLowerCase().trim()),
            'precio_base': item.estimatedPrice,
            'precio_real': item.realPrice ?? item.estimatedPrice,
            'cantidad': item.quantity,
            'fecha': DateTime.now().toIso8601String(),
          };
        }).toList(),
      });

      unawaited(
        http.post(
          urlAnalitica,
          headers: {'Content-Type': 'application/json'},
          body: bodyData,
        ).then((response) {
          debugPrint('📊 Sheets Analítica: Datos enviados con éxito.');
        }).catchError((error) {
          debugPrint('⚠️ Error silencioso al enviar analítica a Sheets: $error');
        })
      );
    } catch (e) {
      debugPrint('⚠️ Error general en método analítico: $e');
    }
  }

  Future<void> enviarOfertaAlChatSheets(String nombreTienda, String bloqueTextoOfertas) async {
    try {
      final Uri urlChat = Uri.parse('https://google.com');

      final bodyData = jsonEncode({
        'tienda': nombreTienda,
        'ofertas': bloqueTextoOfertas,
        'fecha': '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      });

      unawaited(
        http.post(
          urlChat,
          headers: {'Content-Type': 'application/json'},
          body: bodyData,
        ).then((response) {
          debugPrint('💬 Sheets Chat: Oferta comunitaria publicada con éxito.');
        }).catchError((error) {
          debugPrint('⚠️ Error silencioso al enviar al chat: $error');
        })
      );
    } catch (e) {
      debugPrint('⚠️ Error general en método chat: $e');
    }
  }
}

final pantryProvider = AsyncNotifierProvider<PantryNotifier, PantryState>(
  PantryNotifier.new,
);
