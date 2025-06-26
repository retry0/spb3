import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../pages/spb_page.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/config/api_endpoints.dart';
import '../../data/models/spb_model.dart';
import '../../../../core/theme/app_theme.dart';

class KendalaFormPage extends StatefulWidget {
  final SpbModel spb;

  const KendalaFormPage({super.key, required this.spb});

  @override
  State<KendalaFormPage> createState() => _KendalaFormPageState();
}

class _KendalaFormPageState extends State<KendalaFormPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isDriverOrVehicleChanged = false;
  bool _isGpsActive = false;
  Position? _currentPosition;

  String? _errorMessage;
  final TextEditingController _kendalaController = TextEditingController();
  final Dio _dio = getIt<Dio>();
  bool _isConnected = true;

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
    _loadSavedData();
    _checkConnectivity();
  }

  @override
  void dispose() {
    _kendalaController.dispose();
    _animationController.dispose();
    super.dispose();
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
              onPressed: () {
                // Navigator.of(context).pop();
                // Navigator.of(context).pop(); // Go back to previous screen
                // Navigate to Kendala Form page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SpbPage()),
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
                // Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SpbPage()),
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
                // Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SpbPage()),
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
        // If connection is restored, try to sync
        if (hasConnectivity && !_isConnected) {
          _syncData();
        }
      }
    });
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final spbId = widget.spb.noSpb;

      // Load checkbox state
      final isDriverOrVehicleChanged =
          prefs.getBool('kendala_driver_changed_$spbId') ?? false;

      // Load kendala text
      final kendalaText = prefs.getString('kendala_text_$spbId') ?? '';

      if (mounted) {
        setState(() {
          _isDriverOrVehicleChanged = isDriverOrVehicleChanged;
          _kendalaController.text = kendalaText;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load saved data: $e';
        });
      }
    }
  }

  Future<void> _saveData() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_isDriverOrVehicleChanged) {
      setState(() {
        _errorMessage =
            'Harap konfirmasi pergantian driver/kendaraan dengan mencentang kotak';
      });
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
      // Save to local storage first
      await _saveToLocalStorage();
      // Try to sync with server if connected
      if (_isConnected) {
        await _syncData();
      }
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kendala berhasil disimpan'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        // Navigate back after successful save
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error saving data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final spbId = widget.spb.noSpb;

    // Save checkbox state
    await prefs.setBool(
      'kendala_driver_changed_$spbId',
      _isDriverOrVehicleChanged,
    );

    // Save kendala text
    await prefs.setString('kendala_text_$spbId', _kendalaController.text);

    // Save sync status
    await prefs.setBool('kendala_synced_$spbId', false);

    // Save timestamp
    await prefs.setInt(
      'kendala_timestamp_$spbId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _syncData() async {
    try {
      // Get current position if not already available
      if (_currentPosition == null) {
        try {
          _currentPosition = await Geolocator.getCurrentPosition();
        } catch (e) {
          // Use default coordinates if location not available
          _currentPosition = null;
        }
      }

      // Use position or default to 0,0 if not available
      final lat = _currentPosition?.latitude ?? 0.0;
      final long = _currentPosition?.longitude ?? 0.0;

      final String latitude = lat.toString();
      final String longitude = long.toString();

      final prefs = await SharedPreferences.getInstance();
      final spbId = widget.spb.noSpb;
      // Check if already synced
      final isSynced = prefs.getBool('kendala_synced_$spbId') ?? false;
      if (isSynced) return;

      // Prepare data for API
      final data = {
        'noSPB': widget.spb.noSpb,
        'latitude': latitude,
        'longitude': longitude,
        'createdBy': widget.spb.driver.toString(),
        'status': "2", // Set status to indicate kendala/issue
        'alasan': _kendalaController.text,
        'isAnyHandlingEx': _isDriverOrVehicleChanged.toString(),
      };

      // Call API to update SPB status
      final response = await _dio.put(
        ApiServiceEndpoints.AdjustSPBDriver,
        data: data,
      );

      if (response.statusCode == 200) {
        // Mark as synced in local storage
        await prefs.setBool('kendala_synced_$spbId', true);
      } else {
        throw Exception('Failed to sync data: ${response.statusCode}');
      }
    } catch (e) {
      // Just log the error but don't throw - we'll try to sync again later
      print('Sync error: $e');
      // We don't set _errorMessage here as the local save was successful
    }
  }

  void _showConfirmationDialog() {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_isDriverOrVehicleChanged) {
      setState(() {
        _errorMessage =
            'Harap konfirmasi pergantian driver/kendaraan dengan mencentang kotak';
      });
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
          title: const Text('Konfirmasi Kendala'),
          content: const Text(
            'Apakah anda yakin ingin melaporkan kendala untuk SPB ini?',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _saveData();
              },
              child: const Text('Konfirmasi'),
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
        title: const Text('Form Keterangan Kendala'),
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

                    // Kendala Form Card
                    _buildKendalaFormCard(),

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
                        'Informasi SPB',
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
                _buildInfoRow(
                  label: 'Vendor',
                  value: widget.spb.kodeVendor ?? 'N/A',
                ),
                _buildInfoRow(
                  label: 'Tujuan Pengantaran',
                  value: widget.spb.millTujuanName ?? 'N/A',
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

            // Kendala details textbox
            TextFormField(
              controller: _kendalaController,
              enabled: _isDriverOrVehicleChanged,
              decoration: InputDecoration(
                labelText: 'Keterangan Kendala',
                hintText:
                    _isDriverOrVehicleChanged
                        ? 'Masukkan keterangan kendala secara detail'
                        : 'Aktifkan checkbox di atas untuk mengisi keterangan',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                filled: true,
                fillColor:
                    _isDriverOrVehicleChanged
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.5),
                prefixIcon: const Icon(Icons.description_outlined),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              maxLines: 5,
              minLines: 3,
              validator: (value) {
                if (_isDriverOrVehicleChanged &&
                    (value == null || value.isEmpty)) {
                  return 'Keterangan kendala tidak boleh kosong';
                }
                if (_isDriverOrVehicleChanged &&
                    value != null &&
                    value.length < 10) {
                  return 'Keterangan terlalu singkat (min. 10 karakter)';
                }
                return null;
              },
              onChanged: (value) {
                // Clear error message when text changes
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
              style: TextStyle(
                color:
                    _isDriverOrVehicleChanged
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),

            const SizedBox(height: 16),
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
          backgroundColor: AppTheme.errorColor,
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
                      Icons.report_problem_outlined,
                      color:
                          _isDriverOrVehicleChanged && _isGpsActive
                              ? Colors.white
                              : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Simpan Kendala',
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