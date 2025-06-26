import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/espb_form_bloc.dart';
import '../../../../core/theme/app_theme.dart';

class EspbFormSyncIndicator extends StatelessWidget {
  final String spbNumber;
  final bool isSynced;
  final DateTime timestamp;
  final VoidCallback? onRetry;
  final bool compact;

  const EspbFormSyncIndicator({
    super.key,
    required this.spbNumber,
    required this.isSynced,
    required this.timestamp,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EspbFormBloc, EspbFormState>(
      builder: (context, state) {
        // Check if this specific SPB is currently syncing
        final isSyncing = state is EspbFormSyncing && state.spbNumber == spbNumber;
        
        // Check if this specific SPB just had a sync error
        final hasSyncError = state is EspbFormSyncFailure && state.spbNumber == spbNumber;
        
        // Check if all SPBs are being synced
        final isAllSyncing = state is EspbFormSyncingAll;
        
        // Determine the current sync status
        final currentlySyncing = isSyncing || isAllSyncing;
        final currentSyncStatus = isSynced ? 'synced' : (currentlySyncing ? 'syncing' : 'unsynced');
        
        // Get error message if any
        final errorMessage = hasSyncError ? state.message : null;
        
        if (compact) {
          return _buildCompactIndicator(context, currentSyncStatus, errorMessage);
        } else {
          return _buildFullIndicator(context, currentSyncStatus, errorMessage);
        }
      },
    );
  }
  
  Widget _buildCompactIndicator(BuildContext context, String status, String? errorMessage) {
    IconData icon;
    Color color;
    
    switch (status) {
      case 'synced':
        icon = Icons.cloud_done;
        color = AppTheme.successColor;
        break;
      case 'syncing':
        icon = Icons.sync;
        color = AppTheme.infoColor;
        break;
      case 'unsynced':
        icon = Icons.cloud_upload;
        color = errorMessage != null ? AppTheme.errorColor : AppTheme.warningColor;
        break;
      default:
        icon = Icons.cloud_off;
        color = Colors.grey;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        status == 'syncing'
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          _getSyncStatusText(status),
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
  
  Widget _buildFullIndicator(BuildContext context, String status, String? errorMessage) {
    IconData icon;
    Color color;
    String message;
    
    switch (status) {
      case 'synced':
        icon = Icons.cloud_done;
        color = AppTheme.successColor;
        message = 'Data synced with server';
        break;
      case 'syncing':
        icon = Icons.sync;
        color = AppTheme.infoColor;
        message = 'Syncing data with server...';
        break;
      case 'unsynced':
        icon = Icons.cloud_upload;
        color = errorMessage != null ? AppTheme.errorColor : AppTheme.warningColor;
        message = errorMessage ?? 'Waiting to sync with server';
        break;
      default:
        icon = Icons.cloud_off;
        color = Colors.grey;
        message = 'Unknown sync status';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          status == 'syncing'
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getSyncStatusText(status),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                  ),
                ),
                if (status != 'syncing') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last updated: ${DateFormat('dd MMM yyyy, HH:mm').format(timestamp)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (status == 'unsynced' && onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
            ),
        ],
      ),
    );
  }
  
  String _getSyncStatusText(String status) {
    switch (status) {
      case 'synced':
        return 'Synced';
      case 'syncing':
        return 'Syncing...';
      case 'unsynced':
        return 'Not Synced';
      default:
        return 'Unknown';
    }
  }
}