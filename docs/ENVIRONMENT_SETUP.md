# Environment Setup Guide

## Overview

This document provides detailed instructions for setting up development, staging, and production environments for the SPB Secure Flutter application. It covers environment variables, configuration options, and platform-specific setup requirements.

## Environment Types

The application supports three environment types:

1. **Development**: For local development and testing
2. **Staging**: For pre-production testing and QA
3. **Production**: For live application deployment

## Environment Variables

### Core Configuration

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `FLUTTER_ENV` | No | Environment type: `development`, `staging`, `production` | `development` |

### Development Environment

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `DEV_API_BASE_URL` | No | Development API base URL | `http://10.0.2.2:8097/v1` |
| `DEV_ENABLE_LOGGING` | No | Enable debug logging | `true` |
| `DEV_TIMEOUT_SECONDS` | No | Request timeout in seconds | `30` |

### Staging Environment

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `STAGING_API_BASE_URL` | Yes | Staging API base URL | None |
| `STAGING_ENABLE_LOGGING` | No | Enable debug logging | `false` |
| `STAGING_TIMEOUT_SECONDS` | No | Request timeout in seconds | `60` |

### Production Environment

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PROD_API_BASE_URL` | Yes | Production API base URL | None |
| `PROD_ENABLE_LOGGING` | No | Enable debug logging | `false` |
| `PROD_TIMEOUT_SECONDS` | No | Request timeout in seconds | `120` |

## Setup Instructions

### Local Development Setup

1. **Create Environment File**

   Copy the example environment file:
   ```bash
   cp example.env .env
   ```

2. **Configure Development Environment**

   Edit `.env` with your development settings:
   ```bash
   FLUTTER_ENV=development
   DEV_API_BASE_URL=http://10.0.2.2:8097/v1
   DEV_ENABLE_LOGGING=true
   DEV_TIMEOUT_SECONDS=30
   ```

3. **Run the Application**

   ```bash
   flutter run
   ```

### Android Emulator Configuration

When using an Android emulator, the application automatically converts `localhost` references to `10.0.2.2` (the special IP that allows the emulator to access the host machine's localhost).

For example:
- `http://localhost:8000/api` becomes `http://10.0.2.2:8000/api`

You can also explicitly set the emulator URL:
```bash
DEV_API_BASE_URL=http://10.0.2.2:8000/api
```

### Staging Environment Setup

1. **Create Staging Environment File**

   ```bash
   cp example.env .env.staging
   ```

2. **Configure Staging Environment**

   Edit `.env.staging` with your staging settings:
   ```bash
   FLUTTER_ENV=staging
   STAGING_API_BASE_URL=https://api-staging.spb-secure.com/v1
   STAGING_ENABLE_LOGGING=false
   STAGING_TIMEOUT_SECONDS=60
   ```

3. **Build for Staging**

   ```bash
   # Copy staging environment
   cp .env.staging .env
   
   # Build for your target platform
   flutter build apk --profile
   flutter build ios --profile
   flutter build web --profile
   ```

### Production Environment Setup

1. **Create Production Environment File**

   ```bash
   cp example.env .env.production
   ```

2. **Configure Production Environment**

   Edit `.env.production` with your production settings:
   ```bash
   FLUTTER_ENV=production
   PROD_API_BASE_URL=https://api.spb-secure.com/v1
   PROD_ENABLE_LOGGING=false
   PROD_TIMEOUT_SECONDS=120
   ```

3. **Build for Production**

   ```bash
   # Copy production environment
   cp .env.production .env
   
   # Build for your target platform
   flutter build apk --release
   flutter build ios --release
   flutter build web --release
   ```

## Environment Validation

The application includes built-in environment validation to ensure proper configuration:

```dart
// Run environment validation
final validation = EnvironmentValidator.validateEnvironment();
print(validation.getReport());
```

### Validation Rules

1. **URL Format**: All API URLs must be valid URIs
2. **HTTPS in Production**: Production environment requires HTTPS URLs
3. **Required Variables**: All required variables must be set
4. **Value Types**: Boolean and integer values must be valid

### Validation Report Example

```
✅ Environment validation passed

Warnings:
  • Using common development port 8000. Ensure your backend server is running on this port.
  • Android emulator detected with localhost URL. Consider using 10.0.2.2 instead of localhost for better connectivity.
```

## CI/CD Environment Setup

### GitHub Actions

```yaml
name: Build and Deploy

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
      
      - name: Configure Environment
        run: |
          if [[ $GITHUB_REF == refs/heads/main ]]; then
            echo "FLUTTER_ENV=production" > .env
            echo "PROD_API_BASE_URL=${{ secrets.PROD_API_BASE_URL }}" >> .env
            echo "PROD_ENABLE_LOGGING=false" >> .env
            echo "PROD_TIMEOUT_SECONDS=120" >> .env
          else
            echo "FLUTTER_ENV=staging" > .env
            echo "STAGING_API_BASE_URL=${{ secrets.STAGING_API_BASE_URL }}" >> .env
            echo "STAGING_ENABLE_LOGGING=false" >> .env
            echo "STAGING_TIMEOUT_SECONDS=60" >> .env
          fi
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Generate code
        run: flutter packages pub run build_runner build --delete-conflicting-outputs
      
      - name: Build APK
        run: flutter build apk --release
      
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: app-release
          path: build/app/outputs/flutter-apk/app-release.apk
```

### GitLab CI

```yaml
stages:
  - test
  - build
  - deploy

variables:
  FLUTTER_VERSION: "3.27.0"

.setup_env: &setup_env |
  if [[ $CI_COMMIT_BRANCH == "main" ]]; then
    echo "FLUTTER_ENV=production" > .env
    echo "PROD_API_BASE_URL=${PROD_API_BASE_URL}" >> .env
    echo "PROD_ENABLE_LOGGING=false" >> .env
    echo "PROD_TIMEOUT_SECONDS=120" >> .env
  elif [[ $CI_COMMIT_BRANCH == "develop" ]]; then
    echo "FLUTTER_ENV=staging" > .env
    echo "STAGING_API_BASE_URL=${STAGING_API_BASE_URL}" >> .env
    echo "STAGING_ENABLE_LOGGING=false" >> .env
    echo "STAGING_TIMEOUT_SECONDS=60" >> .env
  else
    echo "FLUTTER_ENV=development" > .env
    echo "DEV_API_BASE_URL=${DEV_API_BASE_URL}" >> .env
    echo "DEV_ENABLE_LOGGING=true" >> .env
    echo "DEV_TIMEOUT_SECONDS=30" >> .env
  fi

build:
  stage: build
  image: cirrusci/flutter:${FLUTTER_VERSION}
  script:
    - *setup_env
    - flutter pub get
    - flutter packages pub run build_runner build --delete-conflicting-outputs
    - flutter build apk --release
  artifacts:
    paths:
      - build/app/outputs/flutter-apk/app-release.apk
```

## Environment-Specific Features

### Feature Flags

The application supports environment-specific feature flags:

```dart
// Define feature flags
class FeatureFlags {
  static bool get enableBiometricAuth {
    if (EnvironmentConfig.isProduction) {
      return true; // Enabled in production
    } else if (EnvironmentConfig.isStaging) {
      return true; // Enabled in staging for testing
    } else {
      return true; // Configurable in development
    }
  }
  
  static bool get enableAnalytics {
    return !EnvironmentConfig.isDevelopment; // Disabled in development
  }
  
  static bool get enableCrashReporting {
    return !EnvironmentConfig.isDevelopment; // Disabled in development
  }
}

// Usage
if (FeatureFlags.enableBiometricAuth) {
  // Show biometric auth option
}
```

### Environment-Specific Assets

For environment-specific assets, use asset variants:

```yaml
# In pubspec.yaml
flutter:
  assets:
    - assets/config/
    - assets/images/
    - assets/branding/
```

```dart
// Load environment-specific configuration
Future<Map<String, dynamic>> loadConfig() async {
  final env = EnvironmentConfig.environmentName;
  final configFile = 'assets/config/config_$env.json';
  
  try {
    final jsonString = await rootBundle.loadString(configFile);
    return jsonDecode(jsonString);
  } catch (e) {
    // Fallback to default config
    final defaultConfig = await rootBundle.loadString('assets/config/config_default.json');
    return jsonDecode(defaultConfig);
  }
}
```

## Troubleshooting

### Common Issues

#### 1. Environment Not Initialized

**Symptoms:**
- "EnvironmentConfig not initialized" error
- App crashes on startup

**Solutions:**
- Ensure `EnvironmentConfig.initialize()` is called in `main()` before accessing any configuration
- Check that `.env` file exists and is properly formatted
- Verify environment variables are set correctly

#### 2. API Connection Issues

**Symptoms:**
- API requests fail with connection errors
- "Failed to connect to host" errors

**Solutions:**
- Verify API URL is correct for the current environment
- Check network connectivity
- For Android emulator, ensure localhost URLs are converted to 10.0.2.2
- Verify backend server is running and accessible

#### 3. Invalid Environment Configuration

**Symptoms:**
- "Invalid environment" errors
- "Invalid URL format" errors
- "Required environment variable not set" errors

**Solutions:**
- Run environment validation to identify specific issues
- Check environment variable format and values
- Ensure required variables are set for the current environment
- Verify URL format and scheme (HTTPS required for production)

## Environment Debugging

### Debug Tools

The application includes several tools for debugging environment issues:

```dart
// Get environment configuration summary
final config = EnvironmentConfig.getConfigSummary();
print('Environment Config: $config');

// Validate environment
final validation = EnvironmentValidator.validateEnvironment();
print('Validation Report:\n${validation.getReport()}');

// Check Android emulator configuration
if (Platform.isAndroid) {
  final emulatorInfo = AndroidEmulatorConfig.getDebugInfo();
  print('Emulator Info: $emulatorInfo');
}

// Run network diagnostics
final diagnostics = await NetworkTroubleshooter.diagnoseNetwork();
final report = NetworkTroubleshooter.generateTroubleshootingReport(diagnostics);
print('Network Diagnostics:\n$report');
```

### Environment Inspector

For development builds, the application includes an Environment Inspector screen:

```dart
// Navigate to Environment Inspector
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const EnvironmentInspectorPage()),
);
```

The Environment Inspector provides:
- Current environment configuration
- Environment validation results
- Network diagnostics
- API endpoint testing
- Environment variable override options (development only)

## Security Considerations

### Environment Variable Security

1. **Never commit `.env` files to version control**
2. **Use secure storage for CI/CD environment variables**
3. **Limit access to production environment variables**
4. **Rotate sensitive values regularly**

### Production Safeguards

1. **HTTPS Enforcement**
   ```dart
   // Ensure HTTPS in production
   if (_currentEnvironment == Environment.production && uri.scheme != 'https') {
     throw EnvironmentConfigException(
       'Production environment requires HTTPS URLs. Got: ${uri.scheme}'
     );
   }
   ```

2. **Logging Restrictions**
   ```dart
   // Disable detailed logging in production
   if (EnvironmentConfig.isProduction) {
     AppLogger.init(logLevel: LogLevel.error);
   }
   ```

3. **Debug Features Disabling**
   ```dart
   // Disable debug features in production
   if (kReleaseMode || EnvironmentConfig.isProduction) {
     debugShowCheckedModeBanner = false;
     debugShowMaterialGrid = false;
     debugPaintSizeEnabled = false;
   }
   ```

This environment setup guide provides comprehensive instructions for configuring and managing different environments in the SPB Secure Flutter application.