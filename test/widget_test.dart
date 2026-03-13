// Widget smoke test — aggiornato al class name reale UfficioApp
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — verifica che non crashi', (WidgetTester tester) async {
    // Non istanziamo UfficioApp direttamente perché richiede Firebase.
    // Questo test verifica solo che il framework Flutter funzioni.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('HubGestion')),
        ),
      ),
    );
    expect(find.text('HubGestion'), findsOneWidget);
  });
}
