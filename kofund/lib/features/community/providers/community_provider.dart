import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/services/community_firestore_service.dart';
import 'package:kofund/features/community/models/community_model.dart';
import 'package:kofund/core/constants/community_types.dart';
import 'package:kofund/core/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';

class CommunityProvider with ChangeNotifier {
  final CommunityFirestoreService _communityService;
  final StorageService _storageService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  CommunityModel? _currentCommunity;
  List<CommunityModel> _userCommunities = [];
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _communityMembers = [];
  StreamSubscription<List<Map<String, dynamic>>>? _membersSubscription;

  // Real-time financial fields
  double _totalContributions = 0;
  double _totalExpenses = 0;
  double _fundBalance = 0;
  StreamSubscription? _contributionsSubscription;
  StreamSubscription? _expensesSubscription;

  // Invite functionality fields
  String? _inviteLink;
  String? _inviteCode;
  bool _isAdmin = false;
  bool _canInvite = false;
  Map<String, dynamic> _inviteStats = {};

  // Monthly Program Financial Stats
  double _monthlyProgramBalance = 0;
  int _monthlyProgramParticipants = 0;
  double _monthlyProgramCollected = 0;

  CommunityProvider(this._communityService, this._storageService);

  // Getters
  CommunityModel? get currentCommunity => _currentCommunity;
  List<CommunityModel> get userCommunities => _userCommunities;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get communityMembers => _communityMembers;
  String? get communityId => _currentCommunity?.communityId;
  
  // Financial getters
  double get totalContributions => _totalContributions;
  double get totalExpenses => _totalExpenses;
  double get fundBalance => _fundBalance;
  
  // Monthly program getters
  double get monthlyProgramBalance => _monthlyProgramBalance;
  int get monthlyProgramParticipants => _monthlyProgramParticipants;
  double get monthlyProgramCollected => _monthlyProgramCollected;
  
  // Invite functionality getters
  String? get inviteLink => _inviteLink;
  String? get inviteCode => _inviteCode;
  bool get isAdmin => _isAdmin;
  bool get canInvite => _canInvite;
  Map<String, dynamic> get inviteStats => _inviteStats;

  // ================================================================
  // INVITE FUNCTIONALITY METHODS
  // ================================================================

  /// 🎯 Get or create invite link for community
  Future<String> getInviteLink(String communityId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _inviteLink = await _communityService.getOrCreateInviteLink(communityId);
      
      // Also get invite code
      await _getInviteCode(communityId);
      
      _isLoading = false;
      notifyListeners();
      return _inviteLink!;
    } catch (e) {
      _error = 'Failed to get invite link: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

Future<void> regenerateInviteCode(String communityId) async {
  try {
    _isLoading = true;
    notifyListeners();

    // Check if user is admin
    await checkInvitePermission(communityId); // ← CHANGE TO checkInvitePermission (remove underscore)
    
    if (!_canInvite) {
      throw Exception('Only admins can regenerate invite code');
    }

    await _communityService.regenerateInviteCodeAndLink(communityId);
    
    // Refresh invite info
    await getInviteLink(communityId);
    
    notifyListeners();
  } catch (e) {
    _error = 'Failed to regenerate invite code: $e';
    _isLoading = false;
    notifyListeners();
    rethrow;
  } finally {
    _isLoading = false;
  }
}

  /// 👥 Join community using invite code
  Future<void> joinCommunityWithCode({
    required String inviteCode,
    required String userEmail,
    required String userName,
    String? userId, // Optional - if not provided, will get from auth
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // If userId not provided, try to get it from current user context
      // You'll need to pass this from the calling function with auth provider
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID is required');
      }

      await _communityService.joinCommunityWithCode(
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        inviteCode: inviteCode.trim().toUpperCase(),
      );

      _isLoading = false;
      notifyListeners();
      
      // Clear error after successful join
      _error = null;
    } catch (e) {
      _error = 'Failed to join community: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 🔗 Join community using invite link
  Future<void> joinCommunityWithLink({
    required String inviteLink,
    required String userEmail,
    required String userName,
    String? userId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (userId == null || userId.isEmpty) {
        throw Exception('User ID is required');
      }

      await _communityService.joinCommunityWithLink(
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        inviteLink: inviteLink,
      );

      _isLoading = false;
      notifyListeners();
      _error = null;
    } catch (e) {
      _error = 'Failed to join community: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 🔍 Check if current user can invite members
  Future<void> checkInvitePermission(String communityId, {String? userId}) async {
    try {
      // 🚀 OPTIMIZATION: Use communityMembers which is already in memory
      if (_communityMembers.isNotEmpty && userId != null) {
        final currentUserMember = _communityMembers.firstWhere(
          (m) => m['userId'] == userId,
          orElse: () => {},
        );
        
        if (currentUserMember.isNotEmpty) {
          final role = currentUserMember['role'] ?? 'member';
          _canInvite = role == 'admin';
          _isAdmin = _canInvite;
          notifyListeners();
          return;
        }
      }
      
      // Fallback - check using service only if absolutely necessary
      if (userId != null) {
        _canInvite = await _communityService.canUserInviteMembers(
          userId: userId,
          communityId: communityId,
        );
        _isAdmin = _canInvite;
      } else {
        _canInvite = false;
        _isAdmin = false;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking invite permission: $e');
      _canInvite = false;
      _isAdmin = false;
      notifyListeners();
    }
  }

  /// 📊 Get community invite statistics
  Future<void> getInviteStatistics(String communityId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _inviteStats = await _communityService.getInviteStats(communityId);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to get invite statistics: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 🔑 Get invite code for community
  Future<void> _getInviteCode(String communityId) async {
    try {
      final community = await _communityService.getCommunityById(communityId);
      if (community != null) {
        _inviteCode = community.inviteCode;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error getting invite code: $e');
    }
  }

  /// 👤 Helper to get current user from community members
  Map<String, dynamic>? _getCurrentUserFromMembers() {
    // This should be implemented with actual user ID from auth
    // For now, returns null - you need to pass userId when calling checkInvitePermission
    return null;
  }

  // ================================================================
  // EXISTING METHODS (Updated)
  // ================================================================

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
      
      // Set admin permissions for the creator
      _isAdmin = true;
      _canInvite = true;
      
      // Get invite info for the new community
      _inviteCode = community.inviteCode;
      _inviteLink = community.inviteLink;
      
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

  // ✅ Load current community by ID
  Future<void> loadCurrentCommunity(String communityId, {String? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 🚀 OPTIMIZATION: Fetch community once
      final community = await _communityService.getCommunityById(communityId);
      if (community == null) {
        _error = 'Community not found';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      _currentCommunity = community;
      
      // Set invite info from the already loaded model
      _inviteCode = community.inviteCode;
      _inviteLink = community.inviteLink;
      
      // Start real-time streams
      _startRealTimeFinancials(communityId);
      
      // 🚀 OPTIMIZATION: Use the data we already have to populate stats initially
      _inviteStats = {
        'inviteCode': community.inviteCode,
        'inviteLink': community.inviteLink,
        'totalMembers': community.totalMembers,
        'pendingMembers': community.pendingMembers,
        'lastRefreshed': community.createdAt,
      };
      
      // 🔥 Trigger member load which will then trigger permission check if userId provided
      await loadCommunityMembers(communityId);
      
      if (userId != null) {
        // This now uses in-memory member list if available
        await checkInvitePermission(communityId, userId: userId);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load community: $e';
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

      // Use the new service method
      await joinCommunityWithCode(
        inviteCode: code,
        userEmail: userEmail,
        userName: userName,
        userId: userId,
      );

      // Load the community after joining
      await loadCurrentCommunityByCode(code);
      
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

  /// 🔍 Load current community by invite code
  Future<void> loadCurrentCommunityByCode(String inviteCode) async {
    try {
      final community = await _communityService.getCommunityByCode(inviteCode);
      if (community != null) {
        _currentCommunity = community;
        _inviteCode = community.inviteCode;
        _inviteLink = community.inviteLink;
        
        // Start real-time streams
        _startRealTimeFinancials(community.communityId);
        
        // Check permissions
        await checkInvitePermission(community.communityId);
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading community by code: $e');
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

  // ✅ Upload community logo with size validation & compression
  static const int _maxLogoSizeBytes = 2 * 1024 * 1024; // 2 MB hard limit

  Future<bool> pickAndUploadLogo(String communityId) async {
    try {
      // Step 1: Pick from gallery
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90, // High quality before crop
      );

      if (image == null) return false; // User cancelled picker

      // Step 2: Crop to square (1:1 ratio — perfect for circular logo)
      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Logo',
            toolbarColor: const Color(0xFF00BFA6), // KoFund teal
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFF00BFA6),
            lockAspectRatio: true,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'Crop Logo',
            aspectRatioLockEnabled: true,
            minimumAspectRatio: 1.0,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (cropped == null) return false; // User cancelled crop

      // Step 3: Check file size AFTER crop + compression
      final File croppedFile = File(cropped.path);
      final int fileSizeBytes = await croppedFile.length();
      const double limitMb = _maxLogoSizeBytes / (1024 * 1024);

      if (fileSizeBytes > _maxLogoSizeBytes) {
        _error = 'Image is too large (${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB). '
                 'Please choose an image smaller than ${limitMb.toStringAsFixed(0)} MB.';
        notifyListeners();
        return false;
      }

      debugPrint('📸 Uploading logo: ${(fileSizeBytes / 1024).toStringAsFixed(1)} KB');

      _isLoading = true;
      _error = null;
      notifyListeners();

      // Step 4: Upload to Firebase Storage
      final String logoUrl = await _storageService.uploadCommunityLogo(
        communityId,
        croppedFile,
      );

      // Step 5: Persist URL to Firestore
      await _communityService.updateCommunity(
        communityId: communityId,
        logoUrl: logoUrl,
        name: _currentCommunity?.name ?? '',
        type: _currentCommunity?.type ?? CommunityType.other,
        description: _currentCommunity?.description ?? '',
      );

      // Step 6: Reload live data
      await loadCurrentCommunity(communityId);

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ Community logo updated successfully');
      return true;
    } catch (e) {
      _error = 'Failed to upload logo: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Logo upload failed: $e');
      return false;
    }
  }

  // ================================================================
  // FINANCIAL METHODS (Existing - Keep as is)
  // ================================================================

  // 🆕 Method to load monthly program stats
  Future<void> loadMonthlyProgramStats(String communityId) async {
    try {
      // Get all programs for the community
      final programs = await _firestore
          .collection('programs')
          .where('communityId', isEqualTo: communityId)
          .get();

      // Find the monthly payment program
      QueryDocumentSnapshot? monthlyProgram;
      try {
        monthlyProgram = programs.docs.firstWhere(
          (doc) => doc.data()['isMonthlyPaymentProgram'] == true,
        );
      } catch (e) {
        monthlyProgram = null;
      }

      if (monthlyProgram != null) {
        final programData = monthlyProgram.data();
        final programId = monthlyProgram.id;

        // Get participants count
        final participantsSnapshot = await _firestore
            .collection('participants')
            .where('programId', isEqualTo: programId)
            .where('status', isEqualTo: 'joined')
            .get();

        _monthlyProgramParticipants = participantsSnapshot.docs.length;

        // Get total contributions
        final contributionsSnapshot = await _firestore
            .collection('contributions')
            .where('programId', isEqualTo: programId)
            .get();

        _monthlyProgramCollected = contributionsSnapshot.docs.fold(0.0, (sum, doc) {
          return sum + (doc.data()['amount'] ?? 0).toDouble();
        });

        // Get expenses
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
        _monthlyProgramBalance = 0;
        _monthlyProgramParticipants = 0;
        _monthlyProgramCollected = 0;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading monthly program stats: $e');
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
        
        // Load invite statistics
        await getInviteStatistics(_currentCommunity!.communityId);
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
    _stopRealTimeFinancials();

    // Real-time contributions total
    _contributionsSubscription = _firestore
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

    // Real-time expenses total
    _expensesSubscription = _firestore
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
      final contributionsSnapshot = await _firestore
          .collection('contributions')
          .where('communityId', isEqualTo: communityId)
          .get();

      double totalCollected = contributionsSnapshot.docs.fold(0.0, (sum, doc) {
        return sum + (doc.data()['amount'] ?? 0).toDouble();
      });

      // Get total expenses
      final expensesSnapshot = await _firestore
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

  // ================================================================
  // OTHER EXISTING METHODS (Keep as is)
  // ================================================================

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

  Future<void> loadCommunityMembers(String communityId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _membersSubscription?.cancel();
      
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

  Future<bool> deleteCommunity(String communityId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _communityService.deleteCommunity(communityId);
      
      if (_currentCommunity?.communityId == communityId) {
        _currentCommunity = null;
        _stopRealTimeFinancials();
        _inviteLink = null;
        _inviteCode = null;
        _isAdmin = false;
        _canInvite = false;
      }
      
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
    _stopRealTimeFinancials();
    _totalContributions = 0;
    _totalExpenses = 0;
    _fundBalance = 0;
    _inviteLink = null;
    _inviteCode = null;
    _isAdmin = false;
    _canInvite = false;
    _inviteStats = {};
    notifyListeners();
  }

  // ✅ Set current community
  void setCurrentCommunity(CommunityModel community) {
    _currentCommunity = community;
    _inviteCode = community.inviteCode;
    _inviteLink = community.inviteLink;
    notifyListeners();
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
    _stopRealTimeFinancials();
    super.dispose();
  }
}

