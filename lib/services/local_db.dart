import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/analisis_ia.dart';
import '../models/food_package.dart';

/// Caché local en SQLite. La disponibilidad real la decide Firestore.
class LocalDb {
  LocalDb._();
  static final LocalDb instancia = LocalDb._();

  static const _nombre = 'rescate_alimentos.db';
  // v2: borradores guardan la foto y el formulario (la tabla v1 no se usaba).
  static const _version = 2;

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
        _crearBorradores(batch);
        await batch.commit(noResult: true);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final batch = db.batch();
          batch.execute('DROP TABLE IF EXISTS borradores_publicacion');
          _crearBorradores(batch);
          await batch.commit(noResult: true);
        }
      },
    );
  }

  static void _crearBorradores(Batch batch) => batch.execute('''
        CREATE TABLE borradores_publicacion (
          restaurant_id TEXT PRIMARY KEY,
          foto BLOB,
          tipo_foto TEXT,
          json_ia TEXT,
          json_formulario TEXT NOT NULL,
          creado_en INTEGER NOT NULL
        )''');

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

  /// Un borrador por restaurante; guardar otro reemplaza al anterior.
  Future<void> guardarBorrador(BorradorPublicacion b) async {
    final d = await db;
    await d.insert(
      'borradores_publicacion',
      b.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<BorradorPublicacion?> leerBorrador(String restaurantId) async {
    final d = await db;
    final filas = await d.query(
      'borradores_publicacion',
      where: 'restaurant_id = ?',
      whereArgs: [restaurantId],
    );
    return filas.isEmpty ? null : BorradorPublicacion.fromRow(filas.first);
  }

  Future<void> borrarBorrador(String restaurantId) async {
    final d = await db;
    await d.delete('borradores_publicacion',
        where: 'restaurant_id = ?', whereArgs: [restaurantId]);
  }

  Future<void> limpiar() async {
    final d = await db;
    await d.delete('ofertas_cache');
    await d.delete('reservas_locales');
    await d.delete('borradores_publicacion');
  }
}

/// Publicación que no se pudo enviar: foto, análisis de IA y lo escrito en el
/// formulario, para reintentar sin volver a tomar la foto ni esperar a la IA.
class BorradorPublicacion {
  const BorradorPublicacion({
    required this.restaurantId,
    required this.creadoEn,
    this.foto,
    this.tipoFoto,
    this.analisis,
    this.nombre = '',
    this.descripcion = '',
    this.precioOriginal = '',
    this.precioRescate = '',
    this.cantidad = '',
  });

  final String restaurantId;
  final DateTime creadoEn;
  final Uint8List? foto;
  final String? tipoFoto;
  final AnalisisIA? analisis;

  // Tal como se escribieron, para devolverlos idénticos al formulario.
  final String nombre;
  final String descripcion;
  final String precioOriginal;
  final String precioRescate;
  final String cantidad;

  Map<String, Object?> toRow() => {
        'restaurant_id': restaurantId,
        'foto': foto,
        'tipo_foto': tipoFoto,
        'json_ia': analisis == null ? null : jsonEncode(analisis!.toJson()),
        'json_formulario': jsonEncode({
          'nombre': nombre,
          'descripcion': descripcion,
          'precioOriginal': precioOriginal,
          'precioRescate': precioRescate,
          'cantidad': cantidad,
        }),
        'creado_en': creadoEn.millisecondsSinceEpoch,
      };

  factory BorradorPublicacion.fromRow(Map<String, Object?> row) {
    final form =
        jsonDecode(row['json_formulario'] as String) as Map<String, dynamic>;
    final ia = row['json_ia'] as String?;
    return BorradorPublicacion(
      restaurantId: row['restaurant_id'] as String,
      creadoEn: DateTime.fromMillisecondsSinceEpoch(row['creado_en'] as int),
      foto: row['foto'] as Uint8List?,
      tipoFoto: row['tipo_foto'] as String?,
      analisis: ia == null
          ? null
          : AnalisisIA.fromJson(jsonDecode(ia) as Map<String, dynamic>),
      nombre: form['nombre'] as String? ?? '',
      descripcion: form['descripcion'] as String? ?? '',
      precioOriginal: form['precioOriginal'] as String? ?? '',
      precioRescate: form['precioRescate'] as String? ?? '',
      cantidad: form['cantidad'] as String? ?? '',
    );
  }
}
