/// Los tres estados que puede tener una pantalla que carga datos.
///
/// Se agrupan en un archivo porque son el mismo concepto visto de tres
/// maneras y pesan pocas lineas cada uno: cualquier pantalla los usa y siempre
/// con la misma estructura, para que "cargando", "vacio" y "error" se vean
/// iguales en toda la app.
///
/// La diferencia entre los tres importa y no es solo estetica:
///   - [PantallaCargando] dice que la informacion viene.
///   - [PantallaVacia] dice que ya llego y no hay nada que mostrar.
///   - [PantallaError] dice que no se pudo saber, y por eso trae un boton para
///     volver a intentarlo. Sin ese boton, un fallo de red deja la app muerta.
library;

import 'package:flutter/material.dart';

/// While the data is on its way.
///
/// A circular progress indicator, not a skeleton: the lists here are short and
/// a skeleton would take more code than the content it replaces.
class PantallaCargando extends StatelessWidget {
  final String mensaje;

  const PantallaCargando({super.key, this.mensaje = 'Cargando...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(mensaje, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// The list came back but there is nothing in it.
class PantallaVacia extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;

  /// Action at the bottom. Optional because some empty states are simply a
  /// dead end ("you have no orders yet") and a button there would be noise.
  final Widget? accion;

  const PantallaVacia({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: tema.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: tema.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (accion != null) ...[const SizedBox(height: 20), accion!],
          ],
        ),
      ),
    );
  }
}

/// The request failed, with a way to try again.
class PantallaError extends StatelessWidget {
  final String mensaje;
  final VoidCallback? alReintentar;

  /// Offer the "go to settings" action. Used when the failure is probably the
  /// URL: if the app cannot reach the backend, changing the URL is the fix, and
  /// hiding that behind a generic "try again" would send the user in circles.
  final VoidCallback? alConfigurarUrl;

  const PantallaError({
    super.key,
    required this.mensaje,
    this.alReintentar,
    this.alConfigurarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return PantallaVacia(
      icono: Icons.wifi_off_rounded,
      titulo: 'No pudimos conectarnos',
      mensaje: mensaje,
      accion: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alReintentar != null)
            FilledButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          if (alConfigurarUrl != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: alConfigurarUrl,
              icon: const Icon(Icons.settings_ethernet_rounded),
              label: const Text('Cambiar direccion del backend'),
            ),
          ],
        ],
      ),
    );
  }
}
