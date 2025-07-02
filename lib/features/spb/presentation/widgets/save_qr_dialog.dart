import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:typed_data';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/spb_model.dart';

/// A dialog that requests storage permission and saves QR code to gallery
class SaveQrDialog extends StatefulWidget {
  /// The QR code image data to save
  final Uint8List imageData;

  /// Optional name for the saved image
  final String? imageName;

  /// Optional quality for the saved image (1-100)
  final int quality;

  final String spb;

  const SaveQrDialog({
    super.key,
    required this.imageData,
    this.imageName,
    this.quality = 100,
    required this.spb,
  });

  /// Show the save QR dialog
  static Future<bool?> show({
    required BuildContext context,
    required Uint8List imageData,
    String? imageName,
    int quality = 100,
    required String spb,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => SaveQrDialog(
            imageData: imageData,
            imageName: imageName,
            quality: quality,
            spb: spb,
          ),
    );
  }

  @override
  State<SaveQrDialog> createState() => _SaveQrDialogState();
}

class _SaveQrDialogState extends State<SaveQrDialog> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isSuccess ? 'Simpan QR' : 'Simpan QR Code ke gallery',
        style: TextStyle(
          color:
              _isSuccess
                  ? AppTheme.successColor
                  : Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: _buildDialogContent(),
      actions: _buildDialogActions(),
    );
  }

  Widget _buildDialogContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Simpan QR code...'),
            ],
          ),
        ),
      );
    }

    if (_isSuccess) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppTheme.successColor,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'QR code berhasil tersimpan di gallery.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorColor, size: 64),
          const SizedBox(height: 16),
          Text(
            'Error: $_errorMessage',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.errorColor),
          ),
          const SizedBox(height: 16),
          const Text(
            'Would you like to try again?',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aplikasi ini memerlikan permission untuk simpan QR codes ke gallery.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.photo_library,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Simpan QR Code sebagai gambar')),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildDialogActions() {
    if (_isLoading) {
      return [];
    }

    if (_isSuccess) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('OK'),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _requestPermissionAndSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Try Again'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Tolak'),
      ),
      ElevatedButton(
        onPressed: _requestPermissionAndSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        child: const Text('Izinkan'),
      ),
    ];
  }

  Future<void> _requestPermissionAndSave() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Request storage permission
      PermissionStatus status;

      if (await Permission.photos.isGranted) {
        status = PermissionStatus.granted;
      } else {
        status = await Permission.photos.request();

        // If photos permission is not available (older Android), try storage permission
        if (status != PermissionStatus.granted) {
          status = await Permission.storage.request();
        }
      }

      if (status.isGranted) {
        // Permission granted, save image
        await _saveImageToGallery();
      } else if (status.isPermanentlyDenied) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Permission permanently denied. Please enable it in app settings.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Permission denied. Cannot save QR code.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error requesting permission: $e';
      });
    }
  }

  Future<void> _saveImageToGallery() async {
    try {
      final imageName = widget.imageName ?? 'SPB_${widget.spb}';

      final result = await ImageGallerySaverPlus.saveImage(
        widget.imageData,
        quality: widget.quality,
        name: imageName,
      );

      if (result['isSuccess']) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['errorMessage'] ?? 'Failed to save image';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error saving image: $e';
      });
    }
  }
}
