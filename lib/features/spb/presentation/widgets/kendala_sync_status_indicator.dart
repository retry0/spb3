import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/services/kendala_form_sync_service.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/database_helper.dart';

/// A widget that displays the sync status of kendala forms
class KendalaSyncStatusIndicator extends StatefulWidget {
  /// The SPB number to check sync status for
  /// If null, shows overall sync status
  final String? spbNumber;

  /// Whether to show a compact version of the indicator
  final bool compact;

  /// Callback when retry is pressed
  final VoidCallback? onRetry;

  const KendalaSyncStatusIndicator({
    super.key,
    this.spbNumber,
    this.compact = false,
    this.onRetry,
  });

  @override
  State<KendalaSyncStatusIndicator> createState() =>
      _KendalaSyncStatusIndicatorState();
}

class _KendalaSyncStatusIndicatorState
    extends State<KendalaSyncStatusIndicator> {
  final KendalaFormSyncService _syncService = getIt<KendalaFormSyncService>();
  final DatabaseHelper _dbHelper = getIt<DatabaseHelper>();
  bool _isSynced = false;
  bool _isLoading = true;
  int _retryCount = 0;
  String? _lastError;
  DateTime? _lastSyncAttempt;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();
  }

  Future<void> _checkSyncStatus() async {
    setState(() {
      _isLoading = true;
    });

    if (widget.spbNumber != null) {
      // Check specific form sync status
      await _checkSpecificFormStatus(widget.spbNumber!);
    } else {
      // Check overall sync status
      await _checkOverallSyncStatus();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkSpecificFormStatus(String spbNumber) async {
    try {
      // First check SQLite
      final sqliteData = await _dbHelper.getKendalaForm(spbNumber);
      
      if (sqliteData != null) {
        setState(() {
          _isSynced = sqliteData['is_synced'] == 1;
          _retryCount = sqliteData['retry_count'] as int? ?? 0;
          _lastError = sqliteData['last_error'] as String?;
          
          final lastSyncAttemptTimestamp = sqliteData['last_sync_attempt'] as int?;
          _lastSyncAttempt = lastSyncAttemptTimestamp != null 
              ? DateTime.fromMillisecondsSinceEpoch(lastSyncAttemptTimestamp * 1000)
              : null;
        });
        return;
      }
      
      // Fallback to SharedPreferences
      final isSynced = await _syncService.isFormSynced(spbNumber);

      setState(() {
        _isSynced = isSynced;
      });
    } catch (e) {
      // Handle error silently
      setState(() {
        _isSynced = false;
        _lastError = 'Error checking sync status: $e';
      });
    }
  }

  Future<void> _checkOverallSyncStatus() async {
    try {
      final stats = await _syncService.getSyncStats();
      
      setState(() {
        _isSynced = stats.pendingForms == 0;
      });
    } catch (e) {
      // Handle error silently
      setState(() {
        _isSynced = false;
        _lastError = 'Error checking sync status: $e';
      });
    }
  }

  void _handleRetry() {
    if (widget.onRetry != null) {
      widget.onRetry!();
    } else {
      if (widget.spbNumber != null) {
        _syncService.syncForm(widget.spbNumber!).then((_) {
          _checkSyncStatus();
        });
      } else {
        _syncService.forceSyncNow().then((_) {
          _checkSyncStatus();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.compact ? _buildCompactLoading() : _buildFullLoading();
    }

    return ValueListenableBuilder<SyncStatus>(
      valueListenable: _syncService.syncStatusNotifier,
      builder: (context, syncStatus, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: _syncService.errorMessageNotifier,
          builder: (context, errorMessage, _) {
            return ValueListenableBuilder<DateTime?>(
              valueListenable: _syncService.lastSyncTimeNotifier,
              builder: (context, lastSyncTime, _) {
                // Determine current status
                final bool isSyncing = syncStatus == SyncStatus.syncing;
                final bool hasError = (_lastError != null || errorMessage != null) && !_isSynced;

                if (widget.compact) {
                  return _buildCompactIndicator(
                    isSyncing,
                    hasError,
                    lastSyncTime ?? _lastSyncAttempt,
                  );
                } else {
                  return _buildFullIndicator(
                    isSyncing,
                    hasError,
                    _lastError ?? errorMessage,
                    lastSyncTime ?? _lastSyncAttempt,
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCompactLoading() {
    return const SizedBox(
      height: 20,
      child: Center(
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildFullLoading() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          const Text('Checking sync status...'),
        ],
      ),
    );
  }

  Widget _buildCompactIndicator(
    bool isSyncing,
    bool hasError,
    DateTime? lastSyncTime,
  ) {
    IconData icon;
    Color color;
    String text;

    if (isSyncing) {
      icon = Icons.sync;
      color = AppTheme.infoColor;
      text = 'Syncing...';
    } else if (_isSynced) {
      icon = Icons.cloud_done;
      color = AppTheme.successColor;
      text = 'Synced';
    } else if (hasError) {
      icon = Icons.error_outline;
      color = AppTheme.errorColor;
      text = 'Sync failed';
    } else {
      icon = Icons.cloud_upload;
      color = AppTheme.warningColor;
      text = 'Not synced';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isSyncing
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
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildFullIndicator(
    bool isSyncing,
    bool hasError,
    String? errorMessage,
    DateTime? lastSyncTime,
  ) {
    IconData icon;
    Color color;
    String title;
    String message;

    if (isSyncing) {
      icon = Icons.sync;
      color = AppTheme.infoColor;
      title = 'Syncing Data';
      message = 'Synchronizing data with server...';
    } else if (_isSynced) {
      icon = Icons.cloud_done;
      color = AppTheme.successColor;
      title = 'Data Synced';
      message = 'All data is synchronized with the server';
    } else if (hasError) {
      icon = Icons.error_outline;
      color = AppTheme.errorColor;
      title = 'Sync Failed';
      message = errorMessage ?? 'Failed to synchronize data with server';
      
      // Add retry count information if available
      if (_retryCount > 0) {
        message += ' (Retry attempts: $_retryCount)';
      }
    } else {
      icon = Icons.cloud_upload;
      color = AppTheme.warningColor;
      title = 'Not Synced';
      message = 'Data is stored locally and will be synced when online';
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
          isSyncing
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
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
                ),
                if (lastSyncTime != null && !isSyncing) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last sync: ${DateFormat('dd MMM yyyy, HH:mm').format(lastSyncTime)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!_isSynced && !isSyncing)
            TextButton.icon(
              onPressed: _handleRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
              ),
            ),
        ],
      ),
    );
  }
}