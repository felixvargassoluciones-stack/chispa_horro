import 'package:flutter/foundation.dart';

@immutable
class GroceryItem {
  final String id;
  final String name;             // Ej: "Leche Santa Clara" o "Comprar pan dulce"
  final double estimatedPrice;   // Precio base o anterior registrado por la IA ($0.00 por defecto)
  final double? realPrice;       // Precio real capturado en la góndola de la tienda
  final double quantity;         // Soporta kg/L fraccionados (double)
  final String category;         // Ej: "Lácteos", "Limpieza", "Manuales"
  final bool isChecked;          // true si ya se movió al carrito real de la tienda
  final String? aisle;           // El pasillo físico correspondiente
  final String unit;             // Ej: "kg", "L", "pz", "paquete"
  final DateTime? updatedAt;     // Estampa de tiempo indispensable para el Motor Predictivo
  final double? lastPricePaid;   // Último precio registrado en el búnker de la IA para calcular ahorro
  
  // METADATOS DE ENTORNO LOCAL-FIRST:
  final String? supermarketId;   // Almacena a qué tienda pertenece (ej: 'walmart_jacal')
  final bool isAutoInjected;     // True si fue sugerido de forma predictiva por el motor de la IA
  final String fractionLabel;    // Almacena etiquetas legibles: "1/4", "1/2", "1", "250g"
  const GroceryItem({
    required this.id,
    required this.name,
    this.estimatedPrice = 0.0,   // 🚀 REQUERIMIENTO COMPLETADO: Inicia en $0.00 para la lista manual
    this.realPrice,
    this.quantity = 1.0,
    this.category = 'General',
    this.isChecked = false,
    this.aisle,
    this.unit = 'pz',
    this.updatedAt,              
    this.lastPricePaid,          
    this.supermarketId,
    this.isAutoInjected = false,
    this.fractionLabel = '1',
  });

  /// Copia segura de la instancia modificando propiedades específicas (Inmutabilidad)
  GroceryItem copyWith({
    String? id,
    String? name,
    double? estimatedPrice,
    double? realPrice,
    double? quantity,
    String? category,
    bool? isChecked,
    String? aisle,
    String? unit,
    DateTime? updatedAt,         
    double? lastPricePaid,       
    String? supermarketId,
    bool? isAutoInjected,
    String? fractionLabel,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      realPrice: realPrice ?? this.realPrice,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
      aisle: aisle ?? this.aisle,
      unit: unit ?? this.unit,
      updatedAt: updatedAt ?? this.updatedAt,
      lastPricePaid: lastPricePaid ?? this.lastPricePaid, 
      supermarketId: supermarketId ?? this.supermarketId,
      isAutoInjected: isAutoInjected ?? this.isAutoInjected,
      fractionLabel: fractionLabel ?? this.fractionLabel,
    );
  }
  /// Mapeo estrictamente tipado y adaptado a las columnas físicas de tu SQLite v5 (Sin códigos de barra)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'estimated_price': estimatedPrice, 
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'is_checked': isChecked ? 1 : 0,   // Normalizado a INTEGER (0/1) para SQLite
      'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'last_price_paid': lastPricePaid ?? 0.0,
      'supermarket_id': supermarketId ?? 'Casa', // Soporte estricto al entorno congelado
    };
  }

  /// Factory defensivo que desinfecta, normaliza y reconstruye el objeto desde SQLite v5
  factory GroceryItem.fromMap(Map<String, dynamic> map, {bool? fallbackAutoInjected}) {
    return GroceryItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      // Blindaje numérico: Evita caídas si SQLite devuelve enteros en lugar de doubles
      estimatedPrice: (map['estimated_price'] as num? ?? 0.0).toDouble(),
      realPrice: map['real_price'] != null ? (map['real_price'] as num).toDouble() : null,
      quantity: (map['quantity'] as num? ?? 1.0).toDouble(),
      category: map['category']?.toString() ?? 'General',
      isChecked: (map['is_checked'] as int? ?? 0) == 1,
      aisle: map['aisle']?.toString(),
      unit: map['unit']?.toString() ?? 'pz',
      updatedAt: map['updated_at'] != null 
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastPricePaid: (map['last_price_paid'] as num? ?? 0.0).toDouble(),
      supermarketId: map['supermarket_id']?.toString() ?? 'Casa',
      isAutoInjected: fallbackAutoInjected ?? false,
      fractionLabel: map['fraction_label']?.toString() ?? '1',
    );
  }
}
