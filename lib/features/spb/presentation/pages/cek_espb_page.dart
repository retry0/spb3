import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../../core/di/injection.dart';
import '../../data/models/spb_model.dart';
import '../../../../core/config/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../pages/spb_page.dart';
import '../../data/services/kendala_form_sync_service.dart';
import '../widgets/kendala_sync_status_indicator.dart';

class CekEspbPage extends StatefulWidget {
  final SpbModel spb;

  const CekEspbPage({super.key, required this.spb});

  @override
  State<CekEspbPage> createState() => _CekEspbPageState();
}

class _CekEspbPageState extends State<CekEspbPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isGpsActive = false;
  String? _errorMessage;
  Position? _currentPosition;
  final Dio _dio = getIt<Dio>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isConnected = true;
  final Connectivity _connectivity = Connectivity();
  final KendalaFormSyncService _syncService = getIt<KendalaFormSyncService>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _checkGpsPermission();
    _checkConnectivity();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    setState(() {
      _isConnected =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);
    });

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      final hasConnectivity =
          result.isNotEmpty && !result.contains(ConnectivityResult.none);

      if (mounted) {
        setState(() {
          _isConnected = hasConnectivity;
        });
      }
    });
  }

  Future<void> _checkGpsPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      _showLocationServicesDisabledDialog();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, show dialog
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, show dialog
      _showPermissionPermanentlyDeniedDialog();
      return;
    }

    // Permissions are granted, get position
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isGpsActive = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get GPS location: $e';
        _isGpsActive = false;
      });
    }
  }

  void _showLocationServicesDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('GPS tidak aktif'),
          content: const Text(
            'GPS perlu diaktifkan untuk mengakses halaman ini, '
            'harap aktifkan gps di pengaturan perangkat Anda.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () async {
                // Navigate to Kendala Form page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SpbPage()),
                );
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Buka Pengaturan'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
                // Check again after settings
                if (mounted) {
                  _checkGpsPermission();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Izin Lokasi Diperlukan'),
          content: const Text(
            'Aplikasi ini memerlukan akses ke lokasi Anda untuk memeriksa detail SPB. '
            'Harap berikan izin lokasi untuk melanjutkan.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                // Navigate to Kendala Form page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SpbPage()),
                );
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
              onPressed: () {
                Navigator.of(context).pop();
                _checkGpsPermission();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Izin Ditolak'),
          content: const Text(
            'Izin lokasi ditolak secara permanen. Harap aktifkan di '
            'pengaturan aplikasi untuk menggunakan fitur GPS.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                // Navigate to Kendala Form page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SpbPage()),
                );
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Buka Pengaturan'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
                // Check again after settings
                if (mounted) {
                  _checkGpsPermission();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptSpb() async {
    // Validate GPS
    if (!_isGpsActive || _currentPosition == null) {
      // Try to get position one more time
      try {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
          _isGpsActive = true;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'GPS tidak aktif. Harap aktifkan GPS dan coba lagi.';
          _isGpsActive = false;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Prepare data for saving
      final data = {
        'noSPB': widget.spb.noSpb,
        'status': "1", // Set status to accepted
        'createdBy': widget.spb.driver,
        'latitude': _currentPosition?.latitude.toString() ?? "0.0",
        'longitude': _currentPosition?.longitude.toString() ?? "0.0",
        // Use string "0" for isAnyHandlingEx
        'isAnyHandlingEx': "0",
      };

      if (_isConnected) {
        // Online mode - send directly to API
        try {
          // Set timeout for API request
          final options = Options(
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          );

          // Call API to accept SPB
          final response = await _dio.put(
            ApiServiceEndpoints.AcceptSPBDriver,
            data: data,
            options: options,
          );

          if (response.statusCode == 200) {
            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('SPB berhasil diterima'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );

              // Navigate back after successful acceptance
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  Navigator.of(
                    context,
                  ).pop(true); // Return true to indicate success
                }
              });
            }
          } else {
            throw Exception('Failed to accept SPB: ${response.statusCode}');
          }
        } on DioException catch (e) {
          // Handle Dio specific errors
          String errorMessage;

          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            errorMessage = 'Koneksi timeout. Silakan coba lagi.';
            // Save to local storage as fallback
            await _saveDataToLocalStorage(data);
          } else if (e.type == DioExceptionType.connectionError) {
            errorMessage = 'Koneksi terputus. Data disimpan secara lokal.';
            // Save to local storage as fallback
            await _saveDataToLocalStorage(data);
          } else {
            errorMessage = 'Error API: ${e.message}';
            if (e.response != null) {
              errorMessage += ' (${e.response!.statusCode})';
              if (e.response!.data != null) {
                errorMessage += ': ${e.response!.data}';
              }
            }
            setState(() {
              _errorMessage = errorMessage;
              _isLoading = false;
            });
          }
        }
      } else {
        // Offline mode - save to local storage
        await _saveDataToLocalStorage(data);
      }
    } catch (e) {
      // Handle other errors
      setState(() {
        _errorMessage = 'Error menyimpan data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDataToLocalStorage(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a unique key for this SPB
      final spbKey = 'pending_spb_${widget.spb.noSpb}';

      // Add timestamp for syncing order
      data['timestamp'] = DateTime.now().millisecondsSinceEpoch;

      // Save data as JSON string
      await prefs.setString(spbKey, jsonEncode(data));

      // Keep track of pending SPBs
      final pendingSpbs = prefs.getStringList('pending_spbs') ?? [];
      if (!pendingSpbs.contains(widget.spb.noSpb)) {
        pendingSpbs.add(widget.spb.noSpb);
        await prefs.setStringList('pending_spbs', pendingSpbs);
      }

      // Show success message with offline indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'SPB disimpan secara lokal. Akan disinkronkan saat online.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate back after successful local save
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error menyimpan data lokal: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _syncPendingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingSpbs = prefs.getStringList('pending_spbs') ?? [];

      if (pendingSpbs.isEmpty) return;

      // Show syncing notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menyinkronkan data yang tertunda...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      for (final spbId in pendingSpbs) {
        final spbKey = 'pending_spb_$spbId';
        final jsonData = prefs.getString(spbKey);

        if (jsonData != null) {
          try {
            final data = jsonDecode(jsonData);

            // Call API
            final response = await _dio.put(
              ApiServiceEndpoints.AcceptSPBDriver,
              data: data,
            );

            if (response.statusCode == 200) {
              // Remove from pending list on success
              await prefs.remove(spbKey);
              pendingSpbs.remove(spbId);
            }
          } catch (e) {
            // Log error but continue with next item
            print('Error syncing SPB $spbId: $e');
          }
        }
      }

      // Update pending list
      await prefs.setStringList('pending_spbs', pendingSpbs);

      // Show completion notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pendingSpbs.isEmpty
                  ? 'Semua data berhasil disinkronkan'
                  : 'Beberapa data gagal disinkronkan dan akan dicoba lagi nanti',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error syncing pending data: $e');
    }
  }

  void _showAcceptConfirmationDialog() {
    // Validate GPS
    if (!_isGpsActive || _currentPosition == null) {
      setState(() {
        _errorMessage = 'GPS tidak aktif. Harap aktifkan GPS dan coba lagi.';
      });
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Penerimaan'),
          content: const Text(
            'Apakah Anda yakin ingin menerima SPB ini? Tindakan ini tidak dapat dibatalkan.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Terima'),
              onPressed: () {
                Navigator.of(context).pop();
                _acceptSpb();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cek E-SPB'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connectivity indicator
                if (!_isConnected)
                  _buildStatusCard(
                    icon: Icons.wifi_off,
                    title: 'Mode Offline',
                    message:
                        'Anda sedang offline. Data akan disimpan lokal dan disinkronkan saat online.',
                    color: Colors.orange,
                  ),

                // GPS indicator
                if (!_isGpsActive)
                  _buildStatusCard(
                    icon: Icons.location_off,
                    title: 'GPS tidak aktif',
                    message: 'Harap aktifkan GPS untuk melanjutkan.',
                    color: Colors.red,
                    actionLabel: 'Aktifkan',
                    onAction: _checkGpsPermission,
                  ),

                // GPS coordinates display
                if (_isGpsActive && _currentPosition != null)
                  _buildStatusCard(
                    icon: Icons.location_on,
                    title: 'GPS aktif',
                    message:
                        'Koordinat: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                    color: Colors.green,
                  ),

                // Error message
                if (_errorMessage != null)
                  _buildStatusCard(
                    icon: Icons.error_outline,
                    title: 'Error',
                    message: _errorMessage!,
                    color: Colors.red,
                  ),

                const SizedBox(height: 16),

                // SPB Details Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.description_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Detail E-SPB',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'No. SPB: ${widget.spb.noSpb}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Date and Time
                        _buildInfoGroup(
                          title: 'Informasi Waktu',
                          icon: Icons.calendar_today_rounded,
                          children: [
                            _buildInfoRow(
                              label: 'Tanggal Pengantaran',
                              value: DateFormat(
                                'dd MMMM yyyy',
                              ).format(DateTime.parse(widget.spb.tglAntarBuah)),
                            ),
                            _buildInfoRow(
                              label: 'Waktu Pengantaran',
                              value: DateFormat(
                                'HH:mm',
                              ).format(DateTime.parse(widget.spb.tglAntarBuah)),
                            ),
                          ],
                        ),

                        const Divider(height: 32),

                        // Vendor and Destination
                        _buildInfoGroup(
                          title: 'Informasi Pengiriman',
                          icon: Icons.local_shipping_rounded,
                          children: [
                            _buildInfoRow(
                              label: 'No E-SPB',
                              value: widget.spb.noSpb,
                            ),
                            _buildInfoRow(
                              label: 'Vendor',
                              value: widget.spb.kodeVendor ?? 'N/A',
                            ),
                            _buildInfoRow(
                              label: 'Tujuan Pengantaran',
                              value: widget.spb.millTujuan,
                            ),
                          ],
                        ),

                        const Divider(height: 32),

                        // Driver and Vehicle
                        _buildInfoGroup(
                          title: 'Informasi Kendaraan',
                          icon: Icons.person_outline_rounded,
                          children: [
                            _buildInfoRow(
                              label: 'Driver',
                              value: widget.spb.driver ?? 'N/A',
                            ),
                            _buildInfoRow(
                              label: 'No Polisi Truk',
                              value: widget.spb.noPolisi ?? 'N/A',
                            ),
                          ],
                        ),

                        const Divider(height: 32),

                        // Cargo Details
                        _buildInfoGroup(
                          title: 'Informasi Muatan',
                          icon: Icons.inventory_2_outlined,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoRow(
                                    label: 'Jumlah Janjang',
                                    value: '${widget.spb.jumJjg ?? 'N/A'} Kg',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoRow(
                                    label: 'Brondolan',
                                    value:
                                        '${widget.spb.brondolan ?? 'N/A'} Kg',
                                  ),
                                ),
                              ],
                            ),
                            _buildInfoRow(
                              label: 'Total Berat Taksasi',
                              value:
                                  '${widget.spb.totBeratTaksasi ?? 'N/A'} Kg',
                              valueStyle: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Sync status indicator
                KendalaSyncStatusIndicator(
                  spbNumber: widget.spb.noSpb,
                  onRetry: () => _syncService.syncForm(widget.spb.noSpb),
                ),

                const SizedBox(height: 24),

                // Accept Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading || !_isGpsActive
                            ? null
                            : _showAcceptConfirmationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  color:
                                      _isGpsActive
                                          ? Colors.white
                                          : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Terima SPB',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(actionLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoGroup({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: valueStyle ?? Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
