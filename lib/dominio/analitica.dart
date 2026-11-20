import 'dinero.dart';
import 'eventos.dart';

/// Registro de actividad de un usuario.
class RegistroUso {
  final String usuarioId;
  final Servicio servicio;
  final DateTime fecha;

  const RegistroUso(this.usuarioId, this.servicio, this.fecha);
}

/// Calcula métricas de actividad y retención.
class Analitica {
  final List<RegistroUso> registros = [];

  /// Escucha los eventos de los servicios.
  void conectar(BusEventos bus) {
    bus.suscribir<EventoApp>((evento) {
      if (evento.cuentaComoUso) {
        registros.add(
          RegistroUso(evento.usuarioId, evento.servicio, evento.fecha),
        );
      }
    });
  }

  /// Agrega un registro de uso manualmente.
  void agregar(RegistroUso registro) {
    registros.add(registro);
  }

  /// Usuarios activos entre dos fechas.
  Set<String> _activosEntre(DateTime desde, DateTime hasta) {
    return {
      for (final r in registros)
        if (!soloFecha(r.fecha).isBefore(soloFecha(desde)) &&
            !soloFecha(r.fecha).isAfter(soloFecha(hasta)))
          r.usuarioId,
    };
  }

  /// Usuarios activos durante un día.
  int dau(DateTime dia) {
    return _activosEntre(dia, dia).length;
  }

  /// Usuarios activos en los últimos 7 días.
  int wau(DateTime dia) {
    return _activosEntre(masDias(dia, -6), dia).length;
  }

  /// Usuarios activos en los últimos 30 días.
  int mau(DateTime dia) {
    return _activosEntre(masDias(dia, -29), dia).length;
  }

  /// Proporción de usuarios mensuales activos hoy.
  double stickiness(DateTime dia) {
    final mensual = mau(dia);

    if (mensual == 0) {
      return 0;
    }

    return dau(dia) / mensual;
  }

  /// Primer día de actividad de un usuario.
  DateTime? primerDia(String usuario) {
    DateTime? menor;

    for (final r in registros) {
      if (r.usuarioId != usuario) {
        continue;
      }

      final fecha = soloFecha(r.fecha);

      if (menor == null || fecha.isBefore(menor)) {
        menor = fecha;
      }
    }

    return menor;
  }

  /// Usuarios cuya primera actividad ocurrió ese día.
  Set<String> cohorte(DateTime dia) {
    final fecha = soloFecha(dia);

    return {
      for (final usuario in registros.map((r) => r.usuarioId).toSet())
        if (primerDia(usuario) == fecha) usuario,
    };
  }

  /// Retención exacta después de N días.
  double retencion(DateTime dia, int n) {
    final usuarios = cohorte(dia);

    if (usuarios.isEmpty) {
      return 0;
    }

    final objetivo = masDias(soloFecha(dia), n);

    final volvieron = _activosEntre(
      objetivo,
      objetivo,
    ).where(usuarios.contains).length;

    return volvieron / usuarios.length;
  }

  /// Promedio de servicios distintos por usuario activo.
  double serviciosPorUsuario(DateTime desde, DateTime hasta) {
    final por = _serviciosPorUsuario(desde, hasta);

    if (por.isEmpty) {
      return 0;
    }

    final cantidad = por.values.fold<int>(
      0,
      (s, servicios) => s + servicios.length,
    );

    return cantidad / por.length;
  }

  /// Proporción de usuarios que utilizan varios servicios.
  double porcentajeMultiservicio(
    DateTime desde,
    DateTime hasta, {
    int minimo = 2,
  }) {
    final por = _serviciosPorUsuario(desde, hasta);

    if (por.isEmpty) {
      return 0;
    }

    final usuarios = por.values
        .where((servicios) => servicios.length >= minimo)
        .length;

    return usuarios / por.length;
  }

  /// Agrupa los servicios utilizados por usuario.
  Map<String, Set<Servicio>> _serviciosPorUsuario(
    DateTime desde,
    DateTime hasta,
  ) {
    final por = <String, Set<Servicio>>{};

    for (final r in registros) {
      final dia = soloFecha(r.fecha);

      if (dia.isBefore(soloFecha(desde)) || dia.isAfter(soloFecha(hasta))) {
        continue;
      }

      (por[r.usuarioId] ??= {}).add(r.servicio);
    }

    return por;
  }

  /// Compara retención entre quienes usaron
  /// uno o varios servicios durante su primera semana.
  ///
  /// Es una correlación, no una prueba de causalidad.
  ({double unServicio, double multiservicio, int nUno, int nMulti})
  retencionSemana2PorServicios(DateTime desde, DateTime hasta) {
    var nUno = 0;
    var nMulti = 0;
    var retUno = 0;
    var retMulti = 0;

    final usuarios = registros.map((r) => r.usuarioId).toSet();

    for (final usuario in usuarios) {
      final primero = primerDia(usuario)!;

      if (primero.isBefore(soloFecha(desde)) ||
          primero.isAfter(soloFecha(hasta))) {
        continue;
      }

      final semana1 = <Servicio>{};
      var retenido = false;

      for (final r in registros) {
        if (r.usuarioId != usuario) {
          continue;
        }

        final fecha = soloFecha(r.fecha);

        final diferencia = _diasEntre(primero, fecha);

        // Primera semana: días 0 a 6.
        if (diferencia >= 0 && diferencia <= 6) {
          semana1.add(r.servicio);
        }

        // Segunda semana: días 7 a 13.
        if (diferencia >= 7 && diferencia <= 13) {
          retenido = true;
        }
      }

      if (semana1.length >= 2) {
        nMulti++;

        if (retenido) {
          retMulti++;
        }
      } else {
        nUno++;

        if (retenido) {
          retUno++;
        }
      }
    }

    return (
      unServicio: nUno == 0 ? 0 : retUno / nUno,
      multiservicio: nMulti == 0 ? 0 : retMulti / nMulti,
      nUno: nUno,
      nMulti: nMulti,
    );
  }

  /// Días de calendario entre dos fechas.
  static int _diasEntre(DateTime a, DateTime b) {
    final inicio = DateTime.utc(a.year, a.month, a.day);

    final fin = DateTime.utc(b.year, b.month, b.day);

    return fin.difference(inicio).inDays;
  }
}
