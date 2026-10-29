import 'package:cloud_firestore/cloud_firestore.dart';

/// Rol de la cuenta dentro de la app.
enum UserRole {
  cliente,
  restaurante;

  static UserRole fromString(String? value) => UserRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => UserRole.cliente,
      );
}

/// Cuenta autenticada. Documento: `users/{uid}`.
///
/// Si [role] es [UserRole.restaurante], [restaurantId] apunta al documento
/// `restaurants/{restaurantId}` que administra esta cuenta.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? phone;
  final String? photoUrl;
  final UserRole role;
  final String? restaurantId;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.phone,
    this.photoUrl,
    this.restaurantId,
  });

  bool get isRestaurant => role == UserRole.restaurante;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
      role: UserRole.fromString(data['role'] as String?),
      restaurantId: data['restaurantId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'phone': phone,
        'photoUrl': photoUrl,
        'role': role.name,
        'restaurantId': restaurantId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  AppUser copyWith({
    String? displayName,
    String? phone,
    String? photoUrl,
    UserRole? role,
    String? restaurantId,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        phone: phone ?? this.phone,
        photoUrl: photoUrl ?? this.photoUrl,
        role: role ?? this.role,
        restaurantId: restaurantId ?? this.restaurantId,
        createdAt: createdAt,
      );
}
