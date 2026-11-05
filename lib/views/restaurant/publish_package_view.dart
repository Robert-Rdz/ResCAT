import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/analisis_ia.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../../services/storage_service.dart';
import '../widgets/package_card.dart';

/// Devuelve `true` al cerrar si se publicó.
class PublishPackageView extends StatefulWidget {
  const PublishPackageView({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<PublishPackageView> createState() => _PublishPackageViewState();
}

class _PublishPackageViewState extends State<PublishPackageView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  Uint8List? _photoBytes;
  String _photoContentType = 'image/jpeg';
  bool _saving = false;
  String? _error;

  // Análisis de IA.
  bool _analyzing = false;
  AnalisisIA? _analysis;
  String? _analysisError;

  /// Texto que Gemini va escribiendo mientras llega la respuesta.
  String _streamTitle = '';
  String _streamDescription = '';

  /// Gemini estaba saturado y se está reintentando.
  bool _retrying = false;

  /// Descarta respuestas de una foto que ya se cambió o quitó.
  int _analysisRequest = 0;

  /// Últimos textos que puso la IA; si el usuario los editó, no se pisan.
  String _aiName = '';
  String _aiDescription = '';

  static final _priceFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'));

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _descriptionController,
      _originalPriceController,
      _discountedPriceController,
      _quantityController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _parsePrice(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  bool get _usableAnalysis => _analysis?.esComida ?? false;

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        // GeminiService espera la imagen ya reducida.
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoContentType = file.mimeType ?? 'image/jpeg';
        _error = null;
      });
      await _analyze();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la foto.');
    }
  }

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
      _analysisRequest++;
      _analyzing = false;
      _analysis = null;
      _analysisError = null;
    });
  }

  Future<void> _analyze() async {
    final bytes = _photoBytes;
    if (bytes == null) return;
    final request = ++_analysisRequest;
    setState(() {
      _analyzing = true;
      _analysis = null;
      _analysisError = null;
      _streamTitle = '';
      _streamDescription = '';
      _retrying = false;
    });

    try {
      final result = await context.read<GeminiService>().analizarPlatillo(
        bytes,
        onReintento: () {
          if (!mounted || request != _analysisRequest) return;
          setState(() {
            _retrying = true;
            _streamTitle = '';
            _streamDescription = '';
          });
        },
        onAvance: (title, description) {
          if (!mounted || request != _analysisRequest) return;
          if (title == _streamTitle && description == _streamDescription) {
            return;
          }
          setState(() {
            _streamTitle = title;
            _streamDescription = description;
          });
        },
      );
      if (!mounted || request != _analysisRequest) return;
      setState(() {
        _analysis = result;
        if (result.esComida) _applyAnalysis(result);
      });
    } on AnalisisException catch (e) {
      if (mounted && request == _analysisRequest) {
        setState(() => _analysisError = e.mensaje);
      }
    } finally {
      if (mounted && request == _analysisRequest) {
        setState(() => _analyzing = false);
      }
    }
  }

  /// Llena nombre y descripción solo si están vacíos o siguen como los dejó
  /// la IA en un análisis anterior.
  void _applyAnalysis(AnalisisIA a) {
    final name = _nameController.text.trim();
    if (a.titulo.isNotEmpty && (name.isEmpty || name == _aiName)) {
      _nameController.text = a.titulo;
      _aiName = a.titulo;
    }
    final description = _descriptionController.text.trim();
    if (a.descripcion.isNotEmpty &&
        (description.isEmpty || description == _aiDescription)) {
      _descriptionController.text = a.descripcion;
      _aiDescription = a.descripcion;
    }
  }

  void _useSuggestedPrice(double price) {
    setState(() {
      _discountedPriceController.text = price.toStringAsFixed(0);
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });
    final firestore = context.read<FirestoreService>();
    final storage = context.read<StorageService>();
    final analysis = _usableAnalysis ? _analysis : null;

    try {
      String? photoUrl;
      if (_photoBytes != null) {
        photoUrl = await storage.uploadPackagePhoto(
          restaurantId: widget.restaurantId,
          bytes: _photoBytes!,
          contentType: _photoContentType,
        );
      }
      await firestore.publishPackage(
        restaurantId: widget.restaurantId,
        name: _nameController.text,
        description: _descriptionController.text,
        originalPrice: _parsePrice(_originalPriceController.text)!,
        discountedPrice: _parsePrice(_discountedPriceController.text)!,
        availableQuantity: int.parse(_quantityController.text),
        photoUrl: photoUrl,
        allergens: analysis?.alergenos ?? const [],
        category: analysis == null || analysis.categoria.isEmpty
            ? null
            : analysis.categoria,
        perishability: analysis?.perecibilidad.name,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on RescueException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo publicar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validatePrice(String? value) {
    final price = _parsePrice(value ?? '');
    if (price == null) return 'Ingresa un precio.';
    if (price <= 0) return 'Debe ser mayor a 0.';
    return null;
  }

  String? _validateDiscounted(String? value) {
    final error = _validatePrice(value);
    if (error != null) return error;
    final original = _parsePrice(_originalPriceController.text);
    if (original != null && _parsePrice(value!)! >= original) {
      return 'Debe ser menor al precio original.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final original = _parsePrice(_originalPriceController.text);
    final discounted = _parsePrice(_discountedPriceController.text);
    final showDiscount =
        original != null && discounted != null && discounted < original;

    final perishability = _usableAnalysis ? _analysis!.perecibilidad : null;
    final suggested =
        original == null ? null : perishability?.precioSugerido(original);

    final aiHelper = _usableAnalysis
        ? (_analysis!.requiereRevision
            ? 'Sugerido por IA con poca confianza: revísalo'
            : 'Sugerido por IA')
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar excedente')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PhotoPicker(
                    bytes: _photoBytes,
                    onPick: _saving ? null : _choosePhotoSource,
                    onRemove: _saving || _photoBytes == null
                        ? null
                        : _removePhoto,
                  ),
                  if (_photoBytes != null) ...[
                    const SizedBox(height: 12),
                    _AnalysisPanel(
                      analyzing: _analyzing,
                      retrying: _retrying,
                      streamTitle: _streamTitle,
                      streamDescription: _streamDescription,
                      analysis: _analysis,
                      error: _analysisError,
                      onRetry: _saving ? null : _analyze,
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    readOnly: _saving,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nombre del paquete',
                      hintText: 'Bolsa sorpresa de panadería',
                      helperText: _nameController.text == _aiName &&
                              _aiName.isNotEmpty
                          ? aiHelper
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true)
                        ? 'Ingresa un nombre.'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    readOnly: _saving,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      hintText: '¿Qué puede incluir? Alérgenos, porciones…',
                      helperText: _descriptionController.text ==
                                  _aiDescription &&
                              _aiDescription.isNotEmpty
                          ? aiHelper
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _originalPriceController,
                          readOnly: _saving,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [_priceFormatter],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Precio original',
                            prefixText: r'$ ',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validatePrice,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _discountedPriceController,
                          readOnly: _saving,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [_priceFormatter],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Precio rescate',
                            prefixText: r'$ ',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateDiscounted,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (suggested != null && suggested != discounted) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          'Usar precio sugerido: ${formatPrice(suggested)} '
                          '(-${(perishability!.descuentoSugerido * 100).round()}%, '
                          'perecibilidad ${perishability.etiqueta.toLowerCase()})',
                        ),
                        onPressed:
                            _saving ? null : () => _useSuggestedPrice(suggested),
                      ),
                    ),
                  ],
                  if (showDiscount) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Descuento de '
                      '${(((original - discounted) / original) * 100).round()}% · '
                      'el cliente ahorra ${formatPrice(original - discounted)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    readOnly: _saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad disponible',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Ingresa al menos 1.';
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.publish),
                    label: Text(_saving ? 'Publicando…' : 'Publicar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado del análisis de la foto: cargando, error, no es comida o resultado.
class _AnalysisPanel extends StatelessWidget {
  const _AnalysisPanel({
    required this.analyzing,
    required this.retrying,
    required this.streamTitle,
    required this.streamDescription,
    required this.analysis,
    required this.error,
    required this.onRetry,
  });

  final bool analyzing;
  final bool retrying;
  final String streamTitle;
  final String streamDescription;
  final AnalisisIA? analysis;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget body;
    if (analyzing) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(streamTitle.isNotEmpty
              ? 'La IA está escribiendo…'
              : retrying
                  ? 'La IA está tardando más de lo normal, reintentando…'
                  : 'Analizando el platillo con IA…'),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          if (streamTitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(streamTitle, style: theme.textTheme.titleSmall),
          ],
          if (streamDescription.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(streamDescription, style: theme.textTheme.bodySmall),
          ],
        ],
      );
    } else if (error != null) {
      body = _Message(
        icon: Icons.error_outline,
        color: colors.error,
        text: error!,
        onRetry: onRetry,
      );
    } else if (analysis == null) {
      return const SizedBox.shrink();
    } else if (!analysis!.esComida) {
      body = _Message(
        icon: Icons.no_food_outlined,
        color: colors.error,
        text: 'La foto no parece mostrar comida. Toma otra o llena los datos '
            'a mano.',
        onRetry: onRetry,
      );
    } else {
      final a = analysis!;
      final lowConfidence = a.requiereRevision;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Análisis de IA', style: theme.textTheme.titleSmall),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    lowConfidence ? colors.errorContainer : null,
                label: Text(
                  'Confianza ${(a.confianza * 100).round()}%',
                  style: TextStyle(
                    color: lowConfidence ? colors.onErrorContainer : null,
                  ),
                ),
              ),
            ],
          ),
          if (lowConfidence)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'La IA no está segura. Revisa nombre, descripción y alérgenos.',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
          const SizedBox(height: 8),
          _Field(
            label: 'Categoría',
            value: a.categoria.isEmpty ? '—' : a.categoria,
          ),
          _Field(label: 'Perecibilidad', value: a.perecibilidad.etiqueta),
          if (a.ingredientes.isNotEmpty)
            _Field(label: 'Ingredientes', value: a.ingredientes.join(', ')),
          const SizedBox(height: 4),
          Text('Alérgenos', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          a.alergenos.isEmpty
              ? Text('Ninguno detectado', style: theme.textTheme.bodySmall)
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final alergeno in a.alergenos)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.warning_amber, size: 16),
                        label: Text(alergeno),
                      ),
                  ],
                ),
        ],
      );
    }

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(12), child: body),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    required this.text,
    required this.onRetry,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: theme.textTheme.labelMedium),
            TextSpan(text: value, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.bytes,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPick,
          child: bytes == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: 40, color: colors.onSurfaceVariant),
                    const SizedBox(height: 8),
                    const Text('Toma una foto y la IA llena los datos'),
                    const SizedBox(height: 2),
                    Text(
                      'Opcional',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(bytes!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: 'Quitar foto',
                        icon: const Icon(Icons.close),
                        onPressed: onRemove,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
