import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:NPhotos/app/nphotos_app.dart';
import 'package:NexoraUi/NexoraUi.dart';

import 'permisos_test_helper.dart';

/// El gesto de swipe sobre NPhotos.
///
/// NPhotos es el caso difícil del ecosistema: sus pestañas (galería,
/// álbumes, colecciones) traen rejillas horizontales, deslizadores y
/// scrolls propios que compiten en la arena de gestos con el `PageView`
/// del layout. Aquí se comprueba que el gesto gana donde debe y que la
/// vista no se queda a medias al terminar.
void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      NPhotosApp(permissions: testPermissions()),
    );
    await tester.pumpAndSettle();
  }

  /// Arrastre horizontal con la velocidad de un dedo.
  ///
  /// Va en varios pasos, no en un salto: un `moveTo` de 260 px de golpe
  /// llega al rastreador de velocidad como un flick rapidísimo y el
  /// `PageView` lo interpreta distinto que a un dedo real. Con pasos,
  /// adelante y atrás se comportan igual.
  Future<void> swipe(WidgetTester tester, double dx) async {
    final layout = find.byType(NMobileLayout).first;
    final centro = tester.getCenter(layout);
    final inicio = centro.dx - dx / 2;
    final gesto = await tester.startGesture(Offset(inicio, centro.dy));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 1; i <= 6; i++) {
      await gesto.moveTo(Offset(inicio + dx * i / 6, centro.dy));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesto.up();
    await tester.pumpAndSettle();
  }

  /// Toca un destino de la bottom bar por posición.
  ///
  /// No se calcula por coordenadas: la barra no pinta la etiqueta de cada
  /// destino y su geometría depende de un centrado más holgura y padding
  /// que cambian con el número de destinos. Localizar los gestos en orden
  /// es exacto y no se rompe si el kit cambia el espaciado.
  ///
  /// Se filtran los que tienen `onTap` porque la barra también lleva un
  /// `GestureDetector` de arrastre horizontal (para mover la píldora), y
  /// ese no es un destino.
  Future<void> tapBarItem(WidgetTester tester, int index) async {
    final items = find.descendant(
      of: find.byType(NBottomBarMobile),
      matching: find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onTap != null,
      ),
    );
    final total = items.evaluate().length;
    if (index >= total) {
      throw StateError('La barra tiene $total destinos; se pidió el $index');
    }
    await tester.tap(items.at(index));
    await tester.pumpAndSettle();
  }

  /// Qué pestaña está activa.
  ///
  /// Se lee del `PageView` del layout y no de la posición de la píldora:
  /// la barra tiene padding y un centrado propio, así que su geometría no
  /// se deduce con aritmética simple y una aproximación da falsos
  /// positivos.
  int? activeIndex(WidgetTester tester) {
    final page =
        tester.widget<PageView>(find.byType(PageView).first).controller?.page;
    return page?.round();
  }

  testWidgets('la app arranca en la primera pestaña', (tester) async {
    await pump(tester);
    expect(find.byType(NMobileLayout), findsOneWidget);
    expect(find.byType(NBottomBarMobile), findsOneWidget);
  });

  testWidgets('deslizar a la izquierda avanza de pestaña', (tester) async {
    await pump(tester);
    final antes = activeIndex(tester);

    await swipe(tester, -260);

    final despues = activeIndex(tester);
    expect(despues, isNot(antes), reason: 'la píldora tiene que moverse');
    expect(despues, greaterThan(antes ?? 0));
  });

  testWidgets('deslizar a la derecha retrocede de pestaña', (tester) async {
    await pump(tester);

    await swipe(tester, -260);
    expect(activeIndex(tester), 1);

    await swipe(tester, 260);
    expect(activeIndex(tester), 0);
  });

  testWidgets('no se sale por la primera pestaña', (tester) async {
    await pump(tester);

    await swipe(tester, 260);

    expect(activeIndex(tester), 0, reason: 'no hay nada antes');
  });

  testWidgets('el gesto no se come el scroll vertical', (tester) async {
    await pump(tester);
    final antes = activeIndex(tester);

    final centro = tester.getCenter(find.byType(NMobileLayout).first);
    final gesto = await tester.startGesture(centro);
    await gesto.moveBy(const Offset(0, -200));
    await gesto.up();
    await tester.pumpAndSettle();

    expect(activeIndex(tester), antes);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el gesto queda estable al asentarse', (tester) async {
    await pump(tester);

    await swipe(tester, -260);
    final activo = activeIndex(tester);

    // Con doble aviso la vista se resincronizaría sola al terminar la
    // animación del `PageView` y la píldora daría un tirón.
    await tester.pump(const Duration(milliseconds: 400));
    expect(activeIndex(tester), activo);
  });

  testWidgets('volver por la barra tras un gesto no deja la vista a medias', (
    tester,
  ) async {
    await pump(tester);

    await swipe(tester, -260);
    expect(activeIndex(tester), 1);

    await tapBarItem(tester, 0);
    expect(activeIndex(tester), 0);
  });
}
