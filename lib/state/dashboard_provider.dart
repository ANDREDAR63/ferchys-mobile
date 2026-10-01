/// Estado de los dashboards de admin, cocina y repartidor.
///
/// Los cuatro reportes de `ReportController` NO se piden de entrada: primero se
/// cargan los indicadores rapidos y despues los reportes. Asi la pantalla
/// muestra algo util en cuanto llega la primera respuesta, en vez de quedar en
/// blanco hasta que terminen las cuatro.
///
/// ALCANCE DEL DASHBOARD DE ADMIN: SOLO LECTURA. La version web permite crear
/// y editar usuarios, productos, ingredientes y promociones; en el movil se
/// decided no replicar eso, porque son formularios largos que en una pantalla
/// de telefono se vuelven lentos y propensos a errores. El movil de admin
/// resume y consulta; el alta y la edicion quedan en la web.
///
/// LOS KPIs NO TIENEN ENDPOINT PROPIO. El backend no expone un
/// "dashboard-stats", asi que se replico lo que hace la web: contar elementos
/// de cada lista. Son seis peticiones, pero se lanzan a la vez con
/// `Future.wait` y solo se necesita la longitud de cada una.
library;

import 'package:flutter/foundation.dart';

import '../modelos/ingrediente.dart';
import '../servicios/cliente_api.dart';
import '../servicios/servicio_catalogo.dart';
import '../servicios/servicio_dashboard.dart';
import '../servicios/servicio_pedidos.dart';

/// Los seis numeros de la fila de indicadores del administrador.
class IndicadoresAdmin {
  final int pedidos;
  final int productos;
  final int usuarios;
  final int ingredientes;
  final int promociones;
  final int pagos;

  const IndicadoresAdmin({
    required this.pedidos,
    required this.productos,
    required this.usuarios,
    required this.ingredientes,
    required this.promociones,
    required this.pagos,
  });

  /// Todos en cero, para el estado inicial antes de que llegue la respuesta.
  ///
  /// Se diferencia de un valor "vacio": mostrar 0 mientras carga seria mentir, por eso
  /// la pantalla consulta [DashboardProvider.cargandoIndicadores] aparte y
  /// muestra un esqueleto en vez de ceros.
  const IndicadoresAdmin.vacios()
    : pedidos = 0,
      productos = 0,
      usuarios = 0,
      ingredientes = 0,
      promociones = 0,
      pagos = 0;
}

class DashboardProvider extends ChangeNotifier {
  final ServicioDashboard _dashboard;
  final ServicioPedidos _pedidos;
  final ServicioCatalogo _catalogo;
  final ClienteApi _api;

  IndicadoresAdmin _indicadores = const IndicadoresAdmin.vacios();

  /// Ingredientes con el CRUD completo, para el listado de la cocina.
  List<Ingrediente> _ingredientes = [];

  ReporteVentasPorPeriodo? _reportePeriodo;
  ReporteVentasPorProducto? _reporteProductos;
  List<PedidosPorEstado> _pedidosPorEstado = [];
  List<InsumoConAlerta> _insumosConAlerta = [];

  bool _cargandoIndicadores = false;
  bool _cargandoReportes = false;

  /// True solo cuando `low-stock` respondio bien en la ultima carga.
  ///
  /// Se necesita para no confundir "no hay insumos en alerta" con "no se pudo
  /// consultar las alertas". Sin esta bandera, un fallo del endpoint dejaria la
  /// tarjeta afirmando que todo esta por encima del minimo.
  bool _alertasCargadas = false;

  /// Un solo mensaje de error para toda la pantalla. Se muestra arriba, no
  /// junto a cada tarjeta: cuatro errores repetidos se ven peor que uno.
  String? _error;

  /// Rango de fechas del reporte de ventas, y como se agrupa.
  ///
  /// Por defecto son los ultimos 30 dias por dia, que es lo que un administrador
  /// mira al abrir la app. El dia se elige como agrupado porque una semana se
  /// ve como un solo punto y no dice nada.
  DateTime _desde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _hasta = DateTime.now();
  String _agrupadoPor = 'day';

  DashboardProvider({
    required ServicioDashboard dashboard,
    required ServicioPedidos pedidos,
    required ServicioCatalogo catalogo,
    required ClienteApi api,
  }) : _dashboard = dashboard,
       _pedidos = pedidos,
       _catalogo = catalogo,
       _api = api;

  IndicadoresAdmin get indicadores => _indicadores;
  List<Ingrediente> get ingredientes => List.unmodifiable(_ingredientes);
  ReporteVentasPorPeriodo? get reportePeriodo => _reportePeriodo;
  ReporteVentasPorProducto? get reporteProductos => _reporteProductos;
  List<PedidosPorEstado> get pedidosPorEstado =>
      List.unmodifiable(_pedidosPorEstado);
  List<InsumoConAlerta> get insumosConAlerta =>
      List.unmodifiable(_insumosConAlerta);
  bool get cargandoIndicadores => _cargandoIndicadores;
  bool get cargandoReportes => _cargandoReportes;
  bool get alertasCargadas => _alertasCargadas;
  String? get error => _error;
  DateTime get desde => _desde;
  DateTime get hasta => _hasta;
  String get agrupadoPor => _agrupadoPor;

  /// Ingredientes que estan por agotarse, del mas urgente al menos.
  ///
  /// El backend ya los ordena por gravedad (`critico`, `bajo`, `ok`) y dentro de
  /// cada grupo por porcentaje disponible. Solo se quitan los que estan sanos,
  /// porque una lista de veinte insumos en verde no es una alerta.
  List<InsumoConAlerta> get alertasDeStock {
    return _insumosConAlerta.where((insumo) => !insumo.estaSano).toList();
  }

  /// Carga los seis indicadores del administrador.
  ///
  /// Las seis peticiones salen A LA VEZ con `Future.wait` y no una tras otra:
  /// son independientes, y encadenarlas hacia la pantalla sumaria los tiempos
  /// de espera de todas. Lo que tarda mas es lo que se demora en pintar.
  ///
  /// Cada una va envuelta en su propio `try` para que una sola falle (por
  /// ejemplo, si el admin todavia no ha creado promociones) no tire abajo las
  /// otras cinco cifras. Un conteo que no se pudo obtener se muestra como cero,
  /// que es preferible a no mostrar el panel.
  Future<void> cargarIndicadores() async {
    _cargandoIndicadores = true;
    _error = null;
    notifyListeners();

    // Los siete conteos salen a la vez con `Future.wait` y no uno tras otro: son
    // independientes, y encadenarlos hacia la pantalla sumaria los tiempos de
    // espera de todos. Lo que tarda mas es lo que se demora en pintar.
    //
    // El conteo de ingredientes entra en la misma tanda, y no se lee de
    // [_ingredientes] porque esa lista la carga `cargarReportes`, que corre por
    // separado: leerla antes de que llegue daria cero, y un panel con cinco
    // numeros bien y un cero al lado parece un error de datos.
    final conteos = await Future.wait<int>([
      _contarPedidos(),
      _contarProductos(),
      _contarCategorias(),
      _contarLista('/users'),
      _contarLista('/admin/promotions'),
      _contarLista('/payments'),
      _cargarIngredientes(),
    ]);

    _indicadores = IndicadoresAdmin(
      pedidos: conteos[0],
      productos: conteos[1],
      usuarios: conteos[3],
      ingredientes: conteos[6],
      promociones: conteos[4],
      pagos: conteos[5],
    );

    // Catalogo vacio casi siempre significa que la URL apunta a otro servidor,
    // no que de verdad no haya productos. Se avisa porque es la causa mas comun
    // de un panel en cero.
    if (conteos[1] == 0 && conteos[2] == 0) {
      _error = 'No se encontraron productos ni categorias. Revisa la URL del backend.';
    }

    _cargandoIndicadores = false;
    notifyListeners();
  }

  Future<int> _contarPedidos() async {
    return _contar(() async => (await _pedidos.obtenerPedidos()).length);
  }

  /// Productos que ve el administrador, incluidos los inactivos.
  ///
  /// Se piden por `/products` y no por `/admin/products` porque los dos caminos
  /// ejecutan el mismo `ProductController@index`, que filtra por `active`
  /// SOLO si quien pregunta no es admin. Con el token de admin, la respuesta
  /// es identica; usar la ruta de admin no cambiaria el numero y si obligaria
  /// a duplicar el metodo del servicio.
  Future<int> _contarProductos() async {
    return _contar(() async => (await _catalogo.obtenerProductos()).length);
  }

  Future<int> _contarCategorias() async {
    return _contar(() async => (await _catalogo.obtenerCategorias()).length);
  }

  /// Descarga la lista de ingredientes y devuelve cuantos hay.
  ///
  /// Devolver el conteo permite meterla en el mismo `Future.wait` que los otros
  /// indicadores. Si falla se devuelve lo que ya se tenia, para no dejar el
  /// numero en cero por un fallo puntual de la red.
  ///
  /// Las alertas de stock van aparte, en [_cargarAlertasStock]: necesitan poder
  /// informar su propio fallo, y aqui los errores se silencian a proposito.
  Future<int> _cargarIngredientes({bool soloSiFalta = false}) async {
    if (soloSiFalta && _ingredientes.isNotEmpty) return _ingredientes.length;

    try {
      _ingredientes = await _dashboard.obtenerIngredientes();
    } catch (_) {
      // Se deja la lista anterior: si venia de una carga buena, es mejor
      // mostrar datos viejos que mostrar un panel vacio.
    }

    return _ingredientes.length;
  }

  /// Descarga las alertas de stock (`low-stock`).
  ///
  /// Se mantiene separada de [_cargarIngredientes] para poder distinguir "no hay
  /// insumos en alerta" de "no se pudieron consultar las alertas". Sin esta
  /// distincion, un 404 en el endpoint dejaria la tarjeta afirmando que todos
  /// los insumos estan por encima del minimo, que seria una afirmacion falsa.
  Future<void> _cargarAlertasStock() async {
    _insumosConAlerta = await _dashboard.insumosConAlerta();
    _alertasCargadas = true;
  }

  /// Cuenta los elementos de una lista del backend.
  ///
  /// `/users` y `/admin/promotions` son rutas de administrador, asi que se piden
  /// con el cliente generico para no anadir metodos a los servicios que solo
  /// usaria esta pantalla.
  Future<int> _contarLista(String ruta) async {
    return _contar(() async {
      final datos = await _consultarAdmin(ruta);
      return datos is List ? datos.length : 0;
    });
  }

  /// Carga los reportes y las alertas de stock.
  ///
  /// Van en paralelo porque ninguno depende del otro. Cada uno va envuelto en su
  /// propio `try` y se acumulan los errores: si el reporte de productos falla,
  /// el de ventas por periodo igual sirve y la pantalla no queda en blanco.
  /// Mostrar el primero de los fallos es suficiente; cuatro mensajes iguales
  /// apilados no aportan nada y empujan el contenido hacia abajo.
  Future<void> cargarReportes() async {
    _cargandoReportes = true;
    _error = null;
    notifyListeners();

    final problemas = <String>[];

    // Se marca como no consultadas hasta que la peticion termine bien: asi la
    // tarjeta de stock no afirma nada mientras el resultado esta en el aire.
    _alertasCargadas = false;

    await Future.wait<void>([
      _capturar(problemas, () async {
        _reportePeriodo = await _dashboard.ventasPorPeriodo(
          desde: _desde,
          hasta: _hasta,
          agruparPor: _agrupadoPor,
        );
      }),
      _capturar(problemas, () async {
        _reporteProductos = await _dashboard.ventasPorProducto(
          desde: _desde,
          hasta: _hasta,
        );
      }),
      _capturar(problemas, () async {
        _pedidosPorEstado = await _dashboard.pedidosPorEstado(
          desde: _desde,
          hasta: _hasta,
        );
      }),
      // Las alertas de stock van aparte de los ingredientes: si fallan, la
      // pantalla lo dice en vez de mostrar un "todo bien" falso.
      _capturar(problemas, _cargarAlertasStock),
    ]);

    if (problemas.isNotEmpty) _error = problemas.first;

    // El numero de ingredientes pudo cambiar desde la ultima vez que se
    // cargaron los indicadores, asi que se vuelve a copiar ahi.
    _indicadores = IndicadoresAdmin(
      pedidos: _indicadores.pedidos,
      productos: _indicadores.productos,
      usuarios: _indicadores.usuarios,
      ingredientes: _ingredientes.length,
      promociones: _indicadores.promociones,
      pagos: _indicadores.pagos,
    );

    _cargandoReportes = false;
    notifyListeners();
  }

  /// Ejecuta [accion] anotando el error en [problemas] en vez de propagarlo.
  ///
  /// Es lo que permite que las cuatro peticiones corran a la vez sin que una
  /// sola falla se lleve por delante las otras tres.
  Future<void> _capturar(
    List<String> problemas,
    Future<void> Function() accion,
  ) async {
    try {
      await accion();
    } catch (error) {
      problemas.add(_aTexto(error));
    }
  }

  /// Cambia el rango de fechas y recarga el reporte de ventas.
  ///
  /// [agrupadoPor] solo acepta los tres valores que valida el backend
  /// (`day`, `week`, `month`); mandar otro devuelve 422.
  Future<void> cambiarRango({
    DateTime? desde,
    DateTime? hasta,
    String? agrupadoPor,
  }) async {
    if (desde != null) _desde = desde;
    if (hasta != null) _hasta = hasta;
    if (agrupadoPor != null) _agrupadoPor = agrupadoPor;

    _cargandoReportes = true;
    notifyListeners();

    try {
      _reportePeriodo = await _dashboard.ventasPorPeriodo(
        desde: _desde,
        hasta: _hasta,
        agruparPor: _agrupadoPor,
      );
    } catch (error) {
      _error = _aTexto(error);
    } finally {
      _cargandoReportes = false;
      notifyListeners();
    }
  }

  /// Rangos rapidos que se ofrecen como botones.
  ///
  /// Son los que se piden en una reunion: "hoy", "esta semana" y "este mes".
  /// El dia se compara contra la medianoche de hoy, no contra las 23:59, porque
  /// al final del dia el total seria casi cero y la variacion saldria enorme.
  Future<void> aplicarRangoRapido(String clave) async {
    final hoy = DateTime.now();
    final inicioDeHoy = DateTime(hoy.year, hoy.month, hoy.day);

    switch (clave) {
      case 'hoy':
        await cambiarRango(desde: inicioDeHoy, hasta: inicioDeHoy);
      case 'semana':
        await cambiarRango(
          desde: inicioDeHoy.subtract(const Duration(days: 6)),
          hasta: inicioDeHoy,
        );
      case 'mes':
        await cambiarRango(
          desde: DateTime(hoy.year, hoy.month, 1),
          hasta: inicioDeHoy,
        );
    }
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Ejecuta [accion] y devuelve el conteo, o cero si falla.
  Future<int> _contar(Future<int> Function() accion) async {
    try {
      return await accion();
    } catch (_) {
      return 0;
    }
  }

  /// Peticion cruda al backend para rutas de administrador.
  ///
  /// Vive aqui para no ensuciar [ServicioDashboard] con endpoints que usa una
  /// sola pantalla. Reutiliza el mismo `ClienteApi`, asi que comparte token y
  /// URL: si se creara un cliente aparte, habria que volver a pegarle el token
  /// y se podrian desincronizar.
  Future<dynamic> _consultarAdmin(String ruta) {
    return _api.get(ruta);
  }

  String _aTexto(Object error) {
    if (error is ErrorDeApi) return error.mensaje;
    // Se incluye el error crudo: un fallo que no viene de la API (por ejemplo al
    // parsear una respuesta) antes quedaba oculto tras un mensaje generico, y no
    // habia forma de saber que habia pasado.
    return 'No se pudieron cargar los datos del dashboard: $error';
  }
}
