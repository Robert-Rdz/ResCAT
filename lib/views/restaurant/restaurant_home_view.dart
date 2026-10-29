import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../widgets/package_card.dart';
import 'deliveries_tab.dart';
import 'publish_package_view.dart';

/// Panel del restaurante: sus paquetes publicados y la validación de entregas.
class RestaurantHomeView extends StatefulWidget {
  const RestaurantHomeView({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<RestaurantHomeView> createState() => _RestaurantHomeViewState();
}

class _RestaurantHomeViewState extends State<RestaurantHomeView> {
  late final FirestoreService _firestore = context.read<FirestoreService>();
  late Stream<List<FoodPackage>> _packages =
      _firestore.watchRestaurantPackages(widget.restaurantId);
  late final Future<Restaurant?> _restaurant =
      _firestore.getRestaurant(widget.restaurantId);
  int _tab = 0;

  /// Un stream de Firestore se cierra tras un error; para reintentar hay que
  /// crear la consulta de nuevo.
  void _retryPackages() => setState(() {
        _packages = _firestore.watchRestaurantPackages(widget.restaurantId);
      });

  static String _packagesErrorMessage(Object? error) => switch (error) {
        FirebaseException(code: 'failed-precondition') =>
          'El índice de Firestore (restaurantId + createdAt) no está listo.\n'
              'Despliégalo o espera a que termine de construirse.',
        FirebaseException(code: 'permission-denied') =>
          'Firestore rechazó la lectura. Revisa las reglas de seguridad.',
        FirebaseException(code: 'unavailable') =>
          'Sin conexión con el servidor.',
        _ => 'No se pudieron cargar tus paquetes.',
      };

  Future<void> _openPublish() async {
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PublishPackageView(restaurantId: widget.restaurantId),
      ),
    );
    if (published == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paquete publicado.')),
      );
    }
  }

  Future<void> _withdraw(FoodPackage package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Retirar paquete?'),
        content: Text(
          '"${package.name}" dejará de mostrarse a los clientes. '
          'Los apartados existentes se mantienen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _firestore.deactivatePackage(package.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo retirar el paquete.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Restaurant?>(
          future: _restaurant,
          builder: (context, snapshot) =>
              Text(snapshot.data?.name ?? 'Mi restaurante'),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: context.read<SessionProvider>().signOut,
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _openPublish,
              icon: const Icon(Icons.add),
              label: const Text('Publicar excedente'),
            )
          : null,
      // IndexedStack conserva el scroll y la suscripción de cada pestaña.
      body: IndexedStack(
        index: _tab,
        children: [
          _buildPackages(),
          DeliveriesTab(restaurantId: widget.restaurantId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Paquetes',
          ),
          NavigationDestination(
            icon: Icon(Icons.pin_outlined),
            selectedIcon: Icon(Icons.pin),
            label: 'Entregas',
          ),
        ],
      ),
    );
  }

  Widget _buildPackages() {
    return StreamBuilder<List<FoodPackage>>(
      stream: _packages,
      builder: (context, snapshot) {
        // Al reintentar, el snapshot conserva el error anterior hasta que
        // llega el primer evento; se muestra la carga mientras tanto.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          // El mensaje de failed-precondition incluye el enlace para crear
          // el índice en la consola de Firebase.
          debugPrint('watchRestaurantPackages: ${snapshot.error}');
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            message: _packagesErrorMessage(snapshot.error),
            action: OutlinedButton.icon(
              onPressed: _retryPackages,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final packages = snapshot.data!;
        if (packages.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            message: 'Aún no has publicado paquetes.\n'
                'Toca "Publicar excedente" para empezar.',
          );
        }
        return ListView.separated(
          // Espacio extra para que el FAB no tape el último botón.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: packages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final package = packages[i];
            return PackageCard(
              key: ValueKey(package.id),
              package: package,
              showRestaurant: false,
              action: package.isActive
                  ? OutlinedButton(
                      onPressed: () => _withdraw(package),
                      child: const Text('Retirar'),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
