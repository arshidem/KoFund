// First, create the LogoutService (if not already done)
// lib/core/services/logout_service.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/profile/providers/profile_provider.dart';
import 'package:kofund/features/members/providers/member_provider.dart';

class LogoutService {
  /// Complete logout that clears EVERYTHING
  static Future<void> completeLogout(BuildContext context) async {
    try {
      debugPrint('🔄 STARTING COMPLETE LOGOUT PROCESS');
      
      // 1. Clear all provider states FIRST
      _clearAllProviderStates(context);
      
      // 2. Get auth provider and sign out from Firebase
      final _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      await _authProvider.signOut(context);
      
      // 3. Clear navigation stack completely
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login', 
        (route) => false,
      );
      
      debugPrint('✅ COMPLETE LOGOUT SUCCESSFUL');
      
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      // Even if there's an error, try to navigate to login
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login', 
        (route) => false,
      );
    }
  }
  
  /// Clear all provider states
  static void _clearAllProviderStates(BuildContext context) {
    try {
      // Clear ProfileProvider
      Provider.of<ProfileProvider>(context, listen: false).clearAllData();
      
      // Clear MemberProvider
      Provider.of<MemberProvider>(context, listen: false).clearAllData();
      
      // Add other providers as needed
      // Provider.of<EventProvider>(context, listen: false).clearAllData();
      // Provider.of<ContributionProvider>(context, listen: false).clearAllData();
      
      debugPrint('✅ All provider states cleared');
    } catch (e) {
      debugPrint('⚠️ Error clearing provider states: $e');
    }
  }
}






