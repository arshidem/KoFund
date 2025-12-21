// main.dart - UPDATED VERSION with proper Firebase initialization and deep linking
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'core/constants/app_colors.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_links/app_links.dart';    
// 🧩 Services
import 'core/services/firebase_auth_service.dart';
import 'core/services/community_firestore_service.dart';
import 'core/services/program_service.dart';
import 'core/services/participant_service.dart';
import 'core/services/contribution_service.dart';
import 'core/services/expense_service.dart';
import 'core/services/user_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/issue_service.dart';
import 'core/services/notification_storage_service.dart';
import 'core/services/fcm_token_service.dart';

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
import 'features/history/providers/history_provider.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/polls/providers/poll_provider.dart';
import 'features/issues/providers/issue_provider.dart';

// 🌗 Theme Provider
import 'core/providers/theme_provider.dart';

// 🚀 Routing
import 'routing/app_router.dart';

import 'dart:async';
import 'routing/route_names.dart'; // Or wherever your RouteNames class is

// 🏁 Screens
import 'features/auth/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// =============================
// 🚀 MAIN() - FIXED VERSION
// =============================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    print('✅ Firebase initialized SUCCESSFULLY');
  } catch (e) {
    print('❌ Firebase initialization FAILED: $e');
    // Even if Firebase fails, we can still run the app in offline mode
  }

  // Set Firebase Auth persistence (requires Firebase to be initialized)
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    print('✅ Firebase Auth persistence: LOCAL (offline supported)');
  } catch (e) {
    print('⚠️ Auth persistence error: $e');
  }

  // Initialize Shared Preferences
  await SharedPreferences.getInstance();
  print('✅ Shared Preferences initialized');

  // Register Background FCM Handler (requires Firebase to be initialized)
  FirebaseMessaging.onBackgroundMessage(
    NotificationService.firebaseMessagingBackgroundHandler
  );
  print('✅ Background FCM handler registered');

  // Initialize AdMob in background (non-critical)
  unawaited(_initializeAdMobSafely());

  // Global error handlers
  FlutterError.onError = (details) {
    debugPrint('🐛 Flutter Error: ${details.exception}');
    if (details.stack != null) {
      debugPrint('📌 Stack: ${details.stack}');
    }
  };

  // Run app
  runZonedGuarded(() {
    runApp(const AppProviders());
  }, (error, stackTrace) {
    debugPrint('🐛 Dart Error: $error');
    debugPrint('📌 Stack: $stackTrace');
  });
}

// =============================
// 🔰 AdMob Initialization
// =============================
Future<void> _initializeAdMobSafely() async {
  print('🔄 Initializing AdMob...');

  try {
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: ['0C1F0F65AC946A5A803424C28073E8DD'],
      ),
    );

    await MobileAds.instance.initialize();
    print('✅ AdMob initialized');
  } catch (e) {
    print('❌ AdMob initialization failed (non-critical): $e');
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
  
  late AppAuthProvider _authProvider;
  bool _isAuthInitialized = false;
  
  @override
  void initState() {
    super.initState();
    
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
      if (_authProvider is AppAuthProvider) {
        // Try to access initialization via reflection or public method
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Check if auth provider has a public initialization method
        // If not, wait for it to initialize on its own
        final startTime = DateTime.now();
        
        while (!_authProvider.canAccessApp && 
               DateTime.now().difference(startTime).inSeconds < 5) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
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
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
        ),

        // 🌐 Community Provider
        ChangeNotifierProvider(
          create: (_) => CommunityProvider(communityFirestoreService),
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

        // 🕐 History Provider - FIXED: Use the existing auth provider
        ChangeNotifierProxyProvider<AppAuthProvider, HistoryProvider>(
          create: (_) => HistoryProvider(
            contributionService: contributionService,
            expenseService: expenseService,
            programService: programService,
            userService: userService,
            authProvider: _authProvider,
          ),
          update: (_, authProvider, previousHistoryProvider) {
            return previousHistoryProvider ?? HistoryProvider(
              contributionService: contributionService,
              expenseService: expenseService,
              programService: programService,
              userService: userService,
              authProvider: authProvider,
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
        ChangeNotifierProxyProvider2<AppAuthProvider, UserService, MemberProvider>(
          create: (_) => MemberProvider(
            userService: userService,
            authProvider: _authProvider,
            participantService: participantService,
            contributionService: contributionService,
          ),
          update: (_, authProvider, userService, previousMemberProvider) {
            return previousMemberProvider ?? MemberProvider(
              userService: userService,
              authProvider: authProvider,
              participantService: participantService,
              contributionService: contributionService,
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
 final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();  @override
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
          surface: AppColors.lightSurface,
          background: AppColors.lightBackground,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.lightTextPrimary,
          onBackground: AppColors.lightTextPrimary,
        ),
        
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.lightTextPrimary),
          bodySmall: TextStyle(color: AppColors.lightTextSecondary),
          titleMedium: TextStyle(fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          filled: true,
          fillColor: AppColors.lightSurface,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lightPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightBorder,
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
          surface: AppColors.darkSurface,
          background: AppColors.darkBackground,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: AppColors.darkTextPrimary,
          onBackground: AppColors.darkTextPrimary,
        ),
        
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
          bodySmall: TextStyle(color: AppColors.darkTextSecondary),
          titleMedium: TextStyle(fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          filled: true,
          fillColor: AppColors.darkSurface,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkPrimary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorder,
        ),
      ),
    );
  }
}