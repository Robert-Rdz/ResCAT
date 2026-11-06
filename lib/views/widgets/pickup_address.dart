import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';

/// Google Maps en el punto exacto si hay coordenadas; si no, busca la
/// dirección en texto. Abre la app de Maps si está instalada, o el navegador.
Uri mapsSearchUri(String address, {GeoPoint? location}) => Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': location == null
            ? address
            : '${location.latitude},${location.longitude}',
      },
    );

/// Dónde recoger el pedido; al tocarla se abre en Google Maps.
///
/// Los paquetes y apartados creados antes de 2026-11-05 no traen la
/// dirección; en ese caso se pide el restaurante con [load].
class PickupAddress extends StatefulWidget {
  const PickupAddress({
    super.key,
    required this.address,
    this.location,
    this.load,
    this.openUrl = _openExternal,
  });

  final String address;
  final GeoPoint? location;
  final Future<Restaurant?> Function()? load;

  /// Inyectable para pruebas.
  final Future<bool> Function(Uri) openUrl;

  static Future<bool> _openExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  State<PickupAddress> createState() => _PickupAddressState();
}

class _PickupAddressState extends State<PickupAddress> {
  Future<Restaurant?>? _loading;

  @override
  void initState() {
    super.initState();
    if (widget.address.trim().isEmpty) {
      _loading = widget.load?.call().catchError((_) => null);
    }
  }

  Future<void> _openMaps(String address, GeoPoint? location) async {
    var opened = false;
    try {
      opened = await widget.openUrl(mapsSearchUri(address, location: location));
    } catch (e) {
      debugPrint('Abrir Maps: $e');
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.address.trim().isNotEmpty) {
      return _tappable(widget.address, widget.location);
    }
    return FutureBuilder<Restaurant?>(
      future: _loading,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _row('Cargando dirección…');
        }
        final restaurant = snap.data;
        final address = restaurant?.address.trim() ?? '';
        return address.isEmpty
            ? _row('Dirección no disponible')
            : _tappable(address, restaurant!.location);
      },
    );
  }

  Widget _tappable(String address, GeoPoint? location) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      hint: 'Abrir en Google Maps',
      child: InkWell(
        onTap: () => _openMaps(address, location),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _row(
            'Recoge en $address',
            trailing: Icon(Icons.open_in_new, size: 16, color: colors.primary),
          ),
        ),
      ),
    );
  }

  Widget _row(String text, {Widget? trailing}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.location_on_outlined,
            size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        if (trailing != null) ...[const SizedBox(width: 6), trailing],
      ],
    );
  }
}
