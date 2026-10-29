import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';

/// Guarda cifrados el uid y el rol de la última sesión para abrir la app
/// sin esperar a Firestore.
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kUid = 'sesion_uid';
  static const _kRol = 'sesion_rol';

  Future<void> guardarSesion(String uid, UserRole rol) async {
    await _storage.write(key: _kUid, value: uid);
    await _storage.write(key: _kRol, value: rol.name);
  }

  /// Devuelve el rol guardado solo si pertenece al [uid] actual.
  Future<UserRole?> rolGuardado(String uid) async {
    final uidGuardado = await _storage.read(key: _kUid);
    if (uidGuardado != uid) return null;
    final rol = await _storage.read(key: _kRol);
    return rol == null ? null : UserRole.fromString(rol);
  }

  Future<void> borrarSesion() async {
    await _storage.delete(key: _kUid);
    await _storage.delete(key: _kRol);
  }
}
