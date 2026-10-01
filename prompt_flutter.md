
# ESTILO DE CÓDIGO REQUERIDO — MUY IMPORTANTE

Voy a APRENDER LEYENDO este código, no solo a usarlo. Por eso:

1. Comenta CADA archivo con un bloque breve al inicio explicando qué hace y por qué existe
   (2-4 líneas, no un ensayo).
2. Comenta las partes no obvias del código (por qué un try/catch, por qué ese patrón de
   Provider, qué hace cada parámetro nombrado) — pero NO comentes lo obvio línea por línea.
3. Usa nombres de variables y funciones en español para que combine con el resto del proyecto
   (que ya usa nombres en español), PERO mantén en inglés las convenciones propias de Flutter/Dart
   (nombres de clases base, widgets, parámetros de framework).
4. Prioriza código simple y explícito sobre "elegante" o abreviado — prefiero un if/else claro
   a un operador ternario anidado, por ejemplo.
5. Cada archivo debe poder entenderse leyéndolo solo, sin saltar a otros 5 archivos para
   entender qué hace.

# ENTREGABLE ESPERADO

1. Todos los archivos listados arriba, completos y funcionales.
2. Actualiza `pubspec.yaml` con exactamente las dependencias listadas (y sus versiones estables
   más recientes).
3. Al final, dame un resumen breve (no repitas el código) de:
   - Qué archivos creaste
   - Qué necesito configurar manualmente (la URL del backend en app_config.dart)
   - Cómo correr la app (`flutter pub get` && `flutter run`)
4. NO ejecutes `flutter run` tú mismo — solo genera los archivos, yo lo corro para practicar
   leyendo los logs y debuggeando si algo falla.
