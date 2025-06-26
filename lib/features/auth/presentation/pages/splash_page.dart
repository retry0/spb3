import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/environment_config.dart';
import '../../../../core/widgets/network_error_widget.dart';
import '../bloc/auth_bloc.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Add a small delay for splash screen visibility
      await Future.delayed(const Duration(seconds: 2));

      // Check authentication status
      if (mounted) {
        context.read<AuthBloc>().add(const AuthCheckRequested());
      }
    } catch (e) {
      // Handle initialization errors
      if (mounted) {
        _showInitializationError(e.toString());
      }
    }
  }

  void _showInitializationError(String error) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (context) => NetworkErrorWidget(
              errorMessage: 'Failed to initialize app: $error',
              onRetry: () {
                Navigator.of(context).pop();
                _initializeApp();
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/spb');
        } else if (state is AuthUnauthenticated) {
          context.go('/login');
        } else if (state is AuthError) {
          // Show network error widget for auth errors
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (context) => NetworkErrorWidget(
                    errorMessage: state.message,
                    onRetry: () {
                      Navigator.of(context).pop();
                      context.read<AuthBloc>().add(const AuthCheckRequested());
                    },
                  ),
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 100, color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'e-SPB SMART',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
