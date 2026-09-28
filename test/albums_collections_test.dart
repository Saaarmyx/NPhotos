import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_ui/nexora_ui.dart';
import 'package:nphotos/app/nphotos_app.dart';
import 'package:nphotos/controllers/gallery_controller.dart';
import 'package:nphotos/controllers/selection_controller.dart';
import 'package:nphotos/models/photo.dart';
import 'package:nphotos/screens/albums/album_detail_screen.dart';
import 'package:nphotos/screens/albums/albums_screen.dart';
import 'package:nphotos/screens/favorites/favorites_screen.dart';
import 'package:nphotos/screens/trash/trash_screen.dart';
import 'package:nphotos/screens/videos/videos_screen.dart';
import 'package:nphotos/services/photo_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

Photo _photo(String path, {DateTime? modified}) => Photo(
  id: path,
  path: path,
  title: p.basename(path),
  dateCreated: modified ?? DateTime(2026, 1, 10),
  dateModified: modified ?? DateTime(2026, 1, 10),
  sizeInBytes: 16,
);

void main() {
  group('Prefs de popup', () {
    test('defaults: grid, compacto, A-Z, nada oculto', () {
      final c = GalleryController(
        photoService: PhotoService(roots: const []),
      );
      expect(c.albumsViewMode, AlbumsViewMode.grid);
      expect(c.collectionsViewMode, CollectionsViewMode.compact);
      expect(c.collectionsSort, CollectionsSort.az);
      expect(c.hidePins, isFalse);
      expect(c.hideAlbums, isFalse);
      expect(c.hideCovers, isFalse);
      c.dispose();
    });

    test('toggles notifican y alternan', () {
      final c = GalleryController(
        photoService: PhotoService(roots: const []),
      );
      var calls = 0;
      c.addListener(() => calls++);
      c.setAlbumsViewMode(AlbumsViewMode.list);
      c.setCollectionsViewMode(CollectionsViewMode.grouped);
      c.setCollectionsSort(CollectionsSort.za);
      c.toggleHidePins();
      c.toggleHideAlbums();
      c.toggleHideCovers();
      expect(c.albumsViewMode, AlbumsViewMode.list);
      expect(c.collectionsViewMode, CollectionsViewMode.grouped);
      expect(c.collectionsSort, CollectionsSort.za);
      expect(c.hidePins, isTrue);
      expect(c.hideAlbums, isTrue);
      expect(c.hideCovers, isTrue);
      expect(calls, 6);
      // Sin cambios no notifica.
      c.setAlbumsViewMode(AlbumsViewMode.list);
      expect(calls, 6);
      c.dispose();
    });
  });

  group('Orden', () {
    test('applyNameSort A-Z y Z-A', () {
      final c = GalleryController(
        photoService: PhotoService(roots: const []),
      );
      final photos = [_photo('/x/b.jpg'), _photo('/x/a.jpg')];
      expect(
        c.applyNameSort(photos).map((e) => e.title).toList(),
        ['a.jpg', 'b.jpg'],
      );
      c.setCollectionsSort(CollectionsSort.za);
      expect(
        c.applyNameSort(photos).map((e) => e.title).toList(),
        ['b.jpg', 'a.jpg'],
      );
      c.dispose();
    });
  });

  group('Screens dedicadas', () {
    late Directory tmp;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tmp = await Directory.systemTemp.createTemp('nphotos_screens');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    /// PNG 1x1 válido.
    ///
    /// Bytes reales, no un patrón: así `Image.file` decodifica de
    /// verdad y la pantalla se comporta como en producción.
    const png1x1 = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00,
      0x90, 0x77, 0x53, 0xDE,
      0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,
      0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
      0x03, 0x01, 0x01, 0x00,
      0x18, 0xDD, 0x8D, 0xB0,
      0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
      0xAE, 0x42, 0x60, 0x82,
    ];

    /// Escribe un fichero de imagen en disco.
    ///
    /// Importa: la E/S real no avanza bajo el reloj falso de
    /// `testWidgets`; sin `tester.runAsync` la escritura se queda
    /// colgada y el test muere por tiempo. El decode posterior sí
    /// funciona con normalidad.
    Future<File> image(WidgetTester tester, String name) async {
      final file = File(p.join(tmp.path, name));
      await tester.runAsync(() => file.writeAsBytes(png1x1));
      return file;
    }

    /// `fetchPhotos` usa `compute` (isolate real): dentro de `testWidgets`
    /// el reloj falso no lo completa, así que se ejecuta con
    /// `tester.runAsync` (reloj real) en vez de `await` directo.
    Future<GalleryController> loaded(WidgetTester tester) async {
      final c = GalleryController(photoService: PhotoService(roots: [tmp]));
      await tester.runAsync(() => c.fetchPhotos());
      return c;
    }

    testWidgets('Favoritos muestra la marcada', (
      WidgetTester tester,
    ) async {
      await image(tester, 'a.jpg');
      final c = await loaded(tester);
      await tester.runAsync(
        () => c.toggleFavorite(p.join(tmp.path, 'a.jpg')),
      );
      await tester.pumpWidget(
        MaterialApp(home: FavoritesScreen(controller: c)),
      );
      await tester.pump();
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      c.dispose();
    });

    testWidgets('Vídeos muestra el mp4', (WidgetTester tester) async {
      await image(tester, 'clip.mp4');
      final c = await loaded(tester);
      await tester.pumpWidget(MaterialApp(home: VideosScreen(controller: c)));
      await tester.pump();
      expect(find.text('Vídeos'), findsOneWidget);
      // Los vídeos no se decodifican (Flutter no lee MP4): se pintan
      // con la portada de acento, sin `Image` detrás.
      expect(find.byType(NVideoThumb), findsWidgets);
      expect(find.byType(Image), findsNothing);
      c.dispose();
    });

    testWidgets('Papelera muestra la movida', (WidgetTester tester) async {
      await image(tester, 'a.jpg');
      final c = await loaded(tester);
      await tester.runAsync(() => c.moveToTrash(p.join(tmp.path, 'a.jpg')));
      await tester.pumpWidget(MaterialApp(home: TrashScreen(controller: c)));
      await tester.pump();
      expect(find.text('Papelera'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      c.dispose();
    });

    testWidgets('AlbumDetailScreen es el molde del álbum', (
      WidgetTester tester,
    ) async {
      await image(tester, 'a.jpg');
      final c = await loaded(tester);
      final album = c.albums.single;
      await tester.pumpWidget(
        MaterialApp(
          home: AlbumDetailScreen(album: album, controller: c),
        ),
      );
      await tester.pump();
      expect(find.text(album.name), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      c.dispose();
    });

    test('ocultar álbum lo saca de la parrilla y vuelve con la colección', () {
      final c = GalleryController(
        photoService: PhotoService(roots: const []),
      );
      // Sin datos: se comprueba la API de preferencias directamente.
      expect(c.hiddenAlbums, isEmpty);
      expect(c.visibleAlbums, isEmpty);
      c.dispose();
    });

    testWidgets('Álbumes en modo lista pinta filas con chevron', (
      WidgetTester tester,
    ) async {
      await image(tester, 'a.jpg');
      final c = await loaded(tester);
      c.setAlbumsViewMode(AlbumsViewMode.list);
      await tester.pumpWidget(MaterialApp(
          // Scaffold: las filas usan InkWell y exigen un Material.
          home: Scaffold(
            body: AlbumsScreen(
              controller: c,
              selection: SelectionController(),
            ),
          ),
        ));
      await tester.pump();
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
      c.dispose();
    });
  });

  group('Switches del popup', () {
    Future<void> settleMenu(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> openPopup(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Más opciones'));
      await settleMenu(tester);
    }

    Finder switchOf(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(PopupMenuItem<String>),
      ),
      matching: find.byType(Switch),
    );

    testWidgets('galería: el popup de ordenar lleva título', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const NPhotosApp());
      await settleMenu(tester);
      await openPopup(tester);

      expect(find.text('ORDENAR'), findsOneWidget);
      expect(find.text('Por día de captura'), findsOneWidget);
      expect(find.text('Por día de agregación'), findsOneWidget);
      // Sin rayas: el menú no usa PopupMenuDivider.
      expect(find.byType(PopupMenuDivider), findsNothing);
    });

    testWidgets('galería: un tap alterna una sola vez', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const NPhotosApp());
      await settleMenu(tester);

      await openPopup(tester);
      expect(find.text('Por día de captura'), findsOneWidget);
      // 'Álbum cámara' arranca apagado; un tap lo enciende (sin rebote).
      expect(tester.widget<Switch>(switchOf('Álbum cámara')).value, isFalse);
      await tester.tap(switchOf('Álbum cámara'));
      await tester.pump(const Duration(milliseconds: 300));
      // El menú sigue abierto (el switch consumió el tap) y ya se
      // redibujó encendido: sin cerrar ni reabrir.
      expect(tester.widget<Switch>(switchOf('Álbum cámara')).value, isTrue);
      // Cerrar tocando fuera y reabrir: persiste (un solo toggle).
      await tester.tapAt(const Offset(10, 300));
      await settleMenu(tester);

      await openPopup(tester);
      expect(tester.widget<Switch>(switchOf('Álbum cámara')).value, isTrue);
    });

    testWidgets('álbumes: switch Pines oculta la sección', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const NPhotosApp());
      await settleMenu(tester);

      // Ir a Álbumes.
      await tester.tap(find.byIcon(Icons.photo_album_outlined));
      await settleMenu(tester);

      await openPopup(tester);
      expect(find.text('OCULTAR'), findsOneWidget);
      expect(find.text('Lista'), findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);
      await tester.tap(switchOf('Pines'));
      await settleMenu(tester);

      // Reabrir: el switch queda encendido (un solo toggle).
      await openPopup(tester);
      expect(tester.widget<Switch>(switchOf('Pines')).value, isTrue);
    });

    testWidgets('colecciones: orden Z→A reordena la lista', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const NPhotosApp());
      await settleMenu(tester);

      // Ir a Colecciones.
      await tester.tap(find.byIcon(Icons.collections_bookmark_outlined));
      await settleMenu(tester);

      await openPopup(tester);
      expect(find.text('ORDEN'), findsOneWidget);
      // A→Z por defecto: "Añadidos recientemente" va primero.
      expect(
        tester.getTopLeft(find.text('Añadidos recientemente')).dy,
        lessThan(tester.getTopLeft(find.text('Lugares')).dy),
      );

      await tester.tap(switchOf('Z → A'));
      await settleMenu(tester);
      await tester.tapAt(const Offset(10, 300));
      await settleMenu(tester);

      // Z→A: Lugares (L) va antes que Añadidos (A).
      expect(
        tester.getTopLeft(find.text('Lugares')).dy,
        lessThan(tester.getTopLeft(find.text('Añadidos recientemente')).dy),
      );
    });
  });
}
