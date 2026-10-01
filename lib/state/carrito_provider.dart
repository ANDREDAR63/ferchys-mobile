/// Estado del carrito de compra.
///
/// REPLICA EL COMPORTAMIENTO DE LA WEB, QUE TIENE DOS CARRILES:
///
/// - **Invitado**: el backend exige token para el carrito
///   (`Cart::firstOrCreate(['user_id' => $request->user()->id])`), asi que un
///   visitante sin sesion NO PUEDE tener carrito en el servidor. Sus productos
///   se guardan en el dispositivo con la misma clave que usa la web
///   (`ferchys-carrito`) y con el producto completo embebido, para poder
///   mostrar nombre, precio e imagen sin volver a pedir el catalogo.
///
/// - **Con sesion**: el carrito vive en la base de datos. Cada cambio de
///   cantidad se manda al servidor, porque el total se recalcula alla y es el
///   que se cobra.
///
/// Y ENTRE MEDIO ESTA LA FUSION: en cuanto la persona inicia sesion, lo que
/// tenia en el dispositivo se sube al servidor y se borra de disco. Es el
/// momento que hace la web con un `useEffect` que depende de `user`.
///
/// Se cambia de carril con [definirAutenticado], y lo llama un
/// `ChangeNotifierProxyProvider` en `main.dart` cada vez que la sesion cambia.
/// asi el provider no necesita conocer al de autenticacion.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../modelos/carrito_item.dart';
import '../modelos/producto.dart';
import '../servicios/servicio_carrito.dart';

class CarritoProvider extends ChangeNotifier {
  final ServicioCarrito _servicio;
  final SharedPreferences _preferencias;

  List<CarritoItem> _items = [];
  bool _autenticado = false;
  bool _cargando = false;

  /// Si el carrito de invitado ya se leyo de disco.
  ///
  /// Lo protege la lectura inicial: sin esto, cada cambio de autenticacion
  /// volveria a pisar lo que la persona esta modificando en la pantalla con lo
  /// que hay guardado.
  bool _invitadoLeido = false;

  /// Ultimo ingreso cuyos carritos ya se fusionaron.
  ///
  /// Sirve para no repetir la fusion, que es la unica parte de este provider
  /// que no es idempotente. Ver [definirAutenticado].
  int _ingresosFusionados = 0;

  /// Texto para un `SnackBar` tras agregar o quitar. Vive aqui para que los
  /// botones del catalogo no tengan que armar el mensaje cada vez.
  String? _aviso;

  CarritoProvider({
    required ServicioCarrito servicio,
    required SharedPreferences preferencias,
  }) : _servicio = servicio,
       _preferencias = preferencias;

  List<CarritoItem> get items => List.unmodifiable(_items);
  bool get cargando => _cargando;
  String? get aviso => _aviso;
  bool get estaVacio => _items.isEmpty;

  /// Numero de articulos, no de lineas. Un pedido con 3 lineas de 2 unidades
  /// cada una son 6 articulos, y eso es lo que va en el badge del icono.
  int get cantidadArticulos {
    return _items.fold(0, (suma, item) => suma + item.cantidad);
  }

  /// Suma de `cantidad * precio`.
  ///
  /// Es una estimacion para mostrar en la lista. El total que se cobra es el
  /// que calcula el backend al crear el pedido, y puede diferir si el precio
  /// cambio entre agregar y pagar. Por eso al final se muestra el total real.
  double get totalEstimado {
    return _items.fold(0, (suma, item) => suma + item.subtotal);
  }

  /// Cambia de carril entre invitado y usuario, y carga lo que corresponda.
  ///
  /// Fusionar los dos carritos es la unica operacion que no se puede repetir:
  /// si un producto ya subido volviera a subirse, apareceria duplicado y la
  /// persona pagaria dos veces por lo mismo. Por eso no alcanza con preguntar
  /// "¿estaba autenticado antes?", porque en un `update` de `provider` no siempre
  /// se sabe eso, y volveria a entrar en cada cambio de estado.
  ///
  /// En vez de eso se lleva la cuenta con [ingresos], el numero incremental de
  /// ingresos que lleva [AuthProvider]. Fusionar una sola vez por ingreso es lo
  /// unico que hace falta, y da igual que se llame otras veces con el mismo
  /// numero.
  Future<void> definirAutenticado(bool valor, {required int ingresos}) async {
    final recienIngreso = ingresos > _ingresosFusionados;

    // Se anota ANTES de await: si mientras sube el carrito se dispara otro
    // cambio de autenticacion, tiene que ver que ese ingreso ya se esta
    // atendiendo y no arrancar una segunda fusion encima.
    if (ingresos > _ingresosFusionados) _ingresosFusionados = ingresos;

    if (_autenticado == valor && !recienIngreso) {
      // Aun asi, la PRIMERA vez hay que leer el carrito de invitado de disco.
      // Un provider recien creado arranca en `false` igual que un invitado que
      // ya entro, asi que el corte de arriba se llevaria por delante la lectura
      // y el carrito guardado de la sesion anterior nunca apareceria.
      if (!_invitadoLeido) await _cargarInvitado();
      return;
    }

    _autenticado = valor;

    if (valor) {
      await _fusionarInvitadoEnServidor();
    } else {
      await _cargarInvitado();
    }

    notifyListeners();
  }

  /// Agrega un producto, en el carril que corresponda.
  ///
  /// [cantidad] puede ser mayor que 1: en el catalogo se pide directo desde la
  /// tarjeta, sin pasar antes por el carrito.
  Future<void> agregar(Producto producto, {int cantidad = 1}) async {
    if (cantidad <= 0) return;

    _aviso = '${producto.nombre} se agrego al carrito';
    _cargando = true;
    notifyListeners();

    try {
      if (_autenticado) {
        final item = await _servicio.agregarProducto(producto.id, cantidad);
        _reemplazarOInsertar(item);
      } else {
        _items = _fusionarEnInvitado(producto, cantidad);
        await _guardarInvitado();
      }
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Cambia la cantidad de una linea.
  ///
  /// Cantidad cero o negativa elimina la linea, que es lo que hace la web y lo
  /// que espera la persona cuando toca el boton de restar de ultimo.
  Future<void> cambiarCantidad(CarritoItem item, int cantidad) async {
    if (cantidad <= 0) {
      await quitar(item);
      return;
    }

    _cargando = true;
    notifyListeners();

    try {
      if (_autenticado) {
        final idNumerico = int.tryParse(item.id);
        if (idNumerico == null) return;

        final actualizado = await _servicio.actualizarCantidad(
          idNumerico,
          cantidad,
        );
        _reemplazarOInsertar(actualizado);
      } else {
        final producto = item.producto;
        if (producto == null) return;

        _items = _fijarCantidadEnInvitado(producto, cantidad);
        await _guardarInvitado();
      }
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> quitar(CarritoItem item) async {
    _cargando = true;
    notifyListeners();

    try {
      if (_autenticado) {
        final idNumerico = int.tryParse(item.id);
        if (idNumerico != null) {
          await _servicio.eliminarItem(idNumerico);
        }
        _items.removeWhere((otro) => otro.id == item.id);
      } else {
        _items.removeWhere((otro) => otro.productoId == item.productoId);
        await _guardarInvitado();
      }
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Vacia el carrito. Se usa al confirmar un pedido, para que la pantalla de
  /// carrito no siga mostrando lo que ya se cobro.
  Future<void> vaciar() async {
    if (_autenticado) {
      await _servicio.vaciar();
    } else {
      await _preferencias.remove(ClavesAlmacenamiento.carritoInvitado);
    }

    _items = [];
    notifyListeners();
  }

  /// Libera el `SnackBar` una vez que ya se mostro.
  void limpiarAviso() {
    if (_aviso == null) return;
    _aviso = null;
  }

  /// Lee el carrito de invitado del disco.
  Future<void> _cargarInvitado() async {
    _invitadoLeido = true;

    final texto = _preferencias.getString(ClavesAlmacenamiento.carritoInvitado);
    if (texto == null || texto.isEmpty) {
      _items = [];
      return;
    }

    try {
      final lista = jsonDecode(texto) as List<dynamic>;
      _items = lista
          .whereType<Map<String, dynamic>>()
          .map(CarritoItem.desdeJson)
          .toList();
    } catch (_) {
      // Si el JSON guardado se corrompio (app cerrada a la fuerza durante una
      // escritura), se descarta. Un carrito roto no debe impedir abrir la app.
      _items = [];
      await _preferencias.remove(ClavesAlmacenamiento.carritoInvitado);
    }
  }

  /// Sube el carrito de invitado al servidor y lo borra del disco.
  ///
  /// Cada linea se manda por separado porque el backend solo expone
  /// `POST /cart/items` de a uno. Si una linea falla, las demas ya quedaron:
  /// por eso se capturan los errores de a uno y al final se descarta el
  /// carrito local, que ya no sirve para nada.
  Future<void> _fusionarInvitadoEnServidor() async {
    final texto = _preferencias.getString(ClavesAlmacenamiento.carritoInvitado);
    if (texto == null || texto.isEmpty) {
      _items = await _cargarDesdeServidor();
      return;
    }

    List<CarritoItem> locales = [];
    try {
      locales = (jsonDecode(texto) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CarritoItem.desdeJson)
          .toList();
    } catch (_) {
      locales = [];
    }

    for (final item in locales) {
      try {
        await _servicio.agregarProducto(item.productoId, item.cantidad);
      } catch (_) {
        // Un producto pudo quedar desactivado entre la visita y el login.
        // Se sigue con los demas: perder una linea es mejor que perder todas.
      }
    }

    await _preferencias.remove(ClavesAlmacenamiento.carritoInvitado);
    _items = await _cargarDesdeServidor();
  }

  Future<List<CarritoItem>> _cargarDesdeServidor() async {
    try {
      return await _servicio.obtenerCarrito();
    } catch (_) {
      return [];
    }
  }

  /// Suma [cantidad] a la linea de [producto], o la crea si no existe.
  ///
  /// Se busca por `productoId` y no por `id` porque el id de invitado es texto
  /// ("invitado-7") y el del servidor es un numero: el id cambia al cambiar de
  /// carril, el producto no.
  List<CarritoItem> _fusionarEnInvitado(Producto producto, int cantidad) {
    final siguiente = List<CarritoItem>.from(_items);
    final indice = siguiente.indexWhere(
      (item) => item.productoId == producto.id,
    );

    if (indice == -1) {
      siguiente.add(
        CarritoItem(
          id: 'invitado-${producto.id}',
          productoId: producto.id,
          cantidad: cantidad,
          producto: producto,
        ),
      );
      return siguiente;
    }

    final existente = siguiente[indice];
    siguiente[indice] = CarritoItem(
      id: existente.id,
      productoId: existente.productoId,
      cantidad: existente.cantidad + cantidad,
      producto: existente.producto ?? producto,
    );

    return siguiente;
  }

  /// Fija la cantidad de una linea de invitado.
  ///
  /// A diferencia de [_fusionarEnInvitado], que SUMA porque viene de "agregar
  /// otra vez el mismo producto", esto REEMPLAZA. El boton de mas manda la
  /// cantidad final que el usuario quiere (por ejemplo 3 sobre una linea que
  /// tiene 2), asi que sumar daria 5 y cada toque saltaria de a dos.
  List<CarritoItem> _fijarCantidadEnInvitado(Producto producto, int cantidad) {
    final siguiente = List<CarritoItem>.from(_items);
    final indice = siguiente.indexWhere(
      (item) => item.productoId == producto.id,
    );

    if (indice == -1) {
      // La linea no esta mas: se agregó desde otra parte entre medio. Se
      // agrega en vez de devolver la lista vacia, para no perder el producto.
      return _fusionarEnInvitado(producto, cantidad);
    }

    final existente = siguiente[indice];
    siguiente[indice] = CarritoItem(
      id: existente.id,
      productoId: existente.productoId,
      cantidad: cantidad,
      producto: existente.producto ?? producto,
    );

    return siguiente;
  }

  /// Guarda el carrito de invitado.
  ///
  /// Se guarda el producto entero embebido a proposito: si el carrito se abre
  /// sin internet, todavia se pueden ver nombre, precio e imagen. Es el mismo
  /// truco que usa la web con `localStorage`.
  Future<void> _guardarInvitado() async {
    final lista = _items
        .map(
          (item) => {
            'id': item.id,
            'product_id': item.productoId,
            'quantity': item.cantidad,
            'product': item.producto?.aJson(),
          },
        )
        .toList();

    await _preferencias.setString(
      ClavesAlmacenamiento.carritoInvitado,
      jsonEncode(lista),
    );
  }

  /// Reemplaza la linea con el mismo id, o la agrega si no estaba.
  ///
  /// Hace falta porque `POST /cart/items` no crea una linea nueva cuando el
  /// producto ya estaba: el backend hace `increment('quantity')` y devuelve el
  /// item ya sumado. Sin esto, el producto aparecia dos veces.
  void _reemplazarOInsertar(CarritoItem item) {
    final indice = _items.indexWhere((otro) => otro.id == item.id);

    if (indice == -1) {
      _items = [..._items, item];
    } else {
      final siguiente = List<CarritoItem>.from(_items);
      siguiente[indice] = item;
      _items = siguiente;
    }
  }
}
