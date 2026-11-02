// A concrete transaction review precedes every queued package installation or system upgrade.
import 'package:flutter/material.dart';

import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';
import '../queue/queue_dialog.dart';

Future<bool> reviewTransaction(
  BuildContext context,
  StoreController c, {
  required String title,
  required String source,
  required String operation,
  required Map<String, dynamic> request,
}) async {
  Map<String, dynamic> review;
  try {
    if (source == 'appimage') {
      review = {
        'source': source,
        'summary': title,
        'changes': [
          {
            'id': request['filename'] ?? request['id'],
            'action': operation,
            'version': request['version'] ?? '',
          },
        ],
        'downloadBytes': request['size'] ?? 0,
        'note': operation == 'remove'
            ? 'Remove the AppImage and its desktop shortcut. Your application data is kept.'
            : 'AppImages are installed in your user account and run with your user permissions.',
      };
    } else {
      final prefix = source == 'deb' ? 'apt' : 'flatpak';
      review = await c.service.request('$prefix-plan', request);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(StoreController.clean(e))));
    }
    return false;
  }
  if (!context.mounted) return false;
  final changes = [
    for (final v in review['changes'] ?? []) Map<String, dynamic>.from(v),
  ];
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.all(12),
      title: Text(
        operation == 'upgrade-system'
            ? 'Update AmogOS 2 Pro?'
            : operation == 'remove'
            ? 'Remove $title?'
            : 'Add $title to the queue?',
      ),
      content: SizedBox(
        width: 530,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.preview
                    ? 'Design preview. No packages on this computer will be changed.'
                    : 'From ${sourceLabels[source] ?? source}',
                style: const TextStyle(fontSize: 13),
              ),
              if (review['note'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    review['note'],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                '${changes.length} package changes',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: (changes.length * 64.0).clamp(
                  64,
                  MediaQuery.sizeOf(context).height < 600 ? 140 : 230,
                ),
                child: ListView.builder(
                  itemCount: changes.length,
                  itemBuilder: (context, i) {
                    final change = changes[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Icon(
                            change['action'] == 'remove'
                                ? Icons.remove_circle_outline
                                : Icons.download_rounded,
                            size: 18,
                            color: change['action'] == 'remove'
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  change['id']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  change['version']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            change['action'] ?? '',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Download: ${byteSize(review['downloadBytes'] as num?)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (source == 'deb')
                Text(
                  'Disk space: ${byteSize(review['spaceBytes'] as num?)}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: changes.isEmpty
              ? null
              : () => Navigator.pop(context, true),
          child: Text(
            c.preview
                ? 'Queue preview'
                : operation == 'remove'
                ? 'Queue removal'
                : 'Add to queue',
          ),
        ),
      ],
    ),
  );
  if (accepted != true) return false;
  try {
    await c.enqueue(
      StoreJob(
        title: title,
        source: source,
        operation: operation,
        request: request,
        review: review,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title added to your queue'),
          action: SnackBarAction(
            label: 'View queue',
            onPressed: () => showQueue(context, c),
          ),
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(StoreController.clean(e))));
    }
    return false;
  }
}
