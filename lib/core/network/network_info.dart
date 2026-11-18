import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstraction over device network connectivity for testability and DI.
abstract interface class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onStatusChange;
}

class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  @override
  Stream<bool> get onStatusChange {
    return _connectivity.onConnectivityChanged
        .map(_hasConnection)
        .distinct();
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
