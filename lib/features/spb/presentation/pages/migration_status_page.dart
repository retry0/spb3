import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../data/services/kendala_form_migration_service.dart';

class MigrationStatusPage extends StatefulWidget {
  const MigrationStatusPage({super.key});

  @override
  State<MigrationStatusPage> createState() => _MigrationStatusPageState();
}

class _MigrationStatusPageState extends State<MigrationStatusPage> {
  final KendalaFormMigrationService _migrationService = getIt<KendalaFormMigrationService>();
  bool _migrationStarted = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Migration'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildMigrationStatus(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Database Migration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'This tool will migrate all Kendala form data from SharedPreferences to SQLite database. '
              'This is a one-time operation and is necessary for improved performance and reliability.',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Make sure you have a stable internet connection before starting the migration.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMigrationStatus() {
    return ValueListenableBuilder<MigrationStatus>(
      valueListenable: _migrationService.migrationStatusNotifier,
      builder: (context, status, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: _migrationService.errorMessageNotifier,
          builder: (context, errorMessage, _) {
            return ValueListenableBuilder<int>(
              valueListenable: _migrationService.progressNotifier,
              builder: (context, progress, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: _migrationService.totalItemsNotifier,
                  builder: (context, totalItems, _) {
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildStatusIcon(status),
                                const SizedBox(width: 8),
                                Text(
                                  _getStatusText(status),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(status),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (status == MigrationStatus.inProgress || status == MigrationStatus.cleaning) ...[
                              LinearProgressIndicator(
                                value: totalItems > 0 ? progress / totalItems : null,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                totalItems > 0
                                    ? 'Progress: $progress / $totalItems items'
                                    : 'Processing...',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorMessage,
                                        style: const TextStyle(color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (status == MigrationStatus.completed) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Migration completed successfully. All data has been transferred to the SQLite database.',
                                        style: TextStyle(color: Colors.green, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
  
  Widget _buildActionButtons() {
    return ValueListenableBuilder<MigrationStatus>(
      valueListenable: _migrationService.migrationStatusNotifier,
      builder: (context, status, _) {
        if (status == MigrationStatus.inProgress || status == MigrationStatus.cleaning) {
          return const Center(
            child: Text('Migration in progress... Please wait.'),
          );
        }
        
        if (status == MigrationStatus.completed) {
          return Center(
            child: Column(
              children: [
                const Text('Migration completed successfully!'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // Return success
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Return to App'),
                ),
              ],
            ),
          );
        }
        
        if (status == MigrationStatus.failed) {
          return Center(
            child: Column(
              children: [
                const Text('Migration failed. Would you like to try again?'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(false); // Return failure
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _startMigration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry Migration'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        
        // Not started or initial state
        return Center(
          child: Column(
            children: [
              Text(
                _migrationStarted 
                    ? 'Ready to start migration'
                    : 'Press the button below to start the migration process',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _startMigration,
                icon: const Icon(Icons.sync),
                label: const Text('Start Migration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _startMigration() async {
    setState(() {
      _migrationStarted = true;
    });
    
    final success = await _migrationService.migrateKendalaForms();
    
    if (success) {
      // Clean up old data
      await _migrationService.cleanupSharedPreferences();
    }
  }
  
  Widget _buildStatusIcon(MigrationStatus status) {
    switch (status) {
      case MigrationStatus.notStarted:
        return Icon(Icons.hourglass_empty, color: Colors.grey[600]);
      case MigrationStatus.inProgress:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      case MigrationStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case MigrationStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
      case MigrationStatus.cleaning:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        );
    }
  }
  
  String _getStatusText(MigrationStatus status) {
    switch (status) {
      case MigrationStatus.notStarted:
        return 'Migration Not Started';
      case MigrationStatus.inProgress:
        return 'Migration In Progress';
      case MigrationStatus.completed:
        return 'Migration Completed';
      case MigrationStatus.failed:
        return 'Migration Failed';
      case MigrationStatus.cleaning:
        return 'Cleaning Up Old Data';
    }
  }
  
  Color _getStatusColor(MigrationStatus status) {
    switch (status) {
      case MigrationStatus.notStarted:
        return Colors.grey[600]!;
      case MigrationStatus.inProgress:
        return Theme.of(context).colorScheme.primary;
      case MigrationStatus.completed:
        return Colors.green;
      case MigrationStatus.failed:
        return Colors.red;
      case MigrationStatus.cleaning:
        return Colors.orange;
    }
  }
}