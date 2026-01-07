import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final Map<String, dynamic>? preferences;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.preferences,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isActive': isActive,
      'preferences': preferences,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      photoUrl: map['photoUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastLoginAt: map['lastLoginAt'] != null 
          ? (map['lastLoginAt'] as Timestamp).toDate() 
          : null,
      isActive: map['isActive'] ?? true,
      preferences: map['preferences'],
    );
  }
}
