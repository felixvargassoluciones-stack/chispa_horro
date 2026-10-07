import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 🚀 MEJORA DE ARQUITECTURA: Se elimina por completo la importación de Supabase
import 'pantry_screen.dart';



void main() async {
  // Asegura que los canales nativos del teléfono estén listos antes de arrancar
  WidgetsFlutterBinding.ensureInitialized();

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
