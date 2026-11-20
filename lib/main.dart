import 'package:flutter/material.dart';

import 'dominio/dinero.dart';
import 'dominio/mini_app.dart';
import 'dominio/plataforma.dart';
import 'presentacion/pantallas/pantalla_chat.dart';
import 'presentacion/pantallas/pantalla_inicio.dart';
import 'presentacion/pantallas/pantalla_monedero.dart';
import 'presentacion/pantallas/pantalla_tienda.dart';
import 'presentacion/pantallas/pantalla_viajes.dart';
import 'presentacion/vm/inicio_vm.dart';

void main() {
  runApp(const SuperDoloresApp());
}

class SuperDoloresApp extends StatelessWidget {
  const SuperDoloresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Dolores',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6A1B9A),
        useMaterial3: true,
      ),
      home: const Concha(),
    );
  }
}

/// Estructura principal y navegación de la SuperApp.
class Concha extends StatefulWidget {
  const Concha({super.key});

  @override
  State<Concha> createState() => _ConchaState();
}

class _ConchaState extends State<Concha> {
  late final Plataforma plataforma = Plataforma()..cargarDatosDemo();

  late final InicioViewModel inicio = InicioViewModel(plataforma, 'ana');

  int _tab = 0;

  ({String id, String nombre, IconData icono}) _destino(MiniApp app) {
    return (
      id: app.id,
      nombre: app.nombre,
      icono: switch (app.id) {
        'chat' => Icons.chat,
        'monedero' => Icons.account_balance_wallet,
        'tienda' => Icons.storefront,
        'viajes' => Icons.local_taxi,
        _ => Icons.apps,
      },
    );
  }

  Widget _pagina(String id, String usuario) {
    final app = plataforma.registro.porId(id)!;

    final contexto = plataforma.contextoPara(app, usuario);

    final alCambiar = inicio.notificar;

    return switch (id) {
      'chat' => PantallaChat(
        contexto: contexto,
        alCambiar: alCambiar,
        plataforma: plataforma,
      ),
      'monedero' => PantallaMonedero(
        contexto: contexto,
        alCambiar: alCambiar,
        plataforma: plataforma,
      ),
      'tienda' => PantallaTienda(contexto: contexto, alCambiar: alCambiar),
      'viajes' => PantallaViajes(contexto: contexto, alCambiar: alCambiar),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  void dispose() {
    inicio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: inicio,
      builder: (context, _) {
        final usuario = inicio.usuarioId;

        // Solo aparecen mini-apps activas.
        final apps = plataforma.registro.activas
            .where((a) => a.id != 'horoscopo')
            .toList();

        final paginas = <Widget>[
          PantallaInicio(vm: inicio),
          for (final app in apps)
            KeyedSubtree(
              key: ValueKey('${app.id}-$usuario'),
              child: _pagina(app.id, usuario),
            ),
        ];

        if (_tab >= paginas.length) {
          _tab = 0;
        }

        return Scaffold(
          body: IndexedStack(index: _tab, children: paginas),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (indice) {
              setState(() {
                _tab = indice;
              });
            },
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: inicio.noLeidos > 0,
                  label: Text('${inicio.noLeidos}'),
                  child: const Icon(Icons.home),
                ),
                label: 'Inicio · ${formatearPesos(inicio.saldo)}',
              ),

              for (final app in apps)
                NavigationDestination(
                  icon: Icon(_destino(app).icono),
                  label: app.nombre,
                ),
            ],
          ),
        );
      },
    );
  }
}
