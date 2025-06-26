# Deployment Guide

## Overview

This guide covers deployment strategies, environment configuration, and platform-specific deployment instructions for the SPB Secure Flutter application.

## Deployment Environments

### Development
- **Purpose**: Local development and testing
- **API**: `http://10.0.2.2:8097/v1`
- **Features**: Debug logging, hot reload, development tools
- **Security**: Relaxed security for development convenience

### Staging
- **Purpose**: Pre-production testing and QA
- **API**: `https://api-staging.spb-secure.com/v1`
- **Features**: Production-like environment with test data
- **Security**: Production security with test certificates

### Production
- **Purpose**: Live application for end users
- **API**: `https://api.spb-secure.com/v1`
- **Features**: Optimized performance, monitoring, analytics
- **Security**: Full security hardening and compliance

## Pre-Deployment Checklist

### Code Quality
- [ ] All tests passing (`flutter test`)
- [ ] Code analysis clean (`flutter analyze`)
- [ ] No debug code or console logs in production
- [ ] Proper error handling implemented
- [ ] Security review completed

### Configuration
- [ ] Environment variables configured
- [ ] API endpoints verified
- [ ] SSL certificates valid
- [ ] Database migrations tested
- [ ] Third-party integrations configured

### Performance
- [ ] App size optimized
- [ ] Images compressed and optimized
- [ ] Unnecessary dependencies removed
- [ ] Performance testing completed
- [ ] Memory leaks checked

### Security
- [ ] API keys secured
- [ ] Authentication flows tested
- [ ] Data encryption verified
- [ ] Security headers configured
- [ ] Vulnerability scan completed

## Build Configuration

### Environment Setup

Create environment-specific configuration files:

```bash
# Development
echo "FLUTTER_ENV=development" > .env.development
echo "DEV_API_BASE_URL=http://10.0.2.2:8097/v1" >> .env.development

# Staging
echo "FLUTTER_ENV=staging" > .env.staging
echo "STAGING_API_BASE_URL=https://api-staging.spb-secure.com/v1" >> .env.staging

# Production
echo "FLUTTER_ENV=production" > .env.production
echo "PROD_API_BASE_URL=https://api.spb-secure.com/v1" >> .env.production
```

### Build Commands

#### Development Build
```bash
# Copy development environment
cp .env.development .env

# Build for development
flutter build apk --debug
flutter build ios --debug
```

#### Staging Build
```bash
# Copy staging environment
cp .env.staging .env

# Build for staging
flutter build apk --profile
flutter build ios --profile
```

#### Production Build
```bash
# Copy production environment
cp .env.production .env

# Build for production
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
flutter build ios --release --obfuscate --split-debug-info=build/debug-info
```

## Platform-Specific Deployment

### Android Deployment

#### Google Play Store

1. **Prepare Release Build**
```bash
# Build App Bundle (recommended)
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info

# Or build APK
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/debug-info
```

2. **Sign the App**
```bash
# Create keystore (first time only)
keytool -genkey -v -keystore ~/spb-release-key.keystore \
  -alias spb-key -keyalg RSA -keysize 2048 -validity 10000

# Configure signing in android/app/build.gradle
```

3. **Upload to Play Console**
- Upload the `.aab` file to Google Play Console
- Complete store listing information
- Set up release management
- Submit for review

#### Direct Distribution

1. **Build Signed APK**
```bash
flutter build apk --release --split-per-abi
```

2. **Distribute via Firebase App Distribution**
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Deploy to Firebase App Distribution
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app 1:123456789:android:abcd1234 \
  --groups "testers" \
  --release-notes "Version 1.0.0 - Initial release"
```

### iOS Deployment

#### App Store

1. **Prepare Release Build**
```bash
# Build for iOS
flutter build ios --release --obfuscate --split-debug-info=build/debug-info
```

2. **Archive in Xcode**
```bash
# Open iOS project
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select "Any iOS Device" as target
# 2. Product → Archive
# 3. Upload to App Store Connect
```

3. **App Store Connect**
- Complete app information
- Upload screenshots and metadata
- Set up pricing and availability
- Submit for review

#### TestFlight Distribution

1. **Build and Archive**
```bash
flutter build ios --release
# Archive in Xcode as above
```

2. **Upload to TestFlight**
- Upload via Xcode Organizer
- Add external testers
- Distribute for testing

### Web Deployment

#### Build for Web
```bash
# Build for web
flutter build web --release \
  --web-renderer canvaskit \
  --base-href /

# Build with custom base href
flutter build web --release \
  --web-renderer canvaskit \
  --base-href /spb-app/
```

#### Deploy to Firebase Hosting
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize Firebase
firebase init hosting

# Deploy
firebase deploy --only hosting
```

#### Deploy to Netlify
```bash
# Build the web app
flutter build web --release

# Deploy to Netlify
npx netlify-cli deploy --prod --dir=build/web
```

#### Deploy to GitHub Pages
```bash
# Build with correct base href
flutter build web --release --base-href /repository-name/

# Deploy using GitHub Actions
# See .github/workflows/deploy-web.yml
```

### Desktop Deployment

#### Windows

1. **Build Windows App**
```bash
flutter build windows --release
```

2. **Create Installer**
```bash
# Using Inno Setup
# Create installer script and build MSI/EXE
```

3. **Code Signing**
```bash
# Sign the executable
signtool sign /f certificate.p12 /p password build/windows/runner/Release/spb.exe
```

#### macOS

1. **Build macOS App**
```bash
flutter build macos --release
```

2. **Code Signing and Notarization**
```bash
# Sign the app
codesign --force --verify --verbose --sign "Developer ID Application: Your Name" \
  build/macos/Build/Products/Release/spb.app

# Create DMG
hdiutil create -volname "SPB Secure" -srcfolder build/macos/Build/Products/Release/spb.app \
  -ov -format UDZO spb-installer.dmg

# Notarize with Apple
xcrun notarytool submit spb-installer.dmg --keychain-profile "notarytool-profile" --wait
```

#### Linux

1. **Build Linux App**
```bash
flutter build linux --release
```

2. **Create Package**
```bash
# Create AppImage
# Create .deb package
# Create .rpm package
```

## CI/CD Pipeline

### GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy SPB Secure App

on:
  push:
    branches: [main, develop]
    tags: ['v*']
  pull_request:
    branches: [main]

env:
  FLUTTER_VERSION: '3.27.0'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: flutter packages pub run build_runner build --delete-conflicting-outputs

      - name: Run tests
        run: flutter test --coverage

      - name: Run analysis
        run: flutter analyze

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info

  build-android:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/')
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Configure environment
        run: |
          if [[ $GITHUB_REF == refs/tags/* ]]; then
            cp .env.production .env
          else
            cp .env.staging .env
          fi

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: flutter packages pub run build_runner build --delete-conflicting-outputs

      - name: Build APK
        run: flutter build apk --release --obfuscate --split-debug-info=build/debug-info

      - name: Build App Bundle
        run: flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info

      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: android-builds
          path: |
            build/app/outputs/flutter-apk/app-release.apk
            build/app/outputs/bundle/release/app-release.aab

  build-ios:
    needs: test
    runs-on: macos-latest
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/')
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - name: Configure environment
        run: |
          if [[ $GITHUB_REF == refs/tags/* ]]; then
            cp .env.production .env
          else
            cp .env.staging .env
          fi

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: flutter packages pub run build_runner build --delete-conflicting-outputs

      - name: Build iOS
        run: flutter build ios --release --no-codesign

      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: ios-build
          path: build/ios/iphoneos/Runner.app

  build-web:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - name: Configure environment
        run: |
          if [[ $GITHUB_REF == refs/tags/* ]]; then
            cp .env.production .env
          else
            cp .env.staging .env
          fi

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: flutter packages pub run build_runner build --delete-conflicting-outputs

      - name: Build web
        run: flutter build web --release --web-renderer canvaskit

      - name: Deploy to Firebase Hosting
        if: github.ref == 'refs/heads/main'
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          projectId: spb-secure-app
          channelId: live

  deploy-stores:
    needs: [build-android, build-ios]
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/')
    steps:
      - name: Download Android artifacts
        uses: actions/download-artifact@v3
        with:
          name: android-builds

      - name: Deploy to Google Play
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.example.spb
          releaseFiles: app-release.aab
          track: production
          status: completed
```

### GitLab CI/CD

Create `.gitlab-ci.yml`:

```yaml
stages:
  - test
  - build
  - deploy

variables:
  FLUTTER_VERSION: "3.27.0"

before_script:
  - apt-get update -qq && apt-get install -y -qq git curl unzip
  - git clone https://github.com/flutter/flutter.git -b stable --depth 1
  - export PATH="$PATH:`pwd`/flutter/bin"
  - flutter doctor -v
  - flutter pub get

test:
  stage: test
  script:
    - flutter packages pub run build_runner build --delete-conflicting-outputs
    - flutter test --coverage
    - flutter analyze
  coverage: '/lines......: \d+\.\d+\%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml

build_android:
  stage: build
  script:
    - cp .env.production .env
    - flutter packages pub run build_runner build --delete-conflicting-outputs
    - flutter build apk --release --obfuscate --split-debug-info=build/debug-info
    - flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
  artifacts:
    paths:
      - build/app/outputs/flutter-apk/app-release.apk
      - build/app/outputs/bundle/release/app-release.aab
    expire_in: 1 week
  only:
    - main
    - tags

build_web:
  stage: build
  script:
    - cp .env.production .env
    - flutter packages pub run build_runner build --delete-conflicting-outputs
    - flutter build web --release --web-renderer canvaskit
  artifacts:
    paths:
      - build/web/
    expire_in: 1 week
  only:
    - main
    - tags

deploy_firebase:
  stage: deploy
  image: node:18
  before_script:
    - npm install -g firebase-tools
  script:
    - firebase deploy --only hosting --token $FIREBASE_TOKEN
  dependencies:
    - build_web
  only:
    - main
```

## Environment Variables

### Required Variables

#### Development
```bash
FLUTTER_ENV=development
DEV_API_BASE_URL=http://10.0.2.2:8097/v1
DEV_ENABLE_LOGGING=true
DEV_TIMEOUT_SECONDS=30
```

#### Staging
```bash
FLUTTER_ENV=staging
STAGING_API_BASE_URL=https://api-staging.spb-secure.com/v1
STAGING_ENABLE_LOGGING=false
STAGING_TIMEOUT_SECONDS=60
```

#### Production
```bash
FLUTTER_ENV=production
PROD_API_BASE_URL=https://api.spb-secure.com/v1
PROD_ENABLE_LOGGING=false
PROD_TIMEOUT_SECONDS=120
```

### CI/CD Secrets

Store these as encrypted secrets in your CI/CD platform:

```bash
# Android
ANDROID_KEYSTORE_BASE64=<base64-encoded-keystore>
ANDROID_KEYSTORE_PASSWORD=<keystore-password>
ANDROID_KEY_ALIAS=<key-alias>
ANDROID_KEY_PASSWORD=<key-password>
GOOGLE_PLAY_SERVICE_ACCOUNT=<service-account-json>

# iOS
IOS_CERTIFICATE_BASE64=<base64-encoded-certificate>
IOS_CERTIFICATE_PASSWORD=<certificate-password>
IOS_PROVISIONING_PROFILE_BASE64=<base64-encoded-profile>
APP_STORE_CONNECT_API_KEY=<api-key>

# Firebase
FIREBASE_SERVICE_ACCOUNT=<service-account-json>
FIREBASE_TOKEN=<firebase-token>

# Other
SENTRY_DSN=<sentry-dsn>
ANALYTICS_KEY=<analytics-key>
```

## Monitoring and Analytics

### Application Performance Monitoring

#### Firebase Crashlytics
```dart
// Initialize in main.dart
await Firebase.initializeApp();
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

// Log custom events
FirebaseCrashlytics.instance.log('User performed action');
```

#### Sentry Integration
```dart
// Initialize Sentry
await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_SENTRY_DSN';
    options.environment = EnvironmentConfig.environmentName;
  },
  appRunner: () => runApp(MyApp()),
);
```

### Analytics

#### Firebase Analytics
```dart
// Track events
FirebaseAnalytics.instance.logEvent(
  name: 'user_login',
  parameters: {
    'method': 'username_password',
    'success': true,
  },
);
```

#### Custom Analytics
```dart
// Track user actions
AnalyticsService.track('button_clicked', {
  'button_name': 'login',
  'screen': 'login_page',
});
```

## Security Considerations

### Code Obfuscation

Always use obfuscation for production builds:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
flutter build ios --release --obfuscate --split-debug-info=build/debug-info
```

### Certificate Pinning

Implement certificate pinning for API calls:

```dart
// In DioClient
dio.interceptors.add(
  CertificatePinningInterceptor(
    allowedSHAFingerprints: ['SHA256:...'],
  ),
);
```

### API Key Security

- Never commit API keys to version control
- Use environment variables or secure key management
- Rotate keys regularly
- Monitor key usage

### Data Protection

- Encrypt sensitive data at rest
- Use HTTPS for all network communication
- Implement proper session management
- Follow GDPR/privacy regulations

## Rollback Strategy

### Immediate Rollback

1. **App Stores**
   - Use phased rollout to limit impact
   - Monitor crash reports and user feedback
   - Halt rollout if issues detected

2. **Web Deployment**
   - Keep previous version available
   - Use feature flags to disable problematic features
   - Quick rollback via deployment tools

### Gradual Rollback

1. **Feature Flags**
   - Disable new features remotely
   - Gradually reduce traffic to new version
   - Monitor metrics during rollback

2. **Database Migrations**
   - Ensure backward compatibility
   - Test rollback procedures
   - Have data recovery plan

## Performance Optimization

### Build Optimization

```bash
# Optimize build size
flutter build apk --release --target-platform android-arm64 --split-per-abi

# Tree shaking
flutter build web --release --tree-shake-icons

# Compress assets
flutter build apk --release --shrink
```

### Runtime Optimization

- Implement lazy loading
- Use image caching
- Optimize database queries
- Monitor memory usage

## Troubleshooting

### Common Deployment Issues

#### Build Failures
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter packages pub run build_runner clean
flutter packages pub run build_runner build --delete-conflicting-outputs
```

#### Signing Issues
```bash
# Verify keystore
keytool -list -v -keystore ~/spb-release-key.keystore

# Check certificate
openssl x509 -in certificate.pem -text -noout
```

#### Environment Issues
```bash
# Validate environment
flutter doctor -v
flutter config --list
```

### Deployment Verification

#### Post-Deployment Checks
- [ ] App launches successfully
- [ ] Authentication works
- [ ] API connectivity verified
- [ ] Core features functional
- [ ] Performance metrics normal
- [ ] Error rates acceptable

#### Monitoring Setup
- [ ] Crash reporting active
- [ ] Performance monitoring enabled
- [ ] Analytics tracking
- [ ] Log aggregation configured
- [ ] Alerting rules set up

This deployment guide ensures reliable, secure, and efficient deployment of the SPB Secure Flutter application across all supported platforms.