// main.dart - UPDATED VERSION with proper Firebase initialization and deep linking
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_dimensions.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_links/app_links.dart';    
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// 🧩 Services
import 'core/services/firebase_auth_service.dart';
import 'core/services/community_firestore_service.dart';
import 'core/services/program_service.dart';
import 'core/services/participant_service.dart';
import 'core/services/contribution_service.dart';
import 'core/services/expense_service.dart';
import 'core/services/user_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/virtual_user_service.dart';
import 'core/services/issue_service.dart';
import 'core/services/notification_storage_service.dart';
import 'core/services/fcm_token_service.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/storage_service.dart';

// 🧠 Providers
import 'features/auth/providers/app_auth_provider.dart';
import 'features/community/providers/community_provider.dart';
import 'features/programs/providers/program_provider.dart';
import 'features/participants/providers/participant_provider.dart';
import 'features/expenses/providers/expense_provider.dart';
import 'features/admin/providers/user_provider.dart';
import 'features/contributions/providers/contribution_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/members/providers/member_provider.dart';
import 'features/dashboard/providers/dashboard_provider.dart';

import 'features/notifications/providers/notification_provider.dart';
import 'features/polls/providers/poll_provider.dart';
import 'features/issues/providers/issue_provider.dart';
// Add this import in your main.dart
import 'package:kofund/features/virtual_users/providers/virtual_user_provider.dart';
// 🌗 Theme Provider
import 'core/providers/theme_provider.dart';
import 'core/widgets/theme_transition_wrapper.dart';

// 🚀 Routing
import 'routing/app_router.dart';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, kIsWeb, kDebugMode;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✨ Extract invite code from web URL (kIsWeb-safe)
String? extractWebInviteCode() {
  if (!kIsWeb) return null;
  try {
    // Query parameter: ?code=XXXX
    final qp = Uri.base.queryParameters['code'];
    if (qp != null && qp.isNotEmpty) {
      debugPrint('🎯 Web Invite Code (query): $qp');
      return qp;
    }

    // Path style: /join/XXXX
    final segments = Uri.base.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments[0] == 'join') {
      debugPrint('🎯 Web Invite Code (path): ${segments[1]}');
      return segments[1];
    }
  } catch (e) {
    debugPrint('⚠️ extractWebInviteCode error: $e');
  }
  return null;
}
// =============================
// 🚀 MAIN() - FIXED VERSION
// =============================
void main() async {
  // ⭐ Enable clean (path-based) URLs on the web
  usePathUrlStrategy();
  
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ .env loaded');
  } catch (e) {
    debugPrint('⚠️ .env load failed: $e');
  }

  try {
    if (kDebugMode) {
      await validateFirebaseConfig();
      debugPrint('✅ Firebase config validated');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Firebase config error: $e');
  }
  // Set portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ⭐ CRITICAL: Initialize Firebase FIRST, before anything else
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) debugPrint('✅ Firebase initialized');

    // 🛡️ Initialize App Check to secure Cloud Functions
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'), // Use actual key if targeting web
    );
    if (kDebugMode) debugPrint('✅ Firebase App Check activated');
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Firebase init/AppCheck FAILED: $e');
  }

  // Set Firebase Auth persistence
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    if (kDebugMode) debugPrint('✅ Auth persistence: LOCAL');
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️ Auth persistence error: $e');
  }

  // Initialize Storage & Migration
  await SharedPreferences.getInstance();
  await SecureStorageService().migrateFromSharedPrefs([
    'kofund_auth_state',
    'kofund_user_data',
    'kofund_last_login',
    'cached_community'
  ]);
  if (kDebugMode) debugPrint('✅ Storage migrated/initialized');

  // Register Background FCM Handler
  FirebaseMessaging.onBackgroundMessage(
    NotificationService.firebaseMessagingBackgroundHandler
  );
  if (kDebugMode) debugPrint('✅ FCM Background registered');

  // Initialize AdMob in background (non-critical)
  unawaited(_initializeAdMobSafely());

  // Global error handlers
  FlutterError.onError = (details) {
    if (kDebugMode) {
      debugPrint('🐛 Flutter Error: ${details.exception}');
      if (details.stack != null) {
        debugPrint('📌 Stack: ${details.stack}');
      }
    }
  };

  // Show a visible error screen so silent runtime errors produce an understandable UI
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 56),
              const SizedBox(height: 12),
              Text('An error occurred while starting the app', style: TextStyle(fontSize: 18, color: Colors.red[700])),
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              if (details.stack != null) Text('${details.stack}', style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  };

  // Run app
  runZonedGuarded(() {
    runApp(const AppProviders());
  }, (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('🐛 Dart Error: $error');
      debugPrint('📌 Stack: $stackTrace');
    }
  });
}
// In main.dart - Add a Firebase config validation
Future<void> validateFirebaseConfig() async {
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    
    if (kDebugMode) {
      debugPrint('📱 Platform: $defaultTargetPlatform');
      debugPrint('🌐 Project ID: ${options.projectId}');
    }
    
    // Validate required fields
    if (options.appId.isEmpty || options.projectId.isEmpty) {
      throw Exception('Firebase configuration is incomplete');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('❌ Firebase config validation failed: $e');
    rethrow;
  }
}
// =============================
// 🔰 AdMob Initialization
// =============================
Future<void> _initializeAdMobSafely() async {
  if (kDebugMode) debugPrint('🔄 Initializing AdMob...');

  try {
    final testDeviceId = dotenv.get('TEST_DEVICE_ID', fallback: '');
    
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: [if (testDeviceId.isNotEmpty) testDeviceId],
      ),
    );

    await MobileAds.instance.initialize();
    debugPrint('✅ AdMob initialized');
  } catch (e) {
    debugPrint('❌ AdMob initialization failed (non-critical): $e');
  }
}

// Helper function for unawaited futures
void unawaited(Future<void>? future) {}

// ⭐ NEW: Add a Firebase initialization check widget
class FirebaseInitializationWrapper extends StatelessWidget {
  final Widget child;
  
  const FirebaseInitializationWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkFirebaseInitialized(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.blue,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    const Text(
                      'Initializing app...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.hasError)
                      Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.blue,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      'Firebase Initialization Failed',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await Firebase.initializeApp(
                            options: DefaultFirebaseOptions.currentPlatform,
                          );
                          // Restart app by pushing new MaterialApp
                          runApp(const AppProviders());
                        } catch (e) {
                          debugPrint('Retry failed: $e');
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        return child;
      },
    );
  }
  
  Future<bool> _checkFirebaseInitialized() async {
    try {
      // Check if Firebase is initialized by trying to access a property
      final app = Firebase.app();
      return true;
    } catch (e) {
      debugPrint('Firebase not initialized: $e');
      return false;
    }
  }
}

class AppProviders extends StatefulWidget {
  const AppProviders({super.key});

  @override
  State<AppProviders> createState() => _AppProvidersState();
}

class _AppProvidersState extends State<AppProviders> {
  late final FirebaseAuthService authService;
  late final CommunityFirestoreService communityFirestoreService;
  late final ProgramService programService;
  late final ParticipantService participantService;
  late final ContributionService contributionService;
  late final ExpenseService expenseService;
  late final UserService userService;
  late final IssueService issueService;
  late final NotificationStorageService notificationStorageService;
  late final FCMTokenService fcmTokenService;
  late final NotificationService notificationService;
  late final StorageService storageService;
  
  String? _webInviteCode;
  
  late AppAuthProvider _authProvider;
  bool _isAuthInitialized = false;
  
  @override
  void initState() {
    super.initState();
    
    // 🎯 Extract web invite code early
    _webInviteCode = extractWebInviteCode();
    if (_webInviteCode != null) {
      debugPrint('💾 Storing invite code for later use: $_webInviteCode');
      // Save to SharedPreferences for use throughout app
      _saveWebInviteCode(_webInviteCode!);
    }
    
    // Initialize services
    authService = FirebaseAuthService();
    communityFirestoreService = CommunityFirestoreService();
    programService = ProgramService();
    participantService = ParticipantService();
    contributionService = ContributionService();
    expenseService = ExpenseService();
    issueService = IssueService();
    userService = UserService();
    notificationStorageService = NotificationStorageService();
    fcmTokenService = FCMTokenService();
    notificationService = NotificationService();
    storageService = StorageService();
    
    
    // Create auth provider
    _authProvider = AppAuthProvider(authService);
    
    // Initialize auth provider asynchronously
    _initializeAuthProvider();
    
    // Initialize notification services asynchronously
    _initializeNotificationServices();
  }
  
  Future<void> _initializeAuthProvider() async {
    try {
      debugPrint("🔄 Initializing AppAuthProvider with offline support...");
      
      // ⭐ NEW: Use public initialization method if available
      // Try to access initialization via reflection or public method
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if auth provider has a public initialization method
      // If not, wait for it to initialize on its own
      final startTime = DateTime.now();
      
      while (!_authProvider.canAccessApp && 
             DateTime.now().difference(startTime).inSeconds < 5) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
          
      setState(() {
        _isAuthInitialized = true;
      });
      
      debugPrint("✅ AppAuthProvider initialization status:");
      debugPrint("   - User exists: ${_authProvider.user != null}");
      debugPrint("   - Offline mode: ${_authProvider.isOfflineMode}");
      debugPrint("   - Can access app: ${_authProvider.canAccessApp}");
      
    } catch (e) {
      debugPrint("❌ Error initializing auth provider: $e");
      setState(() {
        _isAuthInitialized = true; // Still mark as initialized to show UI
      });
    }
  }

  // 🎯 Save web invite code to SharedPreferences
  Future<void> _saveWebInviteCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('web_invite_code', code);
      debugPrint('✅ Invite code saved to SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error saving invite code: $e');
    }
  }

  // 🎯 Retrieve web invite code from SharedPreferences
  static Future<String?> getWebInviteCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('web_invite_code');
    } catch (e) {
      debugPrint('❌ Error retrieving invite code: $e');
      return null;
    }
  }

  // 🎯 Clear web invite code from SharedPreferences
  static Future<void> clearWebInviteCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('web_invite_code');
      debugPrint('✅ Invite code cleared');
    } catch (e) {
      debugPrint('❌ Error clearing invite code: $e');
    }
  }
  
  Future<void> _initializeNotificationServices() async {
    try {
      await notificationService.init(
        storage: notificationStorageService,
        tokenService: fcmTokenService,
      );
      debugPrint("✅ Notification service initialized");
    } catch (e) {
      debugPrint("⚠️ Notification service init error (non-critical): $e");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Show loading screen while auth provider initializes
    if (!_isAuthInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.primary(context),
          body: Container(),
        ),
      );
    }
    
    return MultiProvider(
      providers: [
        // 🧩 Core service providers
        Provider<FirebaseAuthService>.value(value: authService),
        Provider<CommunityFirestoreService>.value(value: communityFirestoreService),
        Provider<ProgramService>.value(value: programService),
        Provider<ParticipantService>.value(value: participantService),
        Provider<ContributionService>.value(value: contributionService),
        Provider<ExpenseService>.value(value: expenseService),
        Provider<UserService>.value(value: userService),
        Provider<IssueService>.value(value: issueService),
        
        // 🔔 Notification Services
        Provider<NotificationStorageService>.value(value: notificationStorageService),
        Provider<FCMTokenService>.value(value: fcmTokenService),
        Provider<NotificationService>.value(value: notificationService),

        // 🔐 Auth Provider - Use the pre-initialized instance
        ChangeNotifierProvider<AppAuthProvider>.value(value: _authProvider),
        
        // 🔔 Notification Provider
        ChangeNotifierProxyProvider2<NotificationService, FCMTokenService, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, notificationService, fcmTokenService, previous) {
            final provider = previous ?? NotificationProvider();
            provider.initializeServices(
              notificationService: notificationService,
              tokenService: fcmTokenService,
            );
            return provider;
          },
        ),

        // 🌐 Community Provider
        ChangeNotifierProvider(
          create: (_) => CommunityProvider(
            communityFirestoreService,
            storageService,
          ),
        ),

        // 👥 User Provider
        ChangeNotifierProvider(
          create: (_) => UserProvider(userService),
        ),

        // 📋 Program Provider
        ChangeNotifierProvider(
          create: (_) => ProgramProvider(
            programService: programService,
            participantService: participantService,
            contributionService: contributionService,
          ),
        ),

        // 👤 Participant Provider
        ChangeNotifierProvider(
          create: (_) => ParticipantProvider(
            participantService: participantService,
          ),
        ),

        // 💰 Contribution Provider
        ChangeNotifierProvider(
          create: (_) => ContributionProvider(),
        ),

        // 💸 Expense Provider - FIXED: Use the existing auth provider
        ChangeNotifierProxyProvider<AppAuthProvider, ExpenseProvider>(
          create: (_) => ExpenseProvider(
            expenseService: expenseService,
            userService: userService,
            appAuthProvider: _authProvider,
          ),
          update: (_, authProvider, previousExpenseProvider) {
            return previousExpenseProvider ?? ExpenseProvider(
              expenseService: expenseService,
              userService: userService,
              appAuthProvider: authProvider,
            );
          },
        ),



        // 👤 Profile Provider - FIXED
        ChangeNotifierProxyProvider4<
            AppAuthProvider,
            ProgramProvider,
            ContributionProvider,
            ParticipantService,
            ProfileProvider>(
          create: (_) => ProfileProvider(
            programProvider: ProgramProvider(
              programService: programService,
              participantService: participantService,
              contributionService: contributionService,
            ),
            contributionProvider: ContributionProvider(),
            participantService: participantService,
            authProvider: _authProvider,
            userService: userService,
          ),
          update: (_, authProvider, programProvider, contributionProvider, 
                  participantService, previousProfileProvider) {
            return previousProfileProvider ?? ProfileProvider(
              programProvider: programProvider,
              contributionProvider: contributionProvider,
              participantService: participantService,
              authProvider: authProvider,
              userService: userService,
            );
          },
        ),

        // 👥 Member Provider - FIXED: Use the existing auth provider
    // In main.dart - Update the ChangeNotifierProxyProvider2
ChangeNotifierProxyProvider2<AppAuthProvider, UserService, MemberProvider>(
  create: (_) => MemberProvider(
    userService: userService,
    authProvider: _authProvider,
    participantService: participantService,
    contributionService: contributionService,
    virtualUserService: VirtualUserService(), // Add this
  ),
  update: (_, authProvider, userService, previousMemberProvider) {
    return previousMemberProvider ?? MemberProvider(
      userService: userService,
      authProvider: authProvider,
      participantService: participantService,
      contributionService: contributionService,
      virtualUserService: VirtualUserService(), // Add this
    );
  },
),

        // 📊 Dashboard Provider
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(
            communityService: communityFirestoreService,
            userService: userService,
            contributionService: contributionService,
            programService: programService,
            expenseService: expenseService,
          ),
        ),
        
        // 📊 Poll Provider
        ChangeNotifierProvider(
          create: (context) => PollProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => IssueProvider(),
        ),
        ChangeNotifierProvider<VirtualUserProvider>(
  create: (_) => VirtualUserProvider(VirtualUserService()),
),

        // 🌗 Theme Provider
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri?>? _linkSubscription; // ✅ CORRECT: StreamSubscription<Uri?>
  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }
  
  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();
    
    // ✅ CORRECT: Returns Uri?
    final Uri? initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }
    
    // ✅ CORRECT: uriLinkStream returns Stream<Uri?>
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }
  
void _handleDeepLink(Uri uri) {
  debugPrint('📱 Deep link received: $uri');
  debugPrint('Full URI parse - Scheme: ${uri.scheme}, Host: "${uri.host}", Path: "${uri.path}", Query: ${uri.queryParameters}');
  
  String? inviteCode;
  
  // Handle ANY kofund:// URL with a code parameter
  // Supports both: kofund:///join-community?code=... and kofund://join?code=...
  if (uri.scheme == 'kofund') {
    inviteCode = uri.queryParameters['code'];
    if (inviteCode != null && inviteCode.isNotEmpty) {
      debugPrint('✅ Found invite code from kofund:// URL: $inviteCode');
      _navigateToSplashWithInvite(inviteCode);
      return;
    }
  }
  
  // Handle web links
  if (uri.scheme == 'https' && uri.host.contains('kofund')) {
    // Format 1: https://kofund-153ba.web.app/join/CUOVUA3H
    if (uri.path.startsWith('/join/')) {
      final segments = uri.path.split('/');
      if (segments.length >= 3) {
        inviteCode = segments[2];
      }
    }
    
    // Format 2: https://kofund-153ba.web.app/?code=CUOVUA3H
    if (inviteCode == null || inviteCode.isEmpty) {
      inviteCode = uri.queryParameters['code'];
    }
    
    if (inviteCode != null && inviteCode.isNotEmpty) {
      debugPrint('✅ Found invite code from web URL: $inviteCode');
      _navigateToSplashWithInvite(inviteCode);
      return;
    }
  }
  
  debugPrint('❌ Could not handle deep link: $uri');
}

void _navigateToSplashWithInvite(String? inviteCode) async {
  if (inviteCode == null || inviteCode.isEmpty) return;
  
  debugPrint('📍 Navigating to splash screen with invite code: $inviteCode');
  
  // Save to storage as backup
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('pending_invite_code', inviteCode);
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (navigatorKey.currentState == null) {
      debugPrint('❌ Navigator not ready yet');
      return;
    }
    
    // Use '/' as the route name (or RouteNames.splash)
    navigatorKey.currentState!.pushNamedAndRemoveUntil(
      '/',  // Changed to root route
      (route) => false,
      arguments: {'inviteCode': inviteCode},
    );
  });
}


  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
  

  

  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'KoFund',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      onGenerateRoute: AppRouter.onGenerateRoute,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return ThemeTransitionWrapper(
          isDarkMode: themeProvider.isDarkMode,
          child: child ?? const SizedBox.shrink(),
        );
      },
      

      // 🌤 LIGHT THEME
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
        cardColor: AppColors.lightCard,
        useMaterial3: true,
        
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.lightTextPrimary,
          titleTextStyle: const TextStyle(
            color: AppColors.lightTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        
       colorScheme: const ColorScheme.light(
  primary: AppColors.lightPrimary,
  secondary: AppColors.lightInfo,
  error: AppColors.lightError,
  surface: AppColors.lightBackground,  // This is correct
  // ❌ REMOVE THIS LINE: background: AppColors.lightBackground,
  onPrimary: Colors.white,
  onSecondary: Colors.white,
  onSurface: AppColors.lightTextPrimary,  // This is correct
  // ❌ REMOVE THIS LINE: onBackground: AppColors.lightTextPrimary,
),
        
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.lightTextPrimary),
          bodySmall: TextStyle(color: AppColors.lightTextSecondary),
          titleMedium: TextStyle(fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2),
          ),
          filled: true,
          fillColor: AppColors.lightSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lightPrimary,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.lightPrimary,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.lightPrimary,
            side: const BorderSide(color: AppColors.lightPrimary),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          ),
          color: AppColors.lightCard,
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          backgroundColor: AppColors.lightSurface,
          selectedColor: AppColors.lightPrimary.withValues(alpha: 0.1),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightBorder,
          thickness: 1,
        ),
      ),

      // 🌑 DARK THEME
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        cardColor: AppColors.darkCard,
        useMaterial3: true,
        
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.darkTextPrimary,
          titleTextStyle: const TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        
     colorScheme: const ColorScheme.dark(
  primary: AppColors.darkPrimary,
  secondary: AppColors.darkInfo,
  error: AppColors.darkError,
  surface: AppColors.darkBackground,  // This is correct
  // ❌ REMOVE THIS LINE: background: AppColors.darkBackground,
  onPrimary: Colors.black,
  onSecondary: Colors.black,
  onSurface: AppColors.darkTextPrimary,  // This is correct
  // ❌ REMOVE THIS LINE: onBackground: AppColors.darkTextPrimary,
),
        
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
          bodySmall: TextStyle(color: AppColors.darkTextSecondary),
          titleMedium: TextStyle(fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2),
          ),
          filled: true,
          fillColor: AppColors.darkSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkPrimary,
            foregroundColor: Colors.black,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.darkPrimary,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkPrimary,
            side: const BorderSide(color: AppColors.darkPrimary),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          ),
          color: AppColors.darkCard,
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          backgroundColor: AppColors.darkSurface,
          selectedColor: AppColors.darkPrimary.withValues(alpha: 0.1),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorder,
          thickness: 1,
        ),
      ),
    );
  }
}

