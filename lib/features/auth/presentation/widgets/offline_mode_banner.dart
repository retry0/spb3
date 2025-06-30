import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/di/injection.dart';
import '../bloc/auth_bloc.dart';

class OfflineModeBanner extends StatefulWidget {
  final VoidCallback? onRetry;

  const OfflineModeBanner({super.key, this.onRetry});

  @override
  State<OfflineModeBanner> createState() => _OfflineModeBannerState();
}

class _OfflineModeBannerState extends State<OfflineModeBanner> {
  late AuthService _authService;
  bool _isOffline = false;
  bool _wasAuthenticated = false;
  
  @override
  void initState() {
    super.initState();
    _authService = getIt<AuthService>();
    _checkConnectivity();
  }
  
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult.isEmpty || 
                   connectivityResult.contains(ConnectivityResult.none);
    });
    
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      final wasOffline = _isOffline;
      final isOffline = result.isEmpty || result.contains(ConnectivityResult.none);
      
      if (mounted) {
        setState(() {
          _isOffline = isOffline;
        });
        
        // If we're coming back online and were previously authenticated
        if (wasOffline && !isOffline && _wasAuthenticated) {
          _handleReconnection();
        }
      }
    });
    
    // Check authentication state
    final authState = context.read<AuthBloc>().state;
    _wasAuthenticated = authState is AuthAuthenticated;
  }
  
  Future<void> _handleReconnection() async {
    // Validate token after reconnection
    final isValid = await _authService.isSessionValid();
    
    if (!isValid) {
      // Show a snackbar to inform the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Your session has expired. Please log in again.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Login',
              onPressed: () {
                // Navigate to login
                context.read<AuthBloc>().add(const AuthLogoutRequested(
                  reason: 'Session expired after reconnection',
                ));
              },
            ),
          ),
        );
      }
    } else {
      // Session is still valid, refresh token
      await _authService.forceTokenRefresh();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection restored. Your session has been refreshed.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update authentication state
    final authState = context.watch<AuthBloc>().state;
    _wasAuthenticated = authState is AuthAuthenticated;
    
    if (!_isOffline) {
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
          if (widget.onRetry != null)
            TextButton(
              onPressed: widget.onRetry,
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
  }
}