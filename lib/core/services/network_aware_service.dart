// lib/services/network_aware_service.dart
import 'network_service.dart';
import 'package:flutter/material.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

mixin NetworkAwareService {
  final NetworkService _networkService = NetworkService();
  
  Future<T> executeWithNetworkCheck<T>({
    required Future<T> Function() operation,
    required String operationName,
    BuildContext? context,
    bool showMessage = true,
    bool requireOnline = true,
  }) async {
    final isOnline = await _networkService.isConnected;
    
    if (requireOnline && !isOnline) {
      _showNetworkError(context, operationName);
      throw Exception('Network required for $operationName');
    }
    
    try {
      return await operation();
    } catch (e) {
      rethrow;
    }
  }
  
  void _showNetworkError(BuildContext? context, String operation) {
    if (context != null && context.mounted) {
      SnackbarHelper.showError(context, 'Internet required to $operation');
    }
  }
}





