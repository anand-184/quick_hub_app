import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/service_request_model.dart';
import '../services/firebase_service.dart';

class RequestViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription<List<ServiceRequestModel>>? _requestsSubscription;
  List<ServiceRequestModel> _incomingRequests = [];
  bool _isLoading = false;

  List<ServiceRequestModel> get incomingRequests => _incomingRequests;
  bool get isLoading => _isLoading;

  void listenToIncomingRequests(String providerId) {
    _requestsSubscription = _firebaseService
        .streamProviderRequests(providerId)
        .listen(
          (requests) {
            _incomingRequests = requests;
            notifyListeners();
          },
          onError: (error) {
            debugPrint(
              'RequestViewModel: provider request stream error: $error',
            );
            _incomingRequests = [];
            notifyListeners();
          },
        );
  }

  Future<void> sendRequest({
    required String consumerId,
    required String providerId,
    required String serviceType,
    required GeoPoint location,
    DateTime? scheduledDate,
    String? description,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final request = ServiceRequestModel(
        requestId: const Uuid().v4(),
        consumerId: consumerId,
        providerId: providerId,
        serviceType: serviceType,
        status: RequestStatus.pending,
        timestamp: DateTime.now(),
        location: location,
        scheduledDate: scheduledDate,
        description: description,
      );
      await _firebaseService.createServiceRequest(request);
    } catch (e) {
      print('Error sending request: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRequestStatus(
    String requestId,
    RequestStatus status,
  ) async {
    await _firebaseService.updateRequestStatus(requestId, status);
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
  }
}
