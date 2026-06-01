class Feriado {
  final String nombre;
  final DateTime fecha;
  final String tipo;
  final bool irrenunciable;
  final String comentarios;

  const Feriado({
    required this.nombre,
    required this.fecha,
    required this.tipo,
    required this.irrenunciable,
    required this.comentarios,
  });

  /// Formato APIs Digital Chile: apis.digital.gob.cl
  factory Feriado.fromJson(Map<String, dynamic> json) => Feriado(
        nombre: (json['nombre'] as String?) ?? '',
        fecha: DateTime.parse(json['fecha'] as String),
        tipo: (json['tipo'] as String?) ?? '',
        irrenunciable: (json['irrenunciable'] as int?) == 1,
        comentarios: (json['comentarios'] as String?) ?? '',
      );

  /// Formato Nager Date API: date.nager.at
  factory Feriado.fromNager(Map<String, dynamic> json) {
    final types = (json['types'] as List?)?.cast<String>() ?? [];
    return Feriado(
      nombre: (json['localName'] as String?) ?? '',
      fecha: DateTime.parse(json['date'] as String),
      tipo: types.contains('Public') ? 'Civil' : (types.firstOrNull ?? 'Civil'),
      irrenunciable: types.contains('Public'),
      comentarios: (json['name'] as String?) ?? '',
    );
  }
}
