// Rendered flow tests cover source availability, animated navigation, themes, and a real serial preview queue.
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_store/app/store_app.dart';
import 'package:amogos_store/core/controllers/store_controller.dart';
import 'package:amogos_store/core/models/store_models.dart';
import 'package:amogos_store/core/services/store_service.dart';
import 'package:amogos_store/features/details/package_details.dart';

class FixedRandom implements Random {
  FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  bool nextBool() => value < .5;
  @override
  int nextInt(int max) => (value * max).floor();
}

void main() {
  Future<void> fonts() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  }

  void size(WidgetTester tester, Size value) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = value;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<StoreController> start(WidgetTester tester, {GlobalKey? key}) async {
    await tester.runAsync(fonts);
    final c = StoreController(
      service: StoreService(preview: true),
      random: FixedRandom(.6),
    );
    await tester.runAsync(c.service.initialize);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: StoreApp(preview: true, controller: c),
      ),
    );
    for (
      var frame = 0;
      frame < 30 && (c.loading || c.loadingSources || c.featured == null);
      frame++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    {
      final context = tester.element(find.byType(Scaffold).first);
      const icons = [
        'org.videolan.VLC',
        'com.valvesoftware.Steam',
        'com.heroicgameslauncher.hgl',
        'com.discordapp.Discord',
        'com.thebrokenrail.MCPIReborn',
      ];
      final precaching = Future.wait([
        for (final id in icons)
          precacheImage(AssetImage('assets/catalog/$id.png'), context),
        precacheImage(
          const AssetImage('assets/catalog/vlc-banner.png'),
          context,
        ),
        for (final file in [
          'shopper-darkmode.png',
          'shopper-lightmode.png',
          'wideshopper.png',
          'sillyshopper.png',
          'rippedbagshopper.png',
        ])
          precacheImage(AssetImage('assets/characters/$file'), context),
      ]);
      unawaited(precaching);
    }
    for (var frame = 0; frame < 6; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
    c.name = 'Bob';
    c.changed();
    await tester.pump(const Duration(milliseconds: 450));
    addTearDown(c.dispose);
    return c;
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 12)),
      );
      await tester.pump(const Duration(milliseconds: 90));
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/previews/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'renders the supplied design in black and light, plus source choices and queue',
    (tester) async {
      size(tester, const Size(1304, 843));
      await fonts();
      final key = GlobalKey(), c = await start(tester, key: key);
      expect(c.essentials.length, 4);
      await capture(tester, key, 'home-black');
      c.toggleTheme();
      await capture(tester, key, 'home-light');
      c.toggleTheme();
      final context = tester.element(find.byType(StoreApp));
      final targetContext = tester.element(find.byType(Scaffold).first);
      final vlc = c.service.samples.firstWhere(
        (p) => p.id == 'org.videolan.VLC',
      );
      showPackage(targetContext, c, vlc);
      await tester.pump(const Duration(milliseconds: 450));
      await capture(tester, key, 'app-source-picker');
      final fields = find.descendant(
        of: find.byType(PackageDetails),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      final picker = tester.widget<DropdownButtonFormField<String>>(
        fields.first,
      );
      final renderedPicker = tester.widget<DropdownButton<String>>(
        find
            .descendant(
              of: fields.first,
              matching: find.byType(DropdownButton<String>),
            )
            .first,
      );
      expect(renderedPicker.items!.map((v) => v.value).toSet(), {
        'flatpak',
        'deb',
      });
      expect(renderedPicker.items!.any((v) => v.value == 'appimage'), isFalse);
      picker.onChanged!('deb');
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(fields.first)
            .initialValue,
        'deb',
      );
      Navigator.of(targetContext).pop();
      await tester.pump(const Duration(milliseconds: 400));
      c.selectPage(StorePage.updates);
      await tester.pump(const Duration(milliseconds: 400));
      await capture(tester, key, 'system-updates');
      c.selectPage(StorePage.sources);
      await tester.pump(const Duration(milliseconds: 400));
      await capture(tester, key, 'sources');
      c.selectPage(StorePage.home);
      await tester.pump(const Duration(milliseconds: 400));
      for (final id in ['com.valvesoftware.Steam', 'com.discordapp.Discord']) {
        final request = {'id': id, 'source': 'flatpak', 'operation': 'install'};
        final review = await c.service.request('flatpak-plan', request);
        await c.enqueue(
          StoreJob(
            title: id.contains('Steam') ? 'Steam' : 'Discord',
            source: 'flatpak',
            operation: 'install',
            request: request,
            review: review,
          ),
        );
      }
      await tester.pump(const Duration(milliseconds: 160));
      expect(c.queue.where((j) => j.active).length, 1);
      expect(c.queue.where((j) => j.pending).length, 1);
      await tester.tap(find.byKey(const ValueKey('queue-button')));
      await tester.pump(const Duration(milliseconds: 350));
      await capture(tester, key, 'installation-queue');
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 160));
      }
      expect(c.queue.every((j) => j.status == JobStatus.completed), isTrue);
      expect(context.mounted, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'navigation dot animates between labels and the selected category is bold',
    (tester) async {
      size(tester, const Size(1024, 768));
      final c = await start(tester);
      final dot = find.byKey(const ValueKey('navigation-dot'));
      final before = tester.getTopLeft(dot).dy;
      await tester.tap(find.text('Categories'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 190));
      final middle = tester.getTopLeft(dot).dy;
      expect(middle, greaterThan(before));
      expect(middle, lessThan(before + 51));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getTopLeft(dot).dy, closeTo(before + 51, .1));
      final label = tester.widget<AnimatedDefaultTextStyle>(
        find.byWidgetPredicate(
          (w) =>
              w is AnimatedDefaultTextStyle &&
              w.child is Text &&
              (w.child as Text).data == 'Categories',
        ),
      );
      expect(label.style.fontWeight, FontWeight.w800);
      expect(c.page, StorePage.categories);
      for (final page in StorePage.values) {
        c.selectPage(page);
        await tester.pump(const Duration(milliseconds: 450));
        expect(tester.takeException(), isNull);
        c.toggleTheme();
        await tester.pump(const Duration(milliseconds: 450));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('a single-source app never offers unavailable formats', (
    tester,
  ) async {
    size(tester, const Size(1024, 768));
    final c = await start(tester);
    final mcpi = c.service.samples.firstWhere(
      (p) => p.id == 'com.thebrokenrail.MCPIReborn',
    );
    showPackage(tester.element(find.byType(Scaffold).first), c, mcpi);
    await tester.pump(const Duration(milliseconds: 450));
    final picker = tester.widget<DropdownButtonFormField<String>>(
      find
          .descendant(
            of: find.byType(PackageDetails),
            matching: find.byType(DropdownButtonFormField<String>),
          )
          .first,
    );
    final actual = tester.widget<DropdownButton<String>>(
      find
          .descendant(
            of: find.byType(PackageDetails),
            matching: find.byType(DropdownButton<String>),
          )
          .first,
    );
    expect(actual.items!.map((v) => v.value).toList(), ['flatpak']);
    expect(picker.initialValue, 'flatpak');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'three-format apps expose APT, Flatpak, and compatible AppImage builds',
    (tester) async {
      size(tester, const Size(1024, 768));
      final key = GlobalKey(), c = await start(tester, key: key);
      final krita = c.service.samples.firstWhere(
        (p) => p.id == 'org.kde.krita' && p.source == 'flatpak',
      );
      final choices = await c.service.request('alternatives', krita.request);
      expect((choices['items'] as List).map((v) => v['source']).toSet(), {
        'deb',
        'flatpak',
        'appimage',
      });
      showPackage(tester.element(find.byType(Scaffold).first), c, krita);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 100));
      final fields = find.descendant(
        of: find.byType(PackageDetails),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      final actual = tester.widget<DropdownButton<String>>(
        find
            .descendant(
              of: fields.first,
              matching: find.byType(DropdownButton<String>),
            )
            .first,
      );
      expect(actual.items!.map((v) => v.value).toSet(), {
        'deb',
        'flatpak',
        'appimage',
      });
      final format = tester.widget<DropdownButtonFormField<String>>(
        fields.first,
      );
      format.onChanged!('appimage');
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('AppImage build'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(fields.first)
            .initialValue,
        'appimage',
      );
      await capture(tester, key, 'appimage-source-choice');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'missing Flatpak explains the requirement and disables app installation',
    (tester) async {
      size(tester, const Size(1024, 768));
      final key = GlobalKey(), c = await start(tester, key: key);
      c.flatpakAvailable = false;
      c.changed();
      final steam = c.service.samples.firstWhere(
        (p) => p.id == 'com.valvesoftware.Steam',
      );
      showPackage(tester.element(find.byType(Scaffold).first), c, steam);
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        find.text(
          'Flatpak needs to be installed before you can install this app.',
        ),
        findsOneWidget,
      );
      expect(find.text('Install Flatpak'), findsOneWidget);
      final install = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Install preview'),
      );
      expect(install.onPressed, isNull);
      await capture(tester, key, 'flatpak-required');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  test(
    'special shopper selection is rare and stays stable within a session',
    () {
      final rare = StoreController(
        service: StoreService(preview: true),
        random: FixedRandom(.01),
      );
      final semi = StoreController(
        service: StoreService(preview: true),
        random: FixedRandom(.06),
      );
      final ordinary = StoreController(
        service: StoreService(preview: true),
        random: FixedRandom(.6),
      );
      expect(rare.shopper, 'rareshopper.png');
      expect(semi.shopper, 'semirareshopper.png');
      expect(ordinary.shopper, 'shopper-darkmode.png');
      ordinary.toggleTheme();
      expect(ordinary.shopper, 'shopper-lightmode.png');
      rare.toggleTheme();
      expect(rare.shopper, 'rareshopper.png');
      rare.dispose();
      semi.dispose();
      ordinary.dispose();
    },
  );
}
