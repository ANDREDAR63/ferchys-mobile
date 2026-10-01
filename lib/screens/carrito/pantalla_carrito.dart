/// Carrito de compra, con el formulario para confirmar el pedido.
///
/// TRABAJA CON LOS DOS CARRILES DEL CARRITO. Si hay sesion, las líneas viven en
/// el servidor y cada cambio de cantidad se manda. Si no hay sesion, viven en
/// el dispositivo y se muestran igual. La diferencia se nota al pagar: el
/// checkout exige sesion, direccion y metodo de pago, asi que sin sesion el
/// boton lleva al login en vez de fallar.
///
/// EL TOTAL QUE SE MUESTRA ES UNA ESTIMACION. Se calcula con los precios del
/// catalogo, pero el que se cobra es el que calcula el backend al crear el
/// pedido. Cuando cambia, el backend devuelve el total real y la pantalla de
/// confirmacion muestra ese, no el que se habia calculado aqui.
///
/// EL PAGO NO ES REAL. El backend marca el pago como `approved` en el mismo
/// request que lo crea y de paso mueve el pedido a `preparing`. No hay pasarela
/// ni cobro, asi que el boton dice "Confirmar pedido" y no "Pagar": no tiene
/// sentido pedirle a alguien que confirme un cobro que no ocurre.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../modelos/carrito_item.dart';
import '../../modelos/direccion.dart';
import '../../modelos/pago.dart';
import '../../state/auth_provider.dart';
import '../../state/carrito_provider.dart';
import '../../state/pedidos_provider.dart';
import '../../utils/formateo.dart';
import '../../widgets/estados_pantalla.dart';
import '../../widgets/imagen_producto.dart';
import '../auth/pantalla_login.dart';
import 'pantalla_pedido_confirmado.dart';

class PantallaCarrito extends StatelessWidget {
  const PantallaCarrito({super.key});

  @override
  Widget build(BuildContext context) {
    final carrito = context.watch<CarritoProvider>();
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito'),
        actions: [
          if (!carrito.estaVacio)
            IconButton(
              onPressed: () => _vaciar(context),
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Vaciar carrito',
            ),
        ],
      ),
      body: carrito.estaVacio
          ? const PantallaVacia(
              icono: Icons.shopping_cart_outlined,
              titulo: 'Tu carrito esta vacio',
              mensaje:
                  'Agrega postres desde el catalogo para empezar un pedido.',
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: carrito.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (contexto, indice) =>
                        _FilaCarrito(item: carrito.items[indice]),
                  ),
                ),
                _BarraTotal(carrito: carrito, tema: tema),
              ],
            ),
    );
  }

  /// Pide confirmacion antes de vaciar: es la unica accion de esta pantalla que
  /// no se puede deshacer, porque el backend no guarda historial del carrito.
  Future<void> _vaciar(BuildContext context) async {
    final carrito = context.read<CarritoProvider>();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vaciar el carrito?'),
        content: const Text(
          'Se quitan todos los productos. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await carrito.vaciar();
    }
  }
}

/// Una linea del carrito, con su control de cantidad.
class _FilaCarrito extends StatelessWidget {
  final CarritoItem item;

  const _FilaCarrito({required this.item});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final carrito = context.read<CarritoProvider>();
    final producto = item.producto;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ImagenProducto(
              urlImagen: producto?.imagenUrl,
              nombreProducto: producto?.nombre,
              tamano: 64,
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto?.nombre ?? 'Producto',
                    style: tema.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatearMoneda(producto?.precio ?? 0),
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            _ControlCantidad(
              cantidad: item.cantidad,
              alCambiar: (valor) => carrito.cambiarCantidad(item, valor),
              alQuitar: () => carrito.quitar(item),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menos, la cantidad, mas y un papelera.
class _ControlCantidad extends StatelessWidget {
  final int cantidad;
  final ValueChanged<int> alCambiar;
  final VoidCallback alQuitar;

  const _ControlCantidad({
    required this.cantidad,
    required this.alCambiar,
    required this.alQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => alCambiar(cantidad - 1),
              // Bajar de 1 quita la linea, que es lo esperable: el boton "menos"
              // en un carrito vacio no puede dejar la cantidad en 0 para siempre.
              icon: const Icon(Icons.remove_circle_outline_rounded),
              visualDensity: VisualDensity.compact,
              tooltip: 'Quitar uno',
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$cantidad',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: cantidad < 99 ? () => alCambiar(cantidad + 1) : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
              visualDensity: VisualDensity.compact,
              tooltip: 'Agregar uno',
            ),
          ],
        ),
        TextButton.icon(
          onPressed: alQuitar,
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('Quitar'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Resumen con el total y el boton de continuar.
class _BarraTotal extends StatelessWidget {
  final CarritoProvider carrito;
  final ThemeData tema;

  const _BarraTotal({required this.carrito, required this.tema});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total estimado', style: tema.textTheme.titleSmall),
                Text(
                  formatearMoneda(carrito.totalEstimado),
                  style: tema.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'El total final lo calcula el servidor al confirmar.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _BotonContinuar(carrito: carrito),
          ],
        ),
      ),
    );
  }
}

/// El boton cambia de comportamiento segun haya sesion o no.
class _BotonContinuar extends StatelessWidget {
  final CarritoProvider carrito;

  const _BotonContinuar({required this.carrito});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pedidos = context.watch<PedidosProvider>();

    if (!auth.estaAutenticado) {
      return Column(
        children: [
          FilledButton(
            onPressed: () => _irAlLogin(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Iniciar sesion para pagar'),
          ),
          const SizedBox(height: 6),
          // Se avisa que el carrito se conserva, porque es la duda logique: si
          // al entrar se pierde lo que agrego, no sirve de nada el boton.
          const Text(
            'Tu carrito se conserva al iniciar sesion.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
    }

    return FilledButton(
      onPressed: pedidos.cargando ? null : () => _abrirCheckout(context),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: pedidos.cargando
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Continuar'),
    );
  }

  Future<void> _irAlLogin(BuildContext context) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PantallaLogin()));
  }

  Future<void> _abrirCheckout(BuildContext context) async {
    // El checkout necesita las direcciones y los metodos de pago, y se piden
    // solo cuando se entra: pedirlos al abrir el carrito haria una espera
    // inutil para quien solo va a mirar precios.
    final pedidos = context.read<PedidosProvider>();
    await pedidos.cargar();

    if (!context.mounted) return;

    if (pedidos.metodosPago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay metodos de pago configurados en el backend.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const HojaCheckout(),
    );
  }
}

/// Hoja inferior con direccion, metodo de pago y confirmacion.
class HojaCheckout extends StatefulWidget {
  const HojaCheckout({super.key});

  @override
  State<HojaCheckout> createState() => _HojaCheckoutState();
}

class _HojaCheckoutState extends State<HojaCheckout> {
  int? _direccionId;
  int? _metodoPagoId;

  @override
  void initState() {
    super.initState();

    // Se preselecciona lo que la web preselecciona: la direccion marcada como
    // principal y el primer metodo de pago. Obligar a elegir a mano cuando ya
    // hay una opcion obvia es friccion sin motivo.
    final pedidos = context.read<PedidosProvider>();
    _direccionId = pedidos.direccionSugerida?.id;
    _metodoPagoId = pedidos.metodosPago.isEmpty
        ? null
        : pedidos.metodosPago.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = context.watch<PedidosProvider>();
    final tema = Theme.of(context);
    final carrito = context.watch<CarritoProvider>();

    return Padding(
      // Se sube con el teclado abierto: sin este padding, el boton de
      // confirmar queda tapado por el teclado en pantallas cortas.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (contexto, controlador) {
          return ListView(
            controller: controlador,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tema.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('Confirmar pedido', style: tema.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${carrito.cantidadArticulos} articulos',
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),
              _SeccionDireccion(
                direcciones: pedidos.direcciones,
                seleccionada: _direccionId,
                alSeleccionar: (id) => setState(() => _direccionId = id),
              ),

              const SizedBox(height: 20),
              _SeccionMetodoPago(
                metodos: pedidos.metodosPago,
                seleccionado: _metodoPagoId,
                alSeleccionar: (id) => setState(() => _metodoPagoId = id),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tema.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total estimado', style: tema.textTheme.titleSmall),
                    Text(
                      formatearMoneda(carrito.totalEstimado),
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              if (pedidos.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  pedidos.error!,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.error,
                  ),
                ),
              ],

              const SizedBox(height: 20),
              FilledButton(
                onPressed: (_direccionId == null || _metodoPagoId == null)
                    ? null
                    : () => _confirmar(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: pedidos.cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmar pedido'),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmar(BuildContext context) async {
    final pedidos = context.read<PedidosProvider>();
    final carrito = context.read<CarritoProvider>();
    final navegador = Navigator.of(context);

    final pedido = await pedidos.confirmarPedido(
      direccionId: _direccionId!,
      metodoPagoId: _metodoPagoId!,
    );

    if (pedido == null) return;

    // Se vacia el carrito recien cuando el pedido se creo de verdad. Si el
    // pedido falla, vaciarlo seria tirar lo que la persona eligio.
    await carrito.vaciar();

    if (!context.mounted) return;

    navegador.pop();
    navegador.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PantallaPedidoConfirmado(pedido: pedido),
      ),
    );
  }
}

/// Selector de direccion, con opcion de agregar una nueva.
class _SeccionDireccion extends StatelessWidget {
  final List<Direccion> direcciones;
  final int? seleccionada;
  final ValueChanged<int> alSeleccionar;

  const _SeccionDireccion({
    required this.direcciones,
    required this.seleccionada,
    required this.alSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Direccion de entrega', style: tema.textTheme.titleSmall),
        const SizedBox(height: 8),

        if (direcciones.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tema.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No tienes direcciones guardadas. Agrega una para continuar.',
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onErrorContainer,
              ),
            ),
          )
        else
          // `RadioGroup` es el ancestro que maneja la seleccion desde Flutter
          // 3.32. Antes cada `RadioListTile` llevaba su propio `groupValue` y
          // `onChanged`, lo que obligaba a repetir el estado en cada fila.
          RadioGroup<int>(
            groupValue: seleccionada,
            onChanged: (id) {
              if (id != null) alSeleccionar(id);
            },
            child: Column(
              children: [
                for (final direccion in direcciones)
                  RadioListTile<int>(
                    value: direccion.id,
                    title: Text(direccion.etiqueta),
                    subtitle: Text(direccion.textoCompleto),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),

        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _agregarDireccion(context),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Agregar direccion'),
        ),
      ],
    );
  }

  /// Pide la direccion en un dialogo y la guarda.
  ///
  /// Se pide en un `AlertDialog` y no en otra pantalla porque son un solo
  /// campo: una pantalla completa para escribir una linea seria mucho.
  Future<void> _agregarDireccion(BuildContext context) async {
    final controlador = TextEditingController();
    final pedidos = context.read<PedidosProvider>();

    final texto = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva direccion'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Calle, numero, barrio',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controlador.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controlador.dispose();

    // `null` es "cancelado"; vacio es un error del backend que se muestra
    // como error en la pantalla, no como un dialogo nuevo.
    if (texto == null || texto.isEmpty) return;

    final direccion = await pedidos.agregarDireccion(direccionCompleta: texto);
    if (direccion != null) alSeleccionar(direccion.id);
  }
}

/// Selector del metodo de pago.
class _SeccionMetodoPago extends StatelessWidget {
  final List<MetodoPago> metodos;
  final int? seleccionado;
  final ValueChanged<int> alSeleccionar;

  const _SeccionMetodoPago({
    required this.metodos,
    required this.seleccionado,
    required this.alSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Metodo de pago', style: tema.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'No hay pasarela real: el servidor registra el pago y avanza el pedido.',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        RadioGroup<int>(
          groupValue: seleccionado,
          onChanged: (id) {
            if (id != null) alSeleccionar(id);
          },
          child: Column(
            children: [
              for (final metodo in metodos)
                RadioListTile<int>(
                  value: metodo.id,
                  title: Text(metodo.nombre),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
