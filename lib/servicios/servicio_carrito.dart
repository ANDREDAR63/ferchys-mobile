/// Servicio del carrito de un usuario autenticado.
///
/// Estos endpoints solo existen para usuarios con token: el carrito de
/// invitado vive por completo en el dispositivo (ver `estado_carrito.dart`) y
/// nunca toca la red.
///
/// Nota sobre el backend: el carrito se crea solito la primera vez que se
/// consulta (Cart::firstOrCreate), asi que no hay un endpoint de "crear".
library;

import '../modelos/carrito_item.dart';
import 'cliente_api.dart';

class ServicioCarrito {
  final ClienteApi _api;

  ServicioCarrito(this._api);

  /// GET /cart
  ///
  /// Devuelve el carrito con `items.product` ya cargado. Si el usuario nunca
  /// agrego nada, el backend responde un carrito con la lista vacia.
  Future<List<CarritoItem>> obtenerCarrito() async {
    final datos = await _api.get('/cart') as Map<String, dynamic>;
    return _itemsDe(datos);
  }

  /// POST /cart/items
  ///
  /// El backend NO reemplaza la cantidad: la incrementa. Por eso la app
  /// calcula el total antes de llamar (suma lo que ya hay mas lo nuevo).
  Future<CarritoItem> agregarProducto(int productoId, int cantidad) async {
    final datos = await _api.post(
      '/cart/items',
      cuerpo: {'product_id': productoId, 'quantity': cantidad},
    );
    return CarritoItem.desdeJson(datos as Map<String, dynamic>);
  }

  /// PUT /cart/items/{id}
  ///
  /// A diferencia de agregar, este si reemplaza la cantidad (no la suma).
  Future<CarritoItem> actualizarCantidad(int itemId, int cantidad) async {
    final datos = await _api.put(
      '/cart/items/$itemId',
      cuerpo: {'quantity': cantidad},
    );
    return CarritoItem.desdeJson(datos as Map<String, dynamic>);
  }

  /// DELETE /cart/items/{id}
  ///
  /// El backend responde 204 sin cuerpo, asi que no hay nada que parsear.
  Future<void> eliminarItem(int itemId) async {
    await _api.delete('/cart/items/$itemId');
  }

  /// Vacia el carrito.
  ///
  /// No hay un endpoint "vaciar todo", asi que se borran los items uno por uno.
  /// Se hacen en paralelo con `Future.wait` para que sea una sola ida y vuelta
  /// en vez de N secuenciales. Si un pedido ya se creo, el backend vacio el
  /// carrito solo, y esta funcion no tendra nada que borrar.
  Future<void> vaciar() async {
    final items = await obtenerCarrito();
    if (items.isEmpty) return;

    await Future.wait(
      items.map((item) {
        final idNumerico = int.tryParse(item.id);
        if (idNumerico == null) return Future.value();
        return eliminarItem(idNumerico);
      }),
    );
  }

  /// Lee la lista de items de la respuesta del carrito.
  List<CarritoItem> _itemsDe(Map<String, dynamic> datos) {
    return (datos['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CarritoItem.desdeJson)
        .toList();
  }
}
