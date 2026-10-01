/// Modelo de una direccion de entrega (tabla `addresses`).

library;

import '../utils/valores.dart';

///
/// Solo el backend expone endpoints de direcciones: POST /register ya crea
/// una direccion por defecto, y el usuario puede agregar mas con POST
/// /addresses. En la app movil se listan para elegir donde entregar y se
/// puede crear una nueva desde el checkout.
class Direccion {
  final int id;
  final String etiqueta;
  final String direccionCompleta;
  final String ciudad;
  final bool esPredeterminada;

  const Direccion({
    required this.id,
    required this.direccionCompleta,
    this.etiqueta = 'Casa',
    this.ciudad = 'Bogota',
    this.esPredeterminada = false,
  });

  factory Direccion.desdeJson(Map<String, dynamic> json) {
    return Direccion(
      id: aEntero(json['id']),
      // El nombre de la columna en la base es `full_address` y en espanol
      // queda mas largo que "direccion".
      direccionCompleta: json['full_address'] as String? ?? '',
      etiqueta: json['label'] as String? ?? 'Casa',
      ciudad: json['city'] as String? ?? 'Bogota',
      esPredeterminada: aBooleano(json['is_default']),
    );
  }

  /// Texto de una linea para las tarjetas: "Carrera 7 #32-16, Bogota".
  String get textoCompleto {
    if (ciudad.isEmpty) return direccionCompleta;
    return '$direccionCompleta, $ciudad';
  }
}
