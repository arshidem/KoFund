import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/participant_service.dart';
import '../../../core/services/contribution_service.dart';
import '../../../core/services/event_service.dart';
import '../../../core/services/expense_service.dart';
import 'dart:async';
import '../models/event_model.dart';
import 'package:intl/intl.dart';
import '../../participants/models/participant_model.dart';
import '../../contributions/models/contribution_model.dart';
import '../../expenses/models/expense_model.dart';

class EventProvider with ChangeNotifier {
  final EventService _eventService;
  final ParticipantService _participantService;
  final ContributionService _contributionService;
  final ExpenseService _expenseService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<EventModel> _events = [];
  List<ParticipantModel> _myParticipations = [];
  bool _isLoading = false;
  String? _error;

  // 🚀 OPTIMIZATION: Caches with TTL
  final Map<String, ({Map<String, dynamic> data, DateTime timestamp})> _summaryCache = {};
  final Map<String, ({List<EventModel> data, DateTime timestamp})> _listCache = {};
  final Duration _cacheTTL = const Duration(minutes: 5);

  List<EventModel> get events => _events;
  String? get error => _error;
  List<ParticipantModel> get myParticipations => _myParticipations;
  bool get isLoading => _isLoading;

  EventProvider({
    required EventService eventService,
    required ParticipantService participantService,
    required ContributionService contributionService,
    required ExpenseService expenseService,
  })  : _eventService = eventService,
        _participantService = participantService,
        _contributionService = contributionService,
        _expenseService = expenseService;

  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void setError(String error) {
    _error = error;
    notifyListeners();
  }

  void clearUserData() {
    _myParticipations.clear();
    _events.clear();
    _summaryCache.clear();
    _listCache.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
    // debugPrint('🔄 EventProvider: User data cleared');
  }

  void clearAllData() {
    clearUserData();
  }

  // ✅ OPTIMIZED: Get event financial summary with Cache
  Future<Map<String, dynamic>> getFinancialSummary(String eventId, {String? communityId, bool forceRefresh = false}) async {
    // 🚀 OPTIMIZATION: Check cache first
    if (!forceRefresh && _summaryCache.containsKey(eventId)) {
      final cached = _summaryCache[eventId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        return cached.data;
      }
    }

    try {
      final effectiveCommunityId = communityId ?? '';
      if (effectiveCommunityId.isEmpty) {
        debugPrint('⚠️ EventProvider: communityId is required for financial summary');
        return _emptySummary();
      }

      final totalContributions = await _eventService.getTotalContributions(eventId, communityId: effectiveCommunityId);
      final totalExpenses = await _eventService.getTotalExpenses(eventId, communityId: effectiveCommunityId);
      final participantCount = await _participantService.getParticipantCount(eventId, communityId: effectiveCommunityId);
      
      final contributions = await _contributionService.getContributions(eventId, communityId: communityId);
      
      final event = await _eventService.getEventById(eventId);
      final suggested = event?.suggestedContribution ?? 0.0;
      
      final totalExpected = suggested * participantCount;
      final collectionRate = totalExpected > 0 ? (totalContributions / totalExpected) * 100 : 0.0;

      final summary = {
        'totalParticipants': participantCount,
        'totalCollected': totalContributions,
        'totalExpenses': totalExpenses,
        'balance': totalContributions - totalExpenses,
        'totalExpected': totalExpected,
        'collectionRate': collectionRate,
        'suggestedContribution': suggested,
        'totalContributions': contributions.length,
        'contributionCount': contributions.length,
      };

      _summaryCache[eventId] = (data: summary, timestamp: DateTime.now());
      return summary;
    } catch (e) {
      debugPrint('❌ Error getting financial summary: $e');
      return _emptySummary();
    }
  }

  Map<String, dynamic> _emptySummary() {
    return {
      'totalParticipants': 0,
      'totalCollected': 0.0,
      'totalExpenses': 0.0,
      'balance': 0.0,
      'totalExpected': 0.0,
      'collectionRate': 0.0,
      'suggestedContribution': 0.0,
      'totalContributions': 0,
      'contributionCount': 0,
    };
  }

  Future<void> loadEvents(String communityId, {bool forceRefresh = false}) async {
    // 🚀 OPTIMIZATION: Check cache
    if (!forceRefresh && _listCache.containsKey(communityId)) {
      final cached = _listCache[communityId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        _events = cached.data;
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();
    try {
      _events = await _eventService.getEventsByCommunity(communityId);
      _listCache[communityId] = (data: _events, timestamp: DateTime.now());
    } catch (e) {
      debugPrint('Error loading events: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<EventModel?> getEventById(String eventId) {
    // 🚀 We can still optimize by emitting the cached version first
    final controller = StreamController<EventModel?>();
    
    // Check cache
    final index = _events.indexWhere((p) => p.eventId == eventId);
    if (index != -1) {
      controller.add(_events[index]);
    }
    
    // Then listen to _firestore for real-time updates
    _eventService.getEventStreamById(eventId).listen((event) {
      if (event != null) {
        final idx = _events.indexWhere((p) => p.eventId == eventId);
        if (idx != -1) {
          _events[idx] = event;
        } else {
          _events.add(event);
        }
        notifyListeners();
      }
      if (!controller.isClosed) {
        controller.add(event);
      }
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    }, onDone: () {
      if (!controller.isClosed) controller.close();
    });
    
    return controller.stream;
  }

  Future<void> update(EventModel event) async {
    try {
      await _eventService.updateModel(event);
      
      // ✅ Invalidate cache and reload
      _listCache.remove(event.communityId);
      _summaryCache.remove(event.eventId);
      
      await loadEvents(event.communityId, forceRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> delete(String eventId) async {
    try {
      final event = await _eventService.getEventById(eventId);
      await _eventService.delete(eventId);
      _events.removeWhere((p) => p.eventId == eventId);
      _summaryCache.remove(eventId);
      if (event != null) {
        _listCache.remove(event.communityId);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // ✅ Stream for participant count
  Stream<int> streamParticipantCount(String eventId, {String? communityId}) {
    return _participantService.streamParticipants(eventId, communityId: communityId)
        .map((participants) => participants.length);
  }

  // ✅ Stream for total contributions (used in lists)
  Stream<double> streamTotalContributions(String eventId, {String? communityId}) {
    var query = _firestore
        .collection('contributions')
        .where('eventId', isEqualTo: eventId);
    
    if (communityId != null && communityId.isNotEmpty) {
      query = query.where('communityId', isEqualTo: communityId);
    }

    return query
        .snapshots()
        .asyncMap((snapshot) async {
          // Use the faster aggregate query even for the stream mapping
          return await _contributionService.getTotalContributions(eventId, communityId: communityId);
        });
  }

  // 📈 NEW: Unified Progress Stream (Handles Monthly vs Global)
  Stream<Map<String, dynamic>> streamProgress(String eventId, {String? communityId}) {
    var contribQuery = _firestore
        .collection('contributions')
        .where('eventId', isEqualTo: eventId);
    
    if (communityId != null && communityId.isNotEmpty) {
      contribQuery = contribQuery.where('communityId', isEqualTo: communityId);
    }

    // 🚀 OPTIMIZATION: Use snapshots to immediately emit locally cached contributions
    return contribQuery
        .snapshots()
        .asyncMap((contribSnapshot) async {
          
      // Fast local document read for event details
      final docRef = _firestore.collection('events').doc(eventId);
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await docRef.get(const GetOptions(source: Source.cache));
      } catch (_) {
        doc = await docRef.get();
      }

      if (!doc.exists) {
        return {
          'collected': 0.0,
          'target': 100.0,
          'percentage': 0.0,
          'participantCount': 0,
          'isMonthlyy': false,
        };
      }
      
      final data = doc.data()!;
      final isMonthlyy = data['isMonthlyPayment'] ?? false;
      final suggestedContribution = (data['suggestedContribution'] ?? 0).toDouble();
      final totalAmount = (data['totalAmount'] ?? 0).toDouble();
      final maxParticipants = (data['maxParticipants'] ?? 0) as int;
      final isFixedParticipants = (data['participantType'] ?? 'fixed') == 'fixed';
      
      // Fast local document read for participant count
      int pCount = (data['currentParticipants'] ?? 0) as int;
      try {
        var pQuery = _firestore
            .collection('participants')
            .where('eventId', isEqualTo: eventId)
            .where('status', isEqualTo: 'joined');
        if (communityId != null && communityId.isNotEmpty) {
          pQuery = pQuery.where('communityId', isEqualTo: communityId);
        }
        final pSnap = await pQuery.get(const GetOptions(source: Source.cache));
        pCount = pSnap.docs.length;
      } catch (_) {
        // Fallback to event document's cached count
      }
      
      double collected = 0.0;
      double target = 0.0;
      
      if (isMonthlyy) {
        // --- Monthly Logic ---
        final currentMonthId = DateFormat('yyyy-MM').format(DateTime.now());
        for (var c in contribSnapshot.docs) {
          final m = c.data();
          if (m['monthId'] == currentMonthId) {
            collected += (m['amount'] ?? 0).toDouble();
          }
        }
        
        target = suggestedContribution * (pCount > 0 ? pCount : 1);
        
      } else {
        // --- Global Logic ---
        for (var c in contribSnapshot.docs) {
          collected += (c.data()['amount'] ?? 0).toDouble();
        }
        
        if (totalAmount > 0) {
          target = totalAmount;
        } else {
          final usedCount = isFixedParticipants ? maxParticipants : pCount;
          target = suggestedContribution * (usedCount > 0 ? usedCount : 1);
        }
      }
      
      final percentage = target > 0 ? (collected / target).clamp(0.0, 1.0) : 0.0;
      
      return {
        'collected': collected,
        'target': target,
        'percentage': percentage,
        'participantCount': pCount,
        'isMonthlyy': isMonthlyy,
        'monthId': isMonthlyy ? DateFormat('yyyy-MM').format(DateTime.now()) : null,
      };
    });
  }

  // 💰 NEW: Expenses stream
  Stream<double> streamExpenses(String eventId, {String? communityId}) {
    var query = _firestore
        .collection('expenses')
        .where('eventId', isEqualTo: eventId);
    
    if (communityId != null && communityId.isNotEmpty) {
      query = query.where('communityId', isEqualTo: communityId);
    }

    return query
        .snapshots()
        .map((snapshot) {
          double total = 0.0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'] ?? 'pending';
            if (status == 'approved' || status == 'completed') {
              total += (data['amount'] ?? 0).toDouble();
            }
          }
          return total;
        });
  }

  // 📊 NEW: Full Financial Summary Stream
  Stream<Map<String, dynamic>> streamFinancialSummary(String eventId, {String? communityId}) {
    // 🚀 IMPROVEMENT: Trigger summary on participant, contribution OR expense changes
    final controller = StreamController<Map<String, dynamic>>();
    
    Future<void> update() async {
      if (controller.isClosed) return;
      try {
        final summary = await getFinancialSummary(eventId, communityId: communityId, forceRefresh: true);
        if (!controller.isClosed) controller.add(summary);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    // Listen to all relevant collections
    final sub1 = _participantService.streamParticipants(eventId, communityId: communityId).listen((_) => update());
    
    var contribQuery = _firestore.collection('contributions').where('eventId', isEqualTo: eventId);
    if (communityId != null && communityId.isNotEmpty) contribQuery = contribQuery.where('communityId', isEqualTo: communityId);
    final sub2 = contribQuery.snapshots().listen((_) => update());
    
    var expenseQuery = _firestore.collection('expenses').where('eventId', isEqualTo: eventId);
    if (communityId != null && communityId.isNotEmpty) expenseQuery = expenseQuery.where('communityId', isEqualTo: communityId);
    final sub3 = expenseQuery.snapshots().listen((_) => update());

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
    };

    // Initial trigger
    update();

    return controller.stream;
  }

  Future<void> create(EventModel event, {bool sendNotification = true}) async {
    try {
      await _eventService.create(event, sendNotification: sendNotification);
      
      // ✅ Invalidate cache to ensure the new event shows up on next refresh
      _listCache.remove(event.communityId);
      
      // 🚀 OPTIMIZATION: Trigger reload in background so the UI can close immediately
      loadEvents(event.communityId, forceRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refreshData(String eventId) async {
    try {
      // debugPrint('🔄 EventProvider: Refreshing event data for $eventId');
      final index = _events.indexWhere((p) => p.eventId == eventId);
      if (index != -1) {
        _events.removeAt(index);
      }
      _summaryCache.remove(eventId);
      notifyListeners();
      await _eventService.getEventById(eventId);
      // debugPrint('✅ EventProvider: event data refreshed for $eventId');
    } catch (e) {
      debugPrint('❌ EventProvider: Error refreshing event data: $e');
      rethrow;
    }
  }

  // ✅ Stream for user joined status
  Stream<bool> streamUserJoinedStatus(String eventId, String userId, {String? communityId}) {
    if (communityId == null || communityId.isEmpty) {
      debugPrint('⚠️ streamUserJoinedStatus: communityId is null or empty for event $eventId');
      return Stream.value(false);
    }

    var query = _firestore
        .collection('participants') // FIXED back to participants
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'joined');

    return query.snapshots().map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // ✅ OPTIMIZED: Get participant with real-time contribution data
  Future<ParticipantModel> getParticipantWithContribution(String eventId, String userId, {String? communityId}) async {
    try {
      final effectiveCommunityId = communityId ?? '';
      if (effectiveCommunityId.isEmpty) throw Exception('communityId is required');
      final participant = await _participantService.getParticipant(eventId, userId, communityId: effectiveCommunityId);
      final contributions = await _contributionService.getContributionsByUserAn(
        userId: userId,
        eventId: eventId,
        communityId: communityId,
      );
      final totalPaid = contributions.fold(0.0, (sum, contribution) => sum + contribution['amount']);
      final doc = await _firestore.collection('events').doc(eventId).get();
      final suggestedContribution = (doc.data()?['suggestedContribution'] ?? 0).toDouble();
      
      return participant.copyWith(
        contributionPaid: totalPaid,
        hasPaidContribution: suggestedContribution > 0 ? totalPaid >= suggestedContribution : false,
      );
    } catch (e) {
      debugPrint('❌ Error getting participant with contribution: $e');
      rethrow;
    }
  }

  // ✅ Stream with monthly contributions
  Stream<List<ParticipantModel>> streamParticipantsWithMonthlyContributions(
    String eventId, 
    String monthId,
    {String? communityId}
  ) {
    return _participantService.streamParticipants(eventId, communityId: communityId).asyncMap((participants) async {
      if (participants.isEmpty) return [];
      
      try {
        final doc = await _firestore.collection('events').doc(eventId).get();
        final suggestedContribution = (doc.data()?['suggestedContribution'] ?? 0).toDouble();
        
        final monthlyContributions = await _contributionService.getMonthlyContributionsForParticipant(
          eventId,
          monthId,
          communityId: communityId,
        );
        
        final Map<String, double> userPaidMap = {};
        for (final contribution in monthlyContributions) {
          userPaidMap[contribution.userId] = (userPaidMap[contribution.userId] ?? 0.0) + contribution.amount;
        }
        
        return participants.map((participant) {
          final amountPaid = userPaidMap[participant.userId] ?? 0.0;
          final hasPaid = suggestedContribution > 0 ? amountPaid >= suggestedContribution : true;
          
          return participant.copyWith(
            contributionPaid: amountPaid,
            hasPaidContribution: hasPaid,
          );
        }).toList();
      } catch (e) {
        debugPrint('❌ Error in optimized monthly participants stream: $e');
        return participants;
      }
    });
  }

  Future<Map<String, int>> getMonthlyPaymentCounts(String eventId, {String? communityId}) async {
    try {
      final contributions = await _contributionService.getContributions(eventId, communityId: communityId);
      final counts = <String, int>{};
      for (final contribution in contributions) {
        if (contribution.isMonthlyContribution && contribution.monthId != null) {
          counts[contribution.monthId!] = (counts[contribution.monthId!] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e) {
      debugPrint('❌ Error getting monthly payment counts: $e');
      return {};
    }
  }

  Future<void> join(
    EventModel event,
    String userId,
    String userName,
    String userEmail,
    String communityId,
  ) async {
    try {
      final participant = ParticipantModel(
        participantId: '', 
        eventId: event.eventId,
        eventName: event.title,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        communityId: communityId,
        joinedAt: DateTime.now(),
        status: 'joined',
        contributionPaid: 0,
        hasPaidContribution: false,
      );

      await _participantService.join(participant);
      _summaryCache.remove(event.eventId);
      await loadMyParticipations(userId, communityId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadMyParticipations(String userId, String communityId) async {
    try {
      _myParticipations = await _participantService.getUseParticipations(
        userId,
        communityId,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading participations: $e');
    }
  }

  bool hasUserJoined(String eventId, String userId) {
    return _myParticipations.any(
      (p) => p.eventId == eventId && p.userId == userId && p.status == 'joined',
    );
  }

  Stream<List<EventModel>> streamActivs(String communityId) {
    return _eventService.streamActiveEventsByCommunity(communityId);
  }

  // ✅ Stream for event financial summary
  Stream<Map<String, dynamic>> streamFinancialSummaryOld(String eventId) {
    // Keep this one if any older screen uses Map<String, dynamic> specifically, 
    // but the Map<String, double> version at line 303 is better for the Dashboard.
    // For now, I'll just rename it to avoid conflict or remove it if unused.
    return streamParticipantsWithContributions(eventId).asyncMap((participants) async {
      if (participants.isEmpty) {
        return {
          'totalParticipants': 0,
          'paidParticipants': 0,
          'pendingParticipants': 0,
          'totalCollected': 0.0,
          'totalExpected': 0.0,
          'collectionRate': 0.0,
        };
      }

      final summary = await getFinancialSummary(eventId);
      return summary;
    });
  }

  Stream<List<ParticipantModel>> streamParticipantsWithContributions(String eventId, {String? communityId}) {
    final controller = StreamController<List<ParticipantModel>>();
    
    Future<void> update() async {
      if (controller.isClosed) return;
      try {
        final effectiveCommunityId = communityId ?? '';
        if (effectiveCommunityId.isEmpty) {
          if (!controller.isClosed) controller.add([]);
          return;
        }

        final participants = await _participantService.getEventParticipants(eventId, communityId: effectiveCommunityId);
        if (participants.isEmpty) {
          if (!controller.isClosed) controller.add([]);
          return;
        }
        
        final doc = await _firestore.collection('events').doc(eventId).get(const GetOptions(source: Source.cache)).catchError((_) => _firestore.collection('events').doc(eventId).get());
        final allContributions = await _contributionService.getContributions(eventId, communityId: communityId);
        final suggestedContribution = ((doc.data())?['suggestedContribution'] ?? 0).toDouble();
        
        final Map<String, double> userPaidMap = {};
        for (final contribution in allContributions) {
          userPaidMap[contribution.userId] = (userPaidMap[contribution.userId] ?? 0.0) + contribution.amount;
        }
        
        final result = participants.map((participant) {
          final amountPaid = userPaidMap[participant.userId] ?? 0.0;
          final hasPaid = suggestedContribution > 0 ? amountPaid >= suggestedContribution : true;
          
          return participant.copyWith(
            contributionPaid: amountPaid,
            hasPaidContribution: hasPaid,
          );
        }).toList();
        
        if (!controller.isClosed) controller.add(result);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    // 🚀 IMPROVEMENT: Trigger when participants OR contributions change
    final sub1 = _participantService.streamParticipants(eventId, communityId: communityId).listen((_) => update());
    
    var q2 = _firestore.collection('contributions').where('eventId', isEqualTo: eventId);
    if (communityId != null && communityId.isNotEmpty) q2 = q2.where('communityId', isEqualTo: communityId);
    final sub2 = q2.snapshots().listen((_) => update());
    
    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };
    
    update();
    return controller.stream;
  }

  Future<void> leave(String eventId, String userId, {String? communityId}) async {
    try {
      await _participantService.leave(eventId, userId, communityId: communityId);
      final event = await _eventService.getEventById(eventId);
      if (event != null) {
        await loadMyParticipations(userId, communityId ?? event.communityId);
      }
      _summaryCache.remove(eventId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncEventsStatus() async {
    try {
      for (final event in _events) {
        try {
          await event.syncComputedStatusToFirestore();
        } catch (e) {
          debugPrint('❌ Error syncing status for event ${event.eventId}: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error in syncEventsStatus: $e');
    }
  }

  Future<void> addContributionReminderDate(String eventId, DateTime date) async {
    try {
      await _eventService.addContributionReminderDate(eventId, date);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> removeContributionReminderDate(String eventId, DateTime date) async {
    try {
      await _eventService.removeContributionReminderDate(eventId, date);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  

  
  Future<void> clearAllReminderDates(String eventId) async {
    try {
      await _eventService.clearAllReminderDates(eventId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendContributionReminder(String eventId) async {
    try {
      await _eventService.sendContributionReminder(eventId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateReminderSettings({
    required String eventId,
    bool? enableAutoReminders,
    int? reminderDaysBefore,
    String? reminderFrequency,
    List<DateTime>? contributionReminderDates,
    DateTime? firstPaymentDueDate,
    DateTime? nextReminderDate,
    String? customReminderTitle,
    String? customReminderMessage,
    bool? enableReminderRetries,
    int? retryDaysAfter,
    bool? enableAdminEscalation,
    int? escalationDaysAfter,
  }) async {
    try {
      await _eventService.updateReminderSettings(
        eventId: eventId,
        enableAutoReminders: enableAutoReminders,
        reminderDaysBefore: reminderDaysBefore,
        reminderFrequency: reminderFrequency,
        contributionReminderDates: contributionReminderDates,
        firstPaymentDueDate: firstPaymentDueDate,
        nextReminderDate: nextReminderDate,
        customReminderTitle: customReminderTitle,
        customReminderMessage: customReminderMessage,
        enableReminderRetries: enableReminderRetries,
        retryDaysAfter: retryDaysAfter,
        enableAdminEscalation: enableAdminEscalation,
        escalationDaysAfter: escalationDaysAfter,
      );
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getReminderStatus(String eventId) async {
    try {
      final event = await _eventService.getEventById(eventId);
      if (event == null) return {'hasReminders': false};
      final unpaidParticipants = await _eventService.getParticipantsWithUnpaidContributions(eventId);
      return {
        'hasReminders': event.enableAutoReminders,
        'nextReminder': event.nextReminderDate,
        'participantsToNotify': unpaidParticipants.length,
        'status': event.enableAutoReminders ? 'active' : 'disabled',
      };
    } catch (e) {
      return {'hasReminders': false};
    }
  }

  Future<EventModel?> getMonthlyPayment(String communityId) async {
    try {
      final events = await _eventService.getEventsByCommunity(communityId);
      return events.firstWhere((p) => p.isMonthlyPayment, orElse: () => throw 'Not found');
    } catch (e) {
      return null;
    }
  }

  StreamSubscription? _participationSub;
  void watchUserParticipation(String communityId, String userId) {
    _participationSub?.cancel();
    _participationSub = _firestore
        .collection('participants')
        .where('userId', isEqualTo: userId)
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .listen((snapshot) {
      _myParticipations = snapshot.docs
          .map((doc) => ParticipantModel.fromMap(doc.data(), doc.id))
          .toList();
      notifyListeners();
    });
  }

  Stream<Map<String, dynamic>> streamMonthlyFinancialSummary(String eventId, String monthId, {String? communityId}) {
    final controller = StreamController<Map<String, dynamic>>();
    
    Future<void> update() async {
      if (controller.isClosed) return;
      try {
        final effectiveCommunityId = communityId ?? '';
        if (effectiveCommunityId.isEmpty) {
          if (!controller.isClosed) controller.add({});
          return;
        }

        final participants = await _participantService.getEventParticipants(eventId, communityId: effectiveCommunityId);
        
        final futures = await Future.wait<dynamic>([
          _firestore.collection('events').doc(eventId).get(const GetOptions(source: Source.cache)).catchError((_) => _firestore.collection('events').doc(eventId).get()),
          _contributionService.getMonthlyContributionsForParticipant(eventId, monthId, communityId: communityId),
          _expenseService.getMonthlyExpenses(eventId, monthId, communityId: communityId),
        ]);
        
        final doc = futures[0] as DocumentSnapshot;
        final monthlyContributions = futures[1] as List<ContributionModel>;
        final monthlyExpenses = futures[2] as List<ExpenseModel>;
        final suggestedContribution = ((doc.data() as Map<String, dynamic>?)?['suggestedContribution'] ?? 0).toDouble();
        
        // Map out paid status
        final Map<String, double> userPaidMap = {};
        for (final c in monthlyContributions) {
          userPaidMap[c.userId] = (userPaidMap[c.userId] ?? 0.0) + c.amount;
        }

        int paidParticipants = 0;
        double totalCollected = 0.0;
        for (final p in participants) {
          final paid = userPaidMap[p.userId] ?? 0.0;
          totalCollected += paid;
          if (suggestedContribution > 0 ? paid >= suggestedContribution : true) paidParticipants++;
        }
        
        double totalExpenses = 0.0;
        for (final e in monthlyExpenses) {
          totalExpenses += e.amount;
        }

        final result = {
          'totalParticipants': participants.length,
          'paidParticipants': paidParticipants,
          'pendingParticipants': participants.length - paidParticipants,
          'totalCollected': totalCollected,
          'totalExpenses': totalExpenses,
          'balance': totalCollected - totalExpenses,
          'totalExpected': suggestedContribution * participants.length,
          'totalContributions': monthlyContributions.length,
          'contributionCount': monthlyContributions.length,
        };
        
        if (!controller.isClosed) controller.add(result);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    // 🚀 IMPROVEMENT: Trigger on relevant changes
    final sub1 = _participantService.streamParticipants(eventId, communityId: communityId).listen((_) => update());
    
    var q2 = _firestore.collection('contributions').where('eventId', isEqualTo: eventId).where('monthId', isEqualTo: monthId);
    if (communityId != null && communityId.isNotEmpty) q2 = q2.where('communityId', isEqualTo: communityId);
    final sub2 = q2.snapshots().listen((_) => update());
    
    var q3 = _firestore.collection('expenses').where('eventId', isEqualTo: eventId).where('monthId', isEqualTo: monthId);
    if (communityId != null && communityId.isNotEmpty) q3 = q3.where('communityId', isEqualTo: communityId);
    final sub3 = q3.snapshots().listen((_) => update());

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
    };

    update();
    return controller.stream;
  }

  void clearCache() {
    _summaryCache.clear();
    _listCache.clear();
  }
}






