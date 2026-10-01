/// Pruebas de las reglas del carrito y de la cola de pedidos.
///
/// LO QUE SE PRUEBA ACA NO ES EL DIBUJO, SINO LAS DOS COSAS QUE SI ROMPEN UN
/// CARRITO:
///
/// 1. La cantidad. El boton de "mas" manda la cantidad FINAL que se quiere, no
///    un incremento. Si se sumara, una linea de 2 unidades saltaria a 4 con un
///    solo toque y la persona terminaria pagando el doble.
/// 2. La fusion. Subir el carrito de invitado al servidor no se puede repetir.
///    Si un producto ya subido volviera a subirse, apareceria duplicado.
///
/// Los servicios se falsean en vez de golpear el backend: estas pruebas corren
/// sin servidor, y lo que interesa es la logica del provider, no el HTTP.
library;

import 'package:ferchys_mobile/app_config.dart';
import 'package:ferchys_mobile/modelos/carrito_item.dart';
import 'package:ferchys_mobile/modelos/direccion.dart';
import 'package:ferchys_mobile/modelos/pago.dart';
import 'package:ferchys_mobile/modelos/pedido.dart';
import 'package:ferchys_mobile/modelos/producto.dart';
import 'package:ferchys_mobile/servicios/cliente_api.dart';
import 'package:ferchys_mobile/servicios/servicio_carrito.dart';
import 'package:ferchys_mobile/servicios/servicio_pedidos.dart';
import 'package:ferchys_mobile/state/carrito_provider.dart';
import 'package:ferchys_mobile/state/pedidos_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CarritoProvider como invitado', () {
    test('fijar la cantidad reemplaza y no suma', () async {
      final preferencias = await _preferenciasVacias();
      final carrito = CarritoProvider(
        servicio: _CarritoFalso(),
        preferencias: preferencias,
      );

      await carrito.definirAutenticado(false, ingresos: 0);
      await carrito.agregar(_producto(1), cantidad: 2);

      // La linea tiene 2. El boton de "mas" pide 3, no "sumar 3".
      await carrito.cambiarCantidad(carrito.items.first, 3);

      expect(carrito.items.single.cantidad, 3);
      expect(carrito.cantidadArticulos, 3);
    });

    test(
      'bajar a cero quita la linea, como espera el boton de restar',
      () async {
        final carrito = CarritoProvider(
          servicio: _CarritoFalso(),
          preferencias: await _preferenciasVacias(),
        );

        await carrito.definirAutenticado(false, ingresos: 0);
        await carrito.agregar(_producto(1), cantidad: 1);
        await carrito.cambiarCantidad(carrito.items.first, 0);

        expect(carrito.estaVacio, isTrue);
      },
    );

    test('el carrito de invitado sobrevive a reiniciar la app', () async {
      final preferencias = await _preferenciasVacias();
      final servicio = _CarritoFalso();

      final primero = CarritoProvider(
        servicio: servicio,
        preferencias: preferencias,
      );
      await primero.definirAutenticado(false, ingresos: 0);
      await primero.agregar(_producto(7), cantidad: 3);

      // Instancia nueva sobre las mismas preferencias: es lo que pasa al
      // abrir la app otra vez.
      final segundo = CarritoProvider(
        servicio: servicio,
        preferencias: preferencias,
      );
      await segundo.definirAutenticado(false, ingresos: 0);

      expect(segundo.items.single.productoId, 7);
      expect(segundo.items.single.cantidad, 3);
    });

    test(
      'un carrito guardado corrupto se descarta en vez de romper el arranque',
      () async {
        final preferencias = await _preferenciasVacias();
        await preferencias.setString(
          ClavesAlmacenamiento.carritoInvitado,
          '{roto',
        );

        final carrito = CarritoProvider(
          servicio: _CarritoFalso(),
          preferencias: preferencias,
        );
        await carrito.definirAutenticado(false, ingresos: 0);

        expect(carrito.estaVacio, isTrue);
      },
    );
  });

  group('CarritoProvider al iniciar sesion', () {
    test('sube el carrito de invitado y borra el local', () async {
      final preferencias = await _preferenciasVacias();
      final servicio = _CarritoFalso();

      final invitado = CarritoProvider(
        servicio: servicio,
        preferencias: preferencias,
      );
      await invitado.definirAutenticado(false, ingresos: 0);
      await invitado.agregar(_producto(4), cantidad: 2);

      final conSesion = CarritoProvider(
        servicio: servicio,
        preferencias: preferencias,
      );
      await conSesion.definirAutenticado(true, ingresos: 1);

      expect(servicio.agregados, [
        [4, 2],
      ]);
      expect(
        preferencias.getString(ClavesAlmacenamiento.carritoInvitado),
        isNull,
        reason: 'el carrito local ya esta en el servidor, dejarlo duplica al reiniciar',
      );
    });

    test('el mismo ingreso no fusiona dos veces', () async {
      final preferencias = await _preferenciasVacias();
      final servicio = _CarritoFalso();

      final carrito = CarritoProvider(
        servicio: servicio,
        preferencias: preferencias,
      );
      await carrito.definirAutenticado(false, ingresos: 0);
      await carrito.agregar(_producto(4), cantidad: 1);

      // Se pasa el mismo numero de ingreso varias veces, que es lo que pasa
      // cuando la autenticacion notifica varias veces seguidas.
      await carrito.definirAutenticado(true, ingresos: 1);
      await carrito.definirAutenticado(true, ingresos: 1);
      await carrito.definirAutenticado(true, ingresos: 1);

      expect(
        servicio.agregados.where((item) => item.first == 4).length,
        1,
        reason: 'subir dos veces el mismo producto lo deja duplicado en el servidor',
      );
    });

    test(
      'volver a cargar sin cambiar de carril no vuelve a pedir la lista',
      () async {
        final servicio = _CarritoFalso();

        final carrito = CarritoProvider(
          servicio: servicio,
          preferencias: await _preferenciasVacias(),
        );
        await carrito.definirAutenticado(true, ingresos: 1);
        await carrito.definirAutenticado(true, ingresos: 1);

        expect(servicio.lecturas, 1);
      },
    );

    test('cerrar sesion devuelve al carril de invitado', () async {
      final servicio = _CarritoFalso();

      final carrito = CarritoProvider(
        servicio: servicio,
        preferencias: await _preferenciasVacias(),
      );
      await carrito.definirAutenticado(true, ingresos: 1);
      await carrito.definirAutenticado(false, ingresos: 1);

      expect(servicio.agregados, isEmpty);
    });
  });

  group('PedidosProvider', () {
    test('la cocina solo ve lo que tiene que cocinar', () async {
      final pedidos = _PedidosFalso(
        pedidos: [
          _pedido(1, PedidoEstados.pendiente),
          _pedido(2, PedidoEstados.enPreparacion),
          _pedido(3, PedidoEstados.enCamino),
          _pedido(4, PedidoEstados.entregado),
        ],
      );
      final estado = PedidosProvider(
        pedidos: pedidos,
        direcciones: _DireccionesFalso(),
      );

      await estado.cargar();

      expect(estado.pendientesDeCocina().map((p) => p.id), [1, 2]);
    });

    test('el repartidor solo ve lo que tiene que llevar', () async {
      final pedidos = _PedidosFalso(
        pedidos: [
          _pedido(1, PedidoEstados.pendiente),
          _pedido(2, PedidoEstados.enCamino),
          _pedido(3, PedidoEstados.entregado),
        ],
      );
      final estado = PedidosProvider(
        pedidos: pedidos,
        direcciones: ServicioDirecciones(_apiFalsa()),
      );

      await estado.cargar();

      expect(estado.listosParaEntregar().map((p) => p.id), [2]);
    });

    test('tras pagar, devuelve el pedido con el estado ya avanzado', () async {
      final pagos = _PedidosFalso(
        pedidos: [_pedido(5, PedidoEstados.pendiente)],
      );

      final estado = PedidosProvider(
        pedidos: pagos,
        direcciones: ServicioDirecciones(_apiFalsa()),
      );

      final confirmado = await estado.confirmarPedido(
        direccionId: 1,
        metodoPagoId: 2,
      );

      // El backend mueve el pedido a "preparacion" al registrar el pago. Si se
      // devolviera el objeto creado antes de pagar, la pantalla de confirmacion
      // mostraria "pendiente" y pareceria que el pago no se registro.
      expect(confirmado!.estado, PedidoEstados.enPreparacion);
    });

    test('si el pago falla no se devuelve ningun pedido', () async {
      final pedidos = _PedidosFalso(
        pedidos: [_pedido(6, PedidoEstados.pendiente)],
        fallaElPago: true,
      );
      final estado = PedidosProvider(
        pedidos: pedidos,
        direcciones: ServicioDirecciones(_apiFalsa()),
      );

      final confirmado = await estado.confirmarPedido(
        direccionId: 1,
        metodoPagoId: 2,
      );

      expect(confirmado, isNull);
      expect(estado.error, isNotNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Ayudas para armar el escenario
// ---------------------------------------------------------------------------

/// Direcciones falsas.
///
/// [PedidosProvider.cargar] pide tambien las direcciones para poder mostrar el
/// punto de entrega. Sin esta pantalla, la peticion real fallaria y el provider
/// abortaria antes de dejar los pedidos cargados, que es justo lo que estas
/// pruebas quieren verificar.
class _DireccionesFalso extends ServicioDirecciones {
  _DireccionesFalso() : super(_apiFalsa());

  @override
  Future<List<Direccion>> obtenerDirecciones() async => const [
    Direccion(id: 1, direccionCompleta: 'Calle 1 #2-3', esPredeterminada: true),
  ];
}

/// Cliente HTTP de mentira.
///
/// Se construye uno solo para que los servicios falsos queden bien tipados. No
/// se usa para nada: todos los metodos que las pruebas ejercitan estan
/// sobreescritos, asi que si alguno se escapara, fallaria al no encontrar host
/// en vez de colarse a una peticion real.
ClienteApi _apiFalsa() => ClienteApi(urlBase: 'http://localhost/api');

Future<SharedPreferences> _preferenciasVacias() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Producto _producto(int id) {
  return Producto(
    id: id,
    nombre: 'Producto $id',
    descripcion: 'De prueba',
    precio: 5000,
    categoriaId: 1,
    imagenUrl: null,
    activo: true,
  );
}

Pedido _pedido(int id, String estado) {
  return Pedido(id: id, total: 5000, estado: estado);
}

/// Carrito falso: guarda lo que se le pidio y responde con una lista fija.
class _CarritoFalso extends ServicioCarrito {
  /// Pares `[productoId, cantidad]` de cada llamada a `agregarProducto`.
  final List<List<int>> agregados = [];

  /// Cuantas veces se leyo el carrito del servidor.
  int lecturas = 0;

  _CarritoFalso() : super(_apiFalsa());

  @override
  Future<List<CarritoItem>> obtenerCarrito() async {
    lecturas++;
    return [
      for (final item in agregados)
        CarritoItem(
          id: 'server-${item.first}',
          productoId: item.first,
          cantidad: item.last,
        ),
    ];
  }

  @override
  Future<CarritoItem> agregarProducto(int productoId, int cantidad) async {
    agregados.add([productoId, cantidad]);
    return CarritoItem(
      id: 'server-$productoId',
      productoId: productoId,
      cantidad: cantidad,
    );
  }
}

/// Pedidos falsos: `crearPedido` devuelve pendiente y `registrarPago` lo pasa a
/// preparacion, igual que el backend.
class _PedidosFalso extends ServicioPedidos {
  final List<Pedido> pedidos;
  final bool fallaElPago;

  _PedidosFalso({required this.pedidos, this.fallaElPago = false})
    : super(_apiFalsa());

  @override
  Future<List<Pedido>> obtenerPedidos() async => pedidos;

  @override
  Future<List<MetodoPago>> obtenerMetodosPago() async => const [
    MetodoPago(id: 1, nombre: 'Efectivo'),
  ];

  @override
  Future<Pedido> obtenerPedido(int id) async {
    return pedidos.firstWhere(
      (pedido) => pedido.id == id,
      orElse: () => _pedido(id, PedidoEstados.enPreparacion),
    );
  }

  @override
  Future<Pedido> crearPedido({required int direccionId}) async {
    return _pedido(99, PedidoEstados.pendiente);
  }

  @override
  Future<Pago> registrarPago({
    required int pedidoId,
    required int metodoPagoId,
  }) async {
    if (fallaElPago) {
      throw Exception('El metodo de pago fue rechazado');
    }

    // El servidor ya no devuelve el pedido actualizado, asi que la lista local
    // tampoco se toca: la pantalla tendra que volver a pedirlo.
    return Pago(id: 1, pedidoId: pedidoId, monto: 5000, estado: 'approved');
  }
}
