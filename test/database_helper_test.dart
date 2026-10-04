import 'package:app_ventas/db/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await deleteDatabase(join(await getDatabasesPath(), 'ventas_app.db'));
    await DatabaseHelper.instance.database;
  });

  test('registrarVenta descuenta inventario y guarda venta, historial y utilidad', () async {
    final empresaId = await DatabaseHelper.instance.insertarEmpresa({
      'nombre': 'Empresa Test',
      'logo_ruta': '',
      'activa': 1,
    });

    final productoId = await DatabaseHelper.instance.insertarProducto({
      'nombre': 'Camisa',
      'descripcion': 'Camisa de prueba',
      'cantidad': 3000,
      'precio_compra': 200000,
      'precio_venta': 300000,
      'ruta_foto': '',
    });

    final clienteId = await DatabaseHelper.instance.insertarCliente({
      'nombre': 'Carlos',
      'telefono': '123',
      'deuda_total': 0,
    });

    await DatabaseHelper.instance.registrarVenta(
      6000000,
      [
        {
          'id': productoId,
          'nombre': 'Camisa',
          'cantidad_vendida': 2000,
          'cantidad_actual': 3000,
          'precio': 300000,
          'subtotal': 6000000,
        },
      ],
      clienteId: clienteId,
      pagado: 6000000,
      empresaId: empresaId,
    );

    final productoActualizado = await DatabaseHelper.instance.obtenerProductoPorId(productoId);
    expect(productoActualizado!['cantidad'], 1000);

    final ventas = await DatabaseHelper.instance.obtenerVentas(empresaId: empresaId);
    expect(ventas.length, 1);

    final utilidadMes = await DatabaseHelper.instance.obtenerUtilidadMes(
      DateTime.now().year,
      DateTime.now().month,
      empresaId: empresaId,
    );
    final utilidadTotal = await DatabaseHelper.instance.obtenerUtilidadTotal(empresaId: empresaId);

    expect(utilidadMes, greaterThan(0));
    expect(utilidadTotal, greaterThan(0));
  });

  test('registrarVenta acepta valores de inventario y precios almacenados como texto', () async {
    final empresaId = await DatabaseHelper.instance.insertarEmpresa({
      'nombre': 'Empresa Test 2',
      'logo_ruta': '',
      'activa': 1,
    });

    final db = await DatabaseHelper.instance.database;
    final productoId = await db.insert('almacen', {
      'nombre': 'Pantalón',
      'descripcion': 'Pantalón de prueba',
      'cantidad': '3000',
      'precio_compra': '200000',
      'precio_venta': '300000',
      'ruta_foto': '',
      'proveedor_id': null,
    });

    final clienteId = await DatabaseHelper.instance.insertarCliente({
      'nombre': 'Ana',
      'telefono': '456',
      'deuda_total': 0,
    });

    await DatabaseHelper.instance.registrarVenta(
      6000000,
      [
        {
          'id': productoId,
          'nombre': 'Pantalón',
          'cantidad_vendida': 2000,
          'cantidad_actual': '3000',
          'precio': '300000',
          'subtotal': '6000000',
        },
      ],
      clienteId: clienteId,
      pagado: 6000000,
      empresaId: empresaId,
    );

    final productoActualizado = await DatabaseHelper.instance.obtenerProductoPorId(productoId);
    expect(int.tryParse(productoActualizado!['cantidad'].toString()), 1000);
  });

  test('insertarNota y obtenerNotas guardan la información para backup', () async {
    final empresaId = await DatabaseHelper.instance.insertarEmpresa({
      'nombre': 'Empresa Notas',
      'logo_ruta': '',
      'activa': 1,
    });

    final notaId = await DatabaseHelper.instance.insertarNota({
      'empresa_id': empresaId,
      'titulo': 'Compra de materiales',
      'contenido': 'Nota para el blog',
      'numero': 42,
      'imagen_base64': 'abc123',
      'fecha_creacion': DateTime.now().toIso8601String(),
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    });

    final notas = await DatabaseHelper.instance.obtenerNotas(empresaId: empresaId);
    expect(notas.length, 1);
    expect(notas.first['id'], notaId);
    expect(notas.first['titulo'], 'Compra de materiales');
    expect(notas.first['numero'], 42);
  });
}
