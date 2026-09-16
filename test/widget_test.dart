import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexora_photos/src/widgets/photo_grid.dart';

void main() {
  testWidgets('Grid vacío muestra estado vacío', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ThumbnailGrid(photos: [])),
      ),
    );
    expect(find.text('No hay fotos aún'), findsOneWidget);
  });
}