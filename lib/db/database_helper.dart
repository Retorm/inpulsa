import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // ============================================================
  // COPIA AUTOMÁTICA DIARIA
  // ============================================================
  // Mantiene un solo archivo de respaldo y lo sobrescribe.
  static Timer? _backupTimer;
  static bool _backupEnProceso = false;
  static bool _schedulerIniciado = false;

  DatabaseHelper._init();

  // ============================================================
  // DATABASE
  // ============================================================
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDB('ventas_app.db');

    // Iniciar la copia automática una sola vez.
    _iniciarProgramadorCopiaAutomatica();

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _asegurarEsquemaCompleto(db);
        await _repararEmpresasAntiguas(db);
      },
    );
  }

  // ============================================================
  // CREAR BASE DE DATOS
  // ============================================================
  Future<void> _createDB(Database db, int version) async {
    await _crearTablaEmpresas(db);
    await _crearTablaProveedores(db);
    await _crearTablaAlmacen(db);
    await _crearTablaClientes(db);
    await _crearTablaNotas(db);
    await _crearTablaVentas(db);
    await _crearTablaVentaItems(db);
    await _crearTablaAlistamientos(db);
  }

  // ============================================================
  // UPGRADE
  // ============================================================
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _asegurarEsquemaCompleto(db);
    await _repararEmpresasAntiguas(db);
  }

  // ============================================================
  // TABLAS
  // ============================================================
  Future<void> _crearTablaEmpresas(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empresas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        logo_ruta TEXT,
        activa INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _crearTablaProveedores(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proveedores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empresa_id INTEGER,
        nombre TEXT NOT NULL,
        contacto TEXT
      )
    ''');
  }

  Future<void> _crearTablaAlmacen(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS almacen (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empresa_id INTEGER,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        cantidad INTEGER NOT NULL DEFAULT 0,
        precio_compra INTEGER NOT NULL DEFAULT 0,
        precio_venta INTEGER NOT NULL DEFAULT 0,
        ruta_foto TEXT,
        proveedor_id INTEGER
      )
    ''');
  }

  Future<void> _crearTablaClientes(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empresa_id INTEGER,
        nombre TEXT NOT NULL,
        telefono TEXT,
        deuda_total INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _crearTablaNotas(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empresa_id INTEGER,
        titulo TEXT,
        contenido TEXT,
        numero INTEGER DEFAULT 0,
        imagen_base64 TEXT,
        fecha_creacion TEXT,
        fecha_actualizacion TEXT
      )
    ''');
  }

  Future<void> _crearTablaVentas(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empresa_id INTEGER,
        cliente_id INTEGER,
        total INTEGER NOT NULL DEFAULT 0,
        pagado INTEGER NOT NULL DEFAULT 0,
        fecha TEXT
      )
    ''');
  }

  Future<void> _crearTablaVentaItems(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS venta_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL DEFAULT 0,
        precio_unitario INTEGER NOT NULL DEFAULT 0,
        subtotal INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _crearTablaAlistamientos(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alistamientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empresa_id INTEGER,
        cliente_id INTEGER,
        referencia TEXT,
        items_json TEXT,
        fecha_creacion TEXT
      )
    ''');
  }

  // ============================================================
  // ASEGURAR ESQUEMA COMPLETO
  // ============================================================
  Future<void> _asegurarEsquemaCompleto(Database db) async {
    await _crearTablaEmpresas(db);
    await _crearTablaProveedores(db);
    await _crearTablaAlmacen(db);
    await _crearTablaClientes(db);
    await _crearTablaNotas(db);
    await _crearTablaVentas(db);
    await _crearTablaVentaItems(db);
    await _crearTablaAlistamientos(db);

    // ----------------------------------------------------------
    // EMPRESAS
    // ----------------------------------------------------------
    await _agregarColumnaSiNoExiste(db, 'empresas', 'logo_ruta', 'TEXT');
    await _agregarColumnaSiNoExiste(
      db,
      'empresas',
      'activa',
      'INTEGER NOT NULL DEFAULT 0',
    );

    // ----------------------------------------------------------
    // PROVEEDORES
    // ----------------------------------------------------------
    await _agregarColumnaSiNoExiste(db, 'proveedores', 'empresa_id', 'INTEGER');
    await _agregarColumnaSiNoExiste(db, 'proveedores', 'contacto', 'TEXT');

    // ----------------------------------------------------------
    // ALMACEN
    // ----------------------------------------------------------
    await _agregarColumnaSiNoExiste(db, 'almacen', 'empresa_id', 'INTEGER');
    await _agregarColumnaSiNoExiste(db, 'almacen', 'descripcion', 'TEXT');
    await _agregarColumnaSiNoExiste(
      db,
      'almacen',
      'cantidad',
      'INTEGER DEFAULT 0',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'almacen',
      'precio_compra',
      'INTEGER DEFAULT 0',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'almacen',
      'precio_venta',
      'INTEGER DEFAULT 0',
    );
    await _agregarColumnaSiNoExiste(db, 'almacen', 'ruta_foto', 'TEXT');
    await _agregarColumnaSiNoExiste(db, 'almacen', 'proveedor_id', 'INTEGER');

    // ----------------------------------------------------------
    // CLIENTES
    // ----------------------------------------------------------
    await _agregarColumnaSiNoExiste(db, 'clientes', 'empresa_id', 'INTEGER');
    await _agregarColumnaSiNoExiste(db, 'clientes', 'telefono', 'TEXT');
    await _agregarColumnaSiNoExiste(
      db,
      'clientes',
      'deuda_total',
      'INTEGER DEFAULT 0',
    );

    // ----------------------------------------------------------
    // NOTAS
    // ----------------------------------------------------------
    await _agregarColumnaSiNoExiste(db, 'notas', 'empresa_id', 'INTEGER');
    await _agregarColumnaSiNoExiste(db, 'notas', 'titulo', 'TEXT');
    await _agregarColumnaSiNoExiste(db, 'notas', 'contenido', 'TEXT');
    await _agregarColumnaSiNoExiste(db, 'notas', 'numero', 'INTEGER DEFAULT 0');
    await _agregarColumnaSiNoExiste(db, 'notas', 'imagen_base64', 'TEXT');
    await _agregarColumnaSiNoExiste(db, 'notas', 'fecha_creacion', 'TEXT');
    await _agregarColumnaSiNoExiste(db, 'notas', 'fecha_actualizacion', 'TEXT');

    // ----------------------------------------------------------
    // VENTAS
    // ----------------------------------------------------------
    await _agregarColumnaSiNoExiste(db, 'ventas', 'empresa_id', 'INTEGER');
    await _agregarColumnaSiNoExiste(db, 'ventas', 'cliente_id', 'INTEGER');
    await _agregarColumnaSiNoExiste(db, 'ventas', 'total', 'INTEGER DEFAULT 0');
    await _agregarColumnaSiNoExiste(
      db,
      'ventas',
      'pagado',
      'INTEGER DEFAULT 0',
    );
    await _agregarColumnaSiNoExiste(db, 'ventas', 'fecha', 'TEXT');

    // ----------------------------------------------------------
    // VENTA ITEMS
    // ----------------------------------------------------------
    await _agregarColumnaSiNoExiste(db, 'venta_items', 'venta_id', 'INTEGER');
    await _agregarColumnaSiNoExiste(
      db,
      'venta_items',
      'producto_id',
      'INTEGER',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'venta_items',
      'cantidad',
      'INTEGER DEFAULT 0',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'venta_items',
      'precio_unitario',
      'INTEGER DEFAULT 0',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'venta_items',
      'subtotal',
      'INTEGER DEFAULT 0',
    );

    // ----------------------------------------------------------
    // ALISTAMIENTOS
    // ----------------------------------------------------------
    await _agregarColumnaSiNoExiste(
      db,
      'alistamientos',
      'empresa_id',
      'INTEGER',
    );
    await _agregarColumnaSiNoExiste(
      db,
      'alistamientos',
      'cliente_id',
      'INTEGER',
    );
    await _agregarColumnaSiNoExiste(db, 'alistamientos', 'referencia', 'TEXT');
    await _agregarColumnaSiNoExiste(db, 'alistamientos', 'items_json', 'TEXT');
    await _agregarColumnaSiNoExiste(
      db,
      'alistamientos',
      'fecha_creacion',
      'TEXT',
    );

    await _repararValoresNulos(db);
  }

  // ============================================================
  // AGREGAR COLUMNA SI NO EXISTE
  // ============================================================
  Future<void> _agregarColumnaSiNoExiste(
    Database db,
    String tabla,
    String columna,
    String tipo,
  ) async {
    try {
      final columnas = await db.rawQuery('PRAGMA table_info($tabla)');
      final existe = columnas.any((col) => col['name']?.toString() == columna);
      if (!existe) {
        await db.execute('ALTER TABLE $tabla ADD COLUMN $columna $tipo');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error agregando columna $columna a $tabla: $e');
    }
  }

  // ============================================================
  // REPARAR NULL
  // ============================================================
  Future<void> _repararValoresNulos(Database db) async {
    try {
      await db.rawUpdate(
        'UPDATE empresas SET activa = 0 '
        'WHERE activa IS NULL',
      );
      await db.rawUpdate(
        'UPDATE almacen SET cantidad = 0 '
        'WHERE cantidad IS NULL',
      );
      await db.rawUpdate(
        'UPDATE almacen SET precio_compra = 0 '
        'WHERE precio_compra IS NULL',
      );
      await db.rawUpdate(
        'UPDATE almacen SET precio_venta = 0 '
        'WHERE precio_venta IS NULL',
      );
      await db.rawUpdate(
        'UPDATE clientes SET deuda_total = 0 '
        'WHERE deuda_total IS NULL',
      );
      await db.rawUpdate(
        'UPDATE ventas SET total = 0 '
        'WHERE total IS NULL',
      );
      await db.rawUpdate(
        'UPDATE ventas SET pagado = 0 '
        'WHERE pagado IS NULL',
      );
      await db.rawUpdate(
        'UPDATE venta_items SET cantidad = 0 '
        'WHERE cantidad IS NULL',
      );
      await db.rawUpdate(
        'UPDATE venta_items SET precio_unitario = 0 '
        'WHERE precio_unitario IS NULL',
      );
      await db.rawUpdate(
        'UPDATE venta_items SET subtotal = 0 '
        'WHERE subtotal IS NULL',
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error reparando valores NULL: $e');
    }
  }

  // ============================================================
  // REPARAR EMPRESAS ANTIGUAS
  // ============================================================
  Future<void> _repararEmpresasAntiguas(Database db) async {
    try {
      final empresas = await db.query('empresas', orderBy: 'id ASC');
      if (empresas.isEmpty) {
        return;
      }
      int empresaId;
      final activas = empresas.where((e) => e['activa'] == 1).toList();
      if (activas.isNotEmpty) {
        empresaId = (activas.first['id'] as num).toInt();
      } else {
        empresaId = (empresas.first['id'] as num).toInt();
        await db.update(
          'empresas',
          {'activa': 1},
          where: 'id = ?',
          whereArgs: [empresaId],
        );
      }
      await db.rawUpdate(
        'UPDATE proveedores '
        'SET empresa_id = ? '
        'WHERE empresa_id IS NULL',
        [empresaId],
      );
      await db.rawUpdate(
        'UPDATE almacen '
        'SET empresa_id = ? '
        'WHERE empresa_id IS NULL',
        [empresaId],
      );
      await db.rawUpdate(
        'UPDATE clientes '
        'SET empresa_id = ? '
        'WHERE empresa_id IS NULL',
        [empresaId],
      );
      await db.rawUpdate(
        'UPDATE notas '
        'SET empresa_id = ? '
        'WHERE empresa_id IS NULL',
        [empresaId],
      );
      await db.rawUpdate(
        'UPDATE ventas '
        'SET empresa_id = ? '
        'WHERE empresa_id IS NULL',
        [empresaId],
      );
      await db.rawUpdate(
        'UPDATE alistamientos '
        'SET empresa_id = ? '
        'WHERE empresa_id IS NULL',
        [empresaId],
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error reparando empresas antiguas: $e');
    }
  }

  // ============================================================
  // BUSCAR PRODUCTOS
  // ============================================================
  Future<List<Map<String, dynamic>>> buscarProductosPorEmpresa(
    String query,
    int empresaId,
  ) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT almacen.*,
             proveedores.nombre AS proveedor_nombre
      FROM almacen
      LEFT JOIN proveedores
        ON almacen.proveedor_id = proveedores.id
      WHERE almacen.empresa_id = ?
        AND almacen.nombre LIKE ?
      ORDER BY almacen.nombre
      ''',
      [empresaId, '%$query%'],
    );
  }

  // ============================================================
  // EMPRESAS
  // ============================================================
  Future<int> insertarEmpresa(Map<String, dynamic> empresa) async {
    final db = await instance.database;
    return await db.insert('empresas', empresa);
  }

  Future<List<Map<String, dynamic>>> obtenerEmpresas() async {
    final db = await instance.database;
    return await db.query('empresas', orderBy: 'nombre');
  }

  Future<Map<String, dynamic>?> obtenerEmpresaActiva() async {
    final db = await instance.database;
    final results = await db.query(
      'empresas',
      where: 'activa = ?',
      whereArgs: [1],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> obtenerEmpresaPorId(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'empresas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> activarEmpresa(int id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.update('empresas', {'activa': 0});
      await txn.update(
        'empresas',
        {'activa': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> actualizarEmpresa(int id, Map<String, dynamic> empresa) async {
    final db = await instance.database;
    return await db.update(
      'empresas',
      empresa,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // PROVEEDORES
  // ============================================================
  Future<int> insertarProveedor(Map<String, dynamic> proveedor) async {
    final db = await instance.database;
    return await db.insert('proveedores', proveedor);
  }

  Future<List<Map<String, dynamic>>> obtenerProveedores({
    int? empresaId,
  }) async {
    final db = await instance.database;
    if (empresaId != null) {
      return await db.query(
        'proveedores',
        where: 'empresa_id = ?',
        whereArgs: [empresaId],
        orderBy: 'nombre',
      );
    }
    return await db.query('proveedores', orderBy: 'nombre');
  }

  // ============================================================
  // PRODUCTOS
  // ============================================================
  Future<int?> _obtenerEmpresaIdSegura([int? empresaId]) async {
    if (empresaId != null && empresaId > 0) {
      return empresaId;
    }
    final db = await instance.database;
    final activas = await db.query(
      'empresas',
      columns: ['id'],
      where: 'activa = ?',
      whereArgs: [1],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (activas.isNotEmpty) {
      return (activas.first['id'] as num?)?.toInt();
    }
    final primeras = await db.query(
      'empresas',
      columns: ['id'],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (primeras.isNotEmpty) {
      return (primeras.first['id'] as num?)?.toInt();
    }
    return null;
  }

  Map<String, dynamic> _normalizarProducto(Map<String, dynamic> producto) {
    final data = Map<String, dynamic>.from(producto);
    data['nombre'] = data['nombre']?.toString().trim() ?? '';
    data['descripcion'] = data['descripcion']?.toString() ?? '';
    data['cantidad'] = (data['cantidad'] as num?)?.toInt() ?? 0;
    data['precio_compra'] = (data['precio_compra'] as num?)?.toInt() ?? 0;
    data['precio_venta'] = (data['precio_venta'] as num?)?.toInt() ?? 0;
    data['ruta_foto'] = data['ruta_foto']?.toString() ?? '';
    return data;
  }

  Future<int> insertarProducto(Map<String, dynamic> producto) async {
    final db = await instance.database;
    final data = _normalizarProducto(producto);
    final empresaId = await _obtenerEmpresaIdSegura(
      (data['empresa_id'] as num?)?.toInt(),
    );
    if (empresaId == null) {
      throw Exception(
        'No existe una empresa activa '
        'para guardar el producto.',
      );
    }
    if ((data['nombre'] as String).isEmpty) {
      throw Exception(
        'El nombre del producto '
        'es obligatorio.',
      );
    }
    if ((data['cantidad'] as int) < 0) {
      throw Exception('La cantidad no puede ser negativa.');
    }
    data['empresa_id'] = empresaId;
    return await db.insert('almacen', data);
  }

  Future<int> actualizarProducto(
    int id,
    Map<String, dynamic> producto, {
    int? empresaId,
  }) async {
    final db = await instance.database;
    final actual = await db.query(
      'almacen',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (actual.isEmpty) {
      throw Exception('No se encontró el producto con ID $id.');
    }
    final empresaOriginal = (actual.first['empresa_id'] as num?)?.toInt();
    final empresaFinal = await _obtenerEmpresaIdSegura(
      empresaId ?? empresaOriginal,
    );
    if (empresaFinal == null) {
      throw Exception(
        'No existe una empresa válida '
        'para actualizar el producto.',
      );
    }
    final data = _normalizarProducto(producto);
    if ((data['nombre'] as String).isEmpty) {
      throw Exception(
        'El nombre del producto '
        'es obligatorio.',
      );
    }
    if ((data['cantidad'] as int) < 0) {
      throw Exception('La cantidad no puede ser negativa.');
    }
    data['empresa_id'] = empresaOriginal ?? empresaFinal;
    final filas = await db.update(
      'almacen',
      data,
      where: 'id = ? AND empresa_id = ?',
      whereArgs: [id, data['empresa_id']],
    );
    if (filas == 0) {
      throw Exception(
        'No se pudo actualizar el producto. '
        'El producto no pertenece a la empresa indicada.',
      );
    }
    return filas;
  }

  Future<List<Map<String, dynamic>>> obtenerProductos({int? empresaId}) async {
    final db = await instance.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (empresaId != null) {
      whereClauses.add('almacen.empresa_id = ?');
      whereArgs.add(empresaId);
    }
    final whereString = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';
    return await db.rawQuery('''
      SELECT almacen.*,
             proveedores.nombre AS proveedor_nombre
      FROM almacen
      LEFT JOIN proveedores
        ON almacen.proveedor_id = proveedores.id
      $whereString
      ORDER BY almacen.nombre
      ''', whereArgs);
  }

  Future<Map<String, dynamic>?> obtenerProductoPorId(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'almacen',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> encontrarProductoPorNombre(
    String nombre, {
    int? empresaId,
  }) async {
    final db = await instance.database;
    final whereClauses = <String>['nombre = ?'];
    final whereArgs = <dynamic>[nombre];
    if (empresaId != null) {
      whereClauses.add('empresa_id = ?');
      whereArgs.add(empresaId);
    }
    final results = await db.query(
      'almacen',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ============================================================
  // ELIMINAR PRODUCTO
  // ============================================================
  Future<int> eliminarProducto(int idProducto, {required int empresaId}) async {
    final db = await instance.database;
    if (idProducto <= 0) {
      throw Exception('ID del producto no válido.');
    }
    if (empresaId <= 0) {
      throw Exception('ID de la empresa no válido.');
    }
    final producto = await db.query(
      'almacen',
      columns: ['id', 'empresa_id', 'nombre'],
      where: 'id = ? AND empresa_id = ?',
      whereArgs: [idProducto, empresaId],
      limit: 1,
    );
    if (producto.isEmpty) {
      throw Exception(
        'No se encontró el producto '
        'en la empresa activa.',
      );
    }
    final filasEliminadas = await db.delete(
      'almacen',
      where: 'id = ? AND empresa_id = ?',
      whereArgs: [idProducto, empresaId],
    );
    return filasEliminadas;
  }

  // ============================================================
  // COMPRAR PRODUCTOS A PROVEEDOR
  // ============================================================
  Future<void> comprarProductosProveedor(
    int proveedorId,
    List<Map<String, dynamic>> items, {
    int? empresaId,
  }) async {
    final db = await instance.database;
    final empresaFinal = await _obtenerEmpresaIdSegura(empresaId);
    if (empresaFinal == null) {
      throw Exception(
        'No existe una empresa activa '
        'para registrar la compra.',
      );
    }
    if (items.isEmpty) {
      throw Exception('No hay productos para registrar.');
    }
    await db.transaction((txn) async {
      for (final item in items) {
        final nombre = item['nombre']?.toString() ?? '';
        final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
        final precioCompra = (item['precio_compra'] as num?)?.toInt() ?? 0;
        final precioVenta = (item['precio_venta'] as num?)?.toInt() ?? 0;
        final rutaFoto = item['ruta_foto']?.toString() ?? '';
        final existing = await txn.rawQuery(
          '''
            SELECT *
            FROM almacen
            WHERE nombre = ?
              AND empresa_id = ?
            LIMIT 1
            ''',
          [nombre, empresaFinal],
        );
        if (existing.isNotEmpty) {
          final producto = existing.first;
          final cantidadActual = (producto['cantidad'] as num?)?.toInt() ?? 0;
          final nuevaCantidad = cantidadActual + cantidad;
          await txn.update(
            'almacen',
            {
              'cantidad': nuevaCantidad,
              'precio_compra': precioCompra,
              'precio_venta': precioVenta,
              'ruta_foto': rutaFoto,
              'proveedor_id': proveedorId,
            },
            where: 'id = ?',
            whereArgs: [producto['id']],
          );
        } else {
          await txn.insert('almacen', {
            'empresa_id': empresaFinal,
            'nombre': nombre,
            'descripcion': '',
            'cantidad': cantidad,
            'precio_compra': precioCompra,
            'precio_venta': precioVenta,
            'ruta_foto': rutaFoto,
            'proveedor_id': proveedorId,
          });
        }
      }
    });
  }

  // ============================================================
  // CLIENTES
  // ============================================================
  Future<int> insertarCliente(Map<String, dynamic> cliente) async {
    final db = await instance.database;
    return await db.insert('clientes', cliente);
  }

  Future<int> actualizarCliente(int id, Map<String, dynamic> cliente) async {
    final db = await instance.database;
    return await db.update(
      'clientes',
      cliente,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerClientes({int? empresaId}) async {
    final db = await instance.database;
    if (empresaId != null) {
      return await db.query(
        'clientes',
        where: 'empresa_id = ?',
        whereArgs: [empresaId],
        orderBy: 'nombre',
      );
    }
    return await db.query('clientes', orderBy: 'nombre');
  }

  Future<Map<String, dynamic>?> obtenerClientePorId(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ============================================================
  // NOTAS
  // ============================================================
  Future<int> insertarNota(Map<String, dynamic> nota) async {
    final db = await instance.database;
    return await db.insert('notas', nota);
  }

  Future<int> actualizarNota(int id, Map<String, dynamic> nota) async {
    final db = await instance.database;
    return await db.update('notas', nota, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> obtenerNotas({int? empresaId}) async {
    final db = await instance.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (empresaId != null) {
      whereClauses.add('empresa_id = ?');
      whereArgs.add(empresaId);
    }
    final whereString = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';
    return await db.rawQuery('''
      SELECT *
      FROM notas
      $whereString
      ORDER BY fecha_actualizacion DESC, id DESC
      ''', whereArgs);
  }

  Future<void> eliminarNota(int id) async {
    final db = await instance.database;
    await db.delete('notas', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================================
  // VENTAS
  // ============================================================
  Future<int> insertarVenta(Map<String, dynamic> venta) async {
    final db = await instance.database;
    return await db.insert('ventas', venta);
  }

  Future<int> insertarVentaItem(Map<String, dynamic> ventaItem) async {
    final db = await instance.database;
    return await db.insert('venta_items', ventaItem);
  }

  Future<List<Map<String, dynamic>>> obtenerVentas({
    int? clienteId,
    int? empresaId,
  }) async {
    final db = await instance.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (clienteId != null) {
      whereClauses.add('ventas.cliente_id = ?');
      whereArgs.add(clienteId);
    }
    if (empresaId != null) {
      whereClauses.add('ventas.empresa_id = ?');
      whereArgs.add(empresaId);
    }
    final whereString = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';
    return await db.rawQuery('''
      SELECT ventas.*,
             clientes.nombre AS cliente_nombre
      FROM ventas
      LEFT JOIN clientes
        ON ventas.cliente_id = clientes.id
      $whereString
      ORDER BY fecha DESC
      ''', whereArgs);
  }

  Future<List<Map<String, dynamic>>> obtenerItemsVenta(int ventaId) async {
    final db = await instance.database;
    return await db.query(
      'venta_items',
      where: 'venta_id = ?',
      whereArgs: [ventaId],
    );
  }

  Future<int> eliminarVenta(int idVenta) async {
    final db = await instance.database;
    await db.delete('venta_items', where: 'venta_id = ?', whereArgs: [idVenta]);
    return await db.delete('ventas', where: 'id = ?', whereArgs: [idVenta]);
  }

  // ============================================================
  // ELIMINAR VENTA Y RESTAURAR INVENTARIO
  // ============================================================
  Future<void> eliminarVentaYRestaurarInventario(int idVenta) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final ventaRes = await txn.query(
        'ventas',
        where: 'id = ?',
        whereArgs: [idVenta],
        limit: 1,
      );
      if (ventaRes.isNotEmpty) {
        final venta = ventaRes.first;
        final clienteId = (venta['cliente_id'] as num?)?.toInt();
        final total = (venta['total'] as num?)?.toInt() ?? 0;
        final pagado = (venta['pagado'] as num?)?.toInt() ?? 0;
        final deudaGenerada = total > pagado ? total - pagado : 0;
        if (clienteId != null && deudaGenerada > 0) {
          await txn.rawUpdate(
            '''
              UPDATE clientes
              SET deuda_total =
                CASE
                  WHEN deuda_total - ? < 0
                    THEN 0
                  ELSE deuda_total - ?
                END
              WHERE id = ?
              ''',
            [deudaGenerada, deudaGenerada, clienteId],
          );
        }
      }
      final detalles = await txn.query(
        'venta_items',
        where: 'venta_id = ?',
        whereArgs: [idVenta],
      );
      for (final item in detalles) {
        final productoId = (item['producto_id'] as num?)?.toInt();
        final cantidadVendida = (item['cantidad'] as num?)?.toInt() ?? 0;
        if (productoId == null) {
          continue;
        }
        await txn.rawUpdate(
          '''
            UPDATE almacen
            SET cantidad = cantidad + ?
            WHERE id = ?
            ''',
          [cantidadVendida, productoId],
        );
      }
      await txn.delete(
        'venta_items',
        where: 'venta_id = ?',
        whereArgs: [idVenta],
      );
      await txn.delete('ventas', where: 'id = ?', whereArgs: [idVenta]);
    });
  }

  // ============================================================
  // REGISTRAR VENTA
  // ============================================================
  Future<void> registrarVenta(
    int total,
    List<Map<String, dynamic>> carrito, {
    int? clienteId,
    int pagado = 0,
    int? empresaId,
  }) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final ventaId = await txn.insert('ventas', {
        'empresa_id': empresaId,
        'cliente_id': clienteId,
        'total': total,
        'pagado': pagado,
        'fecha': DateTime.now().toIso8601String(),
      });
      for (final item in carrito) {
        final idProducto =
            num.tryParse(item['id']?.toString() ?? '')?.toInt() ?? 0;
        final cantidadVendida =
            num.tryParse(item['cantidad_vendida']?.toString() ?? '')?.toInt() ??
            0;
        final precioUnitario =
            num.tryParse(item['precio']?.toString() ?? '')?.toInt() ?? 0;
        final subtotal =
            num.tryParse(item['subtotal']?.toString() ?? '')?.toInt() ?? 0;
        if (idProducto == 0 || cantidadVendida <= 0) {
          continue;
        }
        final productoActual = await txn.query(
          'almacen',
          where: 'id = ?',
          whereArgs: [idProducto],
          limit: 1,
        );
        if (productoActual.isEmpty) {
          throw Exception(
            'No se encontró el '
            'producto en inventario.',
          );
        }
        final cantidadActual =
            int.tryParse(productoActual.first['cantidad']?.toString() ?? '0') ??
            0;
        if (cantidadActual < cantidadVendida) {
          throw Exception(
            'Inventario insuficiente '
            'para ${item['nombre']}.',
          );
        }
        final cantidadRestante = cantidadActual - cantidadVendida;
        await txn.insert('venta_items', {
          'venta_id': ventaId,
          'producto_id': idProducto,
          'cantidad': cantidadVendida,
          'precio_unitario': precioUnitario,
          'subtotal': subtotal,
        });
        await txn.update(
          'almacen',
          {'cantidad': cantidadRestante},
          where: 'id = ?',
          whereArgs: [idProducto],
        );
      }
      if (clienteId != null) {
        final deudaExtra = total > pagado ? total - pagado : 0;
        if (deudaExtra > 0) {
          await txn.rawUpdate(
            '''
              UPDATE clientes
              SET deuda_total =
                COALESCE(deuda_total, 0) + ?
              WHERE id = ?
              ''',
            [deudaExtra, clienteId],
          );
        }
      }
    });
  }

  // ============================================================
  // UTILIDAD
  // ============================================================
  Future<int> obtenerUtilidadMes(int year, int month, {int? empresaId}) async {
    final db = await instance.database;
    final monthStart = DateTime(year, month, 1).toIso8601String();
    final monthEnd = DateTime(year, month + 1, 1).toIso8601String();
    final whereClauses = <String>['ventas.fecha >= ?', 'ventas.fecha < ?'];
    final whereArgs = <dynamic>[monthStart, monthEnd];
    if (empresaId != null) {
      whereClauses.add('ventas.empresa_id = ?');
      whereArgs.add(empresaId);
    }
    final rows = await db.rawQuery('''
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
      WHERE ${whereClauses.join(' AND ')}
      ''', whereArgs);
    final util = rows.first['utilidad'];
    if (util == null) {
      return 0;
    }
    return (util as num).toInt();
  }

  Future<int> obtenerUtilidadTotal({int? empresaId}) async {
    final db = await instance.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (empresaId != null) {
      whereClauses.add('ventas.empresa_id = ?');
      whereArgs.add(empresaId);
    }
    final whereString = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';
    final rows = await db.rawQuery('''
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
      $whereString
      ''', whereArgs);
    final util = rows.first['utilidad'];
    if (util == null) {
      return 0;
    }
    return (util as num).toInt();
  }

  // ============================================================
  // ALISTAMIENTOS
  // ============================================================
  Future<int> insertarAlistamiento(Map<String, dynamic> alistamiento) async {
    final db = await instance.database;
    return await db.insert('alistamientos', alistamiento);
  }

  Future<List<Map<String, dynamic>>> obtenerAlistamientos({
    int? empresaId,
  }) async {
    final db = await instance.database;
    if (empresaId != null) {
      return await db.query(
        'alistamientos',
        where: 'empresa_id = ?',
        whereArgs: [empresaId],
        orderBy: 'id DESC',
      );
    }
    return await db.query('alistamientos', orderBy: 'id DESC');
  }

  Future<int> eliminarAlistamiento(int id) async {
    final db = await instance.database;
    return await db.delete('alistamientos', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================================
  // COPIA DE SEGURIDAD AUTOMÁTICA - TODOS LOS DÍAS A LAS 02:00
  // ============================================================
  //
  // IMPORTANTE:
  // Este programador funciona mientras el proceso de Flutter de la app
  // esté vivo. Si Android cierra completamente la app, para ejecutar
  // una tarea con la app cerrada hace falta un programador del sistema
  // (por ejemplo WorkManager/AlarmManager).
  //
  // La ventaja de este método es que:
  //   - usa SIEMPRE el mismo archivo;
  //   - lo sobrescribe;
  //   - no crea una copia nueva cada día;
  //   - si se abre la app después de las 02:00, hace la copia pendiente.
  // ============================================================

  void _iniciarProgramadorCopiaAutomatica() {
    if (_schedulerIniciado) {
      return;
    }

    _schedulerIniciado = true;
    _backupTimer?.cancel();

    // Al abrir la aplicación: si hoy ya pasaron las 02:00 y todavía no
    // existe la copia del día, se crea inmediatamente. En caso contrario,
    // se programa exactamente para las 02:00.
    _programarSiguienteCopiaAutomatica();
  }

  void _programarSiguienteCopiaAutomatica() {
    if (!_schedulerIniciado) {
      return;
    }

    _backupTimer?.cancel();

    final ahora = DateTime.now();
    var proxima = DateTime(ahora.year, ahora.month, ahora.day, 2, 0, 0);

    // Si las 02:00 de hoy ya pasaron, la siguiente ejecución será mañana.
    if (!proxima.isAfter(ahora)) {
      proxima = DateTime(ahora.year, ahora.month, ahora.day + 1, 2, 0, 0);
    }

    final demora = proxima.difference(ahora);

    _backupTimer = Timer(demora, () async {
      await _comprobarCopiaAutomatica(forzarHoy: true);
      _programarSiguienteCopiaAutomatica();
    });

    // Si ya pasaron las 02:00 y no hay copia de hoy, no esperamos a mañana.
    if (ahora.hour >= 2) {
      _comprobarCopiaAutomatica();
    }
  }

  Future<void> _comprobarCopiaAutomatica({bool forzarHoy = false}) async {
    if (_backupEnProceso) {
      return;
    }

    try {
      final ahora = DateTime.now();

      // Antes de las 02:00 no se crea la copia todavía.
      if (ahora.hour < 2) {
        return;
      }

      final dbPath = await getDatabasesPath();
      final backupPath = join(dbPath, 'backup_ventas_automatico.db');
      final backupFile = File(backupPath);

      // Una sola copia por día. Cuando el temporizador llega a las 02:00
      // usamos forzarHoy para documentar que es la ejecución programada,
      // pero aun así protegemos contra ejecuciones duplicadas.
      if (!forzarHoy && await backupFile.exists()) {
        final ultimaModificacion = await backupFile.lastModified();
        final esDeHoy =
            ultimaModificacion.year == ahora.year &&
            ultimaModificacion.month == ahora.month &&
            ultimaModificacion.day == ahora.day;

        if (esDeHoy) {
          return;
        }
      }

      if (await backupFile.exists()) {
        final ultimaModificacion = await backupFile.lastModified();
        final esDeHoy =
            ultimaModificacion.year == ahora.year &&
            ultimaModificacion.month == ahora.month &&
            ultimaModificacion.day == ahora.day;

        if (esDeHoy) {
          return;
        }
      }

      _backupEnProceso = true;

      final resultado = await _crearCopiaAutomaticaEnRuta(backupPath);

      if (resultado) {
        // ignore: avoid_print
        print('COPIA AUTOMÁTICA OK: $backupPath');
      } else {
        // ignore: avoid_print
        print(
          'COPIA AUTOMÁTICA NO CREADA. Se intentará en la próxima ejecución.',
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('ERROR EN COPIA AUTOMÁTICA: $e');
    } finally {
      _backupEnProceso = false;
    }
  }

  Future<bool> _crearCopiaAutomaticaEnRuta(String backupPath) async {
    try {
      final db = await instance.database;

      if (!db.isOpen) {
        return false;
      }

      // Asegurar que WAL pase sus datos a la base principal.
      try {
        await db.execute('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}

      // Comprobar integridad antes de respaldar.
      final integrity = await db.rawQuery('PRAGMA integrity_check');

      if (integrity.isNotEmpty) {
        final resultado = integrity.first.values.first?.toString();

        if (resultado != 'ok') {
          // ignore: avoid_print
          print(
            'Copia automática cancelada: '
            'SQLite detectó un problema: $resultado',
          );
          return false;
        }
      }

      final dbPath = await getDatabasesPath();
      final databasePath = join(dbPath, 'ventas_app.db');

      final databaseFile = File(databasePath);

      if (!await databaseFile.exists()) {
        return false;
      }

      final bytes = await databaseFile.readAsBytes();

      if (bytes.isEmpty) {
        return false;
      }

      // Crear primero un archivo temporal.
      // Así la copia anterior permanece intacta si algo falla.
      final tempPath = '$backupPath.tmp';
      final tempFile = File(tempPath);

      await tempFile.writeAsBytes(bytes, flush: true);

      // Validar cabecera SQLite del archivo temporal.
      final cabeceraBytes = await tempFile.openRead(0, 16).fold<List<int>>(
        <int>[],
        (anterior, actual) {
          anterior.addAll(actual);
          return anterior;
        },
      );

      if (cabeceraBytes.length < 16) {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        return false;
      }

      final cabecera = String.fromCharCodes(cabeceraBytes);

      if (!cabecera.startsWith('SQLite format 3')) {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        return false;
      }

      // Sobrescribir la única copia existente.
      final backupFile = File(backupPath);

      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      await tempFile.rename(backupPath);

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error creando copia automática: $e');
      return false;
    }
  }

  // ============================================================
  // HACER COPIA DE SEGURIDAD
  // ============================================================
  Future<String> hacerCopiaDeSeguridad() async {
    try {
      final db = await instance.database;
      if (!db.isOpen) {
        return 'ERROR\n\nLa base de datos no está abierta.';
      }

      // ----------------------------------------------------------
      // Guardar cualquier dato pendiente de SQLite
      // ----------------------------------------------------------
      try {
        await db.execute('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}

      // ----------------------------------------------------------
      // Comprobar integridad
      // ----------------------------------------------------------
      final integrity = await db.rawQuery('PRAGMA integrity_check');
      if (integrity.isNotEmpty) {
        final resultado = integrity.first.values.first?.toString();
        if (resultado != 'ok') {
          return 'ERROR\n\n'
              'SQLite detectó un problema de integridad:\n'
              '$resultado';
        }
      }

      // ----------------------------------------------------------
      // Ruta de la base de datos
      // ----------------------------------------------------------
      final dbPath = await getDatabasesPath();
      final databasePath = join(dbPath, 'ventas_app.db');
      final databaseFile = File(databasePath);
      if (!await databaseFile.exists()) {
        return 'ERROR\n\n'
            'No se encontró la base de datos.';
      }

      // ----------------------------------------------------------
      // Leer bytes ANTES de abrir el selector de archivos
      // ----------------------------------------------------------
      final bytes = await databaseFile.readAsBytes();
      if (bytes.isEmpty) {
        return 'ERROR\n\n'
            'La base de datos está vacía.';
      }

      // ----------------------------------------------------------
      // Nombre de archivo
      // ----------------------------------------------------------
      final ahora = DateTime.now();
      final fecha =
          '${ahora.year}_'
          '${ahora.month.toString().padLeft(2, '0')}_'
          '${ahora.day.toString().padLeft(2, '0')}_'
          '${ahora.hour.toString().padLeft(2, '0')}_'
          '${ahora.minute.toString().padLeft(2, '0')}_'
          '${ahora.second.toString().padLeft(2, '0')}';
      final nombreArchivo = 'backup_ventas_$fecha.db';

      // ----------------------------------------------------------
      // Elegir ubicación.
      // IMPORTANTE: en Android (Scoped Storage), la ruta que devuelve
      // saveFile() no es un path utilizable con dart:io.File. Hay que
      // pasarle los `bytes` para que el propio plugin escriba el
      // archivo mediante SAF (Storage Access Framework).
      // ----------------------------------------------------------
      final rutaElegida = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar copia de seguridad',
        fileName: nombreArchivo,
        bytes: Platform.isAndroid ? bytes : null,
      );

      if (rutaElegida == null || rutaElegida.trim().isEmpty) {
        return 'Operación cancelada.';
      }

      // ----------------------------------------------------------
      // ANDROID: el plugin ya escribió el archivo con `bytes`.
      // No se puede reabrir con File() porque la ruta puede ser un
      // content:// URI, así que confirmamos con lo que ya sabemos.
      // ----------------------------------------------------------
      if (Platform.isAndroid) {
        return 'COPIA EXITOSA\n\n'
            'La copia fue guardada correctamente.\n\n'
            'Archivo:\n'
            '$rutaElegida\n\n'
            'Tamaño: ${bytes.length} bytes';
      }

      // ----------------------------------------------------------
      // WINDOWS / LINUX / MACOS: aquí sí tenemos una ruta real,
      // escribimos el archivo nosotros mismos y lo verificamos.
      // ----------------------------------------------------------
      String rutaFinal = rutaElegida.trim();
      if (!rutaFinal.toLowerCase().endsWith('.db')) {
        rutaFinal = '$rutaFinal.db';
      }

      final backupFile = File(rutaFinal);
      await backupFile.writeAsBytes(bytes, flush: true);

      if (!await backupFile.exists()) {
        return 'ERROR\n\n'
            'El archivo no fue creado.';
      }
      final tamano = await backupFile.length();
      if (tamano <= 0) {
        return 'ERROR\n\n'
            'El archivo creado está vacío.';
      }

      // ----------------------------------------------------------
      // Verificar cabecera SQLite
      // ----------------------------------------------------------
      final cabeceraBytes = await backupFile.openRead(0, 16).fold<List<int>>(
        <int>[],
        (anterior, actual) {
          anterior.addAll(actual);
          return anterior;
        },
      );
      if (cabeceraBytes.length < 16) {
        return 'ERROR\n\n'
            'El archivo de copia está incompleto.';
      }
      final cabecera = String.fromCharCodes(cabeceraBytes);
      if (!cabecera.startsWith('SQLite format 3')) {
        return 'ERROR\n\n'
            'La copia generada no es una base SQLite válida.';
      }

      return 'COPIA EXITOSA\n\n'
          'La copia fue guardada correctamente.\n\n'
          'Archivo:\n'
          '$rutaFinal\n\n'
          'Tamaño: $tamano bytes';
    } catch (e) {
      return 'ERROR AL CREAR LA COPIA\n\n'
          '$e';
    }
  }

  // ============================================================
  // RESTAURAR COPIA DE SEGURIDAD
  // ============================================================
  Future<String> restaurarCopiaDeSeguridad() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Selecciona la copia de seguridad',
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        return 'Operación cancelada.';
      }
      final backupFilePath = result.files.single.path!;
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        return 'No se encontró el archivo seleccionado.';
      }
      final primerosBytes = await backupFile.openRead(0, 16).fold<List<int>>(
        <int>[],
        (anterior, actual) {
          anterior.addAll(actual);
          return anterior;
        },
      );
      if (primerosBytes.length < 16) {
        return 'El archivo es demasiado pequeño '
            'para ser una base de datos SQLite.';
      }
      final cabecera = String.fromCharCodes(primerosBytes);
      if (!cabecera.startsWith('SQLite format 3')) {
        return 'El archivo seleccionado NO es '
            'una base de datos SQLite válida.';
      }

      // ----------------------------------------------------------
      // CERRAR BASE ACTUAL
      // ----------------------------------------------------------
      await _closeDatabase();
      final dbPath = await getDatabasesPath();
      final databasePath = join(dbPath, 'ventas_app.db');
      final databaseFile = File(databasePath);
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }
      final walFile = File('$databasePath-wal');
      final shmFile = File('$databasePath-shm');
      if (await walFile.exists()) {
        await walFile.delete();
      }
      if (await shmFile.exists()) {
        await shmFile.delete();
      }

      // ----------------------------------------------------------
      // COPIAR RESPALDO
      // ----------------------------------------------------------
      await backupFile.copy(databasePath);

      // ----------------------------------------------------------
      // ABRIR NUEVA BASE
      // ----------------------------------------------------------
      _database = await _initDB('ventas_app.db');
      final db = _database!;

      // ----------------------------------------------------------
      // INTEGRIDAD
      // ----------------------------------------------------------
      final integrity = await db.rawQuery('PRAGMA integrity_check');
      if (integrity.isNotEmpty) {
        final resultado = integrity.first.values.first?.toString();
        if (resultado != 'ok') {
          return 'La copia fue encontrada, pero '
              'SQLite detectó un problema de integridad:\n'
              '$resultado';
        }
      }

      // ----------------------------------------------------------
      // CONTAR INFORMACIÓN
      // ----------------------------------------------------------
      final empresas = await db.rawQuery(
        'SELECT COUNT(*) AS total '
        'FROM empresas',
      );
      final productos = await db.rawQuery(
        'SELECT COUNT(*) AS total '
        'FROM almacen',
      );
      final clientes = await db.rawQuery(
        'SELECT COUNT(*) AS total '
        'FROM clientes',
      );
      final ventas = await db.rawQuery(
        'SELECT COUNT(*) AS total '
        'FROM ventas',
      );
      final proveedores = await db.rawQuery(
        'SELECT COUNT(*) AS total '
        'FROM proveedores',
      );
      final notas = await db.rawQuery(
        'SELECT COUNT(*) AS total '
        'FROM notas',
      );
      final totalEmpresas = (empresas.first['total'] as num?)?.toInt() ?? 0;
      final totalProductos = (productos.first['total'] as num?)?.toInt() ?? 0;
      final totalClientes = (clientes.first['total'] as num?)?.toInt() ?? 0;
      final totalVentas = (ventas.first['total'] as num?)?.toInt() ?? 0;
      final totalProveedores =
          (proveedores.first['total'] as num?)?.toInt() ?? 0;
      final totalNotas = (notas.first['total'] as num?)?.toInt() ?? 0;
      return '''
RESTAURACIÓN EXITOSA
La copia de seguridad fue restaurada correctamente.
━━━━━━━━━━━━━━━━━━━━
DATOS RESTAURADOS
━━━━━━━━━━━━━━━━━━━━
Empresas: $totalEmpresas
Productos: $totalProductos
Clientes: $totalClientes
Proveedores: $totalProveedores
Ventas: $totalVentas
Notas: $totalNotas
━━━━━━━━━━━━━━━━━━━━
Archivo:
$backupFilePath
''';
    } catch (e) {
      try {
        await _closeDatabase();
      } catch (_) {}
      return 'ERROR AL RESTAURAR\n\n$e';
    }
  }

  // ============================================================
  // CERRAR BASE DE DATOS
  // ============================================================
  Future<String?> _closeDatabase() async {
    _backupTimer?.cancel();
    _backupTimer = null;
    _schedulerIniciado = false;

    if (_database != null) {
      try {
        await _database!.close();
      } catch (e) {
        return 'Error cerrando base de datos: $e';
      }
      _database = null;
    }
    return null;
  }

  // ============================================================
  // MÉTODO PÚBLICO PARA CERRAR LA BASE
  // ============================================================
  Future<String?> cerrarDatabase() async {
    return await _closeDatabase();
  }
}
