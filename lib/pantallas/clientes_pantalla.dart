import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../utils/formatters.dart';

class PantallaClientes extends StatefulWidget {
  final Map<String, dynamic> empresaActiva;

  const PantallaClientes({super.key, required this.empresaActiva});

  @override
  State<PantallaClientes> createState() => _PantallaClientesState();
}

class _PantallaClientesState extends State<PantallaClientes> {
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _clientesFiltrados = [];

  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    final datos = await DatabaseHelper.instance.obtenerClientes();

    final empresaId =
        int.tryParse(widget.empresaActiva['id']?.toString() ?? '0') ?? 0;

    final clientesEmpresa = datos.where((cliente) {
      final clienteEmpresaId =
          int.tryParse(
            cliente['empresa_id']?.toString() ??
                cliente['empresaId']?.toString() ??
                cliente['id_empresa']?.toString() ??
                '0',
          ) ??
          0;

      return clienteEmpresaId == empresaId;
    }).toList();

    if (!mounted) return;

    setState(() {
      _clientes = clientesEmpresa;
      _clientesFiltrados = clientesEmpresa;
    });
  }

  void _filtrarClientes(String query) {
    if (query.isEmpty) {
      setState(() {
        _clientesFiltrados = _clientes;
      });
    } else {
      setState(() {
        _clientesFiltrados = _clientes.where((cliente) {
          final nombre = cliente['nombre']?.toString().toLowerCase() ?? '';
          return nombre.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  // -------------------------------------------------------------------------
  // UTILIDADES DE UI (Snackbars y Decoraciones)
  // -------------------------------------------------------------------------

  void _mostrarSnackBar(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // LÓGICA DE CLIENTES (Crear, Editar, Eliminar)
  // -------------------------------------------------------------------------

  void _mostrarFormularioCliente({Map<String, dynamic>? cliente}) {
    if (cliente != null) {
      _nombreController.text = cliente['nombre'] ?? '';
      _telefonoController.text = cliente['telefono'] ?? '';
    } else {
      _nombreController.clear();
      _telefonoController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent, // Para ver el borde redondeado del Container
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 15,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Manija (Drag handle)
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Row(
                children: [
                  Icon(
                    cliente == null ? Icons.person_add : Icons.edit,
                    color: Colors.indigo,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    cliente == null ? 'Nuevo Cliente' : 'Editar Cliente',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              TextField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _telefonoController,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () => _guardarCliente(clienteId: cliente?['id']),
                  child: Text(
                    cliente == null ? 'Guardar Cliente' : 'Actualizar Cliente',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardarCliente({int? clienteId}) async {
    final nombre = _nombreController.text.trim();

    if (nombre.isEmpty) {
      _mostrarSnackBar('El nombre del cliente es obligatorio', esError: true);
      return;
    }

    try {
      if (clienteId == null) {
        final empresaId =
            int.tryParse(widget.empresaActiva['id']?.toString() ?? '0') ?? 0;

        final nuevoCliente = {
          'nombre': nombre,
          'telefono': _telefonoController.text.trim(),
          'deuda_total': 0,
          'empresa_id': empresaId,
        };
        await DatabaseHelper.instance.insertarCliente(nuevoCliente);
      } else {
        final datosActualizados = {
          'nombre': nombre,
          'telefono': _telefonoController.text.trim(),
        };
        await DatabaseHelper.instance.actualizarCliente(
          clienteId,
          datosActualizados,
        );
      }

      _nombreController.clear();
      _telefonoController.clear();

      if (!mounted) return;
      Navigator.of(context).pop();

      _searchController.clear();
      await _cargarClientes();

      _mostrarSnackBar(
        clienteId == null ? '¡Cliente guardado!' : '¡Cliente actualizado!',
      );
    } catch (e) {
      _mostrarSnackBar('Error al guardar cliente: $e', esError: true);
    }
  }

  Future<void> _eliminarClienteConfirmacion(int clienteId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Eliminar Cliente'),
          ],
        ),
        content: const Text(
          '¿Seguro que deseas eliminar este cliente y todo su historial? Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final db = await DatabaseHelper.instance.database;

        final ventasDelCliente = await db.query(
          'ventas',
          columns: ['id'],
          where: 'cliente_id = ?',
          whereArgs: [clienteId],
        );
        for (var venta in ventasDelCliente) {
          await db.delete(
            'venta_items',
            where: 'venta_id = ?',
            whereArgs: [venta['id']],
          );
        }

        await db.delete(
          'ventas',
          where: 'cliente_id = ?',
          whereArgs: [clienteId],
        );

        await db.delete('clientes', where: 'id = ?', whereArgs: [clienteId]);

        _searchController.clear();
        await _cargarClientes();

        if (!mounted) return;
        Navigator.of(context).pop();
        _mostrarSnackBar('Cliente eliminado exitosamente');
      } catch (e) {
        _mostrarSnackBar('Error al eliminar: $e', esError: true);
      }
    }
  }

  Future<void> _actualizarDeudaCliente(int clienteId, int nuevaDeuda) async {
    final cliente = _clientes.cast<Map<String, dynamic>?>().firstWhere(
      (c) => c?['id'] == clienteId,
      orElse: () => null,
    );

    if (cliente == null) return;

    await DatabaseHelper.instance.actualizarCliente(clienteId, {
      'deuda_total': nuevaDeuda,
    });

    final busquedaActual = _searchController.text;
    await _cargarClientes();
    _filtrarClientes(busquedaActual);
  }

  // -------------------------------------------------------------------------
  // LÓGICA DEL HISTORIAL DE VENTAS (Editar, Eliminar)
  // -------------------------------------------------------------------------

  void _mostrarEditarVenta(
    Map<String, dynamic> venta,
    VoidCallback onActualizado,
  ) {
    final totalController = TextEditingController(
      text: formatCurrencyCol((venta['total'] as num).toInt()),
    );
    final pagadoController = TextEditingController(
      text: formatCurrencyCol((venta['pagado'] as num).toInt()),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Editar Venta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: totalController,
              decoration: InputDecoration(
                labelText: 'Total',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: pagadoController,
              decoration: InputDecoration(
                labelText: 'Pagado',
                prefixIcon: const Icon(Icons.money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
              final nuevoTotal = parseCurrencyInputToInteger(
                totalController.text.trim(),
              );
              final nuevoPagado = parseCurrencyInputToInteger(
                pagadoController.text.trim(),
              );

              final db = await DatabaseHelper.instance.database;
              await db.update(
                'ventas',
                {'total': nuevoTotal, 'pagado': nuevoPagado},
                where: 'id = ?',
                whereArgs: [venta['id']],
              );

              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
              onActualizado();
              _mostrarSnackBar('Historial actualizado');
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarVentaConfirmacion(
    int ventaId,
    VoidCallback onActualizado,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar Registro'),
        content: const Text(
          '¿Seguro que deseas eliminar esta venta del historial?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await DatabaseHelper.instance.eliminarVenta(ventaId);
      onActualizado();
      _mostrarSnackBar('Registro eliminado');
    }
  }

  // -------------------------------------------------------------------------
  // INTERFAZ DE DETALLES
  // -------------------------------------------------------------------------

  void _mostrarDetalleCliente(Map<String, dynamic> cliente) {
    final pagoController = TextEditingController();
    final ajusteController = TextEditingController(
      text: formatCurrencyCol((cliente['deuda_total'] as num?)?.toInt() ?? 0),
    );

    int refreshKey = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void recargarHistorial() {
            setModalState(() {
              refreshKey++;
            });
          }

          final deudaActual = (cliente['deuda_total'] as num?)?.toInt() ?? 0;
          final tieneDeuda = deudaActual > 0;

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 15,
              left: 20,
              right: 20,
            ),
            child: Column(
              children: [
                // Manija superior
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // Cabecera (Nombre y Botones de acción)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        cliente['nombre']?.substring(0, 1).toUpperCase() ?? 'C',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cliente['nombre'] ?? '',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cliente['telefono']?.toString().isNotEmpty ==
                                        true
                                    ? cliente['telefono']
                                    : 'Sin teléfono',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Editar',
                      onPressed: () {
                        Navigator.pop(context);
                        _mostrarFormularioCliente(cliente: cliente);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar',
                      onPressed: () =>
                          _eliminarClienteConfirmacion(cliente['id'] as int),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tarjeta de Deuda Total
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: tieneDeuda
                          ? [Colors.red.shade400, Colors.red.shade600]
                          : [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (tieneDeuda ? Colors.red : Colors.green)
                            .withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Deuda Total',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '\$${formatCurrencyCol(deudaActual)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Contenido Deslizable (Pagos, Ajustes, Historial)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sección: Registrar Pago
                        const Text(
                          'Registrar Abono',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: pagoController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'Monto a pagar',
                                  prefixIcon: const Icon(Icons.attach_money),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                final pago = parseCurrencyInputToInteger(
                                  pagoController.text.trim(),
                                );
                                if (pago <= 0) return;

                                var nuevaDeuda = deudaActual - pago;
                                if (nuevaDeuda < 0) nuevaDeuda = 0;

                                await _actualizarDeudaCliente(
                                  cliente['id'] as int,
                                  nuevaDeuda,
                                );

                                if (!mounted) return;
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).pop();
                                _mostrarSnackBar(
                                  'Pago registrado correctamente',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Abonar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        // Sección: Ajuste manual
                        const Text(
                          'Ajustar deuda manualmente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: ajusteController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'Nueva deuda total',
                                  prefixIcon: const Icon(Icons.edit_note),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                final nuevaDeuda = parseCurrencyInputToInteger(
                                  ajusteController.text.trim(),
                                );
                                if (nuevaDeuda < 0) return;

                                await _actualizarDeudaCliente(
                                  cliente['id'] as int,
                                  nuevaDeuda,
                                );

                                if (!mounted) return;
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).pop();
                                _mostrarSnackBar(
                                  'Deuda actualizada correctamente',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Actualizar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        const Divider(),

                        // Sección: Historial
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'Historial de compras',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          key: ValueKey(refreshKey),
                          future: DatabaseHelper.instance.obtenerVentas(
                            clienteId: cliente['id'] as int,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final ventas = snapshot.data ?? [];
                            if (ventas.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(20),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.history_toggle_off,
                                      size: 50,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Este cliente no tiene compras aún.',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: ventas.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final venta = ventas[index];
                                final total = (venta['total'] as num).toInt();
                                final pagado = (venta['pagado'] as num).toInt();
                                final saldo = total - pagado;

                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 5,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.indigo.shade50,
                                      child: const Icon(
                                        Icons.shopping_bag,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                    title: Text(
                                      'Total: \$${formatCurrencyCol(total)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pagado: \$${formatCurrencyCol(pagado)}',
                                          ),
                                          if (saldo > 0)
                                            Text(
                                              'Saldo: \$${formatCurrencyCol(saldo)}',
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${venta['fecha']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _mostrarEditarVenta(
                                            venta,
                                            recargarHistorial,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 20,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _eliminarVentaConfirmacion(
                                                venta['id'] as int,
                                                recargarHistorial,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CONSTRUCCIÓN PRINCIPAL
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade100, // Fondo suave para contrastar con las tarjetas
      appBar: AppBar(
        title: Text('Clientes - ${widget.empresaActiva['nombre'] ?? ''}'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // BARRA DE BÚSQUEDA ESTILIZADA
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color:
                Theme.of(context).appBarTheme.backgroundColor ??
                Theme.of(context).primaryColor,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filtrarClientes,
                decoration: InputDecoration(
                  hintText: 'Buscar cliente...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _filtrarClientes('');
                            FocusScope.of(context).unfocus(); // Ocultar teclado
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ),

          // LISTA DE CLIENTES
          Expanded(
            child: _clientesFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Aún no hay clientes registrados'
                              : 'No se encontraron resultados',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      top: 10,
                      bottom: 80,
                    ), // Padding inferior para el FAB
                    physics: const BouncingScrollPhysics(),
                    itemCount: _clientesFiltrados.length,
                    itemBuilder: (context, index) {
                      final cliente = _clientesFiltrados[index];
                      final deudaTotal =
                          (cliente['deuda_total'] as num?)?.toInt() ?? 0;
                      final tieneDeuda = deudaTotal > 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => _mostrarDetalleCliente(cliente),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.indigo.shade300,
                                        Colors.indigo.shade600,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.indigo.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      cliente['nombre']
                                              ?.substring(0, 1)
                                              .toUpperCase() ??
                                          'C',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),

                                // Info del cliente
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cliente['nombre'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone,
                                            size: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            cliente['telefono']
                                                        ?.toString()
                                                        .isNotEmpty ==
                                                    true
                                                ? cliente['telefono']
                                                : 'Sin teléfono',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Chip de estado de cuenta
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tieneDeuda
                                        ? Colors.red.shade50
                                        : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: tieneDeuda
                                          ? Colors.red.shade200
                                          : Colors.green.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tieneDeuda ? 'DEBE' : 'AL DÍA',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: tieneDeuda
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '\$${formatCurrencyCol(deudaTotal)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: tieneDeuda
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

      // BOTÓN FLOTANTE ESTILIZADO
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioCliente(),
        backgroundColor: Colors.indigo,
        elevation: 4,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Nuevo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
