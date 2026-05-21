import 'package:flutter/foundation.dart';

import 'package:kofund/features/community/models/community_model.dart';
import 'package:kofund/features/events/models/event_model.dart';

import 'package:kofund/core/services/community_firestore_service.dart';
import 'package:kofund/core/services/user_service.dart';
import 'package:kofund/core/services/contribution_service.dart';
import 'package:kofund/core/services/event_service.dart';
import 'package:kofund/core/services/expense_service.dart';

class DashboardProvider with ChangeNotifier {
  final CommunityFirestoreService _communityService;
  final UserService _userService;
  final ContributionService _contributionService;
  final  EventService _eventService;
  final ExpenseService _expenseService;

  DashboardProvider({
    required CommunityFirestoreService communityService,
    required UserService userService,
    required ContributionService contributionService,
    required EventService eventService,
    required ExpenseService expenseService,
  })  : _communityService = communityService,
        _userService = userService,
        _contributionService = contributionService,
        _eventService = eventService,
        _expenseService = expenseService;

  // -------------------------
  // STATE
  // -------------------------

  // -------------------------
  // STATE
  // -------------------------

  CommunityModel? _currentCommunity;
  EventModel? _monthlyPayment;

  // 👉 ONLY FOR MONTHLY PAYMENT event
  double _monthlyBalance = 0.0;
  double _monthlyCollected = 0.0;
  double _monthlyExpenses = 0.0;
  int _monthlyContributors = 0;

  // Other Data
  int _approvedMembersCount = 0;

  bool _isLoading = false;
  String _errorMessage = '';

  // -------------------------
  // GETTERS
  // -------------------------

  CommunityModel? get currentCommunity => _currentCommunity;
  EventModel? get monthlyPayment => _monthlyPayment;

  // 👉 ONLY FOR MONTHLY PAYMENT event
  double get monthlyBalance => _monthlyBalance;
  double get monthlyCollected => _monthlyCollected;
  double get monthlyExpenses => _monthlyExpenses;
  int get monthlyContributors => _monthlyContributors;

  // Other Getters
  int get approvedMembersCount => _approvedMembersCount;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // -------------------------
  // LOAD DASHBOARD
  // -------------------------
Future<void> loadDashboardData(String communityId) async {
  // ✅ SAFETY CHECK: P multiple simultaneous loads
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

    // 3. 👉 MONTHLY PAYMENT event & ITS FINANCIALS
    await _loadMonthlyPayment(communityId);
    
    // 👉 ONLY load financials if monthly payment event exists
    if (_monthlyPayment != null) {
      await _loadMonthlyFinancials(_monthlyPayment!.eventId, communityId);
    } else {
      // 👉 RESET financial data if no monthly event
      _resetMonthlyFinancials();
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
  // 👉 MONTHLY PAYMENT event - ONLY THIS!
  // -------------------------
  Future<void> _loadMonthlyPayment(String communityId) async {
    final events = await _eventService.getEventsByCommunity(communityId);

    try {
      // 👉 ONLY look for events where isMonthlyPayment == true
      _monthlyPayment = events.firstWhere(
        (p) => p.isMonthlyPayment == true
      );
      debugPrint('✅ Found monthly payment event: ${_monthlyPayment!.title}');
    } catch (_) {
      // 👉 NO monthly payment event found
      _monthlyPayment = null;
      debugPrint('ℹ️ No monthly payment event found in this community');
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
  // 👉 MONTHLY event FINANCIALS - ONLY FOR MONTHLY PAYMENT event
  // -------------------------
  Future<void> _loadMonthlyFinancials(String eventId, String communityId) async {
    try {
      debugPrint('💰 Loading financials for monthly payment event: $eventId');
      
      // 👉 ONLY get financial data for the monthly payment event
      final contributions = await _contributionService.getTotalContributions(eventId, communityId: communityId);
      final expenses = await _expenseService.getEventTotalExpenses(eventId, communityId: communityId);
      final contributors = await _getMonthlyContributorsCount(eventId, communityId: communityId);

      _monthlyCollected = contributions;
      _monthlyExpenses = expenses;
      _monthlyBalance = contributions - expenses;
      _monthlyContributors = contributors;

      debugPrint('💰 Monthly event Financials - Collected: $contributions, Expenses: $expenses, Balance: $_monthlyBalance');

    } catch (e) {
      debugPrint('❌ Error loading monthly event financials: $e');
      _errorMessage = 'Failed to load monthly event financials: $e';
      // Reset to defaults on error
      _resetMonthlyFinancials();
    }
  }

  Future<int> _getMonthlyContributorsCount(String eventId, {String? communityId}) async {
    try {
      // Get all contributions for the monthly event and count unique users
      final contributions = await _contributionService.getContributions(eventId, communityId: communityId);
      final uniqueUserIds = <String>{};
      
      for (final contribution in contributions) {
        uniqueUserIds.add(contribution.userId);
      }
      
      return uniqueUserIds.length;
    } catch (e) {
      return 0;
    }
  }

  void _resetMonthlyFinancials() {
    _monthlyCollected = 0.0;
    _monthlyExpenses = 0.0;
    _monthlyBalance = 0.0;
    _monthlyContributors = 0;
    debugPrint('💰 Reset monthly event financials to zero');
  }

  // -------------------------
  // 👉 FINANCIAL DETAILS GETTERS - ONLY FOR MONTHLY PAYMENT event
  // -------------------------

  // Get monthly event progress percentage
  double get monthlyProgressPercentage {
    if (_monthlyPayment == null) return 0.0;
    
    final target = _monthlyPayment!.suggestedContribution ?? 0.0;
    if (target <= 0) return 0.0;
    
    return (_monthlyCollected / target) * 100;
  }

  // Get monthly event target amount
  double get monthlyTarget {
    return _monthlyPayment?.suggestedContribution ?? 0.0;
  }

  // 👉 Check if we have a monthly payment event
  bool get hasMonthlyPayment {
    return _monthlyPayment != null;
  }

  // -------------------------
  // STATS FOR UI
  // -------------------------
  Map<String, dynamic> getDashboardStats() {
    return {
      // Community Info
      'clubName': _currentCommunity?.name ?? '',
      'clubLogo': _currentCommunity?.logoUrl,
      'clubTeventType': _currentCommunity?.type ?? '',
      'membersCount': _approvedMembersCount,
      
      // 👉 MONTHLY event FINANCIAL DATA - ONLY if monthly event exists
      'monthlyBalance': _monthlyBalance,
      'monthlyCollected': _monthlyCollected,
      'monthlyExpenses': _monthlyExpenses,
      'monthlyContributors': _monthlyContributors,
      'monthlyProgress': monthlyProgressPercentage,
      'monthlyTarget': monthlyTarget,
      
      // 👉 event STATUS
      'hasMonthl': _monthlyPayment != null,
    };
  }

  // -------------------------
  // REFRESH
  // -------------------------
  Future<void> refreshDashboard(String communityId) async {
    await loadDashboardData(communityId);
  }

  // Refresh only monthly event financial data
  Future<void> refreshMonthlyFinancials() async {
    if (_monthlyPayment != null && _currentCommunity != null) {
      await _loadMonthlyFinancials(_monthlyPayment!.eventId, _currentCommunity!.communityId);
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
    _monthlyPayment = null;
    _resetMonthlyFinancials();
    _approvedMembersCount = 0;
    _errorMessage = '';
    notifyListeners();
  }
}






