// lib/services/network_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();
  
  final Connectivity _connectivity = Connectivity();
  
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
  
  Stream<bool> get onConnectionChanged {
    return _connectivity.onConnectivityChanged.map(
      (result) => result != ConnectivityResult.none
    );
  }
}
