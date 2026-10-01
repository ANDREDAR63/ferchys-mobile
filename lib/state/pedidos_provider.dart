/// Estado de los pedidos y de las direcciones del usuario.
///
/// El backend tiene UNA sola lista de pedidos para todos los roles, y cambia
/// segun quien pregunta: el cliente ve los suyos, el admin y el personal
/// ven todos. Por eso este provider no distingue "mis pedidos" de "pedidos":
/// pide `GET /orders` y el backend decide. Si la app filtrara por cliente
/// ademas, el repartidor se quedaria sin ver nada.
///
/// Los pedidos que se listan y los que se actualizan (cocina, repartidor,
/// administrador) van en el mismo provider porque mover un pedido de "pendiente"
/// a "en preparacion" tiene que verse reflejado en la lista sin volver a
/// cambiar de pantalla.
library;

import 'package:flutter/foundation.dart';

import '../modelos/direccion.dart';
import '../modelos/pedido.dart';
import '../modelos/pago.dart';
import '../servicios/cliente_api.dart';
import '../servicios/servicio_pedidos.dart';

class PedidosProvider extends ChangeNotifier {
  final ServicioPedidos _pedidos;
  final ServicioDirecciones _direcciones;

  List<Pedido> _pedidosLista = [];
  List<Direccion> _direccionesLista = [];
  List<MetodoPago> _metodosPago = [];

  bool _cargando = false;

  /// Id del pedido abierto en detalle, o `null`.
  int? _pedidoAbierto;

  /// Id del pedido que se esta cambiando de estado, para deshabilitar solo ese
  /// boton y no toda la pantalla mientras la peticion viaja.
  int? _actualizandoPedidoId;

  String? _error;

  PedidosProvider({
    required ServicioPedidos pedidos,
    required ServicioDirecciones direcciones,
  }) : _pedidos = pedidos,
       _direcciones = direcciones;

  List<Pedido> get pedidos => List.unmodifiable(_pedidosLista);
  List<Direccion> get direcciones => List.unmodifiable(_direccionesLista);
  List<MetodoPago> get metodosPago => List.unmodifiable(_metodosPago);
  bool get cargando => _cargando;
  String? get error => _error;
  int? get pedidoAbierto => _pedidoAbierto;
  int? get actualizandoPedidoId => _actualizandoPedidoId;

  /// Pedido abierto en detalle, o `null`.
  ///
  /// Se saca de la lista en memoria, sin pedirlo otra vez al backend: el
  /// detalle ya viene completo en `GET /orders`, items e historial incluidos.
  Pedido? get pedidoEnDetalle {
    if (_pedidoAbierto == null) return null;

    for (final pedido in _pedidosLista) {
      if (pedido.id == _pedidoAbierto) return pedido;
    }

    return null;
  }

  /// Direccion que se ofrece por defecto al pagar.
  ///
  /// El backend marca una con `is_default`. Si no hay ninguna marcada se toma
  /// la primera, porque es mejor pedir que elija que dejarlo sin direccion.
  Direccion? get direccionSugerida {
    if (_direccionesLista.isEmpty) return null;

    for (final direccion in _direccionesLista) {
      if (direccion.esPredeterminada) return direccion;
    }

    return _direccionesLista.first;
  }

  /// Pedidos que aun no llegaron al cliente, ordenados por antiguedad.
  ///
  /// La cocina solo ve `pending` y `preparing`; el repartidor, `shipped`. El
  /// filtro se hace aqui para que las dos pantallas contengan exactamente lo
  /// que le corresponde a ese rol.
  List<Pedido> pendientesDeCocina() {
    return _pedidosLista
        .where(
          (pedido) =>
              pedido.estado == PedidoEstados.pendiente ||
              pedido.estado == PedidoEstados.enPreparacion,
        )
        .toList()
      ..sort((primero, segundo) => primero.id.compareTo(segundo.id));
  }

  List<Pedido> listosParaEntregar() {
    return _pedidosLista
        .where((pedido) => pedido.estado == PedidoEstados.enCamino)
        .toList()
      ..sort((primero, segundo) => primero.id.compareTo(segundo.id));
  }

  /// Carga pedidos, direcciones y metodos de pago.
  ///
  /// Se piden en paralelo con `Future.wait` en vez de uno tras otro: son tres
  /// llamadas independientes y encadenarlas hacia la pantalla seria tres veces
  /// la espera. La direccion solo se pide si la hay, porque es un dato que solo
  /// existe si la persona esta conectada.
  Future<void> cargar({bool pedirDirecciones = true}) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    // Las tres van a la vez y cada una se captura por separado, y no en un solo
    // `try` como un bloque, por una razon concreta: la pantalla esta hecha para
    // avisar "hay pedidos y ademas un error" y seguir mostrando la lista. Si las
    // tres fueran juntas, el fallo de una sola (por ejemplo, que no haya metodos
    // de pago configurados) borraria tambien los pedidos, que es justo lo que
    // esa pantalla promete no hacer.
    final problemas = <String>[];

    final resultados = await Future.wait([
      _capturar(problemas, _pedidos.obtenerPedidos, <Pedido>[]),
      _capturar(problemas, _pedidos.obtenerMetodosPago, <MetodoPago>[]),
      if (pedirDirecciones)
        _capturar(problemas, _direcciones.obtenerDirecciones, <Direccion>[])
      else
        Future.value(<Direccion>[]),
    ]);

    _pedidosLista = resultados[0] as List<Pedido>;
    _metodosPago = resultados[1] as List<MetodoPago>;
    _direccionesLista = resultados[2] as List<Direccion>;

    // Solo el primer fallo se muestra: tres mensajes iguales apilados no aportan
    // nada y empujan la lista hacia abajo.
    if (problemas.isNotEmpty) _error = problemas.first;

    _cargando = false;
    notifyListeners();
  }

  /// Ejecuta [peticion] y devuelve [vacio] si falla, anotando el motivo.
  Future<T> _capturar<T>(
    List<String> problemas,
    Future<T> Function() peticion,
    T vacio,
  ) async {
    try {
      return await peticion();
    } catch (error) {
      problemas.add(_aTexto(error));
      return vacio;
    }
  }

  /// Crea el pedido a partir del carrito del servidor y registra el pago.
  ///
  /// Son DOS llamadas y el orden importa: el pedido tiene que existir antes de
  /// poder pagarlo, porque el endpoint de pago es `/orders/{id}/payments`.
  ///
  /// El backend marca el pago como `approved` en el mismo request y mueve el
  /// pedido a `preparing` por su cuenta, asi que la app no manda el estado:
  /// si lo mandara, el historial quedaria con un cambio que nadie hizo.
  ///
  /// Devuelve el pedido ya pagado, o `null` si algo fallo.
  Future<Pedido?> confirmarPedido({
    required int direccionId,
    required int metodoPagoId,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final creado = await _pedidos.crearPedido(direccionId: direccionId);
      await _pedidos.registrarPago(
        pedidoId: creado.id,
        metodoPagoId: metodoPagoId,
      );

      await cargar();

      // Registrar el pago mueve el pedido a "en preparacion" en el servidor,
      // asi que el objeto que se creo todavia dice "pendiente". Mostrar ese
      // estado daria la sensacion de que el pago no quedo registrado. Se
      // vuelve a pedir el pedido para mostrar el estado real; si esa lectura
      // falla se devuelve el que se tiene, porque perder la confirmacion de un
      // pago que si se registro seria peor que mostrar un estado desactualizado.
      try {
        return await _pedidos.obtenerPedido(creado.id);
      } catch (_) {
        return creado;
      }
    } catch (error) {
      _error = _aTexto(error);
      return null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Avanza un pedido al siguiente estado permitido para quien lo llama.
  ///
  /// No se manda un estado fijo: se pide el que corresponda segun el estado
  /// actual ([PedidoEstados.siguienteDelCocinero]). Asi el boton nunca puede
  /// llevar a un estado que el backend va a rechazar con 422.
  Future<bool> avanzarPedido(int pedidoId, {required bool esCocinero}) async {
    _actualizandoPedidoId = pedidoId;
    _error = null;
    notifyListeners();

    try {
      final pedido = _buscarPorId(pedidoId);
      if (pedido == null) {
        _error = 'El pedido ya no esta en la lista.';
        return false;
      }

      // El repartidor tiene un unico paso (entregar), asi que su "siguiente" es
      // un estado fijo y no una tabla como la del cocinero. Solo se le ofrece
      // el boton cuando el pedido esta en camino, que lo garantiza
      // [listosParaEntregar].
      final siguiente = esCocinero
          ? PedidoEstados.siguienteDelCocinero[pedido.estado]
          : PedidoEstados.siguienteDelRepartidor;

      if (siguiente == null) {
        _error = 'Este pedido ya no tiene un siguiente paso.';
        return false;
      }

      final actualizado = await _pedidos.actualizarEstado(
        pedidoId: pedidoId,
        nuevoEstado: siguiente,
      );

      _reemplazar(actualizado);
      return true;
    } catch (error) {
      _error = _aTexto(error);
      return false;
    } finally {
      _actualizandoPedidoId = null;
      notifyListeners();
    }
  }

  /// Guarda una direccion nueva y la deja seleccionada si es la primera.
  Future<Direccion?> agregarDireccion({
    required String direccionCompleta,
    String etiqueta = 'Casa',
    String ciudad = 'Bogota',
    bool esPredeterminada = false,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final direccion = await _direcciones.crearDireccion(
        direccionCompleta: direccionCompleta,
        etiqueta: etiqueta,
        ciudad: ciudad,
        esPredeterminada: esPredeterminada,
      );
      _direccionesLista = [..._direccionesLista, direccion];
      return direccion;
    } catch (error) {
      _error = _aTexto(error);
      return null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void abrirPedido(int? pedidoId) {
    _pedidoAbierto = pedidoId;
    notifyListeners();
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Pedido? _buscarPorId(int id) {
    for (final pedido in _pedidosLista) {
      if (pedido.id == id) return pedido;
    }
    return null;
  }

  void _reemplazar(Pedido actualizado) {
    _pedidosLista = [
      for (final pedido in _pedidosLista)
        if (pedido.id == actualizado.id) actualizado else pedido,
    ];
  }

  String _aTexto(Object error) {
    if (error is ErrorDeApi) return error.mensaje;
    return 'No se pudo completar la operacion. Intenta de nuevo.';
  }
}
