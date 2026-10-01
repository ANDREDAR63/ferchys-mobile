import 'producto.dart';
import '../utils/valores.dart';

/// Modelo de una promocion (tabla `promotions`).
///
/// Una promocion puede aplicar a un producto concreto o, si `productoId` es
/// null, a todo el catalogo. El backend filtra las vencidas en GET
/// /promotions para cualquiera que no sea admin.
///
/// Nota: la app movil no descuenta el precio. La columna `discount_percentage`
/// se muestra como referencia, pero el total del carrito y del pedido lo
/// calcula el backend con el precio de lista. Si en el futuro se quiere
/// aplicar el descuento de verdad, este es el punto unico a cambiar.
class Promocion {
  final int id;
  final String nombre;
  final double porcentajeDescuento;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final int? productoId;
  final Producto? producto;

  const Promocion({
    required this.id,
    required this.nombre,
    required this.porcentajeDescuento,
    this.fechaInicio,
    this.fechaFin,
    this.productoId,
    this.producto,
  });

  factory Promocion.desdeJson(Map<String, dynamic> json) {
    return Promocion(
      id: aEntero(json['id']),
      nombre: json['name'] as String? ?? 'Promocion',
      porcentajeDescuento: aDoble(json['discount_percentage']),
      // Son columnas date, asi que llegan como "2026-09-30" sin hora.
      fechaInicio: DateTime.tryParse(json['start_date'] as String? ?? ''),
      fechaFin: DateTime.tryParse(json['end_date'] as String? ?? ''),
      productoId: aEntero(json['product_id']),
      producto: json['product'] is Map<String, dynamic>
          ? Producto.desdeJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Aplica a todo el catalogo en vez de a un solo producto.
  bool get esGlobal => productoId == null;

  /// La promocion ya paso su fecha de fin.
  bool get estaVencida {
    if (fechaFin == null) return false;
    // Solo comparamos la fecha: una promo que termina hoy sigue siendo valida.
    final hoy = DateTime.now();
    final finDelDia = DateTime(fechaFin!.year, fechaFin!.month, fechaFin!.day);
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    return hoySinHora.isAfter(finDelDia);
  }

  /// La promocion se puede aplicar ahora mismo.
  ///
  /// Son las dos condiciones: que ya haya empezado y que no haya terminado. La
  /// fecha de inicio se compara tambien sin hora, para que una promo que arranca
  /// hoy a las 6 de la tarde no se vea activa desde la madrugada.
  bool get estaVigente {
    if (estaVencida) return false;

    if (fechaInicio == null) return true;

    final hoy = DateTime.now();
    final inicioDelDia = DateTime(
      fechaInicio!.year,
      fechaInicio!.month,
      fechaInicio!.day,
    );
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);

    return !hoySinHora.isBefore(inicioDelDia);
  }

  /// Descuento en dinero sobre un precio, segun el porcentaje de la promo.
  double descuentoSobre(double precio) {
    return precio * (porcentajeDescuento / 100);
  }
}
