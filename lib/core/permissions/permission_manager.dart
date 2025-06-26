import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../utils/logger.dart';
import 'location_permission_handler.dart';

/// A centralized manager for all app permissions
class PermissionManager {
  // Singleton instance
  static final PermissionManager _instance = PermissionManager._internal();
  
  // Factory constructor
  factory PermissionManager() => _instance;
  
  // Private constructor
  PermissionManager._internal();
  
  // Location permission handler
  final LocationPermissionHandler _locationPermissionHandler = LocationPermissionHandler();
  
  // Getter for location permission handler
  LocationPermissionHandler get locationPermissionHandler => _locationPermissionHandler;
  
  /// Initialize all permission handlers
  Future<void> initialize() async {
    try {
      await _locationPermissionHandler.initialize();
      AppLogger.info('Permission manager initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize permission manager', e);
    }
  }
  
  /// Check if a specific permission is granted
  Future<bool> isPermissionGranted(ph.Permission permission) async {
    try {
      final status = await permission.status;
      return status.isGranted;
    } catch (e) {
      AppLogger.error('Failed to check permission status', e);
      return false;
    }
  }
  
  /// Request a specific permission
  Future<bool> requestPermission(ph.Permission permission) async {
    try {
      final status = await permission.request();
      return status.isGranted;
    } catch (e) {
      AppLogger.error('Failed to request permission', e);
      return false;
    }
  }
  
  /// Show permission rationale dialog
  Future<bool> showPermissionRationaleDialog(
    BuildContext context, 
    String title, 
    String message,
  ) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Deny'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Allow'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }
  
  /// Open app settings
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }
  
  /// Dispose resources
  void dispose() {
    _locationPermissionHandler.dispose();
  }
}