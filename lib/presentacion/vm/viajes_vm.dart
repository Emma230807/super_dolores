import 'package:flutter/foundation.dart';

import '../../dominio/contexto.dart';
import '../../dominio/excepciones.dart';
import '../../dominio/transporte.dart';

/// Lugar disponible en el transporte simulado.
class Lugar {
  final String nombre;
  final Punto punto;

  const Lugar(this.nombre, this.punto);
}

/// Lugares de práctica en Dolores Hidalgo.
const lugaresDolores = <Lugar>[
  Lugar('Jardín Principal', Punto(21.1561, -100.9333)),
  Lugar('Parroquia de Dolores', Punto(21.1565, -100.9339)),
  Lugar('Terminal de autobuses', Punto(21.1637, -100.9411)),
  Lugar('UTNG', Punto(21.1325, -100.9267)),
  Lugar('Mercado Municipal', Punto(21.1552, -100.9301)),
];

/// ViewModel de viajes.
class ViajesViewModel extends ChangeNotifier {
  final ContextoMiniApp _contexto;
  final VoidCallback? alCambiar;

  ViajesViewModel(this._contexto, {this.alCambiar});

  Lugar origen = lugaresDolores[0];
  Lugar destino = lugaresDolores[3];

  Viaje? actual;
  String? error;

  int get estimado => _contexto.viajes.estimar(origen.punto, destino.punto);

  double get distancia => distanciaKm(origen.punto, destino.punto);

  List<Viaje> get historial => _contexto.viajes.misViajes();

  /// Selecciona el origen o destino.
  void elegir({Lugar? nuevoOrigen, Lugar? nuevoDestino}) {
    origen = nuevoOrigen ?? origen;
    destino = nuevoDestino ?? destino;

    notifyListeners();
  }

  /// Ejecuta una operación y captura errores seguros.
  void _hacer(Viaje Function() accion) {
    try {
      actual = accion();
      error = null;

      alCambiar?.call();
    } catch (e) {
      error = mensajeSeguro(e);
    }

    notifyListeners();
  }

  /// Solicita un nuevo viaje.
  void solicitar() {
    if (origen == destino) {
      error = 'El origen y el destino no pueden ser iguales.';

      notifyListeners();
      return;
    }

    _hacer(() => _contexto.viajes.solicitar(origen.punto, destino.punto));
  }

  /// El conductor acepta el viaje.
  void conductorAcepta() {
    _hacer(() => _contexto.viajes.aceptar(actual!.id, 'conductor1'));
  }

  /// Inicia el viaje.
  void iniciar() {
    _hacer(() => _contexto.viajes.iniciar(actual!.id));
  }

  /// Finaliza el viaje utilizando distancia y tiempo.
  void finalizar() {
    _hacer(() {
      final km = distancia;

      return _contexto.viajes.finalizar(
        actual!.id,
        km: km,
        minutos: Tarifa.minutosEstimados(km),
      );
    });
  }

  /// Cancela el viaje.
  void cancelar() {
    _hacer(() => _contexto.viajes.cancelar(actual!.id));
  }
}
