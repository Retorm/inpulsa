import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_ventas/main.dart'; // Importa nuestra aplicación

void main() {
  testWidgets('Prueba de carga inicial de la app de ventas', (
    WidgetTester tester,
  ) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await tester.pumpWidget(const MiAppVentas());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(Scaffold), findsWidgets);
  });
}
