import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../utils/formatters.dart';

class HistorialVentasPantalla extends StatefulWidget {
  final int empresaId;

  const HistorialVentasPantalla({super.key, required this.empresaId});

  @override
  State<HistorialVentasPantalla> createState() =>
      _HistorialVentasPantallaState();
}

class _HistorialVentasPantallaState extends State<HistorialVentasPantalla> {
  List<Map<String, dynamic>> _ventas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  // --- FUNCIÓN COLOCADA FUERA DE INITSTATE CORRECTAMENTE ---
  Future<void> _confirmarEliminacionVenta(Map<String, dynamic> venta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Venta'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta venta? Los productos volverán al inventario automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar y Restaurar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final idVenta = int.parse(venta['id'].toString());
        await DatabaseHelper.instance.eliminarVentaYRestaurarInventario(
          idVenta,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Venta eliminada y stock restaurado con éxito'),
              backgroundColor: Colors.green,
            ),
          );
          _cargarHistorial(); // Refrescamos la lista para que desaparezca la venta
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cargarHistorial() async {
    setState(() => _cargando = true);
    try {
      // Usamos el método oficial que ya está en tu DatabaseHelper
      final datos = await DatabaseHelper.instance.obtenerVentas(
        empresaId: widget
            .empresaId, // Ajusta a widget.empresaId si es un entero directo
      );

      if (mounted) {
        setState(() {
          _ventas = datos;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el historial: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarHistorial,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _ventas.isEmpty
          ? const Center(
              child: Text(
                'No hay ventas registradas en esta empresa.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _ventas.length,
              itemBuilder: (context, index) {
                final venta = _ventas[index];
                final int total =
                    int.tryParse(venta['total']?.toString() ?? '0') ?? 0;
                final int pagado =
                    int.tryParse(venta['pagado']?.toString() ?? '0') ?? 0;
                final String fecha = venta['fecha']?.toString() ?? 'Sin fecha';
                final String cliente =
                    venta['nombre_cliente']?.toString() ?? 'Cliente Ocasional';
                final bool estaPagado = pagado >= total;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: estaPagado
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      child: Icon(
                        estaPagado ? Icons.check_circle : Icons.pending,
                        color: estaPagado ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      'Total: \$${formatCurrencyCol(total)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Cliente: $cliente'),
                        Text('Fecha: $fecha'),
                        Text(
                          estaPagado
                              ? 'Estado: Pagado'
                              : 'Estado: Deuda (\$${formatCurrencyCol(total - pagado)} pendiente)',
                          style: TextStyle(
                            color: estaPagado ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    // --- BOTÓN DE ELIMINAR AGREGADO AQUÍ ---
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar Venta',
                      onPressed: () => _confirmarEliminacionVenta(venta),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
