import 'package:flutter_test/flutter_test.dart';

import 'package:web_materiales/main.dart';

void main() {
  testWidgets('La aplicación de consulta de materiales SAP inicia correctamente',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WebMaterialesApp());

    expect(find.text('Consulta de materiales SAP'), findsOneWidget);
    expect(find.text('Consulta individual'), findsOneWidget);
    expect(find.text('Consulta por rangos'), findsOneWidget);
  });
}
