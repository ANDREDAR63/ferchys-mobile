/// Punto de entrada de la app.
///
/// HAY TRES PANTALLAS DE ARRANQUE Y CADA UNA CORRESPONDE A UN ESTADO DISTINTO:
///
/// 1. [Bienvenida] mientras se confirma la sesion guardada contra `GET /me`.
/// 2. [PantallaLogin] si no hay sesion. Se entra ahi y no al catalogo porque el
///    invitado puede comprar hasta el ultimo paso, pero en un movil lo normal es
///    que la persona ya sepa que va a entrar a su cuenta.
/// 3. [ShellPrincipal] si la sesion esta vigente, ya con las pestanas de su rol.
///
/// [ConfigProvider] se arma ANTES de `runApp` y no dentro, por una razon concreta:
/// el `ClienteApi` que comparten todos los servicios nace con la URL y con el
/// token. Si se creara la URL despues, algun servicio podria haber lanzado
/// una peticion contra la URL por defecto del emulador mientras el usuario
/// estaba escribiendo la direccion real.
///
/// EL TOKEN NO SE PEGA ACA. Lo lee [AuthProvider.restaurarSesion] de disco y lo
/// confirma con el backend, porque un token guardado puede haber caducado o el
/// usuario puede haber sido desactivado mientras la app estaba cerrada.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth/pantalla_login.dart';
import 'screens/home/shell_principal.dart';
import 'servicios/servicio_autenticacion.dart';
import 'servicios/servicio_carrito.dart';
import 'servicios/servicio_catalogo.dart';
import 'servicios/servicio_dashboard.dart';
import 'servicios/servicio_pedidos.dart';
import 'state/auth_provider.dart';
import 'state/carrito_provider.dart';
import 'state/catalogo_provider.dart';
import 'state/config_provider.dart';
import 'state/dashboard_provider.dart';
import 'state/pedidos_provider.dart';
import 'utils/formateo.dart';

Future<void> main() async {
  // Debe ir antes de `runApp`: las pantallas ya formatean fechas y monedas en su
  // primer `build`, y sin el locale de `intl` la primera que se pintaria tiraria
  // una excepcion de formato.
  WidgetsFlutterBinding.ensureInitialized();
  await inicializarFormatos();

  final preferencias = await SharedPreferences.getInstance();
  final config = ConfigProvider(urlApiInicial: await leerUrlGuardada());

  runApp(FerchysApp(config: config, preferencias: preferencias));
}

class FerchysApp extends StatelessWidget {
  final ConfigProvider config;
  final SharedPreferences preferencias;

  const FerchysApp({
    super.key,
    required this.config,
    required this.preferencias,
  });

  @override
  Widget build(BuildContext context) {
    // Una sola instancia de [ClienteApi] para toda la app. Si cada servicio
    // tuviera la suya, cambiar la URL o el token habria que propagarlo a todas
    // y alguna se quedaria atras.
    final api = config.api;

    final autenticacion = ServicioAutenticacion(api);
    final catalogo = ServicioCatalogo(api);
    final carrito = ServicioCarrito(api);
    final pedidos = ServicioPedidos(api);
    final direcciones = ServicioDirecciones(api);
    final dashboard = ServicioDashboard(api);

    return MultiProvider(
      providers: [
        // `.value` porque el provider ya existe y tiene estado: volver a
        // crearlo en cada `build` borraria la URL que el usuario acaba de
        // cambiar en la pantalla de configuracion.
        ChangeNotifierProvider<ConfigProvider>.value(value: config),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(servicio: autenticacion, api: api)
            // Se lanza aqui y no con un boton de "continuar": si el token
            // guardado sirve, no hay nada que decidir. Si no, `AuthProvider`
            // queda sin usuario y la app cae en el login por su cuenta.
            ..restaurarSesion(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CarritoProvider>(
          create: (_) =>
              CarritoProvider(servicio: carrito, preferencias: preferencias),
          // El carrito cambia de carril segun haya sesion o no, asi que no
          // puede vivir suelto: depende del estado de autenticacion.
          //
          // `recienIngreso` se compara con un contador, y no con "estaba
          // autenticado antes", porque en un `update` no siempre se sabe como
          // estaba. El carrito solo fusiona en un ingreso manual: si se
          // fusionara en cada cambio, un producto ya subido volveria a subirse.
          update: (_, auth, carritoExistente) {
            carritoExistente!.definirAutenticado(
              auth.estaAutenticado,
              ingresos: auth.ingresos,
            );
            return carritoExistente;
          },
        ),
        ChangeNotifierProvider<CatalogoProvider>(
          create: (_) => CatalogoProvider(servicio: catalogo),
        ),
        ChangeNotifierProvider<PedidosProvider>(
          create: (_) =>
              PedidosProvider(pedidos: pedidos, direcciones: direcciones),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(
            dashboard: dashboard,
            pedidos: pedidos,
            catalogo: catalogo,
            api: api,
          ),
        ),
      ],
      child: MaterialApp(
        title: "Ferchy's Postres",
        debugShowCheckedModeBanner: false,
        theme: TemaFerchys.claro,
        darkTheme: TemaFerchys.oscuro,
        home: const _Arranque(),
      ),
    );
  }
}

/// Decide que pantalla se muestra, segun haya sesion o no.
class _Arranque extends StatelessWidget {
  const _Arranque();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Mientras se confirma el token guardado no se decide nada. Mostrar el login
    // durante ese instante y cambiarlo despues a la pantalla del rol produce un
    // parpadeo que el usuario lee como un fallo.
    if (auth.cargando) return const Bienvenida();

    if (!auth.estaAutenticado) return const PantallaLogin();

    return const ShellPrincipal();
  }
}

/// Pantalla de espera mientras se restaura la sesion.
class Bienvenida extends StatelessWidget {
  const Bienvenida({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cake_rounded, size: 72, color: tema.colorScheme.primary),
            const SizedBox(height: 16),
            Text("Ferchy's Postres", style: tema.textTheme.headlineSmall),
            const SizedBox(height: 24),
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colores y tipografia de la app.
///
/// LA PALETA CLARA SALE TAL CUAL DE `index.css` DEL SITIO WEB, no de un color
/// semilla. `ColorScheme.fromSeed` genera una paleta coherente pero con
/// superficies y textos propios (grises lavados) que no son los del sitio, y el
/// resultado se veia apagado al lado del rosa fresa y el blanco de la web. Por
/// eso el modo claro arranca de `fromSeed` y luego se sobreescriben los papeles
/// que importan con los valores exactos del CSS.
///
/// EL MODO OSCURO NO SE TOCA. Sigue con el color semilla original y sin
/// overrides, tal como estaba, para no cambiar lo que ya se veia bien.
class TemaFerchys {
  const TemaFerchys._();

  // Paleta de `WEB-FERCHYS/frontend/src/index.css`.
  static const Color rosaFresa = Color(0xFFEE74A5);
  static const Color rosaTierno = Color(0xFFFDE8F0);
  static const Color chocolate = Color(0xFF804F5D);
  static const Color textoSuave = Color(0xFF6B584C);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color grisSuave = Color(0xFFF9F6F7);

  /// rgba(212,163,115,0.15): el borde calido de las tarjetas del sitio.
  static const Color bordeCalido = Color(0x26D4A373);

  /// Semilla del modo oscuro. Es el rosa Material original, no el del sitio, a
  /// proposito: asi el oscuro queda identico al que ya estaba.
  static const Color rosaOscuro = Color(0xFFE91E63);

  static ThemeData get claro => _construirClaro();
  static ThemeData get oscuro => _construirOscuro();

  static ThemeData _construirClaro() {
    final esquema =
        ColorScheme.fromSeed(
          seedColor: rosaFresa,
          brightness: Brightness.light,
        ).copyWith(
          primary: rosaFresa,
          onPrimary: blanco,
          primaryContainer: rosaTierno,
          onPrimaryContainer: chocolate,
          secondary: rosaFresa,
          onSecondary: blanco,
          secondaryContainer: rosaTierno,
          onSecondaryContainer: chocolate,
          surface: blanco,
          onSurface: chocolate,
          surfaceContainerHighest: grisSuave,
          onSurfaceVariant: textoSuave,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      // El fondo del sitio es blanco puro (index.css: `--color-claro`).
      scaffoldBackgroundColor: blanco,
      // La barra del web es blanca con texto chocolate y acentos rosa, no un
      // bloque rosa relleno.
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: blanco,
        foregroundColor: chocolate,
        iconTheme: IconThemeData(color: chocolate),
        actionsIconTheme: IconThemeData(color: rosaFresa),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // Tarjetas blancas, radio 12 y borde calido, como `.card-postre`.
      cardTheme: CardThemeData(
        color: blanco,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: bordeCalido),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: blanco,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: rosaFresa,
          foregroundColor: blanco,
          // Alto de 48: es el minimo que las guias ergonomicas piden para
          // que el boton se pueda pulsar sin mirar.
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }

  static ThemeData _construirOscuro() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: rosaOscuro,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: rosaOscuro,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }
}
