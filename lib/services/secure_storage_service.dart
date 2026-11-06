import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';

/// Guarda cifrado (Keystore en Android, Keychain en iOS) el perfil de la
/// última sesión, para abrir la pantalla correcta sin esperar a Firestore.
///
/// No guarda contraseñas ni tokens: de eso se encarga Firebase Auth.
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kPerfil = 'sesion_perfil';

  Future<void> guardarPerfil(AppUser user) => _storage.write(
        key: _kPerfil,
        value: jsonEncode({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'role': user.role.name,
          'restaurantId': user.restaurantId,
        }),
      );

  /// Devuelve el perfil guardado solo si pertenece al [uid] actual.
  Future<AppUser?> perfilGuardado(String uid) async {
    final raw = await _storage.read(key: _kPerfil);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['uid'] != uid) return null;
      return AppUser(
        uid: uid,
        email: j['email'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        role: UserRole.fromString(j['role'] as String?),
        restaurantId: j['restaurantId'] as String?,
        // No se usa para decidir nada; Firestore trae el valor real.
        createdAt: DateTime.now(),
      );
    } catch (_) {
      // Dato corrupto o de una versión anterior: se ignora y manda Firestore.
      return null;
    }
  }

  Future<void> borrarSesion() => _storage.delete(key: _kPerfil);
}
