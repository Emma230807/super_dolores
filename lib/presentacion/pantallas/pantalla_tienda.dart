import 'package:flutter/material.dart';

import '../../dominio/contexto.dart';
import '../../dominio/dinero.dart';
import '../vm/tienda_vm.dart';
import 'widgets.dart';

class PantallaTienda extends StatefulWidget {
  final ContextoMiniApp contexto;
  final VoidCallback alCambiar;

  const PantallaTienda({
    super.key,
    required this.contexto,
    required this.alCambiar,
  });

  @override
  State<PantallaTienda> createState() => _PantallaTiendaState();
}

class _PantallaTiendaState extends State<PantallaTienda> {
  late final TiendaViewModel vm = TiendaViewModel(
    widget.contexto,
    alCambiar: widget.alCambiar,
  );

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final tienda = vm.tienda;

        return Scaffold(
          appBar: AppBar(
            title: Text(tienda == null ? 'Negocios de Dolores' : tienda.nombre),
            leading: tienda == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: vm.volver,
                  ),
          ),
          body: tienda == null
              ? ListView(
                  children: [
                    for (final t in vm.tiendas)
                      ListTile(
                        leading: Text(
                          t.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: Text(t.nombre),
                        onTap: () => vm.elegirTienda(t),
                      ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final producto in tienda.productos)
                      ListTile(
                        title: Text(producto.nombre),
                        subtitle: Text(
                          '${formatearPesos(producto.precioCentavos)}'
                          ' · Quedan ${producto.existencias}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => vm.cambiar(producto.id, -1),
                            ),
                            Text('${vm.carrito[producto.id] ?? 0}'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => vm.cambiar(producto.id, 1),
                            ),
                          ],
                        ),
                      ),

                    Aviso(vm.error),

                    if (vm.ultimoPedido != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          title: Text('Pedido ${vm.ultimoPedido!.id}'),
                          subtitle: Text(
                            'Total: ${formatearPesos(vm.ultimoPedido!.totalCentavos)}',
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    FilledButton.icon(
                      onPressed: vm.carrito.isEmpty || vm.ocupado
                          ? null
                          : vm.comprar,
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: Text('Pagar ${formatearPesos(vm.total)}'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
