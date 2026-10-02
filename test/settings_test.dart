import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'permisos_test_helper.dart';
import 'package:NPhotos/screens/settings/nphotos_about_screen.dart';
import 'package:NPhotos/screens/settings/nphotos_permissions_screen.dart';

void main() {
  testWidgets('About muestra la app y sus secciones', (
    WidgetTester tester,
  ) async {
    // La pantalla es un `ListView` y los avisos beta de NexoraUi añaden
    // altura: con el viewport por defecto la sección de comunidad queda
    // sin construir y el test falla por algo que sí está en pantalla.
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: NPhotosAboutScreen(permissions: testPermissions()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NPhotos'), findsOneWidget);
    expect(find.textContaining('26.09.28-release'), findsOneWidget);
    expect(find.text('Gestión de permisos'), findsOneWidget);
    expect(find.text('Revocar todos los permisos'), findsOneWidget);
    expect(find.text('Canal de Telegram'), findsOneWidget);
  });

  testWidgets('Permisos en escritorio se declara gestionado por el sistema',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NPhotosPermissionsScreen(permissions: testPermissions()),
        ),
      );
      await tester.pump();
      expect(find.text('Gestión de permisos'), findsWidgets);
      // En Linux no hay runtime permissions: estado honesto.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Gestionado por el sistema'), findsOneWidget);
    },
  );
}
