import 'dart:math' as math;

import 'dinero.dart';
import 'eventos.dart';
import 'excepciones.dart';
import 'monedero.dart';

/// Representa una ubicación mediante latitud y longitud.
class Punto {
  final double lat;
  final double lon;

  const Punto(this.lat, this.lon);
}

/// Calcula la distancia en línea recta sobre la Tierra.
/// Utiliza la fórmula de Haversine.
double distanciaKm(Punto a, Punto b) {
  const r = 6371.0088;

  double rad(double grados) => grados * math.pi / 180;

  final dLat = rad(b.lat - a.lat);
  final dLon = rad(b.lon - a.lon);

  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLon / 2), 2);

  return 2 * r * math.asin(math.sqrt(h));
}

/// Reglas para calcular las tarifas.
class Tarifa {
  static const int baseCentavos = 2500;
  static const int porKmCentavos = 800;
  static const int porMinutoCentavos = 150;
  static const int minimoCentavos = 4500;

  static const double maxMultiplicador = 2.0;

  static const int cancelacionCentavos = 1500;
  static const double velocidadUrbanaKmh = 25;

  /// Estima la duración con una velocidad de 25 km/h.
  static int minutosEstimados(double km) {
    return (km / velocidadUrbanaKmh * 60).ceil();
  }

  /// Calcula el precio según distancia, tiempo y demanda.
  static int calcular({
    required double km,
    required int minutos,
    double multiplicador = 1.0,
  }) {
    final m = multiplicador.clamp(1.0, maxMultiplicador).toDouble();

    final crudo =
        baseCentavos +
        (km * porKmCentavos).round() +
        minutos * porMinutoCentavos;

    final total = (crudo * m).round();

    return total < minimoCentavos ? minimoCentavos : total;
  }
}

/// Estados posibles de un viaje.
enum EstadoViaje { solicitado, aceptado, enCurso, finalizado, cancelado }

/// Transiciones permitidas entre estados.
const _transiciones = <EstadoViaje, Set<EstadoViaje>>{
  EstadoViaje.solicitado: {EstadoViaje.aceptado, EstadoViaje.cancelado},
  EstadoViaje.aceptado: {EstadoViaje.enCurso, EstadoViaje.cancelado},
  EstadoViaje.enCurso: {EstadoViaje.finalizado},
  EstadoViaje.finalizado: {},
  EstadoViaje.cancelado: {},
};

/// Representa un viaje solicitado por un usuario.
class Viaje {
  final String id;
  final String usuarioId;
  final Punto origen;
  final Punto destino;
  final int estimadoCentavos;
  final EstadoViaje estado;
  final String? conductorId;
  final int? cobradoCentavos;

  const Viaje(
    this.id,
    this.usuarioId,
    this.origen,
    this.destino,
    this.estimadoCentavos,
    this.estado, {
    this.conductorId,
    this.cobradoCentavos,
  });

  /// Genera una nueva versión del viaje con otro estado.
  Viaje _a(EstadoViaje nuevo, {String? conductorId, int? cobrado}) {
    if (!_transiciones[estado]!.contains(nuevo)) {
      throw const TransicionInvalidaException();
    }

    return Viaje(
      id,
      usuarioId,
      origen,
      destino,
      estimadoCentavos,
      nuevo,
      conductorId: conductorId ?? this.conductorId,
      cobradoCentavos: cobrado ?? cobradoCentavos,
    );
  }
}

/// Gestiona los viajes y sus cobros.
class ServicioViajes {
  static const int comisionPct = 20;
  static const String cuentaPlataforma = 'plataforma';

  final Monedero _monedero;
  final BusEventos _bus;
  final Ids _ids;
  final DateTime Function() _reloj;

  final Map<String, Viaje> _viajes = {};

  ServicioViajes(this._monedero, this._bus, this._ids, this._reloj);

  /// Busca un viaje por su identificador.
  Viaje? porId(String id) => _viajes[id];

  /// Devuelve los viajes de un usuario.
  List<Viaje> deUsuario(String usuario) {
    return _viajes.values
        .where((v) => v.usuarioId == usuario)
        .toList()
        .reversed
        .toList();
  }

  /// Estima la tarifa de un recorrido.
  int estimar(Punto origen, Punto destino, {double multiplicador = 1.0}) {
    final km = distanciaKm(origen, destino);

    return Tarifa.calcular(
      km: km,
      minutos: Tarifa.minutosEstimados(km),
      multiplicador: multiplicador,
    );
  }

  /// Solicita un viaje sin realizar todavía el cobro.
  Viaje solicitar(String usuarioId, Punto origen, Punto destino) {
    final estimado = estimar(origen, destino);

    if (_monedero.saldo(usuarioId) < estimado) {
      throw const SaldoInsuficienteException();
    }

    final viaje = Viaje(
      _ids.siguiente('via'),
      usuarioId,
      origen,
      destino,
      estimado,
      EstadoViaje.solicitado,
    );

    return _viajes[viaje.id] = viaje;
  }

  /// Un conductor acepta la solicitud.
  Viaje aceptar(String id, String conductorId) {
    return _guardar(
      _viajes[id]!._a(EstadoViaje.aceptado, conductorId: conductorId),
    );
  }

  /// Inicia el viaje.
  Viaje iniciar(String id) {
    return _guardar(_viajes[id]!._a(EstadoViaje.enCurso));
  }

  /// Finaliza el recorrido y distribuye el pago.
  Viaje finalizar(
    String id, {
    required double kmReal,
    required int minutosReal,
    double multiplicador = 1.0,
  }) {
    final viaje = _viajes[id]!;

    final cobrar = Tarifa.calcular(
      km: kmReal,
      minutos: minutosReal,
      multiplicador: multiplicador,
    );

    // Primero validar que la transición sea legal.
    final terminado = viaje._a(EstadoViaje.finalizado, cobrado: cobrar);

    // Transferir el importe del usuario a la plataforma.
    _monedero.transferir(
      viaje.usuarioId,
      cuentaPlataforma,
      cobrar,
      'Viaje ${viaje.id}',
      clave: 'viaje:${viaje.id}',
    );

    // Descontar la comisión y pagar al conductor.
    final comision = porcentaje(cobrar, comisionPct);

    _monedero.transferir(
      cuentaPlataforma,
      viaje.conductorId!,
      cobrar - comision,
      'Pago de viaje ${viaje.id}',
      clave: 'liberar-viaje:${viaje.id}',
    );

    final ahora = _reloj();

    // Publicar los eventos correspondientes.
    _bus.publicar(
      PagoRealizado(
        _ids.siguiente('ev'),
        viaje.usuarioId,
        ahora,
        montoCentavos: cobrar,
        concepto: 'Viaje ${viaje.id}',
        origen: Servicio.transporte,
      ),
    );

    _bus.publicar(
      ViajeFinalizado(
        _ids.siguiente('ev'),
        viaje.usuarioId,
        ahora,
        viajeId: viaje.id,
        montoCentavos: cobrar,
      ),
    );

    return _guardar(terminado);
  }

  /// Cancela un viaje y aplica el cargo correspondiente.
  Viaje cancelar(String id) {
    final viaje = _viajes[id]!;

    // Primero validar que se pueda cancelar.
    final cancelado = viaje._a(EstadoViaje.cancelado);

    // Si ya había conductor, se aplica una tarifa.
    if (viaje.estado == EstadoViaje.aceptado) {
      final saldo = _monedero.saldo(viaje.usuarioId);

      final cargo = saldo < Tarifa.cancelacionCentavos
          ? saldo
          : Tarifa.cancelacionCentavos;

      if (cargo > 0) {
        _monedero.transferir(
          viaje.usuarioId,
          viaje.conductorId!,
          cargo,
          'Cancelación ${viaje.id}',
          clave: 'cancela:${viaje.id}',
        );
      }
    }

    return _guardar(cancelado);
  }

  /// Actualiza el viaje dentro del registro.
  Viaje _guardar(Viaje viaje) {
    return _viajes[viaje.id] = viaje;
  }
}
