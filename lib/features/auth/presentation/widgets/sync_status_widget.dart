import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_manager.dart';
import '../../../../core/di/injection.dart';

class SyncStatusWidget extends StatelessWidget {
  final bool showLastSyncTime;
  final bool compact;

  const SyncStatusWidget({
    super.key,
    this.showLastSyncTime = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final authManager = getIt<AuthManager>();

    return ValueListenableBuilder<SyncStatus>(
      valueListenable: authManager.syncStatus,
      builder: (context, syncStatus, _) {
        return ValueListenableBuilder<DateTime?>(
          valueListenable: authManager.lastSyncTime,
          builder: (context, lastSyncTime, _) {
            Color color;
            IconData icon;
            String message;
            bool showSyncButton = false;

            switch (syncStatus) {
              case SyncStatus.syncing:
                color = Colors.blue;
                icon = Icons.sync;
                message = 'Syncing...';
                break;
              case SyncStatus.success:
                color = Colors.green;
                icon = Icons.check_circle;
                message = showLastSyncTime && lastSyncTime != null
                    ? 'Last synced: ${_formatDateTime(lastSyncTime)}'
                    : 'Synced';
                break;
              case SyncStatus.failed:
                color = Colors.red;
                icon = Icons.error_outline;
                message = 'Sync failed';
                showSyncButton = true;
                break;
              case SyncStatus.idle:
              default:
                color = Colors.grey;
                icon = Icons.sync_disabled;
                message = showLastSyncTime && lastSyncTime != null
                    ? 'Last synced: ${_formatDateTime(lastSyncTime)}'
                    : 'Not synced';
                showSyncButton = true;
                break;
            }

            if (compact) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (syncStatus == SyncStatus.syncing)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  else
                    Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    message,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ],
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (syncStatus == SyncStatus.syncing)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  else
                    Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                  if (showSyncButton && !authManager.isOfflineMode.value) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => authManager.syncAuthData(),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.refresh,
                          size: 14,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hr ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }
}