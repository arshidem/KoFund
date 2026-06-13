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
import 'core/services/event_service.dart';
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
import 'features/events/providers/event_provider.dart';
import 'features/participants/providers/participant_provider.dart';
import 'features/expenses/providers/expense_provider.dart';
import 'features/admin/providers/user_provider.dart';
import 'features/contributions/providers/contribution_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/members/providers/member_provider.dart';
import 'features/dashboard/providers/dashboard_provider.dart';

import 'features/notifications/providers/notification_provider.dart';
import 'features/notifications/providers/announcement_provider.dart';
import 'features/polls/providers/poll_provider.dart';
import 'features/issues/providers/issue_provider.dart';
// Add this import in your main.dart
import 'package:kofund/features/virtual_users/providers/virtual_user_provider.dart';
// 🌗 Theme Provider
import 'core/providers/theme_provider.dart';
import 'core/widgets/theme_transition_wrapper.dart';

// 🚀 Routing
import 'routing/go_router_config.dart';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, kIsWeb, kDebugMode;
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> navigatorKey = GoRouterConfig.rootNavigatorKey;

// ✨ Extract invite code from web URL (kIsWeb-safe)
String? extractWebInviteCode() {
  if (!kIsWeb) return null;
  try {
    // Query parnameter: ?code=XXXX
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

// ✨ Extract event ID from web URL
String? extractWebEventId() {
  if (!kIsWeb) return null;
  try {
    final qp = Uri.base.queryParameters['eventId'];
    if (qp != null && qp.isNotEmpty) {
      debugPrint('🎯 Web Event ID (query): $qp');
      return qp;
    }

    final segments = Uri.base.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments[0] == 'event') {
      debugPrint('🎯 Web Event ID (path): ${segments[1]}');
      return segments[1];
    }
  } catch (e) {
    debugPrint('⚠️ extractWebEventId error: $e');
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
    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'), // Use actual key if targeting web
      );
      if (kDebugMode) debugPrint('✅ Firebase App Check activated');
    }
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
  final prefs = await SharedPreferences.getInstance();
  if (!kIsWeb) {
    await SecureStorageService().migrateFromSharedPrefs([
      'kofund_auth_state',
      'kofund_user_data',
      'kofund_last_login',
      'cached_community'
    ]);
  }
  if (kDebugMode) debugPrint('✅ Storage migrated/initialized');

  // ⭐ KEY FIX: Read the saved theme before runApp so the first frame
  // is already in the correct theme — eliminates the white flash.
  final bool initialDarkMode = prefs.getBool('isDarkMode') ?? false;
  if (kDebugMode) debugPrint('🎨 Initial theme: ${initialDarkMode ? "dark" : "light"}');

  // Register Background FCM Handler (only on mobile/desktop, not web)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      NotificationService.firebaseMessagingBackgroundHandler
    );
    if (kDebugMode) debugPrint('✅ FCM Background registered');
  }

  // Initialize AdMob in background (non-critical)
  unawaited(_initializeAdMobSafely());

  // Global error handlers
  FlutterError.onError = (details) {
    debugPrint('🐛 Flutter Error: ${details.exception}');
    if (details.stack != null) {
      debugPrint('📌 Stack: ${details.stack}');
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

  // Run app — pass initialDarkMode so first frame uses correct theme
  runZonedGuarded(() {
    runApp(AppProviders(initialDarkMode: initialDarkMode));
  }, (error, stackTrace) {
    debugPrint('🐛 Dart Error: $error');
    debugPrint('📌 Stack: $stackTrace');
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
  if (kIsWeb) return;
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
              backgroundColor: Colors.transparent,
              body: const SizedBox.shrink(),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      'Firebase Initialization Failed',
                      style: TextStyle(fontSize: 18),
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
      Firebase.app();
      return true;
    } catch (e) {
      debugPrint('Firebase not initialized: $e');
      return false;
    }
  }
}

class AppProviders extends StatefulWidget {
  final bool initialDarkMode;
  const AppProviders({super.key, this.initialDarkMode = false});

  @override
  State<AppProviders> createState() => _AppProvidersState();
}

class _AppProvidersState extends State<AppProviders> {
  late final FirebaseAuthService authService;
  late final CommunityFirestoreService communityFirestoreService;
  late final EventService _eventService;
  late final ParticipantService _participantService;
  late final ContributionService _contributionService;
  late final ExpenseService _expenseService;
  late final UserService _userService;
  late final IssueService issueService;
  late final NotificationStorageService notificationStorageService;
  late final FCMTokenService fcmTokenService;
  late final NotificationService notificationService;
  late final StorageService _storageService;
  
  String? _webInviteCode;
  
  late AppAuthProvider _authProvider;
  // Keep it false initially to prevent white flash and ensure splash screen handles routing
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
    
    // 🎯 Extract web event ID early
    final webEventId = extractWebEventId();
    if (webEventId != null) {
      debugPrint('💾 Storing event ID for later use: $webEventId');
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('pending_event_id', webEventId);
      });
    }
    
    // Initialize services
    authService = FirebaseAuthService();
    communityFirestoreService = CommunityFirestoreService();
    _eventService = EventService();
    _participantService = ParticipantService();
    _contributionService = ContributionService();
    _expenseService = ExpenseService();
    issueService = IssueService();
    _userService = UserService();
    notificationStorageService = NotificationStorageService();
    fcmTokenService = FCMTokenService();
    notificationService = NotificationService();
    _storageService = StorageService();
    
    
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
      
      final startTime = DateTime.now();
      
      // Wait for the auth provider to finish its internal initialization (usually fast)
      while (!_authProvider.isInitialized && 
             DateTime.now().difference(startTime).inSeconds < 5) {
        await Future.delayed(const Duration(milliseconds: 50));
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


  
  Future<void> _initializeNotificationServices() async {
    if (kIsWeb) {
      debugPrint("🌐 Notification service initialization skipped on Web");
      return;
    }
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
    final bool isDark = widget.initialDarkMode;
    // Show a theme-matched loading screen while auth provider initializes.
    // Using the correct background prevents any white flash in dark mode.
    if (!_isAuthInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          backgroundColor: isDark
              ? AppColors.darkBackground  // 0xFF0B0E11
              : AppColors.lightBackground, // 0xFFF8F9FA
          body: const SizedBox.shrink(),
        ),
      );
    }
    
    return MultiProvider(
      providers: [
        // 🧩 Core service providers
        Provider<FirebaseAuthService>.value(value: authService),
        Provider<CommunityFirestoreService>.value(value: communityFirestoreService),
        Provider<EventService>.value(value: _eventService),
        Provider<ParticipantService>.value(value: _participantService),
        Provider<ContributionService>.value(value: _contributionService),
        Provider<ExpenseService>.value(value: _expenseService),
        Provider<UserService>.value(value: _userService),
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
            _storageService,
          ),
        ),

        // 📣 Announcement Provider
        ChangeNotifierProvider(
          create: (_) => AnnouncementProvider(),
        ),

        // 👥 User Provider
        ChangeNotifierProvider(
          create: (_) => UserProvider(_userService),
        ),

        ChangeNotifierProvider(
          create: (_) => EventProvider(
            eventService: _eventService,
            participantService: _participantService,
            contributionService: _contributionService,
            expenseService: _expenseService,
          ),
        ),

        // 👤 Participant Provider
        ChangeNotifierProvider(
          create: (_) => ParticipantProvider(
            participantService: _participantService,
          ),
        ),

        // 💰 Contribution Provider
        ChangeNotifierProvider(
          create: (_) => ContributionProvider(),
        ),

        // 💸 Expense Provider - FIXED: Use the existing auth provider
        ChangeNotifierProxyProvider<AppAuthProvider, ExpenseProvider>(
          create: (_) => ExpenseProvider(
            expenseService: _expenseService,
            userService: _userService,
            appAuthProvider: _authProvider,
          ),
          update: (_, authProvider, previousExpenseProvider) {
            return previousExpenseProvider ?? ExpenseProvider(
              expenseService: _expenseService,
              userService: _userService,
              appAuthProvider: authProvider,
            );
          },
        ),



        // 👤 Profile Provider - FIXED
        ChangeNotifierProxyProvider4<
            AppAuthProvider,
            EventProvider,
            ContributionProvider,
            ParticipantService,
            ProfileProvider>(
          create: (_) => ProfileProvider(
            eventProvider: EventProvider(
              eventService: _eventService,
              participantService: _participantService,
              contributionService: _contributionService,
              expenseService: _expenseService,
            ),
            contributionProvider: ContributionProvider(),
            participantService: _participantService,
            authProvider: _authProvider,
            userService: _userService,
          ),
          update: (_, authProvider, eventProvider, contributionProvider, 
                  participantService, previousProfileProvider) {
            return previousProfileProvider ?? ProfileProvider(
              eventProvider: eventProvider,
              contributionProvider: contributionProvider,
              participantService: participantService,
              authProvider: authProvider,
              userService: _userService,
            );
          },
        ),

        // 👥 Member Provider - FIXED: Use the existing auth provider
    // In main.dart - Update the ChangeNotifierProxyProvider2
ChangeNotifierProxyProvider2<AppAuthProvider, UserService, MemberProvider>(
  create: (_) => MemberProvider(
    userService: _userService,
    authProvider: _authProvider,
    participantService: _participantService,
    contributionService: _contributionService,
    virtualUserService: VirtualUserService(), // Add this
  ),
  update: (_, authProvider, userService, previousMemberProvider) {
    return previousMemberProvider ?? MemberProvider(
      userService: userService,
      authProvider: authProvider,
      participantService: _participantService,
      contributionService: _contributionService,
      virtualUserService: VirtualUserService(), // Add this
    );
  },
),

        // 📊 Dashboard Provider
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(
            communityService: communityFirestoreService,
            userService: _userService,
            contributionService: _contributionService,
            eventService: _eventService,
            expenseService: _expenseService,
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

        // 🌗 Theme Provider — seeded with the initial value read before runApp
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialDarkMode: widget.initialDarkMode),
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
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    _router = GoRouterConfig.createRouter(authProvider);
  }
  
  Future<void> _initAppLinks() async {
    if (kIsWeb) return;
    _appLinks = AppLinks();
    
    // ✅ CORRECT: Returns Uri?
    final Uri? initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDdeepLink(initialUri);
    }
    
    // ✅ CORRECT: uriLinkStream returns Stream<Uri?>
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDdeepLink(uri);
      }
    });
  }
  
void _handleDdeepLink(Uri uri) {

  debugPrint('📱 Deep link received: $uri');
  debugPrint('Full URI parse - Scheme: ${uri.scheme}, Host: "${uri.host}", Path: "${uri.path}", Query: ${uri.queryParameters}');
  
  String? inviteCode;
  
  // Handle ANY kofund:// URL with a code parnameter
  // Supports both: kofund:///join-community?code=... and kofund://join?code=...
  if (uri.scheme == 'kofund') {
    final eventId = uri.queryParameters['eventId'];
    if (eventId != null && eventId.isNotEmpty) {
      debugPrint('✅ Found event ID from kofund:// URL: $eventId');
      _navigateToSplashWithEvent(eventId);
      return;
    }

    inviteCode = uri.queryParameters['code'];
    if (inviteCode != null && inviteCode.isNotEmpty) {
      debugPrint('✅ Found invite code from kofund:// URL: $inviteCode');
      _navigateToSplashWithInvite(inviteCode);
      return;
    }
  }
  
  // Handle web links
  if (uri.scheme == 'https' && uri.host.contains('kofund')) {
    // New shortened Event deep link: https://kofund-153ba.web.app/view/12345
    // or https://kofund-153ba.web.app/e/12345 or /d/
    if (uri.path.startsWith('/view/') || uri.path.startsWith('/e/') || uri.path.startsWith('/d/')) {
      final segments = uri.path.split('/');
      if (segments.length >= 3) {
        final eventId = segments[2];
        debugPrint('✅ Found event ID from direct web URL: $eventId');
        _navigateToEventOrSplash(eventId: eventId);
        return;
      }
    }

    // Public Event deep link: https://kofund-153ba.web.app/p/12345
    if (uri.path.startsWith('/p/') || uri.path.startsWith('/public-event/')) {
      final segments = uri.path.split('/');
      if (segments.length >= 3) {
        final eventId = segments[2];
        debugPrint('✅ Found public event ID from web URL: $eventId');
        _navigateToEventOrSplash(eventId: eventId, isPublic: true);
        return;
      }
    }

    // Original Event deep link: https://kofund-153ba.web.app/event/12345
    if (uri.path.startsWith('/event/')) {
      final segments = uri.path.split('/');
      if (segments.length >= 3) {
        final eventId = segments[2];
        debugPrint('✅ Found event ID from web URL: $eventId');
        _navigateToEventOrSplash(eventId: eventId);
        return;
      }
    }
    
    final qpEventId = uri.queryParameters['eventId'];
    if (qpEventId != null && qpEventId.isNotEmpty) {
      debugPrint('✅ Found event ID from web query URL: $qpEventId');
      _navigateToEventOrSplash(eventId: qpEventId);
      return;
    }

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
    final context = navigatorKey.currentContext;
    if (context != null) {
      GoRouter.of(context).go('/splash?code=$inviteCode');
    }
  });
}

void _navigateToEventOrSplash({required String eventId, bool isPublic = false}) async {
  if (eventId.isEmpty) return;

  final context = navigatorKey.currentContext;
  if (context != null) {
    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      
      // If user is logged in and app is already running, push directly
      if (authProvider.user != null) {
        debugPrint('🚀 App is warm and user logged in - pushing event details directly: $eventId');
        
        GoRouter.of(context).go(isPublic ? '/p/$eventId' : '/e/$eventId');
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Navigation error (provider not ready?): $e');
    }
  }

  // Fallback to splash screen flow for cold start or unauthenticated users
  _navigateToSplashWithEvent(eventId);
}

void _navigateToSplashWithEvent(String? eventId) async {
  if (eventId == null || eventId.isEmpty) return;
  
  debugPrint('📍 Navigating to splash screen with event id: $eventId');
  
  // Save to storage as backup
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('pending_event_id', eventId);
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      GoRouter.of(context).go('/splash?eventId=$eventId');
    }
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

    return MaterialApp.router(
      title: 'KoFund',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return ThemeTransitionWrapper(
          isDarkMode: themeProvider.isDarkMode,
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
            ],
          ),
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

