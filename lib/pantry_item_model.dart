/// Modelo de datos para la alacena activa.
/// Mapea de forma estricta contra la tabla 'pantry_items' de SQLite v5.
class PantryItemModel {
  final String id;
  final String name;
  final double estimatedPrice;
  final double quantity;
  final String unit;
  final String category;
  final bool isChecked;
  final String updatedAt;
  final double lastPricePaid;

  const PantryItemModel({
    required this.id,
    required this.name,
    required this.estimatedPrice,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.isChecked,
    required this.updatedAt,
    required this.lastPricePaid,
  });

  /// Transforma el objeto Dart a un Mapa para guardarlo en SQLite v5.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'estimated_price': estimatedPrice,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      // SQLite no tiene booleanos nativos, normalizamos a 1 (true) o 0 (false)
      'is_checked': isChecked ? 1 : 0,
      'updated_at': updatedAt,
      'last_price_paid': lastPricePaid,
    };
  }

  /// Reconstruye el objeto Dart desde un Mapa obtenido de SQLite de forma segura.
  factory PantryItemModel.fromMap(Map<String, dynamic> map) {
    return PantryItemModel(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Sin nombre',
      estimatedPrice: (map['estimated_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: (map['unit'] as String?) ?? 'unidades',
      category: (map['category'] as String?) ?? 'General',
      // Convertimos el entero 1 o 0 de SQLite de vuelta a booleano en RAM de forma segura
      isChecked: (map['is_checked'] as int?) == 1,
      updatedAt: (map['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
      lastPricePaid: (map['last_price_paid'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
