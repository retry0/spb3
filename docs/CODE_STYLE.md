# Code Style Guide

## Overview

This document outlines the coding standards and style guidelines for the SPB Secure Flutter application. Following these guidelines ensures code consistency, readability, and maintainability across the project.

## General Principles

### 1. Readability

- Write code that is easy to read and understand
- Prioritize clarity over cleverness
- Use descriptive names for variables, functions, and classes
- Include comments for complex logic, but let code speak for itself when possible

### 2. Consistency

- Follow established patterns throughout the codebase
- Use consistent naming conventions
- Maintain consistent file structure and organization
- Apply formatting rules uniformly

### 3. Maintainability

- Write modular, reusable code
- Keep functions and classes focused on a single responsibility
- Minimize dependencies between components
- Write code that is easy to test

## Dart Style Guide

### Naming Conventions

#### Classes and Types

- Use `UpperCamelCase` for classes, enums, extensions, and typedefs
- Be descriptive and avoid abbreviations

```dart
// Good
class UserRepository {}
enum ConnectionStatus {}
typedef JsonMap = Map<String, dynamic>;

// Bad
class userRepo {}
enum connStat {}
typedef JSON = Map<String, dynamic>;
```

#### Variables and Functions

- Use `lowerCamelCase` for variables, functions, and method names
- Be descriptive and avoid single-letter names (except for counters)

```dart
// Good
final userName = 'John';
void fetchUserData() {}
int calculateTotalPrice(List<Product> products) {}

// Bad
final un = 'John';
void getData() {}
int calc(List<Product> p) {}
```

#### Constants

- Use `lowerCamelCase` for constants
- Use `k` prefix for global constants (optional)

```dart
// Good
const int maxLoginAttempts = 3;
const String apiBaseUrl = 'https://api.example.com';

// Also acceptable for global constants
const kMaxLoginAttempts = 3;
const kApiBaseUrl = 'https://api.example.com';
```

#### Private Members

- Use underscore prefix for private members

```dart
// Good
class UserService {
  final AuthRepository _authRepository;
  final String _apiKey;
  
  void _handleError(Exception error) {
    // ...
  }
}
```

#### Acronyms

- Treat acronyms as words in names

```dart
// Good
class HttpClient {}
String parseJson(String jsonString) {}
final userId = 'user123';

// Bad
class HTTPClient {}
String parseJSON(String JSONString) {}
final userID = 'user123';
```

### File Organization

#### File Naming

- Use `snake_case` for file names
- Match file names to the primary class/function they contain
- Use descriptive names that indicate the file's purpose

```
// Good
user_repository.dart
auth_bloc.dart
login_page.dart

// Bad
repository.dart
bloc.dart
page.dart
```

#### Directory Structure

Follow the project's established directory structure:

```
lib/
├── core/                    # Core functionality
│   ├── config/             # Configuration
│   ├── constants/          # Constants
│   ├── di/                 # Dependency injection
│   ├── error/              # Error handling
│   ├── network/            # Network layer
│   ├── router/             # Routing
│   ├── storage/            # Storage
│   ├── theme/              # Theming
│   ├── utils/              # Utilities
│   └── widgets/            # Common widgets
├── features/               # Feature modules
│   ├── auth/               # Authentication feature
│   │   ├── data/           # Data layer
│   │   ├── domain/         # Domain layer
│   │   └── presentation/   # Presentation layer
│   ├── home/               # Home feature
│   └── ...                 # Other features
└── main.dart               # Application entry point
```

#### Import Ordering

Order imports as follows:

1. Dart SDK imports
2. Flutter imports
3. Third-party package imports
4. Project imports (absolute)
5. Project imports (relative)

Add a blank line between each section:

```dart
// Dart imports
import 'dart:async';
import 'dart:convert';

// Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Third-party imports
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:dartz/dartz.dart';

// Project imports (absolute)
import 'package:spb/core/error/failures.dart';
import 'package:spb/core/utils/logger.dart';

// Project imports (relative)
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
```

### Code Formatting

#### Indentation and Line Length

- Use 2 spaces for indentation
- Limit lines to 80 characters where possible
- Break long lines at logical points

```dart
// Good
void someFunction(
  String param1,
  String param2,
  String param3,
) {
  // Function body
}

// Bad
void someFunction(String param1, String param2, String param3) {
  // Function body
}
```

#### Trailing Commas

- Use trailing commas for multi-line parameter lists, collections, and arguments
- This improves version control diffs and makes formatting consistent

```dart
// Good
final list = [
  'item1',
  'item2',
  'item3',
];

void someFunction({
  required String param1,
  required String param2,
  String? param3,
}) {
  // Function body
}

// Bad
final list = [
  'item1',
  'item2',
  'item3'
];

void someFunction({
  required String param1,
  required String param2,
  String? param3
}) {
  // Function body
}
```

#### Braces and Spaces

- Use braces for all control structures, even single-line statements
- Add spaces around operators and after commas

```dart
// Good
if (condition) {
  doSomething();
}

final sum = a + b;
final list = [1, 2, 3];

// Bad
if (condition) doSomething();

final sum=a+b;
final list=[1,2,3];
```

### Documentation

#### Class and Function Documentation

- Document all public APIs using dartdoc comments
- Include parameter descriptions and return values
- Note any side effects or important considerations

```dart
/// A service that manages user authentication.
///
/// This service handles user login, logout, and token management.
class AuthService {
  /// Authenticates a user with username and password.
  ///
  /// Returns a [Future] that completes with [AuthResult] containing
  /// the authentication result and user information if successful.
  ///
  /// Throws [AuthException] if authentication fails.
  ///
  /// Parameters:
  /// - [userName]: The user's username
  /// - [password]: The user's password
  Future<AuthResult> login(String userName, String password) async {
    // Implementation
  }
}
```

#### TODO Comments

- Mark incomplete code with `TODO` comments
- Include your name/identifier and a description of what needs to be done
- Consider adding a ticket/issue reference

```dart
// TODO(dev): Implement token refresh logic - ISSUE-123
```

### Code Organization

#### Class Structure

Organize class members in the following order:

1. Static constants and properties
2. Instance variables
3. Constructors
4. Factory methods
5. Getters and setters
6. Public methods
7. Private methods
8. Overridden methods (e.g., `dispose`, `build`)

```dart
class UserBloc extends Bloc<UserEvent, UserState> {
  // 1. Static constants and properties
  static const int maxRetries = 3;
  
  // 2. Instance variables
  final UserRepository _userRepository;
  final AuthService _authService;
  
  // 3. Constructors
  UserBloc({
    required UserRepository userRepository,
    required AuthService authService,
  }) : 
    _userRepository = userRepository,
    _authService = authService,
    super(UserInitial()) {
    on<UserLoadRequested>(_onUserLoadRequested);
    on<UserUpdateRequested>(_onUserUpdateRequested);
  }
  
  // 4. Factory methods
  factory UserBloc.fromRepository(UserRepository repository) {
    return UserBloc(
      userRepository: repository,
      authService: getIt<AuthService>(),
    );
  }
  
  // 5. Getters and setters
  bool get isUserLoaded => state is UserLoaded;
  
  // 6. Public methods
  Future<void> refreshUser() async {
    // Implementation
  }
  
  // 7. Private methods
  Future<void> _onUserLoadRequested(
    UserLoadRequested event,
    Emitter<UserState> emit,
  ) async {
    // Implementation
  }
  
  Future<void> _onUserUpdateRequested(
    UserUpdateRequested event,
    Emitter<UserState> emit,
  ) async {
    // Implementation
  }
  
  // 8. Overridden methods
  @override
  Future<void> close() {
    // Cleanup
    return super.close();
  }
}
```

#### Method Organization

- Keep methods focused on a single responsibility
- Limit method length (aim for under 30 lines)
- Extract complex logic into helper methods
- Use meaningful method names that describe what they do

```dart
// Good
Future<void> loginUser(String userName, String password) async {
  if (!_validateCredentials(userName, password)) {
    throw ValidationException('Invalid credentials');
  }
  
  final result = await _authRepository.login(userName, password);
  await _handleLoginResult(result);
}

bool _validateCredentials(String userName, String password) {
  return userName.isNotEmpty && password.length >= 8;
}

Future<void> _handleLoginResult(AuthResult result) async {
  // Handle result
}

// Bad
Future<void> login(String u, String p) async {
  // 50+ lines of mixed validation, API calls, and result handling
}
```

### Error Handling

#### Exception Handling

- Use specific exception types
- Handle exceptions at appropriate levels
- Provide meaningful error messages

```dart
// Good
try {
  await userRepository.updateProfile(user);
} on NetworkException catch (e) {
  AppLogger.error('Network error during profile update', e);
  return Left(NetworkFailure('Failed to update profile: ${e.message}'));
} on ValidationException catch (e) {
  AppLogger.warning('Validation error during profile update', e);
  return Left(ValidationFailure(e.message));
} catch (e, stackTrace) {
  AppLogger.error('Unexpected error during profile update', e, stackTrace);
  return Left(ServerFailure('An unexpected error occurred'));
}

// Bad
try {
  await userRepository.updateProfile(user);
} catch (e) {
  return Left(Failure('Error'));
}
```

#### Result Types

- Use `Either<Failure, Success>` from `dartz` for operation results
- Return specific failure types
- Handle all possible failure cases

```dart
// Good
Future<Either<Failure, User>> getUserProfile() async {
  try {
    final user = await userRemoteDataSource.getProfile();
    return Right(user);
  } on NetworkException catch (e) {
    return Left(NetworkFailure(e.message));
  } on AuthException catch (e) {
    return Left(AuthFailure(e.message));
  } catch (e) {
    return Left(ServerFailure('Failed to get user profile'));
  }
}

// Usage
final result = await getUserProfile();
result.fold(
  (failure) => handleFailure(failure),
  (user) => displayUser(user),
);
```

### Asynchronous Code

#### Async/Await

- Prefer `async`/`await` over raw `Future` callbacks
- Use consistent error handling with try/catch
- Properly chain async operations

```dart
// Good
Future<void> loadUserData() async {
  try {
    final userId = await authRepository.getCurrentUserId();
    final userData = await userRepository.getUserData(userId);
    emit(UserLoaded(userData));
  } catch (e) {
    emit(UserError('Failed to load user data'));
  }
}

// Bad
void loadUserData() {
  authRepository.getCurrentUserId().then((userId) {
    userRepository.getUserData(userId).then((userData) {
      emit(UserLoaded(userData));
    }).catchError((e) {
      emit(UserError('Failed to load user data'));
    });
  }).catchError((e) {
    emit(UserError('Failed to get user ID'));
  });
}
```

#### Stream Handling

- Properly close streams in `dispose` methods
- Use `StreamSubscription` for managing subscriptions
- Consider using `StreamBuilder` for UI updates

```dart
// Good
class UserProfileBloc {
  final _userController = StreamController<User>();
  late final StreamSubscription<User> _userSubscription;
  
  UserProfileBloc(UserRepository repository) {
    _userSubscription = repository.userStream.listen((user) {
      _userController.add(user);
    });
  }
  
  void dispose() {
    _userSubscription.cancel();
    _userController.close();
  }
}
```

### State Management

#### BLoC Pattern

- Follow the BLoC pattern for state management
- Keep BLoCs focused on a single feature
- Use events for user actions and state for UI representation

```dart
// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  
  @override
  List<Object> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String userName;
  final String password;
  
  const AuthLoginRequested({
    required this.userName,
    required this.password,
  });
  
  @override
  List<Object> get props => [userName, password];
}

// States
abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final User user;
  
  const AuthAuthenticated({required this.user});
  
  @override
  List<Object> get props => [user];
}
```

#### State Immutability

- Make state classes immutable
- Use `copyWith` methods for state updates
- Use `Equatable` for equality comparisons

```dart
class User extends Equatable {
  final String id;
  final String userName;
  final String email;
  final String name;
  
  const User({
    required this.id,
    required this.userName,
    required this.email,
    required this.name,
  });
  
  User copyWith({
    String? id,
    String? userName,
    String? email,
    String? name,
  }) {
    return User(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      name: name ?? this.name,
    );
  }
  
  @override
  List<Object> get props => [id, userName, email, name];
}
```

### UI Guidelines

#### Widget Structure

- Keep widget methods small and focused
- Extract reusable widgets
- Use `const` constructors when possible
- Follow a consistent widget structure

```dart
class ProfileCard extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;
  
  const ProfileCard({
    super.key,
    required this.user,
    required this.onEdit,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAvatar(),
            const SizedBox(height: 16),
            _buildUserInfo(),
            const SizedBox(height: 16),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 50,
      backgroundImage: user.avatar != null
          ? NetworkImage(user.avatar!)
          : null,
      child: user.avatar == null
          ? Text(user.name[0].toUpperCase())
          : null,
    );
  }
  
  Widget _buildUserInfo() {
    return Column(
      children: [
        Text(
          user.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(user.email),
      ],
    );
  }
  
  Widget _buildActionButton() {
    return ElevatedButton(
      onPressed: onEdit,
      child: const Text('Edit Profile'),
    );
  }
}
```

#### Responsive Design

- Use flexible layouts
- Avoid hardcoded dimensions
- Test on multiple screen sizes
- Use MediaQuery for screen-aware layouts

```dart
// Good
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  
  return Padding(
    padding: const EdgeInsets.all(16),
    child: screenWidth > 600
        ? _buildWideLayout()
        : _buildNarrowLayout(),
  );
}

// Bad
Widget build(BuildContext context) {
  return Container(
    width: 350,
    child: _buildLayout(),
  );
}
```

#### Theme Usage

- Use theme colors and text styles
- Avoid hardcoded colors and styles
- Access theme using `Theme.of(context)`

```dart
// Good
Text(
  'Welcome',
  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
    fontWeight: FontWeight.bold,
  ),
)

// Bad
Text(
  'Welcome',
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.blue,
  ),
)
```

### Performance Considerations

#### Memory Management

- Dispose controllers and streams
- Use `const` constructors
- Avoid unnecessary rebuilds
- Use lazy loading for expensive operations

```dart
// Good
class MyWidget extends StatefulWidget {
  const MyWidget({super.key});
  
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final TextEditingController _controller = TextEditingController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  // Rest of implementation
}
```

#### Efficient Lists

- Use `ListView.builder` for long lists
- Implement pagination for large datasets
- Use keys for dynamic lists
- Consider using `const` widgets for static items

```dart
// Good
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return ListTile(
      key: ValueKey(item.id),
      title: Text(item.title),
      subtitle: Text(item.description),
    );
  },
)

// Bad
ListView(
  children: items.map((item) => ListTile(
    title: Text(item.title),
    subtitle: Text(item.description),
  )).toList(),
)
```

#### Image Optimization

- Use `CachedNetworkImage` for network images
- Specify image dimensions
- Use appropriate image formats
- Consider using asset images for static content

```dart
// Good
CachedNetworkImage(
  imageUrl: user.avatarUrl,
  width: 100,
  height: 100,
  fit: BoxFit.cover,
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
)

// Bad
Image.network(user.avatarUrl)
```

## Flutter-Specific Guidelines

### StatelessWidget vs StatefulWidget

- Use `StatelessWidget` for UI components without internal state
- Use `StatefulWidget` only when necessary for internal state management
- Consider using BLoC for complex state management

```dart
// Good - Stateless widget for presentation
class UserCard extends StatelessWidget {
  final User user;
  
  const UserCard({super.key, required this.user});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(user.name),
        subtitle: Text(user.email),
      ),
    );
  }
}

// Good - Stateful widget when internal state is needed
class CounterWidget extends StatefulWidget {
  const CounterWidget({super.key});
  
  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget> {
  int _counter = 0;
  
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Count: $_counter'),
        ElevatedButton(
          onPressed: _incrementCounter,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

### BLoC Usage

- Use BLoC for complex state management
- Keep BLoCs focused on a single feature
- Use events for user actions
- Use states for UI representation

```dart
// BLoC implementation
class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterState(count: 0)) {
    on<CounterIncremented>(_onIncremented);
    on<CounterDecremented>(_onDecremented);
    on<CounterReset>(_onReset);
  }
  
  void _onIncremented(CounterIncremented event, Emitter<CounterState> emit) {
    emit(CounterState(count: state.count + 1));
  }
  
  void _onDecremented(CounterDecremented event, Emitter<CounterState> emit) {
    emit(CounterState(count: state.count - 1));
  }
  
  void _onReset(CounterReset event, Emitter<CounterState> emit) {
    emit(const CounterState(count: 0));
  }
}

// BLoC usage in UI
class CounterPage extends StatelessWidget {
  const CounterPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CounterBloc(),
      child: const CounterView(),
    );
  }
}

class CounterView extends StatelessWidget {
  const CounterView({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: BlocBuilder<CounterBloc, CounterState>(
          builder: (context, state) {
            return Text(
              'Count: ${state.count}',
              style: Theme.of(context).textTheme.headlineMedium,
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => context.read<CounterBloc>().add(
              const CounterIncremented(),
            ),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => context.read<CounterBloc>().add(
              const CounterDecremented(),
            ),
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
```

### Dependency Injection

- Use GetIt for dependency injection
- Register dependencies in a centralized location
- Use lazy singletons for services
- Use factories for BLoCs

```dart
// Dependency registration
final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  
  // Services
  getIt.registerLazySingleton<AuthService>(
    () => AuthServiceImpl(getIt<HttpClient>()),
  );
  
  // Repositories
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(
      remoteDataSource: getIt<UserRemoteDataSource>(),
      localDataSource: getIt<UserLocalDataSource>(),
    ),
  );
  
  // BLoCs
  getIt.registerFactory(
    () => UserBloc(getIt<UserRepository>()),
  );
}

// Dependency usage
final userRepository = getIt<UserRepository>();
```

### Navigation

- Use GoRouter for navigation
- Define routes in a central location
- Use named routes for better maintainability
- Handle deep links properly

```dart
// Route definition
final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
  ],
);

// Navigation usage
context.go('/home');
context.goNamed('profile', params: {'id': '123'});
```

## Code Review Checklist

### General

- [ ] Code follows the style guide
- [ ] No hardcoded strings (use constants)
- [ ] No magic numbers (use constants)
- [ ] No commented-out code
- [ ] No debug print statements
- [ ] No TODO comments without tickets
- [ ] Proper error handling

### Architecture

- [ ] Follows clean architecture principles
- [ ] Proper separation of concerns
- [ ] Dependencies flow in the correct direction
- [ ] Uses appropriate design patterns

### Performance

- [ ] No unnecessary rebuilds
- [ ] Efficient list rendering
- [ ] Proper resource disposal
- [ ] No memory leaks
- [ ] Optimized image loading

### Security

- [ ] No sensitive data in code
- [ ] Proper input validation
- [ ] Secure API communication
- [ ] Proper error handling without leaking information

### Testing

- [ ] Unit tests for business logic
- [ ] Widget tests for UI components
- [ ] Integration tests for user flows
- [ ] Mocks for external dependencies

## Tools and Automation

### Formatting

Use `flutter format` to automatically format code:

```bash
# Format a specific file
flutter format lib/main.dart

# Format all files
flutter format lib/
```

### Linting

Use `flutter analyze` to check for linting issues:

```bash
# Analyze the entire project
flutter analyze

# Analyze a specific file
flutter analyze lib/main.dart
```

### Custom Lint Rules

Create `analysis_options.yaml` with custom rules:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # Error rules
    always_use_package_imports: true
    avoid_empty_else: true
    avoid_relative_lib_imports: true
    avoid_returning_null_for_future: true
    avoid_slow_async_io: true
    avoid_types_as_parameter_names: true
    cancel_subscriptions: true
    close_sinks: true
    comment_references: true
    
    # Style rules
    always_declare_return_types: true
    always_put_control_body_on_new_line: true
    always_put_required_named_parameters_first: true
    always_require_non_null_named_parameters: true
    avoid_bool_literals_in_conditional_expressions: true
    avoid_catches_without_on_clauses: true
    avoid_catching_errors: true
    avoid_classes_with_only_static_members: true
    avoid_double_and_int_checks: true
    avoid_dynamic_calls: true
    avoid_equals_and_hash_code_on_mutable_classes: true
    avoid_field_initializers_in_const_classes: true
    avoid_function_literals_in_foreach_calls: true
    avoid_implementing_value_types: true
    avoid_js_rounded_ints: true
    avoid_multiple_declarations_per_line: true
    avoid_positional_boolean_parameters: true
    avoid_private_typedef_functions: true
    avoid_redundant_argument_values: true
    avoid_renaming_method_parameters: true
    avoid_return_types_on_setters: true
    avoid_returning_null: true
    avoid_returning_this: true
    avoid_setters_without_getters: true
    avoid_single_cascade_in_expression_statements: true
    avoid_unnecessary_containers: true
    avoid_unused_constructor_parameters: true
    avoid_void_async: true
    await_only_futures: true
    camel_case_extensions: true
    camel_case_types: true
    cascade_invocations: true
    cast_nullable_to_non_nullable: true
    constant_identifier_names: true
    curly_braces_in_flow_control_structures: true
    deprecated_consistency: true
    directives_ordering: true
    do_not_use_environment: true
    empty_catches: true
    empty_constructor_bodies: true
    empty_statements: true
    eol_at_end_of_file: true
    exhaustive_cases: true
    file_names: true
    implementation_imports: true
    join_return_with_assignment: true
    leading_newlines_in_multiline_strings: true
    library_names: true
    library_prefixes: true
    lines_longer_than_80_chars: true
    missing_whitespace_between_adjacent_strings: true
    no_adjacent_strings_in_list: true
    no_default_cases: true
    no_duplicate_case_values: true
    no_logic_in_create_state: true
    no_runtimeType_toString: true
    non_constant_identifier_names: true
    null_check_on_nullable_type_parameter: true
    null_closures: true
    omit_local_variable_types: true
    one_member_abstracts: true
    only_throw_errors: true
    overridden_fields: true
    package_api_docs: true
    package_prefixed_library_names: true
    parameter_assignments: true
    prefer_adjacent_string_concatenation: true
    prefer_asserts_in_initializer_lists: true
    prefer_asserts_with_message: true
    prefer_collection_literals: true
    prefer_conditional_assignment: true
    prefer_const_constructors: true
    prefer_const_constructors_in_immutables: true
    prefer_const_declarations: true
    prefer_const_literals_to_create_immutables: true
    prefer_constructors_over_static_methods: true
    prefer_contains: true
    prefer_equal_for_default_values: true
    prefer_expression_function_bodies: true
    prefer_final_fields: true
    prefer_final_in_for_each: true
    prefer_final_locals: true
    prefer_for_elements_to_map_fromIterable: true
    prefer_foreach: true
    prefer_function_declarations_over_variables: true
    prefer_generic_function_type_aliases: true
    prefer_if_elements_to_conditional_expressions: true
    prefer_if_null_operators: true
    prefer_initializing_formals: true
    prefer_inlined_adds: true
    prefer_int_literals: true
    prefer_interpolation_to_compose_strings: true
    prefer_is_empty: true
    prefer_is_not_empty: true
    prefer_is_not_operator: true
    prefer_iterable_whereType: true
    prefer_mixin: true
    prefer_null_aware_operators: true
    prefer_relative_imports: false
    prefer_single_quotes: true
    prefer_spread_collections: true
    prefer_typing_uninitialized_variables: true
    prefer_void_to_null: true
    provide_deprecation_message: true
    public_member_api_docs: false
    recursive_getters: true
    sized_box_for_whitespace: true
    slash_for_doc_comments: true
    sort_child_properties_last: true
    sort_constructors_first: true
    sort_pub_dependencies: true
    sort_unnamed_constructors_first: true
    tighten_type_of_initializing_formals: true
    type_annotate_public_apis: true
    type_init_formals: true
    unawaited_futures: true
    unnecessary_await_in_return: true
    unnecessary_brace_in_string_interps: true
    unnecessary_const: true
    unnecessary_constructor_name: true
    unnecessary_getters_setters: true
    unnecessary_lambdas: true
    unnecessary_late: true
    unnecessary_new: true
    unnecessary_null_aware_assignments: true
    unnecessary_null_checks: true
    unnecessary_null_in_if_null_operators: true
    unnecessary_nullable_for_final_variable_declarations: true
    unnecessary_overrides: true
    unnecessary_parenthesis: true
    unnecessary_raw_strings: true
    unnecessary_string_escapes: true
    unnecessary_string_interpolations: true
    unnecessary_this: true
    use_build_context_synchronously: true
    use_full_hex_values_for_flutter_colors: true
    use_function_type_syntax_for_parameters: true
    use_if_null_to_convert_nulls_to_bools: true
    use_is_even_rather_than_modulo: true
    use_key_in_widget_constructors: true
    use_late_for_private_fields_and_variables: true
    use_named_constants: true
    use_raw_strings: true
    use_rethrow_when_possible: true
    use_setters_to_change_properties: true
    use_string_buffers: true
    use_test_throws_matchers: true
    void_checks: true
```

### Pre-commit Hooks

Use `git_hooks` to enforce code quality:

```yaml
# pubspec.yaml
dev_dependencies:
  git_hooks: ^1.0.0

# In your project root, create .git_hooks.dart
import 'package:git_hooks/git_hooks.dart';

void main(List<String> arguments) {
  GitHooks.run(arguments, hooks: {
    GitHookType.preCommit: preCommitHook,
  });
}

Future<bool> preCommitHook() async {
  // Run formatter
  final formatResult = await Process.run('flutter', ['format', '--set-exit-if-changed', 'lib', 'test']);
  if (formatResult.exitCode != 0) {
    print('❌ Flutter format check failed. Run "flutter format lib test" to fix.');
    return false;
  }
  
  // Run analyzer
  final analyzeResult = await Process.run('flutter', ['analyze']);
  if (analyzeResult.exitCode != 0) {
    print('❌ Flutter analyze failed. Fix the issues before committing.');
    return false;
  }
  
  // Run tests
  final testResult = await Process.run('flutter', ['test']);
  if (testResult.exitCode != 0) {
    print('❌ Tests failed. Fix the failing tests before committing.');
    return false;
  }
  
  return true;
}
```

## Examples

### Good Code Example

```dart
/// Repository for managing user data.
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;
  final UserLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  const UserRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Gets the current user profile.
  ///
  /// Returns [User] if successful, [Failure] otherwise.
  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    if (await networkInfo.isConnected) {
      try {
        final remoteUser = await remoteDataSource.getCurrentUser();
        await localDataSource.cacheUser(remoteUser);
        return Right(remoteUser);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      } on NetworkException catch (e) {
        return _getLocalUser();
      }
    } else {
      return _getLocalUser();
    }
  }

  /// Gets the user from local cache.
  Future<Either<Failure, User>> _getLocalUser() async {
    try {
      final localUser = await localDataSource.getLastUser();
      return Right(localUser);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
```

### Bad Code Example (With Improvements)

```dart
// Bad code
class userRepo {
  var remote;
  var local;
  var net;
  
  userRepo(this.remote, this.local, this.net);
  
  getUser() async {
    try {
      if (await net.isConnected) {
        var data = await remote.getUser();
        await local.saveUser(data);
        return data;
      } else {
        try {
          var data = await local.getUser();
          return data;
        } catch (e) {
          return null;
        }
      }
    } catch (e) {
      print("Error: $e");
      return null;
    }
  }
}

// Improved version
class UserRepository {
  final RemoteDataSource remoteDataSource;
  final LocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  
  const UserRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });
  
  Future<Either<Failure, User>> getUser() async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.getUser();
        await localDataSource.cacheUser(user);
        return Right(user);
      } catch (e) {
        return _getLocalUser();
      }
    } else {
      return _getLocalUser();
    }
  }
  
  Future<Either<Failure, User>> _getLocalUser() async {
    try {
      final user = await localDataSource.getLastUser();
      return Right(user);
    } on CacheException {
      return const Left(CacheFailure('No cached user found'));
    }
  }
}
```

## Resources

### Official Style Guides

- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Flutter Style Guide](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo)
- [Material Design Guidelines](https://material.io/design)

### Tools

- [Dart Formatter](https://dart.dev/tools/dart-format)
- [Dart Analyzer](https://dart.dev/tools/dart-analyze)
- [Flutter Lints](https://pub.dev/packages/flutter_lints)
- [Custom Lint](https://pub.dev/packages/custom_lint)

### Recommended Reading

- [Clean Code by Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [Clean Architecture by Robert C. Martin](https://www.amazon.com/Clean-Architecture-Craftsmans-Software-Structure/dp/0134494164)
- [Flutter Clean Architecture](https://resocoder.com/flutter-clean-architecture-tdd/)