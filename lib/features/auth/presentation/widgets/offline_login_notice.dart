import 'package:flutter/material.dart';

class OfflineLoginNotice extends StatelessWidget {
  const OfflineLoginNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.orange[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You are currently offline. You can still log in using previously saved credentials.',
            style: TextStyle(
              color: Colors.orange[800],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Note: Some features may be limited in offline mode. Your actions will be synchronized when you reconnect.',
            style: TextStyle(
              color: Colors.orange[800],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}