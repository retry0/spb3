# Data Synchronization Troubleshooting Guide

This guide addresses synchronization issues between the `kendala_form_page` offline data and the online API.

## 1. Offline Data Storage Implementation

### Local Storage Structure

The application uses a combination of `SharedPreferences` for simple key-value storage and SQLite database for structured data:

```dart
// In kendala_form_page.dart
Future<void> _saveDataToLocalStorage(Map<String, dynamic> data) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final spbId = widget.spb.noSpb;
    
    // Save form data as JSON string
    final formDataKey = 'kendala_form_data_$spbId';
    await prefs.setString(formDataKey, jsonEncode(data));
    
    // Save checkbox state
    await prefs.setBool(
      'kendala_driver_changed_$spbId',
      _isDriverOrVehicleChanged,
    );

    // Save kendala text
    await prefs.setString('kendala_text_$spbId', _kendalaController.text);

    // Save sync status
    await prefs.setBool('kendala_synced_$spbId', false);
    
    // Keep track of pending forms
    final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
    if (!pendingForms.contains(spbId)) {
      pendingForms.add(spbId);
      await prefs.setStringList('pending_kendala_forms', pendingForms);
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Error menyimpan data lokal: $e';
      _isLoading = false;
    });
  }
}
```

### Data Validation

The current implementation has basic validation but may need enhancement:

```dart
// In kendala_form_page.dart
void _submitForm() {
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
}
```

### Potential Issues:
- The data format stored in SharedPreferences might not match what the API expects
- JSON encoding/decoding errors could occur if special characters are present
- No validation for maximum text length or required fields beyond basic checks

## 2. Sync Mechanism

### Sync Trigger Conditions

The sync process is triggered in several scenarios:

```dart
// In kendala_form_page.dart
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
```

### Sync Scheduling Logic

The current implementation attempts to sync when:
1. Network connectivity is restored
2. The app starts (if there are pending items)
3. Manually triggered by the user

```dart
// In kendala_form_page.dart
Future<void> _syncData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
    
    if (pendingForms.isEmpty) return;
    
    // Show syncing notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menyinkronkan data kendala yang tertunda...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    for (final spbId in pendingForms) {
      final formDataKey = 'kendala_form_data_$spbId';
      final jsonData = prefs.getString(formDataKey);
      
      if (jsonData != null) {
        try {
          // Parse the stored JSON data
          final data = jsonDecode(jsonData) as Map<String, dynamic>;
          
          // Call API
          final response = await _dio.put(
            ApiServiceEndpoints.AdjustSPBDriver,
            data: data,
          );
          
          if (response.statusCode == 200) {
            // Mark as synced
            await prefs.setBool('kendala_synced_$spbId', true);
            pendingForms.remove(spbId);
          }
        } catch (e) {
          // Log error but continue with next item
          print('Error syncing kendala form for SPB $spbId: $e');
        }
      }
    }
    
    // Update pending list
    await prefs.setStringList('pending_kendala_forms', pendingForms);
  } catch (e) {
    print('Error syncing pending kendala data: $e');
  }
}
```

### Network Connectivity Handling

The app uses `connectivity_plus` to detect network changes:

```dart
// In kendala_form_page.dart
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
```

### Potential Issues:
- No retry mechanism with exponential backoff for failed sync attempts
- No handling for partial sync success (some items sync, others fail)
- No conflict resolution strategy if data is modified both locally and remotely
- No background sync capability when app is not in foreground

## 3. API Integration

### API Endpoint Configuration

The API endpoints are configured in `api_endpoints.dart`:

```dart
// In core/config/api_endpoints.dart
class ApiServiceEndpoints {
  static String get baseUrl => dotenv.env['API_BASE_URL']!;

  // Data endpoints
  static String get dataSPB =>
      '$baseUrl${dotenv.env['API_SPB_DATA_ENDPOINT']!}';

  static String get AcceptSPBDriver =>
      '$baseUrl${dotenv.env['API_ACCEPT_SPB_ENDPOINT']!}';

  static String get AdjustSPBDriver =>
      '$baseUrl${dotenv.env['API_ADJUST_SPB_ENDPOINT']!}';

  /// Get endpoint with query parameters
  static String withQuery(String endpoint, Map<String, String> params) {
    if (params.isEmpty) return endpoint;

    final uri = Uri.parse(endpoint);
    final newUri = uri.replace(
      queryParameters: {...uri.queryParameters, ...params},
    );

    return newUri.toString();
  }
}
```

### Authentication/Authorization

The app uses JWT tokens for authentication, managed by an auth interceptor:

```dart
// In core/network/interceptors/auth_interceptor.dart
class AuthInterceptor extends Interceptor {
  final SecureStorage _secureStorage = getIt<SecureStorage>();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _secureStorage.read(StorageKeys.accessToken);

      if (token != null && !JwtDecoder.isExpired(token)) {
        options.headers['Authorization'] = 'Bearer $token';
      } else if (token != null) {
        AppLogger.warning('Expired JWT token cleared');
      }
    } catch (e) {
      AppLogger.error('Auth interceptor error: $e');
    }

    handler.next(options);
  }
}
```

### Request/Response Format

The API expects a specific format for the kendala form data:

```dart
// In kendala_form_page.dart
final data = {
  'noSPB': widget.spb.noSpb,
  'latitude': _currentPosition?.latitude.toString() ?? "0.0",
  'longitude': _currentPosition?.longitude.toString() ?? "0.0",
  'createdBy': widget.spb.driver.toString(),
  'status': "2", // Set status to indicate kendala/issue
  'alasan': _kendalaController.text,
  'isAnyHandlingEx': _isDriverOrVehicleChanged ? "1" : "0",
  'timestamp': DateTime.now().millisecondsSinceEpoch,
};
```

### Error Handling

The current error handling in the sync process:

```dart
// In kendala_form_page.dart
try {
  // API call logic
} on DioException catch (e) {
  // Handle Dio specific errors
  String errorMessage;
  
  if (e.type == DioExceptionType.connectionTimeout || 
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    errorMessage = 'Koneksi timeout. Menyimpan data secara lokal.';
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
} catch (e) {
  // Handle other errors
  setState(() {
    _errorMessage = 'Error menyimpan data: $e';
    _isLoading = false;
  });
}
```

### Potential Issues:
- API endpoint URLs might be incorrect or have changed
- Authentication token might be expired or invalid
- Request format might not match what the API expects
- Error handling might not properly capture all error scenarios
- No handling for server-side validation errors

## 4. Synchronization Process Testing

### Current Sync Behavior

The current sync process follows this flow:
1. User submits a kendala form
2. If online, app attempts to send data to API immediately
3. If offline or API call fails, data is stored locally
4. When connectivity is restored, app attempts to sync pending data
5. Successfully synced items are removed from the pending list

### Expected Functionality

The expected behavior is:
1. Forms should be saved locally regardless of connectivity
2. Forms should be marked as "pending sync" when created offline
3. When connectivity is restored, all pending forms should be synced
4. Sync status should be clearly indicated to the user
5. Retry mechanism should handle temporary failures

### Error Messages and Logs

Common error messages:

```
Error syncing kendala form for SPB $spbId: DioException [...]
Failed to parse sync queue data: [...]
Network error during sync: Connection refused
```

### Data Consistency Verification

To verify data consistency:

```dart
// Check local storage for pending forms
final prefs = await SharedPreferences.getInstance();
final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
print('Pending forms: $pendingForms');

// Check sync status for a specific form
final spbId = 'SPB12345';
final isSynced = prefs.getBool('kendala_synced_$spbId') ?? false;
print('Form $spbId synced: $isSynced');

// Verify form data
final formData = prefs.getString('kendala_form_data_$spbId');
if (formData != null) {
  print('Form data: $formData');
} else {
  print('No form data found for $spbId');
}
```

## Recommended Fixes

### 1. Improve Offline Data Storage

```dart
// Create a dedicated class for managing offline data
class KendalaFormStorage {
  static Future<void> saveForm(String spbId, Map<String, dynamic> formData, bool isDriverChanged, String kendalaText) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save form data with proper error handling
    try {
      await prefs.setString('kendala_form_data_$spbId', jsonEncode(formData));
      await prefs.setBool('kendala_driver_changed_$spbId', isDriverChanged);
      await prefs.setString('kendala_text_$spbId', kendalaText);
      await prefs.setBool('kendala_synced_$spbId', false);
      
      // Update pending forms list
      final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
      if (!pendingForms.contains(spbId)) {
        pendingForms.add(spbId);
        await prefs.setStringList('pending_kendala_forms', pendingForms);
      }
      
      return true;
    } catch (e) {
      print('Error saving form data: $e');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>?> getFormData(String spbId) async {
    final prefs = await SharedPreferences.getInstance();
    final formDataJson = prefs.getString('kendala_form_data_$spbId');
    
    if (formDataJson == null) return null;
    
    try {
      return jsonDecode(formDataJson) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing form data: $e');
      return null;
    }
  }
}
```

### 2. Enhance Sync Mechanism

```dart
// Implement a robust sync service with retry logic
class SyncService {
  final Dio _dio;
  final int maxRetries;
  final Duration initialBackoff;
  
  SyncService({
    required Dio dio,
    this.maxRetries = 3,
    this.initialBackoff = const Duration(seconds: 5),
  }) : _dio = dio;
  
  Future<bool> syncPendingForms() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingForms = prefs.getStringList('pending_kendala_forms') ?? [];
    
    if (pendingForms.isEmpty) return true;
    
    bool allSynced = true;
    
    for (final spbId in pendingForms) {
      final success = await _syncForm(spbId);
      if (success) {
        pendingForms.remove(spbId);
        await prefs.setStringList('pending_kendala_forms', pendingForms);
      } else {
        allSynced = false;
      }
    }
    
    return allSynced;
  }
  
  Future<bool> _syncForm(String spbId, {int retryCount = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final formDataJson = prefs.getString('kendala_form_data_$spbId');
    
    if (formDataJson == null) return false;
    
    try {
      final data = jsonDecode(formDataJson) as Map<String, dynamic>;
      
      final response = await _dio.put(
        ApiServiceEndpoints.AdjustSPBDriver,
        data: data,
      );
      
      if (response.statusCode == 200) {
        await prefs.setBool('kendala_synced_$spbId', true);
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error syncing form $spbId (attempt ${retryCount + 1}): $e');
      
      // Implement exponential backoff for retries
      if (retryCount < maxRetries) {
        final backoff = initialBackoff * pow(2, retryCount);
        await Future.delayed(backoff);
        return _syncForm(spbId, retryCount: retryCount + 1);
      }
      
      return false;
    }
  }
}
```

### 3. Improve API Integration

```dart
// Create a dedicated API service for kendala forms
class KendalaFormApiService {
  final Dio _dio;
  
  KendalaFormApiService({required Dio dio}) : _dio = dio;
  
  Future<bool> submitForm(Map<String, dynamic> formData) async {
    try {
      // Validate required fields
      _validateFormData(formData);
      
      // Add request timeout
      final options = Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );
      
      final response = await _dio.put(
        ApiServiceEndpoints.AdjustSPBDriver,
        data: formData,
        options: options,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('API error: $e');
      return false;
    }
  }
  
  void _validateFormData(Map<String, dynamic> data) {
    final requiredFields = ['noSPB', 'status', 'createdBy', 'latitude', 'longitude'];
    
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null || data[field].toString().isEmpty) {
        throw Exception('Missing required field: $field');
      }
    }
  }
}
```

### 4. Implement Better UI Feedback

```dart
// Add a sync status indicator widget
class SyncStatusIndicator extends StatelessWidget {
  final String spbId;
  final VoidCallback onRetry;
  
  const SyncStatusIndicator({
    Key? key,
    required this.spbId,
    required this.onRetry,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _getSyncStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final isSynced = snapshot.data ?? false;
        
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSynced ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSynced ? Colors.green : Colors.orange,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSynced ? Icons.cloud_done : Icons.cloud_upload,
                color: isSynced ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSynced 
                      ? 'Data telah disinkronkan dengan server' 
                      : 'Data belum disinkronkan dengan server',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSynced ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              if (!isSynced)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(60, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Future<bool> _getSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('kendala_synced_$spbId') ?? false;
  }
}
```

## Conclusion

The data synchronization issues between the kendala_form_page offline data and online API likely stem from several factors:

1. **Inconsistent data format**: The data saved locally might not match what the API expects
2. **Inadequate error handling**: The current implementation doesn't properly handle all error scenarios
3. **Lack of robust retry mechanism**: Failed sync attempts don't have a proper retry strategy
4. **Poor connectivity handling**: The app might not correctly detect network state changes
5. **Insufficient user feedback**: Users may not be aware of sync status or failures

By implementing the recommended fixes, you can create a more reliable synchronization process that properly handles offline data storage, provides clear user feedback, and ensures data consistency between the local device and the server.