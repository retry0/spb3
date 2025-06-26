import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_manager.dart';
import '../../../../core/di/injection.dart';
import '../../../auth/presentation/widgets/sync_status_widget.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ProfileSecuritySection extends StatelessWidget {
  const ProfileSecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security & Privacy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Change Password
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              subtitle: const Text('Update your account password'),
              trailing: const Icon(Icons.chevron_right),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                context.push('/change-password');
              },
            ),
            
            const Divider(),
            
            // Sync Status
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync Status'),
              subtitle: const SyncStatusWidget(compact: true),
              trailing: ValueListenableBuilder<bool>(
                valueListenable: getIt<AuthManager>().isOfflineMode,
                builder: (context, isOffline, _) {
                  if (isOffline) {
                    return const Icon(Icons.wifi_off, color: Colors.orange);
                  }
                  return IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      getIt<AuthManager>().syncAuthData();
                    },
                  );
                },
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                // Show sync details dialog
                _showSyncDetailsDialog(context);
              },
            ),
            
            const Divider(),
            
            // Session Management
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Active Session'),
              subtitle: const Text('This device only'),
              trailing: TextButton(
                onPressed: () {
                  // Show logout confirmation dialog
                  _showLogoutConfirmationDialog(context);
                },
                child: const Text('End Session'),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showSyncDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SyncStatusWidget(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ValueListenableBuilder<bool>(
              valueListenable: getIt<AuthManager>().isOfflineMode,
              builder: (context, isOffline, _) {
                if (isOffline) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wifi_off, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Offline Mode',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.orange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are currently offline. Changes will be synchronized when you reconnect to the internet.',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wifi, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Online Mode',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You are currently online. Changes are being synchronized in real-time.',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: getIt<AuthManager>().isOfflineMode,
            builder: (context, isOffline, _) {
              if (isOffline) {
                return const SizedBox.shrink();
              }
              
              return ElevatedButton(
                onPressed: () {
                  getIt<AuthManager>().syncAuthData();
                  Navigator.of(context).pop();
                },
                child: const Text('Sync Now'),
              );
            },
          ),
        ],
      ),
    );
  }
  
  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end your current session? You will be logged out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}