/// Pantallas de trabajo de la cocina y del repartidor.
///
/// SE AGRUPAN EN UN ARCHIVO PORQUE SON EL MISMO PANTALLA CON DISTINTOS
/// PARAMETROS. Las dos muestran una lista de pedidos y un boton que avanza el
/// estado; lo unico que cambia es que estados entran en la lista y a donde se
/// lleva el boton. Duplicar el archivo entero para cambiar dos parametros haria
/// que una correccion en una se olvide en la otra.
///
/// NO HAY NOTIFICACIONES NI REFRESH AUTOMATICO. Un pedido nuevo no avisa solo:
/// la pantalla se actualiza al abrirla y al tirar hacia abajo. Es una
/// limitacion conocida y esta anotada aca para que no se lea como un error.
library;

import 'package:flutter/material.dart';

import '../pedidos/pantalla_pedidos.dart';

/// Pantalla de la cocina: ve lo que tiene que cocinar.
class PantallaCocina extends StatelessWidget {
  const PantallaCocina({super.key});

  @override
  Widget build(BuildContext context) {
    return const PantallaPedidos(permiteAvanzar: true, esCocina: true);
  }
}

/// Pantalla del repartidor: ve lo que tiene que llevar.
class PantallaRepartidor extends StatelessWidget {
  const PantallaRepartidor({super.key});

  @override
  Widget build(BuildContext context) {
    return const PantallaPedidos(permiteAvanzar: true);
  }
}
