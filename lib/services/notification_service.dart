import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../view/screens/notifications_screen.dart';
import '../main.dart';
import 'firebase_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Base URL for the notification service on Render
  final String _renderUrl = "https://quick-hub-project-1.onrender.com/send-notification";

  Future<void> initialize() async {
    // 1. Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
        );
      },
    );

    // 2. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print('User granted notification permission');
      
      // 3. Handle Foreground Messages (This makes them pop up)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showLocalNotification(
            title: message.notification!.title ?? 'Quick Hub',
            body: message.notification!.body ?? '',
          );
        }
      });
      
      // 4. Handle background message click
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
         if (kDebugMode) print('A new onMessageOpenedApp event was published!');
         navigatorKey.currentState?.push(
           MaterialPageRoute(builder: (context) => const NotificationsScreen()),
         );
      });

      // 5. Handle terminated state message click
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(const Duration(seconds: 1), () {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
          );
        });
      }
    }
  }

  Future<void> _showLocalNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'quick_hub_channel',
      'Quick Hub Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotifications.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Save to Firestore for in-app history
      final notificationId = _firestore.collection('notifications').doc().id;
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
      if (!userDoc.exists) return;
      
      final pushToken = userDoc.data()?['pushToken'];
      if (pushToken == null || pushToken.toString().isEmpty) return;

      // 3. Call Render service
      await http.post(
        Uri.parse(_renderUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': pushToken,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) print("Error in notification service: $e");
    }
  }

  // Helper method to update token in Firestore
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
}
