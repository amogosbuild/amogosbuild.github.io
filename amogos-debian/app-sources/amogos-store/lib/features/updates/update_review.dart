// Selected updates preserve each Flatpak scope and the reviewed AppImage publisher build.
import 'package:flutter/material.dart';

import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';
import '../details/transaction_review.dart';

Future<void> reviewSelectedUpdates(
  BuildContext context,
  StoreController c,
  String source,
) async {
  final keys = c.updateSelections[source] ?? <String>{};
  final items = c
      .updateItems(source)
      .where((v) => keys.contains(StoreController.updateKey(v)))
      .toList();
  if (items.isEmpty) return;
  if (source == 'deb') {
    await reviewTransaction(
      context,
      c,
      title: '${items.length} selected APT updates',
      source: source,
      operation: 'update-selected',
      request: {
        'source': source,
        'operation': 'update-selected',
        'packages': [for (final v in items) v['id']],
      },
    );
    return;
  }
  if (source == 'flatpak') {
    for (final scope in ['system', 'user']) {
      final group = items
          .where((v) => (v['scope'] ?? 'system') == scope)
          .toList();
      if (group.isEmpty || !context.mounted) continue;
      await reviewTransaction(
        context,
        c,
        title:
            '${group.length} ${scope == 'user' ? 'user' : 'system'} Flatpak updates',
        source: source,
        operation: 'update-selected',
        request: {
          'source': source,
          'operation': 'update-selected',
          'scope': scope,
          'packages': [
            for (final v in group) {'id': v['id'], 'reference': v['reference']},
          ],
        },
      );
    }
    return;
  }
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.all(12),
      title: const Text('Update selected AppImages?'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'These publisher builds will replace the AppImages in your account. Application data is kept.',
              ),
              for (final v in items)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    '${v['name']}\n${v['fromVersion']} → ${v['version']}',
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Download: ${byteSize(items.fold<num>(0, (sum, v) => sum + (v['size'] as num? ?? 0)))}',
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
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Add to queue'),
        ),
      ],
    ),
  );
  if (accepted != true) return;
  for (final v in items) {
    try {
      await c.enqueue(
        StoreJob(
          title: v['name'] ?? v['id'],
          source: source,
          operation: 'update',
          request: {...v, 'operation': 'update'},
          review: {
            'changes': [v],
            'downloadBytes': v['size'],
          },
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(StoreController.clean(error))));
      }
    }
  }
}
