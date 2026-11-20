import 'comercio.dart';
import 'excepciones.dart';
import 'mensajeria.dart';
import 'mini_app.dart';
import 'monedero.dart';
import 'transporte.dart';

/// Única puerta de una mini-app hacia los servicios.
class ContextoMiniApp {
  final MiniApp app;
  final String usuarioId;

  final RegistroMiniApps _registro;
  final Monedero _monedero;
  final ServicioMensajes _mensajes;
  final ServicioComercio _comercio;
  final ServicioViajes _viajes;

  ContextoMiniApp(
    this.app,
    this.usuarioId,
    this._registro,
    this._monedero,
    this._mensajes,
    this._comercio,
    this._viajes,
  );

  /// Comprueba actividad y permisos.
  void _exige(Permiso permiso) {
    _registro.exigeActiva(app.id);

    if (!app.permisos.contains(permiso)) {
      throw PermisoDenegadoException(app.nombre, permiso.name);
    }
  }

  ApiMonedero get monedero {
    _exige(Permiso.monederoLeer);
    return ApiMonedero._(this);
  }

  ApiPagos get pagos {
    _exige(Permiso.monederoPagar);
    return ApiPagos._(this);
  }

  ApiMensajes get mensajes {
    _exige(Permiso.mensajesLeer);
    return ApiMensajes._(this);
  }

  ApiComercio get comercio {
    _exige(Permiso.monederoPagar);
    return ApiComercio._(this);
  }

  ApiViajes get viajes {
    _exige(Permiso.ubicacion);
    _exige(Permiso.monederoPagar);
    return ApiViajes._(this);
  }
}

/// Acceso de lectura al monedero del usuario.
class ApiMonedero {
  final ContextoMiniApp _c;

  ApiMonedero._(this._c);

  int saldo() {
    _c._exige(Permiso.monederoLeer);
    return _c._monedero.saldo(_c.usuarioId);
  }

  List<Movimiento> movimientos() {
    _c._exige(Permiso.monederoLeer);
    return _c._monedero.movimientos(_c.usuarioId);
  }
}

/// Operaciones de pago asociadas al usuario.
class ApiPagos {
  final ContextoMiniApp _c;

  ApiPagos._(this._c);

  void pagar(int monto, String concepto, {required String clave}) {
    _c._exige(Permiso.monederoPagar);

    _c._monedero.pagar(_c.usuarioId, monto, concepto, clave: clave);
  }

  void enviarDinero(String para, int monto, {required String clave}) {
    _c._exige(Permiso.monederoPagar);

    _c._mensajes.enviarDinero(_c.usuarioId, para, monto, clave: clave);
  }
}

/// Acceso a conversaciones y mensajes.
class ApiMensajes {
  final ContextoMiniApp _c;

  ApiMensajes._(this._c);

  List<ResumenConversacion> resumenes() {
    _c._exige(Permiso.mensajesLeer);
    return _c._mensajes.resumenes(_c.usuarioId);
  }

  List<Mensaje> conversacion(String con) {
    _c._exige(Permiso.mensajesLeer);
    return _c._mensajes.conversacion(_c.usuarioId, con);
  }

  int noLeidos() {
    _c._exige(Permiso.mensajesLeer);
    return _c._mensajes.noLeidos(_c.usuarioId);
  }

  void marcarLeidos(String con) {
    _c._exige(Permiso.mensajesLeer);
    _c._mensajes.marcarLeidos(_c.usuarioId, con);
  }

  Mensaje enviar(String para, String texto) {
    _c._exige(Permiso.mensajesLeer);
    _c._exige(Permiso.mensajesEscribir);

    return _c._mensajes.enviar(_c.usuarioId, para, texto);
  }
}

/// Acceso al comercio local.
class ApiComercio {
  final ContextoMiniApp _c;

  ApiComercio._(this._c);

  List<Tienda> tiendas() {
    _c._exige(Permiso.monederoPagar);
    return _c._comercio.tiendas;
  }

  List<Pedido> misPedidos() {
    _c._exige(Permiso.monederoPagar);
    return _c._comercio.pedidosDe(_c.usuarioId);
  }

  Pedido comprar(
    String tiendaId,
    Map<String, int> items, {
    required String clave,
  }) {
    _c._exige(Permiso.monederoPagar);

    return _c._comercio.comprar(
      usuarioId: _c.usuarioId,
      tiendaId: tiendaId,
      items: items,
      clave: clave,
    );
  }
}

/// Acceso al transporte simulado.
class ApiViajes {
  final ContextoMiniApp _c;

  ApiViajes._(this._c);

  void _exigeAcceso() {
    _c._exige(Permiso.ubicacion);
    _c._exige(Permiso.monederoPagar);
  }

  int estimar(Punto origen, Punto destino) {
    _exigeAcceso();
    return _c._viajes.estimar(origen, destino);
  }

  List<Viaje> misViajes() {
    _exigeAcceso();
    return _c._viajes.deUsuario(_c.usuarioId);
  }

  Viaje solicitar(Punto origen, Punto destino) {
    _exigeAcceso();

    return _c._viajes.solicitar(_c.usuarioId, origen, destino);
  }

  /// Impide operar sobre los viajes de otra persona.
  String _propio(String id) {
    _exigeAcceso();

    final viaje = _c._viajes.porId(id);

    if (viaje == null || viaje.usuarioId != _c.usuarioId) {
      throw const PedidoInvalidoException('Viaje no encontrado.');
    }

    return id;
  }

  /// Acciones simuladas del conductor.
  Viaje aceptar(String id, String conductor) {
    return _c._viajes.aceptar(_propio(id), conductor);
  }

  Viaje iniciar(String id) {
    return _c._viajes.iniciar(_propio(id));
  }

  Viaje finalizar(String id, {required double km, required int minutos}) {
    return _c._viajes.finalizar(_propio(id), kmReal: km, minutosReal: minutos);
  }

  Viaje cancelar(String id) {
    return _c._viajes.cancelar(_propio(id));
  }
}
