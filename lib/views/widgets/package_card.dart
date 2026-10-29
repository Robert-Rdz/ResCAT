import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';

final _currency = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

String formatPrice(double value) => _currency.format(value);

/// Tarjeta de paquete para cliente y restaurante.
class PackageCard extends StatelessWidget {
  const PackageCard({
    super.key,
    required this.package,
    this.action,
    this.showRestaurant = true,
  });

  final FoodPackage package;
  final Widget? action;
  final bool showRestaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Opacity(
      opacity: package.isAvailable ? 1 : 0.6,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (package.photoUrl != null)
                    CachedNetworkImage(
                      imageUrl: package.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          ColoredBox(color: colors.surfaceContainerHighest),
                      errorWidget: (_, __, ___) => const _PhotoPlaceholder(),
                    )
                  else
                    const _PhotoPlaceholder(),
                  if (package.discountPercent > 0)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '-${package.discountPercent}%',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(package.name, style: theme.textTheme.titleMedium),
                  if (showRestaurant) ...[
                    const SizedBox(height: 2),
                    Text(
                      package.restaurantName,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                  if (package.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      package.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatPrice(package.originalPrice),
                              style: theme.textTheme.bodySmall?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              formatPrice(package.discountedPrice),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              package.isAvailable
                                  ? 'Quedan ${package.availableQuantity}'
                                  : package.availableQuantity == 0
                                      ? 'Agotado'
                                      : 'Retirado',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (action != null) action!,
                    ],
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

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primaryContainer,
      child: Icon(Icons.fastfood_outlined,
          size: 48, color: colors.onPrimaryContainer),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
