import 'package:flutter/material.dart';

import '../../dominio/contexto.dart';
import '../../dominio/dinero.dart';
import '../../dominio/transporte.dart';
import '../vm/viajes_vm.dart';
import 'widgets.dart';

class PantallaViajes extends StatefulWidget {
  final ContextoMiniApp contexto;
  final VoidCallback alCambiar;

  const PantallaViajes({
    super.key,
    required this.contexto,
    required this.alCambiar,
  });

  @override
  State<PantallaViajes> createState() => _PantallaViajesState();
}

class _PantallaViajesState extends State<PantallaViajes> {
  late final ViajesViewModel vm = ViajesViewModel(
    widget.contexto,
    alCambiar: widget.alCambiar,
  );

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  Widget _selector(
    String etiqueta,
    Lugar valor,
    void Function(Lugar) alElegir,
  ) {
    return DropdownButtonFormField<Lugar>(
      initialValue: valor,
      decoration: InputDecoration(
        labelText: etiqueta,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final lugar in lugaresDolores)
          DropdownMenuItem(value: lugar, child: Text(lugar.nombre)),
      ],
      onChanged: (lugar) {
        if (lugar != null) {
          alElegir(lugar);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viajes')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final viaje = vm.actual;

          final activo =
              viaje != null &&
              viaje.estado != EstadoViaje.finalizado &&
              viaje.estado != EstadoViaje.cancelado;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _selector(
                'Origen',
                vm.origen,
                (lugar) => vm.elegir(nuevoOrigen: lugar),
              ),

              const SizedBox(height: 12),

              _selector(
                'Destino',
                vm.destino,
                (lugar) => vm.elegir(nuevoDestino: lugar),
              ),

              const SizedBox(height: 12),

              Text(
                '${vm.distancia.toStringAsFixed(1)} km'
                ' · Estimado ${formatearPesos(vm.estimado)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 12),

              if (!activo)
                FilledButton.icon(
                  onPressed: vm.solicitar,
                  icon: const Icon(Icons.local_taxi),
                  label: const Text('Pedir viaje'),
                ),

              Aviso(vm.error),

              if (viaje != null) ...[
                const Divider(),

                Text(
                  'Estado: ${viaje.estado.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                if (viaje.cobradoCentavos != null)
                  Text('Cobrado: ${formatearPesos(viaje.cobradoCentavos!)}'),

                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (viaje.estado == EstadoViaje.solicitado)
                      OutlinedButton(
                        onPressed: vm.conductorAcepta,
                        child: const Text('(Simular) conductor acepta'),
                      ),

                    if (viaje.estado == EstadoViaje.aceptado)
                      OutlinedButton(
                        onPressed: vm.iniciar,
                        child: const Text('(Simular) iniciar'),
                      ),

                    if (viaje.estado == EstadoViaje.enCurso)
                      FilledButton(
                        onPressed: vm.finalizar,
                        child: const Text('(Simular) llegar y pagar'),
                      ),

                    if (viaje.estado == EstadoViaje.solicitado ||
                        viaje.estado == EstadoViaje.aceptado)
                      TextButton(
                        onPressed: vm.cancelar,
                        child: const Text('Cancelar'),
                      ),
                  ],
                ),
              ],

              const Divider(),

              Text('Historial', style: Theme.of(context).textTheme.titleMedium),

              for (final v in vm.historial)
                ListTile(
                  dense: true,
                  title: Text(v.id),
                  subtitle: Text(v.estado.name),
                ),
            ],
          );
        },
      ),
    );
  }
}
