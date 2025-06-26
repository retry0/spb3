# Troubleshooting Guide

## Overview

This guide provides solutions for common issues encountered when developing, deploying, or using the SPB Secure Flutter application. It covers authentication problems, network issues, database errors, UI glitches, and platform-specific challenges.

## Table of Contents

- [Authentication Issues](#authentication-issues)
- [Network Problems](#network-problems)
- [Database Errors](#database-errors)
- [UI and Rendering Issues](#ui-and-rendering-issues)
- [State Management Problems](#state-management-problems)
- [Performance Issues](#performance-issues)
- [Platform-Specific Issues](#platform-specific-issues)
- [Build and Deployment Problems](#build-and-deployment-problems)
- [Environment Configuration Issues](#environment-configuration-issues)
- [Dependency Issues](#dependency-issues)

## Authentication Issues

### JWT Token Problems

#### Issue: "Invalid token" or "Token expired" errors

**Symptoms:**
- User is unexpectedly logged out
- API requests fail with 401 Unauthorized
- "Session expired" messages appear

**Causes:**
- Token has expired
- Token is malformed
- Token was invalidated by the server
- Clock skew between client and server

**Solutions:**

1. **Check token validity:**
   ```dart
   final tokenManager = getIt<JwtTokenManager>();
   final metadata = await tokenManager.getTokenMetadata();
   print('Token valid: ${metadata?['isValid']}');
   print('Expiration: ${metadata?['expirationDate']}');
   ```

2. **Inspect token contents:**
   ```dart
   // Use the debug token page
   Navigator.push(
     context,
     MaterialPageRoute(builder: (context) => const DebugTokenPage()),
   );
   ```

3. **Clear stored tokens and re-authenticate:**
   ```dart
   await tokenManager.clearStoredToken();
   context.read<AuthBloc>().add(const AuthLogoutRequested());
   ```

4. **Check for clock skew:**
   ```dart
   final serverTime = await getServerTime();
   final localTime = DateTime.now();
   final timeDifference = serverTime.difference(localTime);
   print('Time difference: ${timeDifference.inSeconds} seconds');
   ```

### Login Failures

#### Issue: Unable to log in despite correct credentials

**Symptoms:**
- Login attempts fail with "Invalid credentials"
- No specific error message is shown
- Login button seems unresponsive

**Causes:**
- Network connectivity issues
- Backend authentication service problems
- Incorrect API endpoint configuration
- Input validation issues

**Solutions:**

1. **Check network connectivity:**
   ```dart
   final connectivityResult = await Connectivity().checkConnectivity();
   print('Connectivity: $connectivityResult');
   ```

2. **Verify API endpoint configuration:**
   ```dart
   print('API base URL: ${EnvironmentConfig.baseUrl}');
   print('Login endpoint: ${ApiEndpoints.login}');
   ```

3. **Test API directly:**
   ```bash
   # Using curl
   curl -X POST "http://10.0.2.2:8097/v1/Account/LoginUser" \
     -H "Content-Type: application/json" \
     -d '{"userName":"test_user","password":"password123"}'
   ```

4. **Enable detailed logging:**
   ```dart
   // In main.dart before runApp()
   if (kDebugMode) {
     Dio.enableLogging = true;
   }
   ```

5. **Check username format:**
   ```dart
   final validationError = UserNameValidator.validateFormat(userName);
   if (validationError != null) {
     print('Username validation error: $validationError');
   }
   ```

### Session Management Issues

#### Issue: Frequent session timeouts or unexpected logouts

**Symptoms:**
- User is logged out unexpectedly
- Session expires too quickly
- "Session expired" message appears frequently

**Causes:**
- Short token expiration time
- Token not being properly stored
- Background app refresh issues
- Memory management problems

**Solutions:**

1. **Check token expiration time:**
   ```dart
   final token = await secureStorage.read(StorageKeys.accessToken);
   if (token != null) {
     final decodedToken = JwtDecoder.decode(token);
     final expiresAt = DateTime.fromMillisecondsSinceEpoch(decodedToken['exp'] * 1000);
     final now = DateTime.now();
     print('Token expires in: ${expiresAt.difference(now).inMinutes} minutes');
   }
   ```

2. **Verify token storage:**
   ```dart
   final token = await secureStorage.read(StorageKeys.accessToken);
   print('Token exists: ${token != null}');
   ```

3. **Implement token refresh logic:**
   ```dart
   // Check token validity before API calls
   if (await tokenManager.isTokenExpiringSoon()) {
     // Refresh token or redirect to login
   }
   ```

4. **Add session activity tracking:**
   ```dart
   // Update last activity timestamp
   await prefs.setInt('last_activity', DateTime.now().millisecondsSinceEpoch);
   ```

## Network Problems

### Connection Issues

#### Issue: Unable to connect to backend API

**Symptoms:**
- API requests fail with timeout or connection errors
- "No internet connection" errors
- App works on some devices but not others

**Causes:**
- No internet connectivity
- Incorrect API endpoint configuration
- Android emulator localhost issues
- Server is down or unreachable
- Network restrictions or firewalls

**Solutions:**

1. **Run network diagnostics:**
   ```dart
   final diagnostics = await NetworkTroubleshooter.diagnoseNetwork();
   final report = NetworkTroubleshooter.generateTroubleshootingReport(diagnostics);
   print(report);
   ```

2. **Check Android emulator configuration:**
   ```dart
   if (AndroidEmulatorConfig.isAndroidEmulator) {
     print('Running on Android emulator');
     print('Original URL: ${EnvironmentConfig.rawBaseUrl}');
     print('Converted URL: ${EnvironmentConfig.baseUrl}');
   }
   ```

3. **Test API reachability:**
   ```dart
   try {
     final response = await Dio().get('${EnvironmentConfig.baseUrl}/health');
     print('API reachable: ${response.statusCode}');
   } catch (e) {
     print('API unreachable: $e');
   }
   ```

4. **Check DNS resolution:**
   ```dart
   try {
     final uri = Uri.parse(EnvironmentConfig.baseUrl);
     final addresses = await InternetAddress.lookup(uri.host);
     print('Resolved addresses: ${addresses.map((a) => a.address).join(', ')}');
   } catch (e) {
     print('DNS resolution failed: $e');
   }
   ```

5. **For Android emulator issues:**
   ```bash
   # Test from host machine
   curl http://localhost:8000/health
   
   # Test from emulator
   adb shell
   curl http://10.0.2.2:8000/health
   ```

### API Response Errors

#### Issue: Unexpected API response formats or errors

**Symptoms:**
- "Failed to parse response" errors
- Type errors when processing API data
- Missing fields in API responses

**Causes:**
- API contract changes
- Incorrect model definitions
- Backend errors
- Version mismatches

**Solutions:**

1. **Inspect raw API response:**
   ```dart
   try {
     final dio = Dio();
     dio.interceptors.add(LogInterceptor(responseBody: true));
     final response = await dio.get('${EnvironmentConfig.baseUrl}/endpoint');
     print('Raw response: ${response.data}');
   } catch (e) {
     print('API error: $e');
   }
   ```

2. **Verify model definitions:**
   ```dart
   // Check if model matches API response
   final jsonData = jsonDecode(responseString);
   try {
     final model = MyModel.fromJson(jsonData);
     print('Model parsed successfully: $model');
   } catch (e) {
     print('Model parsing failed: $e');
     print('Expected format: ${MyModel.fromJson({}).toJson()}');
     print('Actual data: $jsonData');
   }
   ```

3. **Add more robust error handling:**
   ```dart
   try {
     final response = await dio.get('/endpoint');
     if (response.data is Map<String, dynamic>) {
       return MyModel.fromJson(response.data);
     } else {
       throw FormatException('Unexpected response format: ${response.data.runtimeType}');
     }
   } catch (e) {
     AppLogger.error('API error', e);
     throw ServerException('Failed to process API response');
   }
   ```

4. **Check API version compatibility:**
   ```dart
   // Add API version header
   dio.options.headers['X-API-Version'] = '1.0';
   
   // Check version in response
   final apiVersion = response.headers.value('X-API-Version');
   if (apiVersion != '1.0') {
     AppLogger.warning('API version mismatch: expected 1.0, got $apiVersion');
   }
   ```

### SSL/TLS Issues

#### Issue: SSL certificate validation failures

**Symptoms:**
- "Certificate verification failed" errors
- API requests fail on some devices but work on others
- HTTPS requests fail but HTTP works

**Causes:**
- Self-signed or invalid certificates
- Certificate chain issues
- Certificate pinning misconfigurations
- System time issues

**Solutions:**

1. **Verify certificate validity:**
   ```bash
   # Using OpenSSL
   openssl s_client -connect api.example.com:443 -servername api.example.com
   ```

2. **Check certificate pinning configuration:**
   ```dart
   // Review certificate pinning setup
   final allowedFingerprints = [
     'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
     'SHA256:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
   ];
   
   // Ensure fingerprints match the server's certificate
   ```

3. **Temporarily disable certificate validation (DEVELOPMENT ONLY):**
   ```dart
   // NEVER USE IN PRODUCTION
   if (EnvironmentConfig.isDevelopment) {
     dio.httpClientAdapter = IOHttpClientAdapter(
       createHttpClient: () {
         final client = HttpClient();
         client.badCertificateCallback = (cert, host, port) => true;
         return client;
       },
     );
   }
   ```

4. **Check system time:**
   ```dart
   final now = DateTime.now();
   print('System time: $now');
   // Ensure device time is correct
   ```

## Database Errors

### SQLite Issues

#### Issue: Database migration failures or schema errors

**Symptoms:**
- "Database schema version mismatch" errors
- "Table doesn't exist" errors
- App crashes on startup or when accessing certain features

**Causes:**
- Failed migrations
- Schema changes without proper migration
- Database corruption
- Concurrent database access

**Solutions:**

1. **Check database version:**
   ```dart
   final db = await DatabaseHelper.instance.database;
   final result = await db.rawQuery('PRAGMA user_version');
   print('Database version: ${result.first['user_version']}');
   ```

2. **Inspect database schema:**
   ```dart
   final db = await DatabaseHelper.instance.database;
   final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
   print('Tables: ${tables.map((t) => t['name']).join(', ')}');
   
   // Check specific table schema
   final tableInfo = await db.rawQuery("PRAGMA table_info(users)");
   print('Users table columns: $tableInfo');
   ```

3. **Reset database (development only):**
   ```dart
   // CAUTION: This will delete all data
   final dbHelper = DatabaseHelper.instance;
   await dbHelper.clearAllData();
   
   // Or delete the database file
   final dbPath = await getDatabasesPath();
   final path = join(dbPath, 'spb_secure.db');
   await deleteDatabase(path);
   ```

4. **Add robust migration handling:**
   ```dart
   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
     AppLogger.info('Upgrading database from $oldVersion to $newVersion');
     
     try {
       if (oldVersion < 2) {
         await _migrateToV2(db);
       }
       
       if (oldVersion < 3) {
         await _migrateToV3(db);
       }
     } catch (e) {
       AppLogger.error('Migration failed', e);
       // Implement fallback strategy
     }
   }
   ```

### Data Synchronization Issues

#### Issue: Data not syncing between local and remote

**Symptoms:**
- Local changes not appearing on other devices
- Remote changes not reflected locally
- Sync queue growing without processing

**Causes:**
- Network connectivity issues
- Sync conflicts
- Queue processing failures
- Authentication issues

**Solutions:**

1. **Check sync queue status:**
   ```dart
   final dataRepository = getIt<DataRepository>();
   final pendingItems = await dataRepository.getPendingSyncItems();
   print('Pending sync items: ${pendingItems.length}');
   ```

2. **Force manual sync:**
   ```dart
   final result = await dataRepository.syncPendingData(forceSync: true);
   print('Sync result: $result');
   ```

3. **Inspect sync errors:**
   ```dart
   final failedItems = await dataRepository.getFailedSyncItems();
   for (final item in failedItems) {
     print('Failed item: ${item['record_id']}, Error: ${item['last_error']}');
   }
   ```

4. **Reset sync queue (caution):**
   ```dart
   // This will clear the sync queue without syncing
   final db = await DatabaseHelper.instance.database;
   await db.delete('sync_queue');
   ```

5. **Implement conflict resolution:**
   ```dart
   // Example conflict resolution strategy
   if (localTimestamp > remoteTimestamp) {
     // Local changes are newer, push to server
     await pushLocalChanges();
   } else {
     // Remote changes are newer, update local
     await pullRemoteChanges();
   }
   ```

### Secure Storage Issues

#### Issue: Unable to access or store secure data

**Symptoms:**
- "Failed to read/write secure storage" errors
- Authentication tokens not persisting
- Secure data appears to be lost between sessions

**Causes:**
- Platform-specific secure storage issues
- Permission problems
- Device security policy restrictions
- Keychain/keystore corruption

**Solutions:**

1. **Check secure storage availability:**
   ```dart
   try {
     await secureStorage.write(key: 'test_key', value: 'test_value');
     final value = await secureStorage.read(key: 'test_key');
     print('Secure storage working: ${value == 'test_value'}');
     await secureStorage.delete(key: 'test_key');
   } catch (e) {
     print('Secure storage error: $e');
   }
   ```

2. **Implement fallback storage:**
   ```dart
   Future<void> saveToken(String token) async {
     try {
       await secureStorage.write(key: StorageKeys.accessToken, value: token);
     } catch (e) {
       AppLogger.error('Failed to save token to secure storage', e);
       // Fallback to less secure storage with encryption
       final encryptedToken = encryptData(token);
       await prefs.setString('encrypted_token', encryptedToken);
     }
   }
   ```

3. **Reset secure storage:**
   ```dart
   try {
     await secureStorage.deleteAll();
     print('Secure storage reset successfully');
   } catch (e) {
     print('Failed to reset secure storage: $e');
   }
   ```

4. **Platform-specific troubleshooting:**
   
   **Android:**
   ```dart
   // Check if using EncryptedSharedPreferences
   final androidOptions = const AndroidOptions(
     encryptedSharedPreferences: true,
   );
   final secureStorage = FlutterSecureStorage(aOptions: androidOptions);
   ```
   
   **iOS:**
   ```dart
   // Check Keychain accessibility
   final iOSOptions = const IOSOptions(
     accessibility: KeychainAccessibility.first_unlock_this_device,
   );
   final secureStorage = FlutterSecureStorage(iOptions: iOSOptions);
   ```

## UI and Rendering Issues

### Layout Problems

#### Issue: UI elements misaligned or overflowing

**Symptoms:**
- "Bottom overflowed by X pixels" errors
- UI elements cut off or misaligned
- Yellow/black overflow warning stripes

**Causes:**
- Inflexible layouts
- Hardcoded dimensions
- Missing constraints
- Text overflow

**Solutions:**

1. **Use debug painting to visualize layout:**
   ```dart
   // In main.dart
   void main() {
     debugPaintSizeEnabled = true;
     runApp(const MyApp());
   }
   ```

2. **Wrap problematic widgets with flexible containers:**
   ```dart
   // Instead of fixed height
   Container(
     height: 200,
     child: myWidget,
   )
   
   // Use flexible constraints
   Flexible(
     child: myWidget,
   )
   ```

3. **Handle text overflow:**
   ```dart
   Text(
     longText,
     overflow: TextOverflow.ellipsis,
     maxLines: 2,
   )
   ```

4. **Use MediaQuery for responsive layouts:**
   ```dart
   final screenWidth = MediaQuery.of(context).size.width;
   final screenHeight = MediaQuery.of(context).size.height;
   
   return screenWidth > 600
       ? _buildWideLayout()
       : _buildNarrowLayout();
   ```

5. **Use LayoutBuilder for container-aware sizing:**
   ```dart
   LayoutBuilder(
     builder: (context, constraints) {
       if (constraints.maxWidth < 600) {
         return _buildNarrowLayout();
       } else {
         return _buildWideLayout();
       }
     },
   )
   ```

### Theme and Styling Issues

#### Issue: Inconsistent theming or styling across the app

**Symptoms:**
- Different text styles for similar elements
- Inconsistent colors or spacing
- Theme changes not applying properly

**Causes:**
- Hardcoded styles
- Not using theme data
- Theme not properly propagated
- Missing theme initialization

**Solutions:**

1. **Use theme consistently:**
   ```dart
   // Instead of hardcoded styles
   Text(
     'Title',
     style: TextStyle(
       fontSize: 20,
       fontWeight: FontWeight.bold,
       color: Colors.blue,
     ),
   )
   
   // Use theme
   Text(
     'Title',
     style: Theme.of(context).textTheme.titleLarge,
   )
   ```

2. **Check theme initialization:**
   ```dart
   // In main.dart
   @override
   Widget build(BuildContext context) {
     return BlocBuilder<ThemeBloc, ThemeState>(
       builder: (context, themeState) {
         print('Current theme mode: ${themeState.themeMode}');
         return MaterialApp(
           theme: AppTheme.lightTheme,
           darkTheme: AppTheme.darkTheme,
           themeMode: themeState.themeMode,
           // ...
         );
       },
     );
   }
   ```

3. **Create consistent component library:**
   ```dart
   // Create reusable styled components
   class AppButton extends StatelessWidget {
     final String text;
     final VoidCallback onPressed;
     final bool isLoading;
     
     const AppButton({
       super.key,
       required this.text,
       required this.onPressed,
       this.isLoading = false,
     });
     
     @override
     Widget build(BuildContext context) {
       return ElevatedButton(
         onPressed: isLoading ? null : onPressed,
         style: Theme.of(context).elevatedButtonTheme.style,
         child: isLoading
             ? const SizedBox(
                 width: 20,
                 height: 20,
                 child: CircularProgressIndicator(strokeWidth: 2),
               )
             : Text(text),
       );
     }
   }
   ```

4. **Use theme extensions for custom theme data:**
   ```dart
   // Define custom theme extension
   @immutable
   class AppColors extends ThemeExtension<AppColors> {
     final Color primary;
     final Color secondary;
     final Color error;
     
     const AppColors({
       required this.primary,
       required this.secondary,
       required this.error,
     });
     
     @override
     ThemeExtension<AppColors> copyWith({
       Color? primary,
       Color? secondary,
       Color? error,
     }) {
       return AppColors(
         primary: primary ?? this.primary,
         secondary: secondary ?? this.secondary,
         error: error ?? this.error,
       );
     }
     
     @override
     ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
       if (other is! AppColors) {
         return this;
       }
       return AppColors(
         primary: Color.lerp(primary, other.primary, t)!,
         secondary: Color.lerp(secondary, other.secondary, t)!,
         error: Color.lerp(error, other.error, t)!,
       );
     }
   }
   
   // Add to theme
   final theme = ThemeData(
     // ...
     extensions: [
       const AppColors(
         primary: Colors.blue,
         secondary: Colors.green,
         error: Colors.red,
       ),
     ],
   );
   
   // Use in widgets
   final colors = Theme.of(context).extension<AppColors>()!;
   return Container(color: colors.primary);
   ```

### Animation Issues

#### Issue: Jerky or non-working animations

**Symptoms:**
- Animations stutter or freeze
- Animations don't play at all
- Visual glitches during animations

**Causes:**
- Heavy computation on UI thread
- Improper animation controllers
- Missing dispose calls
- Too many simultaneous animations

**Solutions:**

1. **Check animation controller lifecycle:**
   ```dart
   class _MyAnimatedWidgetState extends State<MyAnimatedWidget> 
       with SingleTickerProviderStateMixin {
     late AnimationController _controller;
     
     @override
     void initState() {
       super.initState();
       _controller = AnimationController(
         vsync: this,
         duration: const Duration(milliseconds: 300),
       );
     }
     
     @override
     void dispose() {
       _controller.dispose(); // Important!
       super.dispose();
     }
   }
   ```

2. **Use simpler built-in animations:**
   ```dart
   // Instead of custom animation
   AnimatedContainer(
     duration: const Duration(milliseconds: 300),
     curve: Curves.easeInOut,
     width: _expanded ? 200 : 100,
     height: _expanded ? 200 : 100,
     color: _expanded ? Colors.blue : Colors.red,
     child: myWidget,
   )
   ```

3. **Offload heavy work:**
   ```dart
   // Instead of doing heavy work in build
   Future<void> _processData() async {
     setState(() => _isLoading = true);
     
     // Run heavy computation in isolate
     final result = await compute(heavyComputation, inputData);
     
     setState(() {
       _result = result;
       _isLoading = false;
     });
   }
   ```

4. **Check for rebuild loops:**
   ```dart
   // Add logging to detect rebuild loops
   @override
   void didUpdateWidget(MyWidget oldWidget) {
     super.didUpdateWidget(oldWidget);
     print('Widget updated: ${DateTime.now().millisecondsSinceEpoch}');
   }
   ```

## State Management Problems

### BLoC Issues

#### Issue: BLoC events not triggering state changes

**Symptoms:**
- UI not updating when events are dispatched
- BLoC state remains unchanged
- No errors in console

**Causes:**
- Event handler not registered
- Event handler not emitting new state
- BLoC not properly provided to widget tree
- State equality preventing updates

**Solutions:**

1. **Check event handler registration:**
   ```dart
   class MyBloc extends Bloc<MyEvent, MyState> {
     MyBloc() : super(const MyInitial()) {
       // Ensure all events have handlers
       on<DataRequested>(_onDataRequested);
       on<DataRefreshed>(_onDataRefreshed);
       on<DataDeleted>(_onDataDeleted);
     }
     
     // Event handlers...
   }
   ```

2. **Verify event handler is emitting state:**
   ```dart
   Future<void> _onDataRequested(
     DataRequested event,
     Emitter<MyState> emit,
   ) async {
     // Make sure to emit new state
     emit(const MyLoading());
     
     try {
       final data = await _repository.getData();
       // Important: emit new state
       emit(MyLoaded(data));
     } catch (e) {
       // Important: emit error state
       emit(MyError('Failed to load data'));
     }
   }
   ```

3. **Check BLoC provider setup:**
   ```dart
   // Ensure BLoC is provided correctly
   BlocProvider(
     create: (context) => getIt<MyBloc>(),
     child: const MyPage(),
   )
   
   // Or for multiple BLoCs
   MultiBlocProvider(
     providers: [
       BlocProvider(create: (context) => getIt<MyBloc>()),
       BlocProvider(create: (context) => getIt<OtherBloc>()),
     ],
     child: const MyPage(),
   )
   ```

4. **Implement BlocObserver for debugging:**
   ```dart
   // In main.dart
   Bloc.observer = AppBlocObserver();
   
   // AppBlocObserver implementation
   class AppBlocObserver extends BlocObserver {
     @override
     void onCreate(BlocBase bloc) {
       super.onCreate(bloc);
       print('onCreate -- ${bloc.runtimeType}');
     }
   
     @override
     void onChange(BlocBase bloc, Change change) {
       super.onChange(bloc, change);
       print('onChange -- ${bloc.runtimeType}, $change');
     }
   
     @override
     void onTransition(Bloc bloc, Transition transition) {
       super.onTransition(bloc, transition);
       print('onTransition -- ${bloc.runtimeType}, $transition');
     }
   
     @override
     void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
       print('onError -- ${bloc.runtimeType}, $error');
       super.onError(bloc, error, stackTrace);
     }
   }
   ```

5. **Check state equality implementation:**
   ```dart
   // Ensure props includes all fields that should affect equality
   @override
   List<Object?> get props => [status, data, error, timestamp];
   ```

### State Persistence Issues

#### Issue: App state lost on app restart or navigation

**Symptoms:**
- User has to log in again after app restart
- Form data is lost when navigating away
- Settings don't persist between sessions

**Causes:**
- Missing state persistence
- Improper state restoration
- Storage access issues
- Incorrect serialization/deserialization

**Solutions:**

1. **Implement hydrated BLoC:**
   ```dart
   // Add hydrated_bloc package
   class MyBloc extends HydratedBloc<MyEvent, MyState> {
     MyBloc() : super(const MyInitial()) {
       on<MyEvent>(_onMyEvent);
     }
     
     @override
     MyState? fromJson(Map<String, dynamic> json) {
       try {
         return MyState.fromJson(json);
       } catch (_) {
         return null;
       }
     }
     
     @override
     Map<String, dynamic>? toJson(MyState state) {
       return state.toJson();
     }
   }
   ```

2. **Save form state on changes:**
   ```dart
   // Save form data as it changes
   void _onFieldChanged(String value) {
     setState(() {
       _formData['field'] = value;
     });
     
     // Save to local storage
     _saveFormData();
   }
   
   Future<void> _saveFormData() async {
     await prefs.setString('form_data', jsonEncode(_formData));
   }
   
   // Restore on init
   @override
   void initState() {
     super.initState();
     _loadFormData();
   }
   
   Future<void> _loadFormData() async {
     final savedData = prefs.getString('form_data');
     if (savedData != null) {
       setState(() {
         _formData = jsonDecode(savedData);
       });
     }
   }
   ```

3. **Use RestorationMixin for navigation state:**
   ```dart
   class _MyFormPageState extends State<MyFormPage> with RestorationMixin {
     final RestorableTextEditingController _nameController = RestorableTextEditingController();
     final RestorableTextEditingController _emailController = RestorableTextEditingController();
     
     @override
     String get restorationId => 'my_form_page';
     
     @override
     void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
       registerForRestoration(_nameController, 'name_controller');
       registerForRestoration(_emailController, 'email_controller');
     }
     
     @override
     void dispose() {
       _nameController.dispose();
       _emailController.dispose();
       super.dispose();
     }
     
     // Rest of implementation
   }
   ```

4. **Check storage permissions:**
   ```dart
   Future<bool> _checkStoragePermissions() async {
     if (Platform.isAndroid) {
       final status = await Permission.storage.status;
       if (status != PermissionStatus.granted) {
         final result = await Permission.storage.request();
         return result == PermissionStatus.granted;
       }
       return true;
     }
     return true; // iOS doesn't need explicit permission for app storage
   }
   ```

## Performance Issues

### Memory Leaks

#### Issue: App memory usage grows over time

**Symptoms:**
- App becomes slower over time
- Out of memory errors
- App crashes after extended use

**Causes:**
- Unclosed streams
- Unmanaged subscriptions
- Large cached data
- Retained widget trees

**Solutions:**

1. **Dispose streams and controllers:**
   ```dart
   class _MyWidgetState extends State<MyWidget> {
     final _controller = StreamController<String>();
     late StreamSubscription _subscription;
     
     @override
     void initState() {
       super.initState();
       _subscription = someStream.listen(_handleData);
     }
     
     @override
     void dispose() {
       _subscription.cancel();
       _controller.close();
       super.dispose();
     }
   }
   ```

2. **Limit cache size:**
   ```dart
   // Configure CachedNetworkImage with limits
   CachedNetworkImage(
     imageUrl: url,
     cacheManager: CacheManager(
       Config(
         'my_cache_key',
         stalePeriod: const Duration(days: 7),
         maxNrOfCacheObjects: 100,
         maxSizeBytes: 50 * 1024 * 1024, // 50MB
       ),
     ),
   )
   ```

3. **Use weak references for large objects:**
   ```dart
   // Store large objects in a way that allows garbage collection
   final cache = <String, WeakReference<LargeObject>>{};
   
   void storeObject(String key, LargeObject object) {
     cache[key] = WeakReference<LargeObject>(object);
   }
   
   LargeObject? getObject(String key) {
     final ref = cache[key];
     return ref?.target;
   }
   ```

4. **Profile memory usage:**
   ```dart
   // Use DevTools for memory profiling
   // Or add manual memory tracking
   void logMemoryUsage() {
     final memoryInfo = MemoryInfo.instance;
     print('Used memory: ${memoryInfo.usedMemory}');
     print('Free memory: ${memoryInfo.freeMemory}');
   }
   ```

### Slow UI Rendering

#### Issue: UI feels sluggish or animations stutter

**Symptoms:**
- Jerky animations
- Delayed response to user input
- Frame drops

**Causes:**
- Heavy computation on UI thread
- Inefficient widget rebuilds
- Large images or assets
- Too many animations

**Solutions:**

1. **Use the performance overlay:**
   ```dart
   // In main.dart
   MaterialApp(
     showPerformanceOverlay: true,
     // ...
   )
   ```

2. **Reduce rebuild scope with const widgets:**
   ```dart
   // Use const for static widgets
   const MyWidget(
     title: 'Static Title',
     icon: Icons.star,
   )
   ```

3. **Implement shouldRepaint for custom painters:**
   ```dart
   class MyCustomPainter extends CustomPainter {
     final Color color;
     
     const MyCustomPainter({required this.color});
     
     @override
     void paint(Canvas canvas, Size size) {
       // Painting code
     }
     
     @override
     bool shouldRepaint(MyCustomPainter oldDelegate) {
       return color != oldDelegate.color;
     }
   }
   ```

4. **Use RepaintBoundary for complex UI sections:**
   ```dart
   RepaintBoundary(
     child: ComplexAnimatedWidget(),
   )
   ```

5. **Optimize image loading and caching:**
   ```dart
   // Specify image dimensions
   Image.network(
     url,
     width: 100,
     height: 100,
     fit: BoxFit.cover,
   )
   
   // Or use CachedNetworkImage
   CachedNetworkImage(
     imageUrl: url,
     width: 100,
     height: 100,
     fit: BoxFit.cover,
     memCacheWidth: 200, // 2x for high-DPI screens
     memCacheHeight: 200,
   )
   ```

6. **Move heavy computation off the UI thread:**
   ```dart
   // Use compute for heavy work
   final result = await compute(heavyComputation, inputData);
   
   // Or use an isolate directly
   final receivePort = ReceivePort();
   await Isolate.spawn(isolateFunction, receivePort.sendPort);
   final result = await receivePort.first;
   ```

### Battery Drain

#### Issue: App consumes excessive battery

**Symptoms:**
- Battery drains quickly when app is in use
- App appears in battery usage stats
- Device gets warm during app use

**Causes:**
- Background processes
- Continuous network requests
- Location or sensor polling
- Inefficient animations

**Solutions:**

1. **Limit background activity:**
   ```dart
   // Use workmanager for efficient background tasks
   Workmanager().registerOneOffTask(
     "syncData",
     "syncDataTask",
     constraints: Constraints(
       networkType: NetworkType.connected,
       batteryNotLow: true,
     ),
   );
   ```

2. **Implement efficient polling:**
   ```dart
   // Instead of continuous polling
   Timer.periodic(const Duration(seconds: 1), (_) {
     fetchData();
   });
   
   // Use exponential backoff
   Duration _nextPollDelay = const Duration(seconds: 5);
   
   void schedulePoll() {
     Future.delayed(_nextPollDelay, () {
       fetchData();
       _nextPollDelay *= 2; // Increase delay
       if (_nextPollDelay > const Duration(minutes: 30)) {
         _nextPollDelay = const Duration(minutes: 30);
       }
       schedulePoll();
     });
   }
   ```

3. **Optimize location usage:**
   ```dart
   // Instead of continuous updates
   final location = Location();
   location.changeSettings(
     interval: 10000, // 10 seconds
     distanceFilter: 10, // 10 meters
   );
   ```

4. **Use push instead of polling:**
   ```dart
   // Set up Firebase messaging for push notifications
   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
     // Handle message and update UI
   });
   ```

## Platform-Specific Issues

### Android Issues

#### Issue: Android emulator network connectivity problems

**Symptoms:**
- API requests fail on Android emulator
- "Connection refused" errors
- Works on physical devices but not emulator

**Causes:**
- Localhost references in API URLs
- Emulator network configuration
- Missing internet permission

**Solutions:**

1. **Use 10.0.2.2 for localhost:**
   ```dart
   // The app should automatically handle this conversion
   // Check if it's working
   if (AndroidEmulatorConfig.isAndroidEmulator) {
     print('Original URL: ${EnvironmentConfig.rawBaseUrl}');
     print('Converted URL: ${EnvironmentConfig.baseUrl}');
   }
   ```

2. **Check Android manifest permissions:**
   ```xml
   <!-- In AndroidManifest.xml -->
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
   ```

3. **Test direct connection:**
   ```bash
   # From emulator shell
   adb shell
   ping 10.0.2.2
   curl http://10.0.2.2:8000/health
   ```

4. **Configure backend server:**
   ```bash
   # Ensure server binds to all interfaces, not just localhost
   # For example, with a Node.js server:
   app.listen(8000, '0.0.0.0', () => {
     console.log('Server running on http://0.0.0.0:8000');
   });
   ```

### iOS Issues

#### Issue: iOS secure storage or keychain problems

**Symptoms:**
- Secure storage operations fail on iOS
- "No keychain access" errors
- Authentication state not persisting

**Causes:**
- Missing entitlements
- Keychain access restrictions
- Simulator limitations

**Solutions:**

1. **Check keychain access groups:**
   ```xml
   <!-- In Info.plist -->
   <key>keychain-access-groups</key>
   <array>
     <string>$(AppIdentifierPrefix)com.example.spb</string>
   </array>
   ```

2. **Configure keychain accessibility:**
   ```dart
   const secureStorage = FlutterSecureStorage(
     iOptions: IOSOptions(
       accessibility: KeychainAccessibility.first_unlock_this_device,
     ),
   );
   ```

3. **Handle simulator limitations:**
   ```dart
   // Check if running on simulator
   if (Platform.isIOS && !await _isPhysicalDevice()) {
     AppLogger.warning('Running on iOS simulator - keychain may have limitations');
   }
   
   Future<bool> _isPhysicalDevice() async {
     final deviceInfo = DeviceInfoPlugin();
     final iosInfo = await deviceInfo.iosInfo;
     return !iosInfo.isPhysicalDevice;
   }
   ```

4. **Implement fallback for simulator:**
   ```dart
   Future<void> saveSecureData(String key, String value) async {
     try {
       await secureStorage.write(key: key, value: value);
     } catch (e) {
       // Fallback for simulator
       if (Platform.isIOS && !await _isPhysicalDevice()) {
         await prefs.setString('sim_$key', value);
       } else {
         rethrow;
       }
     }
   }
   
   Future<String?> getSecureData(String key) async {
     try {
       return await secureStorage.read(key: key);
     } catch (e) {
       // Fallback for simulator
       if (Platform.isIOS && !await _isPhysicalDevice()) {
         return prefs.getString('sim_$key');
       } else {
         rethrow;
       }
     }
   }
   ```

### Web Issues

#### Issue: Web-specific rendering or functionality problems

**Symptoms:**
- Features work on mobile but not web
- Different appearance on web
- JavaScript console errors

**Causes:**
- Platform-specific code
- Unsupported plugins
- CORS issues
- Web renderer differences

**Solutions:**

1. **Check for platform-specific code:**
   ```dart
   // Use conditional imports
   import 'storage_mobile.dart' if (dart.library.html) 'storage_web.dart';
   
   // Or runtime checks
   if (kIsWeb) {
     // Web-specific implementation
   } else {
     // Mobile implementation
   }
   ```

2. **Verify plugin web support:**
   ```yaml
   # In pubspec.yaml, check for web support
   dependencies:
     some_plugin: ^1.0.0 # Check plugin README for web support
   ```

3. **Address CORS issues:**
   ```dart
   // For API requests, ensure backend has CORS headers
   // Or use a proxy in development
   
   // Check network tab in browser dev tools for CORS errors
   ```

4. **Test with different web renderers:**
   ```bash
   # Build with CanvasKit (better fidelity, larger download)
   flutter build web --web-renderer canvaskit
   
   # Build with HTML (smaller, less consistent)
   flutter build web --web-renderer html
   ```

5. **Add web-specific polyfills:**
   ```html
   <!-- In web/index.html -->
   <head>
     <!-- Add polyfills for older browsers if needed -->
     <script src="https://polyfill.io/v3/polyfill.min.js?features=IntersectionObserver"></script>
   </head>
   ```

## Build and Deployment Problems

### Build Failures

#### Issue: App fails to build

**Symptoms:**
- Build process fails with errors
- "Gradle build failed" or "Xcode build failed"
- Missing dependencies or incompatible versions

**Causes:**
- Dependency conflicts
- Missing platform-specific setup
- Outdated Gradle or CocoaPods
- Incompatible plugin versions

**Solutions:**

1. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk  # or ios, web, etc.
   ```

2. **Check dependency compatibility:**
   ```bash
   flutter pub outdated
   flutter pub upgrade --major-versions
   ```

3. **Update Gradle wrapper (Android):**
   ```bash
   cd android
   ./gradlew wrapper --gradle-version=8.10.2
   cd ..
   ```

4. **Update CocoaPods (iOS):**
   ```bash
   cd ios
   pod repo update
   pod install --repo-update
   cd ..
   ```

5. **Check build logs for specific errors:**
   ```bash
   # For Android
   flutter build apk --verbose
   
   # For iOS
   flutter build ios --verbose
   ```

### Code Generation Issues

#### Issue: Generated code is missing or outdated

**Symptoms:**
- "Class not found" errors for generated classes
- "Member not found" errors for fromJson/toJson methods
- Build failures related to generated code

**Causes:**
- Missing build_runner execution
- Conflicting generated files
- Syntax errors in model definitions
- Outdated build_runner or code generators

**Solutions:**

1. **Run code generation:**
   ```bash
   flutter packages pub run build_runner build
   ```

2. **Clean and regenerate:**
   ```bash
   flutter packages pub run build_runner clean
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```

3. **Check model definitions:**
   ```dart
   // Ensure annotations are correct
   @JsonSerializable()
   class UserModel extends User {
     const UserModel({
       required super.id,
       required super.userName,
       required super.email,
       required super.name,
     });
     
     factory UserModel.fromJson(Map<String, dynamic> json) => 
         _$UserModelFromJson(json);
     
     Map<String, dynamic> toJson() => _$UserModelToJson(this);
   }
   ```

4. **Update code generators:**
   ```bash
   flutter pub upgrade build_runner
   flutter pub upgrade json_serializable
   flutter pub upgrade injectable_generator
   ```

5. **Check part directives:**
   ```dart
   // Ensure part directive matches generated file name
   part 'user_model.g.dart';
   ```

### Deployment Issues

#### Issue: App deployment fails or app crashes after deployment

**Symptoms:**
- Deployment process fails
- App crashes on launch after installation
- Features work in debug but not release mode

**Causes:**
- Missing release configurations
- ProGuard/R8 issues
- Missing signing configuration
- Environment configuration issues

**Solutions:**

1. **Test in release mode locally:**
   ```bash
   # For Android
   flutter run --release
   
   # For iOS
   flutter run --release
   ```

2. **Check ProGuard configuration (Android):**
   ```
   # In android/app/proguard-rules.pro
   # Add rules for libraries that need them
   -keep class com.example.myapp.** { *; }
   ```

3. **Verify signing configuration:**
   ```gradle
   // In android/app/build.gradle
   signingConfigs {
       release {
           keyAlias keystoreProperties['keyAlias']
           keyPassword keystoreProperties['keyPassword']
           storeFile file(keystoreProperties['storeFile'])
           storePassword keystoreProperties['storePassword']
       }
   }
   ```

4. **Check environment configuration:**
   ```dart
   // Ensure production environment is properly configured
   print('Environment: ${EnvironmentConfig.environmentName}');
   print('API URL: ${EnvironmentConfig.baseUrl}');
   ```

5. **Enable release logging temporarily:**
   ```dart
   // Add temporary logging in release mode
   if (kReleaseMode) {
     AppLogger.init(logLevel: LogLevel.info);
     AppLogger.info('App started in release mode');
   }
   ```

## Environment Configuration Issues

### Environment Variables

#### Issue: Environment variables not loading correctly

**Symptoms:**
- "Environment not initialized" errors
- API requests going to wrong endpoints
- Features working in one environment but not another

**Causes:**
- Missing .env file
- Incorrect environment variable names
- Environment initialization issues
- Platform-specific environment handling

**Solutions:**

1. **Check environment file:**
   ```bash
   # Ensure .env file exists and has correct format
   cat .env
   
   # Example .env content
   FLUTTER_ENV=development
   DEV_API_BASE_URL=http://10.0.2.2:8097/v1
   DEV_ENABLE_LOGGING=true
   DEV_TIMEOUT_SECONDS=30
   ```

2. **Verify environment initialization:**
   ```dart
   // In main.dart
   Future<void> main() async {
     WidgetsFlutterBinding.ensureInitialized();
     
     try {
       // Initialize environment configuration
       await EnvironmentConfig.initialize();
       print('Environment initialized: ${EnvironmentConfig.environmentName}');
       print('API URL: ${EnvironmentConfig.baseUrl}');
     } catch (e) {
       print('Failed to initialize environment: $e');
     }
     
     // Continue with app initialization
   }
   ```

3. **Validate environment configuration:**
   ```dart
   final validation = EnvironmentValidator.validateEnvironment();
   print(validation.getReport());
   ```

4. **Set environment variables programmatically for testing:**
   ```dart
   // For testing specific environments
   void setTestEnvironment() {
     // This is for testing only
     Platform.environment['FLUTTER_ENV'] = 'development';
     Platform.environment['DEV_API_BASE_URL'] = 'http://test-api.example.com';
     Platform.environment['DEV_ENABLE_LOGGING'] = 'true';
   }
   ```

### Configuration Validation

#### Issue: Invalid configuration causing runtime errors

**Symptoms:**
- "Invalid URL format" errors
- "Required environment variable not set" errors
- App crashes on startup with configuration errors

**Causes:**
- Malformed URLs
- Missing required variables
- Type conversion errors
- Security policy violations

**Solutions:**

1. **Run environment validation:**
   ```dart
   final validation = EnvironmentValidator.validateEnvironment();
   if (!validation.isValid) {
     print('Environment validation failed:');
     print(validation.getReport());
   }
   ```

2. **Check URL format:**
   ```dart
   try {
     final uri = Uri.parse(EnvironmentConfig.baseUrl);
     print('URL is valid: ${uri.scheme}://${uri.host}:${uri.port}${uri.path}');
   } catch (e) {
     print('Invalid URL format: ${EnvironmentConfig.baseUrl}');
   }
   ```

3. **Verify security requirements:**
   ```dart
   // Check HTTPS requirement in production
   if (EnvironmentConfig.isProduction) {
     final uri = Uri.parse(EnvironmentConfig.baseUrl);
     if (uri.scheme != 'https') {
       print('WARNING: Production environment using non-HTTPS URL');
     }
   }
   ```

4. **Generate example configuration:**
   ```dart
   final exampleConfig = EnvironmentValidator.generateExampleEnvFile();
   print('Example configuration:');
   print(exampleConfig);
   ```

## Dependency Issues

### Version Conflicts

#### Issue: Package version conflicts or incompatibilities

**Symptoms:**
- "Incompatible version" errors
- "Conflicting dependencies" errors
- Features working inconsistently

**Causes:**
- Transitive dependency conflicts
- Outdated dependencies
- Incompatible plugin versions
- Flutter/Dart version mismatches

**Solutions:**

1. **Analyze dependencies:**
   ```bash
   flutter pub deps
   ```

2. **Update dependencies:**
   ```bash
   flutter pub upgrade
   ```

3. **Specify version constraints:**
   ```yaml
   # In pubspec.yaml
   dependencies:
     some_package: ^1.2.3  # Compatible with 1.2.3 or higher, but < 2.0.0
     other_package: '>=2.0.0 <3.0.0'  # Between 2.0.0 and 3.0.0
   ```

4. **Override dependencies:**
   ```yaml
   # In pubspec.yaml
   dependency_overrides:
     transitive_dependency: ^2.0.0
   ```

5. **Check Flutter/Dart compatibility:**
   ```bash
   flutter --version
   ```

### Missing Platform Support

#### Issue: Plugins not supporting all target platforms

**Symptoms:**
- "Plugin not implemented" errors
- Features working on some platforms but not others
- Build failures for specific platforms

**Causes:**
- Plugin missing platform implementation
- Platform-specific configuration missing
- Unsupported platform features

**Solutions:**

1. **Check plugin platform support:**
   ```yaml
   # In pubspec.yaml, look for supported platforms
   dependencies:
     some_plugin: ^1.0.0  # Check plugin's pub.dev page for platform support
   ```

2. **Implement platform-specific code:**
   ```dart
   // Use conditional imports
   import 'package:some_plugin/some_plugin.dart'
       if (dart.library.html) 'package:some_plugin/some_plugin_web.dart';
   
   // Or runtime checks
   if (Platform.isAndroid || Platform.isIOS) {
     // Mobile implementation
   } else if (kIsWeb) {
     // Web implementation
   } else {
     // Desktop implementation
   }
   ```

3. **Create platform-specific fallbacks:**
   ```dart
   abstract class PlatformService {
     Future<void> performAction();
     
     factory PlatformService() {
       if (Platform.isAndroid) {
         return AndroidPlatformService();
       } else if (Platform.isIOS) {
         return IOSPlatformService();
       } else {
         return FallbackPlatformService();
       }
     }
   }
   
   class FallbackPlatformService implements PlatformService {
     @override
     Future<void> performAction() async {
       // Fallback implementation or graceful degradation
     }
   }
   ```

4. **Check platform-specific configuration:**
   
   **Android:**
   ```xml
   <!-- AndroidManifest.xml -->
   <uses-permission android:name="android.permission.INTERNET" />
   ```
   
   **iOS:**
   ```xml
   <!-- Info.plist -->
   <key>NSCameraUsageDescription</key>
   <string>This app needs camera access to scan QR codes</string>
   ```
   
   **Web:**
   ```html
   <!-- index.html -->
   <meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
   ```

This troubleshooting guide covers the most common issues encountered in the SPB Secure Flutter application. For additional help, consult the project documentation, reach out to the development team, or check the issue tracker for known problems and solutions.