import 'package:flutter_test/flutter_test.dart';
import 'package:rescate_alimentos/models/analisis_ia.dart';
import 'package:rescate_alimentos/services/gemini_service.dart';

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

  test('precio sugerido según perecibilidad', () {
    expect(Perecibilidad.alta.precioSugerido(120), 48);
    expect(Perecibilidad.media.precioSugerido(120), 60);
    expect(Perecibilidad.baja.precioSugerido(99), 59);
  });

  test('sin precio sugerido si no hay precio original válido', () {
    expect(Perecibilidad.media.precioSugerido(0), isNull);
    expect(Perecibilidad.alta.precioSugerido(1), isNull);
  });

  test('reconoce cuando Gemini está saturado', () {
    expect(
        GeminiService.esSaturacion(Exception(
            'This model is currently experiencing high demand. Please try '
            'again later.')),
        isTrue);
    expect(GeminiService.esSaturacion(Exception('API key not valid')), isFalse);
  });

  group('campoParcial (streaming)', () {
    String campo(String json, String c) => GeminiService.campoParcial(json, c);

    test('campo aún no recibido', () {
      expect(campo('{"esComida": true, "ti', 'titulo'), '');
    });

    test('valor a medias', () {
      expect(campo('{"esComida":true,"titulo":"Enchiladas ver', 'titulo'),
          'Enchiladas ver');
    });

    test('valor completo con escapes', () {
      expect(campo(r'{"titulo":"Pay \"casero\"","descripcion":"x"}', 'titulo'),
          'Pay "casero"');
    });

    test('escape cortado a la mitad', () {
      expect(campo(r'{"titulo":"Caf\u00', 'titulo'), 'Caf');
      expect(campo(r'{"titulo":"Pay \', 'titulo'), 'Pay ');
    });
  });
}
