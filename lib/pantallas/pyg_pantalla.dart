import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../utils/formatters.dart';

class PantallaPyG extends StatefulWidget {
  final Map<String, dynamic> empresaActiva;
  final ValueNotifier<int>? refreshSignal;

  const PantallaPyG({
    super.key,
    required this.empresaActiva,
    this.refreshSignal,
  });

  @override
  State<PantallaPyG> createState() => _PantallaPyGState();
}

class _PantallaPyGState extends State<PantallaPyG> {
  // ============================================================
  // DATOS
  // ============================================================

  int _utilidadMes = 0;
  int _utilidadTotal = 0;

  int _ventasMes = 0;
  int _ventasTotal = 0;

  int _comprasMes = 0;
  int _comprasTotal = 0;

  int _deudaTotal = 0;

  DateTime _selected = DateTime.now();

  bool _loading = false;

  // ============================================================
  // COLORES
  // ============================================================

  static const Color _fondo = Color(0xFFF4F6FB);
  static const Color _azul = Color(0xFF3949AB);
  static const Color _azulClaro = Color(0xFF5C6BC0);
  static const Color _verde = Color(0xFF16A34A);
  static const Color _rojo = Color(0xFFDC2626);
  static const Color _naranja = Color(0xFFF59E0B);

  // ============================================================
  // INICIO
  // ============================================================

  @override
  void initState() {
    super.initState();

    widget.refreshSignal?.addListener(_onRefreshSignal);

    _calcularDatos();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onRefreshSignal);

    super.dispose();
  }

  void _onRefreshSignal() {
    if (!mounted) return;

    _calcularDatos();
  }

  // ============================================================
  // EMPRESA ID
  // ============================================================

  int? _obtenerEmpresaId() {
    final valor = widget.empresaActiva['id'];

    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor?.toString() ?? '');
  }

  // ============================================================
  // CALCULAR DATOS
  // ============================================================

  Future<void> _calcularDatos() async {
    if (!mounted) return;

    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final empresaId = _obtenerEmpresaId();

      if (empresaId == null) {
        throw Exception('No se pudo identificar la empresa.');
      }

      final db = await DatabaseHelper.instance.database;

      final year = _selected.year;
      final month = _selected.month;

      final monthStart = DateTime(year, month, 1).toIso8601String();

      final monthEnd = DateTime(year, month + 1, 1).toIso8601String();

      // ========================================================
      // 1. UTILIDAD MES
      // ========================================================

      final utilMesRows = await db.rawQuery(
        '''
        SELECT
          SUM(
            (vi.precio_unitario - a.precio_compra)
            * vi.cantidad
          ) AS utilidad
        FROM venta_items vi
        JOIN ventas
          ON vi.venta_id = ventas.id
        JOIN almacen a
          ON vi.producto_id = a.id
        WHERE ventas.fecha >= ?
          AND ventas.fecha < ?
          AND ventas.empresa_id = ?
        ''',
        [monthStart, monthEnd, empresaId],
      );

      final utilidadMes = (utilMesRows.first['utilidad'] as num?)?.toInt() ?? 0;

      // ========================================================
      // 2. UTILIDAD TOTAL
      // ========================================================

      final utilTotalRows = await db.rawQuery(
        '''
        SELECT
          SUM(
            (vi.precio_unitario - a.precio_compra)
            * vi.cantidad
          ) AS utilidad
        FROM venta_items vi
        JOIN ventas
          ON vi.venta_id = ventas.id
        JOIN almacen a
          ON vi.producto_id = a.id
        WHERE ventas.empresa_id = ?
        ''',
        [empresaId],
      );

      final utilidadTotal =
          (utilTotalRows.first['utilidad'] as num?)?.toInt() ?? 0;

      // ========================================================
      // 3. VENTAS MES
      // ========================================================

      final ventasMesRows = await db.rawQuery(
        '''
        SELECT
          SUM(total) AS total_ventas
        FROM ventas
        WHERE fecha >= ?
          AND fecha < ?
          AND empresa_id = ?
        ''',
        [monthStart, monthEnd, empresaId],
      );

      final ventasMes =
          (ventasMesRows.first['total_ventas'] as num?)?.toInt() ?? 0;

      // ========================================================
      // 4. VENTAS TOTAL
      // ========================================================

      final ventasTotalRows = await db.rawQuery(
        '''
        SELECT
          SUM(total) AS total_ventas
        FROM ventas
        WHERE empresa_id = ?
        ''',
        [empresaId],
      );

      final ventasTotal =
          (ventasTotalRows.first['total_ventas'] as num?)?.toInt() ?? 0;

      // ========================================================
      // 5. COMPRAS MES
      // ========================================================

      final comprasMesRows = await db.rawQuery(
        '''
        SELECT
          SUM(
            a.precio_compra * vi.cantidad
          ) AS total_compras
        FROM venta_items vi
        JOIN ventas
          ON vi.venta_id = ventas.id
        JOIN almacen a
          ON vi.producto_id = a.id
        WHERE ventas.fecha >= ?
          AND ventas.fecha < ?
          AND ventas.empresa_id = ?
        ''',
        [monthStart, monthEnd, empresaId],
      );

      final comprasMes =
          (comprasMesRows.first['total_compras'] as num?)?.toInt() ?? 0;

      // ========================================================
      // 6. COMPRAS TOTAL
      // ========================================================

      final comprasTotalRows = await db.rawQuery(
        '''
        SELECT
          SUM(
            a.precio_compra * vi.cantidad
          ) AS total_compras
        FROM venta_items vi
        JOIN ventas
          ON vi.venta_id = ventas.id
        JOIN almacen a
          ON vi.producto_id = a.id
        WHERE ventas.empresa_id = ?
        ''',
        [empresaId],
      );

      final comprasTotal =
          (comprasTotalRows.first['total_compras'] as num?)?.toInt() ?? 0;

      // ========================================================
      // 7. DEUDAS
      // ========================================================

      final deudasRows = await db.rawQuery(
        '''
        SELECT
          SUM(deuda_total) AS total_deuda
        FROM clientes
        WHERE empresa_id = ?
        ''',
        [empresaId],
      );

      final deudaTotal =
          (deudasRows.first['total_deuda'] as num?)?.toInt() ?? 0;

      if (!mounted) return;

      setState(() {
        _utilidadMes = utilidadMes;
        _utilidadTotal = utilidadTotal;
        _ventasMes = ventasMes;
        _ventasTotal = ventasTotal;
        _comprasMes = comprasMes;
        _comprasTotal = comprasTotal;
        _deudaTotal = deudaTotal;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _mostrarMensaje('No se pudieron calcular los datos.', error: true);
    }
  }

  // ============================================================
  // CAMBIO DE MES
  // ============================================================

  void _prevMonth() {
    setState(() {
      _selected = DateTime(_selected.year, _selected.month - 1, 1);
    });

    _calcularDatos();
  }

  void _nextMonth() {
    setState(() {
      _selected = DateTime(_selected.year, _selected.month + 1, 1);
    });

    _calcularDatos();
  }

  // ============================================================
  // SELECTOR DE MES Y AÑO
  // ============================================================

  Future<void> _mostrarSelectorMesAnio() async {
    int tempYear = _selected.year;
    int tempMonth = _selected.month;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            const nombresMeses = [
              'Enero',
              'Febrero',
              'Marzo',
              'Abril',
              'Mayo',
              'Junio',
              'Julio',
              'Agosto',
              'Septiembre',
              'Octubre',
              'Noviembre',
              'Diciembre',
            ];

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _azul.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: _azul,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Periodo',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Selecciona mes y año',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
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

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  tempYear--;
                                });
                              },
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$tempYear',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _azul,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  tempYear++;
                                });
                              },
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: nombresMeses.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2.25,
                              crossAxisSpacing: 9,
                              mainAxisSpacing: 9,
                            ),
                        itemBuilder: (context, index) {
                          final mes = index + 1;

                          final seleccionado = tempMonth == mes;

                          return FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: seleccionado
                                  ? _azul
                                  : const Color(0xFFF0F2F8),
                              foregroundColor: seleccionado
                                  ? Colors.white
                                  : Colors.black87,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                tempMonth = mes;
                              });
                            },
                            child: Text(
                              nombresMeses[index],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Aplicar'),
                              onPressed: () {
                                setState(() {
                                  _selected = DateTime(tempYear, tempMonth, 1);
                                });

                                Navigator.pop(dialogContext);

                                _calcularDatos();
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
  }

  // ============================================================
  // COLOR UTILIDAD
  // ============================================================

  Color get _colorUtilidad {
    if (_utilidadMes > 0) {
      return _verde;
    }

    if (_utilidadMes < 0) {
      return _rojo;
    }

    return Colors.grey;
  }

  // ============================================================
  // TEXTO UTILIDAD
  // ============================================================

  String get _textoUtilidad {
    if (_utilidadMes > 0) {
      return 'UTILIDAD';
    }

    if (_utilidadMes < 0) {
      return 'PÉRDIDA';
    }

    return 'SIN RESULTADO';
  }

  // ============================================================
  // NOMBRE DEL MES
  // ============================================================

  String _nombreMes(int mes) {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return meses[mes - 1];
  }

  // ============================================================
  // TARJETA KPI
  // ============================================================

  Widget _kpiCard({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icono, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BARRA COMPARATIVA
  // ============================================================

  Widget _barraComparativa({
    required String titulo,
    required int valor,
    required int total,
    required Color color,
    required IconData icono,
  }) {
    double porcentaje = 0;

    if (total > 0) {
      porcentaje = (valor / total).clamp(0.0, 1.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icono, color: color, size: 19),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),

            Text(
              '\$${formatCurrencyCol(valor)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),

        const SizedBox(height: 9),

        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: porcentaje,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DEUDA
  // ============================================================

  Widget _tarjetaDeuda() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CUENTAS POR COBRAR',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '\$${formatCurrencyCol(_deudaTotal)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 3),

                const Text(
                  'Deuda total de clientes',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO UTILIDAD
  // ============================================================

  Widget _heroUtilidad() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_azul, _azulClaro],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _azul.withValues(alpha: 0.22),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESULTADO DEL PERIODO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tu negocio en números',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Text(
            _textoUtilidad,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '\$${formatCurrencyCol(_utilidadMes)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '${_nombreMes(_selected.month)} ${_selected.year}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(
                  _utilidadMes >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: Colors.white,
                  size: 20,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    _utilidadMes > 0
                        ? 'El periodo cerró con resultado positivo.'
                        : _utilidadMes < 0
                        ? 'El periodo cerró con pérdida.'
                        : 'No se registró utilidad en este periodo.',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(child: _heroDato('Ventas', _ventasMes)),

              const SizedBox(width: 10),

              Expanded(child: _heroDato('Costos', _comprasMes)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroDato(String titulo, int valor) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),

          const SizedBox(height: 3),

          Text(
            '\$${formatCurrencyCol(valor)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILA HISTÓRICA
  // ============================================================

  Widget _filaHistorica(String titulo, int valor, Color color, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 18),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          Text(
            '\$${formatCurrencyCol(valor)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MENSAJE
  // ============================================================

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final empresa = widget.empresaActiva['nombre']?.toString() ?? 'Mi negocio';

    final periodo = '${_nombreMes(_selected.month)} ${_selected.year}';

    final margen = _ventasMes > 0 ? (_utilidadMes / _ventasMes) * 100 : 0.0;

    return Scaffold(
      backgroundColor: _fondo,

      // ==========================================================
      // APP BAR
      // ==========================================================
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _fondo,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finanzas',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            Text(
              empresa,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? null : _calcularDatos,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),

      // ==========================================================
      // BODY
      // ==========================================================
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _calcularDatos,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ==================================================
                  // PERIODO
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _azul.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                color: _azul,
                                size: 21,
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: GestureDetector(
                                onTap: _mostrarSelectorMesAnio,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Periodo seleccionado',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      periodo,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            IconButton(
                              tooltip: 'Mes anterior',
                              onPressed: _prevMonth,
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),

                            IconButton(
                              tooltip: 'Mes siguiente',
                              onPressed: _nextMonth,
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ==================================================
                  // HERO
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _heroUtilidad(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ==================================================
                  // MARGEN
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _verde.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.percent_rounded,
                                color: _verde,
                              ),
                            ),

                            const SizedBox(width: 11),

                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Margen del periodo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Utilidad respecto a las ventas',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Text(
                              '${margen.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: _colorUtilidad,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ==================================================
                  // KPIs
                  // ==================================================
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      delegate: SliverChildListDelegate([
                        _kpiCard(
                          titulo: 'Ventas del mes',
                          valor: '\$${formatCurrencyCol(_ventasMes)}',
                          icono: Icons.point_of_sale_rounded,
                          color: Colors.blue,
                        ),
                        _kpiCard(
                          titulo: 'Costos del mes',
                          valor: '\$${formatCurrencyCol(_comprasMes)}',
                          icono: Icons.shopping_cart_rounded,
                          color: _naranja,
                        ),
                        _kpiCard(
                          titulo: 'Ventas históricas',
                          valor: '\$${formatCurrencyCol(_ventasTotal)}',
                          icono: Icons.bar_chart_rounded,
                          color: _azul,
                        ),
                        _kpiCard(
                          titulo: 'Utilidad histórica',
                          valor: '\$${formatCurrencyCol(_utilidadTotal)}',
                          icono: Icons.trending_up_rounded,
                          color: _verde,
                        ),
                      ]),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.55,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // ==================================================
                  // VENTAS VS COSTOS
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: _azul.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(
                                    Icons.compare_arrows_rounded,
                                    color: _azul,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ventas vs. costos',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Composición del periodo',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            _barraComparativa(
                              titulo: 'Ventas',
                              valor: _ventasMes,
                              total: _ventasMes + _comprasMes,
                              color: Colors.blue,
                              icono: Icons.point_of_sale_rounded,
                            ),

                            const SizedBox(height: 18),

                            _barraComparativa(
                              titulo: 'Costos',
                              valor: _comprasMes,
                              total: _ventasMes + _comprasMes,
                              color: _naranja,
                              icono: Icons.shopping_cart_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // ==================================================
                  // RESUMEN HISTÓRICO
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumen histórico',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              'Acumulado de todo el negocio',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),

                            const SizedBox(height: 15),

                            _filaHistorica(
                              'Ventas',
                              _ventasTotal,
                              Colors.blue,
                              Icons.point_of_sale_rounded,
                            ),

                            const SizedBox(height: 9),

                            _filaHistorica(
                              'Costos',
                              _comprasTotal,
                              _naranja,
                              Icons.shopping_cart_rounded,
                            ),

                            const SizedBox(height: 9),

                            _filaHistorica(
                              'Utilidad',
                              _utilidadTotal,
                              _verde,
                              Icons.trending_up_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // ==================================================
                  // DEUDA
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _tarjetaDeuda(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 35)),
                ],
              ),
            ),
    );
  }
}
