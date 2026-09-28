import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../controllers/gallery_controller.dart';
import '../../controllers/selection_controller.dart';
import '../../models/photo.dart';
import '../../utils/photo_viewer.dart';
import '../../widgets/photo_tile.dart';

const _kMonthsEs = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

String _formatDayHeader(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == today) return 'Hoy';
  if (day == yesterday) return 'Ayer';
  return '${day.day} de ${_kMonthsEs[day.month - 1]} de ${day.year}';
}

/// Galería principal: grilla con pinch-to-zoom + carga silenciosa.
///
/// - Hidratación instantánea desde caché local al abrir (sin loadings
///   repetitivos): solo muestra loading en frío y con lista vacía.
/// - El watcher inserta fotos nuevas al inicio con animación sutil,
///   sin recargar ni parpadear (vía [GalleryController.lastInsertedIds]).
/// - Respeta el popup de la topbar: orden (captura/agregación),
///   vista (por fecha/compacto), filtro (todos/cámara) y búsqueda.
class GalleryScreen extends StatefulWidget {
  final GalleryController controller;
  final SelectionController selection;

  const GalleryScreen({
    super.key,
    required this.controller,
    required this.selection,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  int _columns = 3;
  bool _booted = false;
  double _scaleAccum = 1.0;

  /// Pinch-to-zoom del modo por fecha (el compacto lo gestiona NZoomGrid).
  void _handleGroupedScale(ScaleUpdateDetails details) {
    if (details.scale == 1.0) return;
    _scaleAccum *= details.scale;
    if (_scaleAccum >= 1.25 && _columns > 2) {
      setState(() => _columns--);
      _scaleAccum = 1.0;
    } else if (_scaleAccum <= 0.8 && _columns < 7) {
      setState(() => _columns++);
      _scaleAccum = 1.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await widget.controller.hydrateFromCache();
    if (!mounted) return;
    setState(() => _booted = true);
    // Escaneo real en segundo plano: si ya había caché, es silencioso.
    await widget.controller.fetchPhotos(silent: true);
    await widget.controller.startWatching();
  }

  @override
  Widget build(BuildContext context) {
    // Reacciona al estado de selección para redibujar los checkmarks.
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, widget.selection]),
      builder: (context, _) {
        switch (widget.controller.state) {
          case GalleryState.initial:
          case GalleryState.loading:
            // Carga silenciosa: si ya hay fotos en memoria/caché,
            // se muestran directo en vez de un spinner repetitivo.
            if (widget.controller.photos.isNotEmpty) {
              return _buildGrid();
            }
            if (!_booted) {
              // Primer frame: la hidratación aún no terminó.
              return const SizedBox.shrink();
            }
            return const NLoadingView();

          case GalleryState.permissionDenied:
            return NPermissionDeniedView(
              icon: Icons.security,
              title: 'Permiso necesario',
              message: 'Se requieren permisos para acceder a tus fotos',
              actionLabel: 'Conceder permiso',
              onAction: widget.controller.fetchPhotos,
            );

          case GalleryState.error:
            if (widget.controller.photos.isNotEmpty) return _buildGrid();
            return NErrorView(
              message: widget.controller.errorMessage ?? 'Error al cargar fotos',
              retryLabel: 'Reintentar',
              onRetry: widget.controller.fetchPhotos,
            );

          case GalleryState.loaded:
            if (widget.controller.photos.isEmpty) {
              return NEmptyState(
                icon: Icons.photo_outlined,
                title: 'No hay fotos',
                subtitle: Platform.isAndroid
                    ? 'No hay fotos en DCIM o Pictures.'
                    : 'No hay fotos en ~/Pictures o ~/Downloads.',
              );
            }
            if (widget.controller.visiblePhotos.isEmpty) {
              return NEmptyState(
                icon: widget.controller.filter == GalleryFilter.camera
                    ? Icons.photo_camera_outlined
                    : Icons.search_off_outlined,
                title: widget.controller.filter == GalleryFilter.camera
                    ? 'Sin fotos de cámara'
                    : 'Sin resultados',
                subtitle: widget.controller.filter == GalleryFilter.camera
                    ? 'No hay fotos en el álbum de cámara.'
                    : 'Prueba con otra búsqueda o filtro.',
              );
            }
            return _buildGrid();
        }
      },
    );
  }

  Widget _buildGrid() {
    final controller = widget.controller;
    if (controller.viewMode == GalleryViewMode.compact) {
      return _buildCompactGrid(controller);
    }
    return _buildGroupedGrid(controller);
  }

  void _openViewer(GalleryController controller, Photo photo) {
    final visible = controller.visiblePhotos;
    openPhotoViewer(
      context,
      controller: controller,
      photos: visible,
      initialId: photo.id,
    );
  }

  Widget _tile(GalleryController controller, Photo photo) {
    final selection = widget.selection;
    // Con algo seleccionado, el tap alterna en lugar de abrir el visor.
    final selecting = selection.isActive;
    return GestureDetector(
      onTap: () => selecting
          ? selection.toggle(photo.id)
          : _openViewer(controller, photo),
      // Mantener pulsado inicia (o amplía) la selección múltiple.
      onLongPress: () => selecting
          ? selection.toggle(photo.id)
          : selection.selectOnly(photo.id, kind: SelectionKind.photos),
      child: PhotoTile(
        photo: photo,
        path: photo.path,
        selected: selecting ? selection.isSelected(photo.id) : null,
      ),
    );
  }

  Widget _buildCompactGrid(GalleryController controller) {
    final visible = controller.visiblePhotos;
    return NZoomGrid(
      itemCount: visible.length,
      initialColumns: _columns,
      newIds: controller.lastInsertedIds,
      idForIndex: (index) => visible[index].id,
      onColumnsChanged: (columns) => _columns = columns,
      itemBuilder: (context, index) => _tile(controller, visible[index]),
    );
  }

  Widget _buildGroupedGrid(GalleryController controller) {
    final groups = controller.visibleGroups;
    final entries = groups.entries.toList();
    return GestureDetector(
      // Pinch-to-zoom también en modo por fecha: comparte [_columns].
      onScaleUpdate: _handleGroupedScale,
      onScaleEnd: (_) => _scaleAccum = 1.0,
      child: CustomScrollView(
          slivers: [
            for (final entry in entries) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                  child: Text(
                    _formatDayHeader(entry.key),
                    style: TextStyle(
                      fontFamily: NTypography.fontFamilyBase,
                      fontWeight: NTypography.weightBold,
                      fontSize: NTypography.sizeSm,
                      color: context.nPrimaryTextColor,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _tile(controller, entry.value[index]),
                    childCount: entry.value.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
  }
}
