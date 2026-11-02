// Progress updates preserve the application theme and arcade subtree instead of rebuilding their resources.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_installer/app/installer_app.dart';
import 'package:amogos_installer/core/models/install_models.dart';
import 'package:amogos_installer/features/games/game_painter.dart';
import 'package:amogos_installer/features/setup/setup_shell.dart';

void main() {
  testWidgets(
    'package progress keeps application and arcade resources stable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 820);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const InstallerApp(preview: true));
      final controller = tester
          .widget<SetupShell>(find.byType(SetupShell))
          .controller;
      controller.change(() {
        controller.step = 6;
        controller.event = const InstallEvent(
          'updates',
          .83,
          'Updating packages',
        );
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final paints = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is GamePainter,
      );
      final painter = tester.widget<CustomPaint>(paints).painter;
      for (var index = 0; index < 100; index++) {
        controller.change(
          () => controller.event = InstallEvent(
            'updates',
            .83 + index * .0001,
            'Updating package $index',
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), same(app));
      expect(tester.widget<CustomPaint>(paints).painter, same(painter));
      controller.toggleTheme();
      await tester.pump();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
