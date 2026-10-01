/// Lista de pedidos con su detalle desplegable.
///
/// SIRVE PARA LOS TRES ROLES QUE TIENEN PEDIDOS (cliente, cocina, repartidor) Y
/// POR ESO MISMO FILTRA SEGUN QUIEN MIRA. La cocina solo necesita lo que tiene
/// que cocinar y el repartidor solo lo que tiene que llevar, asi que una lista
/// con todo les obliga a recorrer con el dedo buscando lo suyo.
///
/// EL FILTRO SE APLICA EN EL DISPOSITIVO, NO EN EL BACKEND. `GET /orders` no
/// acepta un filtro por estado, y bajarlos todos para descartar la mitad solo
/// haria la pantalla mas lenta. Para el cliente el backend ya devuelve solo los
/// suyos, asi que no hay nada que descartar.
///
/// EL HISTORIAL DE ESTADOS VIENE DENTRO DE CADA PEDIDO (`statusHistory` en la
/// tabla `order_status_histories`), asi que se despliega sin pedir nada mas.
/// Ahi se ve quien movio el pedido y cuando, que es la pregunta que aparece
/// cuando algo sale mal.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../modelos/pedido.dart';
import '../../state/pedidos_provider.dart';
import '../../utils/formateo.dart';
import '../../widgets/chip_estado_pedido.dart';
import '../../widgets/estados_pantalla.dart';

class PantallaPedidos extends StatefulWidget {
  /// Cuando es `true` muestra el boton para avanzar el estado del pedido, que
  /// solo tienen cocina y repartidor. El cliente no lo ve nunca.
  final bool permiteAvanzar;

  /// Indica si quien mira es la cocina, porque el paso que sigue es distinto:
  /// la cocina alterna entre dos estados y el repartidor solo entrega.
  ///
  /// El filtrado de la lista tambien depende de esto: la cocina solo ve lo que
  /// tiene que cocinar y el repartidor solo lo que tiene que llevar. El filtro
  /// se aplica en el dispositivo y no en el backend porque `GET /orders` no
  /// acepta un filtro por estado: bajarlos todos para descartar la mitad solo
  /// haria la pantalla mas lenta.
  final bool esCocina;

  const PantallaPedidos({
    super.key,
    this.permiteAvanzar = false,
    this.esCocina = false,
  });

  @override
  State<PantallaPedidos> createState() => _PantallaPedidosState();
}

class _PantallaPedidosState extends State<PantallaPedidos> {
  @override
  void initState() {
    super.initState();

    // Mismo criterio que el catalogo: cargar una vez al entrar, no en cada
    // `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PedidosProvider>().cargar(pedirDirecciones: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.read<PedidosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo),
        actions: [
          IconButton(
            onPressed: () => estado.cargar(pedirDirecciones: false),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Consumer<PedidosProvider>(
        builder: (contexto, estado, _) {
          final visibles = _visibles(estado);

          if (estado.cargando && visibles.isEmpty) {
            return const PantallaCargando(mensaje: 'Cargando pedidos...');
          }

          if (estado.error != null && visibles.isEmpty) {
            return PantallaError(
              mensaje: estado.error!,
              alReintentar: () {
                estado.limpiarError();
                estado.cargar(pedirDirecciones: false);
              },
            );
          }

          if (visibles.isEmpty) {
            return PantallaVacia(
              icono: _iconoVacio,
              titulo: _tituloVacio,
              mensaje: _mensajeVacio,
            );
          }

          if (estado.error != null) {
            // Hay pedidos y ademas un error: se avisa arriba y se sigue
            // mostrando la lista, que es lo util.
            return Column(
              children: [
                _BannerAviso(mensaje: estado.error!),
                Expanded(child: _lista(estado, visibles)),
              ],
            );
          }

          return _lista(estado, visibles);
        },
      ),
    );
  }

  /// Los pedidos que le corresponden a quien esta mirando.
  List<Pedido> _visibles(PedidosProvider estado) {
    if (!widget.permiteAvanzar) return estado.pedidos;
    if (widget.esCocina) return estado.pendientesDeCocina();
    return estado.listosParaEntregar();
  }

  Widget _lista(PedidosProvider estado, List<Pedido> visibles) {
    return RefreshIndicator(
      onRefresh: () => estado.cargar(pedirDirecciones: false),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: visibles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (contexto, indice) => _TarjetaPedido(
          pedido: visibles[indice],
          estado: estado,
          permiteAvanzar: widget.permiteAvanzar,
          esCocina: widget.esCocina,
        ),
      ),
    );
  }

  String get _titulo {
    if (!widget.permiteAvanzar) return 'Pedidos';
    return widget.esCocina ? 'Cocina' : 'Repartos';
  }

  /// El texto del estado vacio cambia por rol porque la pregunta que se hace es
  /// distinta: a la cocina le importa si hay algo que cocinar, y al repartidor
  /// si hay algo que llevar.
  IconData get _iconoVacio {
    if (!widget.permiteAvanzar) return Icons.receipt_long_outlined;
    return widget.esCocina
        ? Icons.soup_kitchen_outlined
        : Icons.delivery_dining_outlined;
  }

  String get _tituloVacio {
    if (!widget.permiteAvanzar) return 'Sin pedidos';
    return widget.esCocina ? 'Nada por preparar' : 'Nada por entregar';
  }

  String get _mensajeVacio {
    if (!widget.permiteAvanzar) {
      return 'Cuando hagas un pedido, aparecera aqui con su historial.';
    }
    return widget.esCocina
        ? 'No hay pedidos pendientes. Toca el refresco para actualizar.'
        : 'No hay pedidos en camino. Toca el refresco para actualizar.';
  }
}

/// Franja de error discreta, para cuando la lista si se pudo cargar.
class _BannerAviso extends StatelessWidget {
  final String mensaje;

  const _BannerAviso({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      width: double.infinity,
      color: tema.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        mensaje,
        style: tema.textTheme.bodySmall?.copyWith(
          color: tema.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

/// Tarjeta de un pedido, con el historial desplegable.
class _TarjetaPedido extends StatelessWidget {
  final Pedido pedido;
  final PedidosProvider estado;
  final bool permiteAvanzar;
  final bool esCocina;

  const _TarjetaPedido({
    required this.pedido,
    required this.estado,
    required this.permiteAvanzar,
    required this.esCocina,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final articulos = pedido.items.fold<int>(
      0,
      (suma, item) => suma + item.cantidad,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '#${pedido.id}',
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ChipEstadoPedido(estado: pedido.estado, compacto: true),
                  ],
                ),
                Text(
                  formatearMoneda(pedido.total),
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Text(
              pedido.creadoEn == null
                  ? '$articulos articulos'
                  : '$articulos articulos - ${formatearFechaHora(pedido.creadoEn)}',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),

            if (pedido.direccion != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      pedido.direccion!.textoCompleto,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            if (pedido.historial.isNotEmpty) ...[
              const SizedBox(height: 8),
              Theme(
                // Se baja el divisor del `ExpansionTile` a cero porque la
                // tarjeta ya tiene su propio borde; con el divisor se ve una
                // linea de mas entre las dos.
                data: tema.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    'Historial (${pedido.historial.length} cambios)',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.primary,
                    ),
                  ),
                  children: [
                    for (final cambio in pedido.historial)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: tema.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _textoCambio(cambio),
                                style: tema.textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              formatearFechaHora(cambio.cambiadoEn),
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

            if (permiteAvanzar && _tieneSiguiente()) ...[
              const SizedBox(height: 8),
              _BotonAvanzar(pedido: pedido, estado: estado, esCocina: esCocina),
            ],
          ],
        ),
      ),
    );
  }

  /// El boton de avanzar solo aparece si el pedido tiene un siguiente estado.
  ///
  /// Se calcula con la misma tabla que usa el provider, para que lo que se ve
  /// y lo que se manda al servidor no puedan contradecirse.
  bool _tieneSiguiente() {
    if (esCocina) {
      return PedidoEstados.siguienteDelCocinero.containsKey(pedido.estado);
    }
    return pedido.estado == PedidoEstados.enCamino;
  }

  String _textoCambio(HistorialEstado cambio) {
    final nuevo = PedidoEstados.etiquetaDe(cambio.estadoNuevo);

    if (cambio.estadoAnterior == null) {
      // El primer registro no tiene estado anterior: el pedido nace en este.
      return 'Pedido creado como $nuevo';
    }

    return '${PedidoEstados.etiquetaDe(cambio.estadoAnterior!)} -> $nuevo';
  }
}

/// Boton que mueve el pedido al siguiente estado.
class _BotonAvanzar extends StatelessWidget {
  final Pedido pedido;
  final PedidosProvider estado;
  final bool esCocina;

  const _BotonAvanzar({
    required this.pedido,
    required this.estado,
    required this.esCocina,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    // El texto del boton dice a donde va, no "avanzar": la persona tiene que
    // saber que va a poner el pedido en preparacion antes de confirmarlo.
    final siguiente = esCocina
        ? PedidoEstados.etiquetaDe(
            PedidoEstados.siguienteDelCocinero[pedido.estado]!,
          )
        : PedidoEstados.etiquetaDe(PedidoEstados.siguienteDelRepartidor);

    final ocupando = estado.actualizandoPedidoId == pedido.id;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: ocupando
            ? null
            : () => estado.avanzarPedido(pedido.id, esCocinero: esCocina),
        icon: ocupando
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                esCocina
                    ? Icons.soup_kitchen_outlined
                    : Icons.check_circle_outline,
              ),
        label: Text(
          esCocina ? 'Marcar como $siguiente' : 'Marcar como entregado',
        ),
        style: FilledButton.styleFrom(
          foregroundColor: tema.colorScheme.onSecondaryContainer,
          backgroundColor: tema.colorScheme.secondaryContainer,
        ),
      ),
    );
  }
}
