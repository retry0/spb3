import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../utils/logger.dart';

/// A comprehensive handler for location permissions
class LocationPermissionHandler {
  // Singleton instance
  static final LocationPermissionHandler _instance = LocationPermissionHandler._internal();
  
  // Factory constructor
  factory LocationPermissionHandler() => _instance;
  
  // Private constructor
  LocationPermissionHandler._internal();
  
  // Stream controller for permission status changes
  final _permissionStatusController = StreamController<bool>.broadcast();
  
  // Stream of permission status changes
  Stream<bool> get permissionStatusStream => _permissionStatusController.stream;
  
  // Current permission status
  bool _isPermissionGranted = false;
  bool get isPermissionGranted => _isPermissionGranted;
  
  // Service status
  bool _isServiceEnabled = false;
  bool get isServiceEnabled => _isServiceEnabled;
  
  // Background listener subscription
  StreamSubscription? _serviceStatusSubscription;
  
  /// Initialize the location permission handler
  Future<void> initialize() async {
    try {
      // Check current permission status
      await checkPermissionStatus();
      
      // Start listening for service status changes
      _startServiceStatusListener();
      
      AppLogger.info('Location permission handler initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize location permission handler', e);
    }
  }
  
  /// Check if location permissions are granted
  Future<bool> checkPermissionStatus() async {
    try {
      // Check if location services are enabled
      _isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!_isServiceEnabled) {
        _isPermissionGranted = false;
        _permissionStatusController.add(false);
        AppLogger.warning('Location services are disabled');
        return false;
      }
      
      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      _isPermissionGranted = permission == LocationPermission.always || 
                            permission == LocationPermission.whileInUse;
      
      _permissionStatusController.add(_isPermissionGranted);
      
      AppLogger.info('Location permission status: $_isPermissionGranted');
      return _isPermissionGranted;
    } catch (e) {
      AppLogger.error('Failed to check location permission status', e);
      _isPermissionGranted = false;
      _permissionStatusController.add(false);
      return false;
    }
  }
  
  /// Request location permissions
  Future<bool> requestPermission(BuildContext context) async {
    try {
      // Check if service is enabled first
      if (!await Geolocator.isLocationServiceEnabled()) {
        // Show dialog to enable location services
        final bool shouldOpenSettings = await _showLocationServicesDisabledDialog(context);
        
        if (shouldOpenSettings) {
          await Geolocator.openLocationSettings();
          // Wait a bit for user to enable location services
          await Future.delayed(const Duration(seconds: 3));
          
          // Check again if service is enabled
          _isServiceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!_isServiceEnabled) {
            // Still disabled, can't proceed
            _isPermissionGranted = false;
            _permissionStatusController.add(false);
            return false;
          }
        } else {
          // User declined to open settings
          _isPermissionGranted = false;
          _permissionStatusController.add(false);
          return false;
        }
      }
      
      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      // If already granted, return true
      if (permission == LocationPermission.always || 
          permission == LocationPermission.whileInUse) {
        _isPermissionGranted = true;
        _permissionStatusController.add(true);
        return true;
      }
      
      // If denied previously, show rationale dialog
      if (permission == LocationPermission.denied) {
        final bool shouldRequest = await _showPermissionRationaleDialog(context);
        
        if (!shouldRequest) {
          _isPermissionGranted = false;
          _permissionStatusController.add(false);
          return false;
        }
      }
      
      // If permanently denied, direct to app settings
      if (permission == LocationPermission.deniedForever) {
        final bool openedSettings = await _showPermanentlyDeniedDialog(context);
        
        if (!openedSettings) {
          _isPermissionGranted = false;
          _permissionStatusController.add(false);
          return false;
        }
        
        // Wait for user to potentially change settings
        await Future.delayed(const Duration(seconds: 3));
        
        // Check permission again after returning from settings
        permission = await Geolocator.checkPermission();
        _isPermissionGranted = permission == LocationPermission.always || 
                              permission == LocationPermission.whileInUse;
        _permissionStatusController.add(_isPermissionGranted);
        return _isPermissionGranted;
      }
      
      // Request permission
      permission = await Geolocator.requestPermission();
      
      _isPermissionGranted = permission == LocationPermission.always || 
                            permission == LocationPermission.whileInUse;
      
      _permissionStatusController.add(_isPermissionGranted);
      
      // If still denied after request, show final warning
      if (!_isPermissionGranted) {
        await _showFinalWarningDialog(context);
      }
      
      return _isPermissionGranted;
    } catch (e) {
      AppLogger.error('Failed to request location permission', e);
      _isPermissionGranted = false;
      _permissionStatusController.add(false);
      return false;
    }
  }
  
  /// Start listening for location service status changes
  void _startServiceStatusListener() {
    _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((status) {
      final bool isEnabled = status == ServiceStatus.enabled;
      
      // Only notify if there's a change in status
      if (isEnabled != _isServiceEnabled) {
        _isServiceEnabled = isEnabled;
        
        // If service is disabled, permission is effectively revoked
        if (!_isServiceEnabled) {
          _isPermissionGranted = false;
        } else {
          // If service is enabled, check permission status
          checkPermissionStatus();
        }
        
        _permissionStatusController.add(_isPermissionGranted);
        
        AppLogger.info('Location service status changed: $_isServiceEnabled');
      }
    }, onError: (error) {
      AppLogger.error('Error in location service status stream', error);
    });
  }
  
  /// Show dialog when location services are disabled
  Future<bool> _showLocationServicesDisabledDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Location services are disabled. To use the GPS features of this app, '
            'please enable location services in your device settings.'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }
  
  /// Show permission rationale dialog
  Future<bool> _showPermissionRationaleDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'This app needs access to your location to provide GPS functionality. '
            'We only access your location when you are using the app.'
          ),
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
  
  /// Show dialog when permission is permanently denied
  Future<bool> _showPermanentlyDeniedDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Denied'),
          content: const Text(
            'Location permission is permanently denied. Please enable it in the '
            'app settings to use GPS features.'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () async {
                Navigator.of(context).pop(true);
                await openAppSettings();
              },
            ),
          ],
        );
      },
    ) ?? false;
  }
  
  /// Show final warning dialog when permission is denied
  Future<void> _showFinalWarningDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'This app cannot function without location permissions. '
            'The app will now exit.'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Exit App'),
              onPressed: () {
                Navigator.of(context).pop();
                exit(0); // Exit the app
              },
            ),
          ],
        );
      },
    );
  }
  
  /// Open app settings
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }
  
  /// Get current position with error handling
  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      if (!_isPermissionGranted || !_isServiceEnabled) {
        AppLogger.warning('Cannot get position: permission not granted or service disabled');
        return null;
      }
      
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );
    } catch (e) {
      AppLogger.error('Failed to get current position', e);
      return null;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _serviceStatusSubscription?.cancel();
    _permissionStatusController.close();
  }
}