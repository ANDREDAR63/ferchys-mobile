/// Servicio del catalogo: productos, categorias y promociones.
///
/// Los tres endpoints son publicos (no piden token), asi que el catalogo
/// funciona sin iniciar sesion. Ademas el backend filtra lo que no debe
/// verse segun el rol: un admin ve productos inactivos y promociones
/// vencidas, cualquiera mas solo lo vigente.
library;

import '../modelos/categoria.dart';
import '../modelos/producto.dart';
import '../modelos/promocion.dart';
import 'cliente_api.dart';

class ServicioCatalogo {
  final ClienteApi _api;

  ServicioCatalogo(this._api);

  /// GET /products
  ///
  /// Acepta `category_id` como query opcional, que es lo unico que el
  /// backend soporta para filtrar. La app no lo usa: trae todo y filtra en
  /// memoria, que para un catalogo pequeno es mas rapido y evita un request
  /// por cada cambio de filtro.
  Future<List<Producto>> obtenerProductos({int? categoriaId}) async {
    final datos = await _api.get(
      '/products',
      query: categoriaId == null ? null : {'category_id': '$categoriaId'},
    );

    return _convertirLista<Producto>(datos, Producto.desdeJson);
  }

  /// GET /products/{id}
  ///
  /// Trae el producto con sus ingredientes y promociones ya expandidos, que
  /// GET /products no incluye. Por eso la pantalla de detalle necesita su
  /// propio endpoint en vez de buscarlo en la lista.
  Future<Producto> obtenerProducto(int id) async {
    final datos = await _api.get('/products/$id');
    return Producto.desdeJson(datos as Map<String, dynamic>);
  }

  /// GET /categories
  Future<List<Categoria>> obtenerCategorias() async {
    final datos = await _api.get('/categories');
    return _convertirLista<Categoria>(datos, Categoria.desdeJson);
  }

  /// GET /promotions
  ///
  /// El backend ya descarta las vencidas para los no-admin, asi que aqui no
  /// hace falta volver a filtrar por fecha.
  Future<List<Promocion>> obtenerPromociones() async {
    final datos = await _api.get('/promotions');
    return _convertirLista<Promocion>(datos, Promocion.desdeJson);
  }

  /// Convierte la respuesta JSON en una lista de modelos.
  ///
  /// Se-factoriza porque los cuatro endpoints devuelven el mismo patron
  /// (un array de objetos) y repetir el bucle cuatro veces seria ruido.
  /// `whereType` descarta cualquier elemento que no sea un Map en vez de
  /// tronar con un error de cast.
  List<T> _convertirLista<T>(
    dynamic datos,
    T Function(Map<String, dynamic>) construir,
  ) {
    if (datos is! List) return [];
    return datos.whereType<Map<String, dynamic>>().map(construir).toList();
  }
}
