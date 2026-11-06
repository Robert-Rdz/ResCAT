import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescate_alimentos/models/models.dart';
import 'package:rescate_alimentos/services/firestore_service.dart';

const _address = RestaurantAddress(
  street: 'Limón 17',
  neighborhood: 'Centro',
  city: 'Mazatlán, Sin.',
  postalCode: '82000',
);

void main() {
  group('RestaurantAddress', () {
    test('arma la dirección completa en una línea', () {
      expect(
          _address.full, 'Limón 17, Col. Centro, Mazatlán, Sin., C.P. 82000');
    });

    test('no repite "Col." si ya lo escribieron', () {
      for (final colonia in ['Col. Centro', 'colonia Centro', 'Col Centro']) {
        final a = RestaurantAddress(
            street: 'Limón 17', neighborhood: colonia, city: 'Mazatlán');
        expect(a.full, 'Limón 17, Col. Centro, Mazatlán', reason: colonia);
      }
    });

    test('no confunde colonias que empiezan con "Col"', () {
      const a = RestaurantAddress(
          street: 'Limón 17', neighborhood: 'Colosio', city: 'Mazatlán');
      expect(a.full, 'Limón 17, Col. Colosio, Mazatlán');
    });

    test('sin colonia o ciudad no está completa', () {
      expect(_address.isComplete, isTrue);
      expect(
          const RestaurantAddress(
                  street: 'Limón 17', neighborhood: '', city: 'Mazatlán')
              .isComplete,
          isFalse);
      expect(
          const RestaurantAddress(
                  street: 'Limón 17', neighborhood: 'Centro', city: ' ')
              .isComplete,
          isFalse);
    });
  });

  group('updateRestaurant', () {
    late FakeFirebaseFirestore db;
    late FirestoreService service;

    setUp(() async {
      db = FakeFirebaseFirestore();
      service = FirestoreService(firestore: db);
      await db.collection('restaurants').doc('r1').set({
        'ownerUid': 'u1',
        'name': 'Fonda',
        'address': 'Limón 17',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 1)),
      });
      Future<void> pkg(String id, String restaurantId, bool active) =>
          db.collection('packages').doc(id).set({
            'restaurantId': restaurantId,
            'restaurantName': 'Fonda',
            'restaurantAddress': 'Limón 17',
            'name': 'Paquete $id',
            'isActive': active,
            'availableQuantity': active ? 2 : 0,
          });
      await pkg('activo', 'r1', true);
      await pkg('retirado', 'r1', false);
      await pkg('ajeno', 'r2', true);
    });

    Future<Map<String, dynamic>> data(String col, String id) async =>
        (await db.collection(col).doc(id).get()).data()!;

    test('guarda la dirección por partes y la ubicación', () async {
      await service.updateRestaurant(
        restaurantId: 'r1',
        name: 'Fonda Doña Mary',
        address: _address,
        location: const GeoPoint(23.2494, -106.4111),
      );

      final r = Restaurant.fromFirestore(
          await db.collection('restaurants').doc('r1').get());
      expect(r.name, 'Fonda Doña Mary');
      expect(r.address, _address.full);
      expect(r.addressParts?.neighborhood, 'Centro');
      expect(r.location, const GeoPoint(23.2494, -106.4111));
      expect(r.ownerUid, 'u1');
    });

    test('copia la dirección nueva solo a sus paquetes publicados', () async {
      await service.updateRestaurant(
        restaurantId: 'r1',
        name: 'Fonda Doña Mary',
        address: _address,
        location: const GeoPoint(23.2494, -106.4111),
      );

      final activo = await data('packages', 'activo');
      expect(activo['restaurantAddress'], _address.full);
      expect(activo['restaurantName'], 'Fonda Doña Mary');
      expect(activo['restaurantLocation'], const GeoPoint(23.2494, -106.4111));

      expect((await data('packages', 'retirado'))['restaurantAddress'],
          'Limón 17');
      expect(
          (await data('packages', 'ajeno'))['restaurantAddress'], 'Limón 17');
    });

    test('rechaza una dirección incompleta', () async {
      await expectLater(
        service.updateRestaurant(
          restaurantId: 'r1',
          name: 'Fonda',
          address: const RestaurantAddress(
              street: 'Limón 17', neighborhood: '', city: 'Mazatlán'),
        ),
        throwsA(isA<RescueException>()),
      );
      expect((await data('restaurants', 'r1'))['address'], 'Limón 17');
    });
  });

  test('el paquete conserva la ubicación en la caché local', () {
    final p = FoodPackage(
      id: 'p1',
      restaurantId: 'r1',
      restaurantName: 'Fonda',
      restaurantAddress: _address.full,
      restaurantLocation: const GeoPoint(23.2494, -106.4111),
      name: 'Enchiladas',
      description: '',
      originalPrice: 100,
      discountedPrice: 50,
      availableQuantity: 1,
      createdAt: DateTime(2026, 11, 5),
    );

    final back = FoodPackage.fromCacheJson(p.toCacheJson());
    expect(back.restaurantAddress, _address.full);
    expect(back.restaurantLocation, const GeoPoint(23.2494, -106.4111));
  });
}
