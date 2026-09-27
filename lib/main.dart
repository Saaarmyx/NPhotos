import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import 'app/nphotos_app.dart';

void main() {
  AppAppearance.setAccentColor(NColors.photosAccent);
  runApp(const NPhotosApp());
}
