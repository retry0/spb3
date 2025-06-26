import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../data/models/spb_model.dart';
import '../../../../core/config/api_endpoints.dart';

class KendalaspbPage extends StatefulWidget {
  final SpbModel spb;

  const KendalaspbPage({super.key, required this.spb});

  @override
  State<KendalaspbPage> createState() => _KendalaspbPageState();
}

class _KendalaspbPageState extends State<KendalaspbPage> {
  bool _isLoading = false;
  bool _isGpsActive = false;
  bool first = false;
  bool _isChecked = false;

  String? _errorMessage;
  Position? _currentPosition;
  final Dio _dio = getIt<Dio>();

  @override
  void initState() {
    super.initState();
    _checkGpsPermission();
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
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Location services are disabled. To use the GPS features of this app, '
            'please enable location services in your device settings.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
            ),
            TextButton(
              child: const Text('Open Settings'),
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
          title: const Text('Location Permission Required'),
          content: const Text(
            'This app needs access to your location to check SPB details. '
            'Please grant location permission to continue.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
            ),
            TextButton(
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
          title: const Text('Permission Denied'),
          content: const Text(
            'Location permission is permanently denied. Please enable it in the '
            'app settings to use GPS features.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
            ),
            TextButton(
              child: const Text('Open Settings'),
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

      // Call API to accept SPB
      final response = await _dio.put(
        ApiServiceEndpoints.AdjustSPBDriver,
        data: {
          'noSPB': widget.spb.noSpb,
          'status': "2", // Set status to accepted
          'createdBy': widget.spb.driver,
          'latitude': latitude,
          'longitude': longitude,
          'alasan': "",
          'isAnyHandlingEx': _isChecked,
          // 'latitude': "37.421998333333335",
          // 'longitude': "-122.08400000000002",
        },
      );

      if (response.statusCode == 200) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SPB accepted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back after successful acceptance
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to accept SPB: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error accepting SPB: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAcceptConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Acceptance'),
          content: const Text(
            'Are you sure you want to accept this SPB? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Accept'),
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
    // Format date (extract only the date part)
    final dateStr = widget.spb.tglAntarBuah.split(' ')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Keterangan Kendala'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GPS indicator
            if (!_isGpsActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GPS location not available. Location will be recorded as 0,0.',
                        style: TextStyle(color: Colors.red[800], fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _checkGpsPermission,
                      child: const Text('Enable'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 30),
                      ),
                    ),
                  ],
                ),
              ),

            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[800], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Form fields
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'E-SPB Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // // Tanggal Pengantaran Buah
                    // _buildFormField(
                    //   context,
                    //   label: 'Tanggal Pengantaran Buah',
                    //   value: dateStr,
                    //   icon: Icons.calendar_today,
                    //   readOnly: true,
                    // ),
                    // const SizedBox(height: 16),

                    // Jumlah Janjang and Brondolan (side by side)
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormField(
                            context,
                            label: 'Tanggal Pengantaran Buah',
                            value: DateFormat(
                              'dd/MM/yyyy',
                            ).format(DateTime.parse(widget.spb.tglAntarBuah)),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFormField(
                            context,
                            label: 'Waktu Pengantaran Buah',
                            value: DateFormat(
                              'HH:mm',
                            ).format(DateTime.parse(widget.spb.tglAntarBuah)),
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),

                    // No E-SPB
                    _buildFormField(
                      context,
                      label: 'No E-SPB',
                      value: widget.spb.noSpb,
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    // Vendor
                    _buildFormField(
                      context,
                      label: 'Vendor',
                      value: widget.spb.kodeVendor ?? 'N/A',
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    // Tujuan Pengantaran Buah
                    _buildFormField(
                      context,
                      label: 'Tujuan Pengantaran Buah',
                      value: widget.spb.millTujuan,
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    // Driver
                    _buildFormField(
                      context,
                      label: 'Driver',
                      value: widget.spb.driver ?? 'N/A',
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    // No Polisi Truk
                    _buildFormField(
                      context,
                      label: 'No Polisi Truk',
                      value: widget.spb.noPolisi ?? 'N/A',
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    // Jumlah Janjang and Brondolan (side by side)
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormField(
                            context,
                            label: 'Jumlah Janjang',
                            value: widget.spb.jumJjg?.toString() ?? 'N/A',
                            suffix: 'Kg',
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFormField(
                            context,
                            label: 'Brondolan',
                            value: widget.spb.brondolan?.toString() ?? 'N/A',
                            suffix: 'Kg',
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Total Berat Taksasi
                    _buildFormField(
                      context,
                      label: 'Total Berat Taksasi',
                      value: widget.spb.totBeratTaksasi?.toString() ?? 'N/A',
                      suffix: 'Kg',
                      readOnly: true,
                    ),

                    //const SizedBox(height: 32),
                    // Row(
                    //   //crossAxisAlignment: CrossAxisAlignment.center,
                    //   children: <Widget>[
                    //     //const SizedBox(width: 100),
                    //     Checkbox(
                    //       checkColor: Colors.white,
                    //       activeColor: Color(0xFF2563EB),
                    //       value: first,
                    //       onChanged: (bool? value) {
                    //         setState(() {
                    //           first = value!;
                    //         });
                    //       },
                    //     ),
                    //     const Text(
                    //       'Ada Perngantian driver atau kendaraan',
                    //       style: TextStyle(fontSize: 15.0),
                    //     ),
                    //   ],
                    // ),
                    // // Save button
                    // const SizedBox(height: 10),

                    // Column(
                    //   crossAxisAlignment: CrossAxisAlignment.start,
                    //   children: [
                    //     Text(
                    //       "Silakan input kendala",
                    //       style: TextStyle(
                    //         fontSize: 14,
                    //         color: Colors.grey[700],
                    //         fontWeight: FontWeight.w500,
                    //       ),
                    //     ),
                    //     const SizedBox(height: 6),
                    //     TextFormField(
                    //       keyboardType: TextInputType.multiline,
                    //       //controller: notesController,
                    //       maxLines: 5,
                    //       decoration: InputDecoration(
                    //         border: OutlineInputBorder(
                    //           borderRadius: BorderRadius.all(
                    //             Radius.circular(10.0),
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    Column(
                      children: [
                        CheckboxListTile(
                          title: Text('Ada perngantian driver atau kendaraan'),
                          value: _isChecked,
                          onChanged: (bool? value) {
                            setState(() {
                              _isChecked = value ?? false;
                            });
                          },
                        ),
                        TextFormField(
                          //controller: _textController,
                          keyboardType: TextInputType.multiline,
                          maxLines: 5,
                          enabled: _isChecked, // aktif kalau checkbox dicentang
                          decoration: InputDecoration(
                            labelText: "Silakan input kendala",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : _showAcceptConfirmationDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
                                : const Text('Kirim Form Keterangan Kendala'),
                      ),
                    ),

                    // Checkbox(
                    //   checkColor: Colors.white,
                    //   activeColor: Color(0xFF60A5FA),
                    //   value: first,
                    //   onChanged: (bool? value) {
                    //     setState(() {
                    //       first = value!;
                    //     });
                    //   },
                    // ),

                    // // Disclaimer text
                    // const Center(
                    //   child: Text(
                    //     '*Data tidak sesuai dapat konfirmasi ke admin',
                    //     style: TextStyle(
                    //       fontSize: 12,
                    //       fontStyle: FontStyle.italic,
                    //       color: Colors.grey,
                    //     ),
                    //   ),
                    // ),

                    // const SizedBox(height: 16),

                    // // Konfirmasi Ke Admin button
                    // SizedBox(
                    //   width: double.infinity,
                    //   child: OutlinedButton(
                    //     onPressed: () {
                    //       // Implement admin confirmation
                    //       ScaffoldMessenger.of(context).showSnackBar(
                    //         const SnackBar(
                    //           content: Text(
                    //             'Konfirmasi ke admin akan diimplementasikan',
                    //           ),
                    //         ),
                    //       );
                    //     },
                    //     style: OutlinedButton.styleFrom(
                    //       padding: const EdgeInsets.symmetric(vertical: 16),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(8),
                    //       ),
                    //     ),
                    //     child: const Text('Konfirmasi Ke Admin'),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
    String? suffix,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(icon, color: Colors.grey),
                ),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: icon == null ? 12 : 0,
                    right: suffix != null ? 0 : 12,
                  ),
                  child: TextField(
                    controller: TextEditingController(text: value),
                    readOnly: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              if (suffix != null) ...[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    suffix,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
