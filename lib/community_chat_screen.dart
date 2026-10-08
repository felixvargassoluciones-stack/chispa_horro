import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as url_launcher;



class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({super.key});

  @override
  ConsumerState<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
   String _searchQuery = ''; // 🚀 NUEVO: Almacena el texto de búsqueda (Tienda o Fecha)
  List<dynamic> _chatMessages = [];
  bool _isLoading = true;

  /// 🎧 NUEVO: Abre de forma interactiva el contacto directo por WhatsApp
  Future<void> _openSupportWhatsApp() async {
    const String tuNumeroWhatsApp = '527201494833';
    const String mensajeTexto = 'Hola Ing. Félix Vargas. Necesito soporte técnico o información sobre la aplicación ChispaHorro⚡';
    
    //final String urlTexto = "whatsapp://send?phone=$tuNumeroWhatsApp&text=${Uri.encodeComponent(mensajeTexto)}";
           // 🚀 SOLUCIÓN UNIVERSAL WEB: El esquema https://wa.me es 100% compatible con PC (WhatsApp Web) y celulares
    final String urlTexto = "https://wa.me$tuNumeroWhatsApp?text=${Uri.encodeComponent(mensajeTexto)}";


    try {
      await url_launcher.launchUrl(Uri.parse(urlTexto), mode: url_launcher.LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ No se pudo abrir WhatsApp. Verifica que la app esté instalada.')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarMensajesDelChat();
  }
  
  // ... el resto de tus funciones como _cargarMensajesDelChat() continúan igual abajo ...

  /// Lee de forma asíncrona la Google Sheet secundaria del Chat
  Future<void> _cargarMensajesDelChat() async {
    setState(() => _isLoading = true);
    try {
      // 💡 Url del Web App Script de tu Google Sheet del Chat (Modo Lectura)
      final Uri urlChat = Uri.parse('https://script.google.com/macros/s/AKfycbzUY6a0frR_6z5oEoQ5ccDzvmyd-0YpBIn3Up8BZroDyCg66avhzTz-GCNox7RkT1PRsQ/exec');
      
      final response = await http.get(urlChat);
      if (response.statusCode == 200) {
        final List<dynamic> datosDecodificados = jsonDecode(response.body);
        setState(() {
          // Revertimos la lista para que las ofertas más nuevas salgan arriba
          _chatMessages = datosDecodificados.reversed.toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Fallo en el servidor');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ No se pudieron cargar las ofertas comunitarias. Revisa tu conexión.')),
        );
      }
    }
  }

   /// Dispara el reporte comunitario +1 en la Sheet del chat
  Future<void> _reportarMensajeFalso(String mensajeId) async {
    if (mensajeId.isEmpty) return;

    try {
      // Usamos la misma URL de tu script del chat
      final Uri urlChat = Uri.parse('https://script.google.com/macros/s/AKfycbzUY6a0frR_6z5oEoQ5ccDzvmyd-0YpBIn3Up8BZroDyCg66avhzTz-GCNox7RkT1PRsQ/exec');

      // Enviamos el ID del mensaje y una bandera de reporte
      final bodyData = jsonEncode({
        'reportar_id': mensajeId,
      });

      final response = await http.post(
        urlChat,
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Oferta reportada. Si acumula más reportes, se borrará automáticamente.'),
            backgroundColor: Colors.orange,
          ),
        );
        // Recargamos la pizarra para ocultar el mensaje de inmediato si ya alcanzó el límite
        _cargarMensajesDelChat();
      }
    } catch (e) {
      debugPrint('⚠️ Error al enviar reporte a Sheets: $e');
    }
  }


   @override
  Widget build(BuildContext context) {
    // 🚀 NOTA: Eliminamos la lectura de savedStores de la alacena principal para independizar el chat comunitario

    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 Chat De Ofertas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.orange.shade100,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.support_agent_rounded, color: Colors.green.shade700, size: 28),
            tooltip: 'Contacto y Soporte Pro',
            onPressed: _openSupportWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            tooltip: 'Actualizar pizarra',
            onPressed: _cargarMensajesDelChat,
          ),
        ],
      ),
            body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Burbuja informativa PREMIUM COMPACTA Y NEUTRAL
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.gavel_rounded, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Precios compartidos al momento por la comunidad al finalizar sus compras. Usa el triángulo rojo si detectas datos falsos para eliminarlos automáticamente.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          // 🔍 NUEVO: Buscador inteligente por Tienda o Fecha (Resuelve las alertas de la consola)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar por tienda o fecha (ej: Costco o 14/9)...',
                prefixIcon: const Icon(Icons.search, size: 22, color: Colors.orange),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          const SizedBox(height: 4),

                    // 2. Rejilla de mensajes estilo Pizarra de Ofertas con indicador circular premium
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.orange,
                          strokeWidth: 3.5, // Un poco más grueso para mayor visibilidad
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Sincronizando ofertas comunitarias...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : () {
                    // Motor de filtrado en vivo por Tienda o Fecha
                    final mensajesFiltrados = _chatMessages.where((msg) {
                      final String tienda = msg['tienda'].toString().toLowerCase();
                      final String fecha = msg['fecha'].toString().toLowerCase();
                      return tienda.contains(_searchQuery) || fecha.contains(_searchQuery);
                    }).toList();

                                       if (mensajesFiltrados.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icono premium de radar/búsqueda en tonos grises suaves
                              Icon(
                                Icons.youtube_searched_for_rounded,
                                size: 54,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Sin coincidencias para esta búsqueda',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Prueba escribiendo otra sucursal, producto o asegúrate de que la fecha coincida con el historial.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }


                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: mensajesFiltrados.length,
                      itemBuilder: (context, index) {
                        final msg = mensajesFiltrados[index];
                        return _buildChatTile(msg);
                      },
                    );
                  }(),
          ),


        ],
      ),

    );
  }


  

  /// Construye la tarjeta interactiva de la oferta comunitaria
  Widget _buildChatTile(dynamic msg) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shadowColor: Colors.black12,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                        Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: Colors.blueGrey, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      msg['tienda'].toString().toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ],
                ),
                               // 🧼 CORREGIDO: Traductor y formateador numérico ultra-limpio (dd/mm/aaaa)
                Text(
                  () {
                    final String f = msg['fecha'].toString().toLowerCase();
                    
                    // 1. Si ya contiene un formato numérico con diagonales o guiones, lo extrae
                    final matchNum = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(f);
                    if (matchNum != null) {
                      return '${matchNum.group(1)!.padLeft(2, '0')}/${matchNum.group(2)!.padLeft(2, '0')}/${matchNum.group(3)}';
                    }

                    // 2. Diccionario dinámico para interceptar y traducir los meses en inglés de Google
                    final meses = {'jan':'01','feb':'02','mar':'03','apr':'04','may':'05','jun':'06','jul':'07','aug':'08','sep':'09','oct':'10','nov':'11','dec':'12'};
                    String mesNum = '00';
                    meses.forEach((key, value) { if (f.contains(key)) mesNum = value; });

                    // 3. Extraer el número del día y el año usando expresiones regulares básicas
                    final dayMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(f);
                    final yearMatch = RegExp(r'\b(\d{4})\b').firstMatch(f);

                    if (dayMatch != null && yearMatch != null && mesNum != '00') {
                      final String dia = dayMatch.group(1)!.padLeft(2, '0');
                      final String anio = yearMatch.group(1)!;
                      return '$dia/$mesNum/$anio';
                    }

                    // Respaldo por si el texto es muy corto o diferente
                    return f.length > 10 ? f.substring(0, 10) : f;
                  }(),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF757575), fontWeight: FontWeight.bold),
                )


              ],
            ),

            const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    msg['ofertas'].toString(),
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                // Botón de reporte comunitario integrado quirúrgicamente
                                // ⚠️ CORREGIDO: Botón de reporte comunitario blindado con modal de confirmación preventivo
                IconButton(
                  icon: const Icon(Icons.report_problem_outlined, color: Colors.redAccent, size: 20),
                  tooltip: 'Reportar información falsa',
                  onPressed: () {
                    // Despliega el búnker de confirmación antes de disparar paquetes a la red
                    showDialog(
                      context: context,
                      builder: (BuildContext confirmDialogContext) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                              SizedBox(width: 8),
                              Text('¿Confirmar Reporte?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                          content: const Text(
                            'Ayúdanos a mantener la pizarra limpia de precios falsos o desactualizados.\n\n¿Estás seguro de que esta oferta contiene datos incorrectos?',
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(confirmDialogContext), // Cancela de forma limpia sin tocar la red
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                Navigator.pop(confirmDialogContext); // Cierra el modal de confirmación
                                _reportarMensajeFalso(msg['id']?.toString() ?? ''); // Dispara la red de forma segura
                              },
                              child: const Text('Sí, reportar', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }

}

