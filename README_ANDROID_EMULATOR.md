# Android Emulator Configuration Guide

This guide explains how to configure the SPB Secure App to work with Android emulators, specifically handling the `10.0.2.2` IP address requirement.

## Quick Setup for Android Emulator

### Automatic Configuration (Recommended)
The app automatically detects when running on an Android emulator and converts localhost URLs to use `10.0.2.2`:

```bash
# Set your normal localhost URL
export DEV_API_BASE_URL=http://localhost:8000/api

# The app will automatically convert this to:
# http://10.0.2.2:8000/api when running on Android emulator
```

### Manual Configuration
If you prefer explicit configuration:

```bash
# Explicitly set the emulator IP
export DEV_API_BASE_URL=http://10.0.2.2:8000/api
```

## Understanding Android Emulator Networking

### Why 10.0.2.2?
- Android emulators run in a virtual network
- `localhost` and `127.0.0.1` refer to the emulator itself, not your host machine
- `10.0.2.2` is the special IP that maps to your host machine's localhost

### Network Mapping
| Host Machine | Android Emulator |
|--------------|------------------|
| `localhost` | `10.0.2.2` |
| `127.0.0.1` | `10.0.2.2` |
| `192.168.x.x` | Same IP (if accessible) |

## Step-by-Step Configuration

### 1. Backend Server Setup
Ensure your backend server is running and accessible:

```bash
# Start your backend server (example with Node.js)
npm start
# or
python manage.py runserver 0.0.0.0:8000
# or
./your-backend-server --port 8000
```

**Important**: Bind your server to `0.0.0.0` or all interfaces, not just `localhost`.

### 2. Environment Configuration
Choose one of these approaches:

#### Option A: Automatic Detection (Recommended)
```bash
# .env or environment variables
FLUTTER_ENV=development
DEV_API_BASE_URL=http://localhost:8000/api
```

#### Option B: Explicit Emulator Configuration
```bash
# .env or environment variables
FLUTTER_ENV=development
DEV_API_BASE_URL=http://10.0.2.2:8000/api
```

### 3. Verify Configuration
The app provides debug information to verify your configuration:

```dart
// Check current configuration
print(EnvironmentConfig.getConfigSummary());

// Check emulator-specific info
print(AndroidEmulatorConfig.getDebugInfo());
```

## Common Port Configurations

### Default Development Ports
| Framework | Default Port | Emulator URL |
|-----------|--------------|--------------|
| Node.js/Express | 3000 | `http://10.0.2.2:3000/api` |
| Django | 8000 | `http://10.0.2.2:8000/api` |
| Rails | 3000 | `http://10.0.2.2:3000/api` |
| Spring Boot | 8080 | `http://10.0.2.2:8080/api` |
| Flask | 5000 | `http://10.0.2.2:5000/api` |

### Custom Port Example
```bash
# If your backend runs on port 9000
DEV_API_BASE_URL=http://localhost:9000/api
# Automatically becomes: http://10.0.2.2:9000/api
```

## Troubleshooting

### Connection Issues

1. **"Connection refused" or "Network error"**
   ```bash
   # Check if your backend server is running
   curl http://localhost:8000/api/health
   
   # Check if it's accessible from outside localhost
   curl http://10.0.2.2:8000/api/health
   ```

2. **Backend server not accessible**
   - Ensure server binds to `0.0.0.0`, not just `localhost`
   - Check firewall settings
   - Verify the port number matches

3. **CORS issues**
   - Configure your backend to allow requests from `10.0.2.2`
   - Add appropriate CORS headers

### Configuration Validation

Use the built-in validation to check your setup:

```dart
final validation = EnvironmentValidator.validateEnvironment();
print(validation.getReport());
```

### Debug Information

Get detailed information about your current configuration:

```dart
// Environment configuration
final config = EnvironmentConfig.getConfigSummary();
print('Environment Config: $config');

// Android emulator specific info
if (Platform.isAndroid) {
  final emulatorInfo = AndroidEmulatorConfig.getDebugInfo();
  print('Emulator Info: $emulatorInfo');
}
```

## Backend Server Configuration Examples

### Node.js/Express
```javascript
// Make sure to bind to all interfaces
app.listen(8000, '0.0.0.0', () => {
  console.log('Server running on http://0.0.0.0:8000');
});

// Add CORS for emulator
app.use(cors({
  origin: ['http://localhost:3000', 'http://10.0.2.2:3000']
}));
```

### Django
```python
# settings.py
ALLOWED_HOSTS = ['localhost', '127.0.0.1', '10.0.2.2']

# Run server
python manage.py runserver 0.0.0.0:8000
```

### Flask
```python
# app.py
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
```

## Testing Your Configuration

### 1. Test Backend Accessibility
```bash
# From your host machine
curl http://localhost:8000/api/health

# Test emulator accessibility (if you have adb)
adb shell
curl http://10.0.2.2:8000/api/health
```

### 2. Test in Flutter App
```dart
// Add this to your app for testing
void testConnection() async {
  try {
    final response = await Dio().get('${EnvironmentConfig.baseUrl}/health');
    print('Connection successful: ${response.statusCode}');
  } catch (e) {
    print('Connection failed: $e');
  }
}
```

## Best Practices

1. **Use Automatic Detection**: Let the app handle URL conversion automatically
2. **Bind Server Correctly**: Always bind your backend to `0.0.0.0` for emulator access
3. **Test Both Platforms**: Verify your configuration works on both emulator and real devices
4. **Use Environment Variables**: Keep configuration flexible with environment variables
5. **Monitor Logs**: Check both Flutter and backend logs for connection issues

## Security Considerations

- `10.0.2.2` URLs are only for development/testing
- Never use emulator-specific URLs in production
- The app automatically prevents `10.0.2.2` URLs in production builds
- Always use HTTPS for staging and production environments

## Alternative Solutions

If `10.0.2.2` doesn't work for your setup:

1. **Use your machine's IP address**:
   ```bash
   # Find your IP address
   ipconfig getifaddr en0  # macOS
   ip route get 1 | awk '{print $7}'  # Linux
   
   # Use it in configuration
   DEV_API_BASE_URL=http://192.168.1.100:8000/api
   ```

2. **Use ngrok for external access**:
   ```bash
   # Install and run ngrok
   ngrok http 8000
   
   # Use the ngrok URL
   DEV_API_BASE_URL=https://abc123.ngrok.io/api
   ```

3. **Use Android emulator with custom network**:
   ```bash
   # Start emulator with custom network settings
   emulator -avd YourAVD -netdelay none -netspeed full
   ```