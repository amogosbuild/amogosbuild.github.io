// Local APT repository choices remain usable while remote software catalogs are still loading.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_store/core/controllers/store_controller.dart';
import 'package:amogos_store/core/models/store_models.dart';
import 'package:amogos_store/core/services/store_service.dart';
import 'package:amogos_store/features/details/package_details.dart';

class SlowRemoteService extends StoreService {
  SlowRemoteService() : super(preview: true);
  final remote = Completer<Map<String, dynamic>>();
  Map<String, dynamic> item(String repo) => {
    'id': 'vlc',
    'name': 'VLC',
    'source': 'deb',
    'repo': repo,
    'version': '3.0.24',
    'summary': 'Video player',
  };
  List<Map<String, dynamic>> get choices => [
    item('security.debian.org|stable-security|main'),
    item('deb.debian.org|stable|main'),
  ];
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (action == 'alternatives') {
      return remote.future;
    }
    if (action == 'details') {
      return {...item(body['repo']), 'aptChoices': choices};
    }
    return {};
  }
}

void main() {
  testWidgets('main APT repo appears before slow remote catalogs finish', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = SlowRemoteService();
    final controller = StoreController(service: service);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackageDetails(
            controller: controller,
            initial: StorePackage(service.choices.first),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.remote.isCompleted, isFalse);
    expect(find.text('Repository'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('deb.debian.org · stable · main'), findsWidgets);
    service.remote.complete({'items': service.choices, 'warnings': []});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
