import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nphotos/screens/settings/nphotos_about_screen.dart';
import 'package:nphotos/screens/settings/nphotos_permissions.dart';

void main() {
  testWidgets('About muestra la app y sus secciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NPhotosAboutScreen()));
    await tester.pump();
    expect(find.text('NPhotos'), findsOneWidget);
    expect(find.textContaining('26.09.28-release'), findsOneWidget);
    expect(find.text('Gestión de permisos'), findsOneWidget);
    expect(find.text('Revocar todos los permisos'), findsOneWidget);
    expect(find.text('Canal de Telegram'), findsOneWidget);
  });

  testWidgets('Permisos en escritorio se declara gestionado por el sistema',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: NPhotosPermissionsScreen()),
      );
      await tester.pump();
      expect(find.text('Gestión de permisos'), findsWidgets);
      // En Linux no hay runtime permissions: estado honesto.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Gestionado por el sistema'), findsOneWidget);
    },
  );
}
