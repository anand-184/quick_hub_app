import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message_model.dart';
import '../services/notification_service.dart';

class ChatViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;

  List<ChatMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;

  void listenToMessages(String requestId) {
    _firestore
        .collection('requests')
        .doc(requestId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _messages = snapshot.docs.map((doc) => ChatMessageModel.fromJson(doc.data())).toList();
      notifyListeners();
    });
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    required String requestId,
  }) async {
    try {
      final message = ChatMessageModel(
        messageId: const Uuid().v4(),
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        timestamp: DateTime.now(),
        requestId: requestId,
      );

      await _firestore
          .collection('requests')
          .doc(requestId)
          .collection('messages')
          .doc(message.messageId)
          .set(message.toJson());

      // Send push notification to receiver
      await NotificationService().sendNotification(
        recipientId: receiverId,
        title: 'New Message',
        body: text,
        data: {
          'type': 'chat',
          'requestId': requestId,
          'senderId': senderId,
        },
      );
    } catch (e) {
      print('Error sending message: $e');
    }
  }
}
