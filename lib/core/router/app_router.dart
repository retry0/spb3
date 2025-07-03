import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/main/presentation/pages/main_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/spb/presentation/pages/spb_page.dart';
import '../../ui/screens/splash_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final authState = context.read<AuthBloc>().state;
      final isLoggedIn = authState is AuthAuthenticated;

      // If user is not logged in and trying to access protected routes
      if (!isLoggedIn &&
          state.matchedLocation != '/login' &&
          state.matchedLocation != '/splash' &&
          state.matchedLocation != '/location_permission') {
        return '/login';
      }

      // If user is logged in and trying to access auth routes
      if (isLoggedIn &&
          (state.matchedLocation == '/login' ||
              state.matchedLocation == '/splash')) {
        return '/spb'; // Redirect to SPB page or home page
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainPage(child: child),
        routes: [
          GoRoute(
            path: '/spb',
            name: 'spb',
            builder: (context, state) => const SpbPage(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Page Not Found',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'The page ${state.uri.path} does not exist',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/spb'),
                  child: const Text('Go SPB'),
                ),
              ],
            ),
          ),
        ),
  );
}
