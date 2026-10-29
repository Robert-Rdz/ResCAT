import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../widgets/package_card.dart';

final _deliveredFormat = DateFormat('dd/MM/yyyy HH:mm');

/// Panel del cliente: paquetes disponibles y sus apartados (con PIN).
class ClientHomeView extends StatefulWidget {
  const ClientHomeView({super.key, required this.user});

  final AppUser user;

  @override
  State<ClientHomeView> createState() => _ClientHomeViewState();
}

class _ClientHomeViewState extends State<ClientHomeView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Rescata comida' : 'Mis apartados'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: context.read<SessionProvider>().signOut,
          ),
        ],
      ),
      // IndexedStack conserva el scroll y la suscripción de cada pestaña.
      body: IndexedStack(
        index: _tab,
        children: [
          _AvailablePackagesTab(
            user: widget.user,
            onReserved: () => setState(() => _tab = 1),
          ),
          _MyOrdersTab(user: widget.user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Disponibles',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Mis apartados',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Paquetes disponibles
// -----------------------------------------------------------------------------

class _AvailablePackagesTab extends StatefulWidget {
  const _AvailablePackagesTab({required this.user, required this.onReserved});

  final AppUser user;
  final VoidCallback onReserved;

  @override
  State<_AvailablePackagesTab> createState() => _AvailablePackagesTabState();
}

class _AvailablePackagesTabState extends State<_AvailablePackagesTab> {
  late final FirestoreService _firestore = context.read<FirestoreService>();
  late final Stream<List<FoodPackage>> _packages =
      _firestore.watchAvailablePackages();
  final Set<String> _reserving = {};

  Future<void> _reserve(FoodPackage package) async {
    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => _ReserveDialog(package: package),
    );
    if (quantity == null || !mounted) return;

    setState(() => _reserving.add(package.id));
    try {
      final order = await _firestore.reservePackage(
        packageId: package.id,
        userId: widget.user.uid,
        quantity: quantity,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _PinDialog(order: order),
      );
      widget.onReserved();
    } on RescueException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('No se pudo apartar el paquete. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _reserving.remove(package.id));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FoodPackage>>(
      stream: _packages,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('watchAvailablePackages: ${snapshot.error}');
          return const EmptyState(
            icon: Icons.cloud_off_outlined,
            message: 'No se pudieron cargar los paquetes.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final packages = snapshot.data!;
        if (packages.isEmpty) {
          return const EmptyState(
            icon: Icons.no_food_outlined,
            message: 'Por ahora no hay paquetes disponibles.\n'
                'Vuelve más tarde.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: packages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final package = packages[i];
            final busy = _reserving.contains(package.id);
            return PackageCard(
              key: ValueKey(package.id),
              package: package,
              action: FilledButton(
                onPressed: busy ? null : () => _reserve(package),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Apartar'),
              ),
            );
          },
        );
      },
    );
  }
}

/// Confirmación del apartado con selector de cantidad. Devuelve la cantidad
/// elegida, o `null` si el cliente cancela. Las existencias mostradas pueden
/// estar desfasadas; [FirestoreService.reservePackage] las vuelve a comprobar.
class _ReserveDialog extends StatefulWidget {
  const _ReserveDialog({required this.package});

  final FoodPackage package;

  @override
  State<_ReserveDialog> createState() => _ReserveDialogState();
}

class _ReserveDialogState extends State<_ReserveDialog> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final package = widget.package;
    final max = package.availableQuantity;

    return AlertDialog(
      title: Text('Apartar "${package.name}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(package.restaurantName),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Cantidad')),
              IconButton.outlined(
                tooltip: 'Quitar uno',
                onPressed:
                    _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 40,
                child: Text('$_quantity',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge),
              ),
              IconButton.outlined(
                tooltip: 'Agregar uno',
                onPressed:
                    _quantity < max ? () => setState(() => _quantity++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Pagarás ${formatPrice(package.discountedPrice * _quantity)} '
            'al recoger.',
          ),
          const SizedBox(height: 8),
          const Text(
              'Recibirás un PIN de 4 dígitos para mostrar en el restaurante.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _quantity),
          child: const Text('Apartar'),
        ),
      ],
    );
  }
}

class _PinDialog extends StatelessWidget {
  const _PinDialog({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.check_circle_outline, size: 40),
      title: const Text('¡Apartado!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Muestra este PIN en ${order.restaurantName}:',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _PinText(pin: order.pin),
          const SizedBox(height: 16),
          Text(
            '${order.quantity} × ${order.packageName}\n'
            'Pagarás ${formatPrice(order.total)} al recoger.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('También lo encontrarás en "Mis apartados".',
              textAlign: TextAlign.center),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}

class _PinText extends StatelessWidget {
  const _PinText({required this.pin});

  final String pin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'PIN ${pin.split('').join(' ')}',
      child: ExcludeSemantics(
        child: Text(
          pin,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 12,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Mis apartados
// -----------------------------------------------------------------------------

class _MyOrdersTab extends StatefulWidget {
  const _MyOrdersTab({required this.user});

  final AppUser user;

  @override
  State<_MyOrdersTab> createState() => _MyOrdersTabState();
}

class _MyOrdersTabState extends State<_MyOrdersTab> {
  late final FirestoreService _firestore = context.read<FirestoreService>();
  late final Stream<List<FoodOrder>> _orders =
      _firestore.watchUserOrders(widget.user.uid).map(_notifyDeliveries);
  final Set<String> _cancelling = {};

  /// Último estado conocido de cada apartado; `null` hasta el primer evento.
  Map<String, OrderStatus>? _lastStatus;

  /// Avisa al cliente cuando el restaurante valida su PIN. La pestaña vive en
  /// un IndexedStack, así que el aviso llega aunque esté en "Disponibles".
  List<FoodOrder> _notifyDeliveries(List<FoodOrder> orders) {
    final previous = _lastStatus;
    _lastStatus = {for (final o in orders) o.id: o.status};
    if (previous == null || !mounted) return orders;

    for (final order in orders) {
      if (order.status == OrderStatus.entregado &&
          previous[order.id] == OrderStatus.apartado) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('¡Recogiste "${order.packageName}"! '
              'Gracias por rescatar comida.'),
        ));
      }
    }
    return orders;
  }

  Future<void> _cancel(FoodOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar apartado?'),
        content: Text('Liberarás "${order.packageName}" para otra persona.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling.add(order.id));
    try {
      await _firestore.cancelOrder(order.id);
    } on RescueException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      debugPrint('cancelOrder: $e');
      _showMessage('No se pudo cancelar el apartado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cancelling.remove(order.id));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FoodOrder>>(
      stream: _orders,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('watchUserOrders: ${snapshot.error}');
          return const EmptyState(
            icon: Icons.cloud_off_outlined,
            message: 'No se pudieron cargar tus apartados.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'Aún no has apartado ningún paquete.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _OrderCard(
            key: ValueKey(orders[i].id),
            order: orders[i],
            cancelling: _cancelling.contains(orders[i].id),
            onCancel: () => _cancel(orders[i]),
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    super.key,
    required this.order,
    required this.cancelling,
    required this.onCancel,
  });

  final FoodOrder order;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (order.status) {
      OrderStatus.apartado => ('Por recoger', theme.colorScheme.primary),
      OrderStatus.entregado => ('Entregado', theme.colorScheme.tertiary),
      OrderStatus.cancelado => ('Cancelado', theme.colorScheme.outline),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(order.packageName,
                      style: theme.textTheme.titleMedium),
                ),
                Text(label,
                    style: theme.textTheme.labelLarge?.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${order.restaurantName} · ${order.quantity} × '
              '${formatPrice(order.unitPrice)} = ${formatPrice(order.total)}',
              style: theme.textTheme.bodySmall,
            ),
            if (order.deliveredAt != null)
              Text(
                'Recogido el ${_deliveredFormat.format(order.deliveredAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            if (order.isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PIN de entrega', style: theme.textTheme.labelMedium),
                        _PinText(pin: order.pin),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: cancelling ? null : onCancel,
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
