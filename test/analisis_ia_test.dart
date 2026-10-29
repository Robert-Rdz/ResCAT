import 'package:flutter_test/flutter_test.dart';
import 'package:rescate_alimentos/models/analisis_ia.dart';

/// Verifica que la app lea el JSON del contrato de IA (sección 1.3).
void main() {
  test('lee una respuesta válida del contrato', () {
    final a = AnalisisIA.fromJson({
      'esComida': true,
      'confianza': 0.92,
      'titulo': 'Enchiladas verdes de pollo',
      'descripcion': 'Tres enchiladas con crema y queso fresco.',
      'ingredientes': ['tortilla de maíz', 'pollo', 'salsa verde'],
      'alergenos': ['lácteos'],
      'categoria': 'platillo fuerte',
      'perecibilidad': 'media',
    });
    expect(a.esComida, isTrue);
    expect(a.perecibilidad, Perecibilidad.media);
    expect(a.requiereRevision, isFalse);
  });

  test('confianza baja marca revisión', () {
    final a = AnalisisIA.fromJson({'esComida': true, 'confianza': 0.5});
    expect(a.requiereRevision, isTrue);
  });

  test('campos faltantes no rompen la lectura', () {
    final a = AnalisisIA.fromJson({});
    expect(a.esComida, isFalse);
    expect(a.ingredientes, isEmpty);
    expect(a.perecibilidad, Perecibilidad.media);
  });
}
