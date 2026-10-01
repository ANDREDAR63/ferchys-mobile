/// Formateo de dinero y fechas en estilo colombiano.
///
/// Existe aparte porque el formato de la moneda aparece en casi todas las
/// pantallas y el de fechas tiene una rareza (los miles van con punto) que es
/// facil de olvidar. Centralizarlo aqui garantiza que el mismo numero se vea
/// igual en el carrito, en el pedido y en los reportes.
///
/// UPDATES SOBRE EL PAQUETE INTL, DOS COSAS QUE NO SON OBVIAS:
///
/// 1. Las fechas en un idioma que no sea `en_US` exigen llamar antes a
///    [inicializarFormatos] con `initializeDateFormatting`. Sin esa llamada,
///    `DateFormat('d MMM y', 'es_CO')` revienta con un
///    `LocaleDataException` en tiempo de ejecucion, no de compilacion. Por eso
///    [inicializarFormatos] se invoca desde `main()` antes de `runApp`.
///
/// 2. `NumberFormat.currency` con locale `es_CO` escribe el simbolo AL FINAL
///    ("7.000 $"), que es la convencion colombiana, pero la version web del
///    proyecto muestra "$7.000". Para que las dos apps se vean igual, aqui se
///    usa `decimalPattern` (que solo agrupa los miles) y se antepone el `$` a
///    mano.
library;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Prepara los datos de idioma de `intl`.
///
/// **Hay que llamar esto una vez, al inicio de la app**, antes de construir
/// cualquier `DateFormat` con locale distinto a `en_US`. Se llama desde
/// `main()`.
Future<void> inicializarFormatos() async {
  await initializeDateFormatting('es_CO');
}

/// Solo agrupa los miles al estilo colombiano (7000 -> "7.000").
final NumberFormat _formatoMiles = NumberFormat.decimalPattern('es_CO');

/// Fecha corta para listados: `30 sept 2026`.
final DateFormat _formatoFechaCorta = DateFormat('d MMM y', 'es_CO');

/// Fecha con hora para el historial de pedidos: `30 sept 2026, 3:45 p. m.`.
///
/// El historial importa: cuando algo sale mal hay que saber exactamente en
/// que momento ocurrio el cambio de estado, no solo el dia.
final DateFormat _formatoFechaHora = DateFormat('d MMM y, h:mm a', 'es_CO');

/// Formatea un monto como pesos colombianos: `$7.000`.
///
/// Sin decimales porque los precios del catalogo son enteros en pesos.
String formatearMoneda(double valor) {
  return '\$${_formatoMiles.format(valor)}';
}

/// Formatea una fecha corta. Si la fecha es nula devuelve un texto en vez de
/// fallar, porque un pedido sin `created_at` no debe romper la pantalla.
String formatearFecha(DateTime? fecha) {
  if (fecha == null) return 'Sin fecha';
  return _formatoFechaCorta.format(fecha);
}

String formatearFechaHora(DateTime? fecha) {
  if (fecha == null) return 'Sin fecha';

  // `intl` escribe "p. m." con un espacio DURO estrecho (U+202F) entre "p." y
  // "m.", por la regla CLDR de los locales castellanos. No se ve la diferencia
  // a simple vista, pero rompe cualquier comparacion de strings y hace que el
  // texto se comporte raro al copiarlo. Se cambian por espacios normales para
  // que el resultado sea el que uno espera.
  final texto = _formatoFechaHora.format(fecha);
  return texto.replaceAll('\u202F', ' ').replaceAll('\u00A0', ' ');
}

/// Porcentaje con signo, para las variaciones de los reportes.
///
/// Muestra `+12.5%` cuando sube y `-8.3%` cuando baja, porque el signo es
/// justo la informacion. Un valor nulo significa que no hay periodo anterior
/// con el cual comparar (la venta fue la primera), y se muestra como guion en
/// vez de 0% para no mentir.
String formatearVariacion(double? porcentaje) {
  if (porcentaje == null) return '—';
  if (porcentaje > 0) {
    return '+${porcentaje.toStringAsFixed(1)}%';
  }
  return '${porcentaje.toStringAsFixed(1)}%';
}
