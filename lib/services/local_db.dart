import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/food_package.dart';

/// Caché local en SQLite. La disponibilidad real la decide Firestore.
class LocalDb {
  LocalDb._();
  static final LocalDb instancia = LocalDb._();

  static const _nombre = 'rescate_alimentos.db';
  static const _version = 1;

  Database? _db;

  Future<Database> get db async => _db ??= await _abrir();

  Future<Database> _abrir() async {
    final ruta = p.join(await getDatabasesPath(), _nombre);
    return openDatabase(
      ruta,
      version: _version,
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute('''
          CREATE TABLE ofertas_cache (
            id TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            actualizado_en INTEGER NOT NULL
          )''');
        batch.execute('''
          CREATE TABLE reservas_locales (
            id TEXT PRIMARY KEY,
            oferta_id TEXT NOT NULL,
            codigo TEXT NOT NULL,
            estado TEXT NOT NULL,
            expira_en INTEGER NOT NULL
          )''');
        batch.execute('''
          CREATE TABLE borradores_publicacion (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ruta_foto TEXT NOT NULL,
            json_ia TEXT,
            creado_en INTEGER NOT NULL
          )''');
        await batch.commit(noResult: true);
      },
    );
  }

  /// Reemplaza la caché completa con la última lista recibida de Firestore.
  Future<void> guardarOfertas(List<FoodPackage> ofertas) async {
    final d = await db;
    final ahora = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((txn) async {
      await txn.delete('ofertas_cache');
      for (final o in ofertas) {
        await txn.insert('ofertas_cache', {
          'id': o.id,
          'json': jsonEncode(o.toCacheJson()),
          'actualizado_en': ahora,
        });
      }
    });
  }

  Future<List<FoodPackage>> leerOfertas() async {
    final d = await db;
    final filas = await d.query('ofertas_cache');
    return filas
        .map((f) => FoodPackage.fromCacheJson(
            jsonDecode(f['json'] as String) as Map<String, dynamic>))
        .where((o) => o.isAvailable)
        .toList();
  }

  Future<void> guardarReserva({
    required String id,
    required String ofertaId,
    required String codigo,
    required String estado,
    required DateTime expiraEn,
  }) async {
    final d = await db;
    await d.insert(
      'reservas_locales',
      {
        'id': id,
        'oferta_id': ofertaId,
        'codigo': codigo,
        'estado': estado,
        'expira_en': expiraEn.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> reservasActivas() async {
    final d = await db;
    return d.query(
      'reservas_locales',
      where: 'estado = ? AND expira_en > ?',
      whereArgs: ['apartado', DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<int> guardarBorrador(String rutaFoto, {String? jsonIA}) async {
    final d = await db;
    return d.insert('borradores_publicacion', {
      'ruta_foto': rutaFoto,
      'json_ia': jsonIA,
      'creado_en': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> borrarBorrador(int id) async {
    final d = await db;
    await d.delete('borradores_publicacion', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> limpiar() async {
    final d = await db;
    await d.delete('ofertas_cache');
    await d.delete('reservas_locales');
    await d.delete('borradores_publicacion');
  }
}
