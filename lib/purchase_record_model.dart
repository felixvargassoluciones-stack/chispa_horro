/// Modelo de datos histórico e inmutable para el motor predictivo de la IA.
/// Mapea de forma estricta contra la tabla 'purchase_history' de SQLite.
class PurchaseRecordModel {
  final int? id; // Autoincremental en SQLite, nulo al insertar un registro nuevo
  final String productName;
  final String category;
  final double pricePaid;
  final double quantityBought;
  final String unitConcept;
  final String storeId;
  final String purchaseDate; // Formato fijo inmutable: AAAA-MM-DD

  const PurchaseRecordModel({
    this.id,
    required this.productName,
    required this.category,
    required this.pricePaid,
    required this.quantityBought,
    required this.unitConcept,
    required this.storeId,
    required this.purchaseDate,
  });

    /// Transforma el registro histórico a un Mapa para insertarlo en SQLite.
  Map<String, dynamic> toMap() {
    // Definimos explícitamente el mapa como <String, dynamic>
    final Map<String, dynamic> map = {
      'product_name': productName,
      'category': category,
      'price_paid': pricePaid,
      'quantity_bought': quantityBought,
      'unit_concept': unitConcept,
      'store_id': storeId,
      'purchase_date': purchaseDate,
    };
    
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }


  /// Reconstruye el registro histórico desde un Mapa de SQLite.
  factory PurchaseRecordModel.fromMap(Map<String, dynamic> map) {
    return PurchaseRecordModel(
      id: map['id'] as int?,
      productName: map['product_name'] as String,
      category: map['category'] as String,
      pricePaid: (map['price_paid'] as num).toDouble(),
      quantityBought: (map['quantity_bought'] as num).toDouble(),
      unitConcept: map['unit_concept'] as String,
      storeId: map['store_id'] as String,
      purchaseDate: map['purchase_date'] as String,
    );
  }
}
