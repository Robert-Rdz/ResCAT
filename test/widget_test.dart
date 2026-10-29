import 'package:flutter_test/flutter_test.dart';
import 'package:rescate_alimentos/models/models.dart';

void main() {
  test('FoodPackage calcula el porcentaje de descuento', () {
    final package = FoodPackage(
      id: 'p1',
      restaurantId: 'r1',
      restaurantName: 'Demo',
      name: 'Bolsa sorpresa',
      description: '',
      originalPrice: 200,
      discountedPrice: 80,
      availableQuantity: 3,
      createdAt: DateTime(2026),
    );
    expect(package.discountPercent, 60);
    expect(package.isAvailable, isTrue);
  });

  test('OrderStatus.fromString usa apartado por defecto', () {
    expect(OrderStatus.fromString('entregado'), OrderStatus.entregado);
    expect(OrderStatus.fromString(null), OrderStatus.apartado);
  });

  test('FoodPackage sobrevive la ida y vuelta por la caché de SQLite', () {
    final package = FoodPackage(
      id: 'p1',
      restaurantId: 'r1',
      restaurantName: 'Demo',
      name: 'Bolsa sorpresa',
      description: 'Pan del día',
      originalPrice: 200,
      discountedPrice: 80,
      availableQuantity: 3,
      createdAt: DateTime(2026, 10, 1),
      pickupEnd: DateTime(2026, 10, 1, 21),
    );
    final copy = FoodPackage.fromCacheJson(package.toCacheJson());
    expect(copy.name, package.name);
    expect(copy.discountedPrice, 80);
    expect(copy.pickupStart, isNull);
    expect(copy.pickupEnd, package.pickupEnd);
    expect(copy.createdAt, package.createdAt);
  });
}
