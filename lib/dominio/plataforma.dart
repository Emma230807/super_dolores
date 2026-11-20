import 'comercio.dart';
import 'contexto.dart';
import 'eventos.dart';
import 'mensajeria.dart';
import 'mini_app.dart';
import 'monedero.dart';
import 'transporte.dart';
import 'lealtad.dart';
import 'analitica.dart';
import 'notificaciones.dart';

/// Perfil utilizado en la simulación.
class PerfilDemo {
  final String id;
  final String nombre;

  const PerfilDemo(this.id, this.nombre);
}

/// Plataforma central de la SuperApp.
class Plataforma {
  final DateTime Function() reloj;
  late final Lealtad lealtad = Lealtad(monedero);
  final Analitica analitica = Analitica();
  final Notificador notificador = Notificador();
  final Ids ids = Ids();
  final BusEventos bus = BusEventos();
  final RegistroMiniApps registro = RegistroMiniApps();

  late final Monedero monedero = Monedero(reloj: reloj);

  late final ServicioMensajes mensajes = ServicioMensajes(
    monedero,
    bus,
    ids,
    reloj,
  );

  late final ServicioComercio comercio;

  late final ServicioViajes viajes = ServicioViajes(monedero, bus, ids, reloj);

  final List<PerfilDemo> perfiles = const [
    PerfilDemo('ana', 'Ana'),
    PerfilDemo('luis', 'Luis'),
    PerfilDemo('marta', 'Marta'),
  ];

  static const miniChat = MiniApp('chat', 'Mensajes', '💬', {
    Permiso.identidad,
    Permiso.mensajesLeer,
    Permiso.mensajesEscribir,
    Permiso.monederoPagar,
  });

  static const miniMonedero = MiniApp('monedero', 'Monedero', '👛', {
    Permiso.identidad,
    Permiso.monederoLeer,
    Permiso.monederoPagar,
  });

  static const miniTienda = MiniApp('tienda', 'Tienda', '🛍️', {
    Permiso.identidad,
    Permiso.monederoPagar,
  });

  static const miniViajes = MiniApp('viajes', 'Viajes', '🚕', {
    Permiso.identidad,
    Permiso.ubicacion,
    Permiso.monederoPagar,
  });

  /// Mini-app de terceros con acceso solo a identidad.
  static const miniHoroscopo = MiniApp('horoscopo', 'Horóscopo', '🔮', {
    Permiso.identidad,
  });

  static const conductoresDemo = ['conductor1', 'conductor2'];

  Plataforma({DateTime Function()? reloj, List<Tienda>? tiendas})
    : reloj = reloj ?? DateTime.now {
    comercio = ServicioComercio(
      monedero,
      bus,
      ids,
      this.reloj,
      tiendas ?? tiendasDemo(),
    );

    // Registrar las mini-apps.
    for (final app in [
      miniChat,
      miniMonedero,
      miniTienda,
      miniViajes,
      miniHoroscopo,
    ]) {
      registro.registrar(app);
    }

    // Abrir cuenta central de la plataforma.
    monedero.abrirCuenta(ServicioComercio.cuentaPlataforma, sinLimites: true);

    // Abrir cuentas de usuarios.
    for (final perfil in perfiles) {
      monedero.abrirCuenta(perfil.id);
    }

    // Abrir cuentas de negocios.
    for (final tienda in comercio.tiendas) {
      monedero.abrirCuenta(tienda.duenoId);
    }

    // Abrir cuentas de conductores simulados.
    for (final conductor in conductoresDemo) {
      monedero.abrirCuenta(conductor);
    }

    // Conectar el sistema de lealtad al bus de eventos.
    lealtad.conectar(bus);
    analitica.conectar(bus);
    notificador.conectar(bus);
  }

  /// Negocios locales simulados del manual.
  static List<Tienda> tiendasDemo() => [
    Tienda('tortilleria', 'Tortillería La Güera', '🌮', 'dueno-tortilleria', [
      ProductoTienda('kilo', 'Kilo de tortillas', 2800, 50),
      ProductoTienda('tostadas', 'Paquete de tostadas', 3500, 30),
    ]),
    Tienda('cajeta', 'Dulces Dolores', '🍬', 'dueno-cajeta', [
      ProductoTienda('cajeta', 'Cajeta artesanal', 9500, 20),
      ProductoTienda('alegrias', 'Alegrías de amaranto', 7500, 25),
    ]),
    Tienda('talavera', 'Talavera del Centro', '🏺', 'dueno-talavera', [
      ProductoTienda('taza', 'Taza de Talavera', 22000, 10),
      ProductoTienda('jarron', 'Jarrón azul', 125000, 4),
    ]),
  ];

  /// Cada persona recibe $1,000 de saldo simulado.
  void cargarDatosDemo() {
    for (final perfil in perfiles) {
      monedero.depositar(
        perfil.id,
        100000,
        clave: 'demo-inicial',
        concepto: 'Saldo de práctica',
      );
    }
  }

  /// Genera el acceso autorizado para una mini-app.
  ContextoMiniApp contextoPara(MiniApp app, String usuarioId) {
    if (!perfiles.any((p) => p.id == usuarioId)) {
      throw ArgumentError('Usuario no registrado.');
    }

    final registrada = registro.porId(app.id);

    if (!identical(registrada, app)) {
      throw ArgumentError('Mini-app no registrada.');
    }

    return ContextoMiniApp(
      app,
      usuarioId,
      registro,
      monedero,
      mensajes,
      comercio,
      viajes,
    );
  }
}
