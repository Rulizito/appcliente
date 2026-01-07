// ============================================================================
// models/chat_model.dart
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Modelo para un mensaje individual
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderType; // 'customer', 'business', 'support'
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl; // Para enviar imágenes (opcional)
  final MessageType type;
  final Map<String, dynamic>? metadata; // Para archivos, ubicación, etc.

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.type = MessageType.text,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderType': senderType,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'type': type.name,
      'metadata': metadata,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderType: map['senderType'] ?? 'customer',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      imageUrl: map['imageUrl'],
      type: MessageType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => MessageType.text,
      ),
      metadata: map['metadata'],
    );
  }
}

enum MessageType {
  text,
  image,
  audio,
  video,
  file,
  location,
  order,
  system,
}

// Modelo para una conversación de chat
class ChatConversation {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String status; // 'open', 'closed', 'waiting'
  final String? assignedTo; // ID del agente de soporte asignado
  final String? assignedToName;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final int unreadCount; // Mensajes no leídos por el usuario
  final String category; // 'general', 'order', 'payment', 'technical'

  ChatConversation({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.status = 'open',
    this.assignedTo,
    this.assignedToName,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.category = 'general',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'status': status,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': lastMessageAt != null 
          ? Timestamp.fromDate(lastMessageAt!) 
          : null,
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'category': category,
    };
  }

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    return ChatConversation(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      status: map['status'] ?? 'open',
      assignedTo: map['assignedTo'],
      assignedToName: map['assignedToName'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastMessageAt: map['lastMessageAt'] != null
          ? (map['lastMessageAt'] as Timestamp).toDate()
          : null,
      lastMessage: map['lastMessage'],
      unreadCount: map['unreadCount'] ?? 0,
      category: map['category'] ?? 'general',
    );
  }

  // Obtener color según el estado
  Color getStatusColor() {
    switch (status) {
      case 'open':
        return const Color(0xFF4CAF50); // Verde
      case 'waiting':
        return const Color(0xFFFFA726); // Naranja
      case 'closed':
        return const Color(0xFF9E9E9E); // Gris
      default:
        return const Color(0xFF2196F3); // Azul
    }
  }

  // Obtener texto del estado
  String getStatusText() {
    switch (status) {
      case 'open':
        return 'Abierto';
      case 'waiting':
        return 'Esperando';
      case 'closed':
        return 'Cerrado';
      default:
        return 'Desconocido';
    }
  }
}

// Modelo para una conversación de chat con negocios
class BusinessChatConversation {
  final String id;
  final String customerId;
  final String customerName;
  final String customerAvatar;
  final String businessId;
  final String businessName;
  final String businessLogo;
  final DateTime lastMessageTime;
  final String? lastMessage;
  final int unreadCount;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  BusinessChatConversation({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerAvatar,
    required this.businessId,
    required this.businessName,
    required this.businessLogo,
    required this.lastMessageTime,
    this.lastMessage,
    this.unreadCount = 0,
    this.isActive = true,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerAvatar': customerAvatar,
      'businessId': businessId,
      'businessName': businessName,
      'businessLogo': businessLogo,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  factory BusinessChatConversation.fromMap(Map<String, dynamic> map) {
    return BusinessChatConversation(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerAvatar: map['customerAvatar'] ?? '',
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      businessLogo: map['businessLogo'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp).toDate(),
      lastMessage: map['lastMessage'],
      unreadCount: map['unreadCount'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      metadata: map['metadata'],
    );
  }
}

// Modelo para indicador de escritura
class TypingIndicator {
  final String conversationId;
  final String userId;
  final String userName;
  final String userType; // 'customer' or 'business'
  final bool isTyping;
  final DateTime timestamp;

  TypingIndicator({
    required this.conversationId,
    required this.userId,
    required this.userName,
    required this.userType,
    required this.isTyping,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'userId': userId,
      'userName': userName,
      'userType': userType,
      'isTyping': isTyping,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory TypingIndicator.fromMap(Map<String, dynamic> map) {
    return TypingIndicator(
      conversationId: map['conversationId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userType: map['userType'] ?? 'customer',
      isTyping: map['isTyping'] ?? false,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}

// Modelo para usuario del chat
class ChatUser {
  final String id;
  final String name;
  final String avatar;
  final String type; // 'customer' or 'business'
  final bool isOnline;
  final DateTime? lastSeen;
  final Map<String, dynamic>? metadata;

  ChatUser({
    required this.id,
    required this.name,
    required this.avatar,
    required this.type,
    this.isOnline = false,
    this.lastSeen,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'type': type,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'metadata': metadata,
    };
  }

  factory ChatUser.fromMap(Map<String, dynamic> map) {
    return ChatUser(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      avatar: map['avatar'] ?? '',
      type: map['type'] ?? 'customer',
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null ? (map['lastSeen'] as Timestamp).toDate() : null,
      metadata: map['metadata'],
    );
  }
}