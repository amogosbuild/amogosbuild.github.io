// App ownership keeps installation, theme, and music state alive across every wizard page.
import 'package:flutter/material.dart';

import '../core/controllers/install_controller.dart';
import '../features/music/music_controller.dart';
import '../features/setup/setup_shell.dart';
import 'theme.dart';

class InstallerApp extends StatefulWidget {
  const InstallerApp({super.key, required this.preview});
  final bool preview;
  @override
  State<InstallerApp> createState() => _InstallerAppState();
}

class _InstallerAppState extends State<InstallerApp> {
  late final controller = InstallController(preview: widget.preview);
  late final music = MusicController();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: controller.darkTheme,
    child: SetupShell(controller: controller, music: music),
    builder: (context, dark, child) => MaterialApp(
      title: 'Install AmogOS 2 Pro',
      debugShowCheckedModeBanner: false,
      theme: installerTheme(false),
      darkTheme: installerTheme(true),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: child,
    ),
  );
  @override
  void dispose() {
    controller.dispose();
    music.dispose();
    super.dispose();
  }
}
