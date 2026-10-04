import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../db/database_helper.dart';

class PantallaNotas extends StatefulWidget {
  final Map<String, dynamic> empresaActiva;

  const PantallaNotas({super.key, required this.empresaActiva});

  @override
  State<PantallaNotas> createState() => _PantallaNotasState();
}

class _PantallaNotasState extends State<PantallaNotas> {
  final List<Map<String, dynamic>> _notas = [];

  final TextEditingController _tituloController = TextEditingController();

  final TextEditingController _contenidoController = TextEditingController();

  final TextEditingController _numeroController = TextEditingController();

  final TextEditingController _buscarController = TextEditingController();

  int? _notaEditandoId;

  String? _imagenBase64;

  bool _cargando = true;
  bool _guardando = false;

  String _busqueda = '';

  // ============================================================
  // COLORES
  // ============================================================

  static const Color fondo = Color(0xFFF4F6FB);
  static const Color azul = Color(0xFF3949AB);
  static const Color morado = Color(0xFF7E57C2);

  // ============================================================
  // INICIO
  // ============================================================

  @override
  void initState() {
    super.initState();

    _buscarController.addListener(() {
      if (!mounted) return;

      setState(() {
        _busqueda = _buscarController.text.trim().toLowerCase();
      });
    });

    _cargarNotas();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    _numeroController.dispose();
    _buscarController.dispose();

    super.dispose();
  }

  // ============================================================
  // EMPRESA
  // ============================================================

  int? _obtenerEmpresaId() {
    final valor = widget.empresaActiva['id'];

    if (valor is int) return valor;

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor?.toString() ?? '');
  }

  // ============================================================
  // CARGAR NOTAS
  // ============================================================

  Future<void> _cargarNotas() async {
    try {
      final empresaId = _obtenerEmpresaId();

      if (empresaId == null) {
        throw Exception('Empresa no identificada');
      }

      final notas = await DatabaseHelper.instance.obtenerNotas(
        empresaId: empresaId,
      );

      if (!mounted) return;

      setState(() {
        _notas
          ..clear()
          ..addAll(notas);

        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
      });

      _mostrarMensaje('No se pudieron cargar las notas.', error: true);
    }
  }

  // ============================================================
  // LIMPIAR
  // ============================================================

  void _limpiarFormulario() {
    _tituloController.clear();
    _contenidoController.clear();
    _numeroController.clear();

    _imagenBase64 = null;
    _notaEditandoId = null;
  }

  // ============================================================
  // IMAGEN
  // ============================================================

  Future<void> _seleccionarImagen() async {
    try {
      final picker = ImagePicker();

      final foto = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (foto == null) return;

      final bytes = await foto.readAsBytes();

      if (!mounted) return;

      setState(() {
        _imagenBase64 = base64Encode(bytes);
      });
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('No se pudo cargar la imagen.', error: true);
    }
  }

  // ============================================================
  // FORMULARIO
  // ============================================================

  Future<void> _mostrarFormularioNota({Map<String, dynamic>? nota}) async {
    if (nota != null) {
      _tituloController.text = nota['titulo']?.toString() ?? '';

      _contenidoController.text = nota['contenido']?.toString() ?? '';

      _numeroController.text = nota['numero']?.toString() ?? '';

      _imagenBase64 = nota['imagen_base64']?.toString();

      _notaEditandoId = int.tryParse(nota['id'].toString());
    } else {
      _limpiarFormulario();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalBuilderContext, setModalState) {
            final tieneImagen =
                _imagenBase64 != null && _imagenBase64!.isNotEmpty;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalContext).size.height * 0.92,
                ),
                decoration: const BoxDecoration(
                  color: fondo,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    // ==================================================
                    // CABECERA
                    // ==================================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 14, 8),
                      child: Column(
                        children: [
                          Container(
                            width: 45,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [azul, morado],
                                  ),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: const Icon(
                                  Icons.edit_note_rounded,
                                  color: Colors.white,
                                  size: 29,
                                ),
                              ),

                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nota == null
                                          ? 'Nueva nota'
                                          : 'Editar nota',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      nota == null
                                          ? 'Guarda una nueva idea'
                                          : 'Modifica tu nota',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(
                                tooltip: 'Cerrar',
                                onPressed: () {
                                  Navigator.pop(modalContext);
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ==================================================
                    // CONTENIDO SCROLL
                    // ==================================================
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ==================================================
                            // TITULO
                            // ==================================================
                            TextField(
                              controller: _tituloController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: _decoracionCampo(
                                'Título',
                                'Ej: Pendientes de hoy',
                                Icons.title_rounded,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ==================================================
                            // CONTENIDO
                            // ==================================================
                            TextField(
                              controller: _contenidoController,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                              minLines: 6,
                              maxLines: 12,
                              decoration: _decoracionCampo(
                                'Contenido',
                                'Escribe aquí todo lo que necesites...',
                                Icons.notes_rounded,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ==================================================
                            // NUMERO
                            // ==================================================
                            TextField(
                              controller: _numeroController,
                              keyboardType: TextInputType.number,
                              decoration: _decoracionCampo(
                                'Número',
                                'Cantidad o referencia',
                                Icons.numbers_rounded,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ==================================================
                            // IMAGEN
                            // ==================================================
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: 0.035,
                                    ),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(17),
                                    child: tieneImagen
                                        ? Image.memory(
                                            base64Decode(_imagenBase64!),
                                            height: 190,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) {
                                              return _imagenError(190);
                                            },
                                          )
                                        : Container(
                                            height: 145,
                                            width: double.infinity,
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color(0xFFE8EAF6),
                                                  Color(0xFFF3E5F5),
                                                ],
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 58,
                                                  height: 58,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.8),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.image_outlined,
                                                    color: azul,
                                                    size: 30,
                                                  ),
                                                ),
                                                const SizedBox(height: 9),
                                                Text(
                                                  'Sin imagen',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),

                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _guardando
                                              ? null
                                              : () async {
                                                  await _seleccionarImagen();

                                                  if (mounted) {
                                                    setModalState(() {});
                                                  }
                                                },
                                          icon: Icon(
                                            tieneImagen
                                                ? Icons.change_circle_outlined
                                                : Icons
                                                      .add_photo_alternate_outlined,
                                          ),
                                          label: Text(
                                            tieneImagen
                                                ? 'Cambiar'
                                                : 'Agregar imagen',
                                          ),
                                        ),
                                      ),

                                      if (tieneImagen) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: 'Eliminar imagen',
                                          onPressed: _guardando
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _imagenBase64 = null;
                                                  });

                                                  setModalState(() {});
                                                },
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.red
                                                .withValues(alpha: 0.08),
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            // ==================================================
                            // GUARDAR
                            // ==================================================
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton.icon(
                                onPressed: _guardando
                                    ? null
                                    : () async {
                                        await _guardarNota(modalContext);
                                      },
                                icon: _guardando
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(
                                  _guardando ? 'Guardando...' : 'Guardar nota',
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted) {
      _limpiarFormulario();
    }
  }

  // ============================================================
  // GUARDAR
  // ============================================================

  Future<void> _guardarNota(BuildContext modalContext) async {
    if (_guardando) return;

    final titulo = _tituloController.text.trim();

    final contenido = _contenidoController.text.trim();

    final numero = int.tryParse(_numeroController.text.trim()) ?? 0;

    final imagen = _imagenBase64 ?? '';

    if (titulo.isEmpty && contenido.isEmpty && numero == 0 && imagen.isEmpty) {
      _mostrarMensaje('Escribe algo antes de guardar.', error: true);
      return;
    }

    final empresaId = _obtenerEmpresaId();

    if (empresaId == null) {
      _mostrarMensaje('No se pudo identificar la empresa.', error: true);
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      final ahora = DateTime.now().toIso8601String();

      final editando = _notaEditandoId != null;

      if (editando) {
        await DatabaseHelper.instance.actualizarNota(_notaEditandoId!, {
          'empresa_id': empresaId,
          'titulo': titulo,
          'contenido': contenido,
          'numero': numero,
          'imagen_base64': imagen.isEmpty ? null : imagen,
          'fecha_actualizacion': ahora,
        });
      } else {
        await DatabaseHelper.instance.insertarNota({
          'empresa_id': empresaId,
          'titulo': titulo,
          'contenido': contenido,
          'numero': numero,
          'imagen_base64': imagen.isEmpty ? null : imagen,
          'fecha_creacion': ahora,
          'fecha_actualizacion': ahora,
        });
      }

      if (!mounted) return;

      // ignore: use_build_context_synchronously
      Navigator.of(modalContext).pop();

      await _cargarNotas();

      if (!mounted) return;

      _mostrarMensaje(
        editando
            ? 'Nota actualizada correctamente.'
            : 'Nota creada correctamente.',
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('No se pudo guardar la nota.', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  // ============================================================
  // ELIMINAR
  // ============================================================

  Future<void> _eliminarNota(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.red),
              SizedBox(width: 10),
              Expanded(child: Text('Eliminar nota')),
            ],
          ),
          content: const Text(
            'La nota se eliminará permanentemente. ¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await DatabaseHelper.instance.eliminarNota(id);

      await _cargarNotas();

      if (!mounted) return;

      _mostrarMensaje('Nota eliminada correctamente.');
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('No se pudo eliminar la nota.', error: true);
    }
  }

  // ============================================================
  // DECORACION
  // ============================================================

  InputDecoration _decoracionCampo(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: azul, width: 2),
      ),
    );
  }

  // ============================================================
  // IMAGEN ERROR
  // ============================================================

  Widget _imagenError(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, size: 45, color: Colors.grey),
      ),
    );
  }

  // ============================================================
  // IMAGEN TARJETA
  // ============================================================

  Widget _imagenTarjeta(String imagen) {
    if (imagen.isEmpty) {
      return Container(
        height: 145,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF303F9F), Color(0xFF673AB7), Color(0xFF8E44AD)],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.sticky_note_2_rounded,
            color: Colors.white,
            size: 45,
          ),
        ),
      );
    }

    try {
      return Image.memory(
        base64Decode(imagen),
        height: 145,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return _imagenError(145);
        },
      );
    } catch (_) {
      return _imagenError(145);
    }
  }

  // ============================================================
  // TARJETA
  // ============================================================

  Widget _tarjetaNota(Map<String, dynamic> nota, int index) {
    final titulo = nota['titulo']?.toString().trim() ?? '';

    final contenido = nota['contenido']?.toString().trim() ?? '';

    final numero = nota['numero']?.toString() ?? '0';

    final imagen = nota['imagen_base64']?.toString() ?? '';

    final tieneImagen = imagen.isNotEmpty;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 250 + (index * 35)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _mostrarFormularioNota(nota: nota),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // IMAGEN
                  // ==================================================
                  Stack(
                    children: [
                      _imagenTarjeta(imagen),

                      // Degradado inferior
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 65,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.45),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ==================================================
                      // NUMERO
                      // ==================================================
                      if (numero != '0')
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.numbers_rounded,
                                  size: 14,
                                  color: azul,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  numero,
                                  style: const TextStyle(
                                    color: azul,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ==================================================
                      // MENU
                      // ==================================================
                      Positioned(
                        top: 9,
                        right: 9,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                            shape: BoxShape.circle,
                          ),
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onSelected: (opcion) {
                              if (opcion == 'editar') {
                                _mostrarFormularioNota(nota: nota);
                              }

                              if (opcion == 'eliminar') {
                                final id = int.tryParse(nota['id'].toString());

                                if (id != null) {
                                  _eliminarNota(id);
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'editar',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded),
                                    SizedBox(width: 10),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'eliminar',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ==================================================
                  // INFORMACION
                  // ==================================================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título
                        Text(
                          titulo.isEmpty ? 'Nota sin título' : titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        // Contenido
                        if (contenido.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            contenido,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.8,
                              height: 1.3,
                            ),
                          ),
                        ],

                        const SizedBox(height: 11),

                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: azul.withValues(alpha: 0.09),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color: azul,
                              ),
                            ),

                            const Spacer(),

                            if (tieneImagen)
                              Icon(
                                Icons.image_rounded,
                                size: 17,
                                color: Colors.grey.shade400,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
            Expanded(
              child: Text(
                mensaje,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

    final notasFiltradas = _notas.where((nota) {
      if (_busqueda.isEmpty) {
        return true;
      }

      final titulo = nota['titulo']?.toString().toLowerCase() ?? '';

      final contenido = nota['contenido']?.toString().toLowerCase() ?? '';

      final numero = nota['numero']?.toString().toLowerCase() ?? '';

      return titulo.contains(_busqueda) ||
          contenido.contains(_busqueda) ||
          numero.contains(_busqueda);
    }).toList();

    return Scaffold(
      backgroundColor: fondo,

      // ==========================================================
      // APP BAR
      // ==========================================================
      appBar: AppBar(
        elevation: 0,
        backgroundColor: fondo,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis notas',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            Text(
              empresa,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
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
              onPressed: _cargando ? null : _cargarNotas,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),

      // ==========================================================
      // BOTON
      // ==========================================================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioNota(),
        elevation: 8,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nueva nota',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // ==========================================================
      // BODY
      // ==========================================================
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarNotas,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ==================================================
                  // CABECERA
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 18),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF303F9F),
                              Color(0xFF673AB7),
                              Color(0xFF8E44AD),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: azul.withValues(alpha: 0.22),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tu espacio de ideas',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _notas.isEmpty
                                        ? 'Crea tu primera nota'
                                        : '${_notas.length} ${_notas.length == 1 ? 'nota guardada' : 'notas guardadas'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ==================================================
                  // BUSCADOR
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.035),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _buscarController,
                          decoration: InputDecoration(
                            hintText: 'Buscar notas...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: azul,
                            ),
                            suffixIcon: _busqueda.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _buscarController.clear();
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 22)),

                  // ==================================================
                  // TITULO
                  // ==================================================
                  if (notasFiltradas.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Text(
                              'Tus notas',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: azul.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${notasFiltradas.length}',
                                style: const TextStyle(
                                  color: azul,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // ==================================================
                  // CUADRICULA
                  // ==================================================
                  if (notasFiltradas.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _tarjetaNota(notasFiltradas[index], index);
                        }, childCount: notasFiltradas.length),

                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 360,
                              mainAxisExtent: 315,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                      ),
                    )
                  // ==================================================
                  // SIN RESULTADOS
                  // ==================================================
                  else
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 105,
                                height: 105,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [azul, morado],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.sticky_note_2_rounded,
                                  size: 52,
                                  color: Colors.white,
                                ),
                              ),

                              const SizedBox(height: 20),

                              Text(
                                _busqueda.isNotEmpty
                                    ? 'No encontramos notas'
                                    : 'Todavía no tienes notas',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                _busqueda.isNotEmpty
                                    ? 'Prueba con otra palabra.'
                                    : 'Crea una nota para guardar ideas, recordatorios o información importante.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                ),
                              ),

                              if (_busqueda.isEmpty) ...[
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: () => _mostrarFormularioNota(),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Crear primera nota'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
