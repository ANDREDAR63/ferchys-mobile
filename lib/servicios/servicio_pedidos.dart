/// Servicio de pedidos, pagos y direcciones.
///
/// Agrupa tres controladores del backend (Order, Payment y Address) porque en
/// el flujo de compra estan encadenados: crear el pedido, pagarlo y tener una
/// direccion de entrega son pasos seguidos de la misma accion.
library;

import '../modelos/direccion.dart';
import '../modelos/pago.dart';
import '../modelos/pedido.dart';
import 'cliente_api.dart';

class ServicioPedidos {
  final ClienteApi _api;

  ServicioPedidos(this._api);

  /// GET /orders
  ///
  /// No hace falta ningun filtro por rol en la app: el backend ya devuelve una
  /// lista distinta segun quien pregunta. Un cliente ve sus pedidos, un
  /// cocinero ve los que tiene que preparar, un repartidor los que tiene que
  /// entregar y un admin todos. Por eso una sola funcion sirve para las cuatro
  /// pantallas de dashboard.
  Future<List<Pedido>> obtenerPedidos() async {
    final datos = await _api.get('/orders');
    return _convertirLista<Pedido>(datos, Pedido.desdeJson);
  }

  /// GET /orders/{id}
  Future<Pedido> obtenerPedido(int id) async {
    final datos = await _api.get('/orders/$id');
    return Pedido.desdeJson(datos as Map<String, dynamic>);
  }

  /// POST /orders
  ///
  /// Crea el pedido a partir del carrito actual y lo vacia. El total lo
  /// calcula el backend (no se envia a mano) para que el cliente no pueda
  /// inventarse el precio.
  Future<Pedido> crearPedido({required int direccionId}) async {
    final datos = await _api.post(
      '/orders',
      cuerpo: {'address_id': direccionId},
    );
    return Pedido.desdeJson(datos as Map<String, dynamic>);
  }

  /// PUT /orders/{id}/status
  ///
  /// El backend es la autoridad: decide si la transicion es valida para el rol
  /// y responde 422 si no lo es. Esta app solo evita enviar transiciones que
  /// ya sabe que van a fallar (ver [PedidoEstados]), pero la validacion real
  /// siempre ocurre en el servidor.
  Future<Pedido> actualizarEstado({
    required int pedidoId,
    required String nuevoEstado,
  }) async {
    final datos = await _api.put(
      '/orders/$pedidoId/status',
      cuerpo: {'status': nuevoEstado},
    );
    return Pedido.desdeJson(datos as Map<String, dynamic>);
  }

  /// POST /orders/{id}/payments
  ///
  /// El backend aprueba el pago en el mismo request y de paso mueve el pedido
  /// de `pending` a `preparing`. Por eso el checkout encadena esta llamada
  /// justo despues de crear el pedido.
  Future<Pago> registrarPago({
    required int pedidoId,
    required int metodoPagoId,
  }) async {
    final datos = await _api.post(
      '/orders/$pedidoId/payments',
      cuerpo: {'payment_method_id': metodoPagoId},
    );
    return Pago.desdeJson(datos as Map<String, dynamic>);
  }

  /// GET /payment-methods
  ///
  /// Publico: se consulta antes de iniciar sesion para poder pintar las
  /// opciones de pago aunque el usuario todavia no tenga cuenta.
  Future<List<MetodoPago>> obtenerMetodosPago() async {
    final datos = await _api.get('/payment-methods');
    return _convertirLista<MetodoPago>(datos, MetodoPago.desdeJson);
  }

  /// GET /orders/{id}/payments
  Future<List<Pago>> obtenerPagosDe(int pedidoId) async {
    final datos = await _api.get('/orders/$pedidoId/payments');
    return _convertirLista<Pago>(datos, Pago.desdeJson);
  }

  List<T> _convertirLista<T>(
    dynamic datos,
    T Function(Map<String, dynamic>) construir,
  ) {
    if (datos is! List) return [];
    return datos.whereType<Map<String, dynamic>>().map(construir).toList();
  }
}

/// Servicio de direcciones de entrega.
///
/// El backend expone solo index y store. No hay update ni destroy, asi que en
/// la app una direccion se agrega o se elige, pero nunca se edita.
class ServicioDirecciones {
  final ClienteApi _api;

  ServicioDirecciones(this._api);

  /// GET /addresses
  Future<List<Direccion>> obtenerDirecciones() async {
    final datos = await _api.get('/addresses');
    return (datos as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Direccion.desdeJson)
        .toList();
  }

  /// POST /addresses
  ///
  /// [esPredeterminada] se activa cuando es la unica direccion o cuando el
  /// usuario la eligio en el checkout, para que la app la preseleccione la
  /// proxima vez.
  Future<Direccion> crearDireccion({
    required String direccionCompleta,
    String etiqueta = 'Casa',
    String ciudad = 'Bogota',
    bool esPredeterminada = false,
  }) async {
    final datos = await _api.post(
      '/addresses',
      cuerpo: {
        'full_address': direccionCompleta,
        'label': etiqueta,
        'city': ciudad,
        'is_default': esPredeterminada,
      },
    );
    return Direccion.desdeJson(datos as Map<String, dynamic>);
  }
}
