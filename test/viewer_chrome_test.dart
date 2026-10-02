import 'photo_repo_helper.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:NexoraUi/NexoraUi.dart';
import 'package:NPhotos/controllers/gallery_controller.dart';
import 'package:NPhotos/models/photo.dart';
import 'package:NPhotos/screens/gallery/photo_viewer_screen.dart';

/// El chrome del visor se monta y se ve al abrir; a los 5 s se oculta
/// solo y un toque en la foto lo devuelve.
void main() {
  late Directory tmp;
  late Photo photo;

  setUp(() async {
    SharedPreferencesShim.set();
    tmp = await Directory.systemTemp.createTemp('nphotos_chrome');
    final file = File('${tmp.path}/a.jpg');
    await file.writeAsBytes(List.filled(16, 1));
    photo = Photo(
      id: file.path,
      path: file.path,
      title: 'a.jpg',
      dateCreated: DateTime(2026, 1, 10),
      dateModified: DateTime(2026, 1, 10),
      sizeInBytes: 16,
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> pumpViewer(WidgetTester tester, {Brightness brightness = Brightness.dark}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        home: PhotoViewerScreen(
          controller: GalleryController(photos: testPhotoRepository(root: tmp.path)),
          initialIndex: 0,
          photosOverride: [photo],
        ),
      ),
    );
    await tester.pump();
  }

  for (final brightness in [Brightness.dark, Brightness.light]) {
    testWidgets('las barras del visor se montan visibles en $brightness', (
      tester,
    ) async {
      await pumpViewer(tester, brightness: brightness);

      expect(find.byType(NViewerTopBar), findsOneWidget);
      expect(find.byType(NViewerBottomBar), findsOneWidget);

      final top = tester.getSize(find.byType(NViewerTopBar));
      final bottom = tester.getSize(find.byType(NViewerBottomBar));
      expect(top.height, 64, reason: 'la topbar debe medir 64 como la global');
      expect(bottom.height, greaterThan(0), reason: 'la bottombar debe medir');

      // Chrome opaco al abrir: se ve sobre la foto.
      final opacities = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((w) => w.opacity)
          .toList();
      expect(opacities, everyElement(1.0));
    });
  }

  testWidgets('se oculta a los 5 s y un toque la devuelve', (tester) async {
    await pumpViewer(tester);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(
      tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity)).map((w) => w.opacity),
      everyElement(0.0),
    );

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity)).map((w) => w.opacity),
      everyElement(1.0),
    );
  });
}

/// Evita el arranque real de SharedPreferences en tests.
class SharedPreferencesShim {
  static void set() {}
}
