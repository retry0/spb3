import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'save_qr_dialog.dart';

import '../../data/models/spb_model.dart';
import '../../../../core/di/injection.dart';

class SpbQrCodeModal extends StatefulWidget {
  final SpbModel spb;
  final String driver;
  final String kdVendor;

  const SpbQrCodeModal({
    super.key,
    required this.spb,
    required this.driver,
    required this.kdVendor,
  });

  @override
  State<SpbQrCodeModal> createState() => _SpbQrCodeModalState();
}

class _SpbQrCodeModalState extends State<SpbQrCodeModal> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isSaving = false;
  bool _isOnline = true;
  String? _errorMessage;
  bool _isSynced = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _checkSyncStatus();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);
    });
  }

  Future<void> _checkSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'qr_sync_${widget.spb.noSpb}';
      final isSynced = prefs.getBool(key) ?? false;

      setState(() {
        _isSynced = isSynced;
      });

      // If online and not synced, sync with backend
      if (_isOnline && !_isSynced) {
        await _syncWithBackend();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to check sync status: $e';
      });
    }
  }

  Future<void> _syncWithBackend() async {
    try {
      // In a real app, you would make an API call here
      // For demo purposes, we'll simulate a successful sync
      await Future.delayed(const Duration(seconds: 1));

      // Save sync status to local storage
      final prefs = await SharedPreferences.getInstance();
      final key = 'qr_sync_${widget.spb.noSpb}';
      await prefs.setBool(key, true);

      setState(() {
        _isSynced = true;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sync with backend: $e';
      });
    }
  }

  Future<void> _saveQrCode() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Capture QR code as image
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to capture QR code';
        });
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to convert QR code to image';
        });
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Show permission dialog and save image
      final imageName =
          'SPB_QR_${widget.spb.noSpb}_${DateTime.now().millisecondsSinceEpoch}';
      final result = await SaveQrDialog.show(
        context: context,
        imageData: pngBytes,
        imageName: imageName,
        quality: 100,
      );

      // If dialog was dismissed without saving successfully
      if (result != true) {
        setState(() {
          _isSaving = false;
        });
      } else {
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Error saving QR code: $e';
      });
    }
    // setState(() {
    //   _isSaving = true;
    //   _errorMessage = null;
    // });

    // try {
    //   // Request storage permission
    //   PermissionStatus status;

    //   // For Android 13+ (API level 33+), we need to request specific permissions
    //   if (await Permission.photos.request().isGranted) {
    //     status = PermissionStatus.granted;
    //   } else {
    //     // For older Android versions, request storage permission
    //     status = await Permission.storage.request();
    //   }

    //   if (!status.isGranted) {
    //     setState(() {
    //       _isSaving = false;
    //       _errorMessage =
    //           'Storage permission denied. Please grant permission in app settings.';
    //     });
    //     return;
    //   }

    //   // Capture QR code as image
    //   final boundary =
    //       _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    //   if (boundary == null) {
    //     setState(() {
    //       _isSaving = false;
    //       _errorMessage = 'Failed to capture QR code';
    //     });
    //     return;
    //   }

    //   final image = await boundary.toImage(pixelRatio: 3.0);
    //   final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    //   if (byteData == null) {
    //     setState(() {
    //       _isSaving = false;
    //       _errorMessage = 'Failed to convert QR code to image';
    //     });
    //     return;
    //   }

    //   final pngBytes = byteData.buffer.asUint8List();

    //   // Save to gallery
    //   final result = await ImageGallerySaverPlus.saveImage(
    //     pngBytes,
    //     quality: 100,
    //     name:
    //         'SPB_QR_${widget.spb.noSpb}_${DateTime.now().millisecondsSinceEpoch}',
    //   );

    //   if (result['isSuccess']) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text('QR code saved to gallery'),
    //         backgroundColor: Colors.green,
    //       ),
    //     );
    //   } else {
    //     setState(() {
    //       _errorMessage = 'Failed to save QR code: ${result['errorMessage']}';
    //     });
    //   }
    // } catch (e) {
    //   setState(() {
    //     _errorMessage = 'Error saving QR code: $e';
    //   });
    // } finally {
    //   setState(() {
    //     _isSaving = false;
    //   });
    // }
  }

  String _generateQrContent() {
    // Concatenate SPB data with | as separator
    return [
      widget.spb.noSpb,
      'A',
      widget.spb.jumJjg,
      widget.spb.brondolan,
      widget.spb.totBeratTaksasi,
      widget.spb.noPolisi,
      widget.spb.driverName,
    ].join('|');
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360 || screenSize.height < 600;
    final padding = MediaQuery.of(context).padding;
    final availableHeight = screenSize.height - padding.top - padding.bottom;

    // Calculate QR code size based on screen width
    final qrSize =
        isSmallScreen
            ? screenSize.width * 0.5
            : screenSize.width < 600
            ? 200.0
            : 250.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.05,
        vertical: screenSize.height * 0.03,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenSize.width * 0.9,
          maxHeight: availableHeight * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.qr_code, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'QR Code for SPB: ${widget.spb.noSpb}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(),

                // Status indicators
                _buildStatusIndicators(),

                // QR Code
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: _generateQrContent(),
                          version: QrVersions.auto,
                          size: qrSize,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                        ),
                      ),
                    ),
                  ),
                ),

                // SPB Info
                _buildSpbInfoCard(isSmallScreen),

                // Sync status
                const SizedBox(height: 16),
                _buildSyncStatus(),

                // Action buttons
                const SizedBox(height: 16),
                _buildActionButtons(),

                // Loading indicator
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicators() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Offline indicator
        if (!_isOnline)
          Container(
            margin: const EdgeInsets.only(bottom: 16, top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are offline. QR code will be synced when online.',
                    style: TextStyle(color: Colors.orange[800], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // Error message
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSpbInfoCard(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSmallScreen) ...[
            // Compact layout for small screens
            _buildInfoRow('No. SPB', widget.spb.noSpb),
            _buildInfoRow(
              'Tanggal',
              DateFormat(
                'dd/MM/yyyy',
              ).format(DateTime.parse(widget.spb.tglAntarBuah)),
            ),
            _buildInfoRow(
              'Mill Tujuan',
              widget.spb.millTujuanName ?? widget.spb.millTujuan,
            ),
            _buildInfoRow('Status', widget.spb.status),
          ] else ...[
            // Regular layout for normal screens
            _buildInfoRow('No. SPB', widget.spb.noSpb),
            _buildInfoRow(
              'Tanggal',
              DateFormat(
                'dd/MM/yyyy',
              ).format(DateTime.parse(widget.spb.tglAntarBuah)),
            ),
            _buildInfoRow(
              'Jam',
              DateFormat(
                'HH:mm',
              ).format(DateTime.parse(widget.spb.tglAntarBuah)),
            ),
            _buildInfoRow(
              'Mill Tujuan',
              widget.spb.millTujuanName ?? widget.spb.millTujuan,
            ),
            _buildInfoRow('Status', widget.spb.status),
            _buildInfoRow('Driver', widget.driver),
            if (widget.spb.keterangan != null &&
                widget.spb.keterangan!.isNotEmpty)
              _buildInfoRow('Keterangan', widget.spb.keterangan!),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncStatus() {
    return Row(
      children: [
        Icon(
          _isSynced ? Icons.cloud_done : Icons.cloud_upload,
          size: 16,
          color: _isSynced ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 8),
        Text(
          _isSynced ? 'Synced with server' : 'Pending sync',
          style: TextStyle(
            fontSize: 12,
            color: _isSynced ? Colors.green : Colors.orange,
          ),
        ),
        const Spacer(),
        if (!_isSynced && _isOnline)
          TextButton.icon(
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Sync Now'),
            onPressed: _syncWithBackend,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.save_alt, size: 16),
          label: const Text('Save QR Code'),
          onPressed: _isSaving ? null : _saveQrCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
