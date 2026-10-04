import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db/database_helper.dart';
import 'pantallas/almacen_pantalla.dart';
import 'pantallas/ventas_pantalla.dart';
import 'pantallas/notas_pantalla.dart';
import 'pantallas/clientes_pantalla.dart';
import 'pantallas/pyg_pantalla.dart';
import 'pantallas/ajustes_pantalla.dart';
import 'pantallas/empresa_inicio_pantalla.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MiAppVentas());
}

class MiAppVentas extends StatelessWidget {
  const MiAppVentas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App de Ventas',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeWrapper(),
    );
  }
}

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  Map<String, dynamic>? _empresaActiva;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarEmpresaActiva();
  }

  Future<void> _cargarEmpresaActiva() async {
    final empresa = await DatabaseHelper.instance.obtenerEmpresaActiva();
    if (!mounted) return;
    setState(() {
      _empresaActiva = empresa;
      _isLoading = false;
    });
  }

  void _alSeleccionarEmpresa(Map<String, dynamic> empresa) {
    setState(() {
      _empresaActiva = empresa;
    });
  }

  void _cambiarEmpresa() {
    setState(() {
      _empresaActiva = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_empresaActiva == null) {
      return PantallaInicioEmpresa(
        onEmpresaSeleccionada: _alSeleccionarEmpresa,
      );
    }

    return PantallaPrincipal(
      empresaActiva: _empresaActiva!,
      onCambiarEmpresa: _cambiarEmpresa,
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  final Map<String, dynamic> empresaActiva;
  final VoidCallback onCambiarEmpresa;

  const PantallaPrincipal({
    super.key,
    required this.empresaActiva,
    required this.onCambiarEmpresa,
  });

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0;
  final ValueNotifier<int> _ventaSignal = ValueNotifier<int>(0);

  late final List<Widget> _pantallas;

  @override
  void initState() {
    super.initState();
    _pantallas = [
      PantallaVentas(
        empresaActiva: widget.empresaActiva,
        onVentaRegistrada: () => _ventaSignal.value++,
      ),
      PantallaAlmacen(empresaActiva: widget.empresaActiva),
      PantallaClientes(empresaActiva: widget.empresaActiva),
      PantallaPyG(
        empresaActiva: widget.empresaActiva,
        refreshSignal: _ventaSignal,
      ),
      PantallaNotas(empresaActiva: widget.empresaActiva),
      PantallaAjustes(
        empresaActiva: widget.empresaActiva,
        onCambiarEmpresa: widget.onCambiarEmpresa,
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant PantallaPrincipal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.empresaActiva['id'] != widget.empresaActiva['id']) {
      _pantallas[0] = PantallaVentas(
        empresaActiva: widget.empresaActiva,
        onVentaRegistrada: () => _ventaSignal.value++,
      );
      _pantallas[1] = PantallaAlmacen(empresaActiva: widget.empresaActiva);
      _pantallas[2] = PantallaClientes(empresaActiva: widget.empresaActiva);
      _pantallas[3] = PantallaPyG(
        empresaActiva: widget.empresaActiva,
        refreshSignal: _ventaSignal,
      );
      _pantallas[4] = PantallaNotas(empresaActiva: widget.empresaActiva);
      _pantallas[5] = PantallaAjustes(
        empresaActiva: widget.empresaActiva,
        onCambiarEmpresa: widget.onCambiarEmpresa,
      );
    }
  }

  @override
  void dispose() {
    _ventaSignal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pantallas[_indiceActual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _indiceActual = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Ventas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'inventario',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'P&G'),
          BottomNavigationBarItem(icon: Icon(Icons.note_alt), label: 'Notas'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class PlaceholderPantalla extends StatelessWidget {
  final String titulo;
  final IconData icono;

  const PlaceholderPantalla({
    super.key,
    required this.titulo,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              'Módulo de $titulo en desarrollo',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
