import 'direccion.dart';
import 'pago.dart';
import 'producto.dart';
import 'usuario.dart';
import '../utils/valores.dart';

/// Modelo de un pedido (tabla `orders`).
///
/// El ciclo de vida del pedido es el corazon del dominio, asi que los estados
/// estan centralizados en [PedidoEstados] en vez de repetidos como cadenas.
/// El backend valida las transiciones en OrderController::updateStatus, pero
/// la app las usa solo para decidir que botones mostrar.
class Pedido {
  final int id;
  final double total;
  final String estado;
  final DateTime? creadoEn;
  final List<ElementoPedido> items;
  final List<Pago> pagos;
  final List<HistorialEstado> historial;
  final Direccion? direccion;
  final Usuario? repartidor;

  const Pedido({
    required this.id,
    required this.total,
    required this.estado,
    this.creadoEn,
    this.items = const [],
    this.pagos = const [],
    this.historial = const [],
    this.direccion,
    this.repartidor,
  });

  factory Pedido.desdeJson(Map<String, dynamic> json) {
    return Pedido(
      id: aEntero(json['id']),
      total: aDoble(json['total']),
      estado: json['status'] as String? ?? PedidoEstados.pendiente,
      creadoEn: DateTime.tryParse(json['created_at'] as String? ?? ''),
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ElementoPedido.desdeJson)
          .toList(),
      pagos: (json['payments'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Pago.desdeJson)
          .toList(),
      historial: (json['statusHistory'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(HistorialEstado.desdeJson)
          .toList(),
      direccion: json['address'] is Map<String, dynamic>
          ? Direccion.desdeJson(json['address'] as Map<String, dynamic>)
          : null,
      repartidor: json['courier'] is Map<String, dynamic>
          ? Usuario.desdeJson(json['courier'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Suma de todos los subtotales. Se recalcula en vez de confiar en [total]
  /// para poder mostrar el detalle sin depender del servidor.
  double get totalDeItems {
    double suma = 0;
    for (final item in items) {
      suma += item.subtotal;
    }
    return suma;
  }

  /// Primer pago aprobado, si existe.
  ///
  /// El backend guarda un pago por pedido y lo aprueba al crearlo, asi que
  /// normalmente hay cero o uno. Se busca el aprobado y no el ultimo para no
  /// mostrar "cobro contra entrega" si ya se cobro.
  Pago? get pagoAprobado {
    for (final pago in pagos) {
      if (pago.aprobado) return pago;
    }
    return null;
  }

  bool get estaPagado => pagoAprobado != null;
}

/// Una linea del pedido: producto, cantidad y precio congelado.
///
/// `precioUnitario` es el precio en el momento de la compra, no el actual.
/// Por eso se llama asi y no `precio`: si el admin sube el precio del
/// cheesecake manana, este pedido debe seguir mostrando lo que se pago.
class ElementoPedido {
  final int id;
  final int cantidad;
  final double precioUnitario;
  final Producto? producto;

  const ElementoPedido({
    required this.id,
    required this.cantidad,
    required this.precioUnitario,
    this.producto,
  });

  factory ElementoPedido.desdeJson(Map<String, dynamic> json) {
    return ElementoPedido(
      id: aEntero(json['id']),
      cantidad: aEntero(json['quantity'], porDefecto: 1),
      precioUnitario: aDoble(json['unit_price']),
      producto: json['product'] is Map<String, dynamic>
          ? Producto.desdeJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  double get subtotal => precioUnitario * cantidad;

  /// Nombre del producto, o un texto generico si la relacion no vino.
  String get nombreProducto => producto?.nombre ?? 'Producto';
}

/// Un cambio de estado registrado en `order_status_histories`.
///
/// El backend escribe una fila en cada transicion, y esa tabla es la unica
/// fuente de verdad del recorrido del pedido.
class HistorialEstado {
  final String? estadoAnterior;
  final String estadoNuevo;
  final DateTime? cambiadoEn;

  const HistorialEstado({
    this.estadoAnterior,
    required this.estadoNuevo,
    this.cambiadoEn,
  });

  factory HistorialEstado.desdeJson(Map<String, dynamic> json) {
    return HistorialEstado(
      estadoAnterior: json['previous_status'] as String?,
      estadoNuevo: json['new_status'] as String? ?? '',
      // La tabla no tiene created_at (el modelo desactiva timestamps), asi que
      // la fecha real del cambio esta en changed_at.
      cambiadoEn: DateTime.tryParse(
        json['changed_at'] as String? ?? json['created_at'] as String? ?? '',
      ),
    );
  }
}

/// Los estados posibles de un pedido y su etiqueta en espanol.
///
/// Las claves coinciden con el enum de la migracion `create_orders_table`.
/// [siguiente] define el unico paso que puede dar cada rol, replicando el
/// mapa de transiciones del backend: el cocinero avanza pending -> preparing
/// -> shipped, y el repartidor cierra con delivered.
class PedidoEstados {
  PedidoEstados._();

  static const String pendiente = 'pending';
  static const String enPreparacion = 'preparing';
  static const String enCamino = 'shipped';
  static const String entregado = 'delivered';
  static const String cancelado = 'cancelled';

  /// Estado -> texto para mostrar. En el movil las etiquetas son cortas
  /// porque van en chips y cabeceras de tarjeta.
  ///
  /// Estas SI llevan tildes a proposito: son texto que lee la persona, no
  /// comentarios. En los comentarios del proyecto se omiten para no depender
  /// del teclado, pero en pantalla "En preparacion" se ve como un descuido.
  static const Map<String, String> etiquetas = {
    pendiente: 'Pendiente',
    enPreparacion: 'En preparación',
    enCamino: 'En camino',
    entregado: 'Entregado',
    cancelado: 'Cancelado',
  };

  /// Siguiente estado permitido para quien esta preparando el pedido.
  static const Map<String, String> siguienteDelCocinero = {
    pendiente: enPreparacion,
    enPreparacion: enCamino,
  };

  /// Un repartidor solo puede confirmar entrega de un pedido en camino.
  static const String siguienteDelRepartidor = entregado;

  /// Estados que el repartidor ve en su cola: lo que ya sale para entregar.
  static const List<String> estadosDelRepartidor = [enCamino];

  /// Estados que el cocinero ve: lo pagado por preparar y lo que ya prepara.
  static const List<String> estadosDelCocinero = [pendiente, enPreparacion];

  /// Texto legible de un estado, con fallback por si llega uno desconocido.
  static String etiquetaDe(String estado) {
    return etiquetas[estado] ?? estado;
  }
}
