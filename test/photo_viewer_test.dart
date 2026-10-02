import 'photo_repo_helper.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:NPhotos/controllers/gallery_controller.dart';
import 'package:NPhotos/models/photo.dart';
import 'package:NPhotos/screens/gallery/photo_viewer_screen.dart';
import 'package:path/path.dart' as p;

void main() {
  test('la matriz de zoom focal deja fijo el punto tocado', () {
    // Misma fórmula que _handleDoubleTap: M = T(f)·S(s)·T(-f).
    const f = Offset(400, 300);
    const s = 2.5;
    final m = Matrix4.identity()
      ..translateByDouble(f.dx, f.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-f.dx, -f.dy, 0, 1);
    expect(m.entry(0, 0), s);
    // M·f == f ⟺ traslación == f·(1-s).
    final t = m.getTranslation();
    expect(t.x, closeTo(f.dx * (1 - s), 1e-9));
    expect(t.y, closeTo(f.dy * (1 - s), 1e-9));
  });

  late Directory tmp;
  late Photo photo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('nphotos_viewer');
    final file = File(p.join(tmp.path, 'a.png'));
    // PNG de 100x100 (cabecera válida, el decode da igual para el test).
    final bytes = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x64,
      0x08, 0x02, 0x00, 0x00, 0x00,
    ];
    await file.writeAsBytes(bytes);
    photo = Photo(
      id: file.path,
      path: file.path,
      title: 'a.png',
      dateCreated: DateTime(2026, 9, 27, 15, 34),
      dateModified: DateTime(2026, 9, 27, 15, 34),
      sizeInBytes: bytes.length,
      width: 100,
      height: 100,
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Widget viewer() => MaterialApp(
    home: PhotoViewerScreen(
      controller: GalleryController(photos: testPhotoRepository(root: tmp.path)),
      initialIndex: 0,
      photosOverride: [photo],
    ),
  );

  List<double> opacities(WidgetTester tester) => tester
      .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
      .map((w) => w.opacity)
      .toList();

  testWidgets('chrome visible al abrir y se esconde a los 5 s', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(viewer());
    await tester.pump();
    expect(opacities(tester), everyElement(1.0));

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(opacities(tester), everyElement(0.0));
  });

  testWidgets('un toque esconde y otro muestra el chrome', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(viewer());
    await tester.pump();

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opacities(tester), everyElement(0.0));

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opacities(tester), everyElement(1.0));
  });

  testWidgets('doble toque amplía (bloquea swipe) y repite para volver',
    (WidgetTester tester) async {
      await tester.pumpWidget(viewer());
      await tester.pump();

      ScrollPhysics physics() =>
          tester.widget<PageView>(find.byType(PageView)).physics!;
      expect(physics(), isA<PageScrollPhysics>());

      final center = tester.getCenter(find.byType(InteractiveViewer));
      var gesture = await tester.startGesture(center);
      await gesture.up();
      gesture = await tester.startGesture(center);
      await gesture.up();
      await tester.pumpAndSettle();

      // Zoom 2.5x focal: el PageView queda bloqueado.
      expect(physics(), isA<NeverScrollableScrollPhysics>());

      gesture = await tester.startGesture(center);
      await gesture.up();
      gesture = await tester.startGesture(center);
      await gesture.up();
      await tester.pumpAndSettle();

      // De vuelta a 1x: swipe liberado.
      expect(physics(), isA<PageScrollPhysics>());
    },
  );
}
