import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../widgets/location_picker.dart';

/// Datos del restaurante que ven los clientes: nombre, teléfono, dirección y
/// ubicación exacta. Devuelve `true` al guardar.
class RestaurantProfileView extends StatefulWidget {
  const RestaurantProfileView({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  State<RestaurantProfileView> createState() => _RestaurantProfileViewState();
}

class _RestaurantProfileViewState extends State<RestaurantProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.restaurant.name);
  late final _phone = TextEditingController(text: widget.restaurant.phone);
  // Restaurantes registrados antes de separar la dirección solo tienen el
  // texto libre: va en "Calle y número" para que completen lo demás.
  late final _street = TextEditingController(
      text:
          widget.restaurant.addressParts?.street ?? widget.restaurant.address);
  late final _neighborhood =
      TextEditingController(text: widget.restaurant.addressParts?.neighborhood);
  late final _city =
      TextEditingController(text: widget.restaurant.addressParts?.city);
  late final _postalCode =
      TextEditingController(text: widget.restaurant.addressParts?.postalCode);
  late GeoPoint? _location = widget.restaurant.location;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _street,
      _neighborhood,
      _city,
      _postalCode
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  RestaurantAddress get _address => RestaurantAddress(
        street: _street.text,
        neighborhood: _neighborhood.text,
        city: _city.text,
        postalCode: _postalCode.text,
      );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      await context.read<FirestoreService>().updateRestaurant(
            restaurantId: widget.restaurant.id,
            name: _name.text,
            address: _address,
            location: _location,
            phone: _phone.text,
          );
      if (mounted) Navigator.pop(context, true);
    } on RescueException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      debugPrint('updateRestaurant: $e');
      _showMessage('No se pudieron guardar los cambios. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String? _required(String? value, String message) =>
      (value?.trim().isEmpty ?? true) ? message : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget field(
      TextEditingController controller,
      String label,
      IconData icon, {
      String? Function(String?)? validator,
      TextInputType? keyboardType,
      TextCapitalization capitalization = TextCapitalization.words,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: controller,
            readOnly: _saving,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            textInputAction: TextInputAction.next,
            // Se ve en vivo cómo quedará la dirección.
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              border: const OutlineInputBorder(),
            ),
            validator: validator,
          ),
        );

    final preview = _address.full;

    return Scaffold(
      appBar: AppBar(title: const Text('Datos del restaurante')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            field(_name, 'Nombre del restaurante', Icons.storefront_outlined,
                validator: (v) => _required(v, 'Ingresa el nombre.')),
            field(_phone, 'Teléfono (opcional)', Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            Text('Dirección para recoger', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            field(_street, 'Calle y número', Icons.place_outlined,
                validator: (v) =>
                    _required(v, 'Ingresa la calle y el número.')),
            field(_neighborhood, 'Colonia', Icons.holiday_village_outlined,
                validator: (v) => _required(v, 'Ingresa la colonia.')),
            field(_city, 'Ciudad y estado', Icons.location_city_outlined,
                validator: (v) => _required(v, 'Ingresa la ciudad.')),
            field(_postalCode, 'Código postal (opcional)',
                Icons.markunread_mailbox_outlined,
                keyboardType: TextInputType.number),
            if (preview.isNotEmpty) ...[
              Text('Los clientes verán:', style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(preview, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
            ],
            LocationPicker(
              value: _location,
              enabled: !_saving,
              onChanged: (p) => setState(() => _location = p),
            ),
            const SizedBox(height: 8),
            Text(
              'Los paquetes que tienes publicados también se actualizan.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Guardar'),
          ),
        ),
      ),
    );
  }
}
