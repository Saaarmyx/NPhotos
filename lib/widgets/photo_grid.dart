import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

/// Grilla compartida para fotos y álbumes.
///
/// Reemplaza los 4 `GridView.builder` duplicados (galería, favoritos,
/// álbumes y detalle de álbum). El número de columnas se resuelve por
/// ancho disponible ([NBreakpoints.mobile]) en lugar de `Platform.isAndroid`,
/// para que el layout responda también a tablets, ventanas redimensionadas
/// y web.
class PhotoGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int compactColumns;
  final int wideColumns;
  final double wideBreakpoint;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final double childAspectRatio;

  const PhotoGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.compactColumns = 3,
    this.wideColumns = 5,
    this.wideBreakpoint = NBreakpoints.mobile,
    this.spacing = NSpacing.spaceXs,
    this.padding = const EdgeInsets.all(NSpacing.spaceXs),
    this.childAspectRatio = 1.0,
  });

  /// Configuración usada por galería, favoritos y detalle de álbum.
  const PhotoGrid.photos({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.wideBreakpoint = NBreakpoints.mobile,
    this.spacing = NSpacing.spaceXs,
    this.padding = const EdgeInsets.all(NSpacing.spaceXs),
  }) : compactColumns = 3,
       wideColumns = 5,
       childAspectRatio = 1.0;

  /// Configuración usada por la parrilla de álbumes (tarjetas con título).
  const PhotoGrid.albums({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.wideBreakpoint = NBreakpoints.mobile,
    this.spacing = NSpacing.spaceSm,
    this.padding = const EdgeInsets.all(NSpacing.spaceSm),
  }) : compactColumns = 2,
       wideColumns = 4,
       childAspectRatio = 0.85;

  /// Resuelve las columnas según el ancho disponible.
  static int columnsFor(
    BuildContext context, {
    required int compact,
    required int wide,
    double breakpoint = NBreakpoints.mobile,
  }) {
    return MediaQuery.widthOf(context) < breakpoint ? compact : wide;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnsFor(
          context,
          compact: compactColumns,
          wide: wideColumns,
          breakpoint: wideBreakpoint,
        ),
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
