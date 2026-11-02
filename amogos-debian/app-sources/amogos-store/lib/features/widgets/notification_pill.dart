// A root-layer notification pill stays above dialogs and expires independently of route animations.
import 'package:flutter/material.dart';

import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';

class NotificationPillHost extends StatelessWidget {
  const NotificationPillHost({
    super.key,
    required this.controller,
    required this.child,
    required this.onViewQueue,
  });
  final StoreController controller;
  final Widget child;
  final VoidCallback onViewQueue;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      Positioned(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        child: SafeArea(
          top: false,
          child: Center(
            child: ValueListenableBuilder<StoreNotification?>(
              valueListenable: controller.notification,
              builder: (context, notification, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: notification == null
                    ? const SizedBox.shrink()
                    : ConstrainedBox(
                        key: ValueKey(notification.id),
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Material(
                          key: const ValueKey('notification-pill'),
                          elevation: 12,
                          shadowColor: Colors.black54,
                          color: Theme.of(context).colorScheme.inverseSurface,
                          borderRadius: BorderRadius.circular(32),
                          child: Semantics(
                            liveRegion: true,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .inversePrimary,
                                    size: 21,
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      notification.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onInverseSurface,
                                      ),
                                    ),
                                  ),
                                  if (notification.showQueue)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .inversePrimary,
                                      ),
                                      onPressed: () {
                                        controller.dismissNotification();
                                        onViewQueue();
                                      },
                                      child: const Text('View queue'),
                                    ),
                                  Semantics(
                                    label: 'Dismiss notification',
                                    button: true,
                                    child: IconButton(
                                      onPressed: controller.dismissNotification,
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 17,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onInverseSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
