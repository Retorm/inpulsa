import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../db/database_helper.dart';

class PantallaInicioEmpresa extends StatefulWidget {
  final void Function(Map<String, dynamic>) onEmpresaSeleccionada;

  const PantallaInicioEmpresa({super.key, required this.onEmpresaSeleccionada});

  @override
  State<PantallaInicioEmpresa> createState() => _PantallaInicioEmpresaState();
}

class _PantallaInicioEmpresaState extends State<PantallaInicioEmpresa> {
  final _nombreController = TextEditingController();

  File? _logoSeleccionado;

  bool _isLoading = false;
  bool _cargandoEmpresas = true;

  List<Map<String, dynamic>> _empresas = [];

  // ============================================================
  // COLORES
  // ============================================================

  static const Color azulOscuro = Color(0xFF172554);
  static const Color azul = Color(0xFF2563EB);
  static const Color azulClaro = Color(0xFF60A5FA);
  static const Color fondo = Color(0xFFF4F7FF);

  @override
  void initState() {
    super.initState();
    _cargarEmpresas();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  // ============================================================
  // CARGAR EMPRESAS
  // ============================================================

  Future<void> _cargarEmpresas() async {
    try {
      final empresas = await DatabaseHelper.instance.obtenerEmpresas();

      if (!mounted) return;

      setState(() {
        _empresas = empresas;
        _cargandoEmpresas = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargandoEmpresas = false;
      });

      _mostrarMensaje('No se pudieron cargar los negocios.', error: true);
    }
  }

  // ============================================================
  // OBTENER ID
  // ============================================================

  int? _obtenerIdEmpresa(Map<String, dynamic> empresa) {
    final valor = empresa['id'];

    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor?.toString() ?? '');
  }

  // ============================================================
  // SELECCIONAR LOGO
  // ============================================================

  Future<void> _seleccionarLogo() async {
    if (_isLoading) return;

    try {
      final picker = ImagePicker();

      final foto = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (foto == null || !mounted) return;

      setState(() {
        _logoSeleccionado = File(foto.path);
      });
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('No se pudo seleccionar la imagen.', error: true);
    }
  }

  // ============================================================
  // QUITAR LOGO
  // ============================================================

  void _quitarLogoSeleccionado() {
    if (_isLoading) return;

    setState(() {
      _logoSeleccionado = null;
    });
  }

  // ============================================================
  // CREAR EMPRESA
  // ============================================================

  Future<void> _guardarEmpresa() async {
    if (_isLoading) return;

    final nombre = _nombreController.text.trim();

    if (nombre.isEmpty) {
      _mostrarMensaje('Escribe el nombre del negocio.', error: true);
      return;
    }

    if (nombre.length < 2) {
      _mostrarMensaje('El nombre es demasiado corto.', error: true);
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final empresaId = await DatabaseHelper.instance.insertarEmpresa({
        'nombre': nombre,
        'logo_ruta': _logoSeleccionado?.path ?? '',
        'activa': 0,
      });

      await DatabaseHelper.instance.activarEmpresa(empresaId);

      final empresa = await DatabaseHelper.instance.obtenerEmpresaPorId(
        empresaId,
      );

      if (!mounted) return;

      if (empresa != null) {
        widget.onEmpresaSeleccionada(empresa);
        return;
      }

      throw Exception('No se pudo recuperar el negocio creado.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _mostrarMensaje('No se pudo crear el negocio.', error: true);
    }
  }

  // ============================================================
  // SELECCIONAR EMPRESA
  // ============================================================

  Future<void> _seleccionarEmpresaExistente(
    Map<String, dynamic> empresa,
  ) async {
    if (_isLoading) return;

    final empresaId = _obtenerIdEmpresa(empresa);

    if (empresaId == null || empresaId <= 0) {
      _mostrarMensaje('No se pudo identificar este negocio.', error: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseHelper.instance.activarEmpresa(empresaId);

      final empresaActiva = await DatabaseHelper.instance.obtenerEmpresaPorId(
        empresaId,
      );

      if (!mounted) return;

      if (empresaActiva == null) {
        throw Exception('No se pudo cargar el negocio seleccionado.');
      }

      widget.onEmpresaSeleccionada(empresaActiva);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _mostrarMensaje('No se pudo abrir el negocio.', error: true);
    }
  }

  // ============================================================
  // FORMULARIO CREAR
  // ============================================================

  void _mostrarFormularioCrear() {
    if (_isLoading) return;

    _nombreController.clear();

    setState(() {
      _logoSeleccionado = null;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 35,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ICONO
                      Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [azul, Color(0xFF4F46E5)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.add_business_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Crear nuevo negocio',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: azulOscuro,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        'Personaliza tu negocio para comenzar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),

                      const SizedBox(height: 25),

                      // LOGO
                      GestureDetector(
                        onTap: () async {
                          await _seleccionarLogo();

                          if (mounted) {
                            setDialogState(() {});
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    azul.withValues(alpha: 0.08),
                                    azulClaro.withValues(alpha: 0.15),
                                  ],
                                ),
                                border: Border.all(
                                  color: azul.withValues(alpha: 0.20),
                                  width: 2,
                                ),
                              ),
                              child: _logoSeleccionado != null
                                  ? ClipOval(
                                      child: Image.file(
                                        _logoSeleccionado!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.storefront_rounded,
                                      size: 55,
                                      color: azul,
                                    ),
                            ),

                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: const BoxDecoration(
                                  color: azul,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        _logoSeleccionado == null
                            ? 'Agregar logo'
                            : 'Logo seleccionado',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),

                      if (_logoSeleccionado != null)
                        TextButton.icon(
                          onPressed: () {
                            _quitarLogoSeleccionado();

                            setDialogState(() {});
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Quitar logo'),
                        ),

                      const SizedBox(height: 15),

                      TextField(
                        controller: _nombreController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: 'Nombre del negocio',
                          hintText: 'Ej. Mi tienda',
                          prefixIcon: const Icon(Icons.storefront_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF7F8FC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: azul, width: 2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _nombreController.text.trim().isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(dialogContext).pop();

                                      _guardarEmpresa();
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: azul,
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              icon: const Icon(Icons.rocket_launch_rounded),
                              label: const Text(
                                'Crear negocio',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
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
  // LOGO EMPRESA
  // ============================================================

  Widget _logoEmpresa(Map<String, dynamic> empresa, {double size = 74}) {
    final ruta = empresa['logo_ruta']?.toString().trim() ?? '';

    if (ruta.isNotEmpty) {
      final archivo = File(ruta);

      if (archivo.existsSync()) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(
              archivo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return _logoGenerico(size);
              },
            ),
          ),
        );
      }
    }

    return _logoGenerico(size);
  }

  Widget _logoGenerico(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: azul.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        Icons.storefront_rounded,
        size: size * 0.45,
        color: Colors.white,
      ),
    );
  }

  // ============================================================
  // TARJETA EMPRESA
  // ============================================================

  Widget _tarjetaEmpresa(Map<String, dynamic> empresa) {
    final nombre = empresa['nombre']?.toString().trim().isNotEmpty == true
        ? empresa['nombre'].toString()
        : 'Negocio sin nombre';

    final id = _obtenerIdEmpresa(empresa);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _isLoading
              ? null
              : () => _seleccionarEmpresaExistente(empresa),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _logoEmpresa(empresa, size: 76),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: azulOscuro,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Listo para entrar',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      if (id != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Negocio #$id',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [azul, Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  // FONDO DECORATIVO
  // ============================================================

  Widget _fondoDecorativo() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEEF4FF), Color(0xFFF8FAFF), Color(0xFFEFF6FF)],
            ),
          ),
        ),

        Positioned(
          top: -130,
          right: -100,
          child: Container(
            width: 330,
            height: 330,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: azul.withValues(alpha: 0.09),
            ),
          ),
        ),

        Positioned(
          top: 220,
          left: -160,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: azulClaro.withValues(alpha: 0.08),
            ),
          ),
        ),

        Positioned(
          bottom: -180,
          right: -80,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.indigo.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: fondo,

      body: Stack(
        children: [
          _fondoDecorativo(),

          SafeArea(
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 30,
                    ),
                    child: Column(
                      children: [
                        // ==================================================
                        // LOGO PRINCIPAL
                        // ==================================================
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [azul, Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: azul.withValues(alpha: 0.28),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ==================================================
                        // TITULO
                        // ==================================================
                        Text(
                          'Bienvenido',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: azulOscuro,
                            letterSpacing: -0.8,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Administra tus negocios desde un solo lugar',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 35),

                        // ==================================================
                        // NEGOCIOS
                        // ==================================================
                        if (_cargandoEmpresas)
                          Container(
                            padding: const EdgeInsets.all(45),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const CircularProgressIndicator(),
                          )
                        else if (_empresas.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: azul.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.business_rounded,
                                  color: azul,
                                  size: 20,
                                ),
                              ),

                              const SizedBox(width: 10),

                              const Text(
                                'Tus negocios',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: azulOscuro,
                                ),
                              ),

                              const Spacer(),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: azul,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_empresas.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          ..._empresas.map(_tarjetaEmpresa),

                          const SizedBox(height: 8),
                        ] else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.store_mall_directory_outlined,
                                  size: 55,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Aún no tienes negocios',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Crea tu primer negocio para comenzar.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 18),

                        // ==================================================
                        // CREAR NEGOCIO
                        // ==================================================
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [azul, Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(23),
                            boxShadow: [
                              BoxShadow(
                                color: azul.withValues(alpha: 0.22),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(23),
                              onTap: _mostrarFormularioCrear,
                              child: Padding(
                                padding: const EdgeInsets.all(19),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.add_business_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),

                                    const SizedBox(width: 15),

                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Crear nuevo negocio',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Añade otro negocio y mantén sus datos separados.',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // ==================================================
                        // SEGURIDAD
                        // ==================================================
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 17,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Información guardada localmente',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        Text(
                          'Selecciona un negocio para continuar',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ============================================================
      // CARGANDO
      // ============================================================
      bottomNavigationBar: _isLoading
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Abriendo negocio...',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
