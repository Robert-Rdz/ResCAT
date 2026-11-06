import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../widgets/package_card.dart';
import '../widgets/pickup_address.dart';

final _hourFormat = DateFormat('HH:mm');

/// Detalle de un paquete para el cliente. Devuelve `true` si el cliente tocó
/// "Apartar"; la reserva (cantidad y PIN) la hace la pantalla que lo abrió.
class PackageDetailView extends StatelessWidget {
  const PackageDetailView({
    super.key,
    required this.package,
    this.loadRestaurant,
  });

  final FoodPackage package;

  /// Solo se usa si el paquete no trae la dirección (publicado antes de que
  /// se copiara al paquete).
  final Future<Restaurant?> Function()? loadRestaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final perishability = package.perishability == null
        ? null
        : Perecibilidad.desdeTexto(package.perishability);
    // Sin categoría ni ingredientes, el paquete se publicó sin análisis de IA.
    final analyzed = package.category != null || package.ingredients.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: PackageCard.heroTag(package),
                child: package.photoUrl == null
                    ? _PhotoPlaceholder(colors: colors)
                    : CachedNetworkImage(
                        imageUrl: package.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _PhotoPlaceholder(colors: colors),
                      ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList.list(
              children: [
                Text(package.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 18, color: colors.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        package.restaurantName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                if (package.category != null || perishability != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (package.category != null)
                        Chip(
                          avatar: const Icon(Icons.restaurant_menu, size: 18),
                          label: Text(_capitalize(package.category!)),
                        ),
                      if (perishability != null)
                        Chip(
                          avatar: const Icon(Icons.schedule, size: 18),
                          label: Text(_consumeBy(perishability)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _PriceRow(package: package),
                const SizedBox(height: 12),
                PickupAddress(
                  address: package.restaurantAddress,
                  location: package.restaurantLocation,
                  load: loadRestaurant,
                ),
                if (package.pickupStart != null &&
                    package.pickupEnd != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.access_time,
                    text:
                        'Recoge de ${_hourFormat.format(package.pickupStart!)} '
                        'a ${_hourFormat.format(package.pickupEnd!)}',
                  ),
                ],
                if (package.description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(package.description, style: theme.textTheme.bodyLarge),
                ],
                if (package.ingredients.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Ingredientes', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final i in package.ingredients)
                        Chip(
                          label: Text(i),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _AllergensCard(
                  allergens: package.allergens,
                  analyzed: analyzed,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed:
                package.isAvailable ? () => Navigator.pop(context, true) : null,
            child: Text(package.isAvailable
                ? 'Apartar · ${formatPrice(package.discountedPrice)}'
                : package.availableQuantity == 0
                    ? 'Agotado'
                    : 'Ya no está disponible'),
          ),
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _consumeBy(Perecibilidad p) => switch (p) {
        Perecibilidad.alta => 'Consúmelo hoy',
        Perecibilidad.media => 'Mejor hoy o mañana',
        Perecibilidad.baja => 'Aguanta varios días',
      };
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.package});

  final FoodPackage package;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final saving = package.originalPrice - package.discountedPrice;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatPrice(package.discountedPrice),
          style: theme.textTheme.headlineMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 10),
        if (saving > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              formatPrice(package.originalPrice),
              style: theme.textTheme.bodyLarge?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (saving > 0)
              Text(
                'Ahorras ${formatPrice(saving)}',
                style:
                    theme.textTheme.labelLarge?.copyWith(color: colors.primary),
              ),
            Text(
              package.isAvailable
                  ? 'Quedan ${package.availableQuantity}'
                  : 'Agotado',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

/// Los alérgenos los detecta la IA a partir de la foto, así que siempre se
/// pide confirmar con el restaurante.
class _AllergensCard extends StatelessWidget {
  const _AllergensCard({required this.allergens, required this.analyzed});

  final List<String> allergens;
  final bool analyzed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasAllergens = allergens.isNotEmpty;

    final String title;
    final String body;
    if (hasAllergens) {
      title = 'Puede contener: ${allergens.join(', ')}';
      body = 'Detectado por IA a partir de la foto. Si tienes alguna alergia, '
          'confirma con el restaurante antes de comerlo.';
    } else if (analyzed) {
      title = 'No se detectaron alérgenos comunes';
      body = 'La IA lo estimó a partir de la foto y puede equivocarse. Si '
          'tienes alguna alergia, confirma con el restaurante.';
    } else {
      title = 'Alérgenos';
      body = 'Si tienes alguna alergia, pregunta en el restaurante al recoger.';
    }

    return Card(
      elevation: 0,
      color: hasAllergens ? colors.errorContainer : colors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasAllergens ? Icons.warning_amber_rounded : Icons.info_outline,
              color: hasAllergens
                  ? colors.onErrorContainer
                  : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: hasAllergens ? colors.onErrorContainer : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hasAllergens ? colors.onErrorContainer : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: colors.primaryContainer,
        child: Icon(Icons.fastfood_outlined,
            size: 64, color: colors.onPrimaryContainer),
      );
}
