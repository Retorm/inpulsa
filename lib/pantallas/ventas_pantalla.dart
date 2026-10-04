import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../utils/formatters.dart';
import 'historial_ventas_pantalla.dart';

class PantallaVentas extends StatefulWidget {
  final Map<String, dynamic> empresaActiva;
  final VoidCallback? onVentaRegistrada;

  const PantallaVentas({
    super.key,
    required this.empresaActiva,
    this.onVentaRegistrada,
  });

  @override
  State<PantallaVentas> createState() => _PantallaVentasState();
}

class _PantallaVentasState extends State<PantallaVentas> {
  // Caché separado por empresa para evitar mezclar productos entre empresas.
  static final Map<int, List<Map<String, dynamic>>> _carritosCachePorEmpresa =
      {};

  // Lista para guardar los carritos en "Alistamiento" (Separados)
  static final List<Map<String, dynamic>> _alistamientos = [];

  List<Map<String, dynamic>> _productosDisponibles = [];
  List<Map<String, dynamic>> _clientesDisponibles = [];
  final List<Map<String, dynamic>> _carrito = [];
  int? _idProductoSeleccionado;
  int? _idClienteSeleccionado;
  final _cantidadController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarInventario();
    _cargarClientes();
    _cargarAlistamientosPersistentes();

    // Restaurar únicamente el carrito de la empresa activa.
    final empresaId = _idEmpresaActiva();
    final carritoGuardado =
        _carritosCachePorEmpresa[empresaId] ?? <Map<String, dynamic>>[];
    _carrito.addAll(
      carritoGuardado.map((item) => Map<String, dynamic>.from(item)),
    );
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  // --- PERSISTENCIA DE ALISTAMIENTOS ---
  Future<void> _guardarAlistamientosPersistentes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String data = jsonEncode(_alistamientos);
      await prefs.setString('alistamientos_guardados', data);
    } catch (e) {
      debugPrint('Error al guardar alistamientos en almacenamiento: $e');
    }
  }

  Future<void> _cargarAlistamientosPersistentes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('alistamientos_guardados');
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(data);
        if (mounted) {
          setState(() {
            _alistamientos.clear();
            _alistamientos.addAll(
              decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar alistamientos guardados: $e');
    }
  }

  int _idEmpresaActiva() {
    return int.tryParse(widget.empresaActiva['id']?.toString() ?? '0') ?? 0;
  }

  bool _productoPerteneceAEmpresa(Map<String, dynamic> producto) {
    final empresaId = _idEmpresaActiva();

    // Admitimos los nombres más comunes de la columna para mayor compatibilidad.
    final productoEmpresaId =
        producto['empresa_id'] ??
        producto['empresaId'] ??
        producto['id_empresa'];

    return productoEmpresaId != null &&
        int.tryParse(productoEmpresaId.toString()) == empresaId;
  }

  bool _clientePerteneceAEmpresa(Map<String, dynamic> cliente) {
    final empresaId = _idEmpresaActiva();

    // Admitimos los nombres más comunes de la columna para mayor compatibilidad.
    final clienteEmpresaId =
        cliente['empresa_id'] ?? cliente['empresaId'] ?? cliente['id_empresa'];

    return clienteEmpresaId != null &&
        int.tryParse(clienteEmpresaId.toString()) == empresaId;
  }

  // Guarda los cambios actuales del carrito SOLO para la empresa activa.
  void _sincronizarCache() {
    _carritosCachePorEmpresa[_idEmpresaActiva()] = _carrito
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _cargarInventario() async {
    final datos = await DatabaseHelper.instance.obtenerProductos();

    // IMPORTANTE:
    // Nunca mostramos en Ventas productos pertenecientes a otra empresa.
    final productosEmpresa = datos.where(_productoPerteneceAEmpresa).toList();

    if (!mounted) return;
    setState(() {
      _productosDisponibles = productosEmpresa;

      // Si el producto seleccionado ya no pertenece a la empresa activa,
      // quitamos la selección para impedir ventas cruzadas.
      if (_idProductoSeleccionado != null &&
          !_productosDisponibles.any(
            (p) =>
                int.tryParse(p['id']?.toString() ?? '') ==
                _idProductoSeleccionado,
          )) {
        _idProductoSeleccionado = null;
      }

      if (_productosDisponibles.isNotEmpty && _idProductoSeleccionado == null) {
        _idProductoSeleccionado = int.tryParse(
          _productosDisponibles.first['id']?.toString() ?? '',
        );
      }
    });
  }

  Future<void> _cargarClientes() async {
    final datos = await DatabaseHelper.instance.obtenerClientes();

    // IMPORTANTE:
    // Nunca mostramos en Ventas clientes pertenecientes a otra empresa.
    final clientesEmpresa = datos.where(_clientePerteneceAEmpresa).toList();

    if (!mounted) return;
    setState(() {
      _clientesDisponibles = clientesEmpresa;

      // Si el cliente seleccionado ya no pertenece a la empresa activa,
      // quitamos la selección para impedir ventas cruzadas.
      if (_idClienteSeleccionado != null &&
          !_clientesDisponibles.any(
            (c) =>
                int.tryParse(c['id']?.toString() ?? '') ==
                _idClienteSeleccionado,
          )) {
        _idClienteSeleccionado = null;
      }
    });
  }

  // --- BUSCADORES ---
  void _buscarCliente() async {
    // La lista ya está filtrada por empresa, pero la volvemos a filtrar aquí
    // como segunda barrera de seguridad antes de abrir el selector.
    final clientesEmpresa = _clientesDisponibles
        .where(_clientePerteneceAEmpresa)
        .toList();

    final seleccionado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SelectorBusqueda(
        titulo: 'Buscar Cliente',
        items: clientesEmpresa,
        campoBusqueda: 'nombre',
      ),
    );

    if (seleccionado != null && _clientePerteneceAEmpresa(seleccionado)) {
      setState(() => _idClienteSeleccionado = seleccionado['id']);
    }
  }

  void _buscarProducto() async {
    // _productosDisponibles ya contiene exclusivamente los productos
    // de la empresa activa.
    final productosEmpresa = _productosDisponibles
        .where(_productoPerteneceAEmpresa)
        .map((p) => Map<String, dynamic>.from(p))
        .toList();

    final seleccionado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SelectorBusqueda(
        titulo: 'Buscar Producto - ${widget.empresaActiva['nombre'] ?? ''}',
        items: productosEmpresa,
        campoBusqueda: 'nombre',
      ),
    );

    if (seleccionado != null && _productoPerteneceAEmpresa(seleccionado)) {
      setState(() {
        _idProductoSeleccionado = int.tryParse(
          seleccionado['id']?.toString() ?? '',
        );
      });
    }
  }

  // --- LÓGICA DE ESCÁNER DE QR PARA VENTAS ---
  Future<void> _escanearYAgregar() async {
    final qrEscaneado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const EscanerQRVentasScreen()),
    );

    if (qrEscaneado != null && mounted) {
      int? idProductoExtraido;

      try {
        final Map<String, dynamic> productoJSON = jsonDecode(qrEscaneado);
        idProductoExtraido = productoJSON['id'];
      } catch (e) {
        idProductoExtraido = int.tryParse(qrEscaneado);
      }

      if (idProductoExtraido != null) {
        _procesarProductoEscaneado(idProductoExtraido);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Código QR no válido')));
      }
    }
  }

  void _procesarProductoEscaneado(int idProducto) {
    final existe = _productosDisponibles.any(
      (p) =>
          int.tryParse(p['id']?.toString() ?? '') == idProducto &&
          _productoPerteneceAEmpresa(p),
    );

    if (existe) {
      setState(() {
        _idProductoSeleccionado = idProducto;
        _cantidadController.text = '1';
      });
      _agregarAlCarrito();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Producto agregado al carrito',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El producto escaneado no está en tu inventario'),
        ),
      );
    }
  }

  void _agregarAlCarrito() {
    if (_idProductoSeleccionado == null ||
        _cantidadController.text.trim().isEmpty) {
      return;
    }

    final prod = _productosDisponibles.firstWhere(
      (p) => int.tryParse(p['id']?.toString() ?? '') == _idProductoSeleccionado,
      orElse: () => {},
    );

    if (prod.isEmpty || !_productoPerteneceAEmpresa(prod)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este producto no pertenece a la empresa seleccionada'),
        ),
      );
      return;
    }

    final cantidadAVender = int.tryParse(_cantidadController.text.trim()) ?? 0;
    final cantidadEnStock =
        int.tryParse(prod['cantidad']?.toString() ?? '0') ?? 0;
    final precioVenta =
        int.tryParse(prod['precio_venta']?.toString() ?? '0') ?? 0;

    if (cantidadAVender <= 0) return;

    if (cantidadEnStock == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto está agotado')),
      );
      return;
    }

    if (cantidadAVender > cantidadEnStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solo hay $cantidadEnStock en inventario')),
      );
      return;
    }

    setState(() {
      _carrito.add({
        'id': int.tryParse(prod['id']?.toString() ?? '') ?? 0,
        'empresa_id': _idEmpresaActiva(),
        'nombre': prod['nombre']?.toString() ?? '',
        'precio': precioVenta,
        'cantidad_vendida': cantidadAVender,
        'cantidad_actual': cantidadEnStock,
        'subtotal': precioVenta * cantidadAVender,
      });
      _sincronizarCache();
      _cantidadController.clear();
    });
  }

  void _vaciarCarrito() {
    if (_carrito.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar Carrito'),
        content: const Text(
          '¿Deseas eliminar todos los productos agregados al carrito?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _carrito.clear();
                _sincronizarCache();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Carrito vaciado')));
            },
            child: const Text('Vaciar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  int _calcularTotal() {
    return _carrito.fold<int>(
      0,
      (suma, item) =>
          suma +
          (num.tryParse(item['subtotal']?.toString() ?? '')?.toInt() ?? 0),
    );
  }

  // --- LÓGICA DE WHATSAPP ---
  void _abrirWhatsApp(String telefono, String mensaje, bool esBusiness) {
    final String mensajeCodificado = Uri.encodeComponent(mensaje);
    final String paquete = esBusiness ? 'com.whatsapp.w4b' : 'com.whatsapp';

    final intent = AndroidIntent(
      action: 'action_view',
      data:
          'https://api.whatsapp.com/send?phone=$telefono&text=$mensajeCodificado',
      package: paquete,
    );

    intent.launch().catchError((e) {
      debugPrint("Error al abrir WhatsApp: $e");
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir WhatsApp. Verifica que esté instalado.',
          ),
        ),
      );
    });
  }

  void _mostrarOpcionesWhatsApp(String telefono, String mensaje) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Enviar recibo al cliente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.chat, color: Colors.green),
                  title: const Text('Enviar por WhatsApp Normal'),
                  onTap: () {
                    Navigator.pop(context);
                    _abrirWhatsApp(telefono, mensaje, false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.store, color: Colors.teal),
                  title: const Text('Enviar por WhatsApp Business'),
                  onTap: () {
                    Navigator.pop(context);
                    _abrirWhatsApp(telefono, mensaje, true);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _finalizarVenta() async {
    if (_carrito.isEmpty) return;

    final total = _calcularTotal();
    int pagadoBD = total;
    int montoWhatsApp = total;

    Map<String, dynamic>? clienteSeleccionado;

    if (_idClienteSeleccionado != null) {
      clienteSeleccionado = _clientesDisponibles.firstWhere(
        (c) => c['id'] == _idClienteSeleccionado,
        orElse: () => {},
      );

      // Segunda validación: nunca registrar una venta con un cliente
      // que pertenezca a otra empresa.
      if (clienteSeleccionado.isEmpty ||
          !_clientePerteneceAEmpresa(clienteSeleccionado)) {
        setState(() => _idClienteSeleccionado = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El cliente seleccionado no pertenece a esta empresa.',
            ),
          ),
        );
        return;
      }

      final resultadoPago = await _mostrarDialogoPago(total);
      if (resultadoPago == null) return;

      pagadoBD = resultadoPago['pagadoBD']!;
      montoWhatsApp = resultadoPago['montoWhatsApp']!;
    }

    try {
      final carritoCopia = List<Map<String, dynamic>>.from(_carrito);

      await DatabaseHelper.instance.registrarVenta(
        total,
        _carrito,
        clienteId: _idClienteSeleccionado,
        pagado: pagadoBD,
        empresaId: widget.empresaActiva['id'] as int,
      );

      if (!mounted) return;

      setState(() {
        _carrito.clear();
        _sincronizarCache();
      });

      await _cargarInventario();
      await _cargarClientes();
      widget.onVentaRegistrada?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venta registrada con éxito')),
      );

      if (clienteSeleccionado != null && clienteSeleccionado.isNotEmpty) {
        String telefono = clienteSeleccionado['telefono']?.toString() ?? '';

        if (telefono.isNotEmpty) {
          String mensajeResumen =
              "*Hola ${clienteSeleccionado['nombre']}*,\nAquí tienes el resumen de tu compra:\n\n";

          for (var item in carritoCopia) {
            int subtotalItem =
                (num.tryParse(item['subtotal']?.toString() ?? '0') ?? 0)
                    .toInt();
            mensajeResumen +=
                "▪ ${item['cantidad_vendida']}x ${item['nombre']} - \$${formatCurrencyCol(subtotalItem)}\n";
          }

          mensajeResumen +=
              "\n*Total a pagar:* \$${formatCurrencyCol(montoWhatsApp)}";
          mensajeResumen += "\n\n¡Gracias por Preferirnos!";

          _mostrarOpcionesWhatsApp(telefono, mensajeResumen);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la venta: $e')),
      );
    }
  }

  Future<Map<String, int>?> _mostrarDialogoPago(int total) async {
    final controller = TextEditingController(text: total.toString());

    return showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Venta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Valor de los productos: \$${formatCurrencyCol(total)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: controller,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total a mostrar en WhatsApp (Ej: + Flete)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '¿El cliente pagó los productos?',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                      ),
                      onPressed: () {
                        final montoWs =
                            int.tryParse(controller.text.trim()) ?? total;
                        Navigator.of(
                          context,
                        ).pop({'pagadoBD': 0, 'montoWhatsApp': montoWs});
                      },
                      child: const Text(
                        'NO PAGÓ',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                      ),
                      onPressed: () {
                        final montoWs =
                            int.tryParse(controller.text.trim()) ?? total;
                        Navigator.of(
                          context,
                        ).pop({'pagadoBD': total, 'montoWhatsApp': montoWs});
                      },
                      child: const Text(
                        'PAGÓ TODO',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancelar Venta'),
            ),
          ],
        );
      },
    );
  }

  // --- FORMULARIO DE CLIENTE ---
  void _mostrarFormularioCliente() {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Registrar Nuevo Cliente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: telefonoController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (Ej: 573001234567)',
                    hintText: 'Incluye código país sin +',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final nombre = nombreController.text.trim();
                      if (nombre.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'El nombre del cliente es obligatorio',
                            ),
                          ),
                        );
                        return;
                      }
                      final id = await DatabaseHelper.instance.insertarCliente({
                        'nombre': nombre,
                        'telefono': telefonoController.text.trim(),
                        'deuda_total': 0,
                        // El cliente nuevo queda asociado a la empresa activa.
                        'empresa_id': _idEmpresaActiva(),
                      });
                      await _cargarClientes();
                      setState(() {
                        _idClienteSeleccionado = id;
                      });
                      if (mounted) {
                        // ignore: use_build_context_synchronously
                        Navigator.of(modalContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cliente guardado exitosamente'),
                          ),
                        );
                      }
                    },
                    child: const Text('Guardar Cliente'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarCalculadora() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext modalContext) {
        String display = '0';
        int? firstValue;
        String? operation;

        void actualizarDisplay(String value) {
          if (display == '0') {
            display = value;
          } else {
            display = '$display$value';
          }
        }

        void ejecutarOperacion() {
          if (operation == null || firstValue == null) return;
          final secondValue = int.tryParse(display) ?? 0;
          int result = firstValue!;
          if (operation == '+') {
            result = result + secondValue;
          } else if (operation == '-') {
            result = result - secondValue;
          } else if (operation == '×') {
            result = result * secondValue;
          } else if (operation == '÷') {
            if (secondValue != 0) {
              result = result ~/ secondValue;
            } else {
              result = 0;
            }
          }
          display = result.toString();
          operation = null;
          firstValue = null;
        }

        return StatefulBuilder(
          builder: (context, setState) {
            Widget button(String label, {Color? color, VoidCallback? onTap}) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color ?? Colors.grey.shade200,
                      foregroundColor: color != null
                          ? Colors.white
                          : Colors.black,
                      padding: const EdgeInsets.all(18),
                    ),
                    onPressed: onTap,
                    child: Text(label, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(display, style: const TextStyle(fontSize: 42)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          button(
                            'C',
                            color: Colors.red.shade400,
                            onTap: () {
                              setState(() {
                                display = '0';
                                firstValue = null;
                                operation = null;
                              });
                            },
                          ),
                          button(
                            '⌫',
                            onTap: () {
                              setState(() {
                                if (display.length > 1) {
                                  display = display.substring(
                                    0,
                                    display.length - 1,
                                  );
                                } else {
                                  display = '0';
                                }
                              });
                            },
                          ),
                          button(
                            '÷',
                            color: Colors.orange,
                            onTap: () {
                              setState(() {
                                firstValue = int.tryParse(display) ?? 0;
                                operation = '÷';
                                display = '0';
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          button(
                            '7',
                            onTap: () => setState(() => actualizarDisplay('7')),
                          ),
                          button(
                            '8',
                            onTap: () => setState(() => actualizarDisplay('8')),
                          ),
                          button(
                            '9',
                            onTap: () => setState(() => actualizarDisplay('9')),
                          ),
                          button(
                            '×',
                            color: Colors.orange,
                            onTap: () {
                              setState(() {
                                firstValue = int.tryParse(display) ?? 0;
                                operation = '×';
                                display = '0';
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          button(
                            '4',
                            onTap: () => setState(() => actualizarDisplay('4')),
                          ),
                          button(
                            '5',
                            onTap: () => setState(() => actualizarDisplay('5')),
                          ),
                          button(
                            '6',
                            onTap: () => setState(() => actualizarDisplay('6')),
                          ),
                          button(
                            '-',
                            color: Colors.orange,
                            onTap: () {
                              setState(() {
                                firstValue = int.tryParse(display) ?? 0;
                                operation = '-';
                                display = '0';
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          button(
                            '1',
                            onTap: () => setState(() => actualizarDisplay('1')),
                          ),
                          button(
                            '2',
                            onTap: () => setState(() => actualizarDisplay('2')),
                          ),
                          button(
                            '3',
                            onTap: () => setState(() => actualizarDisplay('3')),
                          ),
                          button(
                            '+',
                            color: Colors.orange,
                            onTap: () {
                              setState(() {
                                firstValue = int.tryParse(display) ?? 0;
                                operation = '+';
                                display = '0';
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          button(
                            '0',
                            onTap: () => setState(() => actualizarDisplay('0')),
                          ),
                          button(
                            '←',
                            onTap: () => setState(() {
                              if (display.length > 1) {
                                display = display.substring(
                                  0,
                                  display.length - 1,
                                );
                              } else {
                                display = '0';
                              }
                            }),
                          ),
                          button(
                            '=',
                            color: Colors.blue,
                            onTap: () {
                              setState(() {
                                ejecutarOperacion();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(modalContext).pop(),
                          child: const Text('Cerrar calculadora'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _verHistorialVentas() async {
    final int idEmpresa =
        int.tryParse(widget.empresaActiva['id']?.toString() ?? '0') ?? 0;

    // Usamos 'await' para esperar a que el usuario regrese de la pantalla de historial
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistorialVentasPantalla(empresaId: idEmpresa),
      ),
    );

    // Cuando el usuario cierre el historial y regrese a esta pantalla,
    // recargamos el inventario para reflejar los productos que hayan sido devueltos.
    if (mounted) {
      _cargarInventario();
    }
  }

  // --- FUNCIONES DE ALISTAMIENTO CON PERSISTENCIA ---
  Future<void> _guardarEnAlistamiento() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío. Agrega productos primero.'),
        ),
      );
      return;
    }

    final TextEditingController nombreRefController = TextEditingController();

    if (_idClienteSeleccionado != null) {
      final cliente = _clientesDisponibles.firstWhere(
        (c) => c['id'] == _idClienteSeleccionado,
        orElse: () => {},
      );
      if (cliente.isNotEmpty) {
        nombreRefController.text = 'Pedido de ${cliente['nombre']}';
      }
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Separar Pedido (Alistamiento)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Guarda este carrito para confirmarlo o editarlo más tarde.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nombreRefController,
              decoration: const InputDecoration(
                labelText: 'Nombre o Referencia',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final referencia = nombreRefController.text.trim().isEmpty
                  ? 'Alistamiento sin nombre'
                  : nombreRefController.text.trim();

              setState(() {
                _alistamientos.add({
                  'id': DateTime.now().millisecondsSinceEpoch,
                  'referencia': referencia,
                  'cliente_id': _idClienteSeleccionado,
                  'fecha': DateTime.now().toString(),
                  'items': List<Map<String, dynamic>>.from(_carrito),
                });
                _carrito.clear();
                _idClienteSeleccionado = null;
                _sincronizarCache();
              });

              await _guardarAlistamientosPersistentes(); // Guardar en disco local

              if (mounted) {
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Guardado en alistamiento: $referencia'),
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarAlistamientos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Carritos en Alistamiento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  if (_alistamientos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No hay pedidos separados en este momento.'),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: _alistamientos.length,
                      itemBuilder: (context, index) {
                        final alistamiento = _alistamientos[index];
                        final items = alistamiento['items'] as List;
                        final total = items.fold<int>(
                          0,
                          (sum, item) =>
                              sum +
                              (num.tryParse(
                                    item['subtotal']?.toString() ?? '0',
                                  )?.toInt() ??
                                  0),
                        );

                        return ListTile(
                          leading: const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircleAvatar(
                              backgroundColor: Colors.deepOrange,
                              child: Icon(
                                Icons.pause_circle_filled,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          title: Text(
                            alistamiento['referencia'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${items.length} productos | Total: \$${formatCurrencyCol(total)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Restaurar al carrito principal',
                                icon: const Icon(
                                  Icons.restore,
                                  color: Colors.green,
                                ),
                                onPressed: () async {
                                  setState(() {
                                    _carrito.clear();
                                    _carrito.addAll(
                                      List<Map<String, dynamic>>.from(items),
                                    );
                                    _idClienteSeleccionado =
                                        alistamiento['cliente_id'];
                                    _sincronizarCache();
                                    _alistamientos.removeAt(index);
                                  });

                                  await _guardarAlistamientosPersistentes(); // Guardar cambios en disco local

                                  if (mounted) {
                                    // ignore: use_build_context_synchronously
                                    Navigator.pop(modalContext);
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Carrito restaurado. Listo para editar o cobrar.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  setModalState(() {
                                    _alistamientos.removeAt(index);
                                  });
                                  setState(() {});
                                  await _guardarAlistamientosPersistentes(); // Guardar cambios en disco local
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // UI ULTRA PREMIUM — POS MODERNO
  // =========================================================================

  static const _radiusXL = 28.0;
  static const _radiusLG = 22.0;
  Color _primary(BuildContext context) => Theme.of(context).colorScheme.primary;

  Color _surface(BuildContext context) => Theme.of(context).colorScheme.surface;

  Color _muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  BoxShadow _softShadow(BuildContext context, {double opacity = .08}) =>
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 24,
        offset: const Offset(0, 10),
      );

  Widget _glassButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? tint,
    String? badge,
  }) {
    final color = tint ?? _primary(context);

    return Material(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroEmpresa() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final logoPath = widget.empresaActiva['logo_ruta']?.toString() ?? '';
    final nombre =
        widget.empresaActiva['nombre']?.toString().trim().isNotEmpty == true
        ? widget.empresaActiva['nombre'].toString()
        : 'Mi negocio';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radiusXL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, Color.lerp(primary, Colors.black, .18) ?? primary],
        ),
        boxShadow: [_softShadow(context, opacity: .18)],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -35,
            right: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -55,
            right: 70,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: logoPath.isNotEmpty && File(logoPath).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          File(logoPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.storefront_rounded,
                            color: primary,
                            size: 34,
                          ),
                        ),
                      )
                    : Icon(Icons.storefront_rounded, color: primary, size: 34),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Caja abierta · Operación lista',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {String? helper, Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.3,
                ),
              ),
              if (helper != null) ...[
                const SizedBox(height: 3),
                Text(
                  helper,
                  style: TextStyle(
                    fontSize: 11,
                    color: _muted(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _selectionTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    Color? tint,
    Widget? extra,
  }) {
    final theme = Theme.of(context);
    final color = tint ?? theme.colorScheme.primary;

    return Material(
      color: _surface(context),
      borderRadius: BorderRadius.circular(_radiusLG),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radiusLG),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radiusLG),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: .55),
            ),
            boxShadow: [_softShadow(context, opacity: .025)],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: _muted(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (extra != null) ...[const SizedBox(width: 6), extra],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: _muted(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clientePanel(String nombreClienteBoton) {
    return _selectionTile(
      icon: Icons.person_rounded,
      label: 'CLIENTE',
      value: nombreClienteBoton,
      tint: Colors.indigo,
      onTap: _buscarCliente,
      extra: Material(
        color: Colors.indigo.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: _mostrarFormularioCliente,
          borderRadius: BorderRadius.circular(13),
          child: const Padding(
            padding: EdgeInsets.all(9),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              size: 19,
              color: Colors.indigo,
            ),
          ),
        ),
      ),
    );
  }

  Widget _productoComposer(String nombreProductoBoton) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(_radiusXL),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .55)),
        boxShadow: [_softShadow(context, opacity: .025)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _selectionTile(
                  icon: Icons.inventory_2_rounded,
                  label: 'PRODUCTO',
                  value: nombreProductoBoton,
                  tint: primary,
                  onTap: _buscarProducto,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: .12),
                      primary.withValues(alpha: .05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  tooltip: 'Escanear QR / barras',
                  onPressed: _escanearYAgregar,
                  icon: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: primary,
                    size: 25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cantidadController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    hintText: '1',
                    prefixIcon: const Icon(Icons.tag_rounded),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: .50),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _agregarAlCarrito,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Añadir'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 19),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCart() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 42),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(_radiusXL),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .50)),
      ),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withValues(alpha: .14),
                  primary.withValues(alpha: .045),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_checkout_rounded,
              color: primary,
              size: 43,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'Listo para vender',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Selecciona un producto o escanea su código para comenzar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted(context),
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniHint(Icons.search_rounded, 'Buscar'),
              _miniHint(Icons.qr_code_2_rounded, 'Escanear'),
              _miniHint(Icons.add_shopping_cart_rounded, 'Añadir'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniHint(IconData icon, String text) {
    final primary = _primary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartItem(Map<String, dynamic> item, int index) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final cantidad =
        int.tryParse(item['cantidad_vendida']?.toString() ?? '0') ?? 0;
    final precio = int.tryParse(item['precio']?.toString() ?? '0') ?? 0;
    final subtotal = int.tryParse(item['subtotal']?.toString() ?? '0') ?? 0;
    final nombre = item['nombre']?.toString() ?? 'Producto';

    return Dismissible(
      key: ValueKey('${item['id']}_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        setState(() {
          _carrito.removeAt(index);
          _sincronizarCache();
        });
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(_radiusLG),
        ),
        child: Icon(
          Icons.delete_forever_rounded,
          color: theme.colorScheme.error,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(_radiusLG),
          border: Border.all(color: theme.dividerColor.withValues(alpha: .45)),
          boxShadow: [_softShadow(context, opacity: .025)],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: .13),
                    primary.withValues(alpha: .045),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.shopping_bag_rounded, color: primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _infoPill('$cantidad uds'),
                      const SizedBox(width: 7),
                      Text(
                        '\$${formatCurrencyCol(precio)} c/u',
                        style: TextStyle(
                          color: _muted(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${formatCurrencyCol(subtotal)}',
                  style: TextStyle(
                    color: primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                InkWell(
                  onTap: () {
                    setState(() {
                      _carrito.removeAt(index);
                      _sincronizarCache();
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(String text) {
    final primary = _primary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _cartHeader() {
    final count = _carrito.length;

    return _sectionTitle(
      'Pedido actual',
      helper: count == 0
          ? 'Aún no has añadido productos'
          : '$count ${count == 1 ? 'línea' : 'líneas'} · desliza un producto para eliminarlo',
      trailing: count > 0
          ? _infoPill('\$${formatCurrencyCol(_calcularTotal())}')
          : null,
    );
  }

  Widget _bottomCheckout() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final total = _calcularTotal();
    final disabled = _carrito.isEmpty;

    return Material(
      elevation: 18,
      color: _surface(context),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.dividerColor.withValues(alpha: .55)),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final narrow = box.maxWidth < 520;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL',
                              style: TextStyle(
                                color: _muted(context),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '\$${formatCurrencyCol(total)}',
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: disabled ? null : _finalizarVenta,
                          icon: const Icon(Icons.payments_rounded),
                          label: const Text(
                            'Cobrar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: Size(narrow ? 145 : 165, 58),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: disabled ? null : _vaciarCarrito,
                          icon: const Icon(Icons.delete_sweep_rounded),
                          label: const Text('Vaciar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            minimumSize: const Size.fromHeight(43),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: disabled ? null : _guardarEnAlistamiento,
                          icon: const Icon(Icons.pause_circle_outline_rounded),
                          label: const Text('Separar pedido'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            minimumSize: const Size.fromHeight(43),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String nombreClienteBoton = 'Seleccionar cliente';
    if (_idClienteSeleccionado != null) {
      final encontrado = _clientesDisponibles.firstWhere(
        (c) => c['id'] == _idClienteSeleccionado,
        orElse: () => {},
      );
      if (encontrado.isNotEmpty) {
        nombreClienteBoton = encontrado['nombre']?.toString() ?? 'Cliente';
      }
    }

    String nombreProductoBoton = 'Buscar un producto';
    if (_idProductoSeleccionado != null) {
      final encontradoP = _productosDisponibles.firstWhere(
        (p) => p['id'] == _idProductoSeleccionado,
        orElse: () => {},
      );
      if (encontradoP.isNotEmpty) {
        final stock = encontradoP['cantidad'] ?? 0;
        nombreProductoBoton = '${encontradoP['nombre']} · Stock $stock';
      }
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 18,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nueva venta',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.3),
            ),
            Text(
              'Punto de venta',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          _glassButton(
            icon: Icons.inventory_2_rounded,
            label: 'Pedidos',
            badge: _alistamientos.isEmpty ? null : '${_alistamientos.length}',
            tint: Colors.orange.shade800,
            onTap: _mostrarAlistamientos,
          ),
          const SizedBox(width: 7),
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              tooltip: 'Historial de ventas',
              onPressed: _verHistorialVentas,
              icon: const Icon(Icons.receipt_long_rounded, size: 21),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarCalculadora,
        elevation: 7,
        icon: const Icon(Icons.calculate_rounded),
        label: const Text(
          'Calculadora',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: _bottomCheckout(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final padding = wide ? 30.0 : 15.0;

          Widget content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heroEmpresa(),
              const SizedBox(height: 18),
              _sectionTitle(
                'Cliente',
                helper:
                    'Asocia la venta con una persona o continúa sin cliente.',
              ),
              const SizedBox(height: 9),
              _clientePanel(nombreClienteBoton),
              const SizedBox(height: 19),
              _sectionTitle(
                'Añadir productos',
                helper: 'Busca por nombre o utiliza el escáner.',
              ),
              const SizedBox(height: 9),
              _productoComposer(nombreProductoBoton),
              const SizedBox(height: 22),
              _cartHeader(),
              const SizedBox(height: 10),
              if (_carrito.isEmpty)
                _emptyCart()
              else
                ...List.generate(
                  _carrito.length,
                  (index) => _cartItem(_carrito[index], index),
                ),
              const SizedBox(height: 100),
            ],
          );

          if (wide) {
            content = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: content,
              ),
            );
          }

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, .32, 1],
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: .035),
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(padding, 12, padding, 0),
              child: content,
            ),
          );
        },
      ),
    );
  }
}

// =========================================================================
// WIDGET DE BÚSQUEDA Y SELECCIÓN (CLIENTES Y PRODUCTOS)
// =========================================================================
class _SelectorBusqueda extends StatefulWidget {
  final String titulo;
  final List<Map<String, dynamic>> items;
  final String campoBusqueda;

  const _SelectorBusqueda({
    required this.titulo,
    required this.items,
    required this.campoBusqueda,
  });

  @override
  State<_SelectorBusqueda> createState() => _SelectorBusquedaState();
}

class _SelectorBusquedaState extends State<_SelectorBusqueda> {
  late List<Map<String, dynamic>> _filtrados;
  final _busquedaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtrados = List.from(widget.items);
  }

  void _filtrar(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filtrados = List.from(widget.items);
      } else {
        _filtrados = widget.items.where((item) {
          final valor =
              item[widget.campoBusqueda]?.toString().toLowerCase() ?? '';
          return valor.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              widget.campoBusqueda == 'nombre'
                  ? Icons.search_rounded
                  : Icons.manage_search_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.titulo,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * .55,
        child: Column(
          children: [
            TextField(
              controller: _busquedaController,
              autofocus: true,
              onChanged: _filtrar,
              decoration: InputDecoration(
                hintText: 'Escribe para buscar...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: .5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 44,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No se encontraron resultados',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _filtrados[index];
                        final String nombre =
                            item[widget.campoBusqueda]?.toString() ?? '';

                        String subtitulo = '';
                        if (widget.campoBusqueda == 'nombre' &&
                            item.containsKey('cantidad')) {
                          final cantidad = item['cantidad'] ?? 0;
                          final precio =
                              int.tryParse(
                                item['precio_venta']?.toString() ?? '0',
                              ) ??
                              0;
                          subtitulo =
                              'Stock: $cantidad  ·  \$${formatCurrencyCol(precio)}';
                        } else if (item.containsKey('telefono') &&
                            item['telefono'].toString().isNotEmpty) {
                          subtitulo = 'Tel: ${item['telefono']}';
                        }

                        return Material(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: () => Navigator.pop(context, item),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.dividerColor.withValues(
                                    alpha: .45,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: .08),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      item.containsKey('cantidad')
                                          ? Icons.inventory_2_rounded
                                          : Icons.person_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (subtitulo.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            subtitulo,
                                            style: TextStyle(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// =========================================================================
// PANTALLA DE ESCÁNER DE CÓDIGO QR / BARRAS
// =========================================================================
class EscanerQRVentasScreen extends StatefulWidget {
  const EscanerQRVentasScreen({super.key});

  @override
  State<EscanerQRVentasScreen> createState() => _EscanerQRVentasScreenState();
}

class _EscanerQRVentasScreenState extends State<EscanerQRVentasScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _escaneado = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Escanear producto',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Cambiar cámara',
            icon: const Icon(Icons.flip_camera_android_rounded),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_escaneado) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  _escaneado = true;
                  cameraController.stop();
                  Navigator.pop(context, code);
                  break;
                }
              }
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 270,
                height: 270,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2.2),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .4),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Centra el código dentro del marco para agregar el producto.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
}
