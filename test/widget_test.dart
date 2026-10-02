import 'package:NexoraCore/NexoraCore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:NexoraUi/NexoraUi.dart';
import 'permisos_test_helper.dart';
import 'package:NPhotos/app/nphotos_app.dart';
import 'package:NPhotos/models/photo.dart';
import 'package:NPhotos/screens/settings/nphotos_settings_screen.dart';

void main() {
  group('Photo', () {
    Photo testPhoto() => Photo(
      id: '/tmp/a.jpg',
      path: '/tmp/a.jpg',
      title: 'a.jpg',
      dateCreated: DateTime(2024, 1, 2),
      dateModified: DateTime(2024, 1, 3),
      sizeInBytes: 1024,
    );

    test('copyWith conserva los campos no indicados', () {
      final photo = testPhoto();
      final copy = photo.copyWith();

      expect(copy.id, photo.id);
      expect(copy.path, photo.path);
      expect(copy.title, photo.title);
      expect(copy.isFavorite, isFalse);
    });

    test('copyWith aplica el cambio de favorito', () {
      final photo = testPhoto();
      expect(photo.copyWith(isFavorite: true).isFavorite, isTrue);
    });
  });

  group('Clasificación de familias (NexoraCore)', () {
    // Estas comprobaciones ya no viven en la app: la familia de un
    // archivo la decide `NexoraCore` con un único `kindForPath`, así que
    // duplicar aquí la lista de extensiones sería justo lo que este
    // refactor elimina.
    test('las fotos se clasifican como imagen y no como vídeo', () {
      expect(kindForPath('/a/b.jpg'), FileKind.image);
      expect(kindForPath('/a/b.png'), FileKind.image);
      expect(kindForPath('/a/b.mp4'), isNot(FileKind.image));
      expect(kindForPath('/a/b.txt'), isNot(FileKind.image));
    });

    test('los vídeos se clasifican como vídeo y el resto no', () {
      expect(kindForPath('/a/b.mp4'), FileKind.video);
      expect(kindForPath('/a/b.mov'), FileKind.video);
      expect(kindForPath('/a/b.jpg'), isNot(FileKind.video));
    });
  });

  testWidgets('NPhotosApp en móvil usa NMobileLayout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(NPhotosApp(permissions: testPermissions()));
    await tester.pump();

    expect(find.byType(NMobileLayout), findsOneWidget);
    // Título del top bar móvil.
    expect(find.text('NPhotos'), findsOneWidget);
    // La bottom bar muestra iconos (y etiqueta en la pestaña activa).
    // Favoritos vive solo en Álbumes, no navega.
    expect(find.byIcon(Icons.photo), findsOneWidget);
    expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);
  });

  testWidgets('NPhotosApp navega a Colecciones', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(NPhotosApp(permissions: testPermissions()));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.collections_bookmark_outlined));
    await tester.pump();

    expect(find.text('Añadidos recientemente'), findsOneWidget);
    expect(find.text('Lugares'), findsOneWidget);
    expect(find.text('Documentos'), findsOneWidget);
    expect(find.text('Alta definición'), findsOneWidget);
    expect(find.text('Personas'), findsOneWidget);
    expect(find.text('Carpeta privada'), findsOneWidget);
    // Vídeos y Papelera viven pineados en Álbumes, no en Colecciones.
    expect(find.text('Vídeos'), findsNothing);
    expect(find.text('Papelera'), findsNothing);
  });

  testWidgets('Ajustes en móvil muestra solo la base del kit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: NPhotosSettingsScreen(permissions: testPermissions()),
      ),
    );
    await tester.pump();

    // Release: sin secciones propias (eran botones muertos).
    // Solo la sección base aportada por el kit.
    await tester.scrollUntilVisible(find.text('Ajustes adicionales'), 300);
    expect(find.text('Ajustes adicionales'), findsOneWidget);
    expect(find.text('Sobre NPhotos'), findsOneWidget);
    expect(find.text('Cuenta'), findsNothing);
    expect(find.text('Idioma'), findsNothing);
    expect(find.text('Nube'), findsNothing);
    expect(find.text('Organización inteligente'), findsNothing);
    expect(find.text('Explorar y compartir'), findsNothing);
  });

  testWidgets('Ajustes en desktop usa el contenido del kit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: NPhotosSettingsScreen(permissions: testPermissions()),
      ),
    );
    await tester.pump();

    expect(find.byType(NSettingsContent), findsOneWidget);
    expect(find.text('Ajustes adicionales'), findsOneWidget);
  });

  testWidgets('NPhotosApp en desktop usa NDesktopLayout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(NPhotosApp(permissions: testPermissions()));
    await tester.pump();

    expect(find.byType(NDesktopLayout), findsOneWidget);
    expect(find.byType(NDesktopSidebar), findsOneWidget);
    // Sidebar: Fotos, Álbumes + contenido de Colecciones
    // aplanado (sin entrada padre). Topbar de escritorio visible.
    // Favoritos vive solo en Álbumes, no navega.
    expect(find.byIcon(Icons.photo), findsOneWidget);
    expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
    expect(find.byIcon(Icons.access_time_outlined), findsOneWidget);
    expect(find.byIcon(Icons.people_outline), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.hd_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Colecciones'), findsNothing);
    expect(find.byIcon(Icons.videocam_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byType(NDesktopTopBar), findsOneWidget);
  });

  testWidgets('NPhotoViewer deja altura al contenido y pie compacto', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NPhotoViewer(
          title: 'Septiembre 27, 2026',
          subtitle: '15:34',
          // Hijo que expande como el PageView real (ColoredBox sin hijo
          // colapsa a cero por sí solo y no sirve para esta regresión).
          onShare: () {},
          onDelete: () {},
          onFavoriteToggle: () {},
          child: const SizedBox.expand(
            key: Key('viewer-body'),
            child: ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );
    await tester.pump();

    // Regresión: el pie flotante no debe robarle la altura al contenido
    // (el Center anterior expandía el bottomNavigationBar y el body
    // quedaba a cero, sin imagen).
    final bodySize = tester.getSize(find.byKey(const Key('viewer-body')));
    expect(bodySize.height, greaterThan(0));

    // Acciones con callback se muestran; sin callback (Editar) se oculta.
    expect(find.byTooltip('Compartir'), findsOneWidget);
    expect(find.byTooltip('Editar'), findsNothing);
    expect(find.byTooltip('Borrar'), findsOneWidget);
    expect(find.byTooltip('Favorito'), findsOneWidget);
  });
}
