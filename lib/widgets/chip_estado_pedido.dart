/// Chip de color para el estado de un pedido.
///
/// El backend maneja los estados en ingles (`pending`, `preparing`...) y cada
/// uno tiene un color distinto en la web. Centralizarlo aqui evita que un chip
/// quede verde en la cocina y azul en el repartidor.
///
/// La clase de color se elige por [estado] y no por el rol: el mismo estado
/// se ve igual en todas las pantallas, que es lo que hace entendible el
/// seguimiento de un pedido.
library;

import 'package:flutter/material.dart';

import '../modelos/pedido.dart';

class ChipEstadoPedido extends StatelessWidget {
  final String estado;

  /// Cuando es `true` el chip se muestra pequeno, para usarlo dentro de una
  /// fila densa de lista en vez de en una tarjeta.
  final bool compacto;

  const ChipEstadoPedido({
    super.key,
    required this.estado,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final colores = _ColoresChip.de(estado, Theme.of(context).colorScheme);
    final tema = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 8 : 10,
        vertical: compacto ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: colores.fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        PedidoEstados.etiquetaDe(estado),
        style:
            (compacto ? tema.textTheme.labelSmall : tema.textTheme.labelMedium)
                ?.copyWith(color: colores.texto, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Par de colores del chip: fondo suave y texto con contraste suficiente.
///
/// Se usan los colores "container" del tema en vez de colores fijos, para que
/// el chip siga viendose bien si alguien cambia el tema de la app.
class _ColoresChip {
  final Color fondo;
  final Color texto;

  const _ColoresChip(this.fondo, this.texto);

  /// Elige el par segun el estado crudo del backend.
  ///
  /// El caso por defecto es para un estado que la app todavia no conoce: se
  /// muestra con colores neutros en vez de romperse, por si el backend agrega
  /// un estado nuevo antes de que se actualice la app.
  factory _ColoresChip.de(String estado, ColorScheme esquema) {
    switch (estado) {
      case PedidoEstados.pendiente:
        return _ColoresChip(
          esquema.tertiaryContainer,
          esquema.onTertiaryContainer,
        );
      case PedidoEstados.enPreparacion:
        return _ColoresChip(
          esquema.secondaryContainer,
          esquema.onSecondaryContainer,
        );
      case PedidoEstados.enCamino:
        return _ColoresChip(
          esquema.primaryContainer,
          esquema.onPrimaryContainer,
        );
      case PedidoEstados.entregado:
        return _ColoresChip(esquema.primary, esquema.onPrimary);
      case PedidoEstados.cancelado:
        return _ColoresChip(esquema.errorContainer, esquema.onErrorContainer);
      default:
        return _ColoresChip(
          esquema.surfaceContainerHighest,
          esquema.onSurfaceVariant,
        );
    }
  }
}
