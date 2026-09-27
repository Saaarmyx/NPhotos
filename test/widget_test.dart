import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_ui/nexora_ui.dart';
import 'package:nphotos/app/nphotos_app.dart';
import 'package:nphotos/models/photo.dart';
import 'package:nphotos/screens/settings/nphotos_settings_screen.dart';
import 'package:nphotos/services/photo_service.dart';

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

  group('PhotoService', () {
    test('supportedExtensions cubre formatos comunes y excluye otros', () {
      expect(PhotoService.supportedExtensions, contains('.jpg'));
      expect(PhotoService.supportedExtensions, contains('.png'));
      expect(PhotoService.supportedExtensions, isNot(contains('.mp4')));
      expect(PhotoService.supportedExtensions, isNot(contains('.txt')));
    });
  });

  testWidgets('NPhotosApp en móvil usa NMobileLayout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NPhotosApp());
    await tester.pump();

    expect(find.byType(NMobileLayout), findsOneWidget);
    // Título del top bar móvil.
    expect(find.text('NPhotos'), findsOneWidget);
    // La bottom bar muestra iconos (y etiqueta en la pestaña activa).
    expect(find.byIcon(Icons.photo), findsOneWidget);
    expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);
  });

  testWidgets('NPhotosApp navega a Colecciones', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NPhotosApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.collections_bookmark_outlined));
    await tester.pump();

    expect(find.text('Añadidos recientemente'), findsOneWidget);
    expect(find.text('Papelera'), findsOneWidget);
  });

  testWidgets('Ajustes en móvil muestra las secciones de NPhotos', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: NPhotosSettingsScreen()),
    );
    await tester.pump();

    expect(find.text('Nube'), findsOneWidget);
    expect(find.text('Organización inteligente'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Explorar y compartir'),
      300,
    );
    expect(find.text('Explorar y compartir'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('General'), 300);
    // Sección base aportada por el kit.
    expect(find.text('General'), findsOneWidget);
  });

  testWidgets('Ajustes en desktop usa el contenido del kit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: NPhotosSettingsScreen()),
    );
    await tester.pump();

    expect(find.byType(NSettingsContent), findsOneWidget);
    expect(find.text('Nube'), findsOneWidget);
  });

  testWidgets('NPhotosApp en desktop usa NDesktopLayout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NPhotosApp());
    await tester.pump();

    expect(find.byType(NDesktopLayout), findsOneWidget);
    expect(find.byType(NDesktopSidebar), findsOneWidget);
    // Mismos destinos que en móvil, más las opciones de colecciones.
    expect(find.byIcon(Icons.photo), findsOneWidget);
    expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('NPhotoViewer deja altura al contenido y pie compacto', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NPhotoViewer(
          title: 'Septiembre 27, 2026',
          subtitle: '15:34',
          // Hijo que expande como el PageView real (ColoredBox sin hijo
          // colapsa a cero por sí solo y no sirve para esta regresión).
          child: SizedBox.expand(
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

    // Orden de acciones: compartir, editar, eliminar, favorito.
    expect(find.byTooltip('Compartir'), findsOneWidget);
    expect(find.byTooltip('Editar'), findsOneWidget);
    expect(find.byTooltip('Eliminar'), findsOneWidget);
    expect(find.byTooltip('Favorito'), findsOneWidget);
  });
}
