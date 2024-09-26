import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dh_schedule_generatorutb/main.dart';

void main() {
  testWidgets('La aplicación se carga y muestra el título',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Generador de horarios UTB'), findsOneWidget);
  });
}
