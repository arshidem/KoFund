import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/events/models/event_model.dart';
import 'package:kofund/features/events/providers/event_provider.dart';
import 'package:kofund/core/utils/haptic_helper.dart';

class PublicEventDetailScreen extends StatefulWidget {
  final String eventId;

  const PublicEventDetailScreen({super.key, required this.eventId});

  @override
  State<PublicEventDetailScreen> createState() => _PublicEventDetailScreenState();
}

class _PublicEventDetailScreenState extends State<PublicEventDetailScreen> {
  bool _isPasswordVerified = false;
  final TextEditingController _passwordController = TextEditingController();
  String? _passwordError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: StreamBuilder<EventModel?>(
        stream: Provider.of<EventProvider>(context, listen: false).getEventById(widget.eventId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final event = snapshot.data;
          if (event == null) {
            return _buildErrorState('Event not found or no longer public.');
          }

          if (!event.isPublicEnabled) {
            return _buildErrorState('This event is no longer publicly shared.');
          }

          // Check password if required
          if (event.publicPassword != null && event.publicPassword!.isNotEmpty && !_isPasswordVerified) {
            return _buildPasswordScreen(event);
          }

          return _buildPublicEventView(event);
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_person_rounded, size: 64, color: AppColors.textTertiary(context)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordScreen(EventModel event) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary(context).withValues(alpha: 0.1),
            AppColors.background(context),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, size: 32, color: AppColors.primary(context)),
                ),
                const SizedBox(height: 24),
                Text(
                  event.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This event is password protected',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: _passwordError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.key_rounded),
                  ),
                  onSubmitted: (_) => _verifyPassword(event),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _verifyPassword(event),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Unlock Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _verifyPassword(EventModel event) {
    HapticHelper.medium();
    if (_passwordController.text == event.publicPassword) {
      setState(() {
        _isPasswordVerified = true;
        _passwordError = null;
      });
    } else {
      setState(() {
        _passwordError = 'Incorrect password. Please try again.';
      });
    }
  }

  Widget _buildPublicEventView(EventModel event) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              event.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark 
                        ? [const Color(0xFF1E3C72), const Color(0xFF2A5298)]
                        : [AppColors.primary(context), AppColors.primary(context).withValues(alpha: 0.7)],
                    ),
                  ),
                ),
                Positioned(
                  right: -50,
                  top: -50,
                  child: Icon(
                    _getEventIcon(event.eventType),
                    size: 200,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Overview'),
                const SizedBox(height: 12),
                _buildInfoCard(event),
                const SizedBox(height: 24),
                _buildSectionTitle('Financial Progress'),
                const SizedBox(height: 12),
                _buildFinancialProgressCard(event),
                const SizedBox(height: 24),
                _buildSectionTitle('Description'),
                const SizedBox(height: 12),
                _buildDescription(event),
                const SizedBox(height: 40),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary(context),
      ),
    );
  }

  Widget _buildInfoCard(EventModel event) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.calendar_today_rounded, 'Date', 
            event.eventDate != null ? DateFormat('EEEE, MMM dd, yyyy').format(event.eventDate!) : 'N/A'),
          const Divider(height: 24),
          _buildInfoRow(Icons.location_on_rounded, 'Location', event.location),
          const Divider(height: 24),
          _buildInfoRow(Icons.monetization_on_rounded, 'Contribution', 
            event.suggestedContribution != null ? '₹${event.suggestedContribution!.toStringAsFixed(0)}' : 'Flexible'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary(context)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialProgressCard(EventModel event) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: Provider.of<EventProvider>(context, listen: false).streamProgress(event.eventId),
      builder: (context, snapshot) {
        final progressData = snapshot.data ?? {
          'collected': 0.0,
          'target': event.totalAmount ?? 100.0,
          'percentage': 0.0,
        };

        final double percentage = progressData['percentage'] ?? 0.0;
        final double collected = progressData['collected'] ?? 0.0;
        final double target = progressData['target'] ?? 100.0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary(context),
                AppColors.primary(context).withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary(context).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Collection Progress',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('Collected', '₹${collected.toStringAsFixed(0)}'),
                  _buildStatItem('Goal', '₹${target.toStringAsFixed(0)}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildDescription(EventModel event) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Text(
        event.description.isNotEmpty ? event.description : 'No description provided.',
        style: TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary(context),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            'Powered by',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 4),
          const Text(
            'KoFund',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'football': return Icons.sports_soccer_rounded;
      case 'cricket': return Icons.sports_cricket_rounded;
      case 'trip': return Icons.flight_takeoff_rounded;
      case 'charity': return Icons.favorite_rounded;
      case 'party': return Icons.celebration_rounded;
      default: return Icons.event_available_rounded;
    }
  }
}
