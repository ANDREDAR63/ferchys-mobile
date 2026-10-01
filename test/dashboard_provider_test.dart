/// Pruebas de la carga de reportes del panel de administrador.
///
/// LO QUE SE FIJA ACA ES QUE UN REPORTE CAIDO NO MIENTA. Antes, si el endpoint
/// `low-stock` fallaba, la lista de alertas quedaba vacia y la pantalla afirmaba
/// "todos los insumos estan por encima del minimo", que es justo lo contrario de
/// lo que se sabe. Ahora el provider distingue "no hay alertas" de "no se pudo
/// consultar", y la pantalla puede decir que no se sabe.
///
/// El `ServicioDashboard` se falsea: estas pruebas corren sin backend y lo que
/// interesa es la logica del provider, no el HTTP.
library;

import 'package:ferchys_mobile/modelos/ingrediente.dart';
import 'package:ferchys_mobile/servicios/cliente_api.dart';
import 'package:ferchys_mobile/servicios/servicio_catalogo.dart';
import 'package:ferchys_mobile/servicios/servicio_dashboard.dart';
import 'package:ferchys_mobile/servicios/servicio_pedidos.dart';
import 'package:ferchys_mobile/state/dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un 404 en los reportes deja el stock como no consultado', () async {
    final provider = _crear(falla: true);

    await provider.cargarReportes();

    expect(provider.alertasCargadas, isFalse);
    expect(provider.alertasDeStock, isEmpty);
    expect(provider.error, contains('endpoint no encontrado'));
  });

  test('cuando el stock carga, queda marcado como consultado', () async {
    final provider = _crear(falla: false);

    await provider.cargarReportes();

    expect(provider.alertasCargadas, isTrue);
    expect(provider.alertasDeStock.length, 1);
    expect(provider.error, isNull);
  });
}

DashboardProvider _crear({required bool falla}) {
  return DashboardProvider(
    dashboard: _DashboardFalso(falla: falla),
    pedidos: _PedidosVacio(),
    catalogo: _CatalogoVacio(),
    api: _apiFalsa(),
  );
}

/// Cliente HTTP de mentira, igual que en las otras pruebas: los servicios falsos
/// lo necesitan para tipar, pero nunca llegan a usarlo.
ClienteApi _apiFalsa() => ClienteApi(urlBase: 'http://localhost/api');

/// Reportes de mentira: o responden datos, o fallan con el 404 de ruta.
class _DashboardFalso extends ServicioDashboard {
  final bool falla;

  _DashboardFalso({required this.falla}) : super(_apiFalsa());

  ErrorDeApi get _noDisponible => const ErrorDeApi(
    'El servidor no tiene habilitada esa funcion todavia '
    '(endpoint no encontrado).',
    codigo: 404,
  );

  @override
  Future<ReporteVentasPorPeriodo> ventasPorPeriodo({
    required DateTime desde,
    required DateTime hasta,
    required String agruparPor,
  }) async {
    if (falla) throw _noDisponible;
    return const ReporteVentasPorPeriodo(
      ventas: [],
      totalActual: 0,
      totalAnterior: 0,
      variacionPorcentual: null,
    );
  }

  @override
  Future<ReporteVentasPorProducto> ventasPorProducto({
    DateTime? desde,
    DateTime? hasta,
    int limite = 5,
  }) async {
    if (falla) throw _noDisponible;
    return const ReporteVentasPorProducto(masVendidos: [], menosVendidos: []);
  }

  @override
  Future<List<PedidosPorEstado>> pedidosPorEstado({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    if (falla) throw _noDisponible;
    return const [];
  }

  @override
  Future<List<InsumoConAlerta>> insumosConAlerta({
    double umbralCritico = 20,
  }) async {
    if (falla) throw _noDisponible;
    return const [
      InsumoConAlerta(
        ingredienteId: 2,
        nombre: 'Harina',
        stockActual: 1.5,
        stockMinimo: 10,
        porcentajeDisponible: 15,
        estado: 'critico',
        productosAfectados: [],
      ),
    ];
  }

  @override
  Future<List<Ingrediente>> obtenerIngredientes() async => const [];
}

/// Servicios sin uso en estas pruebas, solo para satisfacer el constructor.
class _PedidosVacio extends ServicioPedidos {
  _PedidosVacio() : super(_apiFalsa());
}

class _CatalogoVacio extends ServicioCatalogo {
  _CatalogoVacio() : super(_apiFalsa());
}
