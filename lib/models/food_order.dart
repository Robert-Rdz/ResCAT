import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado del apartado.
enum OrderStatus {
  apartado,
  entregado,
  cancelado;

  static OrderStatus fromString(String? value) => OrderStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => OrderStatus.apartado,
      );
}

/// Apartado de un paquete por parte de un cliente. Documento: `orders/{id}`.
///
/// El cliente muestra [pin] en el restaurante; el restaurante lo captura y,
/// si coincide con un apartado activo suyo, la orden pasa a [OrderStatus.entregado].
class FoodOrder {
  final String id;
  final String userId;
  final String restaurantId;
  final String packageId;

  /// Desnormalizados para mostrar el historial sin lecturas extra.
  final String packageName;
  final String restaurantName;
  final int quantity;
  final double unitPrice;

  /// PIN de 4 dígitos ("0000"-"9999"), único entre los apartados activos
  /// del mismo restaurante.
  final String pin;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  const FoodOrder({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.packageId,
    required this.packageName,
    required this.restaurantName,
    required this.quantity,
    required this.unitPrice,
    required this.pin,
    required this.status,
    required this.createdAt,
    this.deliveredAt,
    this.cancelledAt,
  });

  double get total => unitPrice * quantity;

  bool get isActive => status == OrderStatus.apartado;

  factory FoodOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return FoodOrder(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      restaurantId: data['restaurantId'] as String? ?? '',
      packageId: data['packageId'] as String? ?? '',
      packageName: data['packageName'] as String? ?? '',
      restaurantName: data['restaurantName'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      pin: data['pin'] as String? ?? '',
      status: OrderStatus.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'restaurantId': restaurantId,
        'packageId': packageId,
        'packageName': packageName,
        'restaurantName': restaurantName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'pin': pin,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'deliveredAt': deliveredAt == null ? null : Timestamp.fromDate(deliveredAt!),
        'cancelledAt': cancelledAt == null ? null : Timestamp.fromDate(cancelledAt!),
      };
}
