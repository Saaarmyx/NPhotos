// lib/widgets/album_actions_sheet.dart
//
// Hoja de acciones de un álbum/pin. Aparece POR ENCIMA de la bottom bar
// (se monta en el overlay raíz con `useRootNavigator` + `viewInsets`), y
// funciona igual para un álbum de la parrilla o para un pin.
//
// Opciones del álbum: pinear, cambiar nombre, cambiar carátula,
// eliminar y ocultar.
// Opciones del pin: cambiar carátula, nombre y ocultar (ya está fijo).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../controllers/gallery_controller.dart';

/// Acciones disponibles sobre un álbum (parrilla o pin).
enum AlbumAction { togglePin, rename, changeCover, hide, unhide, delete }

/// Abre la hoja de acciones. Devuelve la acción elegida (o null).
Future<AlbumAction?> showAlbumActionsSheet(
  BuildContext context, {
  required GalleryController controller,
  required String title,
  required bool isPinned,
  required bool isHidden,
  required bool isSystem,
}) {
  // Las acciones se declaran como datos; el render es del kit.
  final items = <NActionSheetItem>[];

  // Un pin ya esta fijado: no tiene sentido "fijar" ni "eliminar", y
  // los de sistema no se renombran ni cambian caratula.
  if (!isPinned) {
    items.add(
      NActionSheetItem(
        icon: Icons.push_pin_outlined,
        label: 'Fijar en Pines',
        onTap: () => Navigator.of(context).pop(AlbumAction.togglePin),
      ),
    );
  }
  if (!isSystem) {
    items.add(
      NActionSheetItem(
        icon: Icons.drive_file_rename_outline,
        label: 'Cambiar nombre',
        onTap: () => Navigator.of(context).pop(AlbumAction.rename),
      ),
    );
    items.add(
      NActionSheetItem(
        icon: Icons.photo_library_outlined,
        label: 'Cambiar caratula',
        onTap: () => Navigator.of(context).pop(AlbumAction.changeCover),
      ),
    );
  }
  items.add(
    NActionSheetItem(
      icon: isHidden
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined,
      label: isHidden ? 'Mostrar en Albumes' : 'Ocultar album',
      onTap: () => Navigator.of(context).pop(
        isHidden ? AlbumAction.unhide : AlbumAction.hide,
      ),
    ),
  );
  if (!isPinned && !isSystem) {
    items.add(
      NActionSheetItem(
        icon: Icons.delete_outline,
        label: 'Eliminar album',
        destructive: true,
        onTap: () => Navigator.of(context).pop(AlbumAction.delete),
      ),
    );
  }

  return showNSheet<AlbumAction>(
    context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    child: NActionSheet(title: title, items: items),
  );
}

/// Diálogo para renombrar un álbum (estética del kit).
Future<String?> showAlbumRenameDialog(
  BuildContext context, {
  required String currentName,
}) {
  return showNRenameDialog(
    context,
    title: 'Renombrar álbum',
    initialValue: currentName,
    hintText: 'Nombre del álbum',
  );
}

/// Selector de carátula: rejilla de las fotos del álbum.
Future<String?> showAlbumCoverPicker(
  BuildContext context, {
  required GalleryController controller,
  required String albumPath,
}) {
  final album = controller.albums.where((a) => a.path == albumPath).firstOrNull;
  if (album == null || album.photos.isEmpty) return Future<String?>.value();
  final current = controller.prefsFor(albumPath).cover;
  // `null` = usar la portada automática; un path = esa foto.
  return showNSheet<String?>(
    context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.only(
        top: NSpacing.spaceSm,
        bottom: NSpacing.spaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NSheetHandle(),
          const SizedBox(height: NSpacing.spaceMd),
          const NSheetTitle('Cambiar carátula'),
          SizedBox(
            height: 260,
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: NSpacing.spaceMd),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
              itemCount: album.photos.length + (current != null ? 1 : 0),
              itemBuilder: (context, index) {
                // La primera celda es "usar la portada actual".
                if (current != null && index == 0) {
                  return _CoverCell(
                    selected: false,
                    onTap: () => Navigator.of(context).pop<String?>(null),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          color: context.nMutedTextColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Automática',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.nMutedTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final photo = album.photos[current != null ? index - 1 : index];
                return _CoverCell(
                  selected: photo.path == current,
                  onTap: () => Navigator.of(context).pop(photo.path),
                  child: Image.file(
                    File(photo.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: context.nMutedTextColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoverCell extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _CoverCell({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
