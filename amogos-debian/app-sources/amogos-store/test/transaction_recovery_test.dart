// Reopening the Store reconnects to a root worker without replaying the transaction or overlapping its queue.
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_store/core/controllers/store_controller.dart';
import 'package:amogos_store/core/models/store_models.dart';
import 'package:amogos_store/core/services/store_service.dart';

class RecoveredService extends StoreService {
  RecoveredService() : super(preview: false);
  String status = 'running';
  int applications = 0;
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (action == 'transactions') {
      return {
        'items': [
          {
            'transactionId': 'background-id',
            'source': 'deb',
            'operation': 'install',
            'package': 'kdenlive',
            'title': 'Install Kdenlive',
            'status': status,
            'message': status == 'running'
                ? 'Configuring packages'
                : 'Package changes complete',
            'progress': status == 'running' ? 0.8 : 1,
          },
        ],
      };
    }
    if (action == 'apt-plan') {
      return {'changes': [], 'token': 'fresh'};
    }
    return {};
  }

  @override
  Stream<Map<String, dynamic>> execute(
    String action,
    Map<String, dynamic> body,
  ) async* {
    applications++;
    yield {'done': true, 'progress': 1, 'message': 'Complete'};
  }
}

void main() {
  test(
    'a recovered running job holds the local queue until it completes',
    () async {
      final service = RecoveredService();
      final controller = StoreController(service: service);
      await controller.restoreTransactions();
      expect(controller.currentJob?.request['id'], 'kdenlive');
      expect(controller.waitingCount, 1);
      await controller.enqueue(
        StoreJob(
          title: 'VLC',
          source: 'deb',
          operation: 'install',
          request: {'id': 'vlc'},
          review: {'changes': []},
        ),
      );
      expect(service.applications, 0);
      await controller.restoreTransactions();
      expect(controller.queue.length, 2);
      service.status = 'completed';
      await controller.restoreTransactions();
      for (var i = 0; i < 20 && controller.queueRunning; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(service.applications, 1);
      expect(
        controller.queue.every((j) => j.status == JobStatus.completed),
        isTrue,
      );
      controller.dispose();
    },
  );
  test('a recovered failed transaction remains visible and is not retried automatically', () async {
    final service = RecoveredService()..status = 'failed';
    final controller = StoreController(service: service);
    await controller.restoreTransactions();
    expect(controller.queue.single.status, JobStatus.failed);
    expect(service.applications, 0);
    controller.dispose();
  });
}
