// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/foundation.dart'; // 🚀 SOPORTE WEB: Necesario para detectar si corre en navegador (kIsWeb)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart'; // 🚀 SOPORTE WEB: Acceso al motor de base de datos nativo
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // 🚀 CORRECCIÓN: El nombre exacto de la importación oficial es sqflite_ffi_web.dart

// 🌐 MOTORES DE INYECCIÓN VIRTUAL NATIVOS ADAPTADOS A TU VERSIÓN DEL SDK
import 'dart:ui_web' as ui_web; 
import 'dart:html' as html;

// 🚀 MEJORA DE ARQUITECTURA: Se elimina por completo la importación de Supabase
import 'pantry_screen.dart';

void main() async {
  // Asegura que los canales nativos del teléfono estén listos antes de arrancar
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 SOPORTE WEB: Configuración del ecosistema e inyección de vistas en Chrome/Safari
  if (kIsWeb) {
    // 1. Redirige el motor nativo de SQLite a IndexedDB de forma invisible
    databaseFactory = databaseFactoryFfiWeb;

    // 2. Registramos la fábrica global del visualizador de PDF para evitar pantallas en blanco en PWA instalada
    ui_web.platformViewRegistry.registerViewFactory(
      'pwa-pdf-viewer',
      (int viewId) {
        final html.IFrameElement iframe = html.IFrameElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none';

        iframe.src = 'about:blank';
        return iframe;
      },
    );
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
