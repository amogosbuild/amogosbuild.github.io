// The queue presents the active operation, pending packages, and useful completion logs.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/store_theme.dart';
import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';

Future<void> showQueue(
  BuildContext context,
  StoreController controller,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: SizedBox(
      width: 650,
      height: 610,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 20, 12, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.downloading_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your queue',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close queue',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Text(
                controller.waitingCount == 0
                    ? 'A little patience. A lot to look forward to.'
                    : '${controller.waitingCount} package operations · one at a time',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child:
                  controller.queue
                      .where((j) => j.status != JobStatus.removed)
                      .isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/characters/wideshopper.png',
                            width: 230,
                            height: 105,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Your bag is empty.',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'Find an app you like. We’ll take care of the queue.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      children: [
                        for (final job in controller.queue.where(
                          (j) => j.status != JobStatus.removed,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _JobCard(job: job, controller: controller),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.controller});
  final StoreJob job;
  final StoreController controller;
  @override
  Widget build(BuildContext context) {
    final failed = job.status == JobStatus.failed;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (failed)
                Image.asset(
                  'assets/characters/rippedbagshopper.png',
                  width: 44,
                  height: 44,
                )
              else
                Icon(
                  job.status == JobStatus.completed
                      ? Icons.check_circle_rounded
                      : job.pending
                      ? Icons.schedule_rounded
                      : Icons.downloading_rounded,
                  color: job.status == JobStatus.completed
                      ? const Color(0xff35d688)
                      : Theme.of(context).colorScheme.primary,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sourceLabels[job.source] ?? 'System indexes',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (job.pending)
                IconButton(
                  onPressed: () => controller.removeQueued(job),
                  tooltip: 'Remove from queue',
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              if (job.active && job.progress != null)
                Text(
                  '${(job.progress! * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (job.active) ...[
            LinearProgressIndicator(
              value: job.progress,
              minHeight: 5,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            job.message,
            style: TextStyle(
              fontSize: 11,
              color: failed
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (job.log.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: job.log.join('\n'))),
                icon: const Icon(Icons.copy_rounded, size: 13),
                label: const Text('Copy log', style: TextStyle(fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }
}
