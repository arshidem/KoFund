import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/services/community_firestore_service.dart';
import 'package:kofund/features/community/models/community_model.dart';
import 'package:kofund/core/constants/community_types.dart';

class CommunityProvider with ChangeNotifier {
  final CommunityFirestoreService _communityService;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance; // 🆕 ADD THIS
  
  CommunityModel? _currentCommunity;
  List<CommunityModel> _userCommunities = [];
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _communityMembers = [];
  StreamSubscription<List<Map<String, dynamic>>>? _membersSubscription;

  // 🆕 REAL-TIME FINANCIAL FIELDS
  double _totalContributions = 0;
  double _totalExpenses = 0;
  double _fundBalance = 0;
  StreamSubscription? _contributionsSubscription;
  StreamSubscription? _expensesSubscription;

  CommunityProvider(this._communityService);

  // Getters
  CommunityModel? get currentCommunity => _currentCommunity;
  List<CommunityModel> get userCommunities => _userCommunities;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get communityMembers => _communityMembers;
  // 🆕 ADD THIS GETTER - CommunityProvider
String? get communityId => _currentCommunity?.communityId;
  // 🆕 FINANCIAL GETTERS
  double get totalContributions => _totalContributions;
  double get totalExpenses => _totalExpenses;
  double get fundBalance => _fundBalance;
// 🆕 ADD TO CommunityProvider
// Monthly Program Financial Stats
double _monthlyProgramBalance = 0;
int _monthlyProgramParticipants = 0;
double _monthlyProgramCollected = 0;

// Getters
double get monthlyProgramBalance => _monthlyProgramBalance;
int get monthlyProgramParticipants => _monthlyProgramParticipants;
double get monthlyProgramCollected => _monthlyProgramCollected;

// 🆕 Method to load monthly program stats
// 🆕 CORRECTED Method to load monthly program stats
Future<void> loadMonthlyProgramStats(String communityId) async {
  try {
    // Get all programs for the community
    final programs = await _firestore
        .collection('programs')
        .where('communityId', isEqualTo: communityId)
        .get();

    // Find the monthly payment program - FIXED
    QueryDocumentSnapshot? monthlyProgram;
    try {
      monthlyProgram = programs.docs.firstWhere(
        (doc) => doc.data()['isMonthlyPaymentProgram'] == true,
      );
    } catch (e) {
      monthlyProgram = null; // No monthly program found
    }

    if (monthlyProgram != null) {
      final programData = monthlyProgram.data();
      final programId = monthlyProgram.id;

      // Get participants count for monthly program
      final participantsSnapshot = await _firestore
          .collection('participants')
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'joined')
          .get();

      _monthlyProgramParticipants = participantsSnapshot.docs.length;

      // Get total contributions for monthly program
      final contributionsSnapshot = await _firestore
          .collection('contributions')
          .where('programId', isEqualTo: programId)
          .get();

      _monthlyProgramCollected = contributionsSnapshot.docs.fold(0.0, (sum, doc) {
        return sum + (doc.data()['amount'] ?? 0).toDouble();
      });

      // Get expenses for monthly program (if you track program-specific expenses)
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'approved')
          .get();

      final monthlyProgramExpenses = expensesSnapshot.docs.fold(0.0, (sum, doc) {
        return sum + (doc.data()['amount'] ?? 0).toDouble();
      });

      _monthlyProgramBalance = _monthlyProgramCollected - monthlyProgramExpenses;
    } else {
      // No monthly program found
      _monthlyProgramBalance = 0;
      _monthlyProgramParticipants = 0;
      _monthlyProgramCollected = 0;
    }

    notifyListeners();
  } catch (e) {
    print('❌ Error loading monthly program stats: $e');
    _monthlyProgramBalance = 0;
    _monthlyProgramParticipants = 0;
    _monthlyProgramCollected = 0;
    notifyListeners();
  }
}
// 🆕 ADD THIS METHOD - CommunityProvider
Future<void> loadCommunityStats() async {
  _isLoading = true;
  notifyListeners();

  try {
    if (_currentCommunity != null) {
      // Reload current community data
      await loadCurrentCommunity(_currentCommunity!.communityId);
      
      // Load community members
      await loadCommunityMembers(_currentCommunity!.communityId);
      
      // Load monthly program stats
      await loadMonthlyProgramStats(_currentCommunity!.communityId);
      
      // Financial data is already handled by real-time streams
    }
    _isLoading = false;
    notifyListeners();
  } catch (e) {
    _error = 'Failed to load community stats: $e';
    _isLoading = false;
    notifyListeners();
  }
}
  // 🆕 REAL-TIME FINANCIAL STREAMS
  void _startRealTimeFinancials(String communityId) {
    _stopRealTimeFinancials(); // Clear existing subscriptions

    // ✅ REAL-TIME CONTRIBUTIONS TOTAL
    _contributionsSubscription = FirebaseFirestore.instance
        .collection('contributions')
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .listen((contributionsSnapshot) {
      _totalContributions = contributionsSnapshot.docs.fold(0.0, (sum, doc) {
        final data = doc.data();
        return sum + (data['amount'] ?? 0).toDouble();
      });
      _recalculateBalance();
    });

    // ✅ REAL-TIME EXPENSES TOTAL
    _expensesSubscription = FirebaseFirestore.instance
        .collection('expenses')
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen((expensesSnapshot) {
      _totalExpenses = expensesSnapshot.docs.fold(0.0, (sum, doc) {
        final data = doc.data();
        return sum + (data['amount'] ?? 0).toDouble();
      });
      _recalculateBalance();
    });
  }

  // 🆕 RECALCULATE BALANCE
  void _recalculateBalance() {
    _fundBalance = _totalContributions - _totalExpenses;
    notifyListeners();
  }

  // 🆕 STOP REAL-TIME FINANCIALS
  void _stopRealTimeFinancials() {
    _contributionsSubscription?.cancel();
    _expensesSubscription?.cancel();
    _contributionsSubscription = null;
    _expensesSubscription = null;
  }

  // 🆕 GET FINANCIAL SUMMARY (One-time calculation)
  Future<Map<String, double>> getFinancialSummary(String communityId) async {
    try {
      // Get total contributions
      final contributionsSnapshot = await FirebaseFirestore.instance
          .collection('contributions')
          .where('communityId', isEqualTo: communityId)
          .get();

      double totalCollected = contributionsSnapshot.docs.fold(0.0, (sum, doc) {
        return sum + (doc.data()['amount'] ?? 0).toDouble();
      });

      // Get total expenses
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('communityId', isEqualTo: communityId)
          .where('status', isEqualTo: 'approved')
          .get();

      double totalExpenses = expensesSnapshot.docs.fold(0.0, (sum, doc) {
        return sum + (doc.data()['amount'] ?? 0).toDouble();
      });

      return {
        'totalCollected': totalCollected,
        'totalExpenses': totalExpenses,
        'fundBalance': totalCollected - totalExpenses,
      };
    } catch (e) {
      throw Exception('Failed to get financial summary: $e');
    }
  }

// ✅ ALL COMMUNITIES REQUIRE MANUAL APPROVAL
Future<bool> createCommunity({
  required String name,
  required String adminId,
  required String adminEmail,
  required String adminName,
  required String type,
  String? description,
  String? location,
  String? logoUrl,
}) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    // Validate community type
    if (!CommunityType.isValidType(type)) {
      _error = 'Invalid community type. Please select a valid type.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Generate better default description based on type
    final defaultDescription = description ?? 
        '${CommunityType.getDescription(type)} - ${name.trim()}';

    final community = await _communityService.createCommunity(
      name: name.trim(),
      type: type,
      description: defaultDescription,
      adminEmail: adminEmail,
      adminId: adminId,
      adminName: adminName,
      location: location,
      logoUrl: logoUrl,
    );

    _currentCommunity = community;
    
    _isLoading = false;
    notifyListeners();
    return true;
  } catch (e) {
    _error = 'Failed to create community: $e';
    _isLoading = false;
    notifyListeners();
    return false;
  }
}

  // ✅ Regenerate invite code using the service
  Future<bool> regenerateInviteCode(String communityId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _communityService.regenerateInviteCode(communityId);
      
      // Reload the current community to get updated invite code
      if (_currentCommunity?.communityId == communityId) {
        await loadCurrentCommunity(communityId);
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to regenerate invite code: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ Load current community by ID
  Future<void> loadCurrentCommunity(String communityId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final community = await _communityService.getCommunityById(communityId);
      _currentCommunity = community;
      
      // 🆕 START REAL-TIME FINANCIAL STREAMS
      _startRealTimeFinancials(communityId);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load community: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Load user's communities
  Future<void> loadUserCommunities(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userCommunities = await _communityService.getUserCommunities(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load user communities: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Load community members stream
  Future<void> loadCommunityMembers(String communityId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cancel existing subscription
      _membersSubscription?.cancel();
      
      // Listen to the stream
      _membersSubscription = _communityService.getCommunityMembers(communityId).listen(
        (members) {
          _communityMembers = members;
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          _error = 'Failed to load community members: $error';
          _isLoading = false;
          notifyListeners();
        }
      );
    } catch (e) {
      _error = 'Failed to load community members: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
// ✅ Join community by invite code - ALL MANUAL APPROVAL
Future<bool> joinCommunityByCode({
  required String code,
  required String userId,
  required String userEmail,
  required String userName,
}) async {
  try {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // ✅ 1. Validate community code
    final query = await FirebaseFirestore.instance
        .collection('communities')
        .where('inviteCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      _error = 'Invalid community code';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final communityDoc = query.docs.first;
    final communityId = communityDoc.id;
    final communityData = communityDoc.data();

    // ✅ 2. Check if user already has a community
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final currentUserData = userDoc.data();

    if (currentUserData?['communityId'] != null && currentUserData!['communityId'].isNotEmpty) {
      _error = 'You are already a member of another community. Please leave it first.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // ✅ 3. Update user document - ALL USERS START AS NOT APPROVED
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    await userRef.update({
      'communityId': communityId,
      'communityCode': code.trim().toUpperCase(),
      'isApproved': false, // ✅ ALL new members require manual approval
      'role': 'member',
      'joinedAt': Timestamp.now(),
      // ❌ NO approvedAt field - will be added when admin approves
    });

    // ✅ 4. Add user to community members subcollection as pending
    final memberRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(userId);
    await memberRef.set({
      'userId': userId,
      'email': userEmail,
      'name': userName,
      'role': 'member',
      'isApproved': false, // ✅ Pending approval
      'joinedAt': Timestamp.now(),
      // ❌ NO approvedAt field - will be added when admin approves
    });

    // ✅ 5. Update pending members count in community
    final communityRef = FirebaseFirestore.instance.collection('communities').doc(communityId);
    await communityRef.update({
      'pendingMembers': FieldValue.increment(1), // ✅ Always add to pending
      // ❌ NO auto-increment to totalMembers - only when approved
    });

    // ✅ 6. Update local state
    _currentCommunity = CommunityModel.fromMap(communityData, communityId);
    _isLoading = false;
    notifyListeners();
    return true;
  } catch (e) {
    _error = 'Failed to join community: $e';
    _isLoading = false;
    notifyListeners();
    return false;
  }
}

  // ✅ Update community details
  Future<bool> updateCommunity({
    required String communityId,
    required String name,
    required String type,
    required String description,
    String? location,
    Map<String, dynamic>? settings,
    String? logoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _communityService.updateCommunity(
        communityId: communityId,
        name: name,
        type: type,
        description: description,
        location: location,
        settings: settings,
        logoUrl: logoUrl,
      );

      // Reload the current community if it's the one being updated
      if (_currentCommunity?.communityId == communityId) {
        await loadCurrentCommunity(communityId);
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update community: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ Delete community
  Future<bool> deleteCommunity(String communityId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _communityService.deleteCommunity(communityId);
      
      // Clear current community if it's the one being deleted
      if (_currentCommunity?.communityId == communityId) {
        _currentCommunity = null;
        _stopRealTimeFinancials(); // 🆕 STOP FINANCIAL STREAMS
      }
      
      // Remove from user communities list
      _userCommunities.removeWhere((community) => community.communityId == communityId);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete community: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ Update member role
  Future<bool> updateMemberRole({
    required String communityId,
    required String userId,
    required String role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _communityService.updateMemberRole(
        communityId: communityId,
        userId: userId,
        role: role,
      );
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update member role: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ Remove member from community
  Future<bool> removeMember(String communityId, String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _communityService.removeMemberFromCommunity(communityId, userId);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to remove member: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ✅ Clear current community
  void clearCurrentCommunity() {
    _currentCommunity = null;
    _stopRealTimeFinancials(); // 🆕 STOP FINANCIAL STREAMS
    _totalContributions = 0;
    _totalExpenses = 0;
    _fundBalance = 0;
    notifyListeners();
  }

  // ✅ Set current community
  void setCurrentCommunity(CommunityModel community) {
    _currentCommunity = community;
    notifyListeners();
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
    _stopRealTimeFinancials(); // 🆕 ADD THIS
    super.dispose();
  }
}