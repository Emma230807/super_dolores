import 'dinero.dart';
import 'eventos.dart';

enum TipoNotificacion { transaccional, promocional }

/// Representa una notificación para un usuario.
class Notificacion {
  final String usuarioId;
  final TipoNotificacion tipo;
  final String titulo;
  final String cuerpo;
  final DateTime fecha;

  const Notificacion(
    this.usuarioId,
    this.tipo,
    this.titulo,
    this.cuerpo,
    this.fecha,
  );
}

/// Controla las notificaciones y evita promociones excesivas.
class Notificador {
  static const int maxPromocionalesPorDia = 2;
  static const int silencioDesde = 22;
  static const int silencioHasta = 8;

  final List<Notificacion> enviadas = [];
  final Set<String> _sinPromociones = {};

  /// Permite activar o desactivar promociones por usuario.
  void configurarPromociones(String usuarioId, {required bool activas}) {
    if (activas) {
      _sinPromociones.remove(usuarioId);
    } else {
      _sinPromociones.add(usuarioId);
    }
  }

  /// Comprueba si una hora está dentro del silencio.
  static bool enHorarioDeSilencio(DateTime fecha) {
    return fecha.hour >= silencioDesde || fecha.hour < silencioHasta;
  }

  /// Intenta registrar una notificación.
  /// Devuelve true si fue aceptada.
  bool intentar(Notificacion notificacion) {
    if (notificacion.tipo == TipoNotificacion.promocional) {
      if (_sinPromociones.contains(notificacion.usuarioId)) {
        return false;
      }

      if (enHorarioDeSilencio(notificacion.fecha)) {
        return false;
      }

      final hoy = soloFecha(notificacion.fecha);

      final yaEnviadas = enviadas.where((n) {
        return n.usuarioId == notificacion.usuarioId &&
            n.tipo == TipoNotificacion.promocional &&
            soloFecha(n.fecha) == hoy;
      }).length;

      if (yaEnviadas >= maxPromocionalesPorDia) {
        return false;
      }
    }

    enviadas.add(notificacion);
    return true;
  }

  /// Obtiene los avisos de un usuario, recientes primero.
  List<Notificacion> de(String usuarioId) {
    return enviadas
        .where((n) => n.usuarioId == usuarioId)
        .toList()
        .reversed
        .toList();
  }

  /// Genera avisos transaccionales a partir de eventos.
  void conectar(BusEventos bus) {
    bus.suscribir<DineroRecibido>((e) {
      intentar(
        Notificacion(
          e.usuarioId,
          TipoNotificacion.transaccional,
          'Te llegó dinero',
          '${e.de} te envió '
              '${formatearPesos(e.montoCentavos)}',
          e.fecha,
        ),
      );
    });

    bus.suscribir<ViajeFinalizado>((e) {
      intentar(
        Notificacion(
          e.usuarioId,
          TipoNotificacion.transaccional,
          'Viaje finalizado',
          'Total: ${formatearPesos(e.montoCentavos)}',
          e.fecha,
        ),
      );
    });

    bus.suscribir<PedidoCreado>((e) {
      intentar(
        Notificacion(
          e.usuarioId,
          TipoNotificacion.transaccional,
          'Pedido confirmado',
          'Pedido ${e.pedidoId} por '
              '${formatearPesos(e.totalCentavos)}',
          e.fecha,
        ),
      );
    });
  }
}
