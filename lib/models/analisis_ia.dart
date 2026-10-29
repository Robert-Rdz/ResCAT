enum Perecibilidad {
  alta,
  media,
  baja;

  static Perecibilidad desdeTexto(String? valor) => Perecibilidad.values
      .firstWhere((p) => p.name == valor, orElse: () => Perecibilidad.media);
}

/// Respuesta de Gemini según el contrato de la sección 1.3.
class AnalisisIA {
  const AnalisisIA({
    required this.esComida,
    required this.confianza,
    required this.titulo,
    required this.descripcion,
    required this.ingredientes,
    required this.alergenos,
    required this.categoria,
    required this.perecibilidad,
  });

  /// Por debajo de este valor la UI resalta los campos para revisión.
  static const umbralConfianza = 0.7;

  final bool esComida;
  final double confianza;
  final String titulo;
  final String descripcion;
  final List<String> ingredientes;
  final List<String> alergenos;
  final String categoria;
  final Perecibilidad perecibilidad;

  bool get requiereRevision => confianza < umbralConfianza;

  factory AnalisisIA.fromJson(Map<String, dynamic> json) => AnalisisIA(
        esComida: json['esComida'] as bool? ?? false,
        confianza: (json['confianza'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0,
        titulo: (json['titulo'] as String? ?? '').trim(),
        descripcion: (json['descripcion'] as String? ?? '').trim(),
        ingredientes: List<String>.from(json['ingredientes'] as List? ?? const []),
        alergenos: List<String>.from(json['alergenos'] as List? ?? const []),
        categoria: (json['categoria'] as String? ?? '').trim(),
        perecibilidad: Perecibilidad.desdeTexto(json['perecibilidad'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'esComida': esComida,
        'confianza': confianza,
        'titulo': titulo,
        'descripcion': descripcion,
        'ingredientes': ingredientes,
        'alergenos': alergenos,
        'categoria': categoria,
        'perecibilidad': perecibilidad.name,
      };
}
