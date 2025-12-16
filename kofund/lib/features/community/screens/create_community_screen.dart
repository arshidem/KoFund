import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/constants/community_types.dart'; // Import your CommunityType class
import '../../../routing/route_names.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../providers/community_provider.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  String _selectedType = CommunityType.apartment; // Default to first type
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _createCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AppAuthProvider>();
    final communityProvider = context.read<CommunityProvider>();

    if (authProvider.user == null) {
      SnackbarHelper.showError(context, 'User not authenticated');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String adminName = authProvider.getUserDisplayName;

      // ✅ Create community
      final success = await communityProvider.createCommunity(
        name: _nameController.text.trim(),
        adminId: authProvider.user!.uid,
        adminEmail: authProvider.user!.email ?? '',
        adminName: adminName,
        type: _selectedType,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim()
            : 'Community for ${_nameController.text.trim()}',
        location: _locationController.text.trim().isNotEmpty 
            ? _locationController.text.trim()
            : null,
      );

      if (success && communityProvider.currentCommunity != null) {
        final community = communityProvider.currentCommunity!;
        
        // ✅ UPDATE USER DOCUMENT with community info
        await authProvider.setUserAsCommunityAdmin(
          communityId: community.communityId,
          communityName: community.name,
        );

        // Refresh user data
        await authProvider.refreshUserData();

        if (mounted) {
          SnackbarHelper.showSuccess(
            context, 
            'Community "${_nameController.text.trim()}" created successfully!'
          );
          Navigator.pushReplacementNamed(context, RouteNames.communityDashboard);
        }
      } else {
        if (mounted) {
          SnackbarHelper.showError(
            context,
            communityProvider.error ?? 'Failed to create community',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error creating community: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Community'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Create Your Community',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start building your community and invite members to join',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Community Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Community Name *',
                    hintText: 'Enter community name',
                    prefixIcon: Icon(Icons.group),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a community name';
                    }
                    if (value.length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Community Type - UPDATED with your CommunityType class
     // Community Type - UPDATED with fixed layout
DropdownButtonFormField<String>(
  value: _selectedType,
  decoration: const InputDecoration(
    labelText: 'Community Type *',
    prefixIcon: Icon(Icons.category),
    border: OutlineInputBorder(),
  ),
  items: CommunityType.allTypes.map((type) {
    return DropdownMenuItem(
      value: type,
      child: Row(
        mainAxisSize: MainAxisSize.min, // ✅ don't expand horizontally
        children: [
          Text(
            CommunityType.getIcon(type),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 12),
          Flexible( // ✅ allow column to shrink-wrap
            fit: FlexFit.loose,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  type,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  CommunityType.getDescription(type),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }).toList(),
  onChanged: (value) {
    setState(() {
      _selectedType = value!;
    });
  },
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Please select a community type';
    }
    return null;
  },
),

                const SizedBox(height: 20),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe your community purpose, goals, or rules...',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Location
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (Optional)',
                    hintText: 'e.g., New York, USA',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),

                // Info Card - Updated with community type info
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Community Features:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Auto-generated unique invite code\n• You become the community admin\n• Invite members with the generated code\n• Manage programs and members\n• Choose from ${CommunityType.allTypes.length} community types',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createCommunity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline),
                              SizedBox(width: 8),
                              Text(
                                'Create Community',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cancel Button
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
            ),
          ),
        ),
      ),
    );
  }
}