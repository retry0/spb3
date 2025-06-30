import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import '../../../../core/utils/session_manager.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/auth/auth_service.dart';
import '../bloc/auth_bloc.dart';

class SessionTimeoutDialog extends StatefulWidget {
  final int remainingMinutes;
  final VoidCallback onContinue;
  final VoidCallback onLogout;

  const SessionTimeoutDialog({
    super.key,
    this.remainingMinutes = 5,
    required this.onContinue,
    required this.onLogout,
  });

  @override
  State<SessionTimeoutDialog> createState() => _SessionTimeoutDialogState();
}

class _SessionTimeoutDialogState extends State<SessionTimeoutDialog> {
  late int _remainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.remainingMinutes * 60;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _countdownTimer?.cancel();
          widget.onLogout();
        }
      });
    });
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sesi Akan Berakhir'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            'Sesi Anda akan berakhir dalam $_formattedTime karena tidak ada aktivitas.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          const Text('Apakah Anda ingin melanjutkan sesi?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _countdownTimer?.cancel();
            widget.onLogout();
          },
          child: const Text('Keluar'),
        ),
        ElevatedButton(
          onPressed: () {
            _countdownTimer?.cancel();
            widget.onContinue();
          },
          child: const Text('Lanjutkan Sesi'),
        ),
      ],
    );
  }
}

class SessionTimeoutManager extends StatefulWidget {
  final Widget child;

  const SessionTimeoutManager({super.key, required this.child});

  @override
  State<SessionTimeoutManager> createState() => _SessionTimeoutManagerState();
}

class _SessionTimeoutManagerState extends State<SessionTimeoutManager> {
  StreamSubscription? _sessionStateSubscription;
  bool _isDialogShowing = false;
  
  // Auth service for handling session state
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = getIt<AuthService>();
    _listenForSessionChanges();
  }

  @override
  void dispose() {
    _sessionStateSubscription?.cancel();
    super.dispose();
  }

  void _listenForSessionChanges() {
    final sessionManager = getIt<SessionManager>();

    _sessionStateSubscription = Stream.periodic(
      const Duration(seconds: 10),
      (_) => sessionManager.sessionState.value,
    ).distinct().listen((state) {
      if (state == SessionState.expiring && !_isDialogShowing) {
        _showTimeoutWarning();
      }
    });
  }

  void _showTimeoutWarning() {
    setState(() {
      _isDialogShowing = true;
    });

    final sessionManager = getIt<SessionManager>();
    final timeUntilExpiry = sessionManager.getTimeUntilExpiry();

    if (timeUntilExpiry == null || timeUntilExpiry.inMinutes <= 0) {
      // Session already expired
      _handleSessionTimeout();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => SessionTimeoutDialog(
            remainingMinutes: timeUntilExpiry.inMinutes,
            onContinue: () {
              Navigator.of(context).pop();
              _handleSessionContinue();
            },
            onLogout: () {
              Navigator.of(context).pop();
              _handleSessionTimeout();
            },
          ),
    ).then((_) {
      setState(() {
        _isDialogShowing = false;
      });
    });
  }

  void _handleSessionContinue() {
    final sessionManager = getIt<SessionManager>();
    sessionManager.updateLastActivity();
    
    // Also refresh the token
    _authService.forceTokenRefresh();
  }

  void _handleSessionTimeout() {
    context.read<AuthBloc>().add(
      const AuthLogoutRequested(reason: 'Session timeout'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleUserActivity,
      onPanDown: (_) => _handleUserActivity(),
      onScaleStart: (_) => _handleUserActivity(),
      child: widget.child,
    );
  }

  void _handleUserActivity() {
    // Only update activity if user is authenticated
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final sessionManager = getIt<SessionManager>();
      sessionManager.updateLastActivity();
    }
  }
}