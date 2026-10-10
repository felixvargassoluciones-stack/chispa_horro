import 'package:flutter/foundation.dart'; // 🚀 SOPORTE WEB: Necesario para detectar si corre en navegador (kIsWeb)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart'; // 🚀 SOPORTE WEB: Acceso al motor de base de datos nativo
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // 🚀 CORRECCIÓN: El nombre exacto de la importación oficial es sqflite_ffi_web.dart
// 🚀 MEJORA DE ARQUITECTURA: Se elimina por completo la importación de Supabase
import 'pantry_screen.dart';



void main() async {
  // Asegura que los canales nativos del teléfono estén listos antes de arrancar
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 SOPORTE WEB: Si detecta que corre en navegador web, redirige el motor nativo a IndexedDB de forma invisible
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // 🛰️ CONSOLIDACIÓN LOCAL-FIRST: Se purga el bloque asíncrono de inicialización en la nube.
  // Ahora la app arranca de golpe en el hilo principal sin llamadas pendientes a internet.

  // ProviderScope es obligatorio para que Riverpod (el cerebro de la app) funcione
  runApp(
    const ProviderScope(
      child: ChispaHorroApp(),
    ),
  );
}

class ChispaHorroApp extends StatelessWidget {
  const ChispaHorroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChispaHorro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      // Conectamos la interfaz gráfica de la alacena y el carrito como la pantalla raíz
      home: const PantryScreen(),
    );
  }
}
