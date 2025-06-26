# SPB Secure Flutter Application

[![Flutter Version](https://img.shields.io/badge/Flutter-3.27.0+-blue.svg)](https://flutter.dev/)
[![Dart Version](https://img.shields.io/badge/Dart-3.7.0+-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive, production-ready Flutter application featuring secure authentication, robust data management, and enterprise-grade architecture patterns.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [API Documentation](#api-documentation)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

SPB Secure is a modern Flutter application built with clean architecture principles, featuring secure JWT-based authentication, comprehensive data management, and multi-platform support. The application demonstrates best practices in Flutter development, including proper state management, secure storage, network handling, and error management.

### Key Highlights

- **🔐 Secure Authentication**: JWT-based authentication with automatic token management
- **🏗️ Clean Architecture**: Separation of concerns with Domain, Data, and Presentation layers
- **📱 Multi-Platform**: Supports Android, iOS, Web, Windows, macOS, and Linux
- **🌐 Network Resilience**: Comprehensive error handling and network troubleshooting
- **💾 Data Management**: SQLite database with secure storage for sensitive data
- **🎨 Modern UI**: Material Design 3 with dark/light theme support
- **🔧 Environment Management**: Multi-environment configuration with validation

## ✨ Features

### Core Features

- **User Authentication**
  - Username/password login with JWT tokens
  - Automatic token validation and management
  - Secure token storage using Flutter Secure Storage
  - Session management with automatic logout on token expiration

- **Data Management**
  - SQLite database for local data storage
  - Data synchronization with remote API
  - Offline capability with sync queue
  - Export functionality (PDF, CSV)

- **User Interface**
  - Material Design 3 implementation
  - Dark and light theme support
  - Responsive design for all screen sizes
  - Accessibility features and screen reader support

- **Network & Security**
  - Comprehensive error handling with user-friendly messages
  - Network diagnostics and troubleshooting tools
  - Secure API communication with interceptors
  - Android emulator network configuration support

### Advanced Features

- **Environment Configuration**
  - Multi-environment support (Development, Staging, Production)
  - Environment variable validation
  - Automatic Android emulator URL conversion
  - Configuration debugging tools

- **Developer Tools**
  - JWT token decoder for debugging
  - Network diagnostics page
  - Comprehensive logging system
  - Error tracking and reporting

- **Data Export & Import**
  - PDF generation for reports
  - CSV export functionality
  - File picker integration
  - Image handling and processing

## 🏗️ Architecture

The application follows **Clean Architecture** principles with clear separation of concerns:

```
lib/
├── core/                    # Core functionality and utilities
│   ├── config/             # Environment and API configuration
│   ├── constants/          # Application constants
│   ├── di/                 # Dependency injection setup
│   ├── error/              # Error handling and exceptions
│   ├── network/            # Network layer and interceptors
│   ├── router/             # Navigation and routing
│   ├── storage/            # Data storage abstractions
│   ├── theme/              # UI theming
│   ├── utils/              # Utility functions and helpers
│   └── widgets/            # Reusable UI components
├── features/               # Feature modules
│   ├── auth/               # Authentication feature
│   │   ├── data/           # Data layer (repositories, data sources)
│   │   ├── domain/         # Domain layer (entities, use cases)
│   │   └── presentation/   # Presentation layer (UI, BLoC)
│   ├── home/               # Home dashboard feature
│   ├── data/               # Data management feature
│   ├── profile/            # User profile feature
│   └── theme/              # Theme management feature
└── main.dart               # Application entry point
```

### Architecture Layers

1. **Presentation Layer**: UI components, BLoC state management, and user interactions
2. **Domain Layer**: Business logic, entities, and use cases
3. **Data Layer**: Repository implementations, data sources, and models
4. **Core Layer**: Shared utilities, configurations, and infrastructure

## 🛠️ Tech Stack

### Framework & Language
- **Flutter**: 3.27.0+ (Cross-platform UI framework)
- **Dart**: 3.7.0+ (Programming language)

### State Management
- **flutter_bloc**: 8.1.6 (BLoC pattern implementation)
- **bloc**: 8.1.4 (Core BLoC library)
- **equatable**: 2.0.7 (Value equality)

### Navigation & Routing
- **go_router**: 14.8.1 (Declarative routing)

### Dependency Injection
- **get_it**: 7.7.0 (Service locator)
- **injectable**: 2.5.0 (Code generation for DI)

### Network & API
- **dio**: 5.8.0+ (HTTP client)
- **retrofit**: 4.4.2 (Type-safe HTTP client)
- **json_annotation**: 4.9.0 (JSON serialization)
- **connectivity_plus**: 6.1.4 (Network connectivity)

### Storage & Database
- **sqflite**: 2.4.2 (SQLite database)
- **shared_preferences**: 2.5.3 (Simple key-value storage)
- **flutter_secure_storage**: 9.2.4 (Secure storage)
- **path_provider**: 2.1.5 (File system paths)

### Authentication & Security
- **jwt_decoder**: 2.0.1 (JWT token handling)
- **crypto**: 3.0.6 (Cryptographic functions)

### UI & Design
- **cupertino_icons**: 1.0.8 (iOS-style icons)
- **cached_network_image**: 3.4.1 (Image caching)
- **shimmer**: 3.0.0 (Loading animations)
- **pull_to_refresh**: 2.0.0 (Pull-to-refresh functionality)

### File Handling
- **file_picker**: 8.3.7 (File selection)
- **image_picker**: 1.1.2 (Image selection)
- **image**: 4.5.4 (Image processing)
- **pdf**: 3.11.3 (PDF generation)
- **csv**: 6.0.0 (CSV handling)

### Utilities
- **intl**: 0.19.0 (Internationalization)
- **logger**: 2.5.0 (Logging)
- **uuid**: 4.5.1 (UUID generation)
- **permission_handler**: 11.4.0 (Device permissions)
- **dartz**: 0.10.1 (Functional programming)

### Development Tools
- **build_runner**: 2.5.1 (Code generation)
- **json_serializable**: 6.9.0 (JSON code generation)
- **injectable_generator**: 2.6.2 (DI code generation)
- **retrofit_generator**: 8.2.1 (HTTP client generation)

### Testing
- **flutter_test**: SDK (Unit and widget testing)
- **bloc_test**: 9.1.7 (BLoC testing)
- **mocktail**: 1.0.4 (Mocking)
- **integration_test**: SDK (Integration testing)

## 💻 System Requirements

### Development Environment
- **Flutter SDK**: 3.27.0 or higher
- **Dart SDK**: 3.7.0 or higher
- **Android Studio**: 2023.1+ or VS Code with Flutter extension
- **Xcode**: 15.0+ (for iOS development on macOS)

### Target Platforms
- **Android**: API level 21+ (Android 5.0+)
- **iOS**: iOS 12.0+
- **Web**: Modern browsers (Chrome, Firefox, Safari, Edge)
- **Windows**: Windows 10+
- **macOS**: macOS 10.14+
- **Linux**: Ubuntu 18.04+

### Hardware Requirements
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 10GB free space for development tools
- **Network**: Stable internet connection for dependencies

## 🚀 Installation

### 1. Prerequisites

Ensure you have Flutter installed and configured:

```bash
# Verify Flutter installation
flutter doctor

# Check for any missing dependencies
flutter doctor -v
```

### 2. Clone Repository

```bash
git clone https://github.com/your-org/spb-secure-app.git
cd spb-secure-app
```

### 3. Install Dependencies

```bash
# Get Flutter dependencies
flutter pub get

# Generate code (models, DI, etc.)
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### 4. Environment Setup

Copy the example environment file and configure it:

```bash
cp example.env .env
```

Edit `.env` with your configuration:

```bash
# Environment Configuration
FLUTTER_ENV=development
DEV_API_BASE_URL=http://10.0.2.2:8097/v1
DEV_ENABLE_LOGGING=true
DEV_TIMEOUT_SECONDS=30
```

### 5. Platform-Specific Setup

#### Android
```bash
# Accept Android licenses
flutter doctor --android-licenses

# For emulator development, ensure your backend is accessible
# Use 10.0.2.2 instead of localhost for Android emulator
```

#### iOS (macOS only)
```bash
# Install CocoaPods dependencies
cd ios && pod install && cd ..

# Open iOS project in Xcode if needed
open ios/Runner.xcworkspace
```

#### Web
```bash
# Enable web support (if not already enabled)
flutter config --enable-web
```

### 6. Run the Application

```bash
# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d chrome          # Web
flutter run -d android         # Android
flutter run -d ios             # iOS
flutter run -d windows         # Windows
flutter run -d macos           # macOS
flutter run -d linux           # Linux
```

## ⚙️ Configuration

### Environment Variables

The application supports multiple environments with automatic validation:

| Variable | Environment | Required | Description | Default |
|----------|-------------|----------|-------------|---------|
| `FLUTTER_ENV` | All | No | Environment type | `development` |
| `DEV_API_BASE_URL` | Development | No | Development API URL | `http://10.0.2.2:8097/v1` |
| `DEV_ENABLE_LOGGING` | Development | No | Enable debug logging | `true` |
| `DEV_TIMEOUT_SECONDS` | Development | No | Request timeout | `30` |
| `STAGING_API_BASE_URL` | Staging | Yes | Staging API URL | None |
| `STAGING_ENABLE_LOGGING` | Staging | No | Enable debug logging | `false` |
| `STAGING_TIMEOUT_SECONDS` | Staging | No | Request timeout | `60` |
| `PROD_API_BASE_URL` | Production | Yes | Production API URL | None |
| `PROD_ENABLE_LOGGING` | Production | No | Enable debug logging | `false` |
| `PROD_TIMEOUT_SECONDS` | Production | No | Request timeout | `120` |

### Android Emulator Configuration

For Android emulator development, the app automatically converts localhost URLs:

```bash
# Your backend URL
DEV_API_BASE_URL=http://localhost:8000/api

# Automatically becomes (for Android emulator)
# http://10.0.2.2:8000/api
```

### Database Configuration

The app uses SQLite for local storage with automatic migrations:

- **Database file**: `spb_secure.db`
- **Location**: Application documents directory
- **Version**: 2 (with username authentication support)
- **Tables**: users, data_entries, activity_logs, sync_queue, settings

### Security Configuration

- **JWT Token Storage**: Flutter Secure Storage with platform-specific encryption
- **API Communication**: HTTPS required for production
- **Token Validation**: Automatic expiration checking and cleanup
- **Error Handling**: Structured error responses with user-friendly messages

## 📖 Usage

### Authentication

```dart
// Login with username and password
final authBloc = context.read<AuthBloc>();
authBloc.add(AuthLoginRequested(
  userName: 'your_username',
  password: 'your_password',
));

// Check authentication status
authBloc.add(const AuthCheckRequested());

// Logout
authBloc.add(const AuthLogoutRequested());
```

### Data Management

```dart
// Access data repository
final dataRepository = getIt<DataRepository>();

// Save data entry
await dataRepository.saveDataEntry({
  'name': 'John Doe',
  'email': 'john@example.com',
  'status': 'active',
});

// Get data entries with filtering
final entries = await dataRepository.getDataEntries(
  status: 'active',
  limit: 10,
  orderBy: 'created_at DESC',
);
```

### Network Diagnostics

```dart
// Run network diagnostics
final diagnostics = await NetworkTroubleshooter.diagnoseNetwork();
final report = NetworkTroubleshooter.generateTroubleshootingReport(diagnostics);
print(report);
```

### JWT Token Management

```dart
// Access JWT token manager
final tokenManager = getIt<JwtTokenManager>();

// Get current user data from token
final userData = await tokenManager.getCurrentUserData();

// Get specific claims
final permissions = await tokenManager.getSpecificClaims(['permissions', 'roles']);

// Check token validity
final metadata = await tokenManager.getTokenMetadata();
```

## 📡 API Documentation

### Authentication Endpoints

#### Login
```http
POST /Account/LoginUser
Content-Type: application/json

{
  "userName": "string",
  "password": "string"
}
```

**Response:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### Logout
```http
POST /auth/logout
Authorization: Bearer {token}
```

### User Endpoints

#### Get Current User
```http
GET /user/profile
Authorization: Bearer {token}
```

**Response:**
```json
{
  "id": "string",
  "userName": "string",
  "email": "string",
  "name": "string",
  "avatar": "string",
  "createdAt": "2025-01-27T10:30:45.123Z",
  "updatedAt": "2025-01-27T10:30:45.123Z"
}
```

### Error Responses

All API endpoints return structured error responses:

```json
{
  "statusCode": 422,
  "errorCode": "VALIDATION_ERROR",
  "message": "The request contains invalid data",
  "details": "Validation failed for 3 field(s).",
  "suggestedActions": [
    "Review the field errors below and correct the invalid data",
    "Ensure all required fields are provided"
  ],
  "timestamp": "2025-01-27T10:30:45.123Z",
  "requestId": "req_7f8a9b2c-3d4e-5f6g-7h8i-9j0k1l2m3n4o",
  "fieldErrors": {
    "email": ["Email address is required"],
    "password": ["Password must be at least 8 characters long"]
  },
  "retryable": false
}
```

### Rate Limiting

- **Rate Limit**: 100 requests per hour per user
- **Headers**: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- **Error Code**: `RATE_LIMIT_EXCEEDED` (HTTP 429)

## 🔧 Development

### Code Generation

The project uses code generation for various purposes:

```bash
# Generate all code (models, DI, etc.)
flutter packages pub run build_runner build

# Watch for changes and regenerate automatically
flutter packages pub run build_runner watch

# Clean and regenerate
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Adding New Features

1. **Create Feature Structure**:
   ```
   lib/features/new_feature/
   ├── data/
   │   ├── datasources/
   │   ├── models/
   │   └── repositories/
   ├── domain/
   │   ├── entities/
   │   ├── repositories/
   │   └── usecases/
   └── presentation/
       ├── bloc/
       ├── pages/
       └── widgets/
   ```

2. **Register Dependencies**:
   ```dart
   // In lib/core/di/injection.dart
   getIt.registerLazySingleton<NewFeatureRepository>(
     () => NewFeatureRepositoryImpl(getIt<NewFeatureRemoteDataSource>()),
   );
   ```

3. **Add Routes**:
   ```dart
   // In lib/core/router/app_router.dart
   GoRoute(
     path: '/new-feature',
     name: 'newFeature',
     builder: (context, state) => const NewFeaturePage(),
   ),
   ```

### Debugging Tools

#### JWT Token Decoder
Access the debug token page to decode and inspect JWT tokens:
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const DebugTokenPage()),
);
```

#### Network Diagnostics
Run comprehensive network diagnostics:
```dart
final diagnostics = await NetworkTroubleshooter.diagnoseNetwork();
```

#### Environment Configuration
Check current environment configuration:
```dart
final config = EnvironmentConfig.getConfigSummary();
print(config);
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/

# Run specific test file
flutter test test/features/auth/auth_bloc_test.dart
```

### Test Structure

```
test/
├── core/                   # Core functionality tests
├── features/               # Feature-specific tests
│   ├── auth/
│   │   ├── auth_bloc_test.dart
│   │   ├── auth_repository_test.dart
│   │   └── login_usecase_test.dart
│   └── ...
├── helpers/                # Test helpers and utilities
└── mocks/                  # Mock objects
```

### Writing Tests

#### Unit Tests
```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('AuthBloc', () {
    late AuthBloc authBloc;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = MockAuthRepository();
      authBloc = AuthBloc(loginUseCase: LoginUseCase(mockRepository));
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when login succeeds',
      build: () => authBloc,
      act: (bloc) => bloc.add(AuthLoginRequested(
        userName: 'test',
        password: 'password',
      )),
      expect: () => [
        const AuthLoading(),
        isA<AuthAuthenticated>(),
      ],
    );
  });
}
```

#### Widget Tests
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LoginForm displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginForm(),
        ),
      ),
    );

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
```

## 🚀 Deployment

### Build for Production

#### Android
```bash
# Build APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Build with specific flavor
flutter build apk --release --flavor production
```

#### iOS
```bash
# Build for iOS
flutter build ios --release

# Build IPA for App Store
flutter build ipa --release
```

#### Web
```bash
# Build for web
flutter build web --release

# Build with specific base href
flutter build web --release --base-href /app/
```

#### Desktop
```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

### Environment-Specific Builds

```bash
# Development build
FLUTTER_ENV=development flutter build apk

# Staging build
FLUTTER_ENV=staging flutter build apk

# Production build
FLUTTER_ENV=production flutter build apk --release
```

### CI/CD Pipeline

Example GitHub Actions workflow:

```yaml
name: Build and Deploy

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
      - run: flutter pub get
      - run: flutter test
      - run: flutter analyze

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v3
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Android Emulator Network Issues

**Problem**: Cannot connect to localhost API from Android emulator.

**Solution**:
```bash
# Use 10.0.2.2 instead of localhost
DEV_API_BASE_URL=http://10.0.2.2:8000/api

# Or let the app auto-convert
DEV_API_BASE_URL=http://localhost:8000/api  # Auto-converts to 10.0.2.2
```

**Verification**:
```bash
# Test from emulator
adb shell
curl http://10.0.2.2:8000/api/health
```

#### 2. JWT Token Issues

**Problem**: Authentication fails with "Invalid token" error.

**Solution**:
1. Check token expiration:
   ```dart
   final metadata = await tokenManager.getTokenMetadata();
   print('Token valid: ${metadata?['isValid']}');
   ```

2. Verify token format:
   ```dart
   final claims = JwtDecoderUtil.getAvailableClaims(token);
   print('Available claims: $claims');
   ```

3. Clear stored tokens:
   ```dart
   await tokenManager.clearStoredToken();
   ```

#### 3. Build Issues

**Problem**: Code generation fails or outdated generated files.

**Solution**:
```bash
# Clean and regenerate
flutter clean
flutter pub get
flutter packages pub run build_runner clean
flutter packages pub run build_runner build --delete-conflicting-outputs
```

#### 4. Environment Configuration

**Problem**: "Environment configuration not initialized" error.

**Solution**:
1. Ensure environment variables are set
2. Check `.env` file exists and is properly formatted
3. Verify `EnvironmentConfig.initialize()` is called in `main()`

#### 5. Database Migration Issues

**Problem**: Database schema errors or migration failures.

**Solution**:
```dart
// Clear database and restart
await DatabaseHelper.instance.clearAllData();

// Or delete database file and restart app
final dbPath = await getDatabasesPath();
await deleteDatabase(join(dbPath, 'spb_secure.db'));
```

### Debug Tools

#### Network Diagnostics
```dart
// Run comprehensive network diagnostics
final diagnostics = await NetworkTroubleshooter.diagnoseNetwork();
final report = NetworkTroubleshooter.generateTroubleshootingReport(diagnostics);
print(report);
```

#### Environment Validation
```dart
// Validate environment configuration
final validation = EnvironmentValidator.validateEnvironment();
print(validation.getReport());
```

#### JWT Token Debugging
```dart
// Use the debug token page
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const DebugTokenPage()),
);
```

### Performance Issues

#### 1. Slow App Startup

**Causes**:
- Large dependency injection setup
- Heavy initialization in main()
- Synchronous database operations

**Solutions**:
- Use lazy singletons in DI
- Move heavy operations to background
- Implement splash screen with async initialization

#### 2. Memory Leaks

**Common Causes**:
- Unclosed streams
- Retained BLoC instances
- Large cached images

**Solutions**:
- Always dispose controllers and streams
- Use `flutter_bloc` properly with `BlocProvider`
- Implement proper image caching limits

### Getting Help

1. **Check Logs**: Enable debug logging and check console output
2. **Network Issues**: Use the built-in network diagnostics tool
3. **Environment Issues**: Run environment validation
4. **JWT Issues**: Use the JWT token decoder debug page
5. **Database Issues**: Check SQLite logs and migration status

For additional support:
- Check the [Flutter documentation](https://flutter.dev/docs)
- Review [GitHub Issues](https://github.com/your-org/spb-secure-app/issues)
- Contact the development team

## 🤝 Contributing

We welcome contributions to improve the SPB Secure application! Please follow these guidelines:

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Follow the existing code style and architecture patterns
4. Write tests for new functionality
5. Ensure all tests pass: `flutter test`
6. Run code analysis: `flutter analyze`
7. Commit changes: `git commit -m 'Add amazing feature'`
8. Push to branch: `git push origin feature/amazing-feature`
9. Open a Pull Request

### Code Style

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Add documentation for public APIs
- Keep functions small and focused
- Use proper error handling

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add user profile management
fix: resolve Android emulator network issues
docs: update API documentation
test: add unit tests for auth bloc
refactor: improve error handling structure
```

### Pull Request Process

1. Update documentation for any new features
2. Add tests for new functionality
3. Ensure CI/CD pipeline passes
4. Request review from maintainers
5. Address feedback and make necessary changes

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support and questions:

- **Documentation**: Check this README and related docs
- **Issues**: [GitHub Issues](https://github.com/your-org/spb-secure-app/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/spb-secure-app/discussions)
- **Email**: support@spb-secure.com

---

**Built with ❤️ using Flutter**