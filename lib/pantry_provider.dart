import 'dart:convert';
import 'dart:async';
import 'dart:io';
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
  final String currentSupermarketId; // 🛰️ Súper actual geolocalizado o seleccionado
  final List<Map<String, dynamic>> savedStores;
  final bool isEnvironmentLocked; // 🚀 REQUERIMIENTO: Bloquea el entorno tras elegir tienda

   // 🚀 CORREGIDO: Se añade la palabra clave const obligatoria para clases inmutables
  const PantryState({
    required this.items,
    this.budgetLimit = 1500.0,
    this.productLifespans = const {}, 
    this.historicalPrices = const [], 
    this.currentSupermarketId = 'Casa', 
    this.savedStores = const [],
    this.isEnvironmentLocked = false,
  });


  /// Retorna la acumulación financiera real multiplicando precio por cantidad
  double get totalEstimatedExpense {
    return items.fold(0.0, (sum, item) => sum + (item.estimatedPrice * item.quantity));
  }
  /// Serializa el estado a un String plano para guardarlo en caché local si es necesario
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

  /// Restaura instantáneamente el estado consumiendo el formato JSON plano
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

  /// Método de clonación atómica indispensable para mutaciones de grano fino
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
/// Controlador de Estado Nativo adaptado para Riverpod con soporte Local-First puro
class PantryNotifier extends AsyncNotifier<PantryState> {
  
  // 🛰️ POOL DE CONEXIÓN EN CALIENTE UNIFICADO ANTI-DEADLOCK
  Database? _db;

  Future<Database> _getDatabase() async {
    if (_db != null) return _db!;
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
      debugPrint("🚨 Error al decodificar caché relacional local. Iniciando sesión limpia: $e");
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

  /// Carga el catálogo de supermercados registrados desde SQLite
  Future<void> loadSavedStores() async {
    final dbHelper = DatabaseHelper();
    final stores = await dbHelper.getAllStores();
    
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(savedStores: stores));
    }
  }
  // =========================================================================
  //  LÓGICA DE CONTROL DE TIENDAS MANUAL ASISTIDA POR HÁBITOS
  // =========================================================================

  /// Registra una nueva sucursal en SQLite de forma manual y la auto-selecciona
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
    
    // Refrescamos el catálogo en la memoria del teléfono
    final updatedStores = await dbHelper.getAllStores();

    state = AsyncData(currentState.copyWith(
      currentSupermarketId: uniqueId,
      savedStores: updatedStores,
    ));
  }

  /// Permite al usuario enmendar errores de dedo en los nombres de las tiendas
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

  /// Elimina un punto de referencia comercial de la base de datos
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

  // =========================================================================

  /// Elimina acentos y tildes de una cadena de texto de forma segura
  String _removeAccents(String text) {
    var withAccents = 'áéíóúÁÉÍÓÚüÜíí';
    var withoutAccents = 'aeiouAEIOUuUii';
    String clean = text;
    for (int i = 0; i < withAccents.length; i++) {
      clean = clean.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return clean;
  }
   /// Consulta simultáneamente la alacena activa y el historial en SQLite para calcular el desgaste real.
  Future<PantryState> _fetchItemsFromLocalDatabase() async {
    final db = await _getDatabase();

    // 1. CONSULTA EN PARALELO SEÑOR: Descarga las tres tablas al mismo tiempo ahorrando ciclos de hardware
     final List<dynamic> results = await Future.wait([
      db.query('pantry_items'),
      db.query('purchase_history', orderBy: 'purchase_date DESC, id DESC'), // 🚀 NUEVO: Prioridad cronológica estricta
      db.query('stores_catalog', orderBy: 'name ASC'), 
    ]);

    final List<Map<String, dynamic>> productsResponse = List<Map<String, dynamic>>.from(results[0]);
    final List<Map<String, dynamic>> historyResponse = List<Map<String, dynamic>>.from(results[1]);
    final List<Map<String, dynamic>> savedStoresResponse = List<Map<String, dynamic>>.from(results[2]);

       // 2. MOTOR PREDICTIVO: Agrupación cronológica lineal por nombre sanitizado de producto
    final Map<String, List<DateTime>> purchaseDatesGrouped = {};
    final Map<String, Map<String, dynamic>> lastPurchaseMeta = {};
    
    for (final row in historyResponse) {
      final String productName = (row['product_name'] ?? '').toString();
      final String nameClean = _removeAccents(productName.toLowerCase().trim());
      final String category = (row['category'] ?? 'General').toString().trim();
      
      // 🚀 CLAVE UNIFICADA: Sincronizada milimétricamente con el semáforo de la UI (PantryScreen)
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

       // 3. CÁLCULO MATEMÁTICO DE INTERVALOS SECUENCIALES (Escala de tiempo: DÍAS INSTITUCIONALES)
    final Map<String, double> computedLifespans = {};
    final Map<String, Map<String, dynamic>> pivotesParaPredictivo = {};

    purchaseDatesGrouped.forEach((baseKey, dates) {
      if (dates.isEmpty) return;
      
      // 🚀 ALINEACIÓN CRONOLÓGICA: Ordenamos de la más antigua a la más nueva
      dates.sort((a, b) => a.compareTo(b));
      
           // A) VALIDACIÓN CRÍTICA: Calculamos el intervalo real de consumo medido en MINUTOS puros consecutivos
      if (dates.length >= 2) {
        double totalMinutesAcumulado = 0.0;
        int intervalsCount = 0;
        
        for (int i = 0; i < dates.length - 1; i++) {
          // Extrae de forma limpia la diferencia absoluta en minutos nativos entre las dos compras
          final double differenceInMinutes = dates[i + 1].difference(dates[i]).inMinutes.abs().toDouble();
          
          // Escudo de control: Si es 0 (compras en la misma ráfaga), se fuerza a 1.0 minuto para evitar caídas
          final double minutosSeguros = differenceInMinutes > 0 ? differenceInMinutes : 1.0;
          
          totalMinutesAcumulado += minutosSeguros; 
          intervalsCount++;
        }
        if (intervalsCount > 0) {
          // Almacena el hábito promedio medido en minutos individuales independientes para este artículo
          computedLifespans[baseKey] = totalMinutesAcumulado / intervalsCount;
        }
      } else {
        // 🛡️ REGLA INDIVIDUAL: Si solo se ha comprado una vez, se marca con -1 para apagar el predictivo fantasma
        computedLifespans[baseKey] = -1.0; 
      }


      // B) PIVOTEO CRONOLÓGICO POR INFRAESTRUCTURA DE CLAVE COMPUESTA LONG
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
            return idB.compareTo(idA); // El ID de milisegundos más alto va primero
          }
          return 0;
        });
        
        final elMasNuevo = candidatosDelProducto.first;
        pivotesParaPredictivo[elMasNuevo.key] = elMasNuevo.value;
      }
    });

    // 4. MAPEO DE PRODUCTOS ACTIVOS CON ASIGNACIÓN HISTÓRICA INMEDIATA (Sincronizado)
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

    // 5. INYECCIÓN INTELIGENTE ELÁSTICA SOBRE LA RAM (Frecuencia Dinámica en Días Reales)
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

      // Solo consideramos que existe si es un artículo físico real en la lista, libre de clones predictivos
      final bool alreadyExists = loadedItems.any((item) {
        return _removeAccents(item.name.toLowerCase().trim()) == cleanNormalName && !item.isAutoInjected;
      });

      if (!alreadyExists) {
        double averageDays = computedLifespans[meta['baseKey']] ?? -1.0;
        
        // 🚀 COMPUERTA DE EXCLUSIÓN COMPLETA: Si el producto no tiene al menos 2 registros (es -1), no se sugiere NUNCA
        if (averageDays < 0.0) {
          continue;
        }

               // Calculamos los minutos reales transcurridos desde esa última compra absoluta hasta hoy
        final double minutesSinceLastPurchase = DateTime.now().difference(lastDate).inMinutes.abs().toDouble();
        final double minutosSegurosSince = minutesSinceLastPurchase > 0 ? minutesSinceLastPurchase : 1.0;

        final String pasilloActualUI = state.hasValue ? state.requireValue.currentSupermarketId : 'Todos';
        
        // 🚀 REGLA DE ORO INSTITUCIONAL (80% del ciclo de vida útil del producto en MINUTOS PUROS)
        if ((minutosSegurosSince / averageDays) >= 0.8 && 
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
          debugPrint('🔥 MOTOR IA: ¡Asistente Predictivo programado en Minutos para [$metaName]! Ciclo: $averageDays minutos.');
        }

      }
    }







    
    final prefs = await SharedPreferences.getInstance();
    final double existingLimit = prefs.getDouble('presupuesto_guardado') ?? 1500.0;

    // Alineación inmutable de la lista cronológica del historial incremental
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


  /// Fuerza un refresco reactivo volviendo a consultar la base de datos local
  Future<void> refreshFromLocal() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchItemsFromLocalDatabase());
  }
  // =========================================================================
  // CREACIÓN DE LISTA: EN CASA O POR PASILLO (REQUERIMIENTO: SÓLO ÍTEM Y QTY)
  // =========================================================================

  /// Agrega un producto de forma manual con precio forzado a $0.00.
  /// Cumple la regla: "Para hacer la lista... un modal que solo pida el artículo y cantidad".
  Future<void> addManualItem({
    required String name, 
    required double quantity, 
    required String category,
    String unit = 'pz', 
  }) async {
    // 1. SANITIZACIÓN ABSOLUTA DE ENTRADA
    final String cleanInputName = name.trim();
    if (cleanInputName.isEmpty) return;

    final currentPantryState = state.value ?? PantryState(items: [], budgetLimit: 1500.0);
    final oldItems = currentPantryState.items;

    final now = DateTime.now();
    final tempId = 'item_${now.millisecondsSinceEpoch}';

    // 2. CONSTRUCCIÓN CON PRECIO INICIAL DE $0.00 (Flujo de alta sin tienda)
    final tempItem = GroceryItem(
      id: tempId,
      name: cleanInputName,
      estimatedPrice: 0.0, // 🚀 REQUERIMIENTO: El precio es estrictamente cero al armar la lista
      quantity: quantity, 
      category: category, 
      isChecked: false, // Inicia como pendiente en la alacena
      unit: unit,
      updatedAt: now,
      lastPricePaid: 0.0,
      supermarketId: currentPantryState.currentSupermarketId,
    );

    // 3. PERSISTENCIA DIRECTA EN DISCO v5 (Sin barcodes)
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

    // Actualización reactiva optimista de la memoria RAM
    final updatedItems = [tempItem, ...oldItems];
    state = AsyncValue.data(currentPantryState.copyWith(items: updatedItems));
  }
  // =========================================================================
  // EN LA TIENDA: VALIDACIÓN MONETARIA Y ENVÍO AL CARRITO
  // =========================================================================

  /// Captura el precio real de la etiqueta en tienda, marca el artículo 
  /// y lo manda directamente al carrito de compras.
   /// Captura el precio real de la etiqueta en tienda, marca el artículo 
  /// y lo manda directamente al carrito de compras con persistencia v6.
    /// Captura el precio real de la etiqueta en tienda, marca el artículo 
  /// y lo manda directamente al carrito de compras con persistencia v6.
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

    // 1. Buscamos el artículo original en la RAM de forma aislada
    final oldItem = currentPantryState.items.firstWhere((item) => item.id == id);
    
    final finalName = updatedName ?? oldItem.name;
    final finalQuantity = updatedQuantity ?? oldItem.quantity;
    
    // 2. Detectar si es un ítem predictivo (fantasma) o un registro real de base de datos
    final isPredictive = oldItem.id.startsWith('predictive_');
    
    // 3. Determinar el ID definitivo que vivirá en SQLite y en la RAM
    final finalId = isPredictive ? timestampId : oldItem.id;

    // 🚀 SENIOR FIX v6: Si es lista manual ($0.00), buscamos su última referencia real en el búnker de la RAM
    double precioBaseReferencia = 0.0;
    if (oldItem.estimatedPrice > 0.0) {
      precioBaseReferencia = oldItem.estimatedPrice;
    } else if (oldItem.lastPricePaid != null && oldItem.lastPricePaid! > 0.0) {
      precioBaseReferencia = oldItem.lastPricePaid!;
    } else {
           // 🚀 ASIGNACIÓN SECUENCIAL SENIOR: Al estar el historial ya pre-purgado y ordenado descendentemente,
      // la primera coincidencia que hallemos en RAM será matemáticamente tu última transacción real
      final String cleanSearchName = _removeAccents(finalName.toLowerCase().trim());
      for (final reg in currentPantryState.historicalPrices) {
        final String composite = reg['compositeKey']?.toString() ?? '';
        if (composite.contains('NAME_${cleanSearchName}_')) {
          precioBaseReferencia = (reg['price'] as num?)?.toDouble() ?? 0.0;
          break; // 🔥 DETENCIÓN INMEDIATA: Forzamos a que el precio de hace 3 minutos gane el pivote del carrito
        }
      }

    }

    // 4. Clonación profunda e independiente aislando punteros
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

    // 5. Persistencia directa en base de datos mitigando fallas por ítem fantasma
    final db = await _getDatabase();
    if (isPredictive) {
      // Al ser predictivo se materializa físicamente usando un INSERT
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
      debugPrint('💾 SQLite: Ítem predictivo materializado en disco con ID: $finalId');
        } else {
      // Si ya existía, se ejecuta el UPDATE correspondiente sobre su registro físico
      await db.update(
        'pantry_items',
        {
          'name': finalName,
          'estimated_price': updatedItem.estimatedPrice, // 🚀 NUEVO: Sincroniza el precio base pivote
          'real_price': realPrice, // Sincroniza el nuevo precio ingresado ($40)
          'quantity': finalQuantity,
          'is_checked': 1,
          'updated_at': nowStr,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('🛠️ SQLite: Ítem estándar unificado en disco. Base: \$${updatedItem.estimatedPrice} | Real: \$$realPrice');
    }


    // 6. Sincronización reactiva del estado inmutable de Riverpod
    final updatedItems = currentPantryState.items.map((item) {
      return item.id == id ? updatedItem : item.copyWith();
    }).toList();

    state = AsyncValue.data(currentPantryState.copyWith(items: updatedItems));
  }


    /// Cambia el estado de verificación de un artículo.
  /// Si el artículo es regresado del carrito a la lista, se limpian los residuos monetarios
  /// para permitir recálculos infinitos de ahorro verde en las góndolas.
  Future<void> toggleItemCheck(String id, bool isChecked) async {
    if (state.value == null) return;
    final currentPantryState = state.requireValue;
    final nowStr = DateTime.now().toIso8601String();

    // 1. Localizar el artículo actual en RAM
    final oldItem = currentPantryState.items.firstWhere((item) => item.id == id);

    // 2. Aplicar limpieza si el artículo regresa a la lista (isChecked es false)
    final double finalEstimatedPrice = isChecked ? oldItem.estimatedPrice : 0.0;
    final double? finalRealPrice = isChecked ? oldItem.realPrice : null;
    final double? finalLastPricePaid = isChecked ? oldItem.lastPricePaid : 0.0;

    // 3. Crear el clon inmutable perfectamente sanitizado
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

    // 4. Persistencia limpia y directa en SQLite
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
    debugPrint('🧼 SQLite: Check cambiado a $isChecked. Residuos financieros reseteados con éxito.');

    // 5. Sincronización inmutable en la RAM de Riverpod
    final updatedItems = currentPantryState.items.map((item) {
      return item.id == id ? updatedItem : item.copyWith();
    }).toList();

    state = AsyncValue.data(currentPantryState.copyWith(items: updatedItems));
  }

  // =========================================================================
  // OPERACIONES CONVENCIONALES DE EDICIÓN Y LIMPIEZA
  // =========================================================================

  /// Altera las propiedades físicas del artículo en disco y actualiza la RAM
    /// Altera las propiedades físicas del artículo en disco y actualiza la RAM aislando instancias
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


  /// Remueve físicamente el registro de la alacena activa de SQLite y actualiza la RAM
  Future<void> deleteItem(String id) async {
    final oldState = state.value;
    if (oldState == null) return;

    final db = await _getDatabase();
    await db.delete('pantry_items', where: 'id = ?', whereArgs: [id]);

    final remainingItems = oldState.items.where((item) => item.id != id).toList();
    state = AsyncValue.data(oldState.copyWith(items: remainingItems));
  }
  // =========================================================================
  // CONTROL DE ENTORNO SEGURO Y PRESUPUESTO
  // =========================================================================

    /// Fija el supermercado activo dejando el entorno siempre libre y desbloqueado.
  void setSupermarketManualmente(String storeName) {
    if (!state.hasValue) return;
    final currentState = state.requireValue;

    // 🚀 CORREGIDO: Se fuerza a 'false' de forma perpetua para que la tienda nunca se congele
    const bool shouldLock = false;

    state = AsyncValue.data(currentState.copyWith(
      currentSupermarketId: storeName,
      isEnvironmentLocked: shouldLock, 
    ));
    
    debugPrint('🛰️ Entorno Fijado: Tienda seleccionada [$storeName]. Bloqueado: $shouldLock');
  }


  /// Actualiza el límite financiero de forma local e instantánea en SharedPreferences
  void updateBudgetLimit(double newLimit) async {
    if (state.hasValue) {
      state = AsyncValue.data(state.requireValue.copyWith(budgetLimit: newLimit));
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('presupuesto_guardado', newLimit);
    }
  }

   /// Calcula el nivel de desgaste real de un artículo para activar el semáforo de la UI
  /// Sincronizado en MINUTOS PUROS para garantizar simetría a 0 ms con el motor analítico.
  double getProductDepletionLevel(GroceryItem item) {
    if (item.isAutoInjected) return 1.0;
    if (item.updatedAt == null || !state.hasValue) return 0.0;

    final String name = item.name.toLowerCase().trim();
    final String category = item.category.trim();
    final String key = 'NAME_${_removeAccents(name)}_$category';

    // Recupera el hábito en minutos. Si no tiene registros en el búnker, usa 60 minutos como respaldo de control.
    final double averageMinutes = state.requireValue.productLifespans[key] ?? 60.0;
    
    // Extrae la diferencia exacta en minutos nativos desde la estampa de tiempo hasta este segundo
    final double minutesSinceLastPurchase = DateTime.now().difference(item.updatedAt!).inMinutes.abs().toDouble();
    final double minutesSegurosSince = minutesSinceLastPurchase > 0 ? minutesSinceLastPurchase : 0.1;

    if (averageMinutes <= 0) return 1.0;
    
    // Retorna la relación de desgaste exacta en minutos puros acotada entre 0.0 y 1.0 para la UI
    return (minutesSegurosSince / averageMinutes).clamp(0.0, 1.0);
  }

   // =========================================================================
  // CIERRE DE CARRITO: ALIMENTACIÓN DEL DOBLE HISTORIAL SIMULTÁNEO
  // =========================================================================

    /// Registra los artículos comprados únicamente en el búnker predictivo de la IA
  /// tras confirmación y purga de la alacena activa en SQLite v7.
  Future<void> procesarBunkerYVaciarCarrito(List<GroceryItem> purchasedItems) async {
    if (state.value == null || purchasedItems.isEmpty) return;
    final currentPantryState = state.requireValue;

    final remainingItems = currentPantryState.items.where((item) => !item.isChecked).toList();
    final List<Map<String, dynamic>> updatedHistoryList = List.from(currentPantryState.historicalPrices);
    
    // 🚀 ARCHITECTURE FIX v7: Clonamos el mapa de lifespans para actualizar los pivotes de la IA en caliente sin alertas
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
      
      // Estructuración robusta de la llave para el renderizado del historial offline
      final String itemKey = 'NAME_${cleanName}_CAT:${item.category}_QTY:${item.quantity}_UNT:${item.unit}_STR:${tiendaActual}_DATE:${fechaSelloLlave}_PRC:${precioFinalCobrado}_ID:$microSegundoRAM';
      
      // Inserción al inicio de la lista para mantener la simetría cronológica con SQLite
      updatedHistoryList.insert(0, {
        'compositeKey': itemKey,
        'price': precioFinalCobrado,
        'date': momentoCompra,
      });

      // 🚀 UNIFICACIÓN EN CALIENTE DE LA IA: Sincronizamos la llave de predicción en la RAM de forma inmediata
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

    // Sincronización 100% inmutable, reactiva y libre de alertas/warnings
    state = AsyncValue.data(currentPantryState.copyWith(
      items: remainingItems,
      historicalPrices: updatedHistoryList,
      productLifespans: updatedLifespans, // 🚀 NUEVO: Mapeo sincronizado al instante en memoria
      isEnvironmentLocked: false,
      currentSupermarketId: 'Casa',
    ));
  }

    /// Elimina quirúrgicamente un registro específico del búnker histórico en SQLite y RAM
  Future<void> eliminarRegistroHistorialPorLlave(String compositeKey) async {
    if (!state.hasValue) return;
    final currentPantryState = state.requireValue;

    // 1. Localizar el registro de referencia en la RAM para extraer el DateTime real y el precio
    final matchRef = currentPantryState.historicalPrices.firstWhere(
      (element) => element['compositeKey'] == compositeKey,
      orElse: () => <String, dynamic>{},
    );

    if (matchRef.isEmpty) return;
    
    final DateTime fechaRef = matchRef['date'] as DateTime;
    final double precioRef = matchRef['price'] as double;
    
    // 2. Extraer el identificador de la tienda y el segmento del nombre desde la clave compuesta
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

    // 3. Consultar las filas candidatas en SQLite por fecha e ID de tienda
    final db = await _getDatabase();
    final List<Map<String, dynamic>> filasCandidatas = await db.query(
      'purchase_history',
      where: 'purchase_date = ? AND store_id = ?',
      whereArgs: [fechaRef.toIso8601String(), storeId],
    );

    // 4. Encontrar el ID primario aplicando el mismo Motor Predictivo de desinfectado
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

    // 5. Destrucción física fulminante por Clave Primaria Única
    if (idParaEliminar != null) {
      await db.delete(
        'purchase_history',
        where: 'id = ?',
        whereArgs: [idParaEliminar],
      );
      debugPrint('🧼 SQLite: Registro histórico purgado exitosamente en disco duro por ID: $idParaEliminar');
    } else {
      debugPrint('⚠️ SQLite: No se localizó la fila física correspondiente en el búnker.');
    }

    // 6. Sincronizar de forma inmutable el estado reactivo en RAM de Riverpod
    final updatedHistoryList = currentPantryState.historicalPrices
        .where((element) => element['compositeKey'] != compositeKey)
        .toList();

    state = AsyncValue.data(currentPantryState.copyWith(
      historicalPrices: updatedHistoryList,
    ));
  }

  /// 🧪 HERRAMIENTA DE DEPURACIÓN CRONOLÓGICA: Altera el tiempo de un registro hacia el pasado.
  /// Permite realizar simulaciones precisas del Motor Predictivo y validar el semáforo en caliente.
  Future<void> simularAntiguedadRegistroPorLlave({
    required String compositeKey,
    required int diasAntiguedad,
  }) async {
    if (!state.hasValue) return;
    final currentPantryState = state.requireValue;

    // 1. Localizar el registro de referencia en la RAM para extraer el DateTime real y el precio
    final matchRef = currentPantryState.historicalPrices.firstWhere(
      (element) => element['compositeKey'] == compositeKey,
      orElse: () => <String, dynamic>{},
    );

    if (matchRef.isEmpty) return;
    
    final DateTime fechaRef = matchRef['date'] as DateTime;
    final double precioRef = matchRef['price'] as double;
    
    // 2. Extraer el identificador de la tienda y el segmento del nombre desde la clave compuesta
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

    // 3. Consultar las filas candidatas en SQLite por fecha e ID de tienda
    final db = await _getDatabase();
    final List<Map<String, dynamic>> filasCandidatas = await db.query(
      'purchase_history',
      where: 'purchase_date = ? AND store_id = ?',
      whereArgs: [fechaRef.toIso8601String(), storeId],
    );

    // 4. Encontrar el ID primario aplicando el mismo Motor Predictivo de desinfectado
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

    // 5. Modificación física temporal en disco aplicando la resta exacta de días institucionales
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
      debugPrint('🧪 SIMULADOR IA: Registro [$nombreEnLlave] envejecido con éxito $diasAntiguedad días en SQLite. ID: $idParaModificar');
    } else {
      debugPrint('⚠️ SIMULADOR IA: No se localizó la fila física correspondiente en el búnker para modificar.');
    }

    // 6. Sincronización Local-First total: Recarga la base de datos completa y recalcula hábitos al instante
    await refreshFromLocal();
  }






  void limpiarHistorialCompleto() async {
    if (!state.hasValue) return;
    state = AsyncValue.data(state.requireValue.copyWith(historicalPrices: const []));
    final db = await _getDatabase();
    await db.delete('purchase_history');
  }

  // =========================================================================
  // REPORTE OFICIAL, AUDITORÍA EN TICKET Y AUTO-PURGA POST-COMPARTIR
  // =========================================================================

    /// Genera un ticket en PDF basado en los artículos de la RAM,
  /// lo comparte de forma instantánea y ejecuta la purga absoluta al terminar con éxito.
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
        
        // 🚀 CÁLCULO FINANCIERO ALINEADO: Lee la columna de precio real capturado en tienda
        final double precioPagadoGondola = item.realPrice ?? item.estimatedPrice;
        final double subtotalReal = precioPagadoGondola * item.quantity;
        costoTotalRealReal += subtotalReal;

        // Recupera el valor base real que la IA estimaba originalmente (antes del cambio en góndola)
        final double precioBaseAnterior = (item.lastPricePaid != null && item.lastPricePaid! > 0.0)
            ? item.lastPricePaid!
            : (item.estimatedPrice > 0.0 ? item.estimatedPrice : precioPagadoGondola);
            
        final double subtotalEsperado = precioBaseAnterior * item.quantity;
        costoTotalEsperadoBase += subtotalEsperado;

        // 🚀 CALCULO EXPLICITO DEL BALANCE: Determina con precisión matemática el ahorro o sobrecosto
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

      final Directory tempDir = await getTemporaryDirectory();
      final String pathCompleto = "${tempDir.path}/Ticket_Chispahorro.pdf";
      final File archivoPdf = File(pathCompleto);
      
      // 🚀 RENDIMIENTO HARDWARE MOTO G54: Eliminación del retardo artificial y escritura asíncrona optimizada
      await archivoPdf.writeAsBytes(await pdf.save(), flush: true);

      if (await archivoPdf.exists()) {
        final shareResult = await SharePlus.instance.share(
          ShareParams(
            text: 'Resguardo Oficial de Compra - CHISPAHORRO INTELIGENTE',
            files: [XFile(pathCompleto)],
          ),
        );

        if (shareResult.status != ShareResultStatus.dismissed) {
          debugPrint('🧼 PDF Compartido con éxito. Ejecutando persistencia física y purga.');
          await procesarBunkerYVaciarCarrito(purchasedItems);
        } else {
          debugPrint('⚠️ Compartir cancelado por el usuario. La información permanece intacta en el carrito.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🚨 Error al procesar el reporte: $e')));
      }
    }
  }

      /// 📊 HOJA 1: Envía de forma 100% anónima el lote de compras al búnker analítico B2B.
  Future<void> enviarMetricasAnaliticasSheets(List<GroceryItem> purchasedItems) async {
    try {
      // Url del Web App Script de tu Google Sheet Analítica
      final Uri urlAnalitica = Uri.parse('https://script.google.com/macros/s/AKfycbxa3HwjPSW7aSlXef8lHNKFns6UoxPiuUANgvZgI8zZEW9cTPVAZ4GqmkSDf0Pb8uQf4g/exec');

          final bodyData = jsonEncode({
      'device_hash': 'Device_Local_Anónimo',
      'items': purchasedItems.map((item) {
        // 🚀 CRUCE INTELIGENTE EN RAM: Busca el nombre legible de la tienda usando el ID
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
            nombreTiendaMapeado = currentStoreId; // Respaldo por si no la halla
          }
        }

        return {
          'tienda_id': nombreTiendaMapeado, // 📊 ¡Listo! Ahora sube "Costco" o "Super Q" en vez del ID largo
          'categoria': item.category,
          'producto': _removeAccents(item.name.toLowerCase().trim()),
          'precio_base': item.estimatedPrice,
          'precio_real': item.realPrice ?? item.estimatedPrice,
          'cantidad': item.quantity,
          'fecha': DateTime.now().toIso8601String(),
        };
      }).toList(),
    });


      // Envío asíncrono en segundo plano (Fuego y olvido para no trabar la interfaz)
      unawaited(
        http.post(
          urlAnalitica,
          headers: {'Content-Type': 'application/json'},
          body: bodyData,
        ).then((response) {
          debugPrint('📊 Sheets Analítica: Datos enviados con éxito (Código: ${response.statusCode}).');
        }).catchError((error) {
          debugPrint('⚠️ Error silencioso al enviar analítica a Sheets: $error');
        })
      );
    } catch (e) {
      debugPrint('⚠️ Error general en método analítico: $e');
    }
  }

  /// 💬 HOJA 2: Envía el resumen de ahorros confirmados al Chat Comunitario de Ofertas.
  Future<void> enviarOfertaAlChatSheets(String nombreTienda, String bloqueTextoOfertas) async {
    try {
      // Url del Web App Script de tu Google Sheet del Chat
      final Uri urlChat = Uri.parse('https://script.google.com/macros/s/AKfycbxa3HwjPSW7aSlXef8lHNKFns6UoxPiuUANgvZgI8zZEW9cTPVAZ4GqmkSDf0Pb8uQf4g/exec');

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


