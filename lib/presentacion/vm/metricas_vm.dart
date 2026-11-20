import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../dominio/analitica.dart';
import '../../dominio/dinero.dart';
import '../../dominio/eventos.dart';

/// Genera actividad ficticia con una semilla fija.
/// No representa usuarios reales.
Analitica simularUso({
  required DateTime inicio,
  int usuarios = 200,
  int dias = 30,
  int semilla = 42,
}) {
  final rnd = Random(semilla);
  final analitica = Analitica();

  for (var u = 0; u < usuarios; u++) {
    final llegada = rnd.nextInt(dias - 14);
    final motivacion = rnd.nextDouble();

    const servicios = Servicio.values;

    final cuantos = 1 + (motivacion * 3.2).floor().clamp(0, 3).toInt();

    final favoritos = ([...servicios]..shuffle(rnd)).take(cuantos).toList();

    for (var d = llegada; d < dias; d++) {
      final probabilidad = d == llegada
          ? 1.0
          : (0.15 + 0.7 * motivacion) * pow(0.97, d - llegada);

      if (rnd.nextDouble() < probabilidad) {
        analitica.agregar(
          RegistroUso(
            'u$u',
            favoritos[rnd.nextInt(favoritos.length)],
            masDias(inicio, d),
          ),
        );
      }
    }
  }

  return analitica;
}

/// ViewModel de estadísticas sintéticas.
class MetricasViewModel extends ChangeNotifier {
  final DateTime inicio;

  MetricasViewModel(this.inicio);

  late final Analitica analitica = simularUso(inicio: inicio);

  DateTime get ultimoDia => masDias(inicio, 29);

  int get dau => analitica.dau(ultimoDia);

  int get wau => analitica.wau(ultimoDia);

  int get mau => analitica.mau(ultimoDia);

  double get stickiness => analitica.stickiness(ultimoDia);

  double get serviciosPorUsuario =>
      analitica.serviciosPorUsuario(inicio, ultimoDia);

  double get multiservicio =>
      analitica.porcentajeMultiservicio(inicio, ultimoDia);

  /// Promedio de retención de las cohortes con usuarios.
  double retencionPromedio(int n) {
    final tasas = <double>[];

    for (var d = 0; d < 30 - n; d++) {
      final fecha = masDias(inicio, d);

      if (analitica.cohorte(fecha).isNotEmpty) {
        tasas.add(analitica.retencion(fecha, n));
      }
    }

    if (tasas.isEmpty) {
      return 0;
    }

    return tasas.reduce((a, b) => a + b) / tasas.length;
  }

  /// Comparación de retención por variedad de servicios.
  ({double unServicio, double multiservicio, int nUno, int nMulti})
  get comparacion =>
      analitica.retencionSemana2PorServicios(inicio, masDias(inicio, 14));
}
