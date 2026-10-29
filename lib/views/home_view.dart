import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/session_provider.dart';
import 'auth_view.dart';
import 'client/client_home_view.dart';
import 'restaurant/restaurant_home_view.dart';

/// Punto de entrada visual: decide qué mostrar según la sesión y el rol que
/// tiene el usuario en `users/{uid}`. Como [SessionProvider] escucha ese
/// documento en tiempo real, un cambio de rol en Firestore redirige solo.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    if (session.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = session.user;
    if (user == null) return const AuthView();

    // La clave por usuario/restaurante garantiza que las suscripciones de cada
    // panel se creen de nuevo si cambia la cuenta o el restaurante vinculado.
    return switch (user.role) {
      UserRole.cliente => ClientHomeView(
          key: ValueKey('client-${user.uid}'),
          user: user,
        ),
      UserRole.restaurante when user.restaurantId != null => RestaurantHomeView(
          key: ValueKey('restaurant-${user.restaurantId}'),
          restaurantId: user.restaurantId!,
        ),
      UserRole.restaurante => const _MissingRestaurantView(),
    };
  }
}

/// Cuenta con rol restaurante pero sin `restaurantId`: no debería ocurrir con
/// el registro actual, pero puede pasar con datos editados a mano.
class _MissingRestaurantView extends StatelessWidget {
  const _MissingRestaurantView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi restaurante')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Tu cuenta no tiene un restaurante vinculado.\n'
                'Contacta a soporte para completar el alta.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: context.read<SessionProvider>().signOut,
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
