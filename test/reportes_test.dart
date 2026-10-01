/// Pruebas del parseo de los reportes del administrador.
///
/// El backend NO devuelve los cuatro reportes con la misma forma, y esa
/// asimetria es facil de olvidar cuando se escribe la pantalla:
///
/// - `sales-by-period` viene envuelto: `{data: [...], comparacion: {...}}`
/// - `sales-by-product` trae DOS listas: `mas_vendidos` y `menos_vendidos`
/// - `orders-by-status` y `low-stock` son arreglos sueltos
///
/// Ademas los `decimal` llegan como texto desde MySQL. Estas pruebas fijan las
/// dos cosas con datos copiados tal cual los produce el backend, para que un
/// cambio de contrato se note aqui y no en la pantalla del dashboard.
///
/// Se ejecutan con `flutter test`.
library;

import 'package:ferchys_mobile/modelos/pedido.dart';
import 'package:ferchys_mobile/servicios/servicio_dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReporteVentasPorPeriodo', () {
    // Copia literal de la respuesta de GET /reports/sales-by-period.
    const respuesta = {
      'data': [
        {
          'periodo': '2026-09-01',
          'total_ventas': '125000.00',
          'cantidad_pedidos': 12,
          'ticket_promedio': '10416.67',
        },
        {
          'periodo': '2026-09-02',
          'total_ventas': '98000.50',
          'cantidad_pedidos': 9,
          'ticket_promedio': '10888.94',
        },
      ],
      'comparacion': {
        'total_ventas_actual': '223000.50',
        'total_ventas_anterior': '200000.00',
        'variacion_porcentual': 11.5,
      },
    };

    test('lee la serie que viene dentro de "data"', () {
      final reporte = ReporteVentasPorPeriodo.desdeJson(respuesta);
      expect(reporte.ventas.length, 2);
      expect(reporte.ventas.first.periodo, '2026-09-01');
    });

    test('convierte los decimales que llegan como texto', () {
      final reporte = ReporteVentasPorPeriodo.desdeJson(respuesta);
      expect(reporte.ventas.first.totalVentas, 125000.0);
      expect(reporte.ventas.first.ticketPromedio, 10416.67);
      expect(reporte.ventas.first.cantidadPedidos, 12);
    });

    test('lee la comparacion contra el periodo anterior', () {
      final reporte = ReporteVentasPorPeriodo.desdeJson(respuesta);
      expect(reporte.totalActual, 223000.5);
      expect(reporte.totalAnterior, 200000.0);
      expect(reporte.variacionPorcentual, 11.5);
    });

    test('deja la variacion en null si el backend la manda null', () {
      // El backend manda null cuando el periodo anterior vendio cero, para no
      // inventar un porcentaje. La pantalla lo muestra como guion.
      final reporte = ReporteVentasPorPeriodo.desdeJson(const {
        'data': <dynamic>[],
        'comparacion': {
          'total_ventas_actual': '50000.00',
          'total_ventas_anterior': '0',
          'variacion_porcentual': null,
        },
      });
      expect(reporte.variacionPorcentual, isNull);
      expect(reporte.estaVacio, isTrue);
    });
  });

  group('ReporteVentasPorProducto', () {
    // Copia literal de la respuesta de GET /reports/sales-by-product.
    const respuesta = {
      'mas_vendidos': [
        {
          'producto_id': 3,
          'nombre': 'Brownie con helado',
          'unidades_vendidas': 42,
          'ingresos_generados': '147000.00',
          'numero_pedidos': 30,
        },
      ],
      'menos_vendidos': [
        {
          'producto_id': 9,
          'nombre': 'Torta de chocolate',
          'unidades_vendidas': 1,
          'ingresos_generados': '28000.00',
          'numero_pedidos': 1,
        },
      ],
    };

    test('separa los dos rankings, que no vienen en "data"', () {
      final reporte = ReporteVentasPorProducto.desdeJson(respuesta);
      expect(reporte.masVendidos.length, 1);
      expect(reporte.menosVendidos.length, 1);
      expect(reporte.masVendidos.first.productoId, 3);
      expect(reporte.menosVendidos.first.productoId, 9);
    });

    test('convierte los ingresos que llegan como texto', () {
      final reporte = ReporteVentasPorProducto.desdeJson(respuesta);
      expect(reporte.masVendidos.first.ingresosGenerados, 147000.0);
      expect(reporte.masVendidos.first.unidadesVendidas, 42);
    });

    test('no se rompe si el backend omite un ranking', () {
      final reporte = ReporteVentasPorProducto.desdeJson(const {
        'mas_vendidos': <dynamic>[],
      });
      expect(reporte.masVendidos, isEmpty);
      expect(reporte.menosVendidos, isEmpty);
    });
  });

  group('PedidosPorEstado', () {
    test('lee una fila de orders-by-status', () {
      const fila = {
        'estado': 'pending',
        'cantidad_pedidos': 4,
        'monto_total': 96000.0,
        'porcentaje_del_total': 25.0,
      };
      final filaLeida = PedidosPorEstado.desdeJson(fila);
      expect(filaLeida.estado, 'pending');
      expect(filaLeida.etiqueta, 'Pendiente');
      expect(filaLeida.cantidadPedidos, 4);
      expect(filaLeida.montoTotal, 96000.0);
      expect(filaLeida.porcentajeDelTotal, 25.0);
    });

    test('traduce el estado crudo al español', () {
      expect(PedidoEstados.etiquetaDe('preparing'), 'En preparación');
      expect(PedidoEstados.etiquetaDe('shipped'), 'En camino');
      expect(PedidoEstados.etiquetaDe('delivered'), 'Entregado');
    });

    test('muestra el estado crudo si el backend agrega uno nuevo', () {
      // Si mañana aparece un estado que la app no conoce, se muestra tal cual
      // en vez de un chip en blanco.
      expect(PedidoEstados.etiquetaDe('refunded'), 'refunded');
    });
  });

  group('InsumoConAlerta', () {
    test('lee una fila de low-stock con sus productos afectados', () {
      const fila = {
        'ingrediente_id': 2,
        'nombre': 'Harina',
        'stock_actual': 1.5,
        'stock_minimo': 10.0,
        'porcentaje_disponible': 15.0,
        'estado': 'critico',
        'productos_afectados': ['Brownie', 'Torta'],
      };
      final insumo = InsumoConAlerta.desdeJson(fila);
      expect(insumo.nombre, 'Harina');
      expect(insumo.esCritico, isTrue);
      expect(insumo.productosAfectados.length, 2);
      expect(insumo.resumen, '15% del minimo');
    });

    test('distingue un insumo sano de uno critico', () {
      InsumoConAlerta leer(String estado) {
        return InsumoConAlerta.desdeJson({
          'nombre': 'Azucar',
          'estado': estado,
        });
      }

      expect(leer('ok').estaSano, isTrue);
      expect(leer('ok').esBajo, isFalse);
      expect(leer('bajo').esBajo, isTrue);
    });
  });
}
