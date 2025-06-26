import 'package:flutter/material.dart';

import '../config/environment_config.dart';
// import '../config/network_troubleshooter.dart';
import '../network/models/api_error_response.dart';
import '../utils/logger.dart';

/// Widget to display network error information and troubleshooting options
class NetworkErrorWidget extends StatefulWidget {
  final String? errorMessage;
  final ApiErrorResponse? apiErrorResponse;
  final VoidCallback? onRetry;

  const NetworkErrorWidget({
    super.key,
    this.errorMessage,
    this.apiErrorResponse,
    this.onRetry,
  });

  @override
  State<NetworkErrorWidget> createState() => _NetworkErrorWidgetState();
}

class _NetworkErrorWidgetState extends State<NetworkErrorWidget> {
  //bool _isRunningDiagnostics = false;
  //NetworkDiagnostics? _diagnostics;
  bool _showDetailedReport = false;

  @override
  Widget build(BuildContext context) {
    // Use API error response data if available, otherwise fallback to basic error message
    final displayMessage =
        widget.apiErrorResponse?.message ??
        widget.errorMessage ??
        'No internet connection. Please check your network settings.';

    final hasApiError = widget.apiErrorResponse != null;

    return Scaffold(
      backgroundColor: Colors.red[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getErrorIcon(), size: 64, color: Colors.red[700]),
              const SizedBox(height: 24),
              Text(
                _getErrorTitle(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),

              // API Error Details (if available)
              if (hasApiError) _buildApiErrorDetails(),

              // Quick info about current configuration
              if (!hasApiError) _buildConfigurationInfo(),

              const SizedBox(height: 24),

              // Action buttons
              _buildActionButtons(),

              const SizedBox(height: 24),

              // Diagnostics results
              //if (_diagnostics != null) _buildDiagnosticsResults(),

              // Quick tips
              if (!hasApiError) _buildQuickTips(),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    if (widget.apiErrorResponse != null) {
      switch (widget.apiErrorResponse!.statusCode) {
        case 401:
        case 403:
          return Icons.lock;
        case 404:
          return Icons.search_off;
        case 429:
          return Icons.timer;
        case 500:
        case 502:
        case 503:
        case 504:
          return Icons.dns;
        default:
          return Icons.error;
      }
    }
    return Icons.wifi_off;
  }

  String _getErrorTitle() {
    if (widget.apiErrorResponse != null) {
      switch (widget.apiErrorResponse!.statusCode) {
        case 401:
          return 'Authentication Required';
        case 403:
          return 'Access Denied';
        case 404:
          return 'Not Found';
        case 429:
          return 'Too Many Requests';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Server Error';
        default:
          return 'API Error';
      }
    }
    return 'Network Error';
  }

  Widget _buildApiErrorDetails() {
    final apiError = widget.apiErrorResponse!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Error Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (apiError.details != null && apiError.details!.isNotEmpty) ...[
              Text(
                'Details:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(apiError.details!),
              const SizedBox(height: 12),
            ],

            if (apiError.suggestedActions != null &&
                apiError.suggestedActions!.isNotEmpty) ...[
              Text(
                'Suggested Actions:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...apiError.suggestedActions!.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(child: Text(action)),
                    ],
                  ),
                ),
              ),
            ],

            if (apiError.fieldErrors != null &&
                apiError.fieldErrors!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Field Errors:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...apiError.fieldErrors!.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      ...entry.value.map(
                        (error) => Padding(
                          padding: const EdgeInsets.only(left: 16, top: 2),
                          child: Text(
                            '• $error',
                            style: TextStyle(color: Colors.red[600]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (apiError.requestId != null &&
                apiError.requestId!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fingerprint, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Request ID: ${apiError.requestId}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Environment', EnvironmentConfig.environmentName),
            _buildInfoRow('Base URL', EnvironmentConfig.baseUrl),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final canRetry = widget.apiErrorResponse?.retryable ?? true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: canRetry ? widget.onRetry : null,
          icon: const Icon(Icons.refresh),
          label: Text(canRetry ? 'Retry' : 'Cannot Retry'),
        ),
        // ElevatedButton.icon(
        //   onPressed: _isRunningDiagnostics ? null : _runDiagnostics,
        //   icon:
        //       _isRunningDiagnostics
        //           ? const SizedBox(
        //             width: 16,
        //             height: 16,
        //             child: CircularProgressIndicator(strokeWidth: 2),
        //           )
        //           : const Icon(Icons.bug_report),
        //   label: const Text('Diagnose'),
        // ),
      ],
    );
  }

  Widget _buildDiagnosticsResults() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diagnostics Results',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showDetailedReport = !_showDetailedReport;
                    });
                  },
                  child: Text(
                    _showDetailedReport ? 'Hide Details' : 'Show Details',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick status indicators
            // _buildStatusIndicator(
            //   'Network Connection',
            //   _diagnostics!.connectivity.isConnected,
            //   _diagnostics!.connectivity.details,
            // ),
            // _buildStatusIndicator(
            //   'Internet Access',
            //   _diagnostics!.internetAccess.hasAccess,
            //   _diagnostics!.internetAccess.details,
            // ),
            // _buildStatusIndicator(
            //   'Backend Server',
            //   _diagnostics!.backendAccess.isAccessible,
            //   _diagnostics!.backendAccess.details,
            // ),

            // Detailed report
            if (_showDetailedReport) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                // child: Text(
                //   NetworkTroubleshooter.generateTroubleshootingReport(
                //     _diagnostics!,
                //   ),
                //   style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                // ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isOk, String details) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            color: isOk ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  details,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Tips',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildTip('Check your WiFi or mobile data connection'),
            _buildTip('Ensure your backend server is running and accessible'),
            _buildTip('Verify the API endpoint URL is correct'),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(tip, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // Future<void> _runDiagnostics() async {
  //   setState(() {
  //     _isRunningDiagnostics = true;
  //   });

  //   try {
  //     final diagnostics = await NetworkTroubleshooter.diagnoseNetwork();
  //     setState(() {
  //       _diagnostics = diagnostics;
  //     });

  //     // Log the report for debugging
  //     final report = NetworkTroubleshooter.generateTroubleshootingReport(
  //       diagnostics,
  //     );
  //     AppLogger.info('Network Diagnostics Report:\n$report');
  //   } catch (e) {
  //     AppLogger.error('Failed to run network diagnostics: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Failed to run diagnostics: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   } finally {
  //     setState(() {
  //       _isRunningDiagnostics = false;
  //     });
  //   }
  // }
}