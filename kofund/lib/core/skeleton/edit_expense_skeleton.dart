// 📁 lib/features/contributions/screens/edit_contribution_skeleton.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

class EditContributionSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const EditContributionSkeleton({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
      appBar: AppBar(
        toolbarHeight: 80,
        title: Shimmer.fromColors(
          baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
          child: Container(
            width: 150,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white70 : Colors.white,
          ),
          onPressed: () {},
        ),
        automaticallyImplyLeading: true,
        actions: [
          Shimmer.fromColors(
            baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          
              
              // Skeleton Form Fields
              Column(
                children: [
                  // Skeleton event Dropdown
                  _buildSkeletonDropdown(label: 'event'),
                  
                  const SizedBox(height: 16),
                  
                  // Skeleton Amount Field
                  _buildSkeletonInputField(label: 'Amount', icon: Icons.currency_rupee),
                  
                  const SizedBox(height: 16),
                  
                  // Skeleton Payment Method Dropdown
                  _buildSkeletonDropdown(label: 'Payment Method'),
                  
                  const SizedBox(height: 16),
                  
                  // Skeleton Month Dropdown (if applicable)
                  Shimmer.fromColors(
                    baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Skeleton Edit Reason Field
                  _buildSkeletonInputField(
                    label: 'Reason for Edit', 
                    icon: Icons.edit_note,
                    isMultiLine: true,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Skeleton Changes Summary Card
              _buildSkeletonChangesSummary(),
              
              const SizedBox(height: 24),
              
              // Skeleton Save Button
              Shimmer.fromColors(
                baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildSkeletonDropdown({required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
          child: Container(
            width: 60,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Shimmer.fromColors(
          baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonInputField({
    required String label,
    required IconData icon,
    bool isMultiLine = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
          child: Container(
            width: 80,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Shimmer.fromColors(
          baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
          child: Container(
            height: isMultiLine ? 80 : 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonChangesSummary() {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Skeleton Header
            Row(
              children: [
                Shimmer.fromColors(
                  baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Shimmer.fromColors(
                  baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                  child: Container(
                    width: 120,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Skeleton Divider
            Container(
              height: 1,
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            
            const SizedBox(height: 12),
            
            // Skeleton Change Items
            Column(
              children: List.generate(4, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Shimmer.fromColors(
                        baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                        highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Shimmer.fromColors(
                              baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                              highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                              child: Container(
                                width: 60,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Shimmer.fromColors(
                              baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                              highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                              child: Container(
                                width: 120,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Shimmer.fromColors(
                        baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                        highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
                        child: Container(
                          width: 50,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}





