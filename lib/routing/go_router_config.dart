import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../features/auth/providers/app_auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/verification_pending_screen.dart';
import '../features/auth/screens/set_phone_screen.dart';
import '../features/community/screens/create_community_screen.dart';
import '../features/community/screens/join_community_screen.dart';
import '../features/community/screens/community_dashboard.dart';
import '../core/widgets/community_guard.dart';
import '../features/community/screens/pending_approval_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dashboard/screens/edit_community_screen.dart';
import '../features/members/screens/all_members_screen.dart';
import '../features/members/screens/member_profile_screen.dart';
import '../features/events/screens/event_details_screen.dart';
import '../features/events/screens/create_event_screen.dart';
import '../features/events/screens/public_event_detail_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/participation_history_screen.dart';
import '../features/profile/screens/contribution_history_screen.dart';
import '../features/profile/screens/settings/settings_screen.dart';
import '../features/profile/screens/settings/privacy_settings_screen.dart';
import '../features/profile/screens/settings/change_password_screen.dart';
import '../features/profile/screens/settings/help_faq_screen.dart';
import '../features/profile/screens/settings/contact_support_screen.dart';
import '../features/profile/screens/settings/report_issue_screen.dart';
import '../features/profile/screens/settings/terms_of_service_screen.dart';
import '../features/profile/screens/settings/privacy_policy_screen.dart';
import '../features/profile/screens/settings/community_guidelines_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/notifications/screens/notification_detail_screen.dart';
import '../features/notifications/screens/notification_settings_screen.dart';
import '../features/auth/models/user_model.dart';

// Public website screens
import '../features/website/screens/landing_page.dart';
import '../features/website/screens/privacy_policy_page.dart';
import '../features/website/screens/terms_of_service_page.dart';
import '../features/website/screens/delete_account_page.dart';
import '../features/website/screens/support_page.dart';
import '../features/website/screens/data_safety_page.dart';
import '../features/website/screens/about_page.dart';

import 'route_names.dart';

class GoRouterConfig {
  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AppAuthProvider authProvider) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final path = state.uri.path;
        final loggedIn = authProvider.user != null;

        // On mobile app, we always route '/' to '/splash' first
        if (!kIsWeb && path == '/') {
          return '/splash';
        }

        // Web logic: if logged in and navigating to login/register, route to splash to handle dashboards
        if (kIsWeb && loggedIn && (path == '/login' || path == '/register')) {
          return '/splash';
        }

        return null;
      },
      routes: [
        // Public website routes
        GoRoute(
          path: '/',
          builder: (context, state) => const LandingPage(),
        ),
        GoRoute(
          path: '/privacyPolicy',
          builder: (context, state) => const PrivacyPolicyPage(),
        ),
        GoRoute(
          path: '/termsOfService',
          builder: (context, state) => const TermsOfServicePage(),
        ),
        GoRoute(
          path: '/deleteAccount',
          builder: (context, state) => const DeleteAccountPage(),
        ),
        GoRoute(
          path: '/support',
          builder: (context, state) => const SupportPage(),
        ),
        GoRoute(
          path: '/dataSafety',
          builder: (context, state) => const DataSafetyPage(),
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutPage(),
        ),

        // App routes
        GoRoute(
          path: '/splash',
          builder: (context, state) {
            final inviteCode = state.uri.queryParameters['code'];
            final eventId = state.uri.queryParameters['eventId'];
            return SplashScreen(
              deepLinkInviteCode: inviteCode,
              deepLinkEventId: eventId,
            );
          },
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) {
            final inviteCode = state.uri.queryParameters['code'];
            return LoginScreen(pendingInviteCode: inviteCode);
          },
        ),
        GoRoute(
          path: RouteNames.register,
          builder: (context, state) {
            final inviteCode = state.uri.queryParameters['code'];
            return RegisterScreen(pendingInviteCode: inviteCode);
          },
        ),
        GoRoute(
          path: RouteNames.forgotPassword,
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: RouteNames.setPhone,
          builder: (context, state) {
            final inviteCode = state.uri.queryParameters['code'];
            return SetPhoneScreen(pendingInviteCode: inviteCode);
          },
        ),
        GoRoute(
          path: RouteNames.verificationPending,
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            final inviteCode = state.uri.queryParameters['code'];
            return VerificationPendingScreen(
              email: email,
              pendingInviteCode: inviteCode,
            );
          },
        ),
        GoRoute(
          path: RouteNames.dashboard,
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.createCommunity,
          builder: (context, state) => const CreateCommunityScreen(),
        ),
        GoRoute(
          path: RouteNames.joinCommunity,
          builder: (context, state) {
            final inviteCode = state.uri.queryParameters['code'];
            return JoinCommunityScreen(inviteCode: inviteCode);
          },
        ),
        GoRoute(
          path: RouteNames.communityDashboard,
          builder: (context, state) {
            final eventId = state.uri.queryParameters['eventId'];
            return CommunityGuard(
              child: CommunityDashboard(pendingEventId: eventId),
            );
          },
        ),
        GoRoute(
          path: RouteNames.editCommunity,
          builder: (context, state) => const EditCommunityScreen(),
        ),
        GoRoute(
          path: RouteNames.pendingApproval,
          builder: (context, state) => const PendingApprovalScreen(),
        ),
        GoRoute(
          path: RouteNames.allMembers,
          builder: (context, state) => const AllMembersScreen(),
        ),
        GoRoute(
          path: RouteNames.memberDetails,
          builder: (context, state) {
            final member = state.extra as UserModel;
            return MemberProfileScreen(member: member);
          },
        ),
        GoRoute(
          path: RouteNames.createEvent,
          builder: (context, state) => const CreateEventScreen(),
        ),
        GoRoute(
          path: '${RouteNames.eventDetails}/:eventId',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            return EventDetailsScreen(eventId: eventId);
          },
        ),
        // Compatibility routes for event detail deep links (/view, /e, /d)
        GoRoute(
          path: '/view/:eventId',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            return EventDetailsScreen(eventId: eventId);
          },
        ),
        GoRoute(
          path: '/e/:eventId',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            return EventDetailsScreen(eventId: eventId);
          },
        ),
        GoRoute(
          path: '/d/:eventId',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            return EventDetailsScreen(eventId: eventId);
          },
        ),
        GoRoute(
          path: RouteNames.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: RouteNames.editProfile,
          builder: (context, state) {
            final user = state.extra as UserModel;
            return EditProfileScreen(
              user: user,
              onProfileUpdated: () {},
            );
          },
        ),
        GoRoute(
          path: RouteNames.participationHistory,
          builder: (context, state) => const ParticipationHistoryScreen(),
        ),
        GoRoute(
          path: RouteNames.contributionHistory,
          builder: (context, state) => const ContributionHistoryScreen(),
        ),
        GoRoute(
          path: RouteNames.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: RouteNames.changePassword,
          builder: (context, state) => const ChangePasswordScreen(),
        ),
        GoRoute(
          path: RouteNames.privacySettings,
          builder: (context, state) => const PrivacySettingsScreen(),
        ),
        GoRoute(
          path: RouteNames.helpFAQ,
          builder: (context, state) => const HelpFAQScreen(),
        ),
        GoRoute(
          path: RouteNames.contactSupport,
          builder: (context, state) => const ContactSupportScreen(),
        ),
        GoRoute(
          path: RouteNames.reportIssue,
          builder: (context, state) => const ReportIssueScreen(),
        ),
        GoRoute(
          path: RouteNames.termsOfService,
          builder: (context, state) => const TermsOfServiceScreen(),
        ),
        GoRoute(
          path: RouteNames.privacyPolicy,
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: RouteNames.communityGuidelines,
          builder: (context, state) => const CommunityGuidelinesScreen(),
        ),
        GoRoute(
          path: RouteNames.notifications,
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: RouteNames.notificationDetail,
          builder: (context, state) => NotificationDetailScreen(),
        ),
        GoRoute(
          path: RouteNames.notificationSettings,
          builder: (context, state) => const NotificationSettingsScreen(),
        ),
        GoRoute(
          path: '${RouteNames.publicEventDetail}/:eventId',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            return PublicEventDetailScreen(eventId: eventId);
          },
        ),
        // Compatibility route for public event detail (/p)
        GoRoute(
          path: '/p/:eventId',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId'] ?? '';
            return PublicEventDetailScreen(eventId: eventId);
          },
        ),
      ],
    );
  }
}
