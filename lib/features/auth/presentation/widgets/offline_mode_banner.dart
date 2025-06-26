import 'package:flutter/material.dart';

import '../../../../core/auth/auth_manager.dart';
import '../../../../core/di/injection.dart';

class OfflineModeBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineModeBanner({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final authManager = getIt<AuthManager>();

    return ValueListenableBuilder<bool>(
      valueListenable: authManager.isOfflineMode,
      builder: (context, isOffline, _) {
        if (!isOffline) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.orange,
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You are offline. Some features may be limited.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Retry'),
                ),
            ],
          ),
        );
      },
    );
  }
}