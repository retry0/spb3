import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/espb_form_bloc.dart';

class EspbSyncStatusIndicator extends StatelessWidget {
  final String spbNumber;
  final bool compact;
  final VoidCallback? onRetry;

  const EspbSyncStatusIndicator({
    super.key,
    required this.spbNumber,
    this.compact = false,
    this.onRetry,
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
        
        // Check if this specific SPB was just saved
        final justSaved = state is EspbFormSaveSuccess && state.spbNumber == spbNumber;
        
        // Determine the current sync status
        final currentlySyncing = isSyncing || isAllSyncing;
        
        // Get sync status and error message
        String syncStatus;
        String? errorMessage;
        bool isSynced = false;
        
        if (state is EspbFormLoaded && state.formData.noSpb == spbNumber) {
          isSynced = state.formData.isSynced;
          syncStatus = isSynced ? 'synced' : 'unsynced';
        } else if (justSaved) {
          isSynced = (state as EspbFormSaveSuccess).isSynced;
          syncStatus = isSynced ? 'synced' : 'unsynced';
        } else if (currentlySyncing) {
          syncStatus = 'syncing';
        } else if (hasSyncError) {
          syncStatus = 'error';
          errorMessage = (state as EspbFormSyncFailure).message;
        } else {
          // Load the form to get its sync status
          context.read<EspbFormBloc>().add(EspbFormLoadRequested(spbNumber: spbNumber));
          syncStatus = 'loading';
        }
        
        if (compact) {
          return _buildCompactIndicator(context, syncStatus, errorMessage, isSynced);
        } else {
          return _buildFullIndicator(context, syncStatus, errorMessage, isSynced);
        }
      },
    );
  }
  
  Widget _buildCompactIndicator(
    BuildContext context, 
    String status, 
    String? errorMessage,
    bool isSynced,
  ) {
    IconData icon;
    Color color;
    
    switch (status) {
      case 'synced':
        icon = Icons.cloud_done;
        color = AppTheme.successColor;
        break;
      case 'syncing':
      case 'loading':
        icon = Icons.sync;
        color = AppTheme.infoColor;
        break;
      case 'error':
        icon = Icons.error_outline;
        color = AppTheme.errorColor;
        break;
      case 'unsynced':
        icon = Icons.cloud_upload;
        color = AppTheme.warningColor;
        break;
      default:
        icon = Icons.cloud_off;
        color = Colors.grey;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        status == 'syncing' || status == 'loading'
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
  
  Widget _buildFullIndicator(
    BuildContext context, 
    String status, 
    String? errorMessage,
    bool isSynced,
  ) {
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
      case 'loading':
        icon = Icons.hourglass_empty;
        color = AppTheme.infoColor;
        message = 'Checking sync status...';
        break;
      case 'error':
        icon = Icons.error_outline;
        color = AppTheme.errorColor;
        message = errorMessage ?? 'Error syncing with server';
        break;
      case 'unsynced':
        icon = Icons.cloud_upload;
        color = AppTheme.warningColor;
        message = 'Waiting to sync with server';
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
          status == 'syncing' || status == 'loading'
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
                if (status != 'syncing' && status != 'loading') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last updated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (status == 'unsynced' || status == 'error')
            TextButton.icon(
              onPressed: () {
                if (onRetry != null) {
                  onRetry!();
                } else {
                  context.read<EspbFormBloc>().add(
                    EspbFormSyncRequested(spbNumber: spbNumber),
                  );
                }
              },
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
      case 'loading':
        return 'Loading...';
      case 'error':
        return 'Sync Failed';
      case 'unsynced':
        return 'Not Synced';
      default:
        return 'Unknown';
    }
  }
}