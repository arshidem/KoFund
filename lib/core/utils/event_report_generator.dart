import 'package:flutter/material.dart';
import 'package:kofund/features/events/models/event_model.dart';
import 'package:kofund/features/participants/models/participant_model.dart';
import 'package:kofund/features/expenses/models/expense_model.dart';
import 'package:kofund/features/contributions/models/contribution_model.dart';
import 'event_report_preview_dialog.dart';

class EventReportGenerator {
  static Future<void> generateAndShowPreview({
    required BuildContext context,
    required EventModel event,
    required List<ParticipantModel> participants,
    required List<ExpenseModel> expenses,
    required List<ContributionModel> contributions,
    String? communityName,
  }) async {
    // 1. Calculate Totals for the dialog
    final double totalCollected = contributions.fold(0.0, (double sum, c) => sum + (c.amount));
    final double totalExpenses = expenses.fold(0.0, (double sum, e) => sum + (e.amount));
    final double balance = totalCollected - totalExpenses;

    if (!context.mounted) return;

    // 2. Show the Preview Dialog
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ReportPreviewDialog(
        event: event,
        participants: participants,
        expenses: expenses,
        contributions: contributions,
        totalCollected: totalCollected,
        totalExpenses: totalExpenses,
        balance: balance,
        communityName: communityName,
      ),
    );
  }
}





