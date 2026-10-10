

import 'package:flutter/foundation.dart'; // 🚀 LÍNEA NUEVA: Para resolver el error de 'kIsWeb'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pantry_provider.dart';
import 'dart:convert'; // 🚀 LÍNEA NUEVA: Resuelve por completo el error de base64Encode

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // 🚀 CORRECCIÓN: Quitamos el 'as' para que funcione global directo
import 'dart:io'; // 🚀 LÍNEA NUEVA: Resuelve los errores de 'Directory' y 'File'
import 'package:path_provider/path_provider.dart'; // 🚀 LÍNEA NUEVA: Resuelve el error de 'getTemporaryDirectory'




class PurchaseHistoryScreen extends ConsumerStatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  ConsumerState<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends ConsumerState<PurchaseHistoryScreen> {
  // Variable local para el buscador interno de compras pasadas
  String _searchQuery = '';
  // 🚀 NUEVO: Variable de estado para el filtro de supermercados
  String _selectedStoreFilter = 'Todas';

  // Formateador de moneda integrado localmente para evitar dependencias


  // Formateador de moneda integrado localmente para evitar dependencias
  String _formatCurrency(double amount) {
    if (amount.isInfinite || amount.isNaN) return '\$0.00';
    String str = amount.toStringAsFixed(2);
    List<String> parts = str.split('.');
    String intPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '00';
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    intPart = intPart.replaceAllMapped(reg, (Match match) => '${match.group(1)},');
    return '\$$intPart.$decimalPart';
  }
  @override
  Widget build(BuildContext context) {
    final asyncPantry = ref.watch(pantryProvider);
// 🚀 MEJORA DE ARQUITECTURA: Acceso reactivo al notifier para limpiezas físicas de memoria
final pantryNotifier = ref.read(pantryProvider.notifier);


// 1. BLINDAJE DE SEGURIDAD RELACIONAL: Previene excepciones nulas al leer la bitácora
if (asyncPantry.isLoading || !asyncPantry.hasValue) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('📋 Auditoría e Historial', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.orange.shade100,
      centerTitle: true,
    ),
    body: const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF0D47A1),
      ),
    ),
  );
}

// 2. DESEMPAQUETADO CRONOLÓGICO: Expone el estado síncrono limpio e inmutable de la IA local
final pantryState = asyncPantry.requireValue;


    // Extraemos el mapa del historial inmutable de la IA local en RAM
        // 🚀 LECTURA DIRECTA: Se extrae la lista de mapas cronológica pura de SQLite
    final List<Map<String, dynamic>> historialCronologico = pantryState.historicalPrices;
        // 🚀 UNIFICACIÓN EN RAM: Convertimos la lista de SQLite a un mapa al vuelo
    // para que todos tus buscadores y filtros inferiores sigan funcionando al 100% sin romperse
    final Map<String, double> historialActual = {
      for (var reg in historialCronologico) 
        if (reg['compositeKey'] != null) reg['compositeKey'] as String : (reg['price'] as num?)?.toDouble() ?? 0.0
    };


    return Scaffold(
      appBar: AppBar(
       title: const Text('📋 Historial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
        backgroundColor: Colors.orange.shade100,
        centerTitle: false,
                  actions: [
          // 📢 BOTÓN GEMELO: Acceso directo a Soporte Técnico y Atención al Cliente
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 4.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: IconButton(
                icon: Icon(Icons.support_agent_rounded, color: Colors.green.shade700, size: 24),
                tooltip: 'Contacto y Soporte Pro',
                onPressed: _openSupportWhatsApp,
              ),
            ),
          ),

          // 🔒 BOTÓN 1: PDF con indicador de candado condicional
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 10.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0D47A1), size: 24),
                    tooltip: 'Exportar historial',
                    onPressed: () {
                      if (pantryState.isPremium) {
                        final datosContables = _obtenerHistorialContableFiltrado(historialActual, pantryState.savedStores);
                        _exportarHistorialFiltradoPDF(datosContables['comprasAgrupadas'] as Map<String, List<Map<String, dynamic>>>, datosContables['granTotalGeneral'] as double);
                      } else {
                        _mostrarAlertaPremiumDialog(context);
                      }
                    },
                  ),
                  if (!pantryState.isPremium)
                    const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.lock_rounded, color: Colors.amber, size: 12),
                    ),
                ],
              ),
            ),
          ),
          
          // 🔒 BOTÓN 2: Vaciar Historial Completo (Basurero) protegido bajo el entorno Premium
          if (historialActual.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: Color.fromARGB(255, 227, 3, 7), size: 24),
                      tooltip: 'Vaciar base de datos',
                      onPressed: () {
                        if (pantryState.isPremium) {
                          _mostrarConfirmarBorradoDialog(context, pantryNotifier);
                        } else {
                          _mostrarAlertaPremiumDialog(context);
                        }
                      },
                    ),
                    if (!pantryState.isPremium)
                      const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.lock_rounded, color: Colors.amber, size: 12),
                      ),
                  ],
                ),
              ),
            ),
        ],


      ),
      body: Column(
        children: [
          // Banner informativo que reporta el estado real del almacenamiento local
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.memory_rounded, color: Colors.orange.shade700, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BASE DE DATOS DE IA LOCAL',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        historialActual.isEmpty
                            ? 'Búnker vacío. Finaliza compras para alimentar la memoria.'
                            : 'Resguardando ${historialActual.length} precios de referencia en el móvil.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

                    // Caja de texto interactiva para buscar registros en el historial offline
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar en precios históricos...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // 🚀 NUEVO: Selector premium para el filtrado por Sucursal Comercial
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStoreFilter,
                  isExpanded: true,
                  icon: const Icon(Icons.filter_alt_rounded, color: Colors.orange),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedStoreFilter = newValue);
                    }
                  },
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'Todas',
                      child: Text('🏪 Filtrar por Tienda: Todas las sucursales'),
                    ),
                    const DropdownMenuItem<String>(
                      value: 'Casa',
                      child: Text('🏠 Entorno: Casa'),
                    ),
                    ...pantryState.savedStores.map<DropdownMenuItem<String>>((tienda) {
                      return DropdownMenuItem<String>(
                        value: tienda['id'].toString(),
                        child: Text('🛒 Tienda: ${tienda['name']}'),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // ?? PROCESAMIENTO EN VIVO: Filtra y limpia las llaves de la IA local

          // 🚀 PROCESAMIENTO EN VIVO: Filtra y limpia las llaves de la IA local
          Expanded(
            child: () {
              if (historialActual.isEmpty) {
                return const Center(
                  child: Text(
                    'No hay registros guardados.\nCompleta una compra en el carrito para iniciar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, height: 1.4),
                  ),
                );
              }

                           // 🚀 MODIFICADO: Sistema de doble filtrado simultáneo en RAM (Texto + Tienda)
              final llavesFiltradas = historialActual.keys.where((key) {
                                // // 1. Validación híbrida (Producto o Fecha) sin alterar la RAM
                final String llaveLimpia = key
                    .replaceAll('NAME_', '')
                    .replaceAll('BAR_', '')
                    .replaceAll('_', ' ')
                    .toLowerCase();

                String fechaRealCompra = '';
                final List<String> fragmentos = key.split('_');
                for (final String frag in fragmentos) {
                  if (frag.startsWith('DATE:')) {
                    fechaRealCompra = frag.replaceAll('DATE:', '').replaceAll('-', '/');
                  }
                }

                final bool cumpleTexto = llaveLimpia.contains(_searchQuery) || fechaRealCompra.contains(_searchQuery);


                // 2. Validación por selección de Tienda
                if (_selectedStoreFilter == 'Todas') {
                  return cumpleTexto; // Si se eligen todas, solo importa el texto
                }

                // Extracción segura del ID de la tienda incrustado en la llave compuesta
                String tiendaIdEnLlave = 'Casa';
                final List<String> partesLlave = key.split('_');
                for (final String parte in partesLlave) {
                  if (parte.startsWith('STR:')) {
                    tiendaIdEnLlave = parte.replaceAll('STR:', '');
                    // Manejo de la subclave relacional en caso de ID compuesto
                    if (tiendaIdEnLlave == 'STORE' && partesLlave.length > partesLlave.indexOf(parte) + 1) {
                      tiendaIdEnLlave = 'STORE_${partesLlave[partesLlave.indexOf(parte) + 1]}';
                    }
                    break;
                  }
                }

                final bool cumpleTienda = tiendaIdEnLlave == _selectedStoreFilter;
                return cumpleTexto && cumpleTienda;
              }).toList();


                               if (llavesFiltradas.isEmpty) {
                return const Center(child: Text('No se encontraron coincidencias.'));
              }

              // 🚀 MOTOR CONTABLE: Agrupación dinámica por Nota de Compra (Fecha + Tienda) en RAM
              double granTotalGeneral = 0.0;
              final Map<String, List<Map<String, dynamic>>> comprasAgrupadas = {};

              for (final String rawKey in llavesFiltradas) {
                final double precioRegistrado = historialActual[rawKey] ?? 0.0;
                String productoNombre = 'ARTÍCULO';
                String cantidadDisplay = '1';
                String unidadDisplay = 'pz';
                String tiendaDisplay = 'Casa';
                String fechaRealCompra = 'Hace días';
                double precioTransaccionReal = precioRegistrado;

                final List<String> partes = rawKey.split('_');
                
                if (partes.length > 1) {
                  productoNombre = partes[1].toUpperCase();
                }

                for (final String parte in partes) {
                  if (parte.startsWith('QTY:')) cantidadDisplay = parte.replaceAll('QTY:', '');
                  if (parte.startsWith('UNT:')) unidadDisplay = parte.replaceAll('UNT:', '');
                  if (parte.startsWith('PRC:')) {
                    precioTransaccionReal = double.tryParse(parte.replaceAll('PRC:', '')) ?? precioTransaccionReal;
                  }
                  if (parte.startsWith('STR:')) {
                    final String storeIdRaw = parte.replaceAll('STR:', '');
                    final String fullStoreId = storeIdRaw == 'STORE' && partes.length > partes.indexOf(parte) + 1 
                        ? 'STORE_${partes[partes.indexOf(parte) + 1]}' 
                        : storeIdRaw;

                    final tiendaMatch = pantryState.savedStores.firstWhere(
                      (t) => t['id'].toString() == fullStoreId,
                      orElse: () => {'name': fullStoreId},
                    );
                    tiendaDisplay = tiendaMatch['name'].toString();
                  }
                  if (parte.startsWith('DATE:')) fechaRealCompra = parte.replaceAll('DATE:', '').replaceAll('-', '/');
                }

                if (cantidadDisplay.endsWith('.0')) {
                  cantidadDisplay = cantidadDisplay.substring(0, cantidadDisplay.length - 2);
                }

                final double parsedQty = double.tryParse(cantidadDisplay) ?? 1.0;
                final double precioFinalUnitario = precioTransaccionReal > 0.0 ? precioTransaccionReal : precioRegistrado;
                               final double precioTotalArticulo = precioFinalUnitario * parsedQty;

                // 🚀 EXTRACTOR DE BALANCE EN RAM: Cruzando histórico contra góndola
                double precioBaseReferencia = 0.0;
                final String nombreNormalizado = productoNombre.toLowerCase().trim();
                
                for (final reg in pantryState.historicalPrices) {
                  final String compKey = reg['compositeKey']?.toString() ?? '';
                  if (compKey.contains('NAME_$nombreNormalizado') && compKey != rawKey) {
                    precioBaseReferencia = (reg['price'] as num?)?.toDouble() ?? 0.0;
                    break;
                  }
                }

                // Balance contable unitario: si precioFinalUnitario es menor a la referencia anterior, es un ahorro real
                final double balanceCalculadoUnitario = precioBaseReferencia > 0.0 ? (precioFinalUnitario - precioBaseReferencia) : 0.0;
                final double balanceCalculadoTotal = balanceCalculadoUnitario * parsedQty;

                granTotalGeneral += precioTotalArticulo;

                final String claveGrupo = '$fechaRealCompra|$tiendaDisplay';
                if (!comprasAgrupadas.containsKey(claveGrupo)) {
                  comprasAgrupadas[claveGrupo] = [];
                }

                comprasAgrupadas[claveGrupo]!.add({
                  'rawKey': rawKey,
                  'fecha': fechaRealCompra,
                  'producto': productoNombre,
                  'cantidad': '$cantidadDisplay $unidadDisplay',
                  'tienda': tiendaDisplay,
                  'precioU': precioFinalUnitario,
                  'balance': balanceCalculadoTotal, // 👈 Inyección del balance real extraído
                  'total': precioTotalArticulo,
                });
              }


              // CONSTRUCCIÓN SÍNCRONA DE LA REJILLA DE FILAS ESTILO EXCEL
              final List<DataRow> filasDeLaTabla = [];
              int contadorFilasGlobal = 0;

              comprasAgrupadas.forEach((claveGrupo, articulosDelGrupo) {
                double subtotalDeEstaLista = 0.0;

                // 1. Añadimos los artículos que pertenecen a este ticket específico
                for (final articulo in articulosDelGrupo) {
                  subtotalDeEstaLista += articulo['total'] as double;
                  
                  final Color fondoCelda = contadorFilasGlobal % 2 == 0 ? Colors.white : Colors.grey.shade50;
                  contadorFilasGlobal++;

                                    filasDeLaTabla.add(
                    DataRow(
                      color: WidgetStateProperty.all(fondoCelda),
                      cells: [
                        DataCell(Text(articulo['fecha'].toString(), style: const TextStyle(fontSize: 11))),
                        
                        // 🚀 MODIFICADO: Celda de producto potenciada con menú de eliminación quirúrgica
                        DataCell(
                          Text(articulo['producto'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext dialogContext) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                                      SizedBox(width: 8),
                                      Text('¿Eliminar Fila?', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  content: Text('¿Deseas borrar "${articulo['producto']}" de este ticket?\nEsta acción removerá este registro de la memoria analítica de la IA.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogContext),
                                      child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () async {
                                        // 1. Cierra el modal de confirmación en la UI
                                        Navigator.pop(dialogContext);
                                        // 2. Dispara la purga inmutable en SQLite y RAM mediante la subllave única
                                        await ref.read(pantryProvider.notifier).eliminarRegistroHistorialPorLlave(articulo['rawKey'].toString());
                                      },
                                      child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        
                        DataCell(Text(articulo['cantidad'].toString(), style: const TextStyle(fontSize: 11))),
                        DataCell(Text(articulo['tienda'].toString(), style: const TextStyle(fontSize: 11))),
                        DataCell(Text(_formatCurrency(articulo['precioU'] as double), style: const TextStyle(fontSize: 11))),
                                                DataCell(
                          Text(
                            _formatCurrency((articulo['balance'] ?? 0.0) as double), 
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
                          )
                        ),

                        DataCell(Text(_formatCurrency(articulo['total'] as double), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87))),
                      ],
                    ),
                  );

                }

                // 2. Inyección de la fila de Subtotal al terminar de procesar esta nota de compra
                filasDeLaTabla.add(
                  DataRow(
                    color: WidgetStateProperty.all(Colors.blue.shade50), // Color distintivo para cortes de caja
                    cells: [
                      const DataCell(Text('SUBTOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 0.5))),
                      DataCell(Text('Corte de Ticket', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800))),
                      const DataCell(Text('', style: TextStyle(fontSize: 11))),
                      DataCell(Text(articulosDelGrupo.first['tienda'].toString(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900))),
                      const DataCell(Text('', style: TextStyle(fontSize: 11))),
                      const DataCell(Text('', style: TextStyle(fontSize: 11))), // 👈 Celda extra inyectada para balancear la UI
                      DataCell(Text(
                        _formatCurrency(subtotalDeEstaLista),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blue.shade900),
                      )),
                    ],
                  ),
                );
              });

              // 3. Inyección de la fila del Gran Total absoluto al final de toda la sábana de Excel
              filasDeLaTabla.add(
                DataRow(
                  color: WidgetStateProperty.all(Colors.orange.shade100),
                  cells: [
                    const DataCell(Text('TOTAL DE GASTOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange, letterSpacing: 1))),
                    const DataCell(Text('', style: TextStyle(fontSize: 11))),
                    const DataCell(Text('', style: TextStyle(fontSize: 11))),
                    const DataCell(Text('', style: TextStyle(fontSize: 11))),
                    const DataCell(Text('', style: TextStyle(fontSize: 11))),
                    const DataCell(Text('', style: TextStyle(fontSize: 11))), // 👈 Quinta celda vacía inyectada
                    DataCell(Text(
                      _formatCurrency(granTotalGeneral), 
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green.shade900),
                    )),
                  ],
                ),
              );

              // Renderizado final responsivo con barras de desplazamiento
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                padding: const EdgeInsets.only(bottom: 24.0, left: 8.0, right: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.grey.shade300,
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.orange.shade800),
                      headingRowHeight: 36,
                      dataRowMinHeight: 28,
                      dataRowMaxHeight: 34,
                      horizontalMargin: 10,
                      columnSpacing: 14,
                      border: TableBorder.all(width: 0.5, color: Colors.grey.shade400),
                      columns: const [
                        DataColumn(label: Text('Fecha', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Producto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Cant.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Tienda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Precio U.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Balance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                      rows: filasDeLaTabla,
                    ),
                  ),
                ),
              );






            }(),
          ),
        ],
      ),
    );
  }


       /// Core Contable: Filtra y agrupa el historial en tiempo real según la UI
  Map<String, dynamic> _obtenerHistorialContableFiltrado(
    Map<String, double> historialActual,
    List<Map<String, dynamic>> savedStores,
  ) {
    double granTotalGeneral = 0.0;
    final Map<String, List<Map<String, dynamic>>> comprasAgrupadas = {};

    final llavesFiltradas = historialActual.keys.where((key) {
      final String llaveLimpia = key
          .replaceAll('NAME_', '')
          .replaceAll('BAR_', '')
          .replaceAll('_', ' ')
          .toLowerCase();
      final bool cumpleTexto = llaveLimpia.contains(_searchQuery);

      if (_selectedStoreFilter == 'Todas') return cumpleTexto;

      String tiendaIdEnLlave = 'Casa';
      final List<String> partesLlave = key.split('_');
      for (final String parte in partesLlave) {
        if (parte.startsWith('STR:')) {
          tiendaIdEnLlave = parte.replaceAll('STR:', '');
          if (tiendaIdEnLlave == 'STORE' && partesLlave.length > partesLlave.indexOf(parte) + 1) {
            tiendaIdEnLlave = 'STORE_${partesLlave[partesLlave.indexOf(parte) + 1]}';
          }
          break;
        }
      }
      return cumpleTexto && (tiendaIdEnLlave == _selectedStoreFilter);
    }).toList();

    for (final String rawKey in llavesFiltradas) {
      final double precioRegistrado = historialActual[rawKey] ?? 0.0;
      String productoNombre = 'ARTÍCULO';
      String cantidadDisplay = '1';
      String unidadDisplay = 'pz';
      String tiendaDisplay = 'Casa';
      String fechaRealCompra = 'Hace días';
      double precioTransaccionReal = precioRegistrado;

      final List<String> partes = rawKey.split('_');
      if (partes.length > 1) productoNombre = partes[1].toUpperCase();

      for (final String parte in partes) {
        if (parte.startsWith('QTY:')) cantidadDisplay = parte.replaceAll('QTY:', '');
        if (parte.startsWith('UNT:')) unidadDisplay = parte.replaceAll('UNT:', '');
        if (parte.startsWith('PRC:')) {
          precioTransaccionReal = double.tryParse(parte.replaceAll('PRC:', '')) ?? precioTransaccionReal;
        }
        if (parte.startsWith('STR:')) {
          final String storeIdRaw = parte.replaceAll('STR:', '');
          final String fullStoreId = storeIdRaw == 'STORE' && partes.length > partes.indexOf(parte) + 1 
              ? 'STORE_${partes[partes.indexOf(parte) + 1]}' 
              : storeIdRaw;

          final tiendaMatch = savedStores.firstWhere(
            (t) => t['id'].toString() == fullStoreId,
            orElse: () => {'name': fullStoreId},
          );
          tiendaDisplay = tiendaMatch['name'].toString();
        }
        if (parte.startsWith('DATE:')) fechaRealCompra = parte.replaceAll('DATE:', '').replaceAll('-', '/');
      }

      if (cantidadDisplay.endsWith('.0')) {
        cantidadDisplay = cantidadDisplay.substring(0, cantidadDisplay.length - 2);
      }

            final double parsedQty = double.tryParse(cantidadDisplay) ?? 1.0;
      final double precioFinalUnitario = precioTransaccionReal > 0.0 ? precioTransaccionReal : precioRegistrado;
      final double precioTotalArticulo = precioFinalUnitario * parsedQty;

      // 🚀 EXTRACTOR DE BALANCE PARA PDF: Sincronización analítica síncrona
      double precioBaseReferencia = 0.0;
      final String nombreNormalizado = productoNombre.toLowerCase().trim();
      
      for (final reg in historialActual.keys) {
        if (reg.contains('NAME_$nombreNormalizado') && reg != rawKey) {
          final List<String> subPartes = reg.split('_');
          for (final String subParte in subPartes) {
            if (subParte.startsWith('PRC:')) {
              precioBaseReferencia = double.tryParse(subParte.replaceAll('PRC:', '')) ?? 0.0;
            }
          }
          if (precioBaseReferencia > 0.0) break;
        }
      }

      final double balanceCalculadoUnitario = precioBaseReferencia > 0.0 ? (precioFinalUnitario - precioBaseReferencia) : 0.0;
      final double balanceCalculadoTotal = balanceCalculadoUnitario * parsedQty;

      granTotalGeneral += precioTotalArticulo;

      final String claveGrupo = '$fechaRealCompra|$tiendaDisplay';
      if (!comprasAgrupadas.containsKey(claveGrupo)) {
        comprasAgrupadas[claveGrupo] = [];
      }

      comprasAgrupadas[claveGrupo]!.add({
        'rawKey': rawKey,
        'fecha': fechaRealCompra,
        'producto': productoNombre,
        'cantidad': '$cantidadDisplay $unidadDisplay',
        'tienda': tiendaDisplay,
        'precioU': precioFinalUnitario,
        'balance': balanceCalculadoTotal, // 👈 Inyección del balance extraído directo para el reporte PDF
        'total': precioTotalArticulo,
      });
    }


    return {
      'comprasAgrupadas': comprasAgrupadas,
      'granTotalGeneral': granTotalGeneral,
    };
  }




     /// Genera un documento PDF basado estrictamente en las agrupaciones filtradas en la UI
  Future<void> _exportarHistorialFiltradoPDF(
    Map<String, List<Map<String, dynamic>>> datosAgrupados,
    double granTotal,
  ) async {
    try {
      if (datosAgrupados.isEmpty) return;

      final pdf = pw.Document();
      final List<List<String>> cuerpoTablaPDF = [];

      // Aplanamos la estructura de la RAM mapeando los cortes estilo Excel al reporte plano
      datosAgrupados.forEach((claveGrupo, articulos) {
        double subtotalTicket = 0.0;

        for (final art in articulos) {
          subtotalTicket += art['total'] as double;
          
          cuerpoTablaPDF.add([
            art['fecha'].toString(),
            art['producto'].toString(),
            art['cantidad'].toString(),
            art['tienda'].toString(),
            _formatCurrency((art['balance'] ?? 0.0) as double),
            _formatCurrency(art['precioU'] as double),
            _formatCurrency(art['total'] as double),
          ]);
        }

        // Inyección visual de la fila de Subtotal en el PDF
        cuerpoTablaPDF.add([
          'SUBTOTAL',
          'Corte de Ticket',
          '',
          articulos.first['tienda'].toString(),
          '',
          _formatCurrency(subtotalTicket),
        ]);
      });

      // Inyección visual del Gran Total al fondo del reporte
      cuerpoTablaPDF.add([
        'Σ TOTAL GENERAL',
        '',
        '',
        '',
        '',
        _formatCurrency(granTotal),
      ]);

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
                    pw.Text('REPORTE HISTÓRICO FILTRADO', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Paragraph(
                text: 'Extracto contable de precios de góndola guardados localmente, adaptado según los filtros de búsqueda activos por el usuario.',
              ),
              pw.SizedBox(height: 12),
              
                           // 🚀 SOLUCIÓN ESTRUCTURADA: Reemplaza la plantilla automática por una Tabla Nativa de PDF para dar soporte a sombreados sin errores
              pw.Table(
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FixedColumnWidth(55),  // Fecha
                  1: const pw.FlexColumnWidth(2),    // Producto
                  2: const pw.FixedColumnWidth(40),  // Cantidad
                  3: const pw.FlexColumnWidth(1.2),  // Tienda
                  4: const pw.FixedColumnWidth(50),  // Precio U.
                  5: const pw.FixedColumnWidth(50),  // Balance
                  6: const pw.FixedColumnWidth(55),  // Total
                },
                children: [
                  // 1. Cabecera Oficial del Reporte
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.orange800),
                     children: ['Fecha', 'Producto', 'Cant.', 'Tienda', 'Precio U.', 'Balance', 'Total'].map((header) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          header,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  // 2. Filas de Datos Inyectadas dinámicamente desde la RAM con interceptor de color
                  ...cuerpoTablaPDF.map((fila) {
                           final String primerTexto = fila.join(' ').toUpperCase();
        final bool esSubtotal = primerTexto.contains('SUBTOTAL');
        final bool esTotalGeneral = primerTexto.contains('TOTAL');

        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: esSubtotal 
                ? PdfColors.green50 
                : esTotalGeneral 
                    ? PdfColors.orange100 
                    : null,
          ),
          children: List.generate(fila.length, (colIndex) {
            final String celdaTexto = fila[colIndex];
            final bool alinearDerecha = colIndex == 4 || colIndex == 5;

            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: pw.Container(
                alignment: alinearDerecha ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                child: pw.Text(
                  celdaTexto,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: (esSubtotal || esTotalGeneral) ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: esSubtotal 
                        ? PdfColors.green900 
                        : esTotalGeneral 
                            ? PdfColors.orange900 
                            : PdfColors.grey900,
                  ),
                ),
              ),
            );
          }),
        );

                  }),
                ],
              ),

            ];
          },
        ),
      );

               if (!kIsWeb) {
        // 🚀 CONTROL NATIVO MÓVIL: path_provider aislado quirúrgicamente para teléfonos
        final Directory tempDir = await getTemporaryDirectory();
        final String pathCompleto = "${tempDir.path}/Historico_Filtrado_Chispahorro.pdf";
        final File archivoPdf = File(pathCompleto);
        
        // Escribimos los bytes crudos directamente en la memoria caché física del móvil
        await archivoPdf.writeAsBytes(await pdf.save(), flush: true);

        if (await archivoPdf.exists()) {
                    // 📢 DISPARADOR PREMIUM DE ÚLTIMA GENERACIÓN: Abre la hoja nativa de compartir apps sin errores
          await SharePlus.instance.share(
            ShareParams(
              text: 'Auditoría de Precios Históricos - CHISPAHORRO INTELIGENTE',
              files: [XFile(pathCompleto)],
            ),
          );
         }
      

      

             } else {
        // 🧠 Capturamos las dimensiones del dispositivo ANTES de la brecha asíncrona del await
        final double anchoPantalla = MediaQuery.of(context).size.width;
        final double altoPantalla = MediaQuery.of(context).size.height;

        // 💻 ENTORNO NAVEGADOR / PWA INSTALADA: Extraemos los bytes puros de la RAM
        final Uint8List pdfBytes = await pdf.save();
        
        // Convertimos el PDF a una cadena Base64 segura para el visor interno de Flutter Web
        final String base64Pdf = base64Encode(pdfBytes);
        final String dataUri = 'data:application/pdf;base64,$base64Pdf';

        // 🚀 ESCUDO ASÍNCRONO PERFECTO: Evaluamos la propiedad nativa del ciclo de vida del State
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.analytics_rounded, color: Color(0xFF0D47A1)),
                  SizedBox(width: 8),
                  Text('Previsualización del Reporte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: anchoPantalla * 0.9,  // ⚡ Corregido: Usa la variable local segura sin consultar el contexto
                height: altoPantalla * 0.5, // ⚡ Corregido: Usa la variable local segura sin consultar el contexto

            child: HtmlElementView(
              viewType: 'pwa-pdf-viewer',
              onPlatformViewCreated: (int viewId) {},
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Descargar'),
                  onPressed: () async {
                    await launchUrl(Uri.parse(dataUri), mode: LaunchMode.platformDefault);
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('WhatsApp'),
                  onPressed: () async {
                    const String mensajeWhatsApp = 'Hola, te comparto mi Reporte Histórico de ChispaHorro⚡';
                    // ⚡ SINCRO DE MAYÚSCULAS Y SINTAXIS: Concatenamos de forma segura el mensaje dentro de wa.me
                    final String urlWhatsapp = "https://wa.me${Uri.encodeComponent(mensajeWhatsApp)}";
                    await launchUrl(Uri.parse(urlWhatsapp), mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }




          } catch (e) {
      if (!mounted) return; // ⚡ Corregido: Usa la propiedad del ciclo de vida nativa del State
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error al procesar el PDF del historial: $e')),
      );
    }


    


  }


    // 🗑️ DIÁLOGO DE LIMPIEZA: Confirma antes de vaciar el historial completo en SharedPreferences
  void _mostrarConfirmarBorradoDialog(BuildContext context, PantryNotifier notifier) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('¿Vaciar Historial?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Esta acción eliminará todos los registros de compras guardados de forma permanente. ¿Deseas continuar?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                notifier.limpiarHistorialCompleto(); // Llama al borrador del provider
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Eliminar Todo',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }




    // 🔒 FORMULARIO INTERACTIVO VIP: Captura el nombre/correo y despacha la solicitud a Google Sheets
  void _mostrarAlertaPremiumDialog(BuildContext context) {
    final TextEditingController usuarioController = TextEditingController();
    bool cargandoEnvio = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Activar Versión Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta característica es exclusiva de la versión Premium. Ingresa tu Nombre o Correo para generar tu solicitud de activación:',
                    style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: usuarioController,
                    enabled: !cargandoEnvio,
                    decoration: InputDecoration(
                      labelText: 'Nombre o Correo Electrónico',
                      labelStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '🔔 Una vez enviado, ponte en contacto con atención al cliente desde el chat para validar tu pago y liberar tu licencia manualmente.',
                    style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: cargandoEnvio ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: cargandoEnvio 
                      ? null 
                      : () async {
                          final String inputText = usuarioController.text.trim();
                          if (inputText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('⚠️ Por favor escribe tu nombre o correo.')),
                            );
                            return;
                          }

                          setStateModal(() => cargandoEnvio = true);

                          // Despachamos la solicitud directo al proveedor para que la inserte en el Excel
                         
                          final bool exito = await ref.read(pantryProvider.notifier).enviarSolicitudPremium(inputText);

                          // 🛡️ ESCUDO ASÍNCRONO: Verificamos si el modal sigue vivo antes de redibujar o usar el contexto
                          if (!context.mounted) return;

                          setStateModal(() => cargandoEnvio = false);

                          if (exito) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📥 ¡Solicitud registrada! Pasa al chat de soporte para reportar tu activación.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('⚠️ Error de red. Inténtalo de nuevo más tarde.')),
                            );
                          }

                        },
                  child: cargandoEnvio
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Solicitar Licencia', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }


   /// 🎧 GEMELO SOPORTE: Abre de forma interactiva el contacto directo por WhatsApp con el Ing. Félix
  Future<void> _openSupportWhatsApp() async {
    const String tuNumeroWhatsApp = '527201494833';
    const String mensajeTexto = 'Hola Ing. Félix Vargas. Necesito soporte técnico o información sobre la activación Premium de ChispaHorro⚡';
    
    //final String urlTexto = "whatsapp://send?phone=$tuNumeroWhatsApp&text=${Uri.encodeComponent(mensajeTexto)}";
        // 🧠 DETECTOR DE ENTORNO: Evaluamos el ancho de la pantalla para decidir el canal de comunicación ideal
    final bool esMonitorPC = MediaQuery.of(context).size.width > 900;

    final String urlTexto = esMonitorPC
        ? "https://wa.me${Uri.encodeComponent(mensajeTexto)}" // 💻 PC: Redirección limpia a WhatsApp Web
        : "whatsapp://send?phone=$tuNumeroWhatsApp&text=${Uri.encodeComponent(mensajeTexto)}"; // 📱 Móvil: Disparo directo a la App nativa

    


    try {
         await launchUrl(
      Uri.parse(urlTexto), 
      mode: LaunchMode.externalApplication,
    );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ No se pudo abrir WhatsApp. Verifica que la app esté instalada o usa la versión móvil.')),
        );
      }
    }
  }


  


}
