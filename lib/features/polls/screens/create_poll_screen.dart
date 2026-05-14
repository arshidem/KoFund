import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/polls/providers/poll_provider.dart';
import 'package:kofund/features/polls/models/poll_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/events/providers/event_provider.dart';
import 'package:kofund/features/events/models/event_model.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/providers/theme_provider.dart';
import 'dart:async';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class CreatePollScreen extends StatefulWidget {
  final String communityId;
  final String? eventId;
  final PollModel? pollToEdit;
  final bool isEditing;

  const CreatePollScreen({
    super.key,
    required this.communityId,
    this.id,
    this.pollToEdit,
    this.isEditing = false,
  });

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  PollType _selectedType = PollType.decision;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  bool _allowMultipleVotes = false;
  bool _allowVoteChange = true; // NEW: Default to true
  bool _isAnonymous = false;
  int? _minParticipationPercent;
  bool _isCommunityWide = true;
  String? _selectedeventId;
  bool _isLoading = false;
  bool _loadingEvents = false;

  List<EventModel> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();

    // If editing, populate fields with existing poll data
    if (widget.isEditing) {
      if (widget.pollToEdit != null) {
        _initializeEditingFields();
      } else {
        // Handle case where pollToEdit is null but isEditing is true
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            SnackbarHelper.showInfo(context, 'Poll data not found');
            Navigator.pop(context);
          }
        });
      }
    }
  }

  void _initializeEditingFields() {
    final poll = widget.pollToEdit!;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _titleController.text = poll.title;
        _descriptionController.text = poll.description;
        _selectedType = poll.type;
        _selectedDate = poll.endDate;
        _allowMultipleVotes = poll.allowMultipleVotes;
        _allowVoteChange = poll.allowVoteChange; // NEW
        _isAnonymous = poll.isAnonymous;
        _minParticipationPercent = poll.minParticipationPercent;

        // Initialize options
        _optionControllers.clear();
        for (var option in poll.options) {
          _optionControllers.add(TextEditingController(text: option));
        }

        // Ensure we have at least 2 options
        while (_optionControllers.length < 2) {
          _optionControllers.add(TextEditingController());
        }

        // Set event selection properly
        if (poll. != null && poll.!.isNotEmpty) {
          _isCommunityWide = false;
          _selectedeventId = poll.;
        } else {
          _isCommunityWide = true;
          _selectedeventId = null;
        }
      });
    });
  }

  Future<void> _loadEvents() async {
    try {
      if (!mounted) return;
      setState(() => _loadingEvents = true);

      final eventProvider = context.read<EventProvider>();
      await EventProvider.loadCommunityEvents(widget.communityId);

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _events = eventProvider.events.where((p) => p.isOngoing).toList();
            _loadingEvents = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
      if (mounted) {
        setState(() => _loadingEvents = false);
      }
    }
  }

  void _addOptionField() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
    // Focus on the new field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_optionControllers.isNotEmpty && mounted) {
        FocusScope.of(context).requestFocus(FocusNode());
      }
    });
  }

  void _removeOptionField(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        final controller = _optionControllers[index];
        controller.dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _selectDate() async {
    final maxDate = DateTime.now().add(const Duration(days: 365));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: maxDate,
    );
    if (picked != null && picked != _selectedDate) {
      // Ensure selected date is not in the past
      if (picked.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        SnackbarHelper.showInfo(context, 'End date cannot be in the past');
        return;
      }
      // Validation for too far in future
      if (picked.isAfter(maxDate)) {
        SnackbarHelper.showInfo(context, 'End date cannot be more than 1 year in the future');
        return;
      }
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Helper to determine default allowVoteChange based on poll type
  bool _getDefaultAllowVoteChangeForTeventType(PollType type) {
    switch (type) {
      case PollType.expenseApproval:
      case PollType.contribution:
        return false; // Financial decisions should not allow vote changes
      case PollType.decision:
        return false; // Important decisions should be final
      case PollType.suggestion:
      case PollType.planning:
      default:
        return true; // Suggestions and planning can be flexible
    }
  }

  // Helper to determine if allowVoteChange should be enabled based on poll type
  bool _shouldShowAllowVoteChangeForTeventType(PollType type) {
    switch (type) {
      case PollType.expenseApproval:
        return false; // Expense approvals should never allow vote changes
      case PollType.contribution:
        return false; // Contributions should be binding
      default:
        return true; // Other Types can have the option
    }
  }

  // Helper to get description for allowVoteChange setting
  String _getAllowVoteChangeDescription(PollType type) {
    switch (type) {
      case PollType.expenseApproval:
        return 'Expense approvals require final decisions';
      case PollType.contribution:
        return 'Contributions are binding commitments';
      case PollType.decision:
        return 'Important community decisions should be final';
      case PollType.suggestion:
        return 'Suggestions can be flexible';
      case PollType.planning:
        return 'Planning can allow changes as schedules evolve';
      default:
        return 'Allow members to change their vote after submitting';
    }
  }

  Future<void> _submitPoll() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate options
    final options = <String>[];
    for (var controller in _optionControllers) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        options.add(text);
      }
    }

    if (options.length < 2) {
      SnackbarHelper.showInfo(context, 'Please add at least 2 options');
      return;
    }

    final uniqueOptions = options.toSet();
    if (uniqueOptions.length != options.length) {
      SnackbarHelper.showInfo(context, 'Options must be unique');
      return;
    }

    // Validate event selection when not community-wide
    if (!_isCommunityWide && (_selectedeventId == null || _selectedeventId!.isEmpty)) {
      SnackbarHelper.showInfo(context, 'Please select a event');
      return;
    }

    // Validate vote change setting based on poll type
    final shouldShowVoteChange = _shouldShowAllowVoteChangeForTeventType(_selectedType);
    if (!shouldShowVoteChange) {
      // Force disable vote change for specific poll Types
      _allowVoteChange = false;
    }

    setState(() => _isLoading = true);

    try {
      final _authProvider = context.read<AppAuthProvider>();
      final pollProvider = context.read<PollProvider>();

      if (widget.isEditing && widget.pollToEdit != null) {
        // Update existing poll
        final updatedPoll = widget.pollToEdit!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          options: options,
          endDate: _selectedDate,
          isAnonymous: _isAnonymous,
          allowMultipleVotes: _allowMultipleVotes,
          allowVoteChange: _allowVoteChange, // NEW
          minParticipationPercent: _minParticipationPercent,
          eventId: _isCommunityWide ? null : _selectedeventId,
          updatedAt: DateTime.now(),
        );

        final success = await pollProvider.updatePoll(updatedPoll);
        if (!mounted) return;

        if (success) {
          SnackbarHelper.showSuccess(context, 'Poll updated successfully');
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          SnackbarHelper.showError(context, 'Failed to update poll');
        }
      } else {
        // Create new poll
        final poll = await pollProvider.createPoll(
          communityId: widget.communityId,
          eventId: _isCommunityWide ? null : _selectedeventId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          options: options,
          endDate: _selectedDate,
          createdBy: _authProvider.user!.uid,
          allowMultipleVotes: _allowMultipleVotes,
          allowVoteChange: _allowVoteChange, // NEW
          isAnonymous: _isAnonymous,
          minParticipationPercent: _minParticipationPercent,
        );

        if (poll != null) {
          SnackbarHelper.showSuccess(context, 'Poll created successfully');
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          SnackbarHelper.showError(context, 'Failed to create poll');
        }
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    // Dispose all option controllers
    for (var controller in _optionControllers) {
      controller.dispose();
    }

    _optionControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final shouldShowAllowVoteChange = _shouldShowAllowVoteChangeForTeventType(_selectedType);

    return GradientSheetScaffold(
      title: widget.isEditing ? 'Edit Poll' : 'Create New Poll',
      actions: [
        if (!_isLoading)
          IconButton(
            onPressed: _submitPoll,
            icon: Icon(Icons.check, color: AppColors.textPrimary(context)),
          ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
      ],
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poll type
              _buildSectionHeader('Poll type'),
              _buildPollTypeSelector(isDarkMode),
              if (_selectedType == PollType.expenseApproval ||
                  _selectedType == PollType.contribution ||
                  _selectedType == PollType.decision)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDarkMode ? Colors.blue[900] : Colors.blue[50])!.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isDarkMode ? Colors.blue[700] : Colors.blue[200])!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: isDarkMode ? Colors.blue[300] : Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedType == PollType.expenseApproval
                              ? 'Expense approvals require final decisions. Votes cannot be changed.'
                              : _selectedType == PollType.contribution
                                  ? 'Contributions are binding commitments. Votes cannot be changed.'
                                  : 'Important decisions should be final.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.blue[200] : Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Basic Info
              _buildSectionHeader('Basic Information'),
              _buildBasicInfoFields(isDarkMode),

              const SizedBox(height: 24),

              // event Selection
              if (_events.isNotEmpty || _loadingEvents) ...[
                _buildSectionHeader('Poll Scope'),
                _buildScopeSelector(isDarkMode),
                const SizedBox(height: 24),
              ],

              // Options
              _buildSectionHeader('Options'),
              _buildOptionsList(isDarkMode),

              const SizedBox(height: 24),

              // Poll Settings
              _buildSectionHeader('Poll Settings'),
              _buildPollSettings(isDarkMode, shouldShowAllowVoteChange),

              const SizedBox(height: 24),

              // End Date
              _buildSectionHeader('End Date'),
              _buildDateSelector(isDarkMode),

              const SizedBox(height: 32),

              // Create/Update Button
              _buildSubmitButton(isDarkMode),

              // Cancel button for editing
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPollTypeSelector(bool isDarkMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: PollType.values.map((type) {
          final isSelected = _selectedType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_getPollTypeLabel(type)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedType = type;
                    // Set default allowVoteChange based on type
                    if (!_shouldShowAllowVoteChangeForTeventType(type)) {
                      _allowVoteChange = false;
                    } else {
                      _allowVoteChange = _getDefaultAllowVoteChangeForTeventType(type);
                    }
                  });
                }
              },
              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              selectedColor: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBasicInfoFields(bool isDarkMode) {
    return Column(
      children: [
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Poll Ttitle *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              borderSide: BorderSide(color: AppColors.primary(context), width: 2),
            ),
            filled: true,
            fillColor: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            counterText: '${_titleController.text.length}/100',
          ),
          maxLength: 100,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a title';
            }
            if (value.length > 100) {
              return 'Ttitle too long (max 100 chars)';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description (Optional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              borderSide: BorderSide(color: AppColors.primary(context), width: 2),
            ),
            filled: true,
            fillColor: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            counterText: '${_descriptionController.text.length}/500',
          ),
          maxLength: 500,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildScopeSelector(bool isDarkMode) {
    if (_loadingEvents) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No ongoing events found. Poll will be community-wide.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        ListTile(
          title: const Text('Community-wide'),
          leading: Icon(
            _isCommunityWide ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: AppColors.primary(context),
          ),
          onTap: () => setState(() => _isCommunityWide = true),
        ),
        ListTile(
          title: const Text('event-specific'),
          subtitle: _events.isEmpty
              ? const Text('No ongoing events available')
              : null,
          leading: Icon(
            !_isCommunityWide ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: _events.isEmpty ? Colors.grey : AppColors.primary(context),
          ),
          onTap: _events.isEmpty
              ? null
              : () => setState(() => _isCommunityWide = false),
        ),
        if (!_isCommunityWide) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedeventId,
                hint: const Text('Select a event'),
                isExpanded: true,
                items: _events.map((event) {
                  return DropdownMenuItem<String>(
                    value: event.eventId,
                    child: Text(event.title),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedeventId = value),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionsList(bool isDarkMode) {
    return Column(
      children: [
        ..._optionControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Option ${index + 1} *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        borderSide: BorderSide(color: AppColors.border(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                      ),
                      filled: true,
                      fillColor: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      suffixIcon: _optionControllers.length > 2
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeOptionField(index),
                            )
                          : null,
                      counterText: '${controller.text.length}/50',
                    ),
                    maxLength: 50,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (value.length > 50) {
                        return 'Option too long (max 50 chars)';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addOptionField,
          icon: const Icon(Icons.add),
          label: const Text('Add Option'),
          style: ElevatedButton.styleFrom(
            foregroundColor: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
            backgroundColor: isDarkMode
                ? AppColors.darkPrimary.withValues(alpha: 0.1)
                : AppColors.lightPrimary.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildPollSettings(bool isDarkMode, bool showAllowVoteChange) {
    return Column(
      children: [
        // Anonymous Voting
        SwitchListTile(
          title: const Text('Anonymous Voting'),
          subtitle: const Text("Hide voter's nnames (Instagram-style)"),
          value: _isAnonymous,
          onChanged: (value) => setState(() => _isAnonymous = value),
        ),

        // Multiple Votes
        SwitchListTile(
          title: const Text('Allow Multiple Votes'),
          subtitle: const Text('Users can select multiple options'),
          value: _allowMultipleVotes,
          onChanged: (value) => setState(() => _allowMultipleVotes = value),
        ),

        // Allow Vote Change - NEW
        if (showAllowVoteChange) ...[
          SwitchListTile(
            title: const Text('Allow Vote Changes'),
            subtitle: Text(_getAllowVoteChangeDescription(_selectedType)),
            value: _allowVoteChange,
            onChanged: (value) => setState(() => _allowVoteChange = value),
          ),
          if (!_allowVoteChange && _allowMultipleVotes)
            Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.orange[900] : Colors.orange[50])!.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isDarkMode ? Colors.orange[700] : Colors.orange[200])!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: isDarkMode ? Colors.orange[300] : Colors.orange[600],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note: With multiple votes enabled, users can add votes but cannot remove existing ones.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.orange[200] : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],

        // Minimum Participation
        ListTile(
          title: const Text('Minimum Participation'),
          subtitle: const Text('Percentage of members required to vote (1-100)'),
          trailing: SizedBox(
            width: 100,
            child: TextFormField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g., 50',
                suffixText: '%',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
                counterText: '',
              ),
              maxLength: 3,
              onChanged: (value) {
                final percent = int.tryParse(value);
                // Validate percentage range
                if (percent != null && (percent < 1 || percent > 100)) {
                  SnackbarHelper.showInfo(context, 'Please enter a value between 1 and 100');
                  _minParticipationPercent = null;
                } else {
                  _minParticipationPercent = percent;
                }
              },
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final percent = int.tryParse(value);
                  if (percent == null || percent < 1 || percent > 100) {
                    return 'Enter 1-100';
                  }
                }
                return null;
              },
              initialValue: _minParticipationPercent?.toString(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector(bool isDarkMode) {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formatDate(_selectedDate),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitPoll,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode ? AppColors.darkPrimary : AppColors.lightPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.isEditing ? 'Update Poll' : 'Create Poll',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  String _getPollTypeLabel(PollType type) {
    switch (type) {
      case PollType.decision:
        return 'Decision';
      case PollType.suggestion:
        return 'Suggestion';
      case PollType.planning:
        return 'Planning';
      case PollType.contribution:
        return 'Contribution';
      case PollType.expenseApproval:
        return 'Expense Approval';
      default:
        return 'Poll';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}





