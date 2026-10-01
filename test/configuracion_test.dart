/// Pruebas de la configuracion del backend.
///
/// EL CASO QUE SE CUBRE AQUI YA PASÓ. La app arrancaba con
/// `http://10.0.2.2:8000/api` por defecto, que es el alias que SOLO existe en el
/// emulador de Android. En una tablet fisica esa direccion no lleva a ningun
/// lado, los paquetes se descartan en silencio y el unico sintoma era "el
/// servidor tardo demasiado en responder" con el backend encendido. Estas
/// pruebas existen para que cambiar el default otra vez sea una decision y no
/// un descuido.
library;

import 'package:ferchys_mobile/app_config.dart';
import 'package:ferchys_mobile/screens/configuracion/pantalla_configuracion_url.dart';
import 'package:ferchys_mobile/state/config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('leerUrlGuardada', () {
    test('sin nada guardado devuelve la del servidor por Tailscale', () async {
      SharedPreferences.setMockInitialValues({});

      final url = await leerUrlGuardada();

      // `10.0.2.2` es lo unico que hay que evitar como default: en hardware
      // fisico cuelga en vez de fallar, y el timeout no dice por que.
      expect(url, UrlPorDefecto.tailscale);
      expect(url, isNot(UrlPorDefecto.emuladorAndroid));
    });

    test('devuelve la guardada, sin mirar ninguna otra', () async {
      SharedPreferences.setMockInitialValues({
        ClavesAlmacenamiento.urlBaseApi: 'http://192.168.1.50:8000/api',
      });

      expect(await leerUrlGuardada(), 'http://192.168.1.50:8000/api');
    });

    test('una URL guardada vacia no tapa el default', () async {
      SharedPreferences.setMockInitialValues({
        ClavesAlmacenamiento.urlBaseApi: '',
      });

      expect(await leerUrlGuardada(), UrlPorDefecto.tailscale);
    });
  });

  group('las URLs de ejemplo', () {
    test('son usables tal cual, sin editar', () {
      for (final url in [
        UrlPorDefecto.tailscale,
        UrlPorDefecto.emuladorAndroid,
        UrlPorDefecto.simuladorIos,
      ]) {
        // Un ejemplo que no es una URL valida hace que el error salga al
        // guardar, y entonces el boton de relleno es peor que no tenerlo.
        expect(normalizarUrlApi(url), url, reason: 'ejemplo invalido: $url');
      }
    });

    test('la de Tailscale no es la del emulador', () {
      expect(UrlPorDefecto.tailscale, isNot(UrlPorDefecto.emuladorAndroid));
    });
  });

  group('PantallaConfiguracionUrl', () {
    testWidgets('proponer la URL de Tailscale y la de Tailscale del servidor', (
      probador,
    ) async {
      await probador.pumpWidget(_app());

      expect(find.text('Servidor por Tailscale'), findsOneWidget);
      // La opcion del emulador sigue estando, pero avisando de que es solo
      // para emulador. Callarla obligaria a adivinar en el caso contrario.
      expect(find.text('Emulador de Android'), findsOneWidget);
    });

    testWidgets('un boton de ejemplo llena el campo sin guardarlo', (
      probador,
    ) async {
      await probador.pumpWidget(_app());

      await probador.tap(find.text('Servidor por Tailscale'));
      await probador.pump();

      expect(
        find.textContaining(UrlPorDefecto.tailscale),
        findsWidgets,
        reason: 'el ejemplo deberia haber rellenado el campo',
      );
    });

    testWidgets('probar conexion responde algo y no se queda colgada', (
      probador,
    ) async {
      await probador.pumpWidget(_app());

      await probador.tap(find.text('Probar conexion'));
      // Sin este limite, un fallo de red dejaria la prueba colgada hasta que
      // el runner la matara: que es justamente lo que se quiere evitar.
      await probador.pumpAndSettle(
        const Duration(seconds: 6),
        EnginePhase.sendSemanticsUpdate,
      );

      // Da igual que la peticion tenga exito o no. Lo que importa es que siempre
      // haya un veredicto: nunca un boton girando sin explicacion.
      expect(find.text('Probar conexion'), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'la prueba deberia haber terminado',
      );
    });
  });
}

/// Monta la pantalla con un [ConfigProvider] de mentira.
///
/// Va en una funcion suelta porque las tres pruebas la usan igual y repetir el
/// `pumpWidget` tres veces es ruido.
Widget _app() {
  return ChangeNotifierProvider<ConfigProvider>(
    create: (_) => ConfigProvider(urlApiInicial: UrlPorDefecto.tailscale),
    child: const MaterialApp(home: PantallaConfiguracionUrl()),
  );
}
