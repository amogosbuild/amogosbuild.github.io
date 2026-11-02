// Application entry point and explicit preview selection.
import 'dart:io';

import 'package:flutter/material.dart';

import 'app/installer_app.dart';

void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache
    ..maximumSize = 16
    ..maximumSizeBytes = 8 * 1024 * 1024;
  runApp(
    InstallerApp(preview: !Platform.isLinux || arguments.contains('--preview')),
  );
}
