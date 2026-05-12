import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  
  Future<UserCredential?> registerUser({required String email, required String password}) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }
  
  Future<UserCredential?> loginUser({required String email, required String password}) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<bool> doesEmailExist(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    return snapshot.docs.isNotEmpty;
  }
  
  Future<void> logout() async {
    await _auth.signOut();
  }

  String? get currentUserId => _auth.currentUser?.uid;

  // ==================== USERS ====================



  Future<void> saveUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toJson());
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromJson(doc.data()!);
    }
    return null;
  }
  
  Future<void> updatePushToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({'pushToken': token});
  }

  Stream<List<UserModel>> getNearbyActiveProviders({String? serviceType}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('role', isEqualTo: 'provider')
        .where('isActive', isEqualTo: true);
        
    if (serviceType != null && serviceType.isNotEmpty) {
      query = query.where('serviceType', isEqualTo: serviceType);
    }
    
    return query
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromJson(doc.data())).toList());
  }

  // ==================== SERVICE REQUESTS ====================

  Future<void> createServiceRequest(ServiceRequestModel request) async {
    await _firestore.collection('requests').doc(request.requestId).set(request.toJson());
  }

  Stream<List<ServiceRequestModel>> streamProviderRequests(String providerId) {
    // Note: This requires an index (providerId: ASC, timestamp: DESC/ASC)
    // We'll use ASC for now to match common default behavior if DESC index is missing
    return _firestore
        .collection('requests')
        .where('providerId', isEqualTo: providerId)
        .orderBy('timestamp', descending: false) 
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ServiceRequestModel.fromJson(doc.data())).toList());
  }
  
  Stream<List<ServiceRequestModel>> streamConsumerRequests(String consumerId) {
    // UPDATED: Set descending to false to match your currently enabled index
    return _firestore
        .collection('requests')
        .where('consumerId', isEqualTo: consumerId)
        .orderBy('timestamp', descending: false) 
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ServiceRequestModel.fromJson(doc.data())).toList());
  }

  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    String statusString;
    switch (status) {
      case RequestStatus.accepted: statusString = 'accepted'; break;
      case RequestStatus.inProgress: statusString = 'inProgress'; break;
      case RequestStatus.completed: statusString = 'completed'; break;
      case RequestStatus.declined: statusString = 'declined'; break;
      case RequestStatus.cancelled: statusString = 'cancelled'; break;
      default: statusString = 'pending';
    }
    await _firestore.collection('requests').doc(requestId).update({'status': statusString});
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

    await batch.commit();

    // Notify provider about the payment
    await NotificationService().sendNotification(
      recipientId: providerId,
      title: 'Payment Received',
      body: 'You have received ₹${providerEarnings.toStringAsFixed(2)} for service.',
      data: {'type': 'payment_received', 'requestId': requestId},
    );
  }

  // ==================== REVIEWS ====================

  Future<void> submitReview(ReviewModel review) async {
    final batch = _firestore.batch();
    
    final reviewRef = _firestore.collection('reviews').doc(review.reviewId);
    batch.set(reviewRef, review.toJson());

    final providerRef = _firestore.collection('users').doc(review.providerId);
    
    await _firestore.runTransaction((transaction) async {
      final providerDoc = await transaction.get(providerRef);
      if (providerDoc.exists) {
        final data = providerDoc.data()!;
        final int currentCount = data['reviewCount'] ?? 0;
        final double currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
        
        final double newRating = ((currentRating * currentCount) + review.rating) / (currentCount + 1);
        
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
  }

  Stream<List<ReviewModel>> streamProviderReviews(String providerId) {
    return _firestore
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ReviewModel.fromJson(doc.data())).toList());
  }

  // ==================== NOTIFICATIONS ====================

  Future<void> saveNotification(NotificationModel notification) async {
    await _firestore.collection('notifications').doc(notification.notificationId).set(notification.toJson());
  }

  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => NotificationModel.fromJson(doc.data())).toList());
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  Future<void> deleteRequest(String requestId) async {
    await _firestore.collection('requests').doc(requestId).delete();
  }

  // ==================== CATEGORIES ====================

  Future<List<ServiceCategoryModel>> getCategories() async {
    final snapshot = await _firestore.collection('categories').get();
    return snapshot.docs.map((doc) => ServiceCategoryModel.fromJson(doc.data())).toList();
  }

  // ==================== COMPLAINTS ====================

  Future<void> submitComplaint(ComplaintModel complaint) async {
    await _firestore.collection('complaints').doc(complaint.complaintId).set(complaint.toJson());
  }



  Stream<List<ComplaintModel>> streamAllComplaints() {
    return _firestore
        .collection('complaints')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ComplaintModel.fromJson(doc.data())).toList());
  }
}
