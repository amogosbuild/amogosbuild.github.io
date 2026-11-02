// Selection review requests contain only chosen packages and maintain independent format and scope choices.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_store/app/store_app.dart';
import 'package:amogos_store/core/controllers/store_controller.dart';
import 'package:amogos_store/core/models/store_models.dart';
import 'package:amogos_store/core/services/store_service.dart';
import 'package:amogos_store/features/updates/update_review.dart';

class ReviewService extends StoreService {
  ReviewService() : super(preview: true);
  final plans = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (action.endsWith('-plan')) {
      plans.add({...body});
    }
    return super.request(action, body);
  }
}

void main() {
  testWidgets(
    'selected APT update excludes unselected packages and other formats',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 480);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ReviewService();
      final controller = StoreController(service: service);
      await tester.runAsync(controller.initialize);
      await tester.pumpWidget(StoreApp(preview: true, controller: controller));
      controller.selectPage(StorePage.updates);
      await tester.pumpAndSettle();
      final apt = controller.updateItems('deb');
      controller.selectUpdate(
        'deb',
        StoreController.updateKey(apt.first),
        true,
      );
      controller.selectAllUpdates('appimage', true);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      final review = reviewSelectedUpdates(context, controller, 'deb');
      await tester.pumpAndSettle();
      expect(service.plans.single['packages'], [apt.first['id']]);
      expect(service.plans.single['operation'], 'update-selected');
      expect(find.text('1 package changes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await review;
      expect(controller.queue, isEmpty);
      expect(controller.updateSelections['appimage']!.length, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  test(
    'Flatpak queue review refuses changed origins even when commits match',
    () {
      final old = {
        'operation': 'update-selected',
        'commits': {'ref': 'abc'},
        'items': [
          {
            'reference': 'ref',
            'commit': 'abc',
            'scope': 'user',
            'origin': 'flathub',
            'remoteUrl': 'https://old.example',
          },
        ],
      };
      final fresh = {
        ...old,
        'items': [
          {
            'reference': 'ref',
            'commit': 'abc',
            'scope': 'user',
            'origin': 'flathub',
            'remoteUrl': 'https://new.example',
          },
        ],
      };
      expect(StoreController.sameFlatpakReview(old, fresh), isFalse);
      expect(StoreController.sameFlatpakReview(old, old), isTrue);
    },
  );
}
