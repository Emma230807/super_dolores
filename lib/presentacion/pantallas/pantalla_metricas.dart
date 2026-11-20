import 'package:flutter/material.dart';

import '../vm/metricas_vm.dart';

class PantallaMetricas extends StatefulWidget {
  const PantallaMetricas({super.key});

  @override
  State<PantallaMetricas> createState() => _PantallaMetricasState();
}

class _PantallaMetricasState extends State<PantallaMetricas> {
  late final MetricasViewModel vm = MetricasViewModel(DateTime(2026, 1, 1));

  String _porcentaje(double valor) {
    return '${(valor * 100).toStringAsFixed(1)}%';
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comparacion = vm.comparacion;

    return Scaffold(
      appBar: AppBar(title: const Text('Tablero de retención')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '⚠️ Datos SIMULADOS con semilla fija '
                '(200 usuarios inventados). Sirven para '
                'aprender a interpretar métricas, no para '
                'sacar conclusiones reales.',
              ),
            ),
          ),

          ListTile(
            title: const Text('DAU (activos hoy)'),
            trailing: Text('${vm.dau}'),
          ),

          ListTile(
            title: const Text('WAU (últimos 7 días)'),
            trailing: Text('${vm.wau}'),
          ),

          ListTile(
            title: const Text('MAU (últimos 30 días)'),
            trailing: Text('${vm.mau}'),
          ),

          ListTile(
            title: const Text('Stickiness DAU/MAU'),
            trailing: Text(_porcentaje(vm.stickiness)),
          ),

          ListTile(
            title: const Text('Retención D1 promedio'),
            trailing: Text(_porcentaje(vm.retencionPromedio(1))),
          ),

          ListTile(
            title: const Text('Retención D7 promedio'),
            trailing: Text(_porcentaje(vm.retencionPromedio(7))),
          ),

          ListTile(
            title: const Text('Servicios por usuario'),
            trailing: Text(vm.serviciosPorUsuario.toStringAsFixed(2)),
          ),

          ListTile(
            title: const Text('% usuarios multiservicio'),
            trailing: Text(_porcentaje(vm.multiservicio)),
          ),

          const Divider(),

          Text(
            'Semana 2 según servicios usados en la semana 1',
            style: Theme.of(context).textTheme.titleMedium,
          ),

          ListTile(
            title: Text('1 servicio (n=${comparacion.nUno})'),
            trailing: Text(_porcentaje(comparacion.unServicio)),
          ),

          ListTile(
            title: Text('2 o más servicios (n=${comparacion.nMulti})'),
            trailing: Text(_porcentaje(comparacion.multiservicio)),
          ),

          const Text(
            'Estas cifras muestran una correlación, '
            'no una relación de causa y efecto. '
            'Se necesitaría un experimento controlado '
            'para investigar la causalidad.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
