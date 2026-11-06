import 'package:cloud_firestore/cloud_firestore.dart';

/// Dirección por partes, para que no quede ambigua ("Limón 17" existe en
/// muchas colonias). [full] es lo que se muestra y se copia a los paquetes.
class RestaurantAddress {
  const RestaurantAddress({
    required this.street,
    required this.neighborhood,
    required this.city,
    this.postalCode = '',
  });

  /// Calle y número.
  final String street;

  /// Colonia.
  final String neighborhood;

  /// Ciudad y estado.
  final String city;
  final String postalCode;

  bool get isComplete =>
      street.trim().isNotEmpty &&
      neighborhood.trim().isNotEmpty &&
      city.trim().isNotEmpty;

  /// "Limón 17, Col. Centro, Mazatlán, Sin., C.P. 82000".
  String get full {
    var colonia = neighborhood.trim();
    // Si ya escribieron "Col." no se repite.
    colonia = colonia.replaceFirst(
        RegExp(r'^col(onia)?\.?\s+', caseSensitive: false), '');
    final cp = postalCode.trim();
    return [
      street.trim(),
      if (colonia.isNotEmpty) 'Col. $colonia',
      city.trim(),
      if (cp.isNotEmpty) 'C.P. $cp',
    ].where((p) => p.isNotEmpty).join(', ');
  }

  factory RestaurantAddress.fromMap(Map<String, dynamic> m) =>
      RestaurantAddress(
        street: m['street'] as String? ?? '',
        neighborhood: m['neighborhood'] as String? ?? '',
        city: m['city'] as String? ?? '',
        postalCode: m['postalCode'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'street': street.trim(),
        'neighborhood': neighborhood.trim(),
        'city': city.trim(),
        'postalCode': postalCode.trim(),
      };
}

/// Documento `restaurants/{id}`.
class Restaurant {
  final String id;
  final String ownerUid;
  final String name;

  /// Dirección completa en una línea (ver [RestaurantAddress.full]).
  final String address;

  /// Null en restaurantes registrados antes de 2026-11-05, que solo tienen
  /// [address] en texto libre.
  final RestaurantAddress? addressParts;

  /// Coordenadas tomadas con el GPS del celular, si el dueño las guardó.
  final GeoPoint? location;
  final String? phone;
  final String? logoUrl;

  /// Horario de recolección mostrado al cliente, p. ej. "18:00 - 20:00".
  final String? pickupWindow;
  final double rating;
  final DateTime createdAt;

  const Restaurant({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.address,
    required this.createdAt,
    this.addressParts,
    this.location,
    this.phone,
    this.logoUrl,
    this.pickupWindow,
    this.rating = 0,
  });

  factory Restaurant.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Restaurant(
      id: doc.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      addressParts: data['addressParts'] is Map
          ? RestaurantAddress.fromMap(
              Map<String, dynamic>.from(data['addressParts'] as Map))
          : null,
      location: data['location'] as GeoPoint?,
      phone: data['phone'] as String?,
      logoUrl: data['logoUrl'] as String?,
      pickupWindow: data['pickupWindow'] as String?,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerUid': ownerUid,
        'name': name,
        'address': address,
        'addressParts': addressParts?.toMap(),
        'location': location,
        'phone': phone,
        'logoUrl': logoUrl,
        'pickupWindow': pickupWindow,
        'rating': rating,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
