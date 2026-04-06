import 'package:flutter/foundation.dart';

import 'package:kofund/features/community/models/community_model.dart';
import 'package:kofund/features/programs/models/program_model.dart';

import 'package:kofund/core/services/community_firestore_service.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/contribution_service.dart';
import 'package:kofund/core/services/program_service.dart';
import 'package:kofund/core/services/expense_service.dart';

class DashboardProvider with ChangeNotifier {
  final CommunityFirestoreService _communityService;
  final UserService _userService;
  final ContributionService _contributionService;
  final ProgramService _programService;
  final ExpenseService _expenseService;

  DashboardProvider({
    required CommunityFirestoreService communityService,
    required UserService userService,
    required ContributionService contributionService,
    required ProgramService programService,
    required ExpenseService expenseService,
  })  : _communityService = communityService,
        _userService = userService,
        _contributionService = contributionService,
        _programService = programService,
        _expenseService = expenseService;

  // -------------------------
  // STATE
  // -------------------------

  CommunityModel? _currentCommunity;
  ProgramModel? _monthlyPaymentProgram;

  // 👉 ONLY FOR MONTHLY PAYMENT PROGRAM
  double _monthlyProgramBalance = 0.0;
  double _monthlyProgramCollected = 0.0;
  double _monthlyProgramExpenses = 0.0;
  int _monthlyProgramContributors = 0;

  // Other Data
  int _approvedMembersCount = 0;

  bool _isLoading = false;
  String _errorMessage = '';

  // -------------------------
  // GETTERS
  // -------------------------

  CommunityModel? get currentCommunity => _currentCommunity;
  ProgramModel? get monthlyPaymentProgram => _monthlyPaymentProgram;

  // 👉 ONLY FOR MONTHLY PAYMENT PROGRAM
  double get monthlyProgramBalance => _monthlyProgramBalance;
  double get monthlyProgramCollected => _monthlyProgramCollected;
  double get monthlyProgramExpenses => _monthlyProgramExpenses;
  int get monthlyProgramContributors => _monthlyProgramContributors;

  // Other Getters
  int get approvedMembersCount => _approvedMembersCount;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // -------------------------
  // LOAD DASHBOARD
  // -------------------------
Future<void> loadDashboardData(String communityId) async {
  // ✅ SAFETY CHECK: Prevent multiple simultaneous loads
  if (_isLoading) {
    debugPrint('⏳ DEBUG: Dashboard data load already in progress, skipping...');
    return;
  }
  
  try {
    _setLoading(true);
    _errorMessage = '';

    debugPrint('🔄 DEBUG: Loading dashboard data for community: $communityId');
    
    // 1. COMMUNITY DETAILS
    await _loadCommunityDetails(communityId);

    // 2. APPROVED MEMBERS COUNT
    await _loadApprovedMembersCount(communityId);

    // 3. 👉 MONTHLY PAYMENT PROGRAM & ITS FINANCIALS
    await _loadMonthlyPaymentProgram(communityId);
    
    // 👉 ONLY load financials if monthly payment program exists
    if (_monthlyPaymentProgram != null) {
      await _loadMonthlyProgramFinancials(_monthlyPaymentProgram!.programId);
    } else {
      // 👉 RESET financial data if no monthly program
      _resetMonthlyProgramFinancials();
    }

    debugPrint('✅ DEBUG: Dashboard data loaded successfully');
    notifyListeners();
  } catch (e) {
    _errorMessage = 'Failed to load dashboard data: $e';
    debugPrint('❌ DEBUG: Dashboard load error: $e');
    notifyListeners();
  } finally {
    _setLoading(false);
  }
}

  // -------------------------
  // COMMUNITY
  // -------------------------
  Future<void> _loadCommunityDetails(String communityId) async {
    _currentCommunity = await _communityService.getCommunityById(communityId);

    if (_currentCommunity == null) {
      throw Exception('Community not found');
    }
  }

  // -------------------------
  // 👉 MONTHLY PAYMENT PROGRAM - ONLY THIS!
  // -------------------------
  Future<void> _loadMonthlyPaymentProgram(String communityId) async {
    final programs = await _programService.getProgramsByCommunity(communityId);

    try {
      // 👉 ONLY look for programs where isMonthlyPaymentProgram == true
      _monthlyPaymentProgram = programs.firstWhere(
        (p) => p.isMonthlyPaymentProgram == true
      );
      debugPrint('✅ Found monthly payment program: ${_monthlyPaymentProgram!.title}');
    } catch (_) {
      // 👉 NO monthly payment program found
      _monthlyPaymentProgram = null;
      debugPrint('ℹ️ No monthly payment program found in this community');
    }
  }

  // -------------------------
  // APPROVED MEMBERS
  // -------------------------
  Future<void> _loadApprovedMembersCount(String communityId) async {
    final members = await _userService.getUsersByCommunity(communityId);
    _approvedMembersCount = members.where((u) => u.isApproved == true).length;
  }

  // -------------------------
  // 👉 MONTHLY PROGRAM FINANCIALS - ONLY FOR MONTHLY PAYMENT PROGRAM
  // -------------------------
  Future<void> _loadMonthlyProgramFinancials(String programId) async {
    try {
      debugPrint('💰 Loading financials for monthly payment program: $programId');
      
      // 👉 ONLY get financial data for the monthly payment program
      final contributions = await _contributionService.getProgramTotalContributions(programId);
      final expenses = await _expenseService.getProgramTotalExpenses(programId);
      final contributors = await _getMonthlyProgramContributorsCount(programId);

      _monthlyProgramCollected = contributions;
      _monthlyProgramExpenses = expenses;
      _monthlyProgramBalance = contributions - expenses;
      _monthlyProgramContributors = contributors;

      debugPrint('💰 Monthly Program Financials - Collected: $contributions, Expenses: $expenses, Balance: $_monthlyProgramBalance');

    } catch (e) {
      debugPrint('❌ Error loading monthly program financials: $e');
      _errorMessage = 'Failed to load monthly program financials: $e';
      // Reset to defaults on error
      _resetMonthlyProgramFinancials();
    }
  }

  Future<int> _getMonthlyProgramContributorsCount(String programId) async {
    try {
      // Get all contributions for the monthly program and count unique users
      final contributions = await _contributionService.getProgramContributions(programId);
      final uniqueUserIds = <String>{};
      
      for (final contribution in contributions) {
        uniqueUserIds.add(contribution.userId);
      }
      
      return uniqueUserIds.length;
    } catch (e) {
      return 0;
    }
  }

  void _resetMonthlyProgramFinancials() {
    _monthlyProgramCollected = 0.0;
    _monthlyProgramExpenses = 0.0;
    _monthlyProgramBalance = 0.0;
    _monthlyProgramContributors = 0;
    debugPrint('💰 Reset monthly program financials to zero');
  }

  // -------------------------
  // 👉 FINANCIAL DETAILS GETTERS - ONLY FOR MONTHLY PAYMENT PROGRAM
  // -------------------------

  // Get monthly program progress percentage
  double get monthlyProgramProgressPercentage {
    if (_monthlyPaymentProgram == null) return 0.0;
    
    final target = _monthlyPaymentProgram!.suggestedContribution ?? 0.0;
    if (target <= 0) return 0.0;
    
    return (_monthlyProgramCollected / target) * 100;
  }

  // Get monthly program target amount
  double get monthlyProgramTarget {
    return _monthlyPaymentProgram?.suggestedContribution ?? 0.0;
  }

  // 👉 Check if we have a monthly payment program
  bool get hasMonthlyPaymentProgram {
    return _monthlyPaymentProgram != null;
  }

  // -------------------------
  // STATS FOR UI
  // -------------------------
  Map<String, dynamic> getDashboardStats() {
    return {
      // Community Info
      'clubName': _currentCommunity?.name ?? '',
      'clubType': _currentCommunity?.type ?? '',
      'membersCount': _approvedMembersCount,
      
      // 👉 MONTHLY PROGRAM FINANCIAL DATA - ONLY if monthly program exists
      'monthlyBalance': _monthlyProgramBalance,
      'monthlyCollected': _monthlyProgramCollected,
      'monthlyExpenses': _monthlyProgramExpenses,
      'monthlyContributors': _monthlyProgramContributors,
      'monthlyProgress': monthlyProgramProgressPercentage,
      'monthlyTarget': monthlyProgramTarget,
      
      // 👉 PROGRAM STATUS
      'hasMonthlyProgram': _monthlyPaymentProgram != null,
    };
  }

  // -------------------------
  // REFRESH
  // -------------------------
  Future<void> refreshDashboard(String communityId) async {
    await loadDashboardData(communityId);
  }

  // Refresh only monthly program financial data
  Future<void> refreshMonthlyProgramFinancials() async {
    if (_monthlyPaymentProgram != null) {
      await _loadMonthlyProgramFinancials(_monthlyPaymentProgram!.programId);
      notifyListeners();
    }
  }

  // -------------------------
  // HELPERS
  // -------------------------
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // Clear all data (for logout)
  void clearData() {
    _currentCommunity = null;
    _monthlyPaymentProgram = null;
    _resetMonthlyProgramFinancials();
    _approvedMembersCount = 0;
    _errorMessage = '';
    notifyListeners();
  }
}

