import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';

import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start animation
    _animationController.forward();

    // Initialize app after animation
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Add a delay to show splash screen animation
      await Future.delayed(const Duration(milliseconds: 2500));

      // Check authentication status
      if (mounted) {
        context.read<AuthBloc>().add(const AuthCheckRequested());
      }
    } catch (e) {
      // Handle initialization errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/spb');
        } else if (state is AuthUnauthenticated) {
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/icon/smart_logo.png',
                            height: 80,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Animated text
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
                      ),
                    ),
                    child: Text(
                      "SPB Secure",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.5, 0.9, curve: Curves.easeIn),
                      ),
                    ),
                    child: Text(
                      "Your Security, Our Priority",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 60),

              // Loading indicator
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
                      ),
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                        strokeWidth: 3,
                        // Add a subtle animation to the progress indicator
                        value: _loadingAnimation.value < 1.0
                            ? null
                            : _waveAnimation(_animationController.value),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Creates a wave-like animation for the progress indicator
  double _waveAnimation(double value) {
    // Remap the value from 0.7-1.0 to 0.0-1.0
    final remappedValue = (value - 0.7) / 0.3;
    // Create a sine wave effect
    return 0.5 + 0.5 * sin(remappedValue * 6.28);
  }
}