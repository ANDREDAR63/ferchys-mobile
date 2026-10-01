/// Armazon de la app: decide que se ve segun quien entro y sostiene la navegacion.
///
/// UNA SOLA PANTALLA CON PESTANAS, Y NO UNA POR ROL. Las cuatro pantallas con las
/// que se trabaja (catalogo, pedidos, panel y carrito) comparten el mismo
/// esqueleto de abajo, y lo que cambia entre un admin y un repartidor no es la
/// forma sino el contenido. Armar un `Scaffold` distinto para cada rol
/// duplicaria la barra inferior y el manejo del carrito, y en cuanto una de las
/// copias necesitara un cambio, las dos se desfasarian.
///
/// LAS PESTANAS DEPENDEN DEL ROL Y NO AL REVES. El backend es quien decide a que
/// puede entrar cada uno, asi que aca no se ocultan funciones: se muestra lo que
/// le corresponde a ese rol y ya. Un admin ve el panel, la cocina ve lo que
/// tiene que cocinar, el repartidor lo que tiene que llevar, y el cliente o el
/// invitado ven el catalogo.
///
/// LOS INVITADOS PUEDEN COMPRAR HASTA EL ULTIMO PASO, IGUAL QUE EN LA WEB. Por
/// eso el catalogo y el carrito no piden sesion; la peticion de inicio de sesion
/// se hace recien en el checkout. El carrito invitado vive en disco y se fusiona
/// con el del servidor en cuanto la persona entra.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../modelos/usuario.dart';
import '../../state/auth_provider.dart';
import '../../state/carrito_provider.dart';
import '../carrito/pantalla_carrito.dart';
import '../catalogo/pantalla_catalogo.dart';
import '../dashboard/dashboard_admin.dart';
import '../dashboard/pantallas_operativas.dart';
import '../pedidos/pantalla_pedidos.dart';

/// La app ya montada, una vez que se sabe si hay sesion.
class ShellPrincipal extends StatefulWidget {
  const ShellPrincipal({super.key});

  @override
  State<ShellPrincipal> createState() => _ShellPrincipalState();
}

class _ShellPrincipalState extends State<ShellPrincipal> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    // Se mira al usuario, no al estado de carga: mientras se restaura la sesion
    // [AuthProvider.cargando] esta en falso todavia, y esperar a el dejaria
    // mostrar la pantalla de bienvenida un instante de mas sin ningun ganho.
    final usuario = context.watch<AuthProvider>().usuario;

    final pestanas = _pestanasDe(usuario?.rol);

    // Si el rol cambia mientras la app esta abierta (por ejemplo, al iniciar
    // sesion un invitado pasa a tener pestanas nuevas), el indice podria quedar
    // fuera de rango y mostrar una pantalla en blanco.
    if (_indice >= pestanas.length) _indice = 0;

    // Se busca por etiqueta y no por posicion fija porque el numero de pestanas
    // cambia segun el rol, y con el rol cambia la posicion del carrito.
    final indiceCarrito = pestanas.indexWhere(
      (pestana) => pestana.etiqueta == 'Carrito',
    );

    return Scaffold(
      body: IndexedStack(
        index: _indice,
        // `IndexedStack` y no un `switch`: mantiene vivas las pestanas ya
        // vistas, asi el filtro de categoria del catalogo o el scroll del
        // carrito no se pierden al ir y volver.
        children: [for (final pestana in pestanas) pestana.pantalla],
      ),
      bottomNavigationBar: _BarraInferior(
        pestanas: pestanas,
        indice: _indice,
        indiceCarrito: indiceCarrito,
        alElegir: (indice) => setState(() => _indice = indice),
        autenticado: usuario != null,
      ),
    );
  }

  /// Las pestanas que le tocan a [rol], en orden.
  ///
  /// Para el staff es una sola: su trabajo es una unica cola de pedidos, y
  /// ponerle una barra con tres opciones lo unico que hace es darle algo que
  /// pulsar para equivocarse.
  List<_Pestana> _pestanasDe(String? rol) {
    if (rol == Usuario.rolAdmin) {
      return const [
        _Pestana('Panel', Icons.dashboard_rounded, DashboardAdmin()),
      ];
    }

    if (rol == Usuario.rolCocinero) {
      return const [
        _Pestana('Cocina', Icons.soup_kitchen_outlined, PantallaCocina()),
      ];
    }

    if (rol == Usuario.rolRepartidor) {
      return const [
        _Pestana(
          'Repartos',
          Icons.delivery_dining_outlined,
          PantallaRepartidor(),
        ),
      ];
    }

    // Cliente e invitado comparten el mismo catalogo. El historial de pedidos
    // solo existe con sesion, porque sin token el backend no sabe de quien
    // son los pedidos que hay que mostrar.
    return [
      const _Pestana('Catalogo', Icons.storefront_outlined, PantallaCatalogo()),
      if (rol != null)
        const _Pestana(
          'Pedidos',
          Icons.receipt_long_outlined,
          PantallaPedidos(),
        ),
      const _Pestana(
        'Carrito',
        Icons.shopping_cart_outlined,
        PantallaCarrito(),
      ),
    ];
  }
}

/// Una pestana de la barra inferior.
class _Pestana {
  final String etiqueta;
  final IconData icono;
  final Widget pantalla;

  const _Pestana(this.etiqueta, this.icono, this.pantalla);
}

/// Barra inferior con las pestanas y, si hay sesion, el boton de salir.
class _BarraInferior extends StatelessWidget {
  final List<_Pestana> pestanas;
  final int indice;
  final int indiceCarrito;
  final ValueChanged<int> alElegir;
  final bool autenticado;

  const _BarraInferior({
    required this.pestanas,
    required this.indice,
    required this.indiceCarrito,
    required this.alElegir,
    required this.autenticado,
  });

  @override
  Widget build(BuildContext context) {
    // El numero del carrito sale de [CarritoProvider.cantidadArticulos], que
    // suma unidades y no lineas: con "2 x Profiteroles" el badge dice 2, que es
    // lo que la persona espera ver.
    //
    // Se lee una sola vez aca y no dentro de cada boton porque `context.select`
    // tiene que usarse siempre el mismo numero de veces por `build`. Llamarlo
    // solo cuando la pestana es el carrito haria que el numero de suscripciones
    // cambiara al cambiar de rol, que es justo cuando mas daño hace.
    final articulos = context.select<CarritoProvider, int>(
      (carrito) => carrito.cantidadArticulos,
    );

    return BottomAppBar(
      child: Row(
        children: [
          for (var i = 0; i < pestanas.length; i++)
            Expanded(
              child: _boton(context, i, i == indiceCarrito ? articulos : 0),
            ),
          if (autenticado) ...[
            const VerticalDivider(width: 1, indent: 12, endIndent: 12),
            _BotonSalir(alSalir: () => _confirmarSalida(context)),
          ],
        ],
      ),
    );
  }

  Widget _boton(BuildContext context, int i, int articulos) {
    final pestana = pestanas[i];
    final seleccionada = i == indice;
    final tema = Theme.of(context);

    return InkWell(
      onTap: () => alElegir(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: articulos > 0,
              label: Text('$articulos'),
              child: Icon(
                pestana.icono,
                color: seleccionada ? tema.colorScheme.primary : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              pestana.etiqueta,
              style: tema.textTheme.labelSmall?.copyWith(
                color: seleccionada ? tema.colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cierra la sesion, pidiendo confirmacion solo cuando hay algo que perder.
  ///
  /// Cerrar sesion vacia el carrito guardado en el servidor, y hacerlo sin
  /// querer borraria lo que la persona estaba por pagar. Ese riesgo es del
  /// cliente: el admin, la cocina y el reparto no compran ni tienen carrito, y
  /// frenarles la salida con un aviso sobre un carrito que no usan no tendria
  /// sentido. Por eso el aviso es solo para el cliente; los demas salen directo.
  Future<void> _confirmarSalida(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final usuario = auth.usuario;

    if (usuario != null && !usuario.esCliente) {
      await auth.cerrarSesion();
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Cerrar sesion'),
        content: const Text(
          'Tu carrito guardado se perderá. Si ya pagaste, tu pedido sigue en marcha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmado == true) await auth.cerrarSesion();
  }
}

/// Boton de cerrar sesion al final de la barra.
class _BotonSalir extends StatelessWidget {
  final VoidCallback alSalir;

  const _BotonSalir({required this.alSalir});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InkWell(
        onTap: alSalir,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout_rounded, color: tema.colorScheme.primary),
            const SizedBox(height: 2),
            Text('Salir', style: tema.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
