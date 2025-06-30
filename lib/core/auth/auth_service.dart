import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_endpoints.dart';
import '../constants/storage_keys.dart';
import '../di/injection.dart';
import '../error/exceptions.dart';
import '../storage/secure_storage.dart';
import '../utils/logger.dart';
import 'token_manager.dart';

/// Service responsible for authentication operations
class AuthService {
  final Dio _dio;
  final TokenManager _tokenManager;
  final SecureStorage _secureStorage;
  final Connectivity _connectivity;
  
  // Authentication state
  final ValueNotifier<AuthState> authState = ValueNotifier(AuthState.unknown);
  
  // Connectivity monitoring
  StreamSubscription? _connectivitySubscription;
  bool _wasOffline = false;
  
  AuthService({
    required Dio dio,
    required TokenManager tokenManager,
    required SecureStorage secureStorage,
    required Connectivity connectivity,
  }) : _dio = dio,
       _tokenManager = tokenManager,
       _secureStorage = secureStorage,
       _connectivity = connectivity {
    // Initialize auth state
    _initAuthState();
    
    // Listen for token manager changes
    _tokenManager.isAuthenticated.addListener(_onAuthStateChanged);
    
    // Monitor connectivity for offline-to-online transitions
    _monitorConnectivity();
  }
  
  /// Initialize authentication state
  Future<void> _initAuthState() async {
    try {
      final accessToken = await _tokenManager.getAccessToken(autoRefresh: false);
      if (accessToken != null) {
        authState.value = AuthState.authenticated;
      } else {
        authState.value = AuthState.unauthenticated;
      }
    } catch (e) {
      AppLogger.error('Error initializing auth state: $e');
      authState.value = AuthState.error;
    }
  }
  
  /// Monitor connectivity changes
  void _monitorConnectivity() {
    // Check initial connectivity
    _connectivity.checkConnectivity().then((result) {
      _wasOffline = result.isEmpty || result.contains(ConnectivityResult.none);
    });
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final isOffline = result.isEmpty || result.contains(ConnectivityResult.none);
      
      // Handle offline to online transition
      if (_wasOffline && !isOffline) {
        _handleOfflineToOnlineTransition();
      }
      
      _wasOffline = isOffline;
    });
  }
  
  /// Handle transition from offline to online
  Future<void> _handleOfflineToOnlineTransition() async {
    AppLogger.info('Network connection restored, validating authentication');
    
    // Only proceed if we're authenticated
    if (authState.value != AuthState.authenticated) return;
    
    try {
      // Validate token with server
      final isValid = await _tokenManager.validateTokenOnReconnect();
      
      if (!isValid) {
        // Token is invalid or couldn't be refreshed
        AppLogger.warning('Token invalid after reconnection, requiring re-authentication');
        authState.value = AuthState.sessionExpired;
        
        // Clear tokens
        await _tokenManager.clearTokens();
      } else {
        AppLogger.info('Token successfully validated after reconnection');
        // Token is valid, we can continue the session
        authState.value = AuthState.authenticated;
      }
    } catch (e) {
      AppLogger.error('Error validating token after reconnection: $e');
      // On error, we keep the current auth state but log the issue
    }
  }
  
  /// React to changes in token manager's authentication state
  void _onAuthStateChanged() {
    if (_tokenManager.isAuthenticated.value) {
      authState.value = AuthState.authenticated;
    } else if (_tokenManager.authError.value != null) {
      authState.value = AuthState.error;
    } else {
      authState.value = AuthState.unauthenticated;
    }
  }
  
  /// Login with username and password
  Future<bool> login(String username, String password) async {
    try {
      authState.value = AuthState.authenticating;
      
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult.isNotEmpty && 
                         !connectivityResult.contains(ConnectivityResult.none);
      
      if (!isConnected) {
        // Try offline login
        return await _offlineLogin(username, password);
      }
      
      // Online login
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {
          'userName': username,
          'password': password,
        },
      );
      
      if (response.statusCode == 200 && response.data != null) {
        // Extract tokens from response
        final responseData = response.data['data'] ?? response.data;
        final accessToken = responseData['token'] ?? responseData['accessToken'];
        
        // In a real app, the server would provide a refresh token
        // For this example, we'll create one with a longer expiry
        final refreshToken = responseData['refreshToken'] ?? _createRefreshToken(accessToken);
        
        // Extract user ID from token
        final tokenData = JwtDecoder.decode(accessToken);
        final userId = tokenData['Id'] ?? tokenData['sub'];
        
        // Store tokens
        await _tokenManager.storeTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: userId,
          username: username,
        );
        
        // Store credentials for offline login
        await _storeOfflineCredentials(username, password);
        
        authState.value = AuthState.authenticated;
        return true;
      } else {
        authState.value = AuthState.unauthenticated;
        return false;
      }
    } on DioException catch (e) {
      AppLogger.error('Login error: ${e.message}');
      authState.value = AuthState.error;
      return false;
    } catch (e) {
      AppLogger.error('Login error: $e');
      authState.value = AuthState.error;
      return false;
    }
  }
  
  /// Attempt offline login with stored credentials
  Future<bool> _offlineLogin(String username, String password) async {
    try {
      AppLogger.info('Attempting offline login for user: $username');
      
      // Get stored credentials
      final storedCredentialsJson = await _secureStorage.read('offline_creds_$username');
      if (storedCredentialsJson == null) {
        authState.value = AuthState.unauthenticated;
        return false;
      }
      
      final storedCredentials = jsonDecode(storedCredentialsJson) as Map<String, dynamic>;
      final storedPassword = storedCredentials['password'] as String?;
      
      // Verify password
      if (storedPassword != password) {
        authState.value = AuthState.unauthenticated;
        return false;
      }
      
      // Get stored tokens
      final userId = storedCredentials['userId'] as String?;
      if (userId == null) {
        authState.value = AuthState.unauthenticated;
        return false;
      }
      
      // Create offline tokens
      final accessToken = _createOfflineAccessToken(username, userId);
      final refreshToken = _createOfflineRefreshToken(username, userId);
      
      // Store tokens
      await _tokenManager.storeTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        username: username,
      );
      
      authState.value = AuthState.authenticated;
      AppLogger.info('Offline login successful for user: $username');
      return true;
    } catch (e) {
      AppLogger.error('Offline login error: $e');
      authState.value = AuthState.error;
      return false;
    }
  }
  
  /// Store credentials for offline login
  Future<void> _storeOfflineCredentials(String username, String password) async {
    try {
      // Get user ID from token
      final accessToken = await _tokenManager.getAccessToken();
      if (accessToken == null) return;
      
      final tokenData = JwtDecoder.decode(accessToken);
      final userId = tokenData['Id'] ?? tokenData['sub'];
      
      // Store credentials
      final credentials = {
        'username': username,
        'password': password, // In a real app, you'd hash this
        'userId': userId,
        'storedAt': DateTime.now().toIso8601String(),
      };
      
      await _secureStorage.write(
        'offline_creds_$username',
        jsonEncode(credentials),
      );
      
      AppLogger.info('Offline credentials stored for user: $username');
    } catch (e) {
      AppLogger.error('Error storing offline credentials: $e');
    }
  }
  
  /// Logout the current user
  Future<bool> logout() async {
    try {
      authState.value = AuthState.loggingOut;
      
      // Clear tokens
      await _tokenManager.clearTokens();
      
      // In a real app, you might also call an API to invalidate the token on the server
      
      authState.value = AuthState.unauthenticated;
      return true;
    } catch (e) {
      AppLogger.error('Logout error: $e');
      authState.value = AuthState.error;
      return false;
    }
  }
  
  /// Check if the current session is valid
  Future<bool> isSessionValid() async {
    try {
      final accessToken = await _tokenManager.getAccessToken();
      return accessToken != null;
    } catch (e) {
      AppLogger.error('Error checking session validity: $e');
      return false;
    }
  }
  
  /// Force token refresh
  Future<bool> forceTokenRefresh() async {
    try {
      final newToken = await _tokenManager.refreshToken();
      return newToken != null;
    } catch (e) {
      AppLogger.error('Force token refresh error: $e');
      return false;
    }
  }
  
  /// Create a refresh token based on an access token
  String _createRefreshToken(String accessToken) {
    try {
      // Decode the access token
      final tokenData = JwtDecoder.decode(accessToken);
      
      // Create a refresh token with a longer expiry
      final now = DateTime.now();
      final refreshTokenExpiry = now.add(Duration(days: 30));
      
      final refreshTokenPayload = {
        'sub': tokenData['Id'] ?? tokenData['sub'],
        'username': tokenData['UserName'],
        'exp': refreshTokenExpiry.millisecondsSinceEpoch ~/ 1000,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'type': 'refresh',
      };
      
      // In a real app, this would be signed by your auth server
      // Here we're just base64 encoding it for simulation
      final header = base64Encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
      final payload = base64Encode(utf8.encode(jsonEncode(refreshTokenPayload)));
      final signature = base64Encode(utf8.encode('signature')); // Fake signature
      
      return '$header.$payload.$signature';
    } catch (e) {
      AppLogger.error('Error creating refresh token: $e');
      throw AuthException('Failed to create refresh token');
    }
  }
  
  /// Create an offline access token
  String _createOfflineAccessToken(String username, String userId) {
    final now = DateTime.now();
    final expiryTime = now.add(Duration(hours: 24)); // Offline tokens last longer
    
    final payload = {
      'Id': userId,
      'UserName': username,
      'Nama': username,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiryTime.millisecondsSinceEpoch ~/ 1000,
      'offline': true,
    };
    
    final header = base64Encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final encodedPayload = base64Encode(utf8.encode(jsonEncode(payload)));
    final signature = base64Encode(utf8.encode('offline_signature'));
    
    return '$header.$encodedPayload.$signature';
  }
  
  /// Create an offline refresh token
  String _createOfflineRefreshToken(String username, String userId) {
    final now = DateTime.now();
    final expiryTime = now.add(Duration(days: 90)); // Offline refresh tokens last longer
    
    final payload = {
      'sub': userId,
      'username': username,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiryTime.millisecondsSinceEpoch ~/ 1000,
      'type': 'refresh',
      'offline': true,
    };
    
    final header = base64Encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final encodedPayload = base64Encode(utf8.encode(jsonEncode(payload)));
    final signature = base64Encode(utf8.encode('offline_refresh_signature'));
    
    return '$header.$encodedPayload.$signature';
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _tokenManager.isAuthenticated.removeListener(_onAuthStateChanged);
  }
}

/// Authentication states
enum AuthState {
  unknown,
  authenticating,
  authenticated,
  unauthenticated,
  sessionExpired,
  loggingOut,
  error,
}