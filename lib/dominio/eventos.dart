enum Servicio {
  mensajeria('Mensajes', '💬'),
  pagos('Monedero', '👛'),
  comercio('Tienda', '🛍️'),
  transporte('Viajes', '🚕');

  final String nombre;
  final String emoji;

  const Servicio(this.nombre, this.emoji);
}

/// Hechos que ocurren en la plataforma.
/// Los demás servicios reaccionan mediante eventos.
sealed class EventoApp {
  final String id;
  final String usuarioId;
  final DateTime fecha;

  const EventoApp(this.id, this.usuarioId, this.fecha);

  Servicio get servicio;

  /// Recibir dinero no se considera actividad del usuario.
  bool get cuentaComoUso => true;
}

/// Se publica cuando un usuario realiza un pago.
class PagoRealizado extends EventoApp {
  final int montoCentavos;
  final String concepto;
  final Servicio origen;

  const PagoRealizado(
    super.id,
    super.usuarioId,
    super.fecha, {
    required this.montoCentavos,
    required this.concepto,
    required this.origen,
  });

  @override
  Servicio get servicio => origen;
}

/// Se publica cuando se crea un pedido.
class PedidoCreado extends EventoApp {
  final String pedidoId;
  final int totalCentavos;

  const PedidoCreado(
    super.id,
    super.usuarioId,
    super.fecha, {
    required this.pedidoId,
    required this.totalCentavos,
  });

  @override
  Servicio get servicio => Servicio.comercio;
}

/// Se publica cuando finaliza un viaje.
class ViajeFinalizado extends EventoApp {
  final String viajeId;
  final int montoCentavos;

  const ViajeFinalizado(
    super.id,
    super.usuarioId,
    super.fecha, {
    required this.viajeId,
    required this.montoCentavos,
  });

  @override
  Servicio get servicio => Servicio.transporte;
}

/// Se publica cuando se envía un mensaje.
class MensajeEnviado extends EventoApp {
  final String para;

  const MensajeEnviado(
    super.id,
    super.usuarioId,
    super.fecha, {
    required this.para,
  });

  @override
  Servicio get servicio => Servicio.mensajeria;
}

/// Se publica cuando un usuario recibe dinero.
class DineroRecibido extends EventoApp {
  final String de;
  final int montoCentavos;

  const DineroRecibido(
    super.id,
    super.usuarioId,
    super.fecha, {
    required this.de,
    required this.montoCentavos,
  });

  @override
  Servicio get servicio => Servicio.pagos;

  @override
  bool get cuentaComoUso => false;
}

/// Generador de identificadores consecutivos.
class Ids {
  int _n = 0;

  String siguiente(String prefijo) {
    return '$prefijo-${++_n}';
  }
}

/// Permite publicar eventos y suscribirse a sus tipos.
/// Un suscriptor que falla no detiene a los demás.
class BusEventos {
  final List<void Function(EventoApp)> _suscriptores = [];

  final List<Object> errores = [];

  /// Registra un manejador para un tipo específico.
  void suscribir<T extends EventoApp>(void Function(T) manejador) {
    _suscriptores.add((e) {
      if (e is T) {
        manejador(e);
      }
    });
  }

  /// Publica un evento para los suscriptores.
  void publicar(EventoApp e) {
    for (final s in List.of(_suscriptores)) {
      try {
        s(e);
      } catch (err) {
        errores.add(err);
      }
    }
  }
}
