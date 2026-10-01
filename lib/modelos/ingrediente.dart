/// Modelo de un insumo de inventario (tabla `ingredients`).

library;

import '../utils/valores.dart';

///
/// El insumo no se compra: es la materia prima de las recetas. Cada producto
/// declara cuanto de cada insumo necesita en la tabla pivote
/// `ingredient_product`, y el backend expone esa relacion en la columna
/// `pivot.quantity_required`.
///
/// Sirve para dos cosas: mostrar el inventario al cocinero, y calcular si
/// un pedido se puede preparar con el stock actual (ver [InsumoRequerido]).
class Ingrediente {
  final int id;
  final String nombre;
  final String unidad;
  final double stockActual;
  final double stockMinimo;

  const Ingrediente({
    required this.id,
    required this.nombre,
    required this.unidad,
    this.stockActual = 0,
    this.stockMinimo = 0,
  });

  factory Ingrediente.desdeJson(Map<String, dynamic> json) {
    return Ingrediente(
      id: aEntero(json['id']),
      nombre: json['name'] as String? ?? '',
      // La migracion limita la unidad a 20 caracteres y el comentario sugiere
      // estos tres valores: gr, ml o unidades.
      unidad: json['unit'] as String? ?? 'unidades',
      // Son decimal(10,2) en MySQL, asi que llegan como string.
      stockActual: aDoble(json['current_stock']),
      stockMinimo: aDoble(json['minimum_stock']),
    );
  }

  /// El stock quedo por debajo del minimo: hay que reponer.
  bool get stockBajo => stockActual <= stockMinimo;

  /// Porcentaje de stock disponible respecto al minimo, que es la metrica que
  /// usa el endpoint de reportes para clasificar entre critico y bajo.
  double get porcentajeDisponible {
    if (stockMinimo <= 0) return 100;
    return (stockActual / stockMinimo) * 100;
  }
}

/// Un insumo ya sumarizado para un pedido concreto.
///
/// La app tiene que responde "este pedido se puede preparar?" comparando
/// total requerido contra stock actual. Ese calculo se hace en el cliente
/// (igual que en la version web) y por eso necesita esta clase intermedia:
/// el insumo original mas cuanto se gasta en este pedido.
class InsumoRequerido {
  final Ingrediente ingrediente;
  final double cantidadRequerida;

  const InsumoRequerido({
    required this.ingrediente,
    required this.cantidadRequerida,
  });

  /// No alcanza el stock para cubrir lo que pide el pedido.
  bool get stockInsuficiente => cantidadRequerida > ingrediente.stockActual;

  /// Texto de consumo: "120 gr de 300 disponibles".
  String get descripcion {
    return '${formatearCantidad(cantidadRequerida)} ${ingrediente.unidad} '
        'de ${formatearCantidad(ingrediente.stockActual)} disponibles';
  }
}

/// Formatea un numero quitando decimales sobrantes.
///
/// Se define aqui y no en utils/formateo.dart a proposito: este archivo debe
/// poder entenderse solo. Los 300.0 y 0.5 se ven raros en la UI.
String formatearCantidad(double valor) {
  if (valor == valor.roundToDouble()) {
    return valor.toInt().toString();
  }
  return valor.toStringAsFixed(1);
}
