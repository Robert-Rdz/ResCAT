import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescate_alimentos/services/firestore_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = FirestoreService(firestore: db);
    await db.collection('packages').doc('p1').set({
      'restaurantId': 'r1',
      'restaurantName': 'Fonda Doña Mary',
      'name': 'Enchiladas',
      'description': 'Verdes',
      'originalPrice': 120,
      'discountedPrice': 60,
      'availableQuantity': 3,
      'isActive': true,
    });
  });

  Future<void> update({
    String name = 'Enchiladas suizas',
    double originalPrice = 130,
    double discountedPrice = 55,
    int quantity = 5,
    int expected = 3,
    bool isActive = true,
  }) =>
      service.updatePackage(
        packageId: 'p1',
        name: name,
        description: 'Con crema',
        originalPrice: originalPrice,
        discountedPrice: discountedPrice,
        availableQuantity: quantity,
        expectedQuantity: expected,
        isActive: isActive,
      );

  test('guarda los cambios', () async {
    await update();
    final data = (await db.collection('packages').doc('p1').get()).data()!;
    expect(data['name'], 'Enchiladas suizas');
    expect(data['discountedPrice'], 55);
    expect(data['availableQuantity'], 5);
  });

  test('no pisa una reserva hecha mientras se editaba', () async {
    // Un cliente apartó 1 después de que el restaurante abrió el formulario.
    await db.collection('packages').doc('p1').update({'availableQuantity': 2});

    await expectLater(
      update(expected: 3),
      throwsA(isA<QuantityChangedException>()
          .having((e) => e.currentQuantity, 'currentQuantity', 2)),
    );
    final data = (await db.collection('packages').doc('p1').get()).data()!;
    expect(data['availableQuantity'], 2);
    expect(data['name'], 'Enchiladas');
  });

  test('rechaza precio de rescate mayor o igual al original', () async {
    await expectLater(update(originalPrice: 100, discountedPrice: 100),
        throwsA(isA<RescueException>()));
  });

  test('visible con cantidad 0 no se permite', () async {
    await expectLater(update(quantity: 0), throwsA(isA<RescueException>()));
  });

  test('se puede volver a publicar un paquete retirado', () async {
    await db.collection('packages').doc('p1').update({'isActive': false});
    await update(isActive: true);
    final data = (await db.collection('packages').doc('p1').get()).data()!;
    expect(data['isActive'], isTrue);
  });
}
