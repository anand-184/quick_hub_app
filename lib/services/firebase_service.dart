import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/service_request_model.dart';
import '../models/review_model.dart';
import '../models/notification_model.dart';
import '../models/service_category_model.dart';
import '../models/complaint_model.dart';
import 'notification_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== AUTHENTICATION ====================

  Future<UserCredential?> registerUser({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> loginUser({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<bool> doesEmailExist(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  String? get currentUserId => _auth.currentUser?.uid;

  // ==================== USERS ====================

  Future<void> saveUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toJson());
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to save user profile for ${user.uid}: ${e.code}',
      );
      rethrow;
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final profileData = <String, dynamic>{
          ...data,
          'uid': (data['uid'] as String?)?.isNotEmpty == true
              ? data['uid']
              : doc.id,
        };
        return UserModel.fromJson(profileData);
      }
      return null;
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to read user profile for $uid: ${e.code}',
      );
      return null;
    } catch (e) {
      debugPrint(
        'FirebaseService: unexpected error reading user profile for $uid: $e',
      );
      return null;
    }
  }

  Future<void> updatePushToken(String uid, String? token) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'pushToken': token,
      });
    } on FirebaseException catch (e) {
      debugPrint('FirebaseService: failed to update push token: ${e.code}');
    } catch (e) {
      debugPrint('FirebaseService: unexpected push token error: $e');
    }
  }

  Future<void> updateUserLocation(
    String uid,
    GeoPoint location,
    String? fullAddress,
  ) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'location': location,
        'fullAddress': fullAddress,
      });
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to update user location for $uid: ${e.code}',
      );
    } catch (e) {
      debugPrint(
        'FirebaseService: unexpected user location error for $uid: $e',
      );
    }
  }

  Stream<List<T>> _safeQueryStream<T>(
    Query<Map<String, dynamic>> query,
    T Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) mapper,
  ) {
    return query.snapshots().transform(
      StreamTransformer.fromHandlers(
        handleData:
            (
              QuerySnapshot<Map<String, dynamic>> snapshot,
              EventSink<List<T>> sink,
            ) {
              try {
                sink.add(snapshot.docs.map(mapper).toList());
              } catch (e) {
                debugPrint('FirebaseService: snapshot transform error: $e');
                sink.add([]);
              }
            },
        handleError: (error, stackTrace, EventSink<List<T>> sink) {
          debugPrint('FirebaseService: snapshot stream error: $error');
          sink.add([]);
        },
      ),
    );
  }

  Stream<List<UserModel>> getNearbyActiveProviders({String? serviceType}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('role', isEqualTo: 'provider')
        .where('isActive', isEqualTo: true);

    if (serviceType != null && serviceType.isNotEmpty) {
      query = query.where('serviceType', isEqualTo: serviceType);
    }

    return _safeQueryStream<UserModel>(
      query,
      (doc) => UserModel.fromJson(doc.data()),
    );
  }

  // ==================== SERVICE REQUESTS ====================

  Future<void> createServiceRequest(ServiceRequestModel request) async {
    try {
      await _firestore
          .collection('requests')
          .doc(request.requestId)
          .set(request.toJson());
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to create service request ${request.requestId}: ${e.code}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        'FirebaseService: unexpected create service request error: $e',
      );
      rethrow;
    }
  }

  Stream<List<ServiceRequestModel>> streamProviderRequests(String providerId) {
    // Note: This requires an index (providerId: ASC, timestamp: DESC/ASC)
    // We'll use ASC for now to match common default behavior if DESC index is missing
    return _safeQueryStream<ServiceRequestModel>(
      _firestore
          .collection('requests')
          .where('providerId', isEqualTo: providerId)
          .orderBy('timestamp', descending: false),
      (doc) => ServiceRequestModel.fromJson(doc.data()),
    );
  }

  Stream<List<ServiceRequestModel>> streamConsumerRequests(String consumerId) {
    // UPDATED: Set descending to false to match your currently enabled index
    return _safeQueryStream<ServiceRequestModel>(
      _firestore
          .collection('requests')
          .where('consumerId', isEqualTo: consumerId)
          .orderBy('timestamp', descending: false),
      (doc) => ServiceRequestModel.fromJson(doc.data()),
    );
  }

  Future<void> updateRequestStatus(
    String requestId,
    RequestStatus status,
  ) async {
    String statusString;
    switch (status) {
      case RequestStatus.accepted:
        statusString = 'accepted';
        break;
      case RequestStatus.inProgress:
        statusString = 'inProgress';
        break;
      case RequestStatus.completed:
        statusString = 'completed';
        break;
      case RequestStatus.declined:
        statusString = 'declined';
        break;
      case RequestStatus.cancelled:
        statusString = 'cancelled';
        break;
      default:
        statusString = 'pending';
    }
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': statusString,
      });
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to update request status for $requestId: ${e.code}',
      );
    } catch (e) {
      debugPrint(
        'FirebaseService: unexpected request status update error for $requestId: $e',
      );
    }
  }

  // ==================== PAYMENTS & TRANSACTIONS ====================

  Future<void> processPayment({
    required String requestId,
    required String consumerId,
    required String providerId,
    required double totalAmount,
    required String paymentMethod,
  }) async {
    final commission = totalAmount * 0.10; // 10% platform fee
    final providerEarnings = totalAmount - commission;

    final batch = _firestore.batch();

    // 1. Mark request as paid
    final requestRef = _firestore.collection('requests').doc(requestId);
    batch.update(requestRef, {'paymentStatus': 'paid'});

    // 2. Create transaction record
    final transactionRef = _firestore.collection('transactions').doc();
    batch.set(transactionRef, {
      'transactionId': transactionRef.id,
      'requestId': requestId,
      'consumerId': consumerId,
      'providerId': providerId,
      'totalAmount': totalAmount,
      'commissionAmount': commission,
      'providerEarnings': providerEarnings,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'completed',
      'paymentMethod': paymentMethod,
      'isProviderPaid': false,
    });

    try {
      await batch.commit();

      // Notify provider about the payment
      await NotificationService().sendNotification(
        recipientId: providerId,
        title: 'Payment Received',
        body:
            'You have received ₹${providerEarnings.toStringAsFixed(2)} for service.',
        data: {'type': 'payment_received', 'requestId': requestId},
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to process payment for $requestId: ${e.code}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        'FirebaseService: unexpected payment processing error for $requestId: $e',
      );
      rethrow;
    }
  }

  // ==================== REVIEWS ====================

  Future<void> submitReview(ReviewModel review) async {
    final batch = _firestore.batch();

    final reviewRef = _firestore.collection('reviews').doc(review.reviewId);
    batch.set(reviewRef, review.toJson());

    final providerRef = _firestore.collection('users').doc(review.providerId);

    try {
      await _firestore.runTransaction((transaction) async {
        final providerDoc = await transaction.get(providerRef);
        if (providerDoc.exists) {
          final data = providerDoc.data()!;
          final int currentCount = data['reviewCount'] ?? 0;
          final double currentRating =
              (data['rating'] as num?)?.toDouble() ?? 0.0;

          final double newRating =
              ((currentRating * currentCount) + review.rating) /
              (currentCount + 1);

          transaction.update(providerRef, {
            'rating': newRating,
            'reviewCount': currentCount + 1,
          });
        }
      });

      await batch.commit();

      // Notify provider about the new review
      await NotificationService().sendNotification(
        recipientId: review.providerId,
        title: 'New Review Received',
        body: 'You received a ${review.rating} star review for your service.',
        data: {'type': 'new_review', 'requestId': review.requestId},
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to submit review ${review.reviewId}: ${e.code}',
      );
      rethrow;
    } catch (e) {
      debugPrint('FirebaseService: unexpected submit review error: $e');
      rethrow;
    }
  }

  Stream<List<ReviewModel>> streamProviderReviews(String providerId) {
    return _safeQueryStream<ReviewModel>(
      _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .orderBy('timestamp', descending: true),
      (doc) => ReviewModel.fromJson(doc.data()),
    );
  }

  // ==================== NOTIFICATIONS ====================

  Future<void> saveNotification(NotificationModel notification) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notification.notificationId)
          .set(notification.toJson());
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to save notification ${notification.notificationId}: ${e.code}',
      );
    } catch (e) {
      debugPrint('FirebaseService: unexpected notification save error: $e');
    }
  }

  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    return _safeQueryStream<NotificationModel>(
      _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .orderBy('timestamp', descending: true),
      (doc) => NotificationModel.fromJson(doc.data()),
    );
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to mark notification read $notificationId: ${e.code}',
      );
    } catch (e) {
      debugPrint(
        'FirebaseService: unexpected mark notification read error: $e',
      );
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to delete notification $notificationId: ${e.code}',
      );
    } catch (e) {
      debugPrint('FirebaseService: unexpected delete notification error: $e');
    }
  }

  Future<void> deleteRequest(String requestId) async {
    try {
      await _firestore.collection('requests').doc(requestId).delete();
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to delete request $requestId: ${e.code}',
      );
    } catch (e) {
      debugPrint('FirebaseService: unexpected delete request error: $e');
    }
  }

  // ==================== CATEGORIES ====================

  Future<List<ServiceCategoryModel>> getCategories() async {
    try {
      final snapshot = await _firestore.collection('categories').get();
      return snapshot.docs
          .map((doc) => ServiceCategoryModel.fromJson(doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      debugPrint('FirebaseService: failed to load categories: ${e.code}');
      return [];
    } catch (e) {
      debugPrint('FirebaseService: unexpected categories loading error: $e');
      return [];
    }
  }

  // ==================== COMPLAINTS ====================

  Future<void> submitComplaint(ComplaintModel complaint) async {
    try {
      await _firestore
          .collection('complaints')
          .doc(complaint.complaintId)
          .set(complaint.toJson());
    } on FirebaseException catch (e) {
      debugPrint(
        'FirebaseService: failed to save complaint ${complaint.complaintId}: ${e.code}',
      );
    } catch (e) {
      debugPrint('FirebaseService: unexpected complaint save error: $e');
    }
  }

  Stream<List<ComplaintModel>> streamAllComplaints() {
    return _safeQueryStream<ComplaintModel>(
      _firestore
          .collection('complaints')
          .orderBy('timestamp', descending: true),
      (doc) => ComplaintModel.fromJson(doc.data()),
    );
  }
}
