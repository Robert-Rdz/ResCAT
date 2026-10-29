import 'package:cloud_firestore/cloud_firestore.dart';

/// Documento `packages/{id}`.
class FoodPackage {
  final String id;
  final String restaurantId;

  final String restaurantName;
  final String name;
  final String description;
  final double originalPrice;
  final double discountedPrice;
  final int availableQuantity;
  final String? photoUrl;
  final bool isActive;
  final DateTime? pickupStart;
  final DateTime? pickupEnd;
  final DateTime createdAt;

  const FoodPackage({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.description,
    required this.originalPrice,
    required this.discountedPrice,
    required this.availableQuantity,
    required this.createdAt,
    this.photoUrl,
    this.isActive = true,
    this.pickupStart,
    this.pickupEnd,
  });

  bool get isAvailable => isActive && availableQuantity > 0;

  int get discountPercent => originalPrice <= 0
      ? 0
      : (((originalPrice - discountedPrice) / originalPrice) * 100).round();

  factory FoodPackage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return FoodPackage(
      id: doc.id,
      restaurantId: data['restaurantId'] as String? ?? '',
      restaurantName: data['restaurantName'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      originalPrice: (data['originalPrice'] as num?)?.toDouble() ?? 0,
      discountedPrice: (data['discountedPrice'] as num?)?.toDouble() ?? 0,
      availableQuantity: (data['availableQuantity'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String?,
      isActive: data['isActive'] as bool? ?? false,
      pickupStart: (data['pickupStart'] as Timestamp?)?.toDate(),
      pickupEnd: (data['pickupEnd'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'name': name,
        'description': description,
        'originalPrice': originalPrice,
        'discountedPrice': discountedPrice,
        'availableQuantity': availableQuantity,
        'photoUrl': photoUrl,
        'isActive': isActive,
        'pickupStart': pickupStart == null ? null : Timestamp.fromDate(pickupStart!),
        'pickupEnd': pickupEnd == null ? null : Timestamp.fromDate(pickupEnd!),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  /// Para la caché de SQLite.
  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'name': name,
        'description': description,
        'originalPrice': originalPrice,
        'discountedPrice': discountedPrice,
        'availableQuantity': availableQuantity,
        'photoUrl': photoUrl,
        'isActive': isActive,
        'pickupStart': pickupStart?.millisecondsSinceEpoch,
        'pickupEnd': pickupEnd?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory FoodPackage.fromCacheJson(Map<String, dynamic> j) {
    DateTime? fecha(Object? v) =>
        v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    return FoodPackage(
      id: j['id'] as String,
      restaurantId: j['restaurantId'] as String,
      restaurantName: j['restaurantName'] as String,
      name: j['name'] as String,
      description: j['description'] as String,
      originalPrice: (j['originalPrice'] as num).toDouble(),
      discountedPrice: (j['discountedPrice'] as num).toDouble(),
      availableQuantity: j['availableQuantity'] as int,
      photoUrl: j['photoUrl'] as String?,
      isActive: j['isActive'] as bool,
      pickupStart: fecha(j['pickupStart']),
      pickupEnd: fecha(j['pickupEnd']),
      createdAt: fecha(j['createdAt'])!,
    );
  }
}
