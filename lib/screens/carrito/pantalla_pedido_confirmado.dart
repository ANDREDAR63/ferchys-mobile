/// Pantalla de exito despues de confirmar un pedido.
///
/// ES LA UNICA PANTALLA DONDE SE MUESTRA EL PEDIDO REAL DEL SERVIDOR, con el
/// total que calculo el backend. En la web se reutiliza la vista de detalle; en
/// el movil se muestra aparte porque el flujo es distinto: aqui se acaba de
/// pagar, y lo que la persona necesita es un numero de pedido y saber cuanto
/// va a pagar, no meterse a navegar.
///
/// El boton de "Ver mis pedidos" es lo que espera la gente despues de pedir.
/// Los de compartir y volver al inicio se omitieron a proposito: en un movil
/// no agregan nada y cada boton de mas es un camino mas para perderse.
library;

import 'package:flutter/material.dart';

import '../../modelos/pedido.dart';
import '../../utils/formateo.dart';
import '../../widgets/chip_estado_pedido.dart';
import '../pedidos/pantalla_pedidos.dart';

class PantallaPedidoConfirmado extends StatelessWidget {
  final Pedido pedido;

  const PantallaPedidoConfirmado({super.key, required this.pedido});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: tema.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: tema.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Pedido confirmado',
              style: tema.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Guardo este numero para seguir tu pedido.',
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _FilaDato(
                      etiqueta: 'Numero de pedido',
                      valor: '#${pedido.id}',
                    ),
                    const Divider(height: 24),
                    _FilaDato(
                      etiqueta: 'Estado',
                      // El backend ya movio el pedido a `preparing` al registrar
                      // el pago, asi que el chip muestra el estado real y no un
                      // "pendiente" que ya no existe.
                      valorWidget: ChipEstadoPedido(estado: pedido.estado),
                    ),
                    const Divider(height: 24),
                    _FilaDato(
                      etiqueta: 'Total',
                      valor: formatearMoneda(pedido.total),
                      destacar: true,
                    ),
                    if (pedido.creadoEn != null) ...[
                      const Divider(height: 24),
                      _FilaDato(
                        etiqueta: 'Fecha',
                        valor: formatearFechaHora(pedido.creadoEn),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            _ResumenArticulos(pedido: pedido),

            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () {
                // Se quita esta pantalla del historial para que el boton
                // "atras" del celular no regrese a una compra ya terminada.
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => const PantallaPedidos(),
                  ),
                  (ruta) => ruta.isFirst,
                );
              },
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Ver mis pedidos'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((ruta) => ruta.isFirst),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila etiqueta / valor de la tarjeta de resumen.
class _FilaDato extends StatelessWidget {
  final String etiqueta;
  final String? valor;
  final Widget? valorWidget;
  final bool destacar;

  const _FilaDato({
    required this.etiqueta,
    this.valor,
    this.valorWidget,
    this.destacar = false,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: tema.textTheme.bodyMedium),
        // El chip del estado no se puede pasar por `valor` porque es un widget;
        // por eso la fila acepta las dos formas.
        if (valorWidget != null)
          valorWidget!
        else
          Text(
            valor ?? '',
            style: destacar
                ? tema.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : tema.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
          ),
      ],
    );
  }
}

/// Cantos articulos y el costo de cada uno.
class _ResumenArticulos extends StatelessWidget {
  final Pedido pedido;

  const _ResumenArticulos({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    // Con muchos productos la lista se vuelve larga, asi que se limita a los
    // primeros y se dice cuantos mas hay. El detalle completo esta en el
    // historial del pedido.
    const maximo = 5;
    final visibles = pedido.items.take(maximo).toList();
    final restantes = pedido.items.length - visibles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Articulos (${pedido.items.length})',
          style: tema.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final item in visibles)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${item.cantidad} x ${item.nombreProducto}',
                    style: tema.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatearMoneda(item.subtotal),
                  style: tema.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (restantes > 0)
          Text(
            'y $restantes mas...',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
