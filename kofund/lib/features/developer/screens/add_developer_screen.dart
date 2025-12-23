import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:flutter/services.dart';
class AddDeveloperScreen extends StatefulWidget {
  const AddDeveloperScreen({super.key});

  @override
  State<AddDeveloperScreen> createState() => _AddDeveloperScreenState();
}

class _AddDeveloperScreenState extends State<AddDeveloperScreen> {
  final _emailController = TextEditingController();
  bool _isAdding = false;
  String _searchStatus = '';
  List<QueryDocumentSnapshot> _searchResults = [];

  Future<void> _searchUser() async {
    if (_emailController.text.isEmpty) return;

    setState(() {
      _searchStatus = 'Searching...';
      _searchResults.clear();
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (query.docs.isEmpty) {
        setState(() => _searchStatus = 'User not found');
      } else {
        setState(() {
          _searchResults = query.docs;
          _searchStatus = '';
        });
      }
    } catch (e) {
      setState(() => _searchStatus = 'Error: $e');
    }
  }

  Future<void> _makeDeveloper(String userId, bool isDeveloper) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
            'isDeveloper': isDeveloper,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDeveloper ? 'Added as developer' : 'Removed as developer',
          ),
        ),
      );
      
      // Refresh search
      _searchUser();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    
    if (!authProvider.isDeveloper) {
      return const Scaffold(
        body: Center(child: Text('Access denied')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
     appBar: AppBar(
  toolbarHeight: 80,
  title: const Text(
    'Add Developer', // Added TextStyle here
    style: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  centerTitle: true,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => Navigator.pop(context),
  ),
  backgroundColor: Colors.transparent,
  foregroundColor: Colors.white,
  elevation: 0,
  systemOverlayStyle: const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ),
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient(context),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
    ),
  ),
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
                  children: [
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'User Email',
                        hintText: 'Enter user email',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchUser,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _searchUser,
                        child: const Text('Search User'),
                      ),
                    ),
                    if (_searchStatus.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _searchStatus,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Search Results
            if (_searchResults.isNotEmpty)
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
                      Text(
                        'Search Results',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._searchResults.map((doc) {
                        final user = doc.data() as Map<String, dynamic>;
                        final isDeveloper = user['isDeveloper'] ?? false;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: AppColors.surface(context),
                          child: ListTile(
                            title: Text(user['email'] ?? 'No email'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Name: ${user['name'] ?? 'Unknown'}'),
                                Text('Role: ${isDeveloper ? 'Developer' : 'User'}'),
                              ],
                            ),
                            trailing: Switch(
                              value: isDeveloper,
                              onChanged: (value) =>
                                  _makeDeveloper(doc.id, value),
                              activeColor: AppColors.primary(context),
                            ),
                          ),
                        );
                      }).toList(),
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
            '• Search for user by email\n'
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