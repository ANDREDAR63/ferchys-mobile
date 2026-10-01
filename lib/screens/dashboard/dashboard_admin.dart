/// Panel del administrador: indicadores, pedidos por estado, ventas y stock.
///
/// ES DE SOLO LECTURA, Y ESO ES UNA DECISION, NO UNA CARENCIA. La version web
/// permite crear y editar usuarios, productos, ingredientes y promociones.
/// Esos formularios tienen seis o siete campos cada uno y en un telefono se
/// vuelven lentos y propensos a mandar mal. Se decidio que el movil de
/// admin resume y consulta, y que el alta y la edicion se hagan en la web.
///
/// Se deja a la vista la razon de cada reporte, porque saber por que esta el
/// numero es lo que lo hace util.
///
/// LOS DATOS LLEGAN EN DOS TIEMPOS. Los seis indicadores se piden primero y los
/// cuatro reportes despues, en paralelo. Asi la pantalla muestra lo basico
/// rapido y los graficos van apareciendo, en vez de quedar en blanco hasta que
/// terminen todos.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../servicios/servicio_dashboard.dart';
import '../../state/dashboard_provider.dart';
import '../../utils/formateo.dart';
import '../../widgets/piezas_dashboard.dart';

class DashboardAdmin extends StatefulWidget {
  const DashboardAdmin({super.key});

  @override
  State<DashboardAdmin> createState() => _DashboardAdminState();
}

class _DashboardAdminState extends State<DashboardAdmin> {
  @override
  void initState() {
    super.initState();

    // Los dos blocos de carga se disparan juntos y no encadenados: cada uno ya
    // corre sus peticiones en paralelo internamente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dashboard = context.read<DashboardProvider>();
      dashboard.cargarIndicadores();
      dashboard.cargarReportes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administracion'),
        actions: [
          IconButton(
            onPressed: () {
              dashboard.cargarIndicadores();
              dashboard.cargarReportes();
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await dashboard.cargarIndicadores();
          await dashboard.cargarReportes();
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (dashboard.error != null) ...[
              _BannerError(mensaje: dashboard.error!),
              const SizedBox(height: 12),
            ],

            _filaIndicadores(dashboard),
            const SizedBox(height: 16),

            TarjetaSeccion(
              titulo: 'Ventas por periodo',
              icono: Icons.insights_rounded,
              abiertaInicialmente: true,
              hijo: _bloqueVentas(dashboard, tema),
            ),
            const SizedBox(height: 10),

            TarjetaSeccion(
              titulo: 'Pedidos por estado',
              icono: Icons.donut_small_rounded,
              abiertaInicialmente: true,
              hijo: _bloquePedidosPorEstado(dashboard, tema),
            ),
            const SizedBox(height: 10),

            TarjetaSeccion(
              titulo: 'Productos mas y menos vendidos',
              icono: Icons.leaderboard_rounded,
              hijo: _bloqueProductos(dashboard, tema),
            ),
            const SizedBox(height: 10),

            TarjetaSeccion(
              titulo: 'Alertas de stock',
              icono: Icons.inventory_2_outlined,
              hijo: _bloqueStock(dashboard, tema),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Los seis indicadores en una grilla de tres columnas.
  Widget _filaIndicadores(DashboardProvider dashboard) {
    final indicadores = dashboard.indicadores;
    final cargando = dashboard.cargandoIndicadores;

    final datos = <(String, String, IconData)>[
      ('Pedidos', '${indicadores.pedidos}', Icons.receipt_long_rounded),
      ('Productos', '${indicadores.productos}', Icons.cake_rounded),
      ('Usuarios', '${indicadores.usuarios}', Icons.people_rounded),
      ('Ingredientes', '${indicadores.ingredientes}', Icons.egg_alt_outlined),
      ('Promociones', '${indicadores.promociones}', Icons.local_offer_outlined),
      ('Pagos', '${indicadores.pagos}', Icons.payments_outlined),
    ];

    return GridView.count(
      // `shrinkWrap` + `NeverScrollableScrollPhysics` porque esta grilla esta
      // dentro de un `ListView`: sin esto, el `GridView` se queda con altura
      // infinita y revienta la pantalla.
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.95,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final (etiqueta, valor, icono) in datos)
          TarjetaIndicador(
            etiqueta: etiqueta,
            valor: valor,
            icono: icono,
            cargando: cargando,
          ),
      ],
    );
  }

  Widget _bloqueVentas(DashboardProvider dashboard, ThemeData tema) {
    if (dashboard.cargandoReportes && dashboard.reportePeriodo == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final reporte = dashboard.reportePeriodo;
    if (reporte == null) {
      return const Text('No se pudo cargar el reporte de ventas.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SelectorRango(dashboard: dashboard),
        const SizedBox(height: 14),

        EncabezadoTotalConVariacion(
          total: reporte.totalActual,
          totalAnterior: reporte.totalAnterior,
          variacion: reporte.variacionPorcentual,
        ),
        const SizedBox(height: 18),

        if (reporte.estaVacio)
          const Text('No hubo ventas en este rango.')
        else
          for (final venta in reporte.ventas)
            BarraProporcion(
              etiqueta: venta.periodo,
              detalle: formatearMoneda(venta.totalVentas),
              // La proporcion se calcula contra la mayor venta del periodo, no
              // contra el total: asi se ve que dia fue el mas fuerte. Contra el
              // total, con 30 dias, todas las barras serian de un 3% y no se
              // distinguiria nada.
              proporcion: _proporcionDeVenta(venta.totalVentas, reporte),
              color: tema.colorScheme.primary,
            ),
      ],
    );
  }

  /// Parte del total de la mayor venta del rango.
  double _proporcionDeVenta(double monto, ReporteVentasPorPeriodo reporte) {
    if (reporte.ventas.isEmpty) return 0;

    final mayor = reporte.ventas
        .map((venta) => venta.totalVentas)
        .reduce((a, b) => a > b ? a : b);

    if (mayor <= 0) return 0;
    return monto / mayor;
  }

  Widget _bloquePedidosPorEstado(DashboardProvider dashboard, ThemeData tema) {
    if (dashboard.pedidosPorEstado.isEmpty) {
      return const Text('No hay pedidos en este rango.');
    }

    final mayor = dashboard.pedidosPorEstado
        .map((fila) => fila.cantidadPedidos)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final fila in dashboard.pedidosPorEstado)
          BarraProporcion(
            etiqueta: fila.etiqueta,
            detalle: '${fila.cantidadPedidos} pedidos',
            proporcion: mayor == 0 ? 0 : fila.cantidadPedidos / mayor,
            color: tema.colorScheme.tertiary,
          ),
      ],
    );
  }

  Widget _bloqueProductos(DashboardProvider dashboard, ThemeData tema) {
    final reporte = dashboard.reporteProductos;
    if (reporte == null) {
      return const Text('No se pudo cargar el ranking de productos.');
    }

    if (reporte.masVendidos.isEmpty && reporte.menosVendidos.isEmpty) {
      return const Text('No hubo ventas de productos en este rango.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mas vendidos', style: tema.textTheme.labelLarge),
        const SizedBox(height: 4),
        for (final producto in reporte.masVendidos)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${producto.nombre} (${producto.unidadesVendidas} und.)',
                    style: tema.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatearMoneda(producto.ingresosGenerados),
                  style: tema.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        Text('Menos vendidos', style: tema.textTheme.labelLarge),
        const SizedBox(height: 4),
        // Si el rango fue corto, el ultimo puede no ser el mas flojo de todo el
        // catalogo: solo es el menor de los que el backend devolvio.
        for (final producto in reporte.menosVendidos)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${producto.nombre} (${producto.unidadesVendidas} und.)',
                    style: tema.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatearMoneda(producto.ingresosGenerados),
                  style: tema.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bloqueStock(DashboardProvider dashboard, ThemeData tema) {
    // Si las alertas no se pudieron consultar, no se puede afirmar que todo este
    // bien: se dice que no se sabe.
    if (!dashboard.alertasCargadas) {
      return const Text('No se pudieron cargar las alertas de stock.');
    }

    final alertas = dashboard.alertasDeStock;

    if (alertas.isEmpty) {
      return Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Todos los insumos estan por encima del minimo.'),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (final insumo in alertas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  insumo.esCritico
                      ? Icons.error_rounded
                      : Icons.warning_amber_rounded,
                  size: 20,
                  color: insumo.esCritico
                      ? tema.colorScheme.error
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(insumo.nombre, style: tema.textTheme.bodyMedium),
                      Text(
                        insumo.resumen,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Botones de rango rapido: hoy, semana, mes.
class _SelectorRango extends StatelessWidget {
  final DashboardProvider dashboard;

  const _SelectorRango({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final desde = dashboard.desde;
    final hasta = dashboard.hasta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            _BotonRango(texto: 'Hoy', clave: 'hoy', dashboard: dashboard),
            _BotonRango(texto: '7 dias', clave: 'semana', dashboard: dashboard),
            _BotonRango(texto: 'Este mes', clave: 'mes', dashboard: dashboard),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${formatearFecha(desde)} - ${formatearFecha(hasta)}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Un boton del rango rapido.
class _BotonRango extends StatelessWidget {
  final String texto;
  final String clave;
  final DashboardProvider dashboard;

  const _BotonRango({
    required this.texto,
    required this.clave,
    required this.dashboard,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(texto),
      // Se deshabilita mientras carga para que tres toques seguidos no
      // disparen tres peticiones del reporte.
      onPressed: dashboard.cargandoReportes
          ? null
          : () => dashboard.aplicarRangoRapido(clave),
    );
  }
}

/// Franja de error del panel.
class _BannerError extends StatelessWidget {
  final String mensaje;

  const _BannerError({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: tema.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
