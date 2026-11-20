import 'dinero.dart';
import 'eventos.dart';
import 'excepciones.dart';
import 'monedero.dart';

/// Niveles del programa de lealtad.
enum NivelLealtad {
  bronce('Bronce', 0, 100),
  plata('Plata', 500, 125),
  oro('Oro', 2000, 150);

  final String nombre;
  final int puntosMinimos;
  final int porcentajePuntos;

  const NivelLealtad(this.nombre, this.puntosMinimos, this.porcentajePuntos);
}

/// Sistema de puntos, bonos, rachas y canjes.
class Lealtad {
  static const int centavosPorPunto = 1000;

  static const Map<int, int> bonoSemanal = {2: 50, 3: 100, 4: 200};

  static const int bonoRacha = 70;
  static const int diasPorBonoRacha = 7;
  static const int puntosPorCanje = 100;
  static const int centavosPorCanje = 1000;

  final Monedero _monedero;

  final Map<String, int> _puntos = {};
  final Set<String> _procesados = {};

  final Map<String, Map<DateTime, Set<Servicio>>> _semanas = {};

  final Map<String, DateTime> _ultimoDia = {};
  final Map<String, int> _racha = {};

  int _canjes = 0;

  Lealtad(this._monedero);

  /// Escucha los eventos publicados en la plataforma.
  void conectar(BusEventos bus) {
    bus.suscribir<EventoApp>(alEvento);
  }

  /// Consulta los puntos de un usuario.
  int puntos(String usuario) {
    return _puntos[usuario] ?? 0;
  }

  /// Consulta la racha de actividad.
  int racha(String usuario) {
    return _racha[usuario] ?? 0;
  }

  /// Determina el nivel según los puntos disponibles.
  NivelLealtad nivel(String usuario) {
    final p = puntos(usuario);

    return NivelLealtad.values.lastWhere((n) => p >= n.puntosMinimos);
  }

  /// Añade puntos al usuario.
  void _dar(String usuario, int cantidad) {
    _puntos[usuario] = puntos(usuario) + cantidad;
  }

  /// Procesa las reglas al recibir un evento.
  void alEvento(EventoApp evento) {
    // Las operaciones pasivas no cuentan.
    if (!evento.cuentaComoUso) {
      return;
    }

    // Un evento solo puede generar recompensas una vez.
    if (!_procesados.add(evento.id)) {
      return;
    }

    final usuario = evento.usuarioId;

    // 1. Puntos por compras y viajes completados.
    final gasto = switch (evento) {
      PedidoCreado(:final totalCentavos) => totalCentavos,
      ViajeFinalizado(:final montoCentavos) => montoCentavos,
      _ => 0,
    };

    if (gasto > 0) {
      final base = gasto ~/ centavosPorPunto;

      _dar(usuario, base * nivel(usuario).porcentajePuntos ~/ 100);
    }

    // 2. Bono semanal por servicios distintos.
    final semana = lunesDe(evento.fecha);

    final usados = ((_semanas[usuario] ??= {})[semana] ??= {});

    final antes = usados.length;

    usados.add(evento.servicio);

    final despues = usados.length;

    if (despues > antes) {
      final bono = bonoSemanal[despues];

      if (bono != null) {
        _dar(usuario, bono);
      }
    }

    // 3. Racha de días consecutivos.
    final dia = soloFecha(evento.fecha);
    final ultimo = _ultimoDia[usuario];

    if (ultimo == null) {
      _racha[usuario] = 1;
    } else if (dia == masDias(ultimo, 1)) {
      _racha[usuario] = racha(usuario) + 1;

      if (racha(usuario) % diasPorBonoRacha == 0) {
        _dar(usuario, bonoRacha);
      }
    } else if (dia.isAfter(ultimo)) {
      _racha[usuario] = 1;
    }

    if (ultimo == null || dia.isAfter(ultimo)) {
      _ultimoDia[usuario] = dia;
    }
  }

  /// Canjea puntos por saldo simulado.
  int canjear(String usuario, int puntosACanjear) {
    if (puntosACanjear <= 0 || puntosACanjear % puntosPorCanje != 0) {
      throw const CanjeInvalidoException('Canjea múltiplos de 100 puntos.');
    }

    if (puntosACanjear > puntos(usuario)) {
      throw const CanjeInvalidoException('No tienes suficientes puntos.');
    }

    final centavos = puntosACanjear ~/ puntosPorCanje * centavosPorCanje;

    // Registrar el canje en el monedero.
    _monedero.reembolsar(
      usuario,
      centavos,
      'Canje de puntos',
      clave: 'canje:$usuario:${++_canjes}',
    );

    // Descontar los puntos utilizados.
    _puntos[usuario] = puntos(usuario) - puntosACanjear;

    return centavos;
  }
}
