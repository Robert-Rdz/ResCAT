import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescate_alimentos/models/models.dart';
import 'package:rescate_alimentos/views/client/package_detail_view.dart';

FoodPackage _package({
  int quantity = 3,
  String restaurantAddress = 'Av. del Mar 123, Mazatlán',
  List<String> allergens = const ['mariscos'],
  String? category = 'platillo fuerte',
}) =>
    FoodPackage(
      id: 'p1',
      restaurantId: 'r1',
      restaurantName: 'Mariscos El Güero',
      restaurantAddress: restaurantAddress,
      name: 'Ceviche de camarón',
      description: 'Camarón fresco con limón y pico de gallo.',
      originalPrice: 150,
      discountedPrice: 60,
      availableQuantity: quantity,
      createdAt: DateTime(2026, 11, 4),
      ingredients: const ['camarón', 'limón', 'cebolla'],
      allergens: allergens,
      category: category,
      perishability: 'alta',
    );

Restaurant _restaurant(String address) => Restaurant(
      id: 'r1',
      ownerUid: 'u1',
      name: 'Mariscos El Güero',
      address: address,
      createdAt: DateTime(2026, 11, 1),
    );

/// Abre el detalle desde una pantalla vacía y devuelve lo que regresa al cerrar.
Future<bool?> _openDetail(
  WidgetTester tester,
  FoodPackage package, {
  Future<Restaurant?> Function()? loadRestaurant,
}) async {
  bool? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await Navigator.of(context).push<bool>(MaterialPageRoute(
              builder: (_) => PackageDetailView(
                    package: package,
                    loadRestaurant: loadRestaurant,
                  )));
        },
        child: const Text('abrir'),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('muestra ingredientes, alérgenos y perecibilidad',
      (tester) async {
    await _openDetail(tester, _package());

    expect(find.text('Ceviche de camarón'), findsOneWidget);
    expect(find.text('Consúmelo hoy'), findsOneWidget);
    expect(find.text('Platillo fuerte'), findsOneWidget);

    // Lo de abajo queda fuera de la pantalla del test.
    await tester.scrollUntilVisible(find.text('Puede contener: mariscos'), 200);
    expect(find.text('camarón'), findsOneWidget);
    expect(find.text('Puede contener: mariscos'), findsOneWidget);
  });

  testWidgets('Apartar cierra el detalle y devuelve true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => PackageDetailView(package: _package())));
          },
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Apartar'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('agotado deshabilita el botón', (tester) async {
    await _openDetail(tester, _package(quantity: 0));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('Agotado'), findsWidgets);
  });

  testWidgets('sin análisis de IA no afirma que no hay alérgenos',
      (tester) async {
    await _openDetail(
        tester,
        FoodPackage(
          id: 'p2',
          restaurantId: 'r1',
          restaurantName: 'Panadería',
          name: 'Bolsa sorpresa',
          description: '',
          originalPrice: 100,
          discountedPrice: 50,
          availableQuantity: 1,
          createdAt: DateTime(2026, 11, 4),
        ));

    await tester.scrollUntilVisible(
        find.textContaining('pregunta en el restaurante'), 200);
    expect(find.textContaining('No se detectaron'), findsNothing);
    expect(find.textContaining('pregunta en el restaurante'), findsOneWidget);
  });

  testWidgets('muestra la dirección del restaurante para recoger',
      (tester) async {
    var lookups = 0;
    await _openDetail(tester, _package(), loadRestaurant: () async {
      lookups++;
      return _restaurant('otra');
    });

    expect(find.text('Recoge en Av. del Mar 123, Mazatlán'), findsOneWidget);
    expect(lookups, 0);
  });

  testWidgets('paquete viejo sin dirección la pide al restaurante',
      (tester) async {
    await _openDetail(tester, _package(restaurantAddress: ''),
        loadRestaurant: () async => _restaurant('Calle Juárez 45, Centro'));

    expect(find.text('Recoge en Calle Juárez 45, Centro'), findsOneWidget);
  });

  testWidgets('sin dirección disponible no inventa una', (tester) async {
    await _openDetail(tester, _package(restaurantAddress: ''),
        loadRestaurant: () async => null);

    expect(find.text('Dirección no disponible'), findsOneWidget);
  });
}
