import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescate_alimentos/models/models.dart';
import 'package:rescate_alimentos/services/local_db.dart';
import 'package:rescate_alimentos/services/secure_storage_service.dart';

void main() {
  group('BorradorPublicacion (SQLite)', () {
    test('se guarda y se recupera igual', () {
      final original = BorradorPublicacion(
        restaurantId: 'r1',
        creadoEn: DateTime(2026, 11, 5, 14, 30),
        foto: Uint8List.fromList([1, 2, 3]),
        tipoFoto: 'image/jpeg',
        analisis: AnalisisIA.fromJson({
          'esComida': true,
          'confianza': 0.9,
          'titulo': 'Tacos al pastor',
          'ingredientes': ['tortilla', 'cerdo'],
          'alergenos': <String>[],
          'perecibilidad': 'media',
        }),
        nombre: 'Tacos al pastor',
        precioOriginal: '120',
        precioRescate: '60',
        cantidad: '2',
      );

      final copia = BorradorPublicacion.fromRow(original.toRow());

      expect(copia.restaurantId, 'r1');
      expect(copia.creadoEn, original.creadoEn);
      expect(copia.foto, [1, 2, 3]);
      expect(copia.analisis!.titulo, 'Tacos al pastor');
      expect(copia.analisis!.ingredientes, ['tortilla', 'cerdo']);
      expect(copia.precioOriginal, '120');
      expect(copia.cantidad, '2');
    });

    test('sin foto ni análisis también funciona', () {
      final b = BorradorPublicacion(
        restaurantId: 'r1',
        creadoEn: DateTime(2026, 11, 5),
        nombre: 'Pan dulce',
      );
      final copia = BorradorPublicacion.fromRow(b.toRow());
      expect(copia.foto, isNull);
      expect(copia.analisis, isNull);
      expect(copia.nombre, 'Pan dulce');
    });
  });

  group('SecureStorageService', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    final user = AppUser(
      uid: 'u1',
      email: 'fonda@ejemplo.com',
      displayName: 'Doña Mary',
      role: UserRole.restaurante,
      restaurantId: 'r1',
      createdAt: DateTime(2026, 11, 1),
    );

    test('recupera el perfil del mismo usuario', () async {
      final s = SecureStorageService();
      await s.guardarPerfil(user);
      final p = await s.perfilGuardado('u1');
      expect(p!.role, UserRole.restaurante);
      expect(p.restaurantId, 'r1');
    });

    test('no lo entrega a otro usuario', () async {
      final s = SecureStorageService();
      await s.guardarPerfil(user);
      expect(await s.perfilGuardado('otro'), isNull);
    });

    test('se borra al cerrar sesión', () async {
      final s = SecureStorageService();
      await s.guardarPerfil(user);
      await s.borrarSesion();
      expect(await s.perfilGuardado('u1'), isNull);
    });
  });
}
