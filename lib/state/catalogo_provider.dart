/// Estado del catalogo: productos, categorias y promociones.
///
/// Los tres se piden juntos en [cargar] porque la pantalla de catalogo los
/// necesita a la vez: las categorias para los filtros, los productos para la
/// lista y las promociones para las etiquetas de descuento. Pedirlos por
/// separado serian tres viajes de red para pintar una pantalla.
///
/// EL FILTRADO Y LA BUSQUEDA OCURREN EN ESTE ARCHIVO, NO EN EL BACKEND.
/// A proposito: son listas cortas (decenas de productos, no miles) y filtrar
/// en el dispositivo hace que cambiar de categoria o escribir en el buscador
/// sea instantaneo, sin esperas ni parpadeos. Ademas el catalogo casi siempre
/// esta en memoria despues del primer uso, asi que ni siquiera hay red.
///
/// Si el catalogo creciera a miles de productos, esto habria que mover al
/// backend con los parametros `?category_id=` y `?search=`.
library;

import 'package:flutter/foundation.dart';

import '../modelos/categoria.dart';
import '../modelos/producto.dart';
import '../modelos/promocion.dart';
import '../servicios/cliente_api.dart';
import '../servicios/servicio_catalogo.dart';

class CatalogoProvider extends ChangeNotifier {
  final ServicioCatalogo _servicio;

  List<Producto> _todosLosProductos = [];
  List<Categoria> _categorias = [];
  List<Promocion> _promociones = [];

  bool _cargando = false;
  String? _error;

  /// Id de la categoria seleccionada, o `null` para ver todas.
  ///
  /// Se guarda el ID y no el nombre porque los ids no se repiten ni cambian
  /// aunque se corrija la ortografia de una categoria.
  int? _categoriaSeleccionada;

  /// Texto del buscador, sin distinguir mayusculas ni tildes.
  String _busqueda = '';

  /// Id del producto abierto en detalle. `null` significa que no hay ninguno.
  int? _productoAbierto;

  /// Saldo de la promesa de carga en curso.
  ///
  /// Sin esto, si la persona cambia de categoria mientras el catalogo carga,
  /// llegan dos respuestas y la segunda puede ser de una consulta vieja, que
  /// pisaria a la nueva. Al terminar se revisa el numero y solo la ultima
  /// peticion escribe el resultado.
  int _peticionEnCurso = 0;

  CatalogoProvider({required ServicioCatalogo servicio}) : _servicio = servicio;

  List<Categoria> get categorias => List.unmodifiable(_categorias);
  List<Promocion> get promociones => List.unmodifiable(_promociones);
  bool get cargando => _cargando;
  String? get error => _error;
  int? get categoriaSeleccionada => _categoriaSeleccionada;
  String get busqueda => _busqueda;
  int? get productoAbierto => _productoAbierto;

  /// Productos ya filtrados. Es lo unico que la pantalla debe leer.
  List<Producto> get productosVisibles {
    return _todosLosProductos.where(_cumpleFiltros).toList();
  }

  /// Productos sin filtro, para el texto "12 de 34 productos".
  int get totalProductos => _todosLosProductos.length;

  /// Producto abierto en detalle, o `null`.
  ///
  /// Se busca en la lista ya cargada en vez de hacer otra peticion: el JSON de
  /// un producto individual trae lo mismo que el que ya esta en el catalogo.
  Producto? get productoEnDetalle {
    if (_productoAbierto == null) return null;
    return productoPorId(_productoAbierto!);
  }

  /// Busca un producto por id, o `null` si no esta cargado.
  ///
  /// Lo necesita el carrito de invitado para mostrar nombre y precio de sus
  /// lineas sin volver a pedir el catalogo.
  Producto? productoPorId(int id) {
    for (final producto in _todosLosProductos) {
      if (producto.id == id) return producto;
    }
    return null;
  }

  /// Descuento activo de un producto, o `null` si no tiene.
  ///
  /// Se recorre la lista de promociones en vez de armar un mapa por id porque
  /// son pocas y asi no hay que mantener un indice que se desactualiza al
  /// recargar. Solo cuenta la que tiene el producto asignado: una promotion
  /// general no existe en este proyecto.
  Promocion? promocionDe(int productoId) {
    for (final promocion in _promociones) {
      if (promocion.productoId == productoId && promocion.estaVigente) {
        return promocion;
      }
    }
    return null;
  }

  /// Carga catalogo y promociones desde el backend.
  ///
  /// LAS TRES VAN A LA VEZ Y CADA UNA SE CAPTURA POR SEPARADO. Antes eran
  /// `await` seguidos dentro de un unico `try`, y eso hacia dos cosas malas: la
  /// pantalla tardaba lo que suman las tres, y si una sola fallaba se perdian
  /// las otras dos, dejando el catalogo vacio por un problema de promociones.
  ///
  /// Un catalogo sin promociones funciona igual (los precios salen sin
  /// descuento), asi que perderlo todo por un endpoint es un canje mal hecho.
  /// Cada fallo se anota y al final se muestra solo el primero: tres mensajes
  /// apilados no aportan nada y empujan la lista hacia abajo.
  Future<void> cargar() async {
    _peticionEnCurso++;
    final numeroPeticion = _peticionEnCurso;

    _cargando = true;
    _error = null;
    notifyListeners();

    final problemas = <String>[];

    final resultados = await Future.wait([
      _capturar(problemas, _servicio.obtenerProductos, <Producto>[]),
      _capturar(problemas, _servicio.obtenerCategorias, <Categoria>[]),
      _capturar(problemas, _servicio.obtenerPromociones, <Promocion>[]),
    ]);

    // Si mientras tanto se lanzo otra carga, esta respuesta ya esta vieja.
    if (numeroPeticion != _peticionEnCurso) return;

    _todosLosProductos = resultados[0] as List<Producto>;
    _categorias = resultados[1] as List<Categoria>;
    _promociones = resultados[2] as List<Promocion>;
    _error = problemas.isEmpty ? null : problemas.first;

    // El cartel de "cargando" solo lo apaga la ultima peticion.
    if (numeroPeticion == _peticionEnCurso) {
      _cargando = false;
      notifyListeners();
    }
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

  /// Selecciona una categoria, o `null` para ver todas.
  ///
  /// [refrescar] permite recargar del servidor: si la categoria no existe todavia
  /// porque el catalogo fallo la primera vez, la pantalla la vuelve a pedir.
  Future<void> seleccionarCategoria(
    int? categoriaId, {
    bool refrescar = false,
  }) async {
    if (_categoriaSeleccionada == categoriaId && !refrescar) return;

    _categoriaSeleccionada = categoriaId;
    notifyListeners();

    if (refrescar && _todosLosProductos.isEmpty) {
      await cargar();
    }
  }

  void buscar(String texto) {
    if (_busqueda == texto) return;
    _busqueda = texto;
    notifyListeners();
  }

  void abrirProducto(int? productoId) {
    _productoAbierto = productoId;
    notifyListeners();
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Decide si un producto pasa el filtro de categoria y el buscador.
  ///
  /// La busqueda ignora mayusculas y tildes: si la persona escribe "brownie"
  /// tiene que encontrar "Brownie", y si escribe "postre" deberia encontrar
  /// "Postré". Por eso las tildes se quitan antes de comparar en vez de
  /// listar a mano cada acento posible.
  bool _cumpleFiltros(Producto producto) {
    if (_categoriaSeleccionada != null &&
        producto.categoriaId != _categoriaSeleccionada) {
      return false;
    }

    if (_busqueda.trim().isEmpty) return true;

    final textoBusqueda = _sinAcentos(_busqueda);
    final nombre = _sinAcentos(producto.nombre);
    final descripcion = _sinAcentos(producto.descripcion);

    return nombre.contains(textoBusqueda) ||
        descripcion.contains(textoBusqueda);
  }

  /// Quita tildes y pasa a minusculas, para comparar textos.
  ///
  /// Se hace con una tabla de reemplazos en vez de con un paquete de
  /// normalizacion porque son exactamente estas seis vocales acentuadas las
  /// que aparecen en un catalogo de postres.
  String _sinAcentos(String texto) {
    const reemplazos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ñ': 'n',
    };

    var resultado = texto.toLowerCase();
    reemplazos.forEach((conAcento, sinAcento) {
      resultado = resultado.replaceAll(conAcento, sinAcento);
    });

    return resultado;
  }

  /// Los errores del cliente HTTP ya traen un mensaje para leerse; cualquier
  /// otra cosa se muestra generica.
  /// Traduce un error al texto que se ve en pantalla.
  ///
  /// `ErrorDeApi` ya viene con un mensaje pensado para leerse (por ejemplo, si
  /// el servidor no esta en esa direccion).
  ///
  /// CUALQUIER OTRA EXCEPCION SE MUESTRA TAL CUAL, y antes no lo hacia. Todo lo
  /// que no fuera `ErrorDeApi` se traducía a un unico texto fijo sobre la
  /// direccion del backend, y el resultado es que un error de parseo (por
  /// ejemplo un `int` donde se esperaba un `bool`) se anunciaba como "no pudimos
  /// conectarnos". Eso no era un problema de red y por eso se perdia tiempo
  /// buscando en el lado equivocado.
  String _aTexto(Object error) {
    if (error is ErrorDeApi) return error.mensaje;
    return 'No se pudo cargar el catalogo: $error';
  }
}
