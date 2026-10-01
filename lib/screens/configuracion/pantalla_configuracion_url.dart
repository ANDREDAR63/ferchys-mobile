/// Pantalla para escribir la direccion del backend.
///
/// ESTA PANTALLA ES LA MAS IMPORTANTE DE LA APP Y NO PARECE. Sin la URL correcta
/// no hay catalogo, no hay login y no hay nada, y la causa numero uno de "la
/// app no me carga" es que la URL apunta al lugar equivocado. Por eso se puede
/// abrir desde el boton de "Cambiar direccion" del estado de error, sin tener
/// que cerrar sesion ni borrar datos.
///
/// LA URL SE ESCRIBE A MANO Y NO SE ADIVINA. Cada persona apunta a un sitio
/// distinto y adivinar la IP desde la que llega el servidor daria un error
/// intermitente, porque la IP publica de un celular cambia cada vez que el wifi
/// se reconecta. Escribirla una vez es mas tedioso, pero funciona siempre.
///
/// POR ESO HAY UN BOTON DE "PROBAR CONEXION". El fallo clasico de esta pantalla
/// no es escribir mal la URL, es no darse cuenta de que la URL esta bien escrita
/// pero no lleva a ningun lado. El sintoma aparece 20 segundos despues, en otra
/// pantalla, como un "el servidor tardo demasiado" que no dice que URL se uso.
/// Probar contra `/up` responde en 5 segundos y separa "no hay servidor ahi" de
/// "el servidor esta caido" de "todo bien".
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_config.dart';
import '../../servicios/cliente_api.dart';
import '../../state/config_provider.dart';

class PantallaConfiguracionUrl extends StatefulWidget {
  /// Se usa como titulo de la pantalla. Cuando se abre desde el error de
  /// conexion se ofrece "cerrar" para volver a donde estabas.
  final bool mostrarBotonCerrar;

  const PantallaConfiguracionUrl({super.key, this.mostrarBotonCerrar = false});

  @override
  State<PantallaConfiguracionUrl> createState() =>
      _PantallaConfiguracionUrlState();
}

class _PantallaConfiguracionUrlState extends State<PantallaConfiguracionUrl> {
  late final TextEditingController _controlador;
  String? _error;

  /// Resultado de la ultima prueba de conexion, o `null` si no se probo.
  String? _resultadoPrueba;

  /// Si el resultado anterior fue un fallo, para pintarlo de rojo.
  bool _pruebaFallida = false;

  bool _probando = false;

  @override
  void initState() {
    super.initState();

    // Se parte de la URL ya guardada para no obligar a reescribirla en cada
    // visita. `late final` + initState es el momento exacto en que el
    // provider ya esta disponible para leer.
    _controlador = TextEditingController(
      text: context.read<ConfigProvider>().urlApi,
    );
  }

  @override
  void dispose() {
    // Sin esto el `TextEditingController` queda vivo y puede fugar memoria al
    // salir de la pantalla.
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final config = context.read<ConfigProvider>();

    final error = await config.guardarUrl(_controlador.text);

    if (!mounted) return;

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() => _error = null);

    // Solo se avisa con un `SnackBar` si la pantalla se abrio como ajuste
    // (no como error): si venia del error, la persona quiere volver al
    // catalogo, no quedarse leyendo un mensaje.
    if (!widget.mostrarBotonCerrar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Direccion del backend guardada')),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Pone una URL de ejemplo en el campo sin guardarla todavia.
  void _usarEjemplo(String url) {
    _controlador.text = url;
    setState(() {
      _error = null;
      // El resultado viejo ya no dice nada del contenido del campo: se limpia
      // para que nadie lea "funciona" sobre una URL que todavia no se probo.
      _resultadoPrueba = null;
      _pruebaFallida = false;
    });
  }

  /// Le pregunta al servidor si vive en esa direccion.
  ///
  /// Va contra `{base}/up`, que es el healthcheck de Laravel y no necesita token
  /// ni base de datos: si responde, hay un backend escuchando AHI. Probar un
  /// endpoint de negocio daria falsos negativos (por ejemplo, 401 por falta de
  /// sesion) que se confundirian con "el servidor no esta".
  ///
  /// El timeout es de 5 segundos y no los 20 de la app. Esta pantalla se abre
  /// justo cuando algo falla, y esperar 20 s a un mensaje no ayuda a diagnosticar.
  Future<void> _probar() async {
    final url = normalizarUrlApi(_controlador.text);

    if (url.isEmpty) {
      setState(() {
        _error = 'Escribe la direccion del backend.';
        _resultadoPrueba = null;
      });
      return;
    }

    setState(() {
      _probando = true;
      _error = null;
      _resultadoPrueba = null;
      _pruebaFallida = false;
    });

    // Se usa el `ClienteApi` del provider, con un token aparte y vacio, para no
    // tocar el token de la sesion mientras se prueba una URL que todavia no es
    // la definitiva.
    final probador = ClienteApi(urlBase: url);
    final reloj = Stopwatch()..start();

    String mensaje;
    bool fallo;

    try {
      await probador.get('/up').timeout(const Duration(seconds: 5));
      reloj.stop();
      mensaje =
          'Hay un servidor en esa direccion (${reloj.elapsedMilliseconds} ms).';
      fallo = false;
    } on TimeoutException {
      reloj.stop();
      // Este es el caso que mas confunde: la direccion "no dice nada" en vez de
      // rechazar. En un celular fisico significa que la IP no existe en la red
      // en la que esta el equipo, casi siempre porque se copio la del emulador.
      mensaje =
          'La direccion no respondio en 5 segundos. Revisa que la IP sea correcta '
          'para ESTE dispositivo y que el equipo este en la misma red.';
      fallo = true;
    } on SocketException {
      reloj.stop();
      mensaje =
          'No hay nada escuchando en esa direccion. Revisa la IP, el puerto y que '
          'el backend este encendido.';
      fallo = true;
    } catch (error) {
      reloj.stop();
      mensaje = 'No se pudo probar la direccion: $error';
      fallo = true;
    }

    probador.cerrar();

    if (!mounted) return;
    setState(() {
      _probando = false;
      _resultadoPrueba = mensaje;
      _pruebaFallida = fallo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Direccion del backend'),
        actions: [
          if (widget.mostrarBotonCerrar)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Cerrar',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'La app se conecta al backend de Ferchy\'s. Escribe la direccion '
            'base donde vive la API, incluyendo el /api del final.',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _controlador,
            autocorrect: false,
            // `keyboardType: url` pone el teclado con barra y punto, que es
            // lo que se escribe casi siempre.
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _guardar(),
            decoration: InputDecoration(
              labelText: 'URL de la API',
              hintText: UrlPorDefecto.emuladorAndroid,
              errorText: _error,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Guardar'),
          ),

          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _probando ? null : _probar,
            icon: _probando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_rounded),
            label: const Text('Probar conexion'),
          ),
          if (_resultadoPrueba != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _pruebaFallida
                    ? tema.colorScheme.errorContainer
                    : tema.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _resultadoPrueba!,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: _pruebaFallida
                      ? tema.colorScheme.onErrorContainer
                      : tema.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          Text('Ejemplos rapidos', style: tema.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Solo rellenan el campo. Hay que tocar Guardar para aplicarlos.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          _BotonEjemplo(
            titulo: 'Servidor por Tailscale',
            descripcion:
                'La red privada entre tus equipos. Funciona desde el celular y '
                'la tablet sin depender del wifi de la casa.',
            url: UrlPorDefecto.tailscale,
            alTocar: () => _usarEjemplo(UrlPorDefecto.tailscale),
          ),
          _BotonEjemplo(
            titulo: 'Emulador de Android',
            descripcion:
                'El emulador ve el localhost de la computadora como 10.0.2.2. '
                'En un celular o tablet real esto NO funciona.',
            url: UrlPorDefecto.emuladorAndroid,
            alTocar: () => _usarEjemplo(UrlPorDefecto.emuladorAndroid),
          ),
          _BotonEjemplo(
            titulo: 'Simulador de iOS o servidor local',
            descripcion: 'Aqui el localhost es el mismo equipo.',
            url: UrlPorDefecto.simuladorIos,
            alTocar: () => _usarEjemplo(UrlPorDefecto.simuladorIos),
          ),
          _BotonEjemplo(
            titulo: 'Dispositivo fisico en la misma red',
            descripcion:
                'Cambia la IP por la de la computadora donde corre el backend.',
            url: UrlPorDefecto.dispositivoFisico,
            alTocar: () => _usarEjemplo(UrlPorDefecto.dispositivoFisico),
          ),

          const SizedBox(height: 24),
          _AvisoImportante(tema: tema),
        ],
      ),
    );
  }
}

/// Fila de un ejemplo de URL.
class _BotonEjemplo extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final String url;
  final VoidCallback alTocar;

  const _BotonEjemplo({
    required this.titulo,
    required this.descripcion,
    required this.url,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: alTocar,
        title: Text(titulo),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(descripcion, style: tema.textTheme.bodySmall),
            const SizedBox(height: 4),
            // La URL se muestra en un `Text` aparte y no en el subtitulo del
            // `ListTile`, porque el `ListTile` la recortaria con los tres
            // puntos en pantallas angostas.
            Text(
              url,
              style: tema.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: tema.colorScheme.primary,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }
}

/// Explica el caso de la IP local, que es donde mas gente se traba.
class _AvisoImportante extends StatelessWidget {
  final ThemeData tema;

  const _AvisoImportante({required this.tema});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tema.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 20,
                color: tema.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'Prueba rapida',
                style: tema.textTheme.titleSmall?.copyWith(
                  color: tema.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Desde el movil no se puede abrir "localhost": eso apunta al propio '
            'telefono. Por eso existen 10.0.2.2 (emulador) y la IP de la '
            'computadora (fisico).',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
