import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class RescueException implements Exception {
  final String message;
  const RescueException(this.message);

  @override
  String toString() => message;
}

/// `restaurants/{id}/activePins/{pin}` guarda los PIN en uso para que no se
/// repitan y para validar un PIN con una sola lectura.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, Random? random})
      : _db = firestore ?? FirebaseFirestore.instance,
        _random = random ?? Random.secure();

  final FirebaseFirestore _db;
  final Random _random;

  static const int _maxPinAttempts = 10;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _restaurants =>
      _db.collection('restaurants');
  CollectionReference<Map<String, dynamic>> get _packages =>
      _db.collection('packages');
  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');

  DocumentReference<Map<String, dynamic>> _pinRef(String restaurantId, String pin) =>
      _restaurants.doc(restaurantId).collection('activePins').doc(pin);

  Future<void> saveUser(AppUser user) =>
      _users.doc(user.uid).set(user.toFirestore(), SetOptions(merge: true));

  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? AppUser.fromFirestore(doc) : null;
  }

  Stream<AppUser?> watchUser(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);

  /// Para restaurantes crea también `restaurants/{id}` en el mismo batch.
  Future<AppUser> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required UserRole role,
    String? phone,
    String? restaurantName,
    String? restaurantAddress,
  }) async {
    final now = DateTime.now();
    final batch = _db.batch();

    String? restaurantId;
    if (role == UserRole.restaurante) {
      final ref = _restaurants.doc();
      restaurantId = ref.id;
      batch.set(
        ref,
        Restaurant(
          id: ref.id,
          ownerUid: uid,
          name: restaurantName!.trim(),
          address: restaurantAddress!.trim(),
          phone: phone,
          createdAt: now,
        ).toFirestore(),
      );
    }

    final user = AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      phone: phone,
      role: role,
      restaurantId: restaurantId,
      createdAt: now,
    );
    batch.set(_users.doc(uid), user.toFirestore());

    await batch.commit();
    return user;
  }

  Future<String> createRestaurant(Restaurant restaurant) async {
    final ref = _restaurants.doc();
    final batch = _db.batch()
      ..set(ref, restaurant.toFirestore())
      ..update(_users.doc(restaurant.ownerUid), {
        'role': UserRole.restaurante.name,
        'restaurantId': ref.id,
      });
    await batch.commit();
    return ref.id;
  }

  Future<Restaurant?> getRestaurant(String restaurantId) async {
    final doc = await _restaurants.doc(restaurantId).get();
    return doc.exists ? Restaurant.fromFirestore(doc) : null;
  }

  Future<String> publishPackage({
    required String restaurantId,
    required String name,
    required String description,
    required double originalPrice,
    required double discountedPrice,
    required int availableQuantity,
    String? photoUrl,
    DateTime? pickupStart,
    DateTime? pickupEnd,
  }) async {
    if (name.trim().isEmpty) {
      throw const RescueException('El paquete necesita un nombre.');
    }
    if (originalPrice <= 0 || discountedPrice < 0) {
      throw const RescueException('Los precios no son válidos.');
    }
    if (discountedPrice >= originalPrice) {
      throw const RescueException(
          'El precio con descuento debe ser menor al precio original.');
    }
    if (availableQuantity <= 0) {
      throw const RescueException('La cantidad disponible debe ser mayor a 0.');
    }

    final restaurant = await getRestaurant(restaurantId);
    if (restaurant == null) {
      throw const RescueException('Restaurante no encontrado.');
    }

    final ref = _packages.doc();
    final package = FoodPackage(
      id: ref.id,
      restaurantId: restaurantId,
      restaurantName: restaurant.name,
      name: name.trim(),
      description: description.trim(),
      originalPrice: originalPrice,
      discountedPrice: discountedPrice,
      availableQuantity: availableQuantity,
      photoUrl: photoUrl,
      pickupStart: pickupStart,
      pickupEnd: pickupEnd,
      createdAt: DateTime.now(),
    );
    await ref.set(package.toFirestore());
    return ref.id;
  }

  Future<void> deactivatePackage(String packageId) =>
      _packages.doc(packageId).update({'isActive': false});

  /// Requiere índice (isActive, availableQuantity, createdAt).
  Stream<List<FoodPackage>> watchAvailablePackages() => _packages
      .where('isActive', isEqualTo: true)
      .where('availableQuantity', isGreaterThan: 0)
      .orderBy('availableQuantity')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FoodPackage.fromFirestore).toList());

  /// Requiere índice (restaurantId, createdAt desc).
  Stream<List<FoodPackage>> watchRestaurantPackages(String restaurantId) => _packages
      .where('restaurantId', isEqualTo: restaurantId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FoodPackage.fromFirestore).toList());

  /// En transacción para no apartar más de lo que hay ni repetir PIN.
  Future<FoodOrder> reservePackage({
    required String packageId,
    required String userId,
    int quantity = 1,
  }) async {
    if (quantity <= 0) {
      throw const RescueException('La cantidad debe ser mayor a 0.');
    }

    return _db.runTransaction<FoodOrder>((tx) async {
      final packageRef = _packages.doc(packageId);
      final packageSnap = await tx.get(packageRef);
      if (!packageSnap.exists) {
        throw const RescueException('El paquete ya no existe.');
      }
      final package = FoodPackage.fromFirestore(packageSnap);
      if (!package.isActive) {
        throw const RescueException('Este paquete ya no está disponible.');
      }
      if (package.availableQuantity < quantity) {
        throw RescueException(
            'Solo quedan ${package.availableQuantity} disponibles.');
      }

      // Todas las lecturas deben ir antes de cualquier escritura.
      final pin = await _findFreePin(tx, package.restaurantId);

      final orderRef = _orders.doc();
      final order = FoodOrder(
        id: orderRef.id,
        userId: userId,
        restaurantId: package.restaurantId,
        packageId: package.id,
        packageName: package.name,
        restaurantName: package.restaurantName,
        quantity: quantity,
        unitPrice: package.discountedPrice,
        pin: pin,
        status: OrderStatus.apartado,
        createdAt: DateTime.now(),
      );

      final remaining = package.availableQuantity - quantity;
      tx
        ..set(orderRef, order.toFirestore())
        ..set(_pinRef(package.restaurantId, pin), {
          'orderId': orderRef.id,
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..update(packageRef, {
          'availableQuantity': remaining,
          if (remaining == 0) 'isActive': false,
        });

      return order;
    });
  }

  Future<String> _findFreePin(Transaction tx, String restaurantId) async {
    for (var i = 0; i < _maxPinAttempts; i++) {
      final pin = _random.nextInt(10000).toString().padLeft(4, '0');
      final snap = await tx.get(_pinRef(restaurantId, pin));
      if (!snap.exists) return pin;
    }
    throw const RescueException(
        'No se pudo generar un PIN. Intenta de nuevo en un momento.');
  }

  /// Cancela un apartado activo y devuelve las unidades al paquete.
  Future<void> cancelOrder(String orderId) {
    return _db.runTransaction<void>((tx) async {
      final orderRef = _orders.doc(orderId);
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        throw const RescueException('El apartado no existe.');
      }
      final order = FoodOrder.fromFirestore(orderSnap);
      if (!order.isActive) {
        throw const RescueException('Este apartado ya no se puede cancelar.');
      }

      final packageRef = _packages.doc(order.packageId);
      final packageSnap = await tx.get(packageRef);

      tx
        ..update(orderRef, {
          'status': OrderStatus.cancelado.name,
          'cancelledAt': FieldValue.serverTimestamp(),
        })
        ..delete(_pinRef(order.restaurantId, order.pin));
      if (packageSnap.exists) {
        final package = FoodPackage.fromFirestore(packageSnap);
        tx.update(packageRef, {
          'availableQuantity': FieldValue.increment(order.quantity),
          // Solo se reactiva si se había agotado por los apartados; si el
          // restaurante lo retiró con existencias, sigue retirado.
          if (package.availableQuantity == 0) 'isActive': true,
        });
      }
    });
  }

  Stream<List<FoodOrder>> watchUserOrders(String userId) => _orders
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FoodOrder.fromFirestore).toList());

  /// Valida el PIN capturado por el restaurante y marca la orden como entregada.
  Future<FoodOrder> validatePinAndDeliver({
    required String restaurantId,
    required String pin,
  }) async {
    final cleanPin = pin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleanPin)) {
      throw const RescueException('El PIN debe tener 4 dígitos.');
    }

    return _db.runTransaction<FoodOrder>((tx) async {
      final pinRef = _pinRef(restaurantId, cleanPin);
      final pinSnap = await tx.get(pinRef);
      final orderId = pinSnap.data()?['orderId'] as String?;
      if (!pinSnap.exists || orderId == null) {
        throw const RescueException('PIN incorrecto o sin apartado activo.');
      }

      final orderRef = _orders.doc(orderId);
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        throw const RescueException('PIN incorrecto o sin apartado activo.');
      }
      final order = FoodOrder.fromFirestore(orderSnap);
      if (order.restaurantId != restaurantId ||
          order.pin != cleanPin ||
          !order.isActive) {
        throw const RescueException('PIN incorrecto o sin apartado activo.');
      }

      final now = DateTime.now();
      tx
        ..update(orderRef, {
          'status': OrderStatus.entregado.name,
          'deliveredAt': Timestamp.fromDate(now),
        })
        ..delete(pinRef);

      return FoodOrder(
        id: order.id,
        userId: order.userId,
        restaurantId: order.restaurantId,
        packageId: order.packageId,
        packageName: order.packageName,
        restaurantName: order.restaurantName,
        quantity: order.quantity,
        unitPrice: order.unitPrice,
        pin: order.pin,
        status: OrderStatus.entregado,
        createdAt: order.createdAt,
        deliveredAt: now,
      );
    });
  }

  Stream<List<FoodOrder>> watchRestaurantActiveOrders(String restaurantId) => _orders
      .where('restaurantId', isEqualTo: restaurantId)
      .where('status', isEqualTo: OrderStatus.apartado.name)
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(FoodOrder.fromFirestore).toList());
}
