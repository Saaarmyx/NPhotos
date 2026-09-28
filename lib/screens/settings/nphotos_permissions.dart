// lib/screens/settings/nphotos_permissions.dart
//
// Gestión de permisos FUNCIONAL de NPhotos (los switches del kit son
// mock con estados fijos). Consulta el estado real con
// `permission_handler`, solicita al activar y abre los ajustes del
// sistema al desactivar/revocar: Android no permite revocar permisos
// en tiempo de ejecución desde la app, solo el usuario en ajustes.
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';
import 'package:permission_handler/permission_handler.dart';

/// Abre los ajustes del sistema de la app (única vía real de revocación).
Future<void> openSystemAppSettings() => openAppSettings();

/// Diálogo de confirmación para "Revocar todos los permisos".
/// No desmarca nada por sí solo: Android solo revoca en ajustes del
/// sistema, así que el confirmar abre esos ajustes.
Future<void> confirmRevokeAllPermissions(BuildContext context) async {
  final confirmed = await showNConfirmDialog(
    context,
    title: 'Revocar todos los permisos',
    message: 'Android no permite revocar permisos desde la app. '
        'Se abrirán los ajustes del sistema para que los quites ahí.',
    confirmLabel: 'Abrir ajustes',
    isDestructive: false,
    icon: Icons.shield_outlined,
  );
  if (confirmed) await openSystemAppSettings();
}

/// Permiso real que usa NPhotos.
class _AppPermission {
  final String id;
  final String title;
  final IconData icon;
  final Future<PermissionStatus> Function() status;
  final Future<PermissionStatus> Function() request;

  const _AppPermission({
    required this.id,
    required this.title,
    required this.icon,
    required this.status,
    required this.request,
  });
}

/// Fotos y vídeos: READ_MEDIA_* (SDK 33+) o storage clásico.
Future<int> _androidSdk() async {
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  } catch (_) {
    return 0;
  }
}

Future<PermissionStatus> _mediaStatus() async {
  try {
    if (Platform.isAndroid && await _androidSdk() < 33) {
      return await Permission.storage.status;
    }
    return await Permission.photos.status;
  } catch (_) {
    return PermissionStatus.denied;
  }
}

Future<PermissionStatus> _mediaRequest() async {
  try {
    if (Platform.isAndroid && await _androidSdk() < 33) {
      return await Permission.storage.request();
    }
    return await Permission.photos.request();
  } catch (_) {
    return PermissionStatus.denied;
  }
}

List<_AppPermission> _appPermissions() => [
  _AppPermission(
    id: 'media',
    title: 'Fotos y vídeos',
    icon: Icons.photo_library_outlined,
    status: _mediaStatus,
    request: _mediaRequest,
  ),
  _AppPermission(
    id: 'media_location',
    title: 'Ubicación en fotos',
    icon: Icons.location_on_outlined,
    status: () async {
      try {
        if (!Platform.isAndroid) return PermissionStatus.granted;
        return await Permission.accessMediaLocation.status;
      } catch (_) {
        return PermissionStatus.denied;
      }
    },
    request: () async {
      try {
        if (!Platform.isAndroid) return PermissionStatus.granted;
        return await Permission.accessMediaLocation.request();
      } catch (_) {
        return PermissionStatus.denied;
      }
    },
  ),
  _AppPermission(
    id: 'location',
    title: 'Ubicación',
    icon: Icons.place_outlined,
    status: () async {
      try {
        if (Platform.isAndroid) {
          return await Permission.locationWhenInUse.status;
        }
        return await Permission.location.status;
      } catch (_) {
        return PermissionStatus.denied;
      }
    },
    request: () async {
      try {
        if (Platform.isAndroid) {
          return await Permission.locationWhenInUse.request();
        }
        return await Permission.location.request();
      } catch (_) {
        return PermissionStatus.denied;
      }
    },
  ),
  _AppPermission(
    id: 'notifications',
    title: 'Notificaciones',
    icon: Icons.notifications_outlined,
    status: () async {
      try {
        return await Permission.notification.status;
      } catch (_) {
        return PermissionStatus.denied;
      }
    },
    request: () async {
      try {
        return await Permission.notification.request();
      } catch (_) {
        return PermissionStatus.denied;
      }
    },
  ),
];

/// Pantalla móvil de gestión de permisos.
class NPhotosPermissionsScreen extends StatelessWidget {
  const NPhotosPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: NSecondaryTopBar(title: 'Gestión de permisos'),
      body: NPhotosPermissionsContent(),
    );
  }
}

/// Contenido reutilizable (móvil + panel lateral desktop).
/// Relee el estado real al volver de los ajustes del sistema.
class NPhotosPermissionsContent extends StatefulWidget {
  const NPhotosPermissionsContent({super.key});

  @override
  State<NPhotosPermissionsContent> createState() =>
      _NPhotosPermissionsContentState();
}

class _NPhotosPermissionsContentState extends State<NPhotosPermissionsContent>
    with WidgetsBindingObserver {
  Map<String, PermissionStatus>? _statuses;
  bool _systemManaged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Escritorio: sin permisos en tiempo de ejecución.
      if (mounted) setState(() => _systemManaged = true);
      return;
    }
    final entries = <String, PermissionStatus>{};
    for (final perm in _appPermissions()) {
      try {
        entries[perm.id] = await perm.status();
      } catch (_) {
        entries[perm.id] = PermissionStatus.denied;
      }
    }
    if (mounted) setState(() => _statuses = entries);
  }

  Future<void> _grant(_AppPermission perm) async {
    PermissionStatus status;
    try {
      status = await perm.request();
    } catch (_) {
      status = PermissionStatus.permanentlyDenied;
    }
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      // Sin diálogo del sistema posible: mandar a ajustes.
      await openSystemAppSettings();
    }
    await _refresh();
  }

  /// Android no revoca en runtime: se explica y se abre ajustes.
  Future<void> _revokeExplainer(_AppPermission perm) async {
    if (!mounted) return;
    final open = await showNConfirmDialog(
      context,
      title: 'Quitar "${perm.title}"',
      message: 'Android no permite quitar permisos desde la app. '
          'Se abrirán los ajustes del sistema para que lo quites ahí.',
      confirmLabel: 'Abrir ajustes',
      isDestructive: false,
      icon: Icons.shield_outlined,
    );
    if (open == true) await openSystemAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_systemManaged) {
      return const NEmptyState(
        icon: Icons.security_outlined,
        title: 'Gestionado por el sistema',
        subtitle:
            'En escritorio no hay permisos en tiempo de ejecución.',
      );
    }
    final statuses = _statuses;
    if (statuses == null) {
      return const Center(child: NLoader(size: 44));
    }
    final perms = _appPermissions();
    return ListView(
      padding: const EdgeInsets.all(NSpacing.spaceMd),
      children: [
        NCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < perms.length; i++)
                _PermissionTile(
                  perm: perms[i],
                  granted: statuses[perms[i].id]?.isGranted ?? false,
                  isLast: i == perms.length - 1,
                  onToggle: (value) => value
                      ? _grant(perms[i])
                      : _revokeExplainer(perms[i]),
                ),
            ],
          ),
        ),
        const SizedBox(height: NSpacing.spaceMd),
        NCard(
          padding: EdgeInsets.zero,
          child: NOptionTile(
            icon: Icons.settings_outlined,
            color: NOptionTileColors.accentOf(context),
            title: 'Abrir ajustes del sistema',
            trailing: const Icon(Icons.chevron_right),
            onTap: openSystemAppSettings,
          ),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final _AppPermission perm;
  final bool granted;
  final bool isLast;
  final ValueChanged<bool> onToggle;

  const _PermissionTile({
    required this.perm,
    required this.granted,
    required this.isLast,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        NOptionTile(
          icon: perm.icon,
          color: granted
              ? NOptionTileColors.accentOf(context)
              : context.nMutedTextColor,
          title: perm.title,
          trailing: Switch.adaptive(
            value: granted,
            activeTrackColor: NOptionTileColors.accentOf(context),
            onChanged: onToggle,
          ),
          onTap: () => onToggle(!granted),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: NSpacing.spaceMd,
            endIndent: NSpacing.spaceMd,
            color: context.nMutedTextColor.withValues(alpha: 0.2),
          ),
      ],
    );
  }
}
