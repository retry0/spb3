import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../data/models/espb_form_data.dart';
import '../bloc/espb_form_bloc.dart';
import '../bloc/espb_form_event.dart';
import '../bloc/espb_form_state.dart';

class EspbFormSyncIndicator extends StatelessWidget {
  final EspbFormData formData;
  final bool compact;

  const EspbFormSyncIndicator({
    super.key,
    required this.formData,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EspbFormBloc, EspbFormState>(
      builder: (context, state) {
        // Determine if this form is currently syncing
        bool isSyncing = false;
        if (state is EspbFormSyncLoading) {
          isSyncing = state.formData.id == formData.id;
        }

        // Determine sync status
        final bool isSynced = formData.isSynced;
        final bool hasSyncError = !isSynced && formData.lastError != null;
        final bool hasExceededRetries = formData.retryCount >= 5;

        // Determine colors and icons
        Color color;
        IconData icon;
        String message;

        if (isSyncing) {
          color = Colors.blue;
          icon = Icons.sync;
          message = 'Syncing...';
        } else if (isSynced) {
          color = Colors.green;
          icon = Icons.check_circle;
          message = formData.syncedAt != null
              ? 'Synced: ${_formatDateTime(formData.syncedAt!)}'
              : 'Synced';
        } else if (hasExceededRetries) {
          color = Colors.red;
          icon = Icons.error_outline;
          message = 'Sync failed: Max retries exceeded';
        } else if (hasSyncError) {
          color = Colors.orange;
          icon = Icons.sync_problem;
          message = 'Sync failed: ${formData.lastError}';
        } else {
          color = Colors.grey;
          icon = Icons.sync_disabled;
          message = 'Pending sync';
        }

        if (compact) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSyncing)
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
                isSynced ? 'Synced' : 'Pending',
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
              if (isSyncing)
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
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ),
              if (!isSynced && !isSyncing && !hasExceededRetries)
                InkWell(
                  onTap: () => _retrySync(context),
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
          ),
        );
      },
    );
  }

  void _retrySync(BuildContext context) {
    context.read<EspbFormBloc>().add(SyncFormRequested(formId: formData.id));
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