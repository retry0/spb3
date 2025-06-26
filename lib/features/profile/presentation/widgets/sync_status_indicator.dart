import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/sync_service.dart';
import '../bloc/profile_bloc.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is ProfileLoaded) {
          return _buildSyncStatus(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSyncStatus(BuildContext context, ProfileLoaded state) {
    final syncStatus = state.syncStatus;
    final lastSyncTime = state.lastSyncTime;
    final syncError = state.syncError;
    Color backgroundColor;
    IconData icon;
    String message;
    bool showRetry = false;
    switch (syncStatus) {
      case SyncStatus.syncing:
        backgroundColor = Colors.blue.withOpacity(0.1);
        icon = Icons.sync;
        message = 'Syncing profile data...';
        break;
      case SyncStatus.success:
        backgroundColor = Colors.green.withOpacity(0.1);
        icon = Icons.check_circle;
        message =
            lastSyncTime != null
                ? 'Last synced: ${DateFormat('MMM d, h:mm a').format(lastSyncTime)}'
                : 'Profile synced successfully';
        break;
      case SyncStatus.failed:
        backgroundColor = Colors.red.withOpacity(0.1);
        icon = Icons.error_outline;
        message = syncError ?? 'Sync failed. Tap to retry.';
        showRetry = true;
        break;
      case SyncStatus.idle:
      default:
        if (lastSyncTime != null) {
          backgroundColor = Colors.grey.withOpacity(0.1);
          icon = Icons.access_time;
          message =
              'Last synced: ${DateFormat('MMM d, h:mm a').format(lastSyncTime)}';
        } else {
          return const SizedBox.shrink(); // Don't show anything if never synced
        }
    }
    return Card(
      color: backgroundColor,
      child: InkWell(
        onTap: showRetry ? () => _retrySync(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              syncStatus == SyncStatus.syncing
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                  : Icon(
                    icon,
                    size: 20,
                    color: _getIconColor(syncStatus, context),
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: _getTextColor(syncStatus, context),
                  ),
                ),
              ),
              if (showRetry)
                TextButton(
                  onPressed: () => _retrySync(context),
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getIconColor(SyncStatus status, BuildContext context) {
    switch (status) {
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.syncing:
        return Theme.of(context).colorScheme.primary;
      case SyncStatus.idle:
      default:
        return Colors.grey;
    }
  }

  Color _getTextColor(SyncStatus status, BuildContext context) {
    switch (status) {
      case SyncStatus.success:
        return Colors.green.shade800;
      case SyncStatus.failed:
        return Colors.red.shade800;
      case SyncStatus.syncing:
        return Theme.of(context).colorScheme.primary;
      case SyncStatus.idle:
      default:
        return Colors.grey.shade800;
    }
  }

  void _retrySync(BuildContext context) {
    context.read<ProfileBloc>().add(const ProfileSyncRequested());
  }
}
