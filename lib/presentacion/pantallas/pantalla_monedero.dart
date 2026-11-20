import 'package:flutter/material.dart';

import '../../dominio/contexto.dart';
import '../../dominio/dinero.dart';
import '../../dominio/plataforma.dart';
import '../vm/monedero_vm.dart';
import 'widgets.dart';

class PantallaMonedero extends StatefulWidget {
  final ContextoMiniApp contexto;
  final VoidCallback alCambiar;
  final Plataforma plataforma;

  const PantallaMonedero({
    super.key,
    required this.contexto,
    required this.alCambiar,
    required this.plataforma,
  });

  @override
  State<PantallaMonedero> createState() => _PantallaMonederoState();
}

class _PantallaMonederoState extends State<PantallaMonedero> {
  late final MonederoViewModel vm = MonederoViewModel(
    widget.contexto,
    alCambiar: widget.alCambiar,
  );

  final _monto = TextEditingController(text: '100');
  String? _para;

  @override
  void dispose() {
    _monto.dispose();
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otros = widget.plataforma.perfiles
        .where((p) => p.id != widget.contexto.usuarioId)
        .toList();

    _para ??= otros.first.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Monedero')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                formatearPesos(vm.saldo),
                style: Theme.of(context).textTheme.displaySmall,
              ),

              const Text('Saldo de práctica. No es dinero real.'),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _para,
                decoration: const InputDecoration(
                  labelText: 'Destinatario',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final p in otros)
                    DropdownMenuItem(value: p.id, child: Text(p.nombre)),
                ],
                onChanged: (valor) {
                  setState(() => _para = valor);
                },
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _monto,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto en pesos',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed: vm.ocupado
                    ? null
                    : () async {
                        final pesos = int.tryParse(_monto.text) ?? 0;

                        await vm.enviarDinero(_para!, pesos * 100);
                      },
                icon: const Icon(Icons.send),
                label: const Text('Enviar dinero'),
              ),

              Aviso(vm.error),

              if (vm.exito != null)
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(vm.exito!),
                ),

              const Divider(),

              Text(
                'Movimientos',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              for (final m in vm.movimientos)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.receipt_long),
                  title: Text(m.concepto),
                  subtitle: Text(m.tipo.name),
                  trailing: Text(formatearPesos(m.montoCentavos)),
                ),
            ],
          );
        },
      ),
    );
  }
}
