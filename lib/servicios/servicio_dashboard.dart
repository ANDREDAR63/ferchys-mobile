/// Lecture of the endpoints that only admins and cooks can see.
///
/// Covers the `ingredients` list and the four reports of
/// `ReportController` (`sales-by-period`, `sales-by-product`,
/// `orders-by-status` and `low-stock`).
///
/// ABOUT THE SHAPES OF THE RESPONSES, THEY ARE NOT UNIFORM:
///
/// - `sales-by-period` is the only one wrapped: `{data: [...], comparacion: {...}}`
/// - `sales-by-product` returns TWO rankings with different names
///   (`mas_vendidos` and `menos_vendidos`)
/// - `orders-by-status` and `low-stock` return a plain array
///
/// This asymmetry is why the parsing lives in the `desdeJson` of each class
/// instead of a single generic helper: each endpoint is read in one place.
///
/// ALL THE MODELS HERE USE `aDoble`/`aEntero` FROM utils/valores.dart and NOT
/// `as double`, because the reports aggregate columns of type `decimal` and
/// `SUM(total)` comes from MySQL as a STRING ("12345.00"). With a plain cast
/// the dashboard would fail to load exactly on the screen that matters most.
library;

import '../modelos/ingrediente.dart';
import '../modelos/pedido.dart';
import '../utils/valores.dart';
import 'cliente_api.dart';

/// One row of `sales-by-period`: the sales of a single day, week or month.
///
/// [periodo] is the label already formatted by MySQL `DATE_FORMAT`: a full
/// date for `day` ("2026-09-30"), an ISO week for `week` ("2026-W40") or a
/// month for `month` ("2026-09"). It is kept as a string because each
/// granularity has its own shape and reformatting here would be guesswork.
class VentaPorPeriodo {
  final String periodo;
  final double totalVentas;
  final int cantidadPedidos;
  final double ticketPromedio;

  const VentaPorPeriodo({
    required this.periodo,
    required this.totalVentas,
    required this.cantidadPedidos,
    required this.ticketPromedio,
  });

  factory VentaPorPeriodo.desdeJson(Map<String, dynamic> json) {
    return VentaPorPeriodo(
      periodo: json['periodo'] as String? ?? '',
      totalVentas: aDoble(json['total_ventas']),
      cantidadPedidos: aEntero(json['cantidad_pedidos']),
      ticketPromedio: aDoble(json['ticket_promedio']),
    );
  }
}

/// Full response of `sales-by-period`: the series plus the comparison against
/// the immediately preceding period of the same length.
///
/// The backend sends the previous period's totals already calculated, so the
/// client must NOT recompute the variation; it only displays it.
class ReporteVentasPorPeriodo {
  final List<VentaPorPeriodo> ventas;
  final double totalActual;
  final double totalAnterior;

  /// Percentage change, or `null` when there is no previous period to compare
  /// against (the previous period sold zero). `null` is shown as a dash because
  /// "0%" would be a lie: there is no comparison to make.
  final double? variacionPorcentual;

  const ReporteVentasPorPeriodo({
    required this.ventas,
    required this.totalActual,
    required this.totalAnterior,
    required this.variacionPorcentual,
  });

  factory ReporteVentasPorPeriodo.desdeJson(Map<String, dynamic> json) {
    final filas = (json['data'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VentaPorPeriodo.desdeJson)
        .toList();

    final comparacion =
        json['comparacion'] as Map<String, dynamic>? ?? const {};

    return ReporteVentasPorPeriodo(
      ventas: filas,
      totalActual: aDoble(comparacion['total_ventas_actual']),
      totalAnterior: aDoble(comparacion['total_ventas_anterior']),
      // `null` arrives as JSON null, and `aDoble` with `porDefecto: null` keeps
      // it null. The `as double?` cast would work here but would break if the
      // value ever came as a string.
      variacionPorcentual: comparacion['variacion_porcentual'] == null
          ? null
          : aDoble(comparacion['variacion_porcentual']),
    );
  }

  /// True when there is nothing to graph, so the screen shows a placeholder
  /// instead of an empty chart that looks broken.
  bool get estaVacio => ventas.isEmpty;
}

/// One row of `sales-by-product`, used in both rankings.
class VentaPorProducto {
  final int productoId;
  final String nombre;
  final int unidadesVendidas;
  final double ingresosGenerados;
  final int numeroPedidos;

  const VentaPorProducto({
    required this.productoId,
    required this.nombre,
    required this.unidadesVendidas,
    required this.ingresosGenerados,
    required this.numeroPedidos,
  });

  factory VentaPorProducto.desdeJson(Map<String, dynamic> json) {
    return VentaPorProducto(
      productoId: aEntero(json['producto_id']),
      nombre: json['nombre'] as String? ?? 'Sin nombre',
      unidadesVendidas: aEntero(json['unidades_vendidas']),
      ingresosGenerados: aDoble(json['ingresos_generados']),
      numeroPedidos: aEntero(json['numero_pedidos']),
    );
  }
}

/// The two rankings of `sales-by-product` in a single call.
///
/// Having both at once saves a round trip, and it makes the contrast
/// "best seller vs. least sold" visible in the same screen.
class ReporteVentasPorProducto {
  final List<VentaPorProducto> masVendidos;
  final List<VentaPorProducto> menosVendidos;

  const ReporteVentasPorProducto({
    required this.masVendidos,
    required this.menosVendidos,
  });

  factory ReporteVentasPorProducto.desdeJson(Map<String, dynamic> json) {
    List<VentaPorProducto> leer(String clave) {
      return (json[clave] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(VentaPorProducto.desdeJson)
          .toList();
    }

    return ReporteVentasPorProducto(
      masVendidos: leer('mas_vendidos'),
      menosVendidos: leer('menos_vendidos'),
    );
  }
}

/// One row of `orders-by-status`: how many orders sit in a given state.
class PedidosPorEstado {
  final String estado;
  final int cantidadPedidos;
  final double montoTotal;

  /// Share of the total orders, already computed by the backend.
  final double porcentajeDelTotal;

  const PedidosPorEstado({
    required this.estado,
    required this.cantidadPedidos,
    required this.montoTotal,
    required this.porcentajeDelTotal,
  });

  factory PedidosPorEstado.desdeJson(Map<String, dynamic> json) {
    return PedidosPorEstado(
      estado: json['estado'] as String? ?? PedidoEstados.pendiente,
      cantidadPedidos: aEntero(json['cantidad_pedidos']),
      montoTotal: aDoble(json['monto_total']),
      porcentajeDelTotal: aDoble(json['porcentaje_del_total']),
    );
  }

  /// Label in Spanish for the chips and the legend.
  String get etiqueta {
    return PedidoEstados.etiquetaDe(estado);
  }
}

/// One row of `low-stock`.
///
/// The `state` field is computed on the server using the `umbral_critico`
/// parameter, so the app does not repeat that rule and can never disagree with
/// the backend about what counts as critical.
class InsumoConAlerta {
  final int ingredienteId;
  final String nombre;
  final double stockActual;
  final double stockMinimo;
  final double porcentajeDisponible;

  /// `critico`, `bajo` or `ok`.
  final String estado;

  /// Names of the products that use this ingredient, so the cook knows what
  /// will run out of stock on the menu.
  final List<String> productosAfectados;

  const InsumoConAlerta({
    required this.ingredienteId,
    required this.nombre,
    required this.stockActual,
    required this.stockMinimo,
    required this.porcentajeDisponible,
    required this.estado,
    required this.productosAfectados,
  });

  factory InsumoConAlerta.desdeJson(Map<String, dynamic> json) {
    return InsumoConAlerta(
      ingredienteId: aEntero(json['ingrediente_id']),
      nombre: json['nombre'] as String? ?? 'Sin nombre',
      stockActual: aDoble(json['stock_actual']),
      stockMinimo: aDoble(json['stock_minimo']),
      porcentajeDisponible: aDoble(json['porcentaje_disponible']),
      estado: json['estado'] as String? ?? 'ok',
      productosAfectados: (json['productos_afectados'] as List<dynamic>? ?? [])
          .map((valor) => valor.toString())
          .toList(),
    );
  }

  bool get esCritico => estado == 'critico';
  bool get esBajo => estado == 'bajo';

  /// True when the ingredient is not yet a problem, used to decide if the
  /// card shows a green bar instead of a warning.
  bool get estaSano => estado == 'ok';

  /// "40% del minimo", the number the cook actually compares against.
  String get resumen =>
      '${porcentajeDisponible.toStringAsFixed(0)}% del minimo';
}

/// Names of the order states live in `PedidoEstados` (modelos/pedido.dart),
/// which the web dashboards also need, so they are not duplicated here.
class ServicioDashboard {
  final ClienteApi _api;

  ServicioDashboard(this._api);

  /// GET /ingredients
  ///
  /// Restricted to admin and cook by the backend's `role` middleware.
  Future<List<Ingrediente>> obtenerIngredientes() async {
    final datos = await _api.get('/ingredients');
    if (datos is! List) return [];
    return datos
        .whereType<Map<String, dynamic>>()
        .map(Ingrediente.desdeJson)
        .toList();
  }

  /// GET /reports/sales-by-period
  ///
  /// [agruparPor] is `'day'`, `'week'` or `'month'`. The backend validates it
  /// with `in:day,week,month` and answers 422 for anything else, so the UI
  /// should only offer those three options.
  Future<ReporteVentasPorPeriodo> ventasPorPeriodo({
    required DateTime desde,
    required DateTime hasta,
    required String agruparPor,
  }) async {
    final datos = await _api.get(
      '/reports/sales-by-period',
      query: {
        'from': _soloFecha(desde),
        'to': _soloFecha(hasta),
        'group_by': agruparPor,
      },
    );
    return ReporteVentasPorPeriodo.desdeJson(datos as Map<String, dynamic>);
  }

  /// GET /reports/sales-by-product
  ///
  /// [desde] and [hasta] are optional: if omitted, the backend uses the whole
  /// history. `limit` caps each of the two rankings.
  Future<ReporteVentasPorProducto> ventasPorProducto({
    DateTime? desde,
    DateTime? hasta,
    int limite = 5,
  }) async {
    final query = <String, String>{'limit': '$limite'};
    if (desde != null) query['from'] = _soloFecha(desde);
    if (hasta != null) query['to'] = _soloFecha(hasta);

    final datos = await _api.get('/reports/sales-by-product', query: query);
    return ReporteVentasPorProducto.desdeJson(datos as Map<String, dynamic>);
  }

  /// GET /reports/orders-by-status
  Future<List<PedidosPorEstado>> pedidosPorEstado({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final query = <String, String>{};
    if (desde != null) query['from'] = _soloFecha(desde);
    if (hasta != null) query['to'] = _soloFecha(hasta);

    final datos = await _api.get('/reports/orders-by-status', query: query);
    if (datos is! List) return [];
    return datos
        .whereType<Map<String, dynamic>>()
        .map(PedidosPorEstado.desdeJson)
        .toList();
  }

  /// GET /reports/low-stock
  ///
  /// [umbralCritico] is a percentage: an ingredient is `critico` when it is
  /// below that percentage of its minimum stock (20% by default on the server).
  ///
  /// This is the only report the cook can also see, so both dashboards use it.
  Future<List<InsumoConAlerta>> insumosConAlerta({
    double umbralCritico = 20,
  }) async {
    final datos = await _api.get(
      '/reports/low-stock',
      query: {'umbral_critico': '$umbralCritico'},
    );
    if (datos is! List) return [];
    return datos
        .whereType<Map<String, dynamic>>()
        .map(InsumoConAlerta.desdeJson)
        .toList();
  }

  /// Date in `YYYY-MM-DD`, the format required by the backend's
  /// `date_format:Y-m-d` validation rule.
  ///
  /// Written by hand instead of using `DateFormat` so the query parameters
  /// stay explicit and the services do not depend on `intl`.
  String _soloFecha(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }
}
