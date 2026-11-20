import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_dolores/main.dart';

void main() {
  testWidgets('Super Dolores muestra la pantalla principal', (tester) async {
    await tester.pumpWidget(const SuperDoloresApp());

    expect(find.text('Super Dolores'), findsOneWidget);

    expect(find.text('Hola, Ana 👋'), findsOneWidget);

    expect(find.byIcon(Icons.home), findsWidgets);

    expect(find.textContaining('Saldo de práctica'), findsOneWidget);
  });
}
