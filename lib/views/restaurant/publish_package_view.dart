import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/firestore_service.dart';
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

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoContentType = file.mimeType ?? 'image/jpeg';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la foto.');
    }
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
                    onPick: _saving ? null : _pickPhoto,
                    onRemove: _saving || _photoBytes == null
                        ? null
                        : () => setState(() => _photoBytes = null),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    readOnly: _saving,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del paquete',
                      hintText: 'Bolsa sorpresa de panadería',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true)
                        ? 'Ingresa un nombre.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    readOnly: _saving,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: '¿Qué puede incluir? Alérgenos, porciones…',
                      border: OutlineInputBorder(),
                    ),
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
                    const Text('Agregar foto (opcional)'),
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
