// lib/routing/app_router.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kofund/features/auth/models/user_model.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/community/screens/create_community_screen.dart';
import '../features/community/screens/join_community_screen.dart';
import '../features/community/screens/community_dashboard.dart';
import '../features/community/screens/pending_approval_screen.dart';
import '../features/admin/screens/approval_requests_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';

import '../features/members/screens/all_members_screen.dart';
import '../features/members/screens/member_details_screen.dart';

// PROGRAM SCREENS
import '../features/programs/screens/program_details_screen.dart';
import '../features/programs/screens/create_program_screen.dart';

// 🆕 CONTRIBUTION SCREENS
import '../features/contributions/screens/all_contribution_screen.dart';
import '../features/contributions/screens/update_contribution_screen.dart';
import '../features/contributions/screens/add_contribution_screen.dart';
import '../features/contributions/models/contribution_model.dart';

// PROFILE & SETTINGS SCREENS
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

// PROVIDERS
import '../features/auth/providers/app_auth_provider.dart';

// Notification route names
import '../features/notifications/screens/notifications_screen.dart';
import '../features/notifications/screens/notification_detail_screen.dart';
import '../features/notifications/screens/notification_settings_screen.dart';
import '../features/notifications/models/notification_model.dart';
import 'route_names.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case RouteNames.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case RouteNames.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
        // Add this case to your route generator
      case RouteNames.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case RouteNames.dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case RouteNames.createCommunity:
        return MaterialPageRoute(builder: (_) => const CreateCommunityScreen());
      case RouteNames.joinCommunity:
        return MaterialPageRoute(builder: (_) => const JoinCommunityScreen());
      case RouteNames.communityDashboard:
        return MaterialPageRoute(builder: (_) => const CommunityDashboard());
      case RouteNames.pendingApproval:
        return MaterialPageRoute(builder: (_) => const PendingApprovalScreen());
      case RouteNames.approvalRequests:
        return MaterialPageRoute(builder: (_) => const ApprovalRequestsScreen());
      
      // MEMBER ROUTES
      case RouteNames.allMembers:
        return MaterialPageRoute(builder: (_) => const AllMembersScreen());
      case RouteNames.memberDetails:
        final member = settings.arguments as UserModel;
        return MaterialPageRoute(
          builder: (_) => MemberDetailsScreen(member: member),
        );
      
      // PROGRAM ROUTES
      case RouteNames.createProgram:
        return MaterialPageRoute(builder: (_) => const CreateProgramScreen());
      case RouteNames.programDetails:
        final programId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => ProgramDetailsScreen(programId: programId),
        );
      
      // 🆕 CONTRIBUTION ROUTES
      case RouteNames.allContributions:
        return MaterialPageRoute(builder: (_) => const AllContributionsScreen());
      case RouteNames.updateContribution:
        final contribution = settings.arguments as ContributionModel;
        return MaterialPageRoute(
          builder: (_) => UpdateContributionScreen(contribution: contribution),
        );
      case RouteNames.addContribution:
        return MaterialPageRoute(builder: (_) => const AddContributionScreen());
      
      // PROFILE ROUTES
      case RouteNames.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case RouteNames.editProfile:
        return MaterialPageRoute(
          builder: (context) {
            final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
            final user = authProvider.user;
            
            if (user == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Edit Profile')),
                body: const Center(
                  child: Text('User not found. Please login again.'),
                ),
              );
            }
            
            return EditProfileScreen(
              user: user,
              onProfileUpdated: () {
                // Optional: Add callback logic if needed
              },
            );
          },
        );
      case RouteNames.participationHistory:
        return MaterialPageRoute(builder: (_) => const ParticipationHistoryScreen());
      case RouteNames.contributionHistory:
        return MaterialPageRoute(builder: (_) => const ContributionHistoryScreen());
      case RouteNames.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      
      // SETTINGS ROUTES
      case RouteNames.changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
      case RouteNames.privacySettings:
        return MaterialPageRoute(builder: (_) => const PrivacySettingsScreen());
      case RouteNames.helpFAQ:
        return MaterialPageRoute(builder: (_) => const HelpFAQScreen());
      case RouteNames.contactSupport:
        return MaterialPageRoute(builder: (_) => const ContactSupportScreen());
      case RouteNames.reportIssue:
        return MaterialPageRoute(builder: (_) => const ReportIssueScreen());
      case RouteNames.termsOfService:
        return MaterialPageRoute(builder: (_) => const TermsOfServiceScreen());
      case RouteNames.privacyPolicy:
        return MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen());
      case RouteNames.communityGuidelines:
        return MaterialPageRoute(builder: (_) => const CommunityGuidelinesScreen());
   
   // NOTIFICATION ROUTES
     case RouteNames.notifications:
  return MaterialPageRoute(builder: (_) => const NotificationsScreen());

case RouteNames.notificationDetail:
  final notification = settings.arguments as AppNotification;
  return MaterialPageRoute(
    builder: (_) => NotificationDetailScreen(),
    settings: settings,
  );

case RouteNames.notificationSettings:
  return MaterialPageRoute(builder: (_) => const NotificationSettingsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}