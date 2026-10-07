import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pantry_provider.dart';
import 'grocery_item.dart';
import 'shopping_cart_screen.dart';
import 'purchase_history_screen.dart';

import 'community_chat_screen.dart';




class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
    bool _hasShowedStoreDialog = false; // 🚀 ADICIÓN: Bandera para que el modal solo se abra una vez al iniciar


 




      @override
  void initState() {
    super.initState();
    // 🚀 RESTAURADO: Escucha activa limpia sin llamadas de red fantasmas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(pantryProvider, (previous, next) {
        if (next.hasValue && next.value != null && !_hasShowedStoreDialog) {
          _hasShowedStoreDialog = true; // Bloquea futuras aperturas accidentales
          _showManageStoresDialog(context, ref);
        }
      });
    });
  }








  // Catálogo maestro ordenado según la secuencia física de la tienda
  final List<String> _categories = [
    'Todos',
    'Frutas y Verduras',
    'Carnes',
    'Lácteos',
    'Abarrotes',
    'Limpieza',
    'General',
    'Manual'
  ];

  // Iconos Visuales Característicos mapeados por pasillo
  final Map<String, String> _categoryIcons = {
    'Frutas y Verduras': '🥑',
    'Carnes': '🥩',
    'Lácteos': '🥛',
    'Abarrotes': '🥫',
    'Limpieza': '🧹',
    'General': '📦',
    'Manual': '✏️',
  };

  /// Formateador numérico integrado para inyectar comas de miles y dos decimales
  String _formatCurrency(double amount) {
    if (amount.isInfinite || amount.isNaN) return '\$0.00';
    String str = amount.toStringAsFixed(2);
    List<String> parts = str.split('.');
    String intPart = parts[0];
    String decimalPart = parts[1];

    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    intPart = intPart.replaceAllMapped(reg, (Match match) => '${match.group(1)},');

    return '\$$intPart.$decimalPart';
  }
  /// Despliega el cuadro interactivo para modificar el presupuesto financiero
  void _showUpdateBudgetDialog(BuildContext context, PantryNotifier notifier, double currentLimit) {
    String initialText = currentLimit.toStringAsFixed(2);
    List<String> initialParts = initialText.split('.');
    String initialInt = initialParts[0];
    RegExp initialReg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    initialInt = initialInt.replaceAllMapped(initialReg, (Match match) => '${match.group(1)},');
    
    final budgetController = TextEditingController(text: '\$$initialInt.${initialParts[1]}');
    final budgetFocusNode = FocusNode();

    budgetFocusNode.addListener(() {
      if (budgetFocusNode.hasFocus) {
        budgetController.clear();
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Definir Presupuesto Límite', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: budgetController,
          focusNode: budgetFocusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            prefixText: '\$ ',
            hintText: 'Ej: 1,500.00',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            if (value.isEmpty) return;
            String clean = value.replaceAll(',', '').replaceAll('\$', '');
            List<String> parts = clean.split('.');
            String intPart = parts[0];
            String decimalPart = parts.length > 1 ? parts[1] : '';
            
            RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
            intPart = intPart.replaceAllMapped(reg, (Match match) => '${match.group(1)},');
            
            String formatted = parts.length > 1 ? '\$$intPart.$decimalPart' : '\$$intPart';
            
            budgetController.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              budgetFocusNode.dispose();
              budgetController.dispose();
              Navigator.pop(context);
            },
            child: const Text(
              'Cancelar', 
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final String cleanText = budgetController.text.replaceAll(',', '').replaceAll('\$', '');
              final double? newLimit = double.tryParse(cleanText);
              if (newLimit != null && newLimit > 0) {
                notifier.updateBudgetLimit(newLimit);
              }
              budgetFocusNode.dispose();
              budgetController.dispose();
              Navigator.of(context).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    // 1. ESCUDO DE CONTROL ASÍNCRONO: Monitorea la carga global de SQLite v5
    final asyncPantry = ref.watch(pantryProvider);
    final pantryNotifier = ref.read(pantryProvider.notifier);

    if (asyncPantry.isLoading || !asyncPantry.hasValue) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('⚡ ChispaHorro     ', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green.shade100,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1))),
      );
    }

    // 2. INYECCIÓN DE SELECTORES REACTIVOS OPTIMIZADOS (Cero lag de renders)
    final double budgetLimit = ref.watch(pantryProvider.select((s) => s.value?.budgetLimit ?? 1500.0));
    final String currentSupermarketId = ref.watch(pantryProvider.select((s) => s.value?.currentSupermarketId ?? 'Casa'));
    final List<Map<String, dynamic>> savedStores = ref.watch(pantryProvider.select((s) => s.value?.savedStores ?? const []));
    final List<GroceryItem> allItems = ref.watch(pantryProvider.select((s) => s.value?.items ?? const []));

    

       // 💵 CONSOLIDACIÓN FINANCIERA REAL: Confronte el precio real de góndola digitado en la tienda 
    // para evitar que el Monto a Pagar se quede congelado por debajo del ticket del cajero.
    final double pendingExpense = allItems
        .where((item) => item.isChecked)
        .fold(0.0, (sum, item) => sum + ((item.realPrice ?? item.estimatedPrice) * item.quantity));


    final bool isOverBudget = pendingExpense > budgetLimit;
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ ChispaHorro     ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.green.shade100,
        centerTitle: true,
             actions: [
        // 📢 El Chat Comunitario toma el lugar principal para incentivar el uso masivo
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
            ),
                       child: IconButton(
              icon: const Icon(Icons.campaign_rounded, color: Colors.orange, size: 24),
              tooltip: 'Ofertas de la Comunidad',
              onPressed: () {
                // 🚀 RESTAURADO: Navegación limpia bajo demanda. La velocidad se resolverá con el esqueleto visual.
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CommunityChatScreen()),
                );
              },
            ),

          ),
        ),
        const SizedBox(width: 8),
        // 💾 El botón del Historial se mantiene fijo a la derecha
        Padding(
          padding: const EdgeInsets.only(right: 20.0, top: 8.0, bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 255, 255),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.storage_rounded, color: Color.fromARGB(255, 61, 5, 244), size: 24),
              tooltip: 'Ver Base de Datos IA',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PurchaseHistoryScreen()),
                );
              },
            ),
          ),
        ),
      ],


      ),
      body: Column(
        children: [
                    // === CABECERA FINANCIERA TRIPLE HOMOGÉNEA (COMPACTADA) ===
          Container(
            width: double.infinity,
            // 🚀 COMPACTADO: Relleno vertical reducido de 12 a 5 para ganar espacio inmediato
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(
                bottom: BorderSide(
                  color: Colors.green.shade200,
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 1. Tarjeta Izquierda: Presupuesto Asignado
                    Expanded(
                      child: InkWell(
                        onTap: () => _showUpdateBudgetDialog(context, pantryNotifier, budgetLimit),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          // 🚀 COMPACTADO: Relleno interno reducido de 8 a 4 vertical
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOverBudget ? Colors.red.shade200 : Colors.black12,
                              width: isOverBudget ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'PRESUPUESTO    ',
                                    style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5),
                                  ),
                                  Icon(Icons.edit, size: 14, color: Colors.blue.shade900),
                                ],
                              ),
                              const SizedBox(height: 1),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatCurrency(budgetLimit),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 2. Tarjeta Derecha: Gasto Estimado Pendiente (Monto a pagar)
                    Expanded(
                      child: Container(
                        // 🚀 COMPACTADO: Relleno interno reducido de 8 a 4 vertical
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isOverBudget ? Colors.red.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'MONTO A PAGAR',
                              style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _formatCurrency(pendingExpense),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isOverBudget ? Colors.red.shade800 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 3. Tarjeta Inferior de Ancho Completo: Dinero Disponible
                Container(
                  width: double.infinity,
                  // 🚀 COMPACTADO: Relleno interno vertical reducido de 8 a 3
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isOverBudget ? Colors.red.shade100 : Colors.white,
                    borderRadius: BorderRadius.circular(8), 
                    border: Border.all(color: isOverBudget ? Colors.red.shade400 : Colors.green.shade300, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        isOverBudget ? '⚠️ DINERO FALTANTE' : '💵 DINERO DISPONIBLE', 
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey.shade800, letterSpacing: 0.5)
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _formatCurrency(budgetLimit - pendingExpense), 
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800, letterSpacing: 0.5)
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

                     // === BLOQUE UNIFICADO DE UBICACIÓN Y ASISTENTE PREDICTIVO (COMPACTADO) ===
          () {
            final int aiSuggestionsCount = allItems.where((item) => item.isAutoInjected && !item.isChecked).length;
            final String currentStore = currentSupermarketId;
            final bool isLocked = ref.watch(pantryProvider.select((s) => s.value?.isEnvironmentLocked ?? false));

            return InkWell(
              onTap: isLocked ? null : () => _showManageStoresDialog(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final tiendaMatch = savedStores.firstWhere(
                        (t) => t['id'].toString() == currentStore,
                        orElse: () => {'name': currentStore},
                      );
                      final nombreMostrar = currentStore == 'Casa' 
                          ? 'Casa' 
                          : (tiendaMatch['name'] ?? currentStore).toString();

                      return Container(
                        width: MediaQuery.of(context).size.width * 1.00,
                        // 🚀 COMPACTADO: Margen vertical reducido de 4.0 a 2.0
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                        // 🚀 COMPACTADO: Relleno interno vertical bajado de 6 a 4
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: currentStore == 'Casa'
                                ? [Colors.blueGrey.shade700, Colors.blueGrey.shade900]
                                : [Colors.green.shade700, Colors.teal.shade900],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8), 
                          boxShadow: [
                            BoxShadow(
                              color: currentStore == 'Casa' ? Colors.black12 : Colors.green.shade200,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // 🚀 COMPACTADO: Icono de ubicación achicado de 20 a 16
                                Icon(
                                  currentStore == 'Casa' ? Icons.home_rounded : Icons.location_on_rounded, 
                                  color: isLocked ? Colors.amber : Colors.white70, 
                                  size: 16
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isLocked ? 'ENTORNO EN COMPRA (CONGELADO):' : 'UBICACIÓN ACTUAL:',
                                      style: const TextStyle(color: Color.fromARGB(179, 228, 228, 221), fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                    Text(
                                      nombreMostrar,
                                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (!isLocked)
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                                child: const Icon(Icons.touch_app_rounded, color: Colors.white, size: 13),
                              )
                            else
                              const Icon(Icons.lock_rounded, color: Colors.amber, size: 12),
                          ],
                        ),
                      );
                    },
                  ),

                  if (aiSuggestionsCount > 0)
                    Container(
                      width: double.infinity,
                      // 🚀 COMPACTADO: Margen vertical reducido de 4 a 1
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
                      // 🚀 COMPACTADO: Relleno interno bajado de 10 a 4 vertical para aplanar el banner
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade600, Colors.deepOrange.shade500],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // 🚀 COMPACTADO: Icono predictivo achicado de 22 a 16
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ASISTENTE PREDICTIVO ACTIVO',
                                  style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                                Text(
                                  'Detectamos $aiSuggestionsCount artículos críticos por agotarse.',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }(),

                   // 🚀 COMPACTADO: Caja de texto de búsqueda optimizada verticalmente de 6.0 a 2.0
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar artículo...',
                // 🚀 COMPACTADO: Icono de la lupa reducido de 28 a 18 píxeles
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                // Relleno interno optimizado para aplanar el campo sin cortar el texto
                contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          _buildCategorySelector(ref, currentSupermarketId),
          // 🚀 COMPACTADO: Espaciador vertical reducido de 8 a 2
          const SizedBox(height: 2),
          Expanded(
            child: () {
              // Filtrado en caliente por texto y pasillo seleccionado
              final filteredItems = allItems.where((item) {
                final bool matchesSearch = item.name.toLowerCase().contains(_searchQuery);
                final bool matchesCategory = _selectedCategory == 'Todos' || item.category == _selectedCategory;
                return matchesSearch && matchesCategory;
              }).toList();

              if (filteredItems.isEmpty) {
                return const Center(
                  child: Text(
                    'No se encontraron artículos.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                );
              }

              final List<String> jacalAisleOrder = [
                'Frutas y Verduras',
                'Carnes',
                'Lácteos',
                'Abarrotes',
                'Limpieza',
                'General',
                'Manual',
              ];
              final pendingItems = filteredItems.where((item) => !item.isChecked).toList();
              pendingItems.sort((a, b) {
                final double depletion = pantryNotifier.getProductDepletionLevel(a);
                final double depletionB = pantryNotifier.getProductDepletionLevel(b);

                final bool isCriticalA = depletion >= 0.8;
                final bool isCriticalB = depletionB >= 0.8;

                if (isCriticalA && !isCriticalB) return -1;
                if (!isCriticalA && isCriticalB) return 1;

                int indexA = jacalAisleOrder.indexOf(a.category);
                int indexB = jacalAisleOrder.indexOf(b.category);
                if (indexA == -1) indexA = 99;
                if (indexB == -1) indexB = 99;

                return indexA.compareTo(indexB);
              });

              final sortedPendingList = List<GroceryItem>.from(pendingItems);

              if (sortedPendingList.isEmpty) {
                return const Center(
                  child: Text(
                    '¡Despensa completa! No hay pendientes.',
                    style: TextStyle(fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 90.0),
                itemCount: sortedPendingList.length,
                itemBuilder: (context, index) {
                  final item = sortedPendingList[index];
                  final double subtotal = item.estimatedPrice * item.quantity;
                  final double depletion = pantryNotifier.getProductDepletionLevel(item);
                  final bool isCritical = depletion >= 0.8;

                  String qtyDisplay = item.quantity.toString();
                  if (qtyDisplay.endsWith('.0')) {
                    qtyDisplay = qtyDisplay.substring(0, qtyDisplay.length - 2);
                  }
                  
                  final String unitDisplay = item.unit.isNotEmpty ? item.unit : 'Pieza';
                  final String labelUnit = item.quantity > 1 && unitDisplay.toLowerCase() == 'pieza' ? 'Piezas' : unitDisplay;
                  
                  return _buildItemTile(item, subtotal, isCritical, depletion, qtyDisplay, labelUnit, pantryNotifier);
                },
              );
            }(),
          ),
          // === INYECCIÓN PREMIUM RESPONSIVA CONMUTABLE ANTI-SOLAPAMIENTO ===
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, 
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerRight,
                        children: <Widget>[
                          ...previousChildren,
                          currentChild ?? const SizedBox.shrink(),
                        ],
                      );
                    },
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      );
                    },

                    child: _selectedCategory == 'Todos'
                        ? SizedBox(
                            key: const ValueKey('btn_carrito_todos'),
                            height: 52,
                            width: MediaQuery.of(context).size.width > 600 ? 340 : 260,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ShoppingCartScreen()),
                                );
                              },
                              icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
                              label: Text(
                                'MI CARRITO (${asyncPantry.value?.items.where((i) => i.isChecked).length ?? 0})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                elevation: 3,
                              ),
                            ),
                          )
                        : SizedBox(
                            key: const ValueKey('btn_agregar_pasillo'),
                            height: 50,
                            width: 50,
                            child: ElevatedButton(
                              onPressed: () => _showAddManualItemDialog(context, pantryNotifier),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                                elevation: 3,
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 24),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🚀 COMPACTADO: Selector horizontal de pasillos aplanado para recuperar espacio útil
  Widget _buildCategorySelector(WidgetRef ref, String pasilloSeleccionadoUI) {
    return Container(
      // Reducido de 8 a 2 vertical para evitar separaciones fantasmas
      margin: const EdgeInsets.symmetric(vertical: 2),
      // Altura reducida drásticamente de 46 a 32 píxeles
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final bool isSelected = _selectedCategory == category;
          final String displayLabel = category == 'Todos' ? category : '$index. $category';
          
          return Padding(
            key: ValueKey('carrusel_aisle_${category}_$index'),
            padding: const EdgeInsets.only(right: 4.0),
            child: ChoiceChip(
              label: Text(
                displayLabel,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                  color: isSelected ? const Color.fromARGB(255, 231, 232, 235) : Colors.black87,
                  fontSize: 11.5, // Reducido de 14 a 11.5
                ),
              ),
              selected: isSelected,
              selectedColor: const Color.fromARGB(255, 4, 122, 14),
              backgroundColor: const Color.fromARGB(255, 176, 179, 176).withValues(alpha: 0.6),
              showCheckmark: false,
               // Relleno de las pastillas compactado de forma estricta
              labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              padding: EdgeInsets.zero,
              avatar: isSelected 
                  ? const Icon(Icons.directions_walk_rounded, color:Color.fromARGB(255, 244, 244, 245), size: 14) 
                  : Icon(Icons.circle, color: const Color.fromARGB(255, 236, 4, 4), size: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: isSelected ? Colors.green.shade700 : Colors.green.shade200, width: 0.8),
              onSelected: (bool selected) {
                if (selected) setState(() => _selectedCategory = category);
              },
            ),
          );
        },
      ),
    );
  }
    /// Construye la tarjeta interactiva de cada artículo con semáforo predictivo ultra-compacto
  Widget _buildItemTile(GroceryItem item, double subtotal, bool isCritical, double depletion, String qtyDisplay, String labelUnit, PantryNotifier notifier) {
    return Card(
      // 🚀 COMPACTADO: Margen vertical reducido de 4 a 2 para ganar el doble de espacio
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      elevation: isCritical ? 3.0 : 1.0,
      shadowColor: Colors.black12,
      color: const Color(0xFFF2F4F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // Curvatura estilizada reducida para combinar con el entorno
        side: BorderSide(
          color: isCritical ? Colors.orange.shade600 : Colors.grey.shade300,
          width: isCritical ? 1.2 : 0.8,
        ),
      ),
      child: Padding(
        // 🚀 COMPACTADO: Padding interno reducido drásticamente de 8.0 vertical a 4.0
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isCritical)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.orange.shade800, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'POR AGOTARSE (${(depletion * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.orange.shade900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],  
                  )
                else
                  const SizedBox.shrink(),
                Transform.scale(
                  scale: 1.1, // 🚀 COMPACTADO: Escala del Checkbox optimizada de 1.5 a 1.1
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: Checkbox(
                      value: item.isChecked,
                      activeColor: Colors.green.shade700,
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                      onChanged: (_) {
                        _showEditOrDeleteDialog(context, notifier, item, forcePriceInput: true);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isCritical ? Colors.orange.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: isCritical ? Colors.orange.shade200 : Colors.green.shade200),
                        ),
                        child: Text(
                          '${qtyDisplay}x $labelUnit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCritical ? Colors.orange.shade900 : Colors.green.shade900,
                            // 🚀 COMPACTADO: Tamaño del multiplicador bajado a 10.5 píxeles
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          // 🚀 COMPACTADO: Nombre del producto reducido de 16 a 13 píxeles
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (item.estimatedPrice > 0)
                  Text(
                    _formatCurrency(subtotal),
                    // 🚀 COMPACTADO: Subtotal de la tarjeta ajustado a 13 píxeles
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.estimatedPrice == 0.0 
                          ? 'Lista: Sin precio definido' 
                          : 'Precio base: ${_formatCurrency(item.estimatedPrice)}',
                      // 🚀 COMPACTADO: Fuente de metadatos reducida a 10.5 píxeles
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    ),
                    if (item.lastPricePaid != null && item.lastPricePaid! > 0.0 && item.lastPricePaid! != item.estimatedPrice) ...[
                      const SizedBox(height: 1),
                      if (item.lastPricePaid! > item.estimatedPrice && item.estimatedPrice > 0)
                        Text(
                          '(¡Ahorras ${_formatCurrency(item.lastPricePaid! - item.estimatedPrice)}!)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

    /// Despliega el cuadro minimalista para armar la lista (Sólo Nombre y Cantidad)
  void _showAddManualItemDialog(BuildContext context, PantryNotifier notifier) {
    // Detectamos la tienda activa en el estado global
    final String currentStoreId = ref.read(pantryProvider).value?.currentSupermarketId ?? 'Casa';

    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1.0');
    final priceController = TextEditingController(); // Nuevo controlador de precio

    final nameFocusNode = FocusNode();
    final qtyFocusNode = FocusNode();
    final priceFocusNode = FocusNode(); // Nuevo nodo de enfoque para el precio


    // Limpieza automática al recibir el foco nativo
    qtyFocusNode.addListener(() {
      if (qtyFocusNode.hasFocus) quantityController.clear();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Añadir a la Lista', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PASILLO: ${_selectedCategory.toUpperCase()}',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.blue.shade800, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            const Text('¿Qué artículo necesitas?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              focusNode: nameFocusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.shopping_basket_rounded),
                hintText: 'Ej: Leche Entera, Servilletas',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
                       const Text('Cantidad:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 6),
            TextField(
              controller: quantityController,
              focusNode: qtyFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            // 🚀 INYECCIÓN CONDICIONAL: Si no es Casa, exige el precio real en góndola
            if (currentStoreId != 'Casa') ...[
              const SizedBox(height: 14),
              const Text('Precio Estimado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 6),
              TextField(
                controller: priceController,
                focusNode: priceFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.attach_money, size: 18),
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ],
          ],
        ),

        actions: [
          TextButton(
            onPressed: () {
              nameFocusNode.dispose();
              qtyFocusNode.dispose();
              nameController.dispose();
              quantityController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          ),
                ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () async {
              final String finalName = nameController.text.trim();
              final double parsedQty = double.tryParse(quantityController.text.trim()) ?? 1.0;
              final double parsedPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
              
              if (finalName.isEmpty) return;

              // 1. Ejecuta la inserción en la base de datos local con el precio capturado
              final String finalCategory = _selectedCategory == 'Todos' ? 'General' : _selectedCategory;
              
              if (currentStoreId == 'Casa') {
                notifier.addManualItem(
                  name: finalName,
                  quantity: parsedQty,
                  category: finalCategory,
                );
              } else {
                // Si es tienda, lo creamos e indicamos al notifier que va directo al carrito con su precio real
                await notifier.addManualItem(
                  name: finalName,
                  quantity: parsedQty,
                  category: finalCategory,
                );
                
                // Buscamos el último artículo agregado para obtener su ID o dejamos que el notifier use su lógica.
                // Como sugerencia para asegurar que vaya al carrito de inmediato si tu backend lo requiere:
                final items = ref.read(pantryProvider).value?.items ?? [];
                if (items.isNotEmpty) {
                  final newItem = items.firstWhere((i) => i.name == finalName && !i.isChecked, orElse: () => items.last);
                  await notifier.moveToCartWithPrice(
                    id: newItem.id,
                    realPrice: parsedPrice,
                    updatedQuantity: parsedQty,
                    updatedName: finalName,
                  );
                }
              }

              // 2. Planifica el movimiento del pasillo en la pantalla principal de forma segura
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedCategory = 'Todos';
                  });
                }
              });

              // Liberación y limpieza de memoria RAM incluyendo los nuevos controladores
              nameFocusNode.dispose();
              qtyFocusNode.dispose();
              priceFocusNode.dispose();
              nameController.dispose();
              quantityController.dispose();
              priceController.dispose();
              
              if (context.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),

        ],
      ),
    );
  }
  /// Abre el panel de modificación o el validador de precio real en góndola
  void _showEditOrDeleteDialog(BuildContext context, PantryNotifier notifier, GroceryItem item, {bool forcePriceInput = false}) {
    final nameController = TextEditingController(text: item.name);
    
    // Si la IA ya recuerda un precio base, lo sugiere; si no, inicia limpio en 0.00
    String initialPriceText = item.estimatedPrice == 0.0 && item.lastPricePaid != null && item.lastPricePaid! > 0.0
        ? item.lastPricePaid!.toStringAsFixed(2)
        : item.estimatedPrice.toStringAsFixed(2);
        
    List<String> priceParts = initialPriceText.split('.');
    String priceInt = priceParts[0];

    RegExp regMiles = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    priceInt = priceInt.replaceAllMapped(regMiles, (Match match) => '${match.group(1)},');
    
    final priceController = TextEditingController(text: '\$$priceInt.${priceParts[1]}');
    final quantityController = TextEditingController(text: item.quantity.toString());
    String selectedCategoryForEdit = _categories.contains(item.category) ? item.category : 'General';

        // Reemplaza el bloque de inicialización de FocusNodes por este:
        final nameFocusNode = FocusNode();
    final priceFocusNode = FocusNode();
    final qtyFocusNode = FocusNode();

    // 🚀 CORREGIDO: Borrado preventivo absoluto y forzado de foco síncrono al abrir desde el Checkbox
    if (forcePriceInput) {
      priceController.text = ''; 
      priceController.value = TextEditingValue.empty;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (priceFocusNode.canRequestFocus) {
            priceFocusNode.requestFocus();
          }
        });
      });
    }





    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    forcePriceInput ? Icons.check_circle_outline_rounded : Icons.edit_note_outlined, 
                    color: forcePriceInput ? Colors.green : Colors.blue
                  ),
                  const SizedBox(width: 8),
                  Text(
                    forcePriceInput ? 'Ingresa El Precio' : 'Modificar Artículo', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. PASILLO / CATEGORÍA
                      const Text('Pasillo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          _showPremiumCategoryPicker(
                            context,
                            selectedCategoryForEdit,
                            (newCategory) {
                              setDialogState(() => selectedCategoryForEdit = newCategory);
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade300, width: 1.2),
                            color: Colors.blue.shade50.withValues(alpha: 0.3),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(_categoryIcons[selectedCategoryForEdit] ?? '📦', style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Text(selectedCategoryForEdit, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                                ],
                              ),
                              const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.blue),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. PRODUCTO / NOMBRE
                      const Text('Producto:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nameController,
                        focusNode: nameFocusNode,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.abc, size: 20),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),

                                           // 3. CANTIDAD REAL EN TIENDA (CON LIMPIEZA ABSOLUTA AL TACTO)
                      const Text('Cantidad:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: quantityController,
                        focusNode: qtyFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        // 🧹 LIMPIEZA TOTAL: Vacía por completo el campo al hacer clic para escribir de inmediato
                        onTap: () {
                          quantityController.clear();
                        },
                      ),

                      const SizedBox(height: 14),

                      // 4. PRECIO DE GÓNDOLA (CON FOCO PRINCIPAL SI SE VA A MANDAR AL CARRITO)
                                            // 4. PRECIO DE GÓNDOLA (CON CORRECCIÓN DE BORRADO ABSOLUTO AL TACTO)
                      const Text('Precio Real de Etiqueta:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: priceController,
                        focusNode: priceFocusNode,
                        autofocus: forcePriceInput, 
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.attach_money, size: 18),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                                                // 🚀 SELECCIÓN COMPLETA SENIOR: Resalta todo el texto al tacto para sobreescribir de inmediato sin juntar cifras
                        onTap: () {
                          if (priceController.text.isNotEmpty) {
                            priceController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: priceController.text.length,
                            );
                          }
                        },

                        onChanged: (value) {
                          // Si el usuario borró todo o está vacío, lo dejamos en blanco para que escriba libremente
                          if (value.isEmpty || value == '\$') {
                            priceController.value = TextEditingValue.empty;
                            return;
                          }
                          
                          String clean = value.replaceAll(',', '').replaceAll('\$', '');
                          List<String> parts = clean.split('.');
                          
                          String intPart = parts[0]; 
                          String decimalPart = parts.length > 1 ? parts[1] : ''; 
                          
                          RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
                          intPart = intPart.replaceAllMapped(reg, (Match match) => '${match.group(1)},');
                          
                          String formatted = parts.length > 1 ? '\$$intPart.$decimalPart' : '\$$intPart';
                          
                          priceController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        },
                      ),

                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                                        TextButton(
                      onPressed: () {
                        // 1. Eliminación física directa en disco y RAM
                        notifier.deleteItem(item.id);
                        
                        // 2. 🚀 CORREGIDO: Primero removemos la ventana visual del árbol
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                        
                        // 3. 🚀 CORREGIDO: Al final destruimos los listeners de la memoria
                        nameFocusNode.dispose();
                        priceFocusNode.dispose();
                        qtyFocusNode.dispose();
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                      child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),

                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                                                    TextButton(
                            onPressed: () {
                              // 1. 🚀 CORREGIDO: Primero removemos la ventana visual de la pantalla
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                              
                              // 2. 🚀 CORREGIDO: Al final liberamos los FocusNodes de la RAM
                              nameFocusNode.dispose();
                              priceFocusNode.dispose();
                              qtyFocusNode.dispose();
                            },
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                            child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),

                          const SizedBox(width: 4),
                                                    ElevatedButton(
                            onPressed: () async {
                              final String cleanPriceText = priceController.text.replaceAll(',', '').replaceAll('\$', '').trim();
                              final String cleanQtyText = quantityController.text.replaceAll(',', '').trim();

                              final double parsedPrice = double.tryParse(cleanPriceText) ?? 0.0;
                              final double parsedQty = double.tryParse(cleanQtyText) ?? 1.0;
                              final String finalName = nameController.text.trim();

                              await notifier.moveToCartWithPrice(
                                id: item.id,
                                realPrice: parsedPrice,
                                updatedQuantity: parsedQty,
                                updatedName: finalName.isEmpty ? 'Artículo Genérico' : finalName,
                              );
                              
                              // Planifica el movimiento del pasillo en el hilo principal de forma reactiva
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _selectedCategory = 'Todos';
                                  });
                                }
                              });

                              // 🚀 CORREGIDO: Primero removemos la interfaz visual del árbol de Flutter
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                              
                              // 🚀 CORREGIDO: Al final destruimos las variables de la RAM de forma segura
                              nameFocusNode.dispose();
                              priceFocusNode.dispose();
                              qtyFocusNode.dispose();
                            },
                            child: const Text('Guardar'),
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
  /// Despliega el panel inferior premium para cambiar la secuencia física del pasillo
  void _showPremiumCategoryPicker(BuildContext context, String currentCategory, Function(String) onSelected) {
    final selectableAisles = _categories.where((c) => c != 'Todos').toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Text('Cambiar de Pasillo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                child: Text('Selecciona la secuencia física de compra', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true, 
                  itemCount: selectableAisles.length,
                  separatorBuilder: (c, i) => const Divider(height: 1, indent: 56),
                  itemBuilder: (context, index) {
                    final aisle = selectableAisles[index];
                    final isCurrent = aisle == currentCategory;
                    final icon = _categoryIcons[aisle] ?? '📦';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrent ? Colors.blue.shade50 : Colors.grey.shade100,
                        child: Text(icon, style: const TextStyle(fontSize: 18)),
                      ),
                      title: Text(
                        aisle,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? Colors.blue.shade800 : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                      trailing: isCurrent ? const Icon(Icons.check_circle_rounded, color: Colors.blue) : null,
                      onTap: () {
                        onSelected(aisle);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  /// Despliega la administración de sucursales con protección inmutable de entorno
  void _showManageStoresDialog(BuildContext context, WidgetRef ref) {
    final stateValue = ref.read(pantryProvider).value;
    if (stateValue == null) return;

    // 🚀 REQUERIMIENTO COMPLETO: Si ya está bloqueado, impide abrir el flujo de selección
    if (stateValue.isEnvironmentLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Entorno congelado. Finaliza la compra actual para cambiar de tienda.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final state = ref.watch(pantryProvider).value;
        
        final tiendaActual = state?.currentSupermarketId ?? 'Casa';
        final TextEditingController storeNameController = TextEditingController();

        return AlertDialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: (MediaQuery.of(context).size.width * 0.18) / 2,
            vertical: 40,
          ),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.teal.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Tus Supermercados',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SELECCIONAR ENTORNO DE COMPRA',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  
                  // Entorno estándar: Casa
                                    // Entorno estándar: Casa
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: tiendaActual == 'Casa' ? Colors.green.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tiendaActual == 'Casa' ? Colors.green.shade300 : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.home_rounded, color: tiendaActual == 'Casa' ? Colors.green : Colors.grey),
                      title: const Text('Casa', style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: tiendaActual == 'Casa' ? const Icon(Icons.check_circle_rounded, color: Colors.green) : null,
                      onTap: () {
                        ref.read(pantryProvider.notifier).setSupermarketManualmente('Casa');
                        Navigator.pop(context); // 🚀 CORREGIDO: Cierra el diálogo de inmediato al seleccionar
                      },
                    ),
                  ),


                                    // Listado dinámico de sucursales registradas (Reactivo y con Tap activo)
                  Consumer(
                    builder: (context, ref, child) {
                      final updatedState = ref.watch(pantryProvider).value;
                      final updatedTiendas = updatedState?.savedStores ?? [];
                      final updatedTiendaActual = updatedState?.currentSupermarketId ?? 'Casa';

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: updatedTiendas.map((tienda) {
                          final id = tienda['id'] as String;
                          final name = tienda['name'] as String;
                          final bool isSelected = updatedTiendaActual == id;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.green.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.green.shade300 : Colors.grey.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: ListTile(
                              leading: isSelected 
                                  ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                                  : Icon(Icons.shopping_bag_rounded, color: Colors.blueGrey.shade400),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: isSelected
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (dialogContext) => AlertDialog(
                                            title: const Text('¿Eliminar supermercado?'),
                                            content: Text('Esta acción quitará a "$name" de tus entornos disponibles.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(dialogContext),
                                                child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  ref.read(pantryProvider.notifier).removeStore(id);
                                                  Navigator.pop(dialogContext);
                                                },
                                                child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                              onTap: () {
                                ref.read(pantryProvider.notifier).setSupermarketManualmente(id);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),


                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'AÑADIR NUEVA SUCURSAL',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: storeNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Ej. Walmart Premium, Costco',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.add_business_rounded, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.green.shade400, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final name = storeNameController.text.trim();
                          if (name.isNotEmpty) {
                            await ref.read(pantryProvider.notifier).registerNewStore(name);
                            storeNameController.clear();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        child: const Icon(Icons.save_rounded, size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        );
      },
    );
  }
}
