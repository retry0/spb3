import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';

enum ConnectivityStatus { connected, disconnected }

class ConnectivityService {
  final Connectivity _connectivity;

  // Stream controller for connectivity status
  final _connectivityController =
      StreamController<ConnectivityStatus>.broadcast();

  // Current connectivity status
  ConnectivityStatus _currentStatus = ConnectivityStatus.disconnected;

  // Stream subscription
  StreamSubscription? _connectivitySubscription;

  ConnectivityService(this._connectivity) {
    // Initialize
    _initConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  // Initialize connectivity
  Future<void> _initConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResult);
    } catch (e) {
      AppLogger.error('Failed to get connectivity: $e');
      _currentStatus = ConnectivityStatus.disconnected;
      _connectivityController.add(_currentStatus);
    }
  }

  // Update connection status based on connectivity result
  void _updateConnectionStatus(List<ConnectivityResult> connectivityResult) {
    final hasConnectivity =
        connectivityResult.isNotEmpty &&
        !connectivityResult.contains(ConnectivityResult.none);

    final newStatus =
        hasConnectivity
            ? ConnectivityStatus.connected
            : ConnectivityStatus.disconnected;

    // Only notify if status changed
    if (newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _connectivityController.add(_currentStatus);

      AppLogger.info('Connectivity status changed: $_currentStatus');
    }
  }

  // Get current connectivity status
  ConnectivityStatus get status => _currentStatus;

  // Get connectivity status stream
  Stream<ConnectivityStatus> get onConnectivityChanged =>
      _connectivityController.stream;

  // Check if currently connected
  bool get isConnected => _currentStatus == ConnectivityStatus.connected;

  // Check current connectivity
  Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      AppLogger.error('Failed to check connectivity: $e');
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}
