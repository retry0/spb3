import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../error/failures.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../storage/database_helper.dart';
import '../utils/logger.dart';

/// Utility class to handle common authentication errors
class AuthErrorHandler {
  /// Handles authentication errors and provides appropriate actions
  static void handleAuthError(BuildContext context, String errorMessage) {
    AppLogger.error('Authentication error: $errorMessage');
    
    // Check if it's a "User not found" error
    if (errorMessage.contains('User not found in local database')) {
      _handleUserNotFoundError(context);
    } else {
      // Show a generic error message for other auth errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication error: $errorMessage'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              // Trigger a new auth check
              context.read<AuthBloc>().add(const AuthCheckRequested());
            },
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  /// Handles the specific case where user is not found in local database
  static void _handleUserNotFoundError(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Authentication Error'),
          content: const Text(
            'User data not found in local database. This may happen if the app data was cleared or if this is your first time using the app.\n\nPlease log in again to recreate your user profile.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Clear any existing auth state
                context.read<AuthBloc>().add(const AuthLogoutRequested(
                  reason: 'User not found in database',
                ));
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Attempts to recover from database errors by resetting the database
  static Future<bool> attemptDatabaseRecovery() async {
    try {
      AppLogger.warning('Attempting to recover from database error');
      
      // Get database helper instance
      final dbHelper = DatabaseHelper.instance;
      
      // Clear all data as a last resort
      await dbHelper.clearAllData();
      
      AppLogger.info('Database recovery completed');
      return true;
    } catch (e) {
      AppLogger.error('Database recovery failed: $e');
      return false;
    }
  }
}