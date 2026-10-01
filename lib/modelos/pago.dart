/// Modelo de un pago (tabla `payments`) y del metodo de pago.

library;

import '../utils/valores.dart';

///
/// No hay pasarela de pago real: el backend marca el pago como `approved` en
/// el mismo request que lo crea. Por eso estos modelos son tan planos.
///
/// Se agrupan en un archivo porque el metodo de pago siempre viaja anidado
/// dentro del pago (`payments.paymentMethod` en el JSON de Laravel) y un
/// MetodoPago suelto no aporta nada.
class Pago {
  final int id;
  final int pedidoId;
  final double monto;
  final String estado;
  final DateTime? pagadoEn;
  final MetodoPago? metodo;

  const Pago({
    required this.id,
    required this.pedidoId,
    required this.monto,
    required this.estado,
    this.pagadoEn,
    this.metodo,
  });

  factory Pago.desdeJson(Map<String, dynamic> json) {
    return Pago(
      id: aEntero(json['id']),
      pedidoId: aEntero(json['order_id']),
      monto: aDoble(json['amount']),
      estado: json['status'] as String? ?? 'pending',
      pagadoEn: DateTime.tryParse(json['paid_at'] as String? ?? ''),
      metodo: json['paymentMethod'] is Map<String, dynamic>
          ? MetodoPago.desdeJson(json['paymentMethod'] as Map<String, dynamic>)
          : null,
    );
  }

  /// El backend aprueba el pago al crearlo, asi que "approved" es el unico
  /// estado que representa dinero cobrado de verdad.
  bool get aprobado => estado == 'approved';

  String get nombreMetodo => metodo?.nombre ?? 'Efectivo contra entrega';
}

/// Un metodo de pago (tabla `payment_methods`).
///
/// GET /payment-methods es publico y devuelve solo los activos.
class MetodoPago {
  final int id;
  final String nombre;
  final bool activo;

  const MetodoPago({
    required this.id,
    required this.nombre,
    this.activo = true,
  });

  factory MetodoPago.desdeJson(Map<String, dynamic> json) {
    return MetodoPago(
      id: aEntero(json['id']),
      nombre: json['name'] as String? ?? 'Metodo de pago',
      activo: aBooleano(json['active'], porDefecto: true),
    );
  }
}
