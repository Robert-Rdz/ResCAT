import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/firestore_service.dart';

/// Edita un paquete ya publicado. Devuelve `true` si se guardó.
///
/// La foto y el análisis de IA no se editan aquí: para otra foto se publica
/// un paquete nuevo.
class EditPackageView extends StatefulWidget {
  const EditPackageView({super.key, required this.package});

  final FoodPackage package;

  @override
  State<EditPackageView> createState() => _EditPackageViewState();
}

class _EditPackageViewState extends State<EditPackageView> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.package.name);
  late final _description =
      TextEditingController(text: widget.package.description);
  late final _originalPrice =
      TextEditingController(text: _price(widget.package.originalPrice));
  late final _discountedPrice =
      TextEditingController(text: _price(widget.package.discountedPrice));
  late final _quantity =
      TextEditingController(text: '${widget.package.availableQuantity}');

  /// Cantidad que había en Firestore al abrir (o tras el último aviso).
  late int _expectedQuantity = widget.package.availableQuantity;
  late bool _isActive = widget.package.isActive;
  bool _saving = false;
  String? _error;

  static final _priceFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'));

  static String _price(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  static double? _parsePrice(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _originalPrice,
      _discountedPrice,
      _quantity,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<FirestoreService>().updatePackage(
            packageId: widget.package.id,
            name: _name.text,
            description: _description.text,
            originalPrice: _parsePrice(_originalPrice.text)!,
            discountedPrice: _parsePrice(_discountedPrice.text)!,
            availableQuantity: int.parse(_quantity.text),
            expectedQuantity: _expectedQuantity,
            isActive: _isActive,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on QuantityChangedException catch (e) {
      if (!mounted) return;
      // Se muestra la cantidad real para que el restaurante decida.
      setState(() {
        _expectedQuantity = e.currentQuantity;
        _quantity.text = '${e.currentQuantity}';
        _error = '${e.message} Ahora quedan ${e.currentQuantity}.';
      });
    } on RescueException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('updatePackage: $e');
      if (mounted) {
        setState(() => _error = 'No se pudo guardar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar paquete')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Escribe un nombre.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descripción'),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _originalPrice,
                    decoration: const InputDecoration(
                        labelText: 'Precio original', prefixText: r'$ '),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_priceFormatter],
                    validator: (v) {
                      final p = _parsePrice(v ?? '');
                      return p == null || p <= 0 ? 'Precio inválido.' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _discountedPrice,
                    decoration: const InputDecoration(
                        labelText: 'Precio de rescate', prefixText: r'$ '),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_priceFormatter],
                    validator: (v) {
                      final p = _parsePrice(v ?? '');
                      final original = _parsePrice(_originalPrice.text);
                      if (p == null || p < 0) return 'Precio inválido.';
                      if (original != null && p >= original) {
                        return 'Debe ser menor al original.';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantity,
              decoration: const InputDecoration(
                labelText: 'Cantidad disponible',
                helperText: 'Los apartados ya hechos no se modifican.',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final q = int.tryParse(v ?? '');
                if (q == null) return 'Escribe una cantidad.';
                if (_isActive && q == 0) {
                  return 'Pon al menos 1 o desactiva "Visible".';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible para clientes'),
              subtitle: Text(_isActive
                  ? 'Aparece en "Disponibles".'
                  : 'Retirado: los clientes no lo ven.'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
