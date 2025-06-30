import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/token_manager.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/jwt_decoder_util.dart';

class TokenStatusIndicator extends StatefulWidget {
  final bool compact;
  final VoidCallback? onRefresh;

  const TokenStatusIndicator({
    super.key,
    this.compact = false,
    this.onRefresh,
  });

  @override
  State<TokenStatusIndicator> createState() => _TokenStatusIndicatorState();
}

class _TokenStatusIndicatorState extends State<TokenStatusIndicator> {
  final TokenManager _tokenManager = getIt<TokenManager>();
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _expiryTime;
  bool _isExpiringSoon = false;
  
  @override
  void initState() {
    super.initState();
    _checkTokenStatus();
    
    // Listen for token refresh status changes
    _tokenManager.isRefreshing.addListener(_onRefreshStatusChanged);
    _tokenManager.authError.addListener(_onAuthErrorChanged);
    
    // Set up periodic check
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        _checkTokenStatus();
      }
    });
  }
  
  @override
  void dispose() {
    _tokenManager.isRefreshing.removeListener(_onRefreshStatusChanged);
    _tokenManager.authError.removeListener(_onAuthErrorChanged);
    super.dispose();
  }
  
  void _onRefreshStatusChanged() {
    if (mounted) {
      setState(() {
        _isRefreshing = _tokenManager.isRefreshing.value;
      });
    }
  }
  
  void _onAuthErrorChanged() {
    if (mounted) {
      setState(() {
        _errorMessage = _tokenManager.authError.value;
      });
    }
  }
  
  Future<void> _checkTokenStatus() async {
    try {
      final token = await _tokenManager.getAccessToken(autoRefresh: false);
      if (token == null) {
        setState(() {
          _expiryTime = null;
          _isExpiringSoon = false;
        });
        return;
      }
      
      // Check if token is about to expire
      final expiryDate = JwtDecoderUtil.getTokenExpiration(token);
      if (expiryDate != null) {
        final now = DateTime.now();
        final timeUntilExpiry = expiryDate.difference(now);
        
        setState(() {
          _expiryTime = expiryDate;
          _isExpiringSoon = timeUntilExpiry.inMinutes < 10; // Less than 10 minutes
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }
  
  Future<void> _refreshToken() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    
    try {
      final newToken = await _tokenManager.refreshToken();
      if (newToken != null) {
        _checkTokenStatus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactIndicator();
    } else {
      return _buildFullIndicator();
    }
  }
  
  Widget _buildCompactIndicator() {
    IconData icon;
    Color color;
    String text;
    
    if (_isRefreshing) {
      icon = Icons.sync;
      color = Colors.blue;
      text = 'Refreshing...';
    } else if (_errorMessage != null) {
      icon = Icons.error_outline;
      color = Colors.red;
      text = 'Error';
    } else if (_expiryTime == null) {
      icon = Icons.help_outline;
      color = Colors.grey;
      text = 'Unknown';
    } else if (_isExpiringSoon) {
      icon = Icons.timer;
      color = Colors.orange;
      text = 'Expiring soon';
    } else {
      icon = Icons.check_circle_outline;
      color = Colors.green;
      text = 'Valid';
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _isRefreshing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
  
  Widget _buildFullIndicator() {
    IconData icon;
    Color color;
    String title;
    String message;
    
    if (_isRefreshing) {
      icon = Icons.sync;
      color = Colors.blue;
      title = 'Refreshing Token';
      message = 'Please wait while we refresh your authentication token...';
    } else if (_errorMessage != null) {
      icon = Icons.error_outline;
      color = Colors.red;
      title = 'Token Error';
      message = _errorMessage!;
    } else if (_expiryTime == null) {
      icon = Icons.help_outline;
      color = Colors.grey;
      title = 'Token Status Unknown';
      message = 'Unable to determine token status';
    } else if (_isExpiringSoon) {
      icon = Icons.timer;
      color = Colors.orange;
      title = 'Token Expiring Soon';
      message = 'Your session will expire at ${DateFormat('HH:mm').format(_expiryTime!)}';
    } else {
      icon = Icons.check_circle_outline;
      color = Colors.green;
      title = 'Token Valid';
      message = 'Your session is active until ${DateFormat('HH:mm').format(_expiryTime!)}';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          _isRefreshing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                  ),
                ),
                if (_expiryTime != null && !_isRefreshing) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Expires: ${DateFormat('dd MMM yyyy, HH:mm').format(_expiryTime!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!_isRefreshing && widget.onRefresh != null)
            TextButton.icon(
              onPressed: _refreshToken,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
              ),
            ),
        ],
      ),
    );
  }
}