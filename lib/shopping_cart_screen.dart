//import 'database_helper.dart'; // 🚀 CORREGIDO: Añade el acceso directo al búnker SQLite

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pantry_provider.dart';
import 'grocery_item.dart';

class ShoppingCartScreen extends ConsumerStatefulWidget {
  const ShoppingCartScreen({super.key});

  @override
  ConsumerState<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends ConsumerState<ShoppingCartScreen> {
  String _searchQuery = '';

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
// 🚀 MEJORA DE ARQUITECTURA: Acceso reactivo al notifier para el cierre transaccional
final pantryNotifier = ref.read(pantryProvider.notifier);


// 1. BLINDAJE ANTI-PARPADEO: Detiene el renderizado hasta que SQLite libere los datos en RAM
if (asyncPantry.isLoading || !asyncPantry.hasValue) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('🛒 Mi Carrito de Compra', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.blue.shade100,
      centerTitle: true,
    ),
    body: const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF0D47A1),
      ),
    ),
  );
}

// 2. DESEMPAQUETADO FINANCIERO: Extrae de forma limpia el estado síncrono real de SQLite
final pantryState = asyncPantry.requireValue;



        // 💵 CONSOLIDACIÓN FINANCIERA REAL: Suma el precio real capturado en la góndola (realPrice) 
    // en lugar del estimado base, garantizando simetría total con el ticket del supermercado.
    final double totalCartSpent = pantryState.items
        .where((item) => item.isChecked)
        .fold(0.0, (sum, item) => sum + ((item.realPrice ?? item.estimatedPrice) * item.quantity));


    final double moneyAvailable = pantryState.budgetLimit - totalCartSpent;
    final bool isOverBudget = moneyAvailable < 0;
    final Color availableColor = isOverBudget ? Colors.red.shade900 : Colors.green.shade900;

    // 🚀 TU PROPUESTA MATEMÁTICA: Resta directa entre Presupuesto y Disponible Real para el Costo Real
    final double costoRealCompra = pantryState.budgetLimit - moneyAvailable;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛒 Mi Carrito de Compra', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isOverBudget ? Colors.red.shade100 : Colors.blue.shade100,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // PANEL FINANCIERO TRIPLE CONSOLIDADO (PUNTO 6 + TU RESTA MATEMÁTICA)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isOverBudget ? Colors.red.shade50 : Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: isOverBudget ? Colors.red.shade200 : Colors.blue.shade200, width: 1.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Nivel 1: Presupuesto Asignado Fijo
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(8), 
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('PRESUPUESTO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey.shade700)),
                            const SizedBox(height: 2),
                            Text(_formatCurrency(pantryState.budgetLimit), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 🚀 Nivel 2: Tu Costo Real de Compra acumulado en vivo mediante la resta directa
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(8), 
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('MONTO A PAGAR', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey.shade700)),
                            const SizedBox(height: 2),
                            Text(_formatCurrency(costoRealCompra), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                 const SizedBox(height: 8),
                // Nivel 3: Dinero Real Disponible Líquido en Caja de Cobro
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isOverBudget ? Colors.red.shade100 : Colors.white,
                    borderRadius: BorderRadius.circular(8), 
                    border: Border.all(color: isOverBudget ? Colors.red.shade400 : Colors.green.shade300, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(isOverBudget ? '⚠️ DINERO FALTANTE' : '💵 DINERO DISPONIBLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade800, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(_formatCurrency(moneyAvailable), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: availableColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // BUSCADOR RÁPIDO DE CONTENIDO INTERNO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar en mi carrito...',
                prefixIcon: const Icon(Icons.search, size: 28),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // FILTRADO EXCLUSIVO: SÓLO PRODUCTOS MARCADOS CON LA PALOMITA (isChecked == true)
                   // 🚀 OPTIMIZADO: Filtro inteligente con alertas diferenciadas y corrección de altura
          Expanded(
            child: () {
              // Verificamos primero si el carrito real en la base de datos no tiene nada marcado
              final bool carritoFisicoVacio = !pantryState.items.any((item) => item.isChecked);

              if (carritoFisicoVacio) {
                return const Center(
                  child: Text(
                    'Carrito vacío.\nRegresa y marca artículos para mandarlos aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                  ),
                );
              }

              // Si el carrito sí tiene cosas, ejecutamos el filtro por texto del buscador
              final cartItems = pantryState.items.where((item) {
                final bool matchesSearch = item.name.toLowerCase().contains(_searchQuery);
                final bool isInCart = item.isChecked;
                return matchesSearch && isInCart;
              }).toList();

              // Si el carrito tenía cosas pero el buscador lo dejó en 0, la alerta cambia
              if (cartItems.isEmpty) {
                return const Center(
                  child: Text(
                    'No hay coincidencias en tu carrito para esta búsqueda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                );
              }

              // Secuencia física ordenada del Walmart para que agrupe en el súper
              final List<String> jacalAisleOrder = [
                'Frutas y Verduras',
                'Carnes',
                'Lácteos',
                'Abarrotes',
                'Limpieza',
                'General',
                'Manual',
              ];

              cartItems.sort((a, b) {
                int indexA = jacalAisleOrder.indexOf(a.category);
                int indexB = jacalAisleOrder.indexOf(b.category);
                if (indexA == -1) indexA = 99;
                if (indexB == -1) indexB = 99;
                return indexA.compareTo(indexB);
              });

              final sortedCartList = List<GroceryItem>.from(cartItems);

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80.0), // Ajustado para evitar altura fantasma
                itemCount: sortedCartList.length,
                itemBuilder: (context, index) {


                        final item = sortedCartList[index];
                        final double subtotal = (item.realPrice ?? item.estimatedPrice) * item.quantity;

                        final double depletion = pantryNotifier.getProductDepletionLevel(item);
                        final bool isCritical = depletion >= 0.8;

                        String qtyDisplay = item.quantity.toString();
                        if (qtyDisplay.endsWith('.0')) {
                          qtyDisplay = qtyDisplay.substring(0, qtyDisplay.length - 2);
                        }
                        final String unitDisplay = item.unit.isNotEmpty ? item.unit : 'Pieza';
                        final String labelUnit = item.quantity > 1 && unitDisplay.toLowerCase() == 'pieza' ? 'Piezas' : unitDisplay;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          elevation: isCritical ? 5.0 : 3.0,
                          shadowColor: Colors.black.withValues(alpha: 0.45),
                          color: const Color(0xFFF2F4F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isCritical ? Colors.orange.shade700 : Colors.transparent,
                              width: isCritical ? 1.5 : 0.0,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const SizedBox.shrink(),
                                    Transform.scale(
                                      scale: 1.1,
                                      child: SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: Checkbox(
                                          value: item.isChecked,
                                          activeColor: Colors.green.shade700,
                                          checkColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                               onChanged: (_) {
                                  // 🧼 Regresa el artículo limpiando de raíz todos los residuos financieros 
                                  // para permitir recálculos infinitos de ahorro verde en góndola
                                  ref.read(pantryProvider.notifier).toggleItemCheck(item.id, false);
                                },

                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2), // 🚀 COMPACTADO: Espaciador vertical reducido de 4 a 2
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Expanded(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          // 🚀 ETIQUETA RELACIONAL DE ENTORNO ACTIVO
          (() {
            final tiendaMatch = pantryState.savedStores.firstWhere(
              (t) => t['id'].toString() == (item.supermarketId ?? 'Casa'),
              orElse: () => {'name': item.supermarketId ?? 'Casa'},
            );

            return Container(
              // 🚀 COMPACTADO: Margen interno vertical sintonizado
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                tiendaMatch['name'].toString().toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 9),
              ),
            );
          }()),

          Container(
            // 🚀 COMPACTADO: Unificación de padding vertical con las tarjetas de la alacena
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Text(
              '${qtyDisplay}x $labelUnit',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: Colors.grey.shade700, 
                fontSize: 10.5, // 🚀 COMPACTADO: Multiplicador bajado a 10.5 píxeles
              ),
            ),
          ),
          Text(
            item.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13, // 🚀 COMPACTADO: Nombre del producto reducido de 16 a 13 píxeles
              color: Colors.black45, 
              decoration: TextDecoration.lineThrough, 
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
    
    // 💵 BLOQUE DERECHO: Subtotal neto escalado a las proporciones de la alacena
    SizedBox(
      width: 110, // 🛡️ Ancho controlado anti-desbordamientos
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _formatCurrency(subtotal),
            // 🚀 COMPACTADO: Subtotal ajustado a 13 píxeles para máxima homogeneidad
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.green),
          ),
          if (item.quantity > 1) ...[
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '(${_formatCurrency(item.realPrice ?? item.estimatedPrice)} c/u)',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    ),
  ],
),

                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end, 
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
  'Precio: ${_formatCurrency(item.realPrice ?? item.estimatedPrice)}',
  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
),

                                        if (item.lastPricePaid != null && item.lastPricePaid! != item.estimatedPrice)
                                          const SizedBox(height: 2),
                                                                                   // 🚀 SENIOR FIX v7: Cálculo del balance confrontando el precio base histórico contra el costo real de góndola
                                        () {
                                          final double precioBase = item.estimatedPrice;
                                          final double precioActual = item.realPrice ?? item.estimatedPrice;

                                          if (precioBase > 0.0 && precioActual != precioBase) {
                                            if (precioActual < precioBase) {
                                              // Caso 1: El precio actual es menor, se genera un ahorro real
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                child: Text(
                                                  '(¡Ahorras ${_formatCurrency(precioBase - precioActual)}!)',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                                ),
                                              );
                                            } else {
                                              // Caso 2: El precio actual es mayor, alerta de inflación en la tienda
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                child: Text(
                                                  '(+${_formatCurrency(precioActual - precioBase)} más caro)',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                                                ),
                                              );
                                            }
                                          }
                                          return const SizedBox.shrink();
                                        }(),


                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }(),
          ),
          
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton.extended(
              heroTag: 'checkout_cart_btn',
              onPressed: pantryState.items.any((item) => item.isChecked)
                  ? () {
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('¿Finalizar Compra?', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text('Se guardarán estos artículos en tu historial y se limpiará el carrito actual.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext), 
                                child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                              ),
                                
   ElevatedButton(
  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
  onPressed: () async {
    // 1. Extraemos síncronamente en RAM los artículos que llevan la palomita
    final itemsComprados = pantryState.items.where((item) => item.isChecked).toList();

    Navigator.pop(dialogContext); // Cierra de inmediato el modal de advertencia visual

    if (itemsComprados.isNotEmpty) {
      // 2. DISPARO ANALÍTICO B2B (Fuego y olvido en segundo plano a 0 ms)
      await ref.read(pantryProvider.notifier).enviarMetricasAnaliticasSheets(itemsComprados);

      // 3. DETECTOR INTELIGENTE DE AHORROS (Motor del Chat)
      final List<String> lineasOfertas = [];
      
      for (final item in itemsComprados) {
        final double precioBase = item.estimatedPrice;
        final double precioActual = item.realPrice ?? item.estimatedPrice;

        // Si el precio de góndola fue menor al precio base recordado por la IA, ¡hay oferta!
        if (precioBase > 0.0 && precioActual < precioBase) {
          final double ahorroUnitario = precioBase - precioActual;
          lineasOfertas.add('• ${item.name}: \$${precioActual.toStringAsFixed(2)} (Ahorras \$${ahorroUnitario.toStringAsFixed(2)})');
        }
      }

      // 4. PERSISTENCIA Y PURGA LOCAL FÍSICA EN DISCO
      await ref.read(pantryProvider.notifier).procesarBunkerYVaciarCarrito(itemsComprados);

      // 5. EVALUACIÓN Y LANZAMIENTO DEL CHAT COMUNITARIO
      if (lineasOfertas.isNotEmpty && context.mounted) {
        // Obtenemos el nombre legible del súper actual para el reporte público
        final String currentStoreId = itemsComprados.first.supermarketId ?? pantryState.currentSupermarketId;

        final tiendaMatch = pantryState.savedStores.firstWhere(
          (t) => t['id'].toString() == currentStoreId,
          orElse: () => {'name': currentStoreId == 'Casa' ? 'Casa' : 'Supermercado'},
        );
        final String nombreTiendaMostrar = tiendaMatch['name'].toString();

        final String bloqueTextoOfertas = lineasOfertas.join('\n');

        // Mostramos el cuadro interactivo de invitación al chat
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (chatDialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('¡Compartir Ahorros!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detectamos que conseguiste ofertas reales en tu compra. ¿Te gustaría compartirlas de forma anónima para ayudar a otras familias?',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      '$nombreTiendaMostrar:\n$bloqueTextoOfertas',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.black87),
                    ),
                  ),
                ],
              ),
                                 actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(chatDialogContext); // Cierra el modal de invitación de forma limpia
              Navigator.pop(context); // Sale del carrito regresando a la alacena
            },
            child: const Text('Ahora no', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
            onPressed: () async {
              // 1. Congelamos la referencia del navegador de la UI para evitar parpadeos asíncronos
              final navigator = Navigator.of(context);
              
              // 2. PROCESAMIENTO QUIRÚRGICO INDIVIDUAL POR ARTÍCULO (Evita la acumulación en una sola celda)
              for (final item in itemsComprados) {
                final double precioBase = item.estimatedPrice;
                final double precioActual = item.realPrice ?? item.estimatedPrice;

                // Evaluamos de forma independiente si este artículo específico generó ahorro verde
                if (precioBase > 0.0 && precioActual < precioBase) {
                  final double ahorroUnitario = precioBase - precioActual;
                  
                  // Extraemos dinámicamente el nombre comercial de la tienda correspondiente a ESTE artículo
                  final String itemStoreId = item.supermarketId ?? pantryState.currentSupermarketId;
                  final tiendaMatch = pantryState.savedStores.firstWhere(
                    (t) => t['id'].toString() == itemStoreId,
                    orElse: () => {'name': itemStoreId == 'Casa' ? 'Casa' : 'Supermercado'},
                  );
                  final String nombreTiendaRealItem = tiendaMatch['name'].toString();

                  // Armamos la línea de texto limpia y única para la celda de este registro
                  final String textoOfertaUnica = '• ${item.name}: \$${precioActual.toStringAsFixed(2)} (Ahorras \$${ahorroUnitario.toStringAsFixed(2)})';

                  // 🚀 DISPARO INDEPENDIENTE A LA HOJA DE EXCEL: Cada artículo ganará su propio renglón físico en Google Sheets
                  await ref.read(pantryProvider.notifier).enviarOfertaAlChatSheets(nombreTiendaRealItem, textoOfertaUnica);
                }
              }
              
              // 3. Cierre controlado de ventanas del árbol visual de Flutter
              if (chatDialogContext.mounted) {
                Navigator.pop(chatDialogContext); // Remueve el cuadro de diálogo
              }
              
              navigator.pop(); // Regresa de golpe a la alacena principal con la RAM fresca
            },
            child: const Text('Sí, compartir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],


            ),
          );
        }
      } else {
        // Si no hubo ahorros, sale del carrito directamente a la alacena de forma instantánea
        if (context.mounted) {
          Navigator.pop(context);
        }
      }
    }
  },
  child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
),



                            ],
                          );
                        },
                      );
                    }
                  : null,
              backgroundColor: pantryState.items.any((item) => item.isChecked)
                  ? Colors.blue.shade700
                  : Colors.grey.shade400,
              icon: const Icon(Icons.shopping_bag_rounded, color: Colors.white),
              label: const Text(
                'Finalizar Compra',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
