import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class AddDeveloperScreen extends StatefulWidget {
  const AddDeveloperScreen({super.key});

  @override
  State<AddDeveloperScreen> createState() => _AddDeveloperScreenState();
}

class _AddDeveloperScreenState extends State<AddDeveloperScreen> {
  Map<String, dynamic>? _selectedUser;
  final Map<String, String> _communityNames = {};
  bool _isLoadingCommunities = true;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  final _searchController = TextEditingController();
  final _fs = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String queryStr) async {
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final lowerQuery = queryStr.trim().toLowerCase();
      
      // Indexed prefix match
      final emailQuery = await _fs.collection('users')
          .where('email', isGreaterThanOrEqualTo: queryStr)
          .where('email', isLessThanOrEqualTo: '$queryStr\uf8ff')
          .limit(20)
          .get();

      final nameQuery = await _fs.collection('users')
          .where('displayName', isGreaterThanOrEqualTo: queryStr)
          .where('displayName', isLessThanOrEqualTo: '$queryStr\uf8ff')
          .limit(20)
          .get();

      final matches = <Map<String, dynamic>>[];
      final seenUids = <String>{};

      void addResults(QuerySnapshot snap) {
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['isVirtualUser'] == true) continue;
          if (!seenUids.contains(doc.id)) {
            data['uid'] = doc.id;
            matches.add(data);
            seenUids.add(doc.id);
          }
        }
      }

      addResults(emailQuery);
      addResults(nameQuery);

      if (matches.length < 5) {
        final snapshot = await _fs.collection('users').limit(100).get();
        for (var doc in snapshot.docs) {
          if (seenUids.contains(doc.id)) continue;
          
          final data = doc.data();
          if (data['isVirtualUser'] == true) continue;
          
          final name = (data['displayName'] ?? data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          final phone = (data['phoneNumber'] ?? '').toString().toLowerCase();

          if (name.contains(lowerQuery) || email.contains(lowerQuery) || phone.contains(lowerQuery)) {
            data['uid'] = doc.id;
            matches.add(data);
            seenUids.add(doc.id);
          }
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = matches.take(50).toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _loadEvents() async {
    try {
      final snapshot = await _fs.collection('communities').get();
      for (var doc in snapshot.docs) {
        _communityNames[doc.id] = doc.data()['name']?.toString() ?? 'Unnnamed';
      }
    } catch (e) {
      debugPrint('Error loading communities: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingCommunities = false);
      }
    }
  }

  Future<void> _makeDeveloper(String userId, bool isDeveloper) async {
    try {
      await _fs
          .collection('users')
          .doc(userId)
          .update({
            'isDeveloper': isDeveloper,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      SnackbarHelper.showInfo(context, 
            isDeveloper ? 'Added as developer' : 'Removed as developer',
          );
      
      // Update local state if selected
      if (_selectedUser != null && _selectedUser!['uid'] == userId) {
        setState(() {
          _selectedUser!['isDeveloper'] = isDeveloper;
        });
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Error: $e');
    }
  }

  Widget _buildSkeletonLoader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;
    
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: List.generate(3, (index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
        )),
      ),
    );
  }

  Widget _buildUserSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            labelText: 'Search User',
            hintText: 'Search by name, email or mobile...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching 
               ? Container(
                   padding: const EdgeInsets.all(12),
                   width: 20,
                   height: 20,
                   child: const CircularProgressIndicator(strokeWidth: 2),
                 )
               : (_searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildSkeletonLoader(),
          ),
        // Results
        if (!_isSearching && _searchResults.isNotEmpty && _selectedUser == null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final option = _searchResults[index];
                final name = option['displayName'] ?? option['name'] ?? 'Unknown';
                final email = option['email'] ?? 'No email';
                final commId = option['communityId'];
                final commName = _communityNames[commId] ?? option['communityName'] ?? 'Independent User';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary(context).withValues(alpha: 0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(color: AppColors.primary(context)),
                    ),
                  ),
                  title: Text(name),
                  subtitle: Text('$email • $commName', style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    setState(() {
                      _selectedUser = option;
                      _searchResults = [];
                      _searchController.text = name;
                    });
                    FocusScope.of(context).unfocus();
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    
    if (!authProvider.isDeveloper) {
      return const Scaffold(
        body: Center(child: Text('Access denied')),
      );
    }

    return GradientSheetScaffold(
      title: 'Add Developer',
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
        onPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Card
            Card(
              color: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Search for User',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildUserSearch(),
                    if (_isLoadingCommunities) 
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('Loading communities...', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Search Result Case
            if (_selectedUser != null)
              Card(
                color: AppColors.card(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'User Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => setState(() => _selectedUser = null),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(_selectedUser!['displayName'] ?? _selectedUser!['name'] ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email: ${_selectedUser!['email'] ?? 'No email'}'),
                              Text('Phone: ${_selectedUser!['phoneNumber'] ?? 'No phone'}'),
                              Text('Community: ${_communityNames[_selectedUser!['communityId']] ?? _selectedUser!['communityName'] ?? 'Independent User'}'),
                              Text('Role: ${_selectedUser!['isDeveloper'] == true ? 'Developer' : 'User'}'),
                            ],
                          ),
                          trailing: Switch(
                            value: _selectedUser!['isDeveloper'] == true,
                            onChanged: (value) => 
                                _makeDeveloper(_selectedUser!['uid'], value),
                            activeThumbColor: AppColors.primary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Instructions
         SizedBox(
  width: double.infinity,
  child: Card(
    color: AppColors.surface(context),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instructions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• Search for user by name, email or phone\n'
            '• Toggle the switch to make them developer\n'
            '• Only developers can access developer tools\n'
            '• Developers can also manage other developers',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  ),
)
          ],
        ),
      ),
    );
  }
}
