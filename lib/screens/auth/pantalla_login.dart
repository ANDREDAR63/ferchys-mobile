/// Pantalla de inicio de sesion.
///
/// Es la primera pantalla que ve cualquiera que no tenga sesion, asi que esta
/// pensada para ser rapida de entender: un campo de correo, uno de contrasena y
/// un boton. Todo lo demas esta escondido detras de "Crear cuenta".
///
/// LOS ERRORES VIENEN DEL PROVIDER, NO DE AQUI. `AuthProvider` guarda el
/// ultimo fallo de autenticacion, asi que esta pantalla solo lo muestra. La
/// razon es que el mismo error tiene que verse igual aca y en el registro, y
/// duplicar el `try/catch` en dos pantallas es la forma facil de que los
/// mensajes se vean distintos entre si.
///
/// El campo de contrasena tiene un ojo para alternar entre visible y oculta:
/// en un celular es comun teclear mal una contrasena, y no poder leerla es la
/// forma mas rapida de descubrir el error.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';
import '../../state/config_provider.dart';
import '../configuracion/pantalla_configuracion_url.dart';
import 'pantalla_registro.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();

  /// Oculta la contrasena al entrar. Enseñar el punto de entrada mientras se
  /// escribe es una decision de cada pantalla, no del tema.
  bool _mostrarContrasena = false;

  /// Marca que se esta abriendo el registro, para deshabilitar el boton
  /// mientras navega y evitar un doble toque.
  bool _abriendoRegistro = false;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final auth = context.read<AuthProvider>();

    final exito = await auth.iniciarSesion(
      correo: _correo.text.trim(),
      contrasena: _contrasena.text,
    );

    // Si la pantalla ya no esta montada (la persona salio mientras esperaba),
    // no hay que tocar nada mas: el provider ya guardo el estado.
    if (!mounted || !exito) return;

    // No se navega a ninguna parte a proposito: `main.dart` decide la pantalla
    // inicial segun el rol apenas cambia la sesion. Si esta pantalla empujara
    // el dashboard, el rol se comprobaria en dos sitios distintos.
  }

  Future<void> _abrirRegistro() async {
    _abriendoRegistro = true;
    context.read<AuthProvider>().limpiarError();

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PantallaRegistro()));

    // Al volver hay que dejar el estado como estaba.
    if (!mounted) return;
    setState(() => _abriendoRegistro = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tema = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // Limita el ancho en tablet: un formulario estirado a 900 pixeles
              // es incomodo de leer y de escribir.
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EncabezadoFerchys(tema: tema),
                    const SizedBox(height: 32),

                    TextField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        // Escribir borra el error anterior: si sigue visible
                        // mientras se corrige, parece que el boton no responde.
                        if (auth.error != null) auth.limpiarError();
                      },
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _contrasena,
                      obscureText: !_mostrarContrasena,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Contrasena',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(
                              () => _mostrarContrasena = !_mostrarContrasena,
                            );
                          },
                          icon: Icon(
                            _mostrarContrasena
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          tooltip: _mostrarContrasena ? 'Ocultar' : 'Mostrar',
                        ),
                      ),
                      onChanged: (_) {
                        if (auth.error != null) auth.limpiarError();
                      },
                      onSubmitted: (_) => _entrar(),
                    ),

                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      _CajaError(mensaje: auth.error!),
                    ],

                    const SizedBox(height: 24),
                    FilledButton(
                      // Se deshabilita mientras carga para que un doble toque
                      // no dispare dos peticiones de login.
                      onPressed: auth.cargando || _abriendoRegistro
                          ? null
                          : _entrar,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: auth.cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Entrar'),
                    ),

                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: auth.cargando ? null : _abrirRegistro,
                      child: const Text('Crear una cuenta'),
                    ),

                    const SizedBox(height: 24),
                    const _EnlaceConfiguracionUrl(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo y nombre, arriba de todo.
class _EncabezadoFerchys extends StatelessWidget {
  final ThemeData tema;

  const _EncabezadoFerchys({required this.tema});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sin asset: un icono con el color del tema hace el mismo papel que una
        // imagen y no agrega un archivo binario al repositorio.
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: tema.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cake_rounded,
            size: 48,
            color: tema.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ferchy\'s Postres',
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Dulces hechos para ti',
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Caja roja con el mensaje del backend.
///
/// Se usa el color de error del tema en vez de un rojo fijo, para que respete
/// el modo oscuro sin tener que mantener dos versiones del widget.
class _CajaError extends StatelessWidget {
  final String mensaje;

  const _CajaError({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: tema.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acceso a la configuracion de la URL.
///
/// Esta en el login a proposito: si la URL esta mal, el primer sintoma es que
/// el boton "Entrar" no responde, y sin este enlace la unica salida seria
/// reinstalar la app.
class _EnlaceConfiguracionUrl extends StatelessWidget {
  const _EnlaceConfiguracionUrl();

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();

    return Column(
      children: [
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const PantallaConfiguracionUrl(mostrarBotonCerrar: true),
              ),
            );
          },
          icon: const Icon(Icons.settings_ethernet_rounded, size: 18),
          label: const Text('Cambiar direccion del backend'),
        ),
        const SizedBox(height: 4),
        // Se muestra a que servidor esta conectada la app. Con redes publicas
        // y tuneles, es la duda mas comun: "no sera que estoy viendo los
        // datos de otra persona".
        Text(
          'Conectado a: ${config.urlApi}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
