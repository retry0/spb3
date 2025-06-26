import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../data/models/spb_model.dart';
import '../../../../core/config/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../pages/spb_page.dart';
import '../bloc/espb_form_bloc.dart';
import '../bloc/espb_form_event.dart';
import '../bloc/espb_form_state.dart';
import '../../data/models/espb_form_data.dart';
import '../widgets/espb_form_sync_indicator.dart';

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
  
  // For form submission tracking
  String? _submittedFormId;
  bool _isSubmitted = false;

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
  }

  @override
  void dispose() {
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

      // Save form data using BLoC
      context.read<EspbFormBloc>().add(
        SaveAcceptanceFormRequested(
          noSpb: widget.spb.noSpb,
          latitude: latitude,
          longitude: longitude,
          createdBy: widget.spb.driver ?? '',
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error accepting SPB: $e';
      });
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
    return BlocProvider(
      create: (context) => getIt<EspbFormBloc>(),
      child: BlocListener<EspbFormBloc, EspbFormState>(
        listener: (context, state) {
          if (state is EspbFormSaving) {
            setState(() {
              _isLoading = true;
            });
          } else if (state is EspbFormSaved) {
            setState(() {
              _submittedFormId = state.formData.id;
              _isSubmitted = true;
            });
          } else if (state is EspbFormSynced) {
            // Show success message
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
                Navigator.of(context).pop(true); // Return true to indicate success
              }
            });
          } else if (state is EspbFormSyncFailed) {
            // Show warning but don't navigate back
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('SPB diterima tetapi belum tersinkronisasi: ${state.message}'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    if (_submittedFormId != null) {
                      context.read<EspbFormBloc>().add(
                        SyncFormRequested(formId: _submittedFormId!),
                      );
                    }
                  },
                ),
              ),
            );
            
            setState(() {
              _isLoading = false;
            });
          } else if (state is EspbFormError) {
            setState(() {
              _isLoading = false;
              _errorMessage = state.message;
            });
          }
        },
        child: Scaffold(
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
                    
                    // Form submission status
                    if (_isSubmitted && _submittedFormId != null)
                      BlocBuilder<EspbFormBloc, EspbFormState>(
                        builder: (context, state) {
                          if (state is EspbFormSaved || 
                              state is EspbFormSyncLoading ||
                              state is EspbFormSynced ||
                              state is EspbFormSyncFailed) {
                            EspbFormData? formData;
                            
                            if (state is EspbFormSaved) {
                              formData = state.formData;
                            } else if (state is EspbFormSyncLoading) {
                              formData = state.formData;
                            } else if (state is EspbFormSynced) {
                              formData = state.formData;
                            } else if (state is EspbFormSyncFailed) {
                              formData = state.formData;
                            }
                            
                            if (formData != null) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: EspbFormSyncIndicator(formData: formData),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
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

                    // Accept Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading || !_isGpsActive || _isSubmitted
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
                                          _isGpsActive && !_isSubmitted
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