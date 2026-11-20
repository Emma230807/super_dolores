import 'package:flutter/foundation.dart';

import '../../dominio/dinero.dart';
import '../../dominio/eventos.dart';
import '../../dominio/lealtad.dart';
import '../../dominio/mini_app.dart';
import '../../dominio/plataforma.dart';
import '../../dominio/sugerencias.dart';

/// ViewModel de la pantalla de inicio.
class InicioViewModel extends ChangeNotifier {
  final Plataforma plataforma;
  String usuarioId;

  InicioViewModel(this.plataforma, this.usuarioId);

  /// Cambia el usuario activo.
  void cambiarUsuario(String id) {
    usuarioId = id;
    notificar();
  }

  /// Solicita actualizar la interfaz.
  void notificar() {
    notifyListeners();
  }

  int get saldo => plataforma.monedero.saldo(usuarioId);

  int get puntos => plataforma.lealtad.puntos(usuarioId);

  int get racha => plataforma.lealtad.racha(usuarioId);

  NivelLealtad get nivel => plataforma.lealtad.nivel(usuarioId);

  int get noLeidos => plataforma.mensajes.noLeidos(usuarioId);

  List<MiniApp> get miniApps => plataforma.registro.activas;

  /// Recomienda un servicio según la hora y actividad.
  Sugerencia get sugerencia {
    final usos = <Servicio, int>{};

    final hoy = soloFecha(plataforma.reloj());
    final desde = masDias(hoy, -29);

    for (final registro in plataforma.analitica.registros) {
      final fecha = soloFecha(registro.fecha);

      if (registro.usuarioId == usuarioId &&
          !fecha.isBefore(desde) &&
          !fecha.isAfter(hoy)) {
        usos[registro.servicio] = (usos[registro.servicio] ?? 0) + 1;
      }
    }

    return sugerirServicio(usosUltimos30Dias: usos, ahora: plataforma.reloj());
  }

  /// Canjea todos los puntos posibles en múltiplos de 100.
  int canjearTodo() {
    final canjeables =
        puntos ~/ Lealtad.puntosPorCanje * Lealtad.puntosPorCanje;

    if (canjeables == 0) {
      return 0;
    }

    final centavos = plataforma.lealtad.canjear(usuarioId, canjeables);

    notificar();

    return centavos;
  }
}
