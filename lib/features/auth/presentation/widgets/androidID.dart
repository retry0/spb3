import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

class AndroidIDPage extends StatelessWidget {
  const AndroidIDPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: DeviceIdPage());
  }
}

class DeviceIdPage extends StatefulWidget {
  const DeviceIdPage({super.key});

  @override
  State<DeviceIdPage> createState() => _DeviceIdPageState();
}

class _DeviceIdPageState extends State<DeviceIdPage> {
  String _deviceId = 'Unknown';

  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceId;

    try {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id; // Android ID
    } catch (e) {
      deviceId = 'Gagal mendapatkan Device ID';
    }

    setState(() {
      _deviceId = deviceId;
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _deviceId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copy Device ID!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DEVICE ID')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ElevatedButton(
            //   onPressed: _getDeviceId,
            //   child: const Text('Dapatkan Device ID'),
            // ),
            ElevatedButton(
              onPressed: _getDeviceId,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Dapatkan Device ID',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SelectableText(
              'Device ID: $_deviceId',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            // ElevatedButton(
            //   onPressed: _deviceId == 'Tidak tahu' ? null : _copyToClipboard,
            //   child: const Text('Salin ke Papan Klip'),
            // ),
            ElevatedButton(
              onPressed: _deviceId == 'Tidak tahu' ? null : _copyToClipboard,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Salin ke Papan Klip',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
