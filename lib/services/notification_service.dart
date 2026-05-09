import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'firebase_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  // Base URL for the notification service on Render
  final String _renderUrl = "https://quick-hub-notifications.onrender.com/send-notification";

  Future<void> initialize() async {
    // 1. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print('User granted notification permission');
      
      // 2. Get FCM Token
      String? token = await _fcm.getToken();
      if (token != null) {
        if (kDebugMode) print("FCM Token: $token");
        // We will update the token in Firestore when the user logs in
      }

      // 3. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) print('Got a message whilst in the foreground!');
        if (kDebugMode) print('Message data: ${message.data}');

        if (message.notification != null) {
          if (kDebugMode) {
            print('Message also contained a notification: ${message.notification!.title}');
          }
          // You could show a local notification here if needed
        }
      });
      
      // 4. Handle background/terminated message click
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
         if (kDebugMode) print('A new onMessageOpenedApp event was published!');
         // Navigate to specific screen based on message.data if needed
      });
    } else {
      if (kDebugMode) print('User declined or has not accepted notification permission');
    }
  }

  // Call this after login to sync the token
  Future<void> updateToken(String userId) async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await FirebaseService().updatePushToken(userId, token);
      }
    } catch (e) {
      if (kDebugMode) print("Error updating push token: $e");
    }
  }

  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Save to Firestore for in-app history
      final notificationId = FirebaseFirestore.instance.collection('notifications').doc().id;
      final notification = NotificationModel(
        notificationId: notificationId,
        recipientId: recipientId,
        title: title,
        body: body,
        timestamp: DateTime.now(),
        isRead: false,
      );
      await FirebaseService().saveNotification(notification);

      // 2. Fetch recipient's push token
      final userDoc = await _firestore.collection('users').doc(recipientId).get();
      if (!userDoc.exists) {
        print("User $recipientId does not exist in Firestore.");
        return;
      }
      
      final userData = userDoc.data();
      final pushToken = userData?['pushToken'];
      
      if (pushToken == null || pushToken.toString().isEmpty) {
        print("No push token found for user $recipientId. Only in-app notification saved.");
        return;
      }

      // 3. Call Render service for push notification
      final response = await http.post(
        Uri.parse(_renderUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': pushToken,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print("Push notification sent successfully via Render to $recipientId");
      } else {
        print("Render service returned error (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("Error in notification service: $e");
    }
  }
}
