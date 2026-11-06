import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Lee el GPS del celular. Lanza [LocationException] con un mensaje para el
/// usuario si no hay permiso o el GPS está apagado.
Future<GeoPoint> currentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationException(
        'Activa la ubicación (GPS) del celular e intenta de nuevo.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const LocationException('Sin permiso de ubicación.');
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationException(
        'El permiso de ubicación está bloqueado. Actívalo en Ajustes.');
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );
  return GeoPoint(position.latitude, position.longitude);
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// "Usar mi ubicación actual": guarda las coordenadas exactas del local para
/// que Maps lleve al cliente al punto preciso. Es opcional.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.locate = currentLocation,
  });

  final GeoPoint? value;
  final ValueChanged<GeoPoint?> onChanged;
  final bool enabled;

  /// Inyectable para pruebas.
  final Future<GeoPoint> Function() locate;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  bool _locating = false;
  String? _error;

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final point = await widget.locate();
      if (mounted) widget.onChanged(point);
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('GPS: $e');
      if (mounted) {
        setState(() => _error = 'No se pudo obtener la ubicación. '
            'Intenta de nuevo cerca de una ventana o afuera.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final saved = widget.value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (saved)
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ubicación exacta guardada',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: widget.enabled && !_locating
                    ? () => widget.onChanged(null)
                    : null,
                child: const Text('Quitar'),
              ),
            ],
          ),
        OutlinedButton.icon(
          onPressed: widget.enabled && !_locating ? _locate : null,
          icon: _locating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          label: Text(_locating
              ? 'Obteniendo ubicación…'
              : saved
                  ? 'Volver a tomar mi ubicación'
                  : 'Usar mi ubicación actual'),
        ),
        const SizedBox(height: 4),
        Text(
          _error ??
              'Opcional. Hazlo estando en el local: así Maps lleva al cliente '
                  'al punto exacto.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: _error != null ? colors.error : null),
        ),
      ],
    );
  }
}
