import 'package:geolocator/geolocator.dart';
import 'database_helper.dart';


class LocationService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Verifica permisos, enciende el GPS por un instante y determina la tienda actual.
  /// 
  /// Retorna:
  /// - `Map<String, dynamic>` con los datos de la tienda si estás a menos de 20 metros.
  /// - `{'id': 'NEW_STORE', 'latitude': lat, 'longitude': lon}` si es una ubicación nueva.
  /// - `null` si el GPS está desactivado, no hay permisos o estás en un punto neutral (como casa).
  Future<Map<String, dynamic>?> checkCurrentStore() async {
    try {
      // 1. Verificar si los servicios de ubicación están encendidos en el dispositivo
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // 2. Gestionar el flujo de permisos de forma segura
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      
      if (permission == LocationPermission.deniedForever) return null;

            // 3. CAPTURA POR DEMANDA (Ahorro de batería extremo)
      Position position = await Geolocator.getCurrentPosition(
        locationSettings:AndroidSettings(
          accuracy: LocationAccuracy.medium, // 👈 CORREGIDO: 'medium' es la nueva palabra oficial para precisión balanceada
          timeLimit: Duration(seconds: 5),   // 👈 CORREGIDO: Apaga el hardware a los 5 segundos de forma nativa en Android
        ),
      );

      // 4. Consultar el catálogo de tiendas guardadas en SQLite
      final List<Map<String, dynamic>> savedStores = await _dbHelper.getAllStores();

      Map<String, dynamic>? closestStore;
      double shortestDistance = double.infinity;

      // 5. Aplicar la Fórmula de Proximidad en línea recta
      for (final store in savedStores) {
        final double storeLat = store['latitude'] as double;
        final double storeLon = store['longitude'] as double;

        // Geolocator calcula la distancia en metros de forma nativa en milisegundos
        double distanceInMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          storeLat,
          storeLon,
        );

        if (distanceInMeters < shortestDistance) {
          shortestDistance = distanceInMeters;
          closestStore = store;
        }
      }

      // 6. Tomar una decisión basada en tu margen de 20 metros
      if (closestStore != null && shortestDistance <= 20.0) {
        // ESCENARIO A: Encontró una tienda guardada en tu rango de compra
        return closestStore;
      } else {
        // ESCENARIO C: Estás en un lugar totalmente nuevo.
        // Si la distancia más cercana es mayor a 200 metros, asumimos que es una zona comercial nueva 
        // (y no tu propia casa o el patio, para no molestar con la alerta).
        if (shortestDistance > 200.0 || savedStores.isEmpty) {
          return {
            'id': 'NEW_STORE',
            'latitude': position.latitude,
            'longitude': position.longitude,
          };
        }
      }

      // ESCENARIO B: Estás cerca de un punto registrado neutral o sin clasificar (Retorna silencio)
      return null;
    } catch (e) {
      // Manejo defensivo: Si el GPS tarda en enganchar o hay un timeout, la app no crashea
      return null;
    }
  }
}
