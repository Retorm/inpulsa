import 'dart:convert';
import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:flutter/src/foundation/change_notifier.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../db/database_helper.dart';
import '../utils/formatters.dart';

class PantallaAlmacen extends StatefulWidget {
  final Map<String, dynamic> empresaActiva;

  const PantallaAlmacen({super.key, required this.empresaActiva});

  @override
  State<PantallaAlmacen> createState() => _PantallaAlmacenState();
}

class _PantallaAlmacenState extends State<PantallaAlmacen> {
  List<Map<String, dynamic>> _productos = [];

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _precioCompraController = TextEditingController();
  final _precioVentaController = TextEditingController();
  final _searchController = TextEditingController();

  String _searchQuery = '';
  bool _cargando = false;

  // Filtro de inventario:
  // todos | mucho | bajo | agotado
  String _filtroStock = 'todos';

  @override
  void initState() {
    super.initState();

    _cargarProductos();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _cantidadController.dispose();
    _precioCompraController.dispose();
    _precioVentaController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  int? _obtenerEmpresaId() {
    final valor = widget.empresaActiva['id'];

    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    return int.tryParse(valor?.toString() ?? '');
  }

  int _obtenerEnteroPrecio(dynamic valor) {
    if (valor is num) {
      return valor.toInt();
    }

    if (valor is String) {
      return parseCurrencyInputToInteger(valor);
    }

    return 0;
  }

  Future<void> _cargarProductos() async {
    if (_cargando || !mounted) return;

    setState(() {
      _cargando = true;
    });

    try {
      final empresaId = _obtenerEmpresaId();

      if (empresaId == null) {
        if (mounted) {
          setState(() {
            _productos = [];
          });
        }

        return;
      }

      final datos = await DatabaseHelper.instance.obtenerProductos(
        empresaId: empresaId,
      );

      if (!mounted) return;

      setState(() {
        _productos = datos;
      });
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('Error cargando productos: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QR
  // ============================================================

  Future<void> _mostrarQR(Map<String, dynamic> producto) async {
    final datosJSON = jsonEncode({
      'id': producto['id'],
      'nombre': producto['nombre'],
      'descripcion': producto['descripcion'] ?? '',
      'precio_venta': producto['precio_venta'],
    });

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.indigo,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  producto['nombre']?.toString() ?? 'Producto',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(data: datosJSON, size: 210),
                ),

                const SizedBox(height: 14),

                Text(
                  'Escanea este código para consultar el producto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirEscaner() async {
    final qrEscaneado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const EscanerQRScreen()),
    );

    if (qrEscaneado == null || !mounted) {
      return;
    }

    try {
      final datos = jsonDecode(qrEscaneado);

      if (datos is Map<String, dynamic>) {
        await _mostrarInfoProductoEscaneado(datos);
      }
    } catch (_) {
      _mostrarMensaje(
        'El código QR no contiene información válida.',
        error: true,
      );
    }
  }

  Future<void> _mostrarInfoProductoEscaneado(
    Map<String, dynamic> producto,
  ) async {
    if (!mounted) return;

    final nombre = producto['nombre']?.toString() ?? 'Sin nombre';

    final precio = _obtenerEnteroPrecio(producto['precio_venta']);

    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.indigo,
                    size: 38,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Producto encontrado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _filaInfoQR(
                        Icons.inventory_2_outlined,
                        'Producto',
                        nombre,
                      ),
                      const SizedBox(height: 12),
                      _filaInfoQR(
                        Icons.sell_outlined,
                        'Precio',
                        '\$${formatCurrencyCol(precio)}',
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filaInfoQR(
    IconData icon,
    String titulo,
    String valor, {
    Color color = Colors.indigo,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GUARDAR PRODUCTO
  // ============================================================

  void _limpiarFormulario() {
    _nombreController.clear();
    _descripcionController.clear();
    _cantidadController.clear();
    _precioCompraController.clear();
    _precioVentaController.clear();
  }

  // ============================================================
  // CAMPOS
  // ============================================================

  Widget _crearCampo(
    TextEditingController controller,
    String label, {
    bool isNum = false,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EDITAR PRODUCTO
  // ============================================================

  Future<void> _editarProducto(Map<String, dynamic> producto) async {
    final idProducto = int.tryParse(producto['id']?.toString() ?? '');

    final empresaId = _obtenerEmpresaId();

    if (idProducto == null || empresaId == null) {
      _mostrarMensaje('Producto o empresa no válidos.', error: true);
      return;
    }

    final nCtrl = TextEditingController(
      text: producto['nombre']?.toString() ?? '',
    );

    final dCtrl = TextEditingController(
      text: producto['descripcion']?.toString() ?? '',
    );

    final cCtrl = TextEditingController(
      text: producto['cantidad']?.toString() ?? '0',
    );

    final pcCtrl = TextEditingController(
      text: formatCurrencyCol(_obtenerEnteroPrecio(producto['precio_compra'])),
    );

    final pvCtrl = TextEditingController(
      text: formatCurrencyCol(_obtenerEnteroPrecio(producto['precio_venta'])),
    );

    try {
      final resultado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Editar producto',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Actualiza la información',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _crearCampo(
                      nCtrl,
                      'Nombre',
                      icon: Icons.inventory_2_outlined,
                    ),

                    _crearCampo(
                      dCtrl,
                      'Descripción',
                      icon: Icons.description_outlined,
                    ),

                    _crearCampo(
                      cCtrl,
                      'Cantidad',
                      isNum: true,
                      icon: Icons.numbers_rounded,
                    ),

                    _crearCampo(
                      pcCtrl,
                      'Precio de compra',
                      isNum: true,
                      icon: Icons.shopping_cart_outlined,
                    ),

                    _crearCampo(
                      pvCtrl,
                      'Precio de venta',
                      isNum: true,
                      icon: Icons.sell_outlined,
                    ),

                    const SizedBox(height: 2),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _mostrarQR(producto),
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Generar código QR'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Guardar'),
                            onPressed: () {
                              final nombre = nCtrl.text.trim();

                              final cantidad = int.tryParse(cCtrl.text.trim());

                              if (nombre.isEmpty ||
                                  cantidad == null ||
                                  cantidad < 0) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Verifica nombre y cantidad.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.of(dialogContext).pop(true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (resultado != true || !mounted) return;

      final datos = {
        'nombre': nCtrl.text.trim(),
        'descripcion': dCtrl.text.trim(),
        'cantidad': int.tryParse(cCtrl.text.trim()) ?? 0,
        'precio_compra': parseCurrencyInputToInteger(pcCtrl.text),
        'precio_venta': parseCurrencyInputToInteger(pvCtrl.text),
        'ruta_foto': '',
        'empresa_id': empresaId,
      };

      await DatabaseHelper.instance.actualizarProducto(
        idProducto,
        datos,
        empresaId: empresaId,
      );

      if (!mounted) return;

      await _cargarProductos();

      if (!mounted) return;

      _mostrarMensaje('Producto actualizado correctamente.');
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('Error actualizando: $e', error: true);
    } finally {
      nCtrl.dispose();
      dCtrl.dispose();
      cCtrl.dispose();
      pcCtrl.dispose();
      pvCtrl.dispose();
    }
  }

  // ============================================================
  // ELIMINAR
  // ============================================================

  Future<void> _eliminarProducto(Map<String, dynamic> producto) async {
    final idProducto = int.tryParse(producto['id']?.toString() ?? '');

    final empresaId = _obtenerEmpresaId();

    final nombre = producto['nombre']?.toString() ?? 'este producto';

    if (idProducto == null || empresaId == null) {
      _mostrarMensaje('Producto o empresa no válidos.', error: true);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 34,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Eliminar producto',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                Text(
                  '¿Seguro que deseas eliminar "$nombre"?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Esta acción no se puede deshacer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancelar'),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        icon: const Icon(Icons.delete_rounded),
                        label: const Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    try {
      await DatabaseHelper.instance.eliminarProducto(
        idProducto,
        empresaId: empresaId,
      );

      if (!mounted) return;

      await _cargarProductos();

      if (!mounted) return;

      _mostrarMensaje('Producto "$nombre" eliminado correctamente.');
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('Error eliminando producto: $e', error: true);
    }
  }

  // ============================================================
  // OPCIONES PARA AGREGAR
  // ============================================================

  Future<void> _mostrarFormularioOpciones() async {
    _limpiarFormulario();

    final opcion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (dialogContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Agregar al inventario',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 18),

                _opcionAgregar(
                  context: dialogContext,
                  icon: Icons.add_box_rounded,
                  color: Colors.indigo,
                  titulo: 'Nuevo producto',
                  descripcion: 'Agregar un producto manualmente',
                  valor: 'manual',
                ),

                _opcionAgregar(
                  context: dialogContext,
                  icon: Icons.playlist_add_rounded,
                  color: Colors.blue,
                  titulo: 'Ingreso múltiple',
                  descripcion: 'Registrar varios productos de una vez',
                  valor: 'multiple',
                ),

                _opcionAgregar(
                  context: dialogContext,
                  icon: Icons.local_shipping_rounded,
                  color: Colors.orange,
                  titulo: 'Reabastecer stock',
                  descripcion: 'Aumentar la cantidad de un producto',
                  valor: 'reabastecer',
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || opcion == null) return;

    switch (opcion) {
      case 'manual':
        await _mostrarFormularioManual();
        break;

      case 'multiple':
        await _abrirIngresoMultiple();
        break;

      case 'reabastecer':
        await _mostrarComprarProveedor();
        break;
    }
  }

  Widget _opcionAgregar({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String titulo,
    required String descripcion,
    required String valor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => Navigator.pop(context, valor),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        descripcion,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INGRESO MULTIPLE
  // ============================================================

  Future<void> _abrirIngresoMultiple() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            IngresoMultipleScreen(empresaActiva: widget.empresaActiva),
      ),
    );

    if (result == true && mounted) {
      await _cargarProductos();

      if (!mounted) return;

      _mostrarMensaje('Lote guardado correctamente.');
    }
  }

  Future<void> _mostrarFormularioManual() async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.indigo,
                        ),
                      ),

                      const SizedBox(width: 12),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nuevo producto',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Añade un producto al inventario',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _crearCampo(
                    _nombreController,
                    'Nombre',
                    icon: Icons.inventory_2_outlined,
                  ),

                  _crearCampo(
                    _descripcionController,
                    'Descripción',
                    icon: Icons.description_outlined,
                  ),

                  _crearCampo(
                    _cantidadController,
                    'Cantidad',
                    isNum: true,
                    icon: Icons.numbers_rounded,
                  ),

                  _crearCampo(
                    _precioCompraController,
                    'Precio de compra',
                    isNum: true,
                    icon: Icons.shopping_cart_outlined,
                  ),

                  _crearCampo(
                    _precioVentaController,
                    'Precio de venta',
                    isNum: true,
                    icon: Icons.sell_outlined,
                  ),

                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.speed_rounded,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Las fotos están desactivadas para mantener la aplicación rápida.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar'),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Guardar'),
                          onPressed: () {
                            final nombre = _nombreController.text.trim();

                            final cantidad = int.tryParse(
                              _cantidadController.text.trim(),
                            );

                            if (nombre.isEmpty ||
                                cantidad == null ||
                                cantidad <= 0) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Nombre y cantidad son obligatorios.',
                                  ),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(dialogContext, true);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (resultado != true || !mounted) return;

    final empresaId = _obtenerEmpresaId();

    if (empresaId == null) {
      _mostrarMensaje('No hay una empresa activa válida.', error: true);
      return;
    }

    try {
      await DatabaseHelper.instance.insertarProducto({
        'empresa_id': empresaId,
        'nombre': _nombreController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'cantidad': int.tryParse(_cantidadController.text.trim()) ?? 0,
        'precio_compra': parseCurrencyInputToInteger(
          _precioCompraController.text,
        ),
        'precio_venta': parseCurrencyInputToInteger(
          _precioVentaController.text,
        ),
        'ruta_foto': '',
      });

      _limpiarFormulario();

      await _cargarProductos();

      if (!mounted) return;

      _mostrarMensaje('Producto guardado correctamente.');
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('Error guardando producto: $e', error: true);
    }
  }

  // ============================================================
  // REABASTECER
  // ============================================================

  Future<void> _mostrarComprarProveedor() async {
    if (_productos.isEmpty) {
      _mostrarMensaje('No hay productos para reabastecer.', error: true);
      return;
    }

    int? prodId = int.tryParse(_productos.first['id']?.toString() ?? '');

    final cantCtrl = TextEditingController();

    final pcCtrl = TextEditingController(
      text: formatCurrencyCol(
        _obtenerEnteroPrecio(_productos.first['precio_compra']),
      ),
    );

    try {
      final resultado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (innerContext, setDialogState) {
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.local_shipping_rounded,
                                color: Colors.orange,
                              ),
                            ),

                            const SizedBox(width: 12),

                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reabastecer stock',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Aumenta la cantidad disponible',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        DropdownButtonFormField<int>(
                          initialValue: prodId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Producto',
                            prefixIcon: const Icon(Icons.inventory_2_outlined),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          items: _productos
                              .map((p) {
                                final id = int.tryParse(
                                  p['id']?.toString() ?? '',
                                );

                                if (id == null) {
                                  return null;
                                }

                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(
                                    p['nombre']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              })
                              .whereType<DropdownMenuItem<int>>()
                              .toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              prodId = val;

                              if (val != null) {
                                final p = _productos.firstWhere(
                                  (e) =>
                                      int.tryParse(e['id']?.toString() ?? '') ==
                                      val,
                                );

                                pcCtrl.text = formatCurrencyCol(
                                  _obtenerEnteroPrecio(p['precio_compra']),
                                );
                              }
                            });
                          },
                        ),

                        const SizedBox(height: 13),

                        _crearCampo(
                          cantCtrl,
                          'Cantidad a sumar',
                          isNum: true,
                          icon: Icons.add_box_outlined,
                        ),

                        _crearCampo(
                          pcCtrl,
                          'Precio de compra',
                          isNum: true,
                          icon: Icons.shopping_cart_outlined,
                        ),

                        const SizedBox(height: 3),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Cancelar'),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.add_box_rounded),
                                label: const Text('Registrar'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                onPressed: () {
                                  final sumar =
                                      int.tryParse(cantCtrl.text.trim()) ?? 0;

                                  if (sumar <= 0 || prodId == null) {
                                    ScaffoldMessenger.of(
                                      dialogContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Indica una cantidad válida.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.pop(dialogContext, true);
                                },
                              ),
                            ),
                          ],
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

      if (resultado != true || !mounted) return;

      final empresaId = _obtenerEmpresaId();

      if (empresaId == null || prodId == null) {
        throw Exception('No hay una empresa o producto válido.');
      }

      final p = _productos.firstWhere(
        (e) => int.tryParse(e['id']?.toString() ?? '') == prodId,
      );

      final stock = int.tryParse(p['cantidad']?.toString() ?? '0') ?? 0;

      final sumar = int.tryParse(cantCtrl.text.trim()) ?? 0;

      await DatabaseHelper.instance.actualizarProducto(prodId!, {
        'nombre': p['nombre']?.toString() ?? '',
        'descripcion': p['descripcion']?.toString() ?? '',
        'cantidad': stock + sumar,
        'precio_compra': parseCurrencyInputToInteger(pcCtrl.text),
        'precio_venta': _obtenerEnteroPrecio(p['precio_venta']),
        'ruta_foto': '',
        'empresa_id': empresaId,
      }, empresaId: empresaId);

      await _cargarProductos();

      if (!mounted) return;

      _mostrarMensaje('Stock reabastecido correctamente.');
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('Error reabasteciendo: $e', error: true);
    } finally {
      cantCtrl.dispose();
      pcCtrl.dispose();
    }
  }

  // ============================================================
  // ESTADO DEL PRODUCTO
  // ============================================================

  Color _colorStock(int cantidad) {
    if (cantidad <= 0) {
      return Colors.red;
    }

    if (cantidad <= 5) {
      return Colors.orange;
    }

    return Colors.green;
  }

  String _textoStock(int cantidad) {
    if (cantidad <= 0) {
      return 'AGOTADO';
    }

    if (cantidad <= 5) {
      return 'STOCK BAJO';
    }

    return 'DISPONIBLE';
  }

  Widget _iconoProducto(Map<String, dynamic> producto) {
    final cantidad = int.tryParse(producto['cantidad']?.toString() ?? '0') ?? 0;

    final color = _colorStock(cantidad);

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(Icons.inventory_2_rounded, color: color, size: 28),
    );
  }

  // ============================================================
  // TARJETA DE PRODUCTO
  // ============================================================

  Widget _tarjetaProducto(Map<String, dynamic> producto) {
    final cantidad = int.tryParse(producto['cantidad']?.toString() ?? '0') ?? 0;

    final precio = _obtenerEnteroPrecio(producto['precio_venta']);

    final color = _colorStock(cantidad);

    final nombre = producto['nombre']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _editarProducto(producto),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _iconoProducto(producto),

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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 15,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$cantidad unidades',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: color,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '\$${formatCurrencyCol(precio)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _textoStock(cantidad),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _editarProducto(producto),
                    icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
                  ),

                  IconButton(
                    tooltip: 'Eliminar',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _eliminarProducto(producto),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESUMEN
  // ============================================================

  Widget _resumenInventario() {
    int unidades = 0;
    int bajos = 0;
    int agotados = 0;

    for (final producto in _productos) {
      final cantidad =
          int.tryParse(producto['cantidad']?.toString() ?? '0') ?? 0;

      unidades += cantidad;

      if (cantidad <= 0) {
        agotados++;
      } else if (cantidad <= 5) {
        bajos++;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del inventario',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _datoResumen(
                  icon: Icons.inventory_2_rounded,
                  valor: '${_productos.length}',
                  texto: 'Productos',
                ),
              ),
              Expanded(
                child: _datoResumen(
                  icon: Icons.layers_rounded,
                  valor: '$unidades',
                  texto: 'Unidades',
                ),
              ),
              Expanded(
                child: _datoResumen(
                  icon: Icons.warning_amber_rounded,
                  valor: '$bajos',
                  texto: 'Stock bajo',
                ),
              ),
              Expanded(
                child: _datoResumen(
                  icon: Icons.remove_shopping_cart_outlined,
                  valor: '$agotados',
                  texto: 'Agotados',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datoResumen({
    required IconData icon,
    required String valor,
    required String texto,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 21),
        const SizedBox(height: 5),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  // ============================================================
  // FILTRO DE STOCK
  // ============================================================

  int _cantidadProducto(Map<String, dynamic> producto) {
    return int.tryParse(producto['cantidad']?.toString() ?? '0') ?? 0;
  }

  bool _cumpleFiltroStock(Map<String, dynamic> producto) {
    final cantidad = _cantidadProducto(producto);

    switch (_filtroStock) {
      case 'mucho':
        return cantidad > 5;
      case 'bajo':
        return cantidad > 0 && cantidad <= 5;
      case 'agotado':
        return cantidad <= 0;
      case 'todos':
      default:
        return true;
    }
  }

  int _contarStock(String filtro) {
    return _productos.where((producto) {
      final cantidad = _cantidadProducto(producto);

      switch (filtro) {
        case 'mucho':
          return cantidad > 5;
        case 'bajo':
          return cantidad > 0 && cantidad <= 5;
        case 'agotado':
          return cantidad <= 0;
        default:
          return true;
      }
    }).length;
  }

  Widget _filtroStockChip({
    required String valor,
    required String titulo,
    required IconData icon,
    required Color color,
  }) {
    final seleccionado = _filtroStock == valor;
    final cantidad = _contarStock(valor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!mounted) return;

          setState(() {
            _filtroStock = valor;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado ? color.withValues(alpha: 0.13) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: seleccionado
                  ? color.withValues(alpha: 0.55)
                  : Colors.grey.shade200,
              width: seleccionado ? 1.4 : 1,
            ),
            boxShadow: seleccionado
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: seleccionado ? color : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: TextStyle(
                  color: seleccionado ? color : Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: seleccionado
                      ? color.withValues(alpha: 0.16)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$cantidad',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: seleccionado ? color : Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtrosStock() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _filtroStockChip(
            valor: 'todos',
            titulo: 'Todos',
            icon: Icons.inventory_2_rounded,
            color: Colors.indigo,
          ),
          const SizedBox(width: 8),
          _filtroStockChip(
            valor: 'mucho',
            titulo: 'Mucho inventario',
            icon: Icons.check_circle_rounded,
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          _filtroStockChip(
            valor: 'bajo',
            titulo: 'Stock bajo',
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
          ),
          const SizedBox(width: 8),
          _filtroStockChip(
            valor: 'agotado',
            titulo: 'Sin stock',
            icon: Icons.remove_shopping_cart_rounded,
            color: Colors.red,
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filtrados = _productos.where((p) {
      final nombre = p['nombre']?.toString().toLowerCase() ?? '';
      final descripcion = p['descripcion']?.toString().toLowerCase() ?? '';

      final coincideBusqueda =
          nombre.contains(_searchQuery) || descripcion.contains(_searchQuery);

      return coincideBusqueda && _cumpleFiltroStock(p);
    }).toList();

    final empresa = widget.empresaActiva['nombre']?.toString() ?? 'Empresa';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventario',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              empresa,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Escanear QR',
              icon: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.indigo,
              ),
              onPressed: _abrirEscaner,
            ),
          ),

          Container(
            margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _cargarProductos,
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          const SizedBox(height: 8),

          _resumenInventario(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.indigo,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: Colors.indigo,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          _filtrosStock(),

          const SizedBox(height: 4),

          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _cargarProductos,
                    child: filtrados.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.22,
                              ),
                              Icon(
                                _searchQuery.isEmpty
                                    ? Icons.inventory_2_outlined
                                    : Icons.search_off_rounded,
                                size: 78,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 15),
                              Text(
                                _productos.isEmpty
                                    ? 'Tu inventario está vacío'
                                    : 'No encontramos productos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Text(
                                  _productos.isEmpty
                                      ? 'Pulsa el botón + para agregar tu primer producto.'
                                      : _searchQuery.isNotEmpty
                                      ? 'Prueba con otro nombre o cambia el filtro de stock.'
                                      : 'Cambia el filtro de stock para ver otros productos.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 4, bottom: 110),
                            itemCount: filtrados.length,
                            itemBuilder: (ctx, i) {
                              return _tarjetaProducto(filtrados[i]);
                            },
                          ),
                  ),
          ),
        ],
      ),

      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _mostrarFormularioOpciones,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Agregar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// CONTROLADORES INGRESO MÚLTIPLE
// =====================================================================

class _ControladoresProductoLote {
  final nombreController = TextEditingController();
  final cantidadController = TextEditingController();
  final precioCompraController = TextEditingController();
  final precioVentaController = TextEditingController();

  void dispose() {
    nombreController.dispose();
    cantidadController.dispose();
    precioCompraController.dispose();
    precioVentaController.dispose();
  }
}

// =====================================================================
// INGRESO MÚLTIPLE
// =====================================================================

class IngresoMultipleScreen extends StatefulWidget {
  final Map<String, dynamic>? empresaActiva;

  const IngresoMultipleScreen({super.key, this.empresaActiva});

  @override
  State<IngresoMultipleScreen> createState() => _IngresoMultipleScreenState();
}

class _IngresoMultipleScreenState extends State<IngresoMultipleScreen> {
  final _proveedorController = TextEditingController();

  final List<_ControladoresProductoLote> _lotes = [];

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _agregarFila();
  }

  @override
  void dispose() {
    _proveedorController.dispose();

    for (final c in _lotes) {
      c.dispose();
    }

    super.dispose();
  }

  void _agregarFila() {
    setState(() {
      _lotes.add(_ControladoresProductoLote());
    });
  }

  void _eliminarFila(int index) {
    if (_lotes.length <= 1) {
      return;
    }

    setState(() {
      _lotes[index].dispose();
      _lotes.removeAt(index);
    });
  }

  int? _obtenerEmpresaIdMultiple() {
    final valor = widget.empresaActiva?['id'];

    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    return int.tryParse(valor?.toString() ?? '');
  }

  Future<void> _guardarTodos() async {
    if (_guardando) return;

    int guardados = 0;

    final proveedor = _proveedorController.text.trim();

    final empresaId = _obtenerEmpresaIdMultiple();

    if (empresaId == null) {
      _mostrarMensaje('No hay una empresa activa válida.', error: true);
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      for (final c in _lotes) {
        final nombre = c.nombreController.text.trim();

        final cantidad = int.tryParse(c.cantidadController.text.trim()) ?? 0;

        if (nombre.isEmpty || cantidad <= 0) {
          continue;
        }

        await DatabaseHelper.instance.insertarProducto({
          'empresa_id': empresaId,
          'nombre': nombre,
          'descripcion': proveedor.isNotEmpty ? 'Proveedor: $proveedor' : '',
          'cantidad': cantidad,
          'precio_compra': parseCurrencyInputToInteger(
            c.precioCompraController.text,
          ),
          'precio_venta': parseCurrencyInputToInteger(
            c.precioVentaController.text,
          ),
          'ruta_foto': '',
        });

        guardados++;
      }

      if (!mounted) return;

      if (guardados > 0) {
        Navigator.pop(context, true);
      } else {
        _mostrarMensaje('No hay productos válidos para guardar.', error: true);
      }
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('Error guardando lote: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: error ? Colors.red : Colors.green,
        content: Text(mensaje),
      ),
    );
  }

  Widget _campoLote(
    TextEditingController controller,
    String label, {
    bool number = false,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingreso múltiple',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Registra varios productos rápidamente',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Guardar todo',
            onPressed: _guardando ? null : _guardarTodos,
            icon: _guardando
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, color: Colors.indigo),
          ),
          const SizedBox(width: 5),
        ],
      ),

      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Proveedor general',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _proveedorController,
                  decoration: InputDecoration(
                    hintText: 'Nombre del proveedor',
                    prefixIcon: const Icon(Icons.local_shipping_outlined),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 5, bottom: 100),
              itemCount: _lotes.length,
              itemBuilder: (ctx, i) {
                final c = _lotes[i];

                return Container(
                  margin: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            const Expanded(
                              child: Text(
                                'Producto',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            if (_lotes.length > 1)
                              IconButton(
                                tooltip: 'Eliminar fila',
                                onPressed: () => _eliminarFila(i),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        _campoLote(
                          c.nombreController,
                          'Nombre del producto',
                          icon: Icons.inventory_2_outlined,
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _campoLote(
                                c.cantidadController,
                                'Cantidad',
                                number: true,
                                icon: Icons.numbers_rounded,
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: _campoLote(
                                c.precioCompraController,
                                'P. Compra',
                                number: true,
                                icon: Icons.shopping_cart_outlined,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        _campoLote(
                          c.precioVentaController,
                          'Precio de venta',
                          number: true,
                          icon: Icons.sell_outlined,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _guardando ? null : _agregarFila,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Agregar otro',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// =====================================================================
// ESCÁNER QR
// =====================================================================

class EscanerQRScreen extends StatefulWidget {
  const EscanerQRScreen({super.key});

  @override
  State<EscanerQRScreen> createState() => _EscanerQRScreenState();
}

class _EscanerQRScreenState extends State<EscanerQRScreen> {
  final MobileScannerController cameraController = MobileScannerController();

  bool isScanned = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Escanear QR',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable:
                cameraController.torchState ?? ValueNotifier(TorchState.off),
            builder: (ctx, state, child) {
              final encendido = state == TorchState.on;

              return IconButton(
                tooltip: encendido ? 'Apagar flash' : 'Encender flash',
                icon: Icon(
                  encendido ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
                onPressed: () => cameraController.toggleTorch(),
              );
            },
          ),
        ],
      ),

      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (capture.barcodes.isEmpty || isScanned) {
                return;
              }

              final codigo = capture.barcodes.first.rawValue;

              if (codigo == null || codigo.isEmpty) {
                return;
              }

              isScanned = true;

              Navigator.pop(context, codigo);
            },
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 270,
                  height: 270,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -3,
                        top: -3,
                        child: _esquinaQR(Alignment.topLeft),
                      ),
                      Positioned(
                        right: -3,
                        top: -3,
                        child: _esquinaQR(Alignment.topRight),
                      ),
                      Positioned(
                        left: -3,
                        bottom: -3,
                        child: _esquinaQR(Alignment.bottomLeft),
                      ),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: _esquinaQR(Alignment.bottomRight),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Coloca el código QR dentro del marco',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _esquinaQR(Alignment alignment) {
    return SizedBox(
      width: 42,
      height: 42,
      child: CustomPaint(painter: _EsquinaQRPainter(alignment)),
    );
  }
}

extension on MobileScannerController {
  ValueListenable<Object?>? get torchState => null;
}

// =====================================================================
// PAINTER DEL MARCO QR
// =====================================================================

class _EsquinaQRPainter extends CustomPainter {
  final Alignment alignment;

  _EsquinaQRPainter(this.alignment);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (alignment == Alignment.topLeft) {
      path.moveTo(3, 18);
      path.lineTo(3, 3);
      path.lineTo(18, 3);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(size.width - 18, 3);
      path.lineTo(size.width - 3, 3);
      path.lineTo(size.width - 3, 18);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(3, size.height - 18);
      path.lineTo(3, size.height - 3);
      path.lineTo(18, size.height - 3);
    } else {
      path.moveTo(size.width - 18, size.height - 3);
      path.lineTo(size.width - 3, size.height - 3);
      path.lineTo(size.width - 3, size.height - 18);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EsquinaQRPainter oldDelegate) {
    return oldDelegate.alignment != alignment;
  }
}
