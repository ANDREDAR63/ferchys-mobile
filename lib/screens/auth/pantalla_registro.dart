/// Pantalla de registro de una cuenta nueva.
///
/// El backend exige cuatro cosas al registrarse: nombre, correo, contrasena y
/// direccion. La direccion no es obvia, y por eso vale la pena explicar por que
/// se pide: el registro crea automaticamente una direccion por defecto, que es
/// la que despues aparece seleccionada al pagar. Sin ella, la primera compra
/// tendria que escribir la direccion de nuevo.
///
/// LA CONTRASENA SE VALIDA EN EL DISPOSITIVO Y TAMBIEN LA VALIDA EL BACKEND, PERO
/// NO CON LA MISMA REGLA. Laravel solo exige `min:8`; aca se pide ademas una
/// mayuscula, una minuscula, un numero y un simbolo, con un `RegExp`. Es mas
/// estricta a proposito: una contrasena debil se puede volver a cambiar en un
/// minuto, pero una cuenta robada no se devuelve.
///
/// El medidor de fuerza se muestra mientras se escribe para que la regla se
/// entienda antes de equivocarse, no despues de que el servidor la rechace.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();
  final TextEditingController _confirmar = TextEditingController();
  final TextEditingController _direccion = TextEditingController();
  final TextEditingController _telefono = TextEditingController();

  bool _mostrarContrasena = false;

  /// Error de la confirmacion. Vive aparte del error del provider porque no
  /// viene del servidor: es una comparacion entre dos campos de esta misma
  /// pantalla y tiene que responder al instante, sin red.
  String? _errorConfirmacion;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _confirmar.dispose();
    _direccion.dispose();
    _telefono.dispose();
    super.dispose();
  }

  /// Cuantos de los cuatro requisitos de la contrasena se cumplen.
  ///
  /// Se cuenta en lugar de dar un "si/no" para que la persona vea que le falta
  /// solo un simbolo y no que su contrasena es "mala".
  int _requisitosCumplidos() {
    final texto = _contrasena.text;
    var cumplidos = 0;

    if (texto.length >= 8) cumplidos++;
    if (RegExp(r'[A-Z]').hasMatch(texto)) cumplidos++;
    if (RegExp(r'[a-z]').hasMatch(texto)) cumplidos++;
    if (RegExp(r'[0-9]').hasMatch(texto)) cumplidos++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(texto)) cumplidos++;

    return cumplidos;
  }

  Future<void> _registrar() async {
    setState(() => _errorConfirmacion = null);

    if (_contrasena.text != _confirmar.text) {
      setState(() => _errorConfirmacion = 'Las contrasenas no coinciden.');
      return;
    }

    final exito = await context.read<AuthProvider>().registrar(
      nombre: _nombre.text.trim(),
      correo: _correo.text.trim(),
      contrasena: _contrasena.text,
      contrasenaConfirmada: _confirmar.text,
      direccion: _direccion.text.trim(),
      telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
    );

    // Si se logro, `main.dart` cambia sola a la pantalla principal segun el
    // rol. Se vuelve atras para no dejar esta pantalla en el historial.
    if (exito && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tema = Theme.of(context);
    final cumplidos = _requisitosCumplidos();

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Campo(
                    controlador: _nombre,
                    etiqueta: 'Nombre completo',
                    icono: Icons.person_outline_rounded,
                    siguiente: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  _Campo(
                    controlador: _correo,
                    etiqueta: 'Correo',
                    icono: Icons.alternate_email_rounded,
                    teclado: TextInputType.emailAddress,
                    siguiente: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  _Campo(
                    controlador: _telefono,
                    etiqueta: 'Telefono (opcional)',
                    icono: Icons.phone_outlined,
                    teclado: TextInputType.phone,
                    siguiente: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  _Campo(
                    controlador: _contrasena,
                    etiqueta: 'Contrasena',
                    icono: Icons.lock_outline_rounded,
                    siguiente: TextInputAction.next,
                    ocultar: !_mostrarContrasena,
                    alCambiar: (_) => setState(() {}),
                    sufijo: IconButton(
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

                  // El medidor se construye aqui y no dentro de `_Campo` porque
                  // necesita un `setState` en cada tecla para actualizarse.
                  _MedidorContrasena(cumplidos: cumplidos),
                  const SizedBox(height: 14),

                  _Campo(
                    controlador: _confirmar,
                    etiqueta: 'Repetir contrasena',
                    icono: Icons.lock_reset_rounded,
                    accion: TextInputAction.done,
                    ocultar: !_mostrarContrasena,
                    error: _errorConfirmacion,
                    alEnviar: (_) => _registrar(),
                  ),
                  const SizedBox(height: 14),

                  _Campo(
                    controlador: _direccion,
                    etiqueta: 'Direccion de entrega',
                    icono: Icons.location_on_outlined,
                    siguiente: TextInputAction.done,
                    ayuda: 'Se guarda como tu direccion principal para las compras.',
                  ),

                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tema.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        auth.error!,
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: tema.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: auth.cargando ? null : _registrar,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: auth.cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear cuenta'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Al crear la cuenta entras con rol de cliente. Un '
                    'administrador tiene que cambiar el rol desde la web.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de texto del formulario.
///
/// Existe para no repetir `TextField` con las mismas ocho propiedades cinco
/// veces. Cada campo pasa solo lo que cambia: el icono, si oculta el texto y
/// que pasa al tocar "listo".
class _Campo extends StatelessWidget {
  final TextEditingController controlador;
  final String etiqueta;
  final IconData icono;
  final String? ayuda;
  final String? error;
  final TextInputType? teclado;
  final TextInputAction siguiente;
  final TextInputAction? accion;
  final bool ocultar;
  final Widget? sufijo;
  final ValueChanged<String>? alCambiar;
  final ValueChanged<String>? alEnviar;

  const _Campo({
    required this.controlador,
    required this.etiqueta,
    required this.icono,
    this.ayuda,
    this.error,
    this.teclado,
    this.siguiente = TextInputAction.next,
    this.accion,
    this.ocultar = false,
    this.sufijo,
    this.alCambiar,
    this.alEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      keyboardType: teclado,
      textInputAction: accion ?? siguiente,
      obscureText: ocultar,
      autocorrect: false,
      onChanged: alCambiar,
      onSubmitted: alEnviar,
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        errorText: error,
        prefixIcon: Icon(icono),
        suffixIcon: sufijo,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Las cinco rayas que muestran el avance hacia una contrasena valida.
class _MedidorContrasena extends StatelessWidget {
  final int cumplidos;

  const _MedidorContrasena({required this.cumplidos});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    // Se queda en 1 con el campo vacio en vez de en 0: un campo en cero con
    // todas las rayas rojas asusta antes de que se escriba nada.
    final vacio = cumplidos == 0;
    final color = vacio
        ? tema.colorScheme.outlineVariant
        : (cumplidos <= 2
              ? tema.colorScheme.error
              : (cumplidos <= 4
                    ? Colors.orange.shade700
                    : Colors.green.shade700));

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 1; i <= 5; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == 5 ? 0 : 4),
                decoration: BoxDecoration(
                  color: i <= cumplidos
                      ? color
                      : tema.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Text(
            vacio
                ? '8+ caracteres'
                : (cumplidos >= 5 ? 'Segura' : '$cumplidos de 5'),
            style: tema.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
