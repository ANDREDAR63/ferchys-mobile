/// Piezas de los dashboards: tarjeta de indicador y barra de proportion.
///
/// Se agrupan porque las dos son "mostrar un numero con su contexto" y las
/// usan el panel de administrador y el de cocina.
///
/// LA BARRA ES UN `LinearProgressIndicator` A MANO Y NO UN GRAFICO. Los reportes
/// traen de 2 a 30 filas y el mensaje es "esto es mucho / esto es poco"
/// comparado con el resto, no una evolucion en el tiempo. Una barra de
/// proporcion comunica exactamente eso sin agregar un paquete de graficos ni
/// un `CustomPainter`.
library;

import 'package:flutter/material.dart';

import '../utils/formateo.dart';

/// One of the six big numbers at the top of the admin panel.
class TarjetaIndicador extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final IconData icono;

  /// Marks the card as "still loading" and shows a dash instead of a zero, so a
  /// request that has not returned yet is not confused with a real zero.
  final bool cargando;

  const TarjetaIndicador({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.icono,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      // `margin` en cero porque el espaciado lo pone el `GridView` exterior;
      // dejarlo aqui ponia un doble padding.
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: tema.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    etiqueta,
                    style: tema.textTheme.labelMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              cargando ? '—' : valor,
              style: tema.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label, a money amount and a bar showing its share of the largest one.
///
/// [proporcion] is expected between 0 and 1 and is clamped, because the
/// backend can return a percentage over 100 when a row is compared against
/// itself and rounding leaves it a hair above.
class BarraProporcion extends StatelessWidget {
  final String etiqueta;
  final String detalle;
  final double proporcion;
  final Color color;

  /// Puts the percentage on the right instead of the money. Used in the
  /// products-by-category view, where the share of revenue is the point.
  final bool mostrarPorcentaje;

  const BarraProporcion({
    super.key,
    required this.etiqueta,
    required this.detalle,
    required this.proporcion,
    required this.color,
    this.mostrarPorcentaje = false,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final segura = proporcion.isNaN ? 0.0 : proporcion.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  etiqueta,
                  style: tema.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                mostrarPorcentaje
                    ? '${(proporcion * 100).toStringAsFixed(1)}%'
                    : detalle,
                style: tema.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: segura,
              minHeight: 6,
              color: color,
              // La pista se pinta apenas distinta de la barra: si se usa el
              // color por defecto queda gris fuerte y compite con el dato.
              backgroundColor: tema.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta con titulo que envuelve una seccion del dashboard.
///
/// El `ExpansionTile` va aqui y no en cada pantalla para que los cuatro
/// accordions del panel de admin se abran igual.
class TarjetaSeccion extends StatelessWidget {
  final String titulo;
  final Widget hijo;
  final IconData? icono;

  /// Open from the start. The reports are the reason the admin opens the app,
  /// so they should be visible without a tap.
  final bool abiertaInicialmente;

  const TarjetaSeccion({
    super.key,
    required this.titulo,
    required this.hijo,
    this.icono,
    this.abiertaInicialmente = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: abiertaInicialmente,
        title: Text(titulo, style: Theme.of(context).textTheme.titleSmall),
        leading: icono == null ? null : Icon(icono),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [hijo],
      ),
    );
  }
}

/// Cabecera con el total y su variacion contra el periodo anterior.
///
/// Se separa del resto porque la variacion es lo primero que hay que leer: si
/// las ventas cayeron, todo lo demas de la tarjeta es contexto.
class EncabezadoTotalConVariacion extends StatelessWidget {
  final double total;
  final double totalAnterior;
  final double? variacion;

  const EncabezadoTotalConVariacion({
    super.key,
    required this.total,
    required this.totalAnterior,
    required this.variacion,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final subio = (variacion ?? 0) >= 0;

    // Sin variacion no se pinta flecha ni color: el backend la manda en null
    // cuando el periodo anterior fue cero, y "subio 0%" seria inventar un dato.
    final colorVariacion = variacion == null
        ? tema.colorScheme.onSurfaceVariant
        : (subio ? Colors.green.shade700 : tema.colorScheme.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatearMoneda(total),
          style: tema.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (variacion != null)
              Icon(
                subio ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 18,
                color: colorVariacion,
              ),
            if (variacion != null) const SizedBox(width: 4),
            Text(
              '${formatearVariacion(variacion)} vs. ${formatearMoneda(totalAnterior)} anteriores',
              style: tema.textTheme.bodySmall?.copyWith(color: colorVariacion),
            ),
          ],
        ),
      ],
    );
  }
}
