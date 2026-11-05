import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../models/analisis_ia.dart';

/// Falla pasajera (Gemini saturado o colgado); vale la pena reintentar.
/// [mensaje] es lo que ve el usuario si el reintento también falla.
class _Reintentable implements Exception {
  const _Reintentable(this.mensaje);
  final String mensaje;
}

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
                // Describir una foto no requiere razonar; así responde en
                // pocos segundos. gemini-3.8-flash no acepta `minimal`.
                thinkingConfig:
                    ThinkingConfig.withThinkingLevel(ThinkingLevel.low),
              ),
            );

  // gemini-3.8-flash y 3.5-flash se quedaban colgados o daban 500
  // "high demand" (2026-11-04); flash-lite responde en ~1 s.
  static const nombreModelo = 'gemini-3.5-flash-lite';

  /// RNF1 pide < 5 s; se deja margen para redes móviles lentas.
  /// Por intento; con el reintento el peor caso queda en ~31 s. Si un
  /// intento se cuelga, empezar otro suele ser más rápido que esperarlo.
  static const tiempoLimite = Duration(seconds: 15);

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

  /// Contrato de la sección 1.3. Título y descripción van primero para que
  /// el streaming los muestre cuanto antes.
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
    propertyOrdering: [
      'esComida',
      'titulo',
      'descripcion',
      'ingredientes',
      'alergenos',
      'categoria',
      'perecibilidad',
      'confianza',
    ],
  );

  /// [jpeg] debe venir ya reducida (image_picker con maxWidth 1024, calidad 80).
  ///
  /// La respuesta llega por streaming; [onAvance] recibe el título y la
  /// descripción parciales conforme Gemini los va escribiendo.
  ///
  /// Si Gemini está saturado o no responde a tiempo, se reintenta una vez
  /// tras [esperaReintento]; [onReintento] avisa a la pantalla antes.
  Future<AnalisisIA> analizarPlatillo(
    Uint8List jpeg, {
    void Function(String titulo, String descripcion)? onAvance,
    VoidCallback? onReintento,
  }) async {
    try {
      return await _intentar(jpeg, onAvance);
    } on _Reintentable {
      onReintento?.call();
      await Future<void>.delayed(esperaReintento);
      try {
        return await _intentar(jpeg, onAvance);
      } on _Reintentable catch (e) {
        throw AnalisisException(e.mensaje);
      }
    }
  }

  static const esperaReintento = Duration(seconds: 1);

  /// Gemini no da código HTTP en la excepción; se reconoce por el mensaje.
  @visibleForTesting
  static bool esSaturacion(Object error) {
    final m = error.toString().toLowerCase();
    return m.contains('high demand') ||
        m.contains('overloaded') ||
        m.contains('unavailable') ||
        m.contains('try again later');
  }

  Future<AnalisisIA> _intentar(
    Uint8List jpeg,
    void Function(String titulo, String descripcion)? onAvance,
  ) async {
    final texto = StringBuffer();
    // `.timeout` no cancela el stream; esto evita que un intento abandonado
    // siga escribiendo encima del reintento.
    var abandonado = false;
    try {
      final flujo = _modelo.generateContentStream([
        Content.multi([
          TextPart('Analiza este platillo.'),
          InlineDataPart('image/jpeg', jpeg),
        ]),
      ]);
      await flujo.forEach((parte) {
        if (abandonado) return;
        texto.write(parte.text ?? '');
        if (onAvance != null) {
          final parcial = texto.toString();
          onAvance(campoParcial(parcial, 'titulo'),
              campoParcial(parcial, 'descripcion'));
        }
      }).timeout(tiempoLimite);
    } on TimeoutException {
      abandonado = true;
      throw const _Reintentable(
          'El análisis tardó demasiado. Reintenta o llena los datos a mano.');
    } catch (e) {
      // El usuario ve un mensaje genérico; el error real queda en el log.
      debugPrint('Gemini falló: ${e.runtimeType}: $e');
      if (esSaturacion(e)) {
        throw const _Reintentable(
            'El servicio de IA está saturado. Reintenta en unos segundos o '
            'llena los datos a mano.');
      }
      throw const AnalisisException(
          'No se pudo analizar la foto. Reintenta o llena los datos a mano.');
    }

    if (texto.isEmpty) {
      throw const AnalisisException('La IA no devolvió resultado.');
    }
    try {
      return AnalisisIA.fromJson(
          jsonDecode(texto.toString()) as Map<String, dynamic>);
    } on FormatException {
      throw const AnalisisException('La respuesta de la IA no es válida.');
    }
  }

  /// Extrae el valor (quizá incompleto) de un campo de texto de un JSON que
  /// todavía se está recibiendo. Devuelve '' si el campo aún no aparece.
  @visibleForTesting
  static String campoParcial(String json, String campo) {
    final m = RegExp('"$campo"' r'\s*:\s*"((?:[^"\\]|\\.)*)').firstMatch(json);
    if (m == null) return '';
    var crudo = m.group(1)!;
    // Un escape cortado a la mitad (termina en \ o \u00) no se puede
    // decodificar; se recorta hasta que sí.
    for (var i = 0; i < 6 && crudo.isNotEmpty; i++) {
      try {
        return jsonDecode('"$crudo"') as String;
      } on FormatException {
        crudo = crudo.substring(0, crudo.length - 1);
      }
    }
    return '';
  }
}
