import 'package:cloud_firestore/cloud_firestore.dart';

/// Documento `restaurants/{id}`.
class Restaurant {
  final String id;
  final String ownerUid;
  final String name;
  final String address;
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
        'location': location,
        'phone': phone,
        'logoUrl': logoUrl,
        'pickupWindow': pickupWindow,
        'rating': rating,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
