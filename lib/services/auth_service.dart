import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'firestore_service.dart';

/// Registro e inicio de sesión con email/contraseña.
class AuthService {
  AuthService({FirebaseAuth? auth, FirestoreService? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirestoreService();

  final FirebaseAuth _auth;
  final FirestoreService _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Crea la cuenta en Auth y su perfil en Firestore con el [role] elegido.
  ///
  /// Para [UserRole.restaurante] son obligatorios [restaurantName] y
  /// [restaurantAddress]. Si falla la escritura en Firestore, la cuenta de
  /// Auth se elimina para no dejar usuarios sin perfil.
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    UserRole role = UserRole.cliente,
    String? phone,
    String? restaurantName,
    String? restaurantAddress,
  }) async {
    if (role == UserRole.restaurante &&
        ((restaurantName?.trim().isEmpty ?? true) ||
            (restaurantAddress?.trim().isEmpty ?? true))) {
      throw const RescueException(
          'Indica el nombre y la dirección del restaurante.');
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final firebaseUser = cred.user!;

    try {
      // Garantiza que Firestore envíe el token de la cuenta recién creada;
      // sin él las reglas ven request.auth == null y rechazan la escritura.
      await firebaseUser.getIdToken(true);
      final cleanPhone = phone?.trim() ?? '';
      final user = await _firestore.createUserProfile(
        uid: firebaseUser.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: role,
        phone: cleanPhone.isEmpty ? null : cleanPhone,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
      );
      // El perfil ya existe; un fallo aquí no debe deshacer el registro.
      try {
        await firebaseUser.updateDisplayName(displayName.trim());
      } catch (e) {
        debugPrint('No se pudo actualizar displayName en Auth: $e');
      }
      return user;
    } catch (e, st) {
      debugPrint('Fallo al crear el perfil en Firestore: $e\n$st');
      // Recién creada, así que no requiere reautenticación.
      try {
        await firebaseUser.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();
}
