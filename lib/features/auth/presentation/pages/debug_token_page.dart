import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/jwt_decoder_util.dart';
import '../../../../core/utils/jwt_token_manager.dart';
import '../../../../core/di/injection.dart';

/// Debug page for testing JWT token decoding functionality
class DebugTokenPage extends StatefulWidget {
  const DebugTokenPage({super.key});

  @override
  State<DebugTokenPage> createState() => _DebugTokenPageState();
}

class _DebugTokenPageState extends State<DebugTokenPage> {
  final _tokenController = TextEditingController();
  Map<String, dynamic>? _filteredData;
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _customClaims;
  Map<String, dynamic>? _tokenMetadata;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _decodeToken() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _filteredData = null;
      _userInfo = null;
      _customClaims = null;
      _tokenMetadata = null;
    });

    try {
      final token = _tokenController.text.trim();
      
      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a JWT token';
          _isLoading = false;
        });
        return;
      }

      // Decode and filter token
      final filteredData = JwtDecoderUtil.decodeAndFilterToken(token);
      final userInfo = JwtDecoderUtil.extractUserInfo(token);
      final customClaims = JwtDecoderUtil.extractCustomClaims(token);
      final tokenMetadata = JwtDecoderUtil.getTokenMetadata(token);

      setState(() {
        _filteredData = filteredData;
        _userInfo = userInfo;
        _customClaims = customClaims;
        _tokenMetadata = tokenMetadata;
        _isLoading = false;
      });

      if (filteredData == null) {
        setState(() {
          _errorMessage = 'Invalid JWT token or decoding failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error decoding token: $e';
        _isLoading = false;
      });
    }
  }

  void _loadStoredToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tokenManager = getIt<JwtTokenManager>();
      final userData = await tokenManager.getCurrentUserData();
      final metadata = await tokenManager.getTokenMetadata();
      final customClaims = await tokenManager.getCustomClaims();

      setState(() {
        _userInfo = userData;
        _tokenMetadata = metadata;
        _customClaims = customClaims;
        _isLoading = false;
      });

      if (userData == null) {
        setState(() {
          _errorMessage = 'No stored token found or token is invalid';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading stored token: $e';
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JWT Token Decoder'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Token Input Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JWT Token Input',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Paste JWT Token Here',
                        hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _decodeToken,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Decode Token'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _loadStoredToken,
                            child: const Text('Load Stored Token'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Error Message
            if (_errorMessage != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Token Metadata
            if (_tokenMetadata != null)
              _buildDataCard(
                'Token Metadata',
                _tokenMetadata!,
                Icons.info,
                Colors.blue,
              ),

            // User Information
            if (_userInfo != null)
              _buildDataCard(
                'User Information',
                _userInfo!,
                Icons.person,
                Colors.green,
              ),

            // Custom Claims
            if (_customClaims != null && _customClaims!.isNotEmpty)
              _buildDataCard(
                'Custom Claims',
                _customClaims!,
                Icons.extension,
                Colors.orange,
              ),

            // All Filtered Data
            if (_filteredData != null)
              _buildDataCard(
                'All Filtered Data (Excluding Sensitive Fields)',
                _filteredData!,
                Icons.data_object,
                Colors.purple,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(
    String title,
    Map<String, dynamic> data,
    IconData icon,
    Color color,
  ) {
    final prettyJson = JwtDecoderUtil.prettyPrintFilteredData(_tokenController.text);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(prettyJson),
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy to clipboard',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  _formatData(data),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatData(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    data.forEach((key, value) {
      buffer.writeln('$key: ${_formatValue(value)}');
    });
    return buffer.toString();
  }

  String _formatValue(dynamic value) {
    if (value is String) {
      return '"$value"';
    } else if (value is List) {
      return '[${value.map(_formatValue).join(', ')}]';
    } else if (value is Map) {
      return '{${value.entries.map((e) => '${e.key}: ${_formatValue(e.value)}').join(', ')}}';
    } else {
      return value.toString();
    }
  }
}