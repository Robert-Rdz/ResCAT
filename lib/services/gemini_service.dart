import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/analisis_ia.dart';

class AnalisisException implements Exception {
  const AnalisisException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Analiza la foto del platillo con Gemini vía Firebase AI Logic; la API key
/// queda en Firebase, no en la app.
class GeminiService {
  GeminiService({GenerativeModel? modelo})
      : _modelo = modelo ??
            FirebaseAI.googleAI().generativeModel(
              model: nombreModelo,
              systemInstruction: Content.system(_instrucciones),
              generationConfig: GenerationConfig(
                temperature: 0.2,
                responseMimeType: 'application/json',
                responseSchema: esquemaRespuesta,
              ),
            );

  static const nombreModelo = 'gemini-2.5-flash';

  /// RNF1 pide < 5 s; se deja margen para la red.
  static const tiempoLimite = Duration(seconds: 8);

  final GenerativeModel _modelo;

  static const _instrucciones = '''
Eres el asistente de una app mexicana que vende platillos de pedidos cancelados.
Recibes la foto de un platillo recién preparado en un restaurante.
1. Decide si la imagen muestra comida lista para comer (esComida).
2. Si es comida, escribe en español de México:
   - titulo: nombre comercial corto (máx. 50 caracteres).
   - descripcion: 1 o 2 frases atractivas y honestas (máx. 160 caracteres).
   - ingredientes: los visibles o muy probables, en minúsculas.
   - alergenos: solo de esta lista si aplican: gluten, lácteos, huevo,
     cacahuate, nueces, soya, pescado, mariscos, ajonjolí.
   - categoria: una de: entrada, platillo fuerte, postre, bebida, panadería, otro.
   - perecibilidad: alta (mariscos crudos, sushi, ensaladas, lácteos frescos),
     media (guisos, carnes cocidas, pastas), baja (pan, galletas, empaquetados).
3. confianza: de 0 a 1, qué tan seguro estás de la identificación.
No inventes marcas ni precios. Si no es comida, deja los textos vacíos.
''';

  /// Contrato de la sección 1.3.
  static final esquemaRespuesta = Schema.object(
    properties: {
      'esComida': Schema.boolean(),
      'confianza': Schema.number(),
      'titulo': Schema.string(),
      'descripcion': Schema.string(),
      'ingredientes': Schema.array(items: Schema.string()),
      'alergenos': Schema.array(items: Schema.string()),
      'categoria': Schema.string(),
      'perecibilidad': Schema.enumString(enumValues: ['alta', 'media', 'baja']),
    },
  );

  /// [jpeg] debe venir ya reducida (image_picker con maxWidth 1024, calidad 80).
  Future<AnalisisIA> analizarPlatillo(Uint8List jpeg) async {
    final GenerateContentResponse respuesta;
    try {
      respuesta = await _modelo.generateContent([
        Content.multi([
          TextPart('Analiza este platillo.'),
          InlineDataPart('image/jpeg', jpeg),
        ]),
      ]).timeout(tiempoLimite);
    } on TimeoutException {
      throw const AnalisisException(
          'El análisis tardó demasiado. Reintenta o captura los datos a mano.');
    } catch (e) {
      throw AnalisisException('No se pudo analizar la foto: $e');
    }

    final texto = respuesta.text;
    if (texto == null || texto.isEmpty) {
      throw const AnalisisException('La IA no devolvió resultado.');
    }
    try {
      return AnalisisIA.fromJson(jsonDecode(texto) as Map<String, dynamic>);
    } on FormatException {
      throw const AnalisisException('La respuesta de la IA no es válida.');
    }
  }
}
