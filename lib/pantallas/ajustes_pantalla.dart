import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';

class PantallaAjustes extends StatefulWidget {
  final Map<String, dynamic> empresaActiva;
  final VoidCallback onCambiarEmpresa;

  const PantallaAjustes({
    super.key,
    required this.empresaActiva,
    required this.onCambiarEmpresa,
  });

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  bool _procesando = false;

  String _nombreEmpresa = '';
  String _rutaLogo = '';

  @override
  void initState() {
    super.initState();
    _cargarDatosEmpresa();
  }

  void _cargarDatosEmpresa() {
    _nombreEmpresa = widget.empresaActiva['nombre']?.toString() ?? '';

    _rutaLogo = widget.empresaActiva['logo_ruta']?.toString() ?? '';
  }

  int? _obtenerEmpresaId() {
    final valor = widget.empresaActiva['id'];

    if (valor is int) return valor;
    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor?.toString() ?? '');
  }

  // ============================================================
  // NOMBRE
  // ============================================================

  Future<void> _cambiarNombreEmpresa() async {
    if (_procesando) return;

    final empresaId = _obtenerEmpresaId();

    if (empresaId == null || empresaId <= 0) {
      _mostrarResultado('No se pudo identificar la empresa.', error: true);
      return;
    }

    final controller = TextEditingController(text: _nombreEmpresa);

    try {
      final nuevoNombre = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _cabeceraDialogo(
                    icono: Icons.edit_rounded,
                    titulo: 'Cambiar nombre',
                    color: Colors.indigo,
                    onCerrar: () {
                      Navigator.pop(dialogContext);
                    },
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nombre del negocio',
                      hintText: 'Escribe el nuevo nombre',
                      prefixIcon: const Icon(Icons.storefront_outlined),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            final nombre = controller.text.trim();

                            if (nombre.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'El nombre no puede estar vacío.',
                                  ),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(dialogContext, nombre);
                          },
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Guardar'),
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

      if (nuevoNombre == null || nuevoNombre.trim().isEmpty || !mounted) {
        return;
      }

      setState(() {
        _procesando = true;
      });

      final filas = await DatabaseHelper.instance.actualizarEmpresa(empresaId, {
        'nombre': nuevoNombre.trim(),
      });

      if (filas <= 0) {
        throw Exception('No se pudo actualizar el nombre.');
      }

      if (!mounted) return;

      setState(() {
        _nombreEmpresa = nuevoNombre.trim();
        _procesando = false;
      });

      _mostrarResultado('Nombre actualizado correctamente.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _procesando = false;
      });

      _mostrarResultado('Error cambiando el nombre:\n$e', error: true);
    } finally {
      controller.dispose();
    }
  }

  // ============================================================
  // LOGO
  // ============================================================

  Future<void> _cambiarLogoEmpresa() async {
    if (_procesando) return;

    final empresaId = _obtenerEmpresaId();

    if (empresaId == null || empresaId <= 0) {
      _mostrarResultado('No se pudo identificar la empresa.', error: true);
      return;
    }

    try {
      final resultado = await FilePicker.platform.pickFiles(
        dialogTitle: 'Selecciona el logo del negocio',
        type: FileType.image,
        allowMultiple: false,
      );

      if (resultado == null || resultado.files.isEmpty) {
        return;
      }

      final ruta = resultado.files.single.path;

      if (ruta == null || ruta.trim().isEmpty) {
        _mostrarResultado(
          'No se pudo obtener la ubicación de la imagen.',
          error: true,
        );
        return;
      }

      final archivo = File(ruta);

      if (!await archivo.exists()) {
        _mostrarResultado('La imagen seleccionada no existe.', error: true);
        return;
      }

      setState(() {
        _procesando = true;
      });

      final filas = await DatabaseHelper.instance.actualizarEmpresa(empresaId, {
        'logo_ruta': ruta,
      });

      if (filas <= 0) {
        throw Exception('No se pudo guardar el logo.');
      }

      if (!mounted) return;

      setState(() {
        _rutaLogo = ruta;
        _procesando = false;
      });

      _mostrarResultado('Logo actualizado correctamente.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _procesando = false;
      });

      _mostrarResultado('Error colocando el logo:\n$e', error: true);
    }
  }

  // ============================================================
  // QUITAR LOGO
  // ============================================================

  Future<void> _quitarLogoEmpresa() async {
    if (_procesando) return;

    final empresaId = _obtenerEmpresaId();

    if (empresaId == null || empresaId <= 0) {
      _mostrarResultado('No se pudo identificar la empresa.', error: true);
      return;
    }

    final confirmar = await _confirmarAccion(
      titulo: 'Quitar logo',
      mensaje: '¿Deseas quitar el logo de este negocio?',
      color: Colors.red,
      icono: Icons.delete_outline_rounded,
      textoBoton: 'Quitar',
    );

    if (confirmar != true || !mounted) {
      return;
    }

    try {
      setState(() {
        _procesando = true;
      });

      final filas = await DatabaseHelper.instance.actualizarEmpresa(empresaId, {
        'logo_ruta': '',
      });

      if (filas <= 0) {
        throw Exception('No se pudo quitar el logo.');
      }

      if (!mounted) return;

      setState(() {
        _rutaLogo = '';
        _procesando = false;
      });

      _mostrarResultado('Logo eliminado correctamente.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _procesando = false;
      });

      _mostrarResultado('Error quitando el logo:\n$e', error: true);
    }
  }

  // ============================================================
  // EXPORTAR
  // ============================================================

  Future<void> _exportarCopia() async {
    if (_procesando) return;

    setState(() {
      _procesando = true;
    });

    _mostrarCargando('Creando copia de seguridad...');

    String resultado;

    try {
      resultado = await DatabaseHelper.instance.hacerCopiaDeSeguridad();
    } catch (e) {
      resultado = 'Error al crear la copia de seguridad:\n$e';
    }

    if (!mounted) return;

    _cerrarDialogoCarga();

    setState(() {
      _procesando = false;
    });

    _mostrarResultado(
      resultado,
      error: resultado.toLowerCase().contains('error'),
    );
  }

  // ============================================================
  // IMPORTAR
  // ============================================================

  Future<void> _importarCopia() async {
    if (_procesando) return;

    final confirmar = await _confirmarAccion(
      titulo: 'Restaurar copia',
      mensaje:
          'La restauración reemplazará la información actual por '
          'la información de la copia de seguridad.\n\n'
          '¿Deseas continuar?',
      color: Colors.orange,
      icono: Icons.cloud_download_rounded,
      textoBoton: 'Restaurar',
    );

    if (confirmar != true || !mounted) {
      return;
    }

    setState(() {
      _procesando = true;
    });

    _mostrarCargando('Restaurando copia de seguridad...');

    String resultado;

    try {
      resultado = await DatabaseHelper.instance.restaurarCopiaDeSeguridad();
    } catch (e) {
      resultado = 'Error al restaurar la copia de seguridad:\n$e';
    }

    if (!mounted) return;

    _cerrarDialogoCarga();

    setState(() {
      _procesando = false;
    });

    final texto = resultado.toLowerCase();

    final exitosa =
        texto.contains('restauración completa') ||
        texto.contains('restauración exitosa');

    _mostrarResultado(resultado, error: !exitosa);

    if (exitosa) {
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      widget.onCambiarEmpresa();
    }
  }

  // ============================================================
  // CAMBIAR EMPRESA
  // ============================================================

  Future<void> _cambiarNegocio() async {
    if (_procesando) return;

    final confirmar = await _confirmarAccion(
      titulo: 'Cambiar de negocio',
      mensaje: 'Volverás al selector de empresas para elegir otro negocio.',
      color: Colors.indigo,
      icono: Icons.swap_horiz_rounded,
      textoBoton: 'Cambiar',
    );

    if (confirmar == true && mounted) {
      widget.onCambiarEmpresa();
    }
  }

  // ============================================================
  // DIALOGOS
  // ============================================================

  Widget _cabeceraDialogo({
    required IconData icono,
    required String titulo,
    required Color color,
    required VoidCallback onCerrar,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icono, color: color),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),

        IconButton(onPressed: onCerrar, icon: const Icon(Icons.close_rounded)),
      ],
    );
  }

  Future<bool?> _confirmarAccion({
    required String titulo,
    required String mensaje,
    required Color color,
    required IconData icono,
    required String textoBoton,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(titulo)),
            ],
          ),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () => Navigator.pop(ctx, true),
              icon: Icon(icono),
              label: Text(textoBoton),
            ),
          ],
        );
      },
    );
  }

  void _mostrarCargando(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Row(
            children: [
              const SizedBox(
                width: 27,
                height: 27,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _cerrarDialogoCarga() {
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
  }

  void _mostrarResultado(String mensaje, {bool error = false}) {
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
  // LOGO
  // ============================================================

  Widget _widgetLogo() {
    if (_rutaLogo.isNotEmpty) {
      final archivo = File(_rutaLogo);

      if (archivo.existsSync()) {
        return Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.indigo.withValues(alpha: 0.15),
              width: 3,
            ),
            image: DecorationImage(
              image: FileImage(archivo),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade400],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.storefront_rounded,
        size: 42,
        color: Colors.white,
      ),
    );
  }

  // ============================================================
  // TARJETA ACCIÓN
  // ============================================================

  Widget _tarjetaAccion({
    required IconData icono,
    required Color color,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, color: color),
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
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final tieneLogo = _rutaLogo.isNotEmpty && File(_rutaLogo).existsSync();

    final empresaId = widget.empresaActiva['id']?.toString() ?? 'Sin ID';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      body: AbsorbPointer(
        absorbing: _procesando,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            // ==================================================
            // EMPRESA
            // ==================================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade700, Colors.indigo.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _widgetLogo(),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NEGOCIO ACTIVO',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _nombreEmpresa.isNotEmpty
                              ? _nombreEmpresa
                              : 'Negocio sin nombre',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'ID: $empresaId',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Perfil del negocio',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 9),

            _tarjetaAccion(
              icono: Icons.edit_rounded,
              color: Colors.indigo,
              titulo: 'Cambiar nombre',
              descripcion: 'Modifica el nombre de tu negocio',
              onTap: _cambiarNombreEmpresa,
            ),

            _tarjetaAccion(
              icono: Icons.image_outlined,
              color: Colors.blue,
              titulo: 'Cambiar logo',
              descripcion: 'Selecciona una nueva imagen para tu negocio',
              onTap: _cambiarLogoEmpresa,
            ),

            if (tieneLogo)
              _tarjetaAccion(
                icono: Icons.delete_outline_rounded,
                color: Colors.red,
                titulo: 'Quitar logo',
                descripcion: 'Eliminar el logo actual',
                onTap: _quitarLogoEmpresa,
              ),

            const SizedBox(height: 15),

            const Text(
              'Copias de seguridad',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 9),

            _tarjetaAccion(
              icono: Icons.cloud_upload_rounded,
              color: Colors.green,
              titulo: 'Crear copia',
              descripcion: 'Guarda toda la información de la aplicación',
              onTap: _exportarCopia,
            ),

            _tarjetaAccion(
              icono: Icons.cloud_download_rounded,
              color: Colors.blue,
              titulo: 'Restaurar copia',
              descripcion: 'Recupera información desde una copia',
              onTap: _importarCopia,
            ),

            const SizedBox(height: 15),

            const Text(
              'Cuenta y negocio',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 9),

            _tarjetaAccion(
              icono: Icons.swap_horiz_rounded,
              color: Colors.orange,
              titulo: 'Cambiar de negocio',
              descripcion: 'Selecciona otra empresa',
              onTap: _cambiarNegocio,
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                'App de Ventas',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
