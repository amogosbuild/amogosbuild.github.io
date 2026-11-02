// Wizard tests verify explicit confirmation, responsive themes, and real rendered preview artifacts.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_installer/app/installer_app.dart';
import 'package:amogos_installer/features/setup/setup_shell.dart';
import 'package:amogos_installer/core/models/install_models.dart';
import 'package:amogos_installer/features/music/source/models/track.dart';

void main() {
  Future<void> fonts() async {
    final text = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await text.load();
    await icons.load();
  }

  void size(WidgetTester tester, Size value) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = value;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.pump(const Duration(milliseconds: 500));
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final path = File('build/previews/$name.png');
      path.parent.createSync(recursive: true);
      path.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'renders light and pitch-black setup, storage, soundtrack, and arcade',
    (tester) async {
      size(tester, const Size(1280, 820));
      await fonts();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: const InstallerApp(preview: true)),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await capture(tester, key, 'welcome-light');
      final shell = tester.widget<SetupShell>(find.byType(SetupShell)),
          c = shell.controller;
      c.toggleTheme();
      await tester.pump(const Duration(milliseconds: 300));
      await capture(tester, key, 'welcome-black');
      await c.refreshHardware();
      c.change(() => c.step = 3);
      await tester.pump(const Duration(milliseconds: 300));
      await capture(tester, key, 'storage-black');
      c.toggleTheme();
      await tester.pump(const Duration(milliseconds: 300));
      await capture(tester, key, 'storage-light');
      c.change(() => c.step = 4);
      await tester.pump(const Duration(milliseconds: 300));
      await capture(tester, key, 'account-light');
      c.change(() {
        c.step = 6;
      });
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await capture(tester, key, 'install-light');
      c.toggleTheme();
      await tester.pump(const Duration(milliseconds: 300));
      await capture(tester, key, 'install-black');
      for (final game in [
        'Crossy Amogus',
        'Where is Amogus?',
        'Imposter Take Down',
      ]) {
        await tester.tap(find.text(game));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Tap to start'));
        for (var frame = 0; frame < 100; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await capture(
          tester,
          key,
          game.startsWith('Crossy')
              ? 'crossy-black'
              : game.startsWith('Where')
              ? 'hidden-black'
              : 'takedown-black',
        );
      }
      shell.music.queue.add(
        const Track(
          id: 'preview-track',
          title: 'AmogOS Installer Music',
          artist: 'Your installation soundtrack',
          source: MusicSource.youtube,
          sourceId: 'preview0000',
        ),
      );
      shell.music.queue.add(
        const Track(
          id: 'preview-track-2',
          title: 'A little room for play',
          artist: 'Playlist preview',
          source: MusicSource.youtube,
          sourceId: 'preview0001',
        ),
      );
      await tester.tap(find.text('Your soundtrack'));
      await tester.pump(const Duration(milliseconds: 400));
      await capture(tester, key, 'music-black');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'installation requires matching drive text and a checked acknowledgement',
    (tester) async {
      size(tester, const Size(1280, 820));
      await tester.pumpWidget(const InstallerApp(preview: true));
      final c = tester.widget<SetupShell>(find.byType(SetupShell)).controller;
      await c.refreshHardware();
      c.change(() {
        c.step = 3;
        c.rootGiB = 64;
      });
      await c.next();
      c.change(() {
        c.fullName = 'Alex';
        c.username = 'alex';
        c.password = 'test-passphrase';
        c.passwordAgain = 'test-passphrase';
      });
      await c.next();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Install AmogOS 2 Pro'));
      await tester.pump(const Duration(milliseconds: 300));
      final start = find.widgetWithText(FilledButton, 'Start preview');
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'nvme0n1');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.installing, isTrue);
      expect(find.text('A little fun while we unpack.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('custom boot placement survives review with both disk names', (
    tester,
  ) async {
    size(tester, const Size(1280, 820));
    await tester.pumpWidget(const InstallerApp(preview: true));
    final c = tester.widget<SetupShell>(find.byType(SetupShell)).controller;
    await c.refreshHardware();
    c.inventory!.disks.add(
      const InstallDisk(
        path: '/dev/sdb',
        model: 'Second preview SSD',
        size: 128849018880,
        table: 'gpt',
        partitions: [
          Partition(
            path: '/dev/sdb1',
            number: 1,
            start: 1048576,
            size: 1073741824,
            fs: 'vfat',
            esp: true,
          ),
        ],
      ),
    );
    c.change(() {
      c.step = 3;
      c.bootPlacement = 'custom';
      c.bootDisk = '/dev/sdb';
      c.bootPartition = '/dev/sdb1';
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Choose your bootloader'));
    await tester.pump();
    expect(find.text('EFI system partition'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await c.next();
    expect(c.proposal!.bootDescription, contains('/dev/sdb1'));
    expect(c.proposal!.confirmation, 'nvme0n1 + sdb');
    expect(c.options['bootDisk'], '/dev/sdb');
    c.change(() => c.bootloader = 'none');
    final skipped = await c.service.plan(c.options);
    expect(skipped.confirmation, 'nvme0n1');
    expect(skipped.operations.last, contains('existing bootloader'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('compact layout has no overflow in either theme', (tester) async {
    size(tester, const Size(1024, 768));
    await tester.pumpWidget(const InstallerApp(preview: true));
    final c = tester.widget<SetupShell>(find.byType(SetupShell)).controller;
    for (var stage = 0; stage < 5; stage++) {
      if (stage == 3) await c.refreshHardware();
      c.change(() => c.step = stage);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      c.toggleTheme();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
