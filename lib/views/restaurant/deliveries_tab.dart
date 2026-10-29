import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../widgets/package_card.dart';

final _time = DateFormat('HH:mm');

/// Entregas del restaurante: captura del PIN que muestra el cliente y lista de
/// apartados pendientes de recoger.
class DeliveriesTab extends StatefulWidget {
  const DeliveriesTab({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<DeliveriesTab> {
  late final FirestoreService _firestore = context.read<FirestoreService>();
  late Stream<List<FoodOrder>> _orders =
      _firestore.watchRestaurantActiveOrders(widget.restaurantId);
  final _pinController = TextEditingController();
  bool _validating = false;
  String? _pinError;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /// Un stream de Firestore se cierra tras un error; para reintentar hay que
  /// crear la consulta de nuevo.
  void _retryOrders() => setState(() {
        _orders = _firestore.watchRestaurantActiveOrders(widget.restaurantId);
      });

  static String _ordersErrorMessage(Object? error) => switch (error) {
        FirebaseException(code: 'failed-precondition') =>
          'El índice de Firestore (restaurantId + status + createdAt) no está '
              'listo.\nDespliégalo o espera a que termine de construirse.',
        FirebaseException(code: 'permission-denied') =>
          'Firestore rechazó la lectura. Revisa las reglas de seguridad.',
        FirebaseException(code: 'unavailable') =>
          'Sin conexión con el servidor.',
        _ => 'No se pudieron cargar los apartados.',
      };

  Future<void> _validate() async {
    if (_validating) return;
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _pinError = 'El PIN debe tener 4 dígitos.');
      return;
    }

    setState(() {
      _validating = true;
      _pinError = null;
    });
    try {
      final order = await _firestore.validatePinAndDeliver(
        restaurantId: widget.restaurantId,
        pin: pin,
      );
      if (!mounted) return;
      _pinController.clear();
      await showDialog<void>(
        context: context,
        builder: (_) => _DeliveredDialog(order: order),
      );
    } on RescueException catch (e) {
      if (mounted) setState(() => _pinError = e.message);
    } catch (e) {
      debugPrint('validatePinAndDeliver: $e');
      if (mounted) {
        setState(() => _pinError = 'No se pudo validar el PIN. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Validar entrega', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Captura el PIN de 4 dígitos que te muestra el cliente.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    enabled: !_validating,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '0000',
                      border: const OutlineInputBorder(),
                      errorText: _pinError,
                    ),
                    onChanged: (_) {
                      if (_pinError != null) setState(() => _pinError = null);
                    },
                    onSubmitted: (_) => _validate(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _validating ? null : _validate,
                    icon: _validating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: const Text('Validar y entregar'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FoodOrder>>(
            stream: _orders,
            builder: (context, snapshot) {
              // Al reintentar, el snapshot conserva el error anterior hasta que
              // llega el primer evento; se muestra la carga mientras tanto.
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                debugPrint('watchRestaurantActiveOrders: ${snapshot.error}');
                return EmptyState(
                  icon: Icons.cloud_off_outlined,
                  message: _ordersErrorMessage(snapshot.error),
                  action: OutlinedButton.icon(
                    onPressed: _retryOrders,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data!;
              if (orders.isEmpty) {
                return const EmptyState(
                  icon: Icons.inbox_outlined,
                  message: 'No hay apartados pendientes de entrega.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: orders.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Por entregar (${orders.length})',
                          style: theme.textTheme.titleSmall),
                    );
                  }
                  // El PIN no se muestra: el restaurante debe recibirlo del
                  // cliente para comprobar que es quien apartó.
                  final order = orders[i - 1];
                  return Card(
                    key: ValueKey(order.id),
                    child: ListTile(
                      title: Text(order.packageName),
                      subtitle: Text(
                        '${order.quantity} × ${formatPrice(order.unitPrice)} · '
                        'apartado a las ${_time.format(order.createdAt)}',
                      ),
                      trailing: Text(formatPrice(order.total),
                          style: theme.textTheme.titleMedium),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DeliveredDialog extends StatelessWidget {
  const _DeliveredDialog({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.check_circle_outline, size: 40),
      title: const Text('Entrega confirmada'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(order.packageName,
              textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('${order.quantity} × ${formatPrice(order.unitPrice)}',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text('Cobrar', style: theme.textTheme.labelLarge),
          Text(
            formatPrice(order.total),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
