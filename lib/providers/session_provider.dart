import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Sesión actual: escucha Firebase Auth y el documento `users/{uid}`.
class SessionProvider extends ChangeNotifier {
  SessionProvider({required AuthService auth, required FirestoreService firestore})
      : _auth = auth,
        _firestore = firestore {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  final AuthService _auth;
  final FirestoreService _firestore;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;

  AppUser? _user;
  bool _loading = true;
  bool _busy = false;
  bool _profileMissing = false;
  bool _profileListenFailed = false;
  String? _authError;

  AppUser? get user => _user;
  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isRestaurant => _user?.isRestaurant ?? false;

  /// `true` mientras hay un inicio de sesión o registro en curso.
  bool get isBusy => _busy;

  /// Último error de autenticación, listo para mostrar al usuario.
  String? get authError => _authError;

  void _onAuthChanged(User? firebaseUser) {
    _userSub?.cancel();
    _profileMissing = false;
    _profileListenFailed = false;
    if (firebaseUser == null) {
      _user = null;
      _loading = false;
      notifyListeners();
      return;
    }
    // Durante login/registro la vista de autenticación muestra su propio
    // indicador; así no se desmonta el formulario si algo falla.
    if (!_busy) {
      _loading = true;
      notifyListeners();
    }
    _userSub = _firestore.watchUser(firebaseUser.uid).listen(
      (appUser) {
        _profileMissing = appUser == null;
        if (appUser == null) {
          // En el registro el perfil se escribe justo después de crear la
          // cuenta en Auth; la ausencia momentánea es esperada.
          if (!_busy) _handleMissingProfile();
          return;
        }
        _user = appUser;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('Error al escuchar users/${firebaseUser.uid}: $e');
        // Cerrar sesión a mitad del registro invalidaría el token con el que
        // se está escribiendo el perfil; se reintenta al terminar.
        if (_busy) {
          _profileListenFailed = true;
          return;
        }
        _failSession('No se pudo cargar tu perfil. Intenta de nuevo.');
      },
    );
  }

  void _handleMissingProfile() => _failSession(
      'Esta cuenta no tiene un perfil registrado. Crea una cuenta nueva.');

  void _failSession(String message) {
    _user = null;
    _loading = false;
    _authError = message;
    notifyListeners();
    _auth.signOut();
  }

  /// Inicia sesión con correo y contraseña. Devuelve `true` si tuvo éxito;
  /// si falla, el motivo queda en [authError].
  Future<bool> signIn({required String email, required String password}) =>
      _runAuthAction(() => _auth.signIn(email: email, password: password));

  /// Crea la cuenta con el [role] elegido. Para restaurantes se requieren
  /// [restaurantName] y [restaurantAddress].
  Future<bool> register({
    required String displayName,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
    String? restaurantName,
    String? restaurantAddress,
  }) =>
      _runAuthAction(() => _auth.register(
            displayName: displayName,
            email: email,
            password: password,
            role: role,
            phone: phone,
            restaurantName: restaurantName,
            restaurantAddress: restaurantAddress,
          ));

  Future<bool> _runAuthAction(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _authError = null;
    notifyListeners();

    try {
      await action();
      return true;
    } on FirebaseAuthException catch (e) {
      _authError = _messageFor(e.code);
      return false;
    } on RescueException catch (e) {
      _authError = e.message;
      return false;
    } on FirebaseException catch (e) {
      // Errores de Firestore al guardar el perfil (reglas, red, etc.).
      _authError = _firestoreMessageFor(e.code);
      return false;
    } catch (e) {
      debugPrint('Error inesperado de autenticación: $e');
      _authError = 'Ocurrió un error inesperado. Intenta de nuevo.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
      final current = _auth.currentUser;
      if (current != null && _profileListenFailed) {
        // El listener murió durante el registro; el perfil ya existe.
        _onAuthChanged(current);
      } else if (_profileMissing && current != null) {
        _handleMissingProfile();
      }
    }
  }

  static String _firestoreMessageFor(String code) => switch (code) {
        'permission-denied' =>
          'Firestore rechazó guardar tu perfil. Revisa las reglas de seguridad.',
        'unavailable' || 'deadline-exceeded' =>
          'No se pudo conectar con el servidor. Intenta de nuevo.',
        'not-found' => 'La base de datos de Firestore no está configurada.',
        _ => 'No se pudo guardar tu perfil ($code).',
      };

  void clearAuthError() {
    if (_authError == null) return;
    _authError = null;
    notifyListeners();
  }

  static String _messageFor(String code) => switch (code) {
        'invalid-email' => 'El correo no tiene un formato válido.',
        'user-disabled' => 'Esta cuenta fue deshabilitada.',
        // Firebase devuelve invalid-credential cuando está activa la
        // protección contra enumeración de correos.
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Correo o contraseña incorrectos.',
        'email-already-in-use' => 'Ya existe una cuenta con este correo.',
        'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
        'operation-not-allowed' =>
          'El registro con correo no está habilitado en Firebase.',
        'too-many-requests' =>
          'Demasiados intentos. Espera un momento e intenta de nuevo.',
        'network-request-failed' => 'Sin conexión a internet.',
        _ => 'No se pudo completar la operación ($code).',
      };

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
