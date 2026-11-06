import 'package:cloud_firestore/cloud_firestore.dart';

/// Documento `packages/{id}`.
class FoodPackage {
  final String id;
  final String restaurantId;

  final String restaurantName;

  /// Copia de `restaurants/{id}.address` al publicar, para mostrar dónde se
  /// recoge sin otra lectura. Vacía en paquetes publicados antes de 2026-11-05.
  final String restaurantAddress;

  /// Copia de `restaurants/{id}.location`; con ella Maps abre el punto exacto.
  final GeoPoint? restaurantLocation;
  final String name;
  final String description;
  final double originalPrice;
  final double discountedPrice;
  final int availableQuantity;
  final String? photoUrl;
  final List<String> ingredients;
  final List<String> allergens;
  final String? category;

  /// `alta`, `media` o `baja`, según el análisis de IA.
  final String? perishability;
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
    this.restaurantAddress = '',
    this.restaurantLocation,
    this.photoUrl,
    this.ingredients = const [],
    this.allergens = const [],
    this.category,
    this.perishability,
    this.isActive = true,
    this.pickupStart,
    this.pickupEnd,
  });

  bool get isAvailable => isActive && availableQuantity > 0;

  int get discountPercent => originalPrice <= 0
      ? 0
      : (((originalPrice - discountedPrice) / originalPrice) * 100).round();

  factory FoodPackage.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return FoodPackage(
      id: doc.id,
      restaurantId: data['restaurantId'] as String? ?? '',
      restaurantName: data['restaurantName'] as String? ?? '',
      restaurantAddress: data['restaurantAddress'] as String? ?? '',
      restaurantLocation: data['restaurantLocation'] as GeoPoint?,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      originalPrice: (data['originalPrice'] as num?)?.toDouble() ?? 0,
      discountedPrice: (data['discountedPrice'] as num?)?.toDouble() ?? 0,
      availableQuantity: (data['availableQuantity'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String?,
      ingredients: List<String>.from(data['ingredients'] as List? ?? const []),
      allergens: List<String>.from(data['allergens'] as List? ?? const []),
      category: data['category'] as String?,
      perishability: data['perishability'] as String?,
      isActive: data['isActive'] as bool? ?? false,
      pickupStart: (data['pickupStart'] as Timestamp?)?.toDate(),
      pickupEnd: (data['pickupEnd'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'restaurantAddress': restaurantAddress,
        'restaurantLocation': restaurantLocation,
        'name': name,
        'description': description,
        'originalPrice': originalPrice,
        'discountedPrice': discountedPrice,
        'availableQuantity': availableQuantity,
        'photoUrl': photoUrl,
        'ingredients': ingredients,
        'allergens': allergens,
        'category': category,
        'perishability': perishability,
        'isActive': isActive,
        'pickupStart':
            pickupStart == null ? null : Timestamp.fromDate(pickupStart!),
        'pickupEnd': pickupEnd == null ? null : Timestamp.fromDate(pickupEnd!),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  /// Para la caché de SQLite.
  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'restaurantAddress': restaurantAddress,
        'restaurantLat': restaurantLocation?.latitude,
        'restaurantLng': restaurantLocation?.longitude,
        'name': name,
        'description': description,
        'originalPrice': originalPrice,
        'discountedPrice': discountedPrice,
        'availableQuantity': availableQuantity,
        'photoUrl': photoUrl,
        'ingredients': ingredients,
        'allergens': allergens,
        'category': category,
        'perishability': perishability,
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
      restaurantAddress: j['restaurantAddress'] as String? ?? '',
      restaurantLocation: j['restaurantLat'] is num && j['restaurantLng'] is num
          ? GeoPoint((j['restaurantLat'] as num).toDouble(),
              (j['restaurantLng'] as num).toDouble())
          : null,
      name: j['name'] as String,
      description: j['description'] as String,
      originalPrice: (j['originalPrice'] as num).toDouble(),
      discountedPrice: (j['discountedPrice'] as num).toDouble(),
      availableQuantity: j['availableQuantity'] as int,
      photoUrl: j['photoUrl'] as String?,
      ingredients: List<String>.from(j['ingredients'] as List? ?? const []),
      allergens: List<String>.from(j['allergens'] as List? ?? const []),
      category: j['category'] as String?,
      perishability: j['perishability'] as String?,
      isActive: j['isActive'] as bool,
      pickupStart: fecha(j['pickupStart']),
      pickupEnd: fecha(j['pickupEnd']),
      createdAt: fecha(j['createdAt'])!,
    );
  }
}
