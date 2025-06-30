import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../pages/spb_page.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/config/api_endpoints.dart';
import '../../../../core/storage/database_helper.dart';
import '../../data/models/spb_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/services/cek_spb_form_sync_service.dart';
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
  bool _isDriverOrVehicleChanged = false;
  bool _isGpsActive = false;
  Position? _currentPosition;

  String? _errorMessage;
  final Dio _dio = getIt<Dio>();
  bool _isConnected = true;
  final CekFormSyncService _syncService = getIt<CekFormSyncService>();
  final DatabaseHelper _dbHelper = getIt<DatabaseHelper>();

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
    _checkGpsPermission();
    _checkConnectivity();

    // Check for any pending forms to sync
    _syncPendingForms();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Automatically sync all pending forms from SharedPreferences to SQLite and REST API
  Future<void> _syncPendingForms() async {
    try {
      // Check if we have connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnectivity =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      if (!hasConnectivity) {
        // We're offline, can't sync now
        return;
      }

      // Get all pending forms from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final pendingForms = prefs.getStringList('pending_cek_forms') ?? [];

      if (pendingForms.isEmpty) {
        return; // No pending forms to sync
      }

      // Process each pending form
      for (final spbId in pendingForms) {
        await _syncFormToDatabase(spbId);
      }
    } catch (e) {
      print('Error syncing pending forms: $e');
    }
  }

  /// Sync a specific form from SharedPreferences to SQLite database and REST API
  Future<bool> _syncFormToDatabase(String spbId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final formDataJson = prefs.getString('cek_form_data_$spbId');

      if (formDataJson == null) {
        return false; // No form data found
      }

      // Parse the form data
      final data = jsonDecode(formDataJson) as Map<String, dynamic>;

      // Ensure status is properly formatted as string "1" or "0"
      if (data.containsKey('status')) {
        if (data['status'] is bool) {
          data['status'] = (data['status'] as bool) ? "1" : "0";
        } else if (data['status'] is int) {
          data['status'] = (data['status'] as int) > 0 ? "1" : "0";
        } else if (data['status'] is String) {
          final value = data['status'] as String;
          if (value != "0" && value != "1") {
            data['status'] =
                value == "true" ||
                        value == "yes" ||
                        value == "True" ||
                        int.tryParse(value) == 1
                    ? "1"
                    : "0";
          }
        }
      }

      // Validate required fields
      _validateFormData(data);

      // First, save to SQLite database
      await _saveToDatabase(spbId, data);

      // Then try to sync with REST API
      final syncSuccess = await _syncWithApi(data);

      if (syncSuccess) {
        // Update sync status in both SharedPreferences and SQLite
        await prefs.setBool('cek_synced_$spbId', true);
        await _dbHelper.update(
          'accept_form_data',
          {'is_synced': 1},
          where: 'no_spb = ?',
          whereArgs: [spbId],
        );

        // Remove from pending forms list
        final pendingForms = prefs.getStringList('pending_cek_forms') ?? [];
        pendingForms.remove(spbId);
        await prefs.setStringList('pending_cek_forms', pendingForms);

        return true;
      }

      return false;
    } catch (e) {
      print('Error syncing form $spbId to database: $e');
      return false;
    }
  }

  /// Save form data to SQLite database
  Future<void> _saveToDatabase(String spbId, Map<String, dynamic> data) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Check if record already exists
      final existingRecords = await _dbHelper.query(
        'accept_form_data',
        where: 'no_spb = ?',
        whereArgs: [spbId],
        limit: 1,
      );

      if (existingRecords.isEmpty) {
        // Insert new record
        await _dbHelper.insert('accept_form_data', {
          'no_spb': spbId,
          'status': data['status'] ?? '1', // Default to accepted status
          'created_by': data['createdBy'] ?? '',
          'latitude': data['latitude'] ?? '0.0',
          'longitude': data['longitude'] ?? '0.0',
          'timestamp': data['timestamp'] ?? now,
          'is_synced': 0, // Not synced yet
          'retry_count': 0,
          'last_error': null,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        // Update existing record
        await _dbHelper.update(
          'accept_form_data',
          {
            'status': data['status'] ?? '1',
            'created_by': data['createdBy'] ?? '',
            'latitude': data['latitude'] ?? '0.0',
            'longitude': data['longitude'] ?? '0.0',
            'timestamp': data['timestamp'] ?? now,
            'updated_at': now,
          },
          where: 'no_spb = ?',
          whereArgs: [spbId],
        );
      }
    } catch (e) {
      print('Error saving form to database: $e');
      throw Exception('Failed to save form to database: $e');
    }
  }

  /// Sync form data with REST API
  Future<bool> _syncWithApi(
    Map<String, dynamic> data, {
    int retryCount = 0,
  }) async {
    try {
      // Set timeout for API request
      final options = Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );

      // Make API request
      final response = await _dio.put(
        ApiServiceEndpoints.AcceptSPBDriver,
        data: data,
        options: options,
      );

      if (response.statusCode == 200) {
        return true;
      }

      print('Failed to sync form with API: ${response.statusCode}');
      return false;
    } on DioException catch (e) {
      print(
        'DioException syncing form (attempt ${retryCount + 1}): ${e.message}',
      );

      // Retry for certain error types
      if (retryCount < 3 &&
          (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError)) {
        // Exponential backoff
        final backoffDuration = Duration(seconds: 2 * (retryCount + 1));
        await Future.delayed(backoffDuration);
        return _syncWithApi(data, retryCount: retryCount + 1);
      }

      return false;
    } catch (e) {
      print('Error syncing form with API: $e');

      // Retry for general errors
      if (retryCount < 3) {
        // Exponential backoff
        final backoffDuration = Duration(seconds: 2 * (retryCount + 1));
        await Future.delayed(backoffDuration);
        return _syncWithApi(data, retryCount: retryCount + 1);
      }

      return false;
    }
  }

  /// Validate form data before sending to API
  void _validateFormData(Map<String, dynamic> data) {
    final requiredFields = ['noSPB', 'createdBy', 'latitude', 'longitude'];

    for (final field in requiredFields) {
      if (!data.containsKey(field) ||
          data[field] == null ||
          data[field].toString().isEmpty) {
        throw Exception('Missing required field: $field');
      }
    }
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

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected =
          connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);
    });

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      final hasConnectivity =
          result.isNotEmpty && !result.contains(ConnectivityResult.none);

      if (mounted) {
        setState(() {
          _isConnected = hasConnectivity;
        });

        // If connection is restored, try to sync pending forms
        if (hasConnectivity && !_isConnected) {
          _syncPendingForms();
        }
      }
    });
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
              child: const Text('Coba Lagi'),
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

  Future<void> _saveData() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
        'noSPB': widget.spb.noSpb.toString(),
        'status': "1", // Set status to accepted
        'createdBy': widget.spb.driver.toString(),
        'latitude': _currentPosition?.latitude.toString() ?? "0.0",
        'longitude': _currentPosition?.longitude.toString() ?? "0.0",
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

      // Save to sync service
      final saveResult = await _syncService.saveForm(
        spbId: widget.spb.noSpb,
        formData: data,
      );

      if (!saveResult) {
        setState(() {
          _errorMessage = 'Failed to save form data locally';
          _isLoading = false;
        });
        return;
      }

      // Also save to SQLite database directly
      await _saveToDatabase(widget.spb.noSpb, data);

      if (_isConnected) {
        // Try to sync immediately if online
        final syncResult = await _syncService.syncForm(widget.spb.noSpb);

        if (syncResult) {
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('SPB berhasil diterima dan disinkronkan'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        } else {
          // Show partial success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'SPB diterima tetapi gagal disinkronkan. Akan dicoba lagi nanti.',
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        }
      } else {
        // Show offline message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'SPB diterima secara lokal. Akan disinkronkan saat online.',
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
        }
      }

      // Navigate back after successful save
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving data: $e';
        _isLoading = false;
      });
    }
  }

  void _showConfirmationDialog() {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
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
                _saveData();
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
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status indicators
                    _buildStatusIndicators(),

                    const SizedBox(height: 16),

                    // SPB Info Card
                    _buildSpbInfoCard(),

                    const SizedBox(height: 24),

                    // Sync status indicator
                    KendalaSyncStatusIndicator(
                      spbNumber: widget.spb.noSpb,
                      onRetry: () => _syncService.syncForm(widget.spb.noSpb),
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicators() {
    return Column(
      children: [
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

        // Offline indicator
        if (!_isConnected)
          _buildStatusCard(
            icon: Icons.wifi_off,
            title: 'Mode Offline',
            message:
                'Anda sedang offline. Data akan disimpan lokal dan disinkronkan saat online.',
            color: Colors.orange,
          ),

        // Error message
        if (_errorMessage != null)
          _buildStatusCard(
            icon: Icons.error_outline,
            title: 'Error',
            message: _errorMessage!,
            color: Colors.red,
          ),
      ],
    );
  }

  Widget _buildSpbInfoCard() {
    // SPB Details Card
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'No. SPB: ${widget.spb.noSpb}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                _buildInfoRow(label: 'No E-SPB', value: widget.spb.noSpb),
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
                        value: '${widget.spb.jumJjg.toString()} Kg',
                      ),
                    ),
                    Expanded(
                      child: _buildInfoRow(
                        label: 'Brondolan',
                        value: '${widget.spb.brondolan.toString()} Kg',
                      ),
                    ),
                  ],
                ),
                _buildInfoRow(
                  label: 'Total Berat Taksasi',
                  value: '${widget.spb.totBeratTaksasi.toString()} Kg',
                  valueStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKendalaFormCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.report_problem_outlined,
                    color: AppTheme.errorColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Keterangan Kendala',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Checkbox for driver/vehicle change
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _isDriverOrVehicleChanged
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.5),
                ),
              ),
              child: CheckboxListTile(
                title: const Text('Ada pergantian driver atau kendaraan'),
                subtitle: const Text(
                  'Centang jika terjadi pergantian driver atau kendaraan',
                ),
                value: _isDriverOrVehicleChanged,
                onChanged: (value) {
                  setState(() {
                    _isDriverOrVehicleChanged = value ?? false;
                    // Clear error message when checkbox changes
                    _errorMessage = null;
                  });
                },
                activeColor: Theme.of(context).colorScheme.primary,
                checkColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Disclaimer text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Laporan kendala akan diteruskan ke admin untuk ditindaklanjuti',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _showConfirmationDialog,
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
                      color: _isGpsActive ? Colors.white : Colors.grey.shade400,
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
