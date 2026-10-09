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

import 'package:url_launcher/url_launcher.dart'; // 🚀 LÍNEA NUEVA A INYECTAR


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
  final bool isPremium; // 🔒 VARIABLE VIP: Monitorea el estatus de pago en la RAM

  const PantryState({
    required this.items,
    this.budgetLimit = 1500.0,
    this.productLifespans = const {}, 
    this.historicalPrices = const [], 
    this.currentSupermarketId = 'Casa', 
    this.savedStores = const [],
    this.isEnvironmentLocked = false,
    this.isPremium = false, // Base estándar para todos los usuarios nuevos
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
    bool? isPremium,
  }) {
    return PantryState(
      items: items ?? this.items,
      budgetLimit: budgetLimit ?? this.budgetLimit,
      productLifespans: productLifespans ?? this.productLifespans,
      historicalPrices: historicalPrices ?? this.historicalPrices,
      currentSupermarketId: currentSupermarketId ?? this.currentSupermarketId,
      savedStores: savedStores ?? this.savedStores,
      isEnvironmentLocked: isEnvironmentLocked ?? this.isEnvironmentLocked,
      isPremium : isPremium ?? this.isPremium,
    );
  }

}
class PantryNotifier extends AsyncNotifier<PantryState> {
  
 

 

    @override
  Future<PantryState> build() async {
    try {
      debugPrint("📦 Local-First Activo: Restaurando alacena e IA predictiva desde SQLite.");
      
      // 🛡️ FIRMA INMUTABLE DE DISPOSITIVO: Creamos y fijamos el número de serie para este navegador
      final prefs = await SharedPreferences.getInstance();
      String? equipoId = prefs.getString('chispahorro_device_fixed_id');
      
      if (equipoId == null || equipoId.isEmpty) {
        // Fabricamos el identificador con el formato exacto de tu base de datos del chat
        equipoId = 'MSG_${DateTime.now().millisecondsSinceEpoch}_${(100 + (DateTime.now().microsecondsSinceEpoch % 900))}';
        await prefs.setString('chispahorro_device_fixed_id', equipoId);
        debugPrint('🆔 REGISTRO DE HARDWARE: Generada nueva firma fija para este equipo: $equipoId');
      }

      final PantryState estadoCargado = await _fetchItemsFromLocalDatabase();

      // ⚡ DISPARO AUTOMÁTICO AL INICIAR: Revisa el estatus de pago en segundo plano usando el ID permanente
      Future.microtask(() => verificarEstatusPremiumServidor());

      return estadoCargado;
    } catch (e, stackTrace) {

  debugPrint("🚨 ERROR DETECTADO: $e");
  debugPrint("🛰️ RUTA DEL FALLO (STACKTRACE):");
  if (kDebugMode) {
        debugPrint(stackTrace.toString()); // 🔥 CORRECCIÓN: Usa debugPrint bajo entorno controlado de pruebas
      }
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
    final currentState = state.value;
    if (currentState != null) {
      // 🚀 ADAPTACIÓN WEB NATIVA: En lugar de llamar a SQLite, usamos las tiendas 
      // que el método _fetchItemsFromLocalDatabase ya restauró en el estado.
      state = AsyncData(currentState.copyWith(savedStores: currentState.savedStores));
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

    // 🚀 ADAPTACIÓN WEB NATIVA: Creamos la nueva lista de tiendas en la RAM del estado actual
    final updatedStores = List<Map<String, dynamic>>.from(currentState.savedStores)..add(newStore);

    // Empaquetamos el nuevo estado completo con la sucursal inyectada
    final newState = currentState.copyWith(
      currentSupermarketId: uniqueId,
      savedStores: updatedStores,
    );

    // Guardamos la configuración de inmediato en SharedPreferences de internet
    await _saveStateToLocalStorage(newState);
    
    // Notificamos a la interfaz visual para que redibuje el modal reactivamente
    state = AsyncData(newState);
  }

    Future<void> _saveStateToLocalStorage(PantryState newState) async {
    // 🚀 PERSISTENCIA EN WEB: Guarda los cambios completos en texto JSON dentro del navegador
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chispahorro_web_cache', newState.toJsonString());
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

    // 🚀 ADAPTACIÓN WEB NATIVA: Filtramos la lista en la RAM excluyendo la tienda eliminada
    final updatedStores = currentState.savedStores.where((store) => store['id'] != id).toList();

    // Empaquetamos el nuevo estado redirigiendo el pasillo activo a 'Casa' si se borró la tienda actual
    final newState = currentState.copyWith(
      currentSupermarketId: currentState.currentSupermarketId == id ? 'Casa' : currentState.currentSupermarketId,
      savedStores: updatedStores,
    );

    // Persistimos los datos de forma inmediata en el almacenamiento local del navegador
    await _saveStateToLocalStorage(newState);
    state = AsyncData(newState);
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
       final prefs = await SharedPreferences.getInstance();
    final String? cachedData = prefs.getString('chispahorro_web_cache');

    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        debugPrint("📦 LocalStorage Exitoso: Sincronizando datos de alacena.");
        return PantryState.fromJsonString(cachedData);
      } catch (e) {
        debugPrint("⚠️ Error al deserializar JSON local. Usando valores base: $e");
      }
    } else {
      // 🛡️ SEGURO ANTI-BORRADO PREMIUM: Si Chrome purgó el LocalStorage tras actualizar,
      // obligamos a re-sincronizar el historial analítico directo desde la nube.
      Future.microtask(() => verificarEstatusPremiumServidor());
    }


    final List<Map<String, dynamic>> productsResponse = [];
    final List<Map<String, dynamic>> historyResponse = [];
    final List<Map<String, dynamic>> savedStoresResponse = [];


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

        final updatedItems = [tempItem, ...oldItems];
    final newState = currentPantryState.copyWith(items: updatedItems);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chispahorro_web_cache', newState.toJsonString());
    
    state = AsyncValue.data(newState);

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

          final List<GroceryItem> updatedItemsList = currentPantryState.items.map((item) {
      return item.id == id ? updatedItem : item.copyWith();
    }).toList();

    final newState = currentPantryState.copyWith(items: updatedItemsList);
    
    await _saveStateToLocalStorage(newState);
    
    state = AsyncValue.data(newState);



    
  }
   Future<void> toggleItemCheck(String id, bool isChecked) async {
    if (state.value == null) return;
    final currentPantryState = state.requireValue;

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

    // 🚀 ADAPTACIÓN WEB NATIVA: Reemplazamos la actualización de base de datos SQL
    // por un mapeo síncronizado directo sobre la colección en LocalStorage
    final List<GroceryItem> updatedItemsList = currentPantryState.items.map((item) {
      return item.id == id ? updatedItem : item.copyWith();
    }).toList();

    final newState = currentPantryState.copyWith(items: updatedItemsList);
    
    // Persistimos el estado serializado en el almacenamiento web
    await _saveStateToLocalStorage(newState);
    
    // Notificamos el cambio reactivo a la UI
    state = AsyncValue.data(newState);
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

    // 🚀 BLINDAJE WEB NATIVO: Modificamos el producto de forma directa sobre la colección en RAM
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

    final newState = currentPantryState.copyWith(items: updatedItems);
    
    // Guardamos la persistencia atómica en SharedPreferences de internet
    await _saveStateToLocalStorage(newState);
    state = AsyncValue.data(newState);
  }


    Future<void> deleteItem(String id) async {
    final oldState = state.value;
    if (oldState == null) return;

    // 🚀 ADAPTACIÓN WEB NATIVA: En lugar de borrar en SQL, filtramos la lista en la RAM
    // excluyendo el ID que el usuario seleccionó para eliminar.
    final remainingItems = oldState.items.where((item) => item.id != id).toList();
    final newState = oldState.copyWith(items: remainingItems);
    
    // Guardamos la nueva lista limpia directamente en SharedPreferences del navegador
    await _saveStateToLocalStorage(newState);
    
    // Redibujamos la pantalla reactivamente
    state = AsyncValue.data(newState);
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

    // Filtramos en RAM los artículos pendientes que NO se marcaron
    final remainingItems = currentPantryState.items.where((item) => !item.isChecked).toList();
    
    // 🚀 CORRECCIÓN DE INMUTABILIDAD PROFUNDA WEB: Forzamos el moldeado dinámico explicito de los mapas
    // en la RAM. Esto desbloquea el comando .insert(), permitiendo vaciar el carrito y cerrar el modal.
        // 🚀 BLINDAJE WEB: Forzamos el mapeo dinámico de tipos numéricos para evitar colisiones de inmutabilidad en Chrome
    final List<Map<String, dynamic>> updatedHistoryList = currentPantryState.historicalPrices
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
        
    final Map<String, double> updatedLifespans = currentPantryState.productLifespans.map(
      (k, v) => MapEntry<String, double>(k, (v as num).toDouble()),
    );

    final DateTime momentoCompra = DateTime.now();
    final String fechaSelloLlave = "${momentoCompra.day}-${momentoCompra.month}-${momentoCompra.year}";
    int microSegundoRAM = momentoCompra.millisecondsSinceEpoch;

    // Registramos la simulación cronológica de la compra en el historial interno del JSON
    for (final item in purchasedItems) {
      microSegundoRAM++;
      final String cleanName = _removeAccents(item.name.toLowerCase().trim());
      final String tiendaActual = item.supermarketId ?? 'Casa';
      final double precioFinalCobrado = item.realPrice ?? item.estimatedPrice;
      
      final String itemKey = 'NAME_${cleanName}_CAT:${item.category}_QTY:${item.quantity}_UNT:${item.unit}_STR:${tiendaActual}_DATE:${fechaSelloLlave}_PRC:${precioFinalCobrado}_ID:$microSegundoRAM';
      
            updatedHistoryList.insert(0, {
        'compositeKey': itemKey,
        'price': precioFinalCobrado,
        'date': momentoCompra.toIso8601String(), // 🔥 SOLUCIÓN: Almacenamiento en texto puro para blindaje web
      });

      final String baseKey = 'NAME_${cleanName}_${item.category.trim()}';
      updatedLifespans[baseKey] = precioFinalCobrado;
    }

    final newState = currentPantryState.copyWith(
      items: remainingItems,
      historicalPrices: updatedHistoryList,
      productLifespans: updatedLifespans, 
      isEnvironmentLocked: false,
      currentSupermarketId: 'Casa',
    );

    // Guardamos el estado limpio directamente en SharedPreferences del navegador
    await _saveStateToLocalStorage(newState);
    state = AsyncValue.data(newState);
  }

    Future<void> eliminarRegistroHistorialPorLlave(String compositeKey) async {
    if (!state.hasValue) return;
    final currentPantryState = state.requireValue;

    // 🚀 BLINDAJE WEB NATIVO: Purgamos el registro de la lista en RAM sin tocar SQLite
    final updatedHistoryList = currentPantryState.historicalPrices
        .where((element) => element['compositeKey'] != compositeKey)
        .toList();

    final newState = currentPantryState.copyWith(
      historicalPrices: updatedHistoryList,
    );

    // Persistimos el cambio en el almacenamiento local del navegador y actualizamos el estado visual
    await _saveStateToLocalStorage(newState);
    state = AsyncValue.data(newState);
  }


    Future<void> simularAntiguedadRegistroPorLlave({
    required String compositeKey,
    required int diasAntiguedad,
  }) async {
    if (!state.hasValue) return;
    final currentPantryState = state.requireValue;

    // 🚀 CORRECCIÓN DE INMUTABILIDAD: Forzamos el moldeado explícito de los mapas en la RAM
    final List<Map<String, dynamic>> updatedHistoryList = currentPantryState.historicalPrices
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();

    // Localizamos el artículo por su clave compuesta cronológica
    final int index = updatedHistoryList.indexWhere((element) => element['compositeKey'] == compositeKey);
    if (index == -1) return;

    final dynamic rawDate = updatedHistoryList[index]['date'];
    DateTime fechaOriginal = DateTime.now();
    if (rawDate is String) {
      fechaOriginal = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is DateTime) {
      fechaOriginal = rawDate;
    }

    // Restamos los días de antigüedad de forma síncrona en Dart
    final DateTime nuevaFechaSimulada = fechaOriginal.subtract(Duration(days: diasAntiguedad));

    // Guardamos la nueva fecha como String ISO8601 para mantener consistencia en la caché JSON
    updatedHistoryList[index]['date'] = nuevaFechaSimulada.toIso8601String();

    final newState = currentPantryState.copyWith(
      historicalPrices: updatedHistoryList,
    );

    // Persistimos el estado en SharedPreferences y actualizamos de forma reactiva
    await _saveStateToLocalStorage(newState);
    state = AsyncValue.data(newState);
  }


    void limpiarHistorialCompleto() async {
    if (!state.hasValue) return;
    final currentPantryState = state.requireValue;

    // 🚀 ADAPTACIÓN WEB NATIVA: Seteamos la lista del historial como un arreglo vacío []
    final newState = currentPantryState.copyWith(historicalPrices: const []);
    
    // Guardamos la persistencia atómica en la caché local del navegador
    await _saveStateToLocalStorage(newState);
    state = AsyncValue.data(newState);
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
          // 📢 PUENTE DE HARDWARE: Invoca el menú binario nativo con escucha activa de estatus
                    // 📢 DISPARADOR PREMIUM: Despliega el menú interactivo nativo y limpia el búnker síncronamente al salir
          await SharePlus.instance.share(
            ShareParams(
              text: 'Resguardo Oficial de Compra - CHISPAHORRO INTELIGENTE',
              files: [XFile(pathCompleto)],
            ),
          );

          // ⚡ VACÍO DE RAM ATÓMICO: Ejecución directa garantizada al cerrar el canal de hardware
          await procesarBunkerYVaciarCarrito(purchasedItems);

        }
      

                } else {
        // 💻 ENTORNO NAVEGADOR (Celular Web / PC): Extraemos los bytes puros de la RAM
        final Uint8List pdfBytes = await pdf.save();
        
        final XFile webFile = XFile.fromData(
          pdfBytes,
          mimeType: 'application/pdf',
          name: 'Ticket_Chispahorro.pdf',
        );

        // 🚀 APERTURA EXTERNA: Forzamos una pestaña limpia del navegador saltándonos el visor de Drive
        await launchUrl(
          Uri.parse(webFile.path),
          mode: LaunchMode.externalApplication,
        );

        // ⚡ CIERRE DE CICLO RECOLECTOR: Vaciamos el carrito y alimentamos la IA en el navegador
        await procesarBunkerYVaciarCarrito(purchasedItems);
      }


    } catch (e) {
      debugPrint('🚨 Error al procesar el reporte: $e');
    }
  }


      Future<void> enviarMetricasAnaliticasSheets(List<GroceryItem> purchasedItems) async {
    try {
      final Uri urlAnalitica = Uri.parse('https://script.google.com/macros/s/AKfycbzUY6a0frR_6z5oEoQ5ccDzvmyd-0YpBIn3Up8BZroDyCg66avhzTz-GCNox7RkT1PRsQ/exec');

      final itemsMapped = purchasedItems.map((item) {
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
      }).toList();

            // 🚀 SOLUCIÓN CORRECCIÓN WEB NATIVA: Enviamos los parámetros formateados como texto plano 
      // de formulario clásico. Esto evita que Chrome lance la alerta roja de CORS Policy en GitHub Pages.
            // 🚀 SOLUCIÓN WEB DEFINITIVA: Desglosamos la carga para que viaje como texto plano directo compatible con e.parameter
      unawaited(
        http.post(
          urlAnalitica,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'accion': 'analitica', // 🛡️ Bandera de control para la macro
            'device_hash': 'Device_Local_Anónimo',
            'items_json': jsonEncode(itemsMapped), // Enviamos la cadena JSON dentro de la clave del formulario
          },
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
      // 🚀 RESPALDO WEB ANTI-CORS: Apuntamos de vuelta al script correcto de tu macro de Sheets
      final Uri urlChat = Uri.parse('https://script.google.com/macros/s/AKfycbzUY6a0frR_6z5oEoQ5ccDzvmyd-0YpBIn3Up8BZroDyCg66avhzTz-GCNox7RkT1PRsQ/exec');

      // 🚀 SOLUCIÓN WEB NATIVA: Codificación clásica de formulario plano para saltar las restricciones CORS de Chrome
      unawaited(
        http.post(
          urlChat,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'tienda': nombreTienda,
            'ofertas': bloqueTextoOfertas,
            'fecha': '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          },
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

     // 🔒 REGISTRO DE LICENCIAS MANUAL: Envía el usuario y el hash dinámico para validación administrativa
  Future<bool> enviarSolicitudPremium(String identificadorUsuario) async {
    if (identificadorUsuario.trim().isEmpty) return false;

    try {
      // 🚀 Recuperamos el ID inmutable fijado en el arranque para este navegador específico
      final prefs = await SharedPreferences.getInstance();
      final String hashFijoEquipo = prefs.getString('chispahorro_device_fixed_id') ?? 'MSG_DEFAULT_ERROR';

      final Uri urlRegistro = Uri.parse(
        'https://script.google.com/macros/s/AKfycbzUY6a0frR_6z5oEoQ5ccDzvmyd-0YpBIn3Up8BZroDyCg66avhzTz-GCNox7RkT1PRsQ/exec'
      );

      final response = await http.post(
        urlRegistro,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'accion': 'solicitar_premium',
          'usuario': identificadorUsuario.trim(),
          'device_hash': hashFijoEquipo, // 🔥 ENVIAR AL EXCEL: Amarramos la solicitud al número de serie real de este hardware
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resData = jsonDecode(response.body);
        if (resData['status'] == 'success') {
          debugPrint('📥 SOLICITUD DE LICENCIA [$hashFijoEquipo]: Registrada con éxito en la nube.');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error de red al tramitar solicitud de licencia: $e');
      return false;
    }
  }


     
  



     // 🛰️ MOTOR DE VERIFICACIÓN VIP: Consulta en vivo el estatus dinámico en la macro de Google
  Future<void> verificarEstatusPremiumServidor() async {
    final currentState = state.value;
    if (currentState == null) return;

    try {
      // 🚀 Recuperamos el ID inmutable fijado en el arranque para este navegador específico
      final prefs = await SharedPreferences.getInstance();
      final String hashFijoEquipo = prefs.getString('chispahorro_device_fixed_id') ?? 'MSG_DEFAULT_ERROR';

      // Adjuntamos las variables query dinámicas para que la función doGet localice la fila en tu Excel
      final Uri urlValidacion = Uri.parse(
        'https://script.google.com/macros/s/AKfycbzUY6a0frR_6z5oEoQ5ccDzvmyd-0YpBIn3Up8BZroDyCg66avhzTz-GCNox7RkT1PRsQ/exec'
      ).replace(queryParameters: {
        'accion': 'verificar_premium',
        'device_hash': hashFijoEquipo, // 🔥 CONSULTA FIJA: Busca el número de serie de este hardware
      });

      final response = await http.get(urlValidacion);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final dynamic rawPremium = data['is_premium'];
        final bool esPremiumReal = rawPremium == true || rawPremium.toString().toLowerCase() == 'true';

        // Sincronizamos la memoria RAM de Flutter con el veredicto en vivo de tu Google Sheets
        state = AsyncData(currentState.copyWith(isPremium: esPremiumReal));
        debugPrint('🔒 LICENCIA SINCRO [$hashFijoEquipo]: Estatus Premium = $esPremiumReal');
      }
    } catch (e) {
      debugPrint('⚠️ Falla de red al verificar estatus Premium: $e');
    }
  }




}

final pantryProvider = AsyncNotifierProvider<PantryNotifier, PantryState>(
  PantryNotifier.new,
  
);


