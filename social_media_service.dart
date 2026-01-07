import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/business_model.dart' as business_model;
import '../models/order_model.dart' as order_model;

// Enums y clases movidos al nivel superior
enum SocialPlatform {
  facebook,
  twitter,
  instagram,
  whatsapp,
  telegram,
  linkedin,
  pinterest,
  tiktok,
  snapchat,
}

enum ShareContentType {
  business,
  product,
  order,
  promotion,
  review,
  referral,
  achievement,
}

class ShareableContent {
  final String id;
  final ShareContentType type;
  final String title;
  final String description;
  final String? imageUrl;
  final String? url;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  ShareableContent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.imageUrl,
    this.url,
    this.metadata,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'url': url,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ShareableContent.fromMap(Map<String, dynamic> map) {
    return ShareableContent(
      id: map['id'] ?? '',
      type: ShareContentType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => ShareContentType.business,
      ),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      url: map['url'],
      metadata: map['metadata'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class SocialProfile {
  final String id;
  final String userId;
  final SocialPlatform platform;
  final String platformId;
  final String username;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime connectedAt;
  final Map<String, dynamic>? platformData;

  SocialProfile({
    required this.id,
    required this.userId,
    required this.platform,
    required this.platformId,
    required this.username,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.isActive = true,
    required this.connectedAt,
    this.platformData,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'platform': platform.name,
      'platformId': platformId,
      'username': username,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
      'connectedAt': Timestamp.fromDate(connectedAt),
      'platformData': platformData,
    };
  }

  factory SocialProfile.fromMap(Map<String, dynamic> map) {
    return SocialProfile(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      platform: SocialPlatform.values.firstWhere(
        (platform) => platform.name == map['platform'],
        orElse: () => SocialPlatform.facebook,
      ),
      platformId: map['platformId'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'],
      email: map['email'],
      avatarUrl: map['avatarUrl'],
      accessToken: map['accessToken'],
      refreshToken: map['refreshToken'],
      expiresAt: map['expiresAt'] != null 
          ? (map['expiresAt'] as Timestamp).toDate() 
          : null,
      isActive: map['isActive'] ?? true,
      connectedAt: (map['connectedAt'] as Timestamp).toDate(),
      platformData: map['platformData'],
    );
  }
}

class Referral {
  final String id;
  final String referrerId;
  final String? referredUserId;
  final String referralCode;
  final SocialPlatform? platform;
  final String? sharedContentId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isCompleted;
  final double? rewardAmount;
  final String? rewardType;

  Referral({
    required this.id,
    required this.referrerId,
    this.referredUserId,
    required this.referralCode,
    this.platform,
    this.sharedContentId,
    required this.createdAt,
    this.completedAt,
    this.isCompleted = false,
    this.rewardAmount,
    this.rewardType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'referrerId': referrerId,
      'referredUserId': referredUserId,
      'referralCode': referralCode,
      'platform': platform?.name,
      'sharedContentId': sharedContentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'isCompleted': isCompleted,
      'rewardAmount': rewardAmount,
      'rewardType': rewardType,
    };
  }

  factory Referral.fromMap(Map<String, dynamic> map) {
    return Referral(
      id: map['id'] ?? '',
      referrerId: map['referrerId'] ?? '',
      referredUserId: map['referredUserId'],
      referralCode: map['referralCode'] ?? '',
      platform: map['platform'] != null 
          ? SocialPlatform.values.firstWhere(
              (platform) => platform.name == map['platform'],
              orElse: () => SocialPlatform.facebook,
            )
          : null,
      sharedContentId: map['sharedContentId'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      completedAt: map['completedAt'] != null 
          ? (map['completedAt'] as Timestamp).toDate() 
          : null,
      isCompleted: map['isCompleted'] ?? false,
      rewardAmount: map['rewardAmount']?.toDouble(),
      rewardType: map['rewardType'],
    );
  }
}

class SocialMediaService {
  static final SocialMediaService _instance = SocialMediaService._internal();
  factory SocialMediaService() => _instance;
  SocialMediaService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generar contenido compartible para negocio
  ShareableContent generateBusinessContent(business_model.Business business) {
    return ShareableContent(
      id: business.id,
      type: ShareContentType.business,
      title: '¡Descubre ${business.name}!',
      description: 'Los mejores productos de ${business.categories.join(', ')} con calificación ${business.rating.toStringAsFixed(1)}⭐. ¡Pide ahora y recibe en tu puerta!',
      imageUrl: null, // business.logo,
      url: 'https://tuapp.com/business/${business.id}',
      metadata: {
        'businessId': business.id,
        'businessName': business.name,
        'categories': business.categories,
        'rating': business.rating,
        'averageOrderValue': 0.0, // business.averageOrderValue,
      },
      createdAt: DateTime.now(),
    );
  }

  // Generar contenido compartible para pedido
  ShareableContent generateOrderContent(order_model.Order order) {
    return ShareableContent(
      id: order.id,
      type: ShareContentType.order,
      title: '¡Acabo de pedir en ${order.businessName}!',
      description: 'Delicioso pedido con ${order.items.length} productos por \$${order.total.toStringAsFixed(2)}. ¡Recomiendo este lugar!',
      imageUrl: null, // Podría ser una imagen del pedido
      url: 'https://tuapp.com/order/${order.id}',
      metadata: {
        'orderId': order.id,
        'businessName': order.businessName,
        'total': order.total,
        'itemCount': order.items.length,
        'items': order.items.map((item) => item.toMap()).toList(),
      },
      createdAt: DateTime.now(),
    );
  }

  // Generar contenido compartible para promoción
  ShareableContent generatePromotionContent({
    required String promotionId,
    required String title,
    required String description,
    required String discount,
    String? imageUrl,
    String? businessName,
  }) {
    return ShareableContent(
      id: promotionId,
      type: ShareContentType.promotion,
      title: title,
      description: description,
      imageUrl: imageUrl,
      url: 'https://tuapp.com/promotion/$promotionId',
      metadata: {
        'promotionId': promotionId,
        'discount': discount,
        'businessName': businessName,
      },
      createdAt: DateTime.now(),
    );
  }

  // Compartir contenido en redes sociales
  Future<bool> shareContent(
    ShareableContent content,
    SocialPlatform platform, {
    String? customMessage,
  }) async {
    try {
      switch (platform) {
        case SocialPlatform.facebook:
          return await _shareOnFacebook(content, customMessage);
        case SocialPlatform.twitter:
          return await _shareOnTwitter(content, customMessage);
        case SocialPlatform.whatsapp:
          return await _shareOnWhatsApp(content, customMessage);
        case SocialPlatform.telegram:
          return await _shareOnTelegram(content, customMessage);
        case SocialPlatform.linkedin:
          return await _shareOnLinkedIn(content, customMessage);
        case SocialPlatform.pinterest:
          return await _shareOnPinterest(content, customMessage);
        default:
          return await _shareGeneric(content, customMessage);
      }
    } catch (e) {
      print('Error sharing content: $e');
      return false;
    }
  }

  // Compartir usando el sistema nativo
  Future<bool> shareNative(ShareableContent content, {String? customMessage}) async {
    try {
      final message = customMessage ?? 
          '${content.title}\n\n${content.description}\n\n${content.url ?? ''}';
      
      await Share.share(message);
      return true;
    } catch (e) {
      print('Error sharing natively: $e');
      return false;
    }
  }

  // Métodos específicos por plataforma
  Future<bool> _shareOnFacebook(ShareableContent content, String? customMessage) async {
    try {
      final url = 'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(content.url ?? '')}';
      return await _launchUrl(url);
    } catch (e) {
      print('Error sharing on Facebook: $e');
      return false;
    }
  }

  Future<bool> _shareOnTwitter(ShareableContent content, String? customMessage) async {
    try {
      final message = customMessage ?? content.title;
      final url = 'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}&url=${Uri.encodeComponent(content.url ?? '')}';
      return await _launchUrl(url);
    } catch (e) {
      print('Error sharing on Twitter: $e');
      return false;
    }
  }

  Future<bool> _shareOnWhatsApp(ShareableContent content, String? customMessage) async {
    try {
      final message = customMessage ?? '${content.title}\n\n${content.description}\n\n${content.url ?? ''}';
      final url = 'https://wa.me/?text=${Uri.encodeComponent(message)}';
      return await _launchUrl(url);
    } catch (e) {
      print('Error sharing on WhatsApp: $e');
      return false;
    }
  }

  Future<bool> _shareOnTelegram(ShareableContent content, String? customMessage) async {
    try {
      final message = customMessage ?? '${content.title}\n\n${content.description}\n\n${content.url ?? ''}';
      final url = 'https://t.me/share/url?url=${Uri.encodeComponent(content.url ?? '')}&text=${Uri.encodeComponent(message)}';
      return await _launchUrl(url);
    } catch (e) {
      print('Error sharing on Telegram: $e');
      return false;
    }
  }

  Future<bool> _shareOnLinkedIn(ShareableContent content, String? customMessage) async {
    try {
      final url = 'https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(content.url ?? '')}';
      return await _launchUrl(url);
    } catch (e) {
      print('Error sharing on LinkedIn: $e');
      return false;
    }
  }

  Future<bool> _shareOnPinterest(ShareableContent content, String? customMessage) async {
    try {
      final description = customMessage ?? content.description;
      final url = 'https://pinterest.com/pin/create/button/?url=${Uri.encodeComponent(content.url ?? '')}&description=${Uri.encodeComponent(description)}&media=${Uri.encodeComponent(content.imageUrl ?? '')}';
      return await _launchUrl(url);
    } catch (e) {
      print('Error sharing on Pinterest: $e');
      return false;
    }
  }

  Future<bool> _shareGeneric(ShareableContent content, String? customMessage) async {
    return await shareNative(content, customMessage: customMessage);
  }

  Future<bool> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  // Generar código de referido
  String generateReferralCode(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = userId.hashCode ^ timestamp;
    return 'REF${hash.abs().toString().substring(0, 8).toUpperCase()}';
  }

  // Crear enlace de referido
  Future<Referral> createReferralLink(String userId, {
    SocialPlatform? platform,
    String? contentId,
  }) async {
    try {
      final referralCode = generateReferralCode(userId);
      final referral = Referral(
        id: _firestore.collection('referrals').doc().id,
        referrerId: userId,
        referralCode: referralCode,
        platform: platform,
        sharedContentId: contentId,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('referrals')
          .doc(referral.id)
          .set(referral.toMap());

      return referral;
    } catch (e) {
      print('Error creating referral link: $e');
      rethrow;
    }
  }

  // Completar referido
  Future<void> completeReferral(String referralCode, String referredUserId) async {
    try {
      final referralSnapshot = await _firestore
          .collection('referrals')
          .where('referralCode', isEqualTo: referralCode)
          .where('isCompleted', isEqualTo: false)
          .limit(1)
          .get();

      if (referralSnapshot.docs.isEmpty) {
        throw Exception('Código de referido no válido o ya utilizado');
      }

      final referralDoc = referralSnapshot.docs.first;
      final referral = Referral.fromMap(referralDoc.data());

      // Actualizar referido
      await _firestore
          .collection('referrals')
          .doc(referral.id)
          .update({
        'referredUserId': referredUserId,
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
        'rewardAmount': 50.0, // Reward configurable
        'rewardType': 'points',
      });

      // Otorgar recompensa al referente
      await _grantReferralReward(referral.referrerId, referral);

      // Otorgar bonificación al referido
      await _grantReferralBonus(referredUserId);

    } catch (e) {
      print('Error completing referral: $e');
      rethrow;
    }
  }

  Future<void> _grantReferralReward(String referrerId, Referral referral) async {
    try {
      // Aquí se integraría con el sistema de lealtad
      await _firestore.collection('loyalty_rewards').add({
        'userId': referrerId,
        'type': 'referral',
        'amount': referral.rewardAmount ?? 50.0,
        'referralId': referral.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error granting referral reward: $e');
    }
  }

  Future<void> _grantReferralBonus(String referredUserId) async {
    try {
      // Aquí se integraría con el sistema de lealtad
      await _firestore.collection('loyalty_rewards').add({
        'userId': referredUserId,
        'type': 'referral_bonus',
        'amount': 25.0, // Bonus configurable
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error granting referral bonus: $e');
    }
  }

  // Obtener perfiles sociales conectados del usuario
  Future<List<SocialProfile>> getUserSocialProfiles(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('social_profiles')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => SocialProfile.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting user social profiles: $e');
      return [];
    }
  }

  // Conectar perfil social
  Future<SocialProfile> connectSocialProfile({
    required String userId,
    required SocialPlatform platform,
    required String platformId,
    required String username,
    String? displayName,
    String? email,
    String? avatarUrl,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    Map<String, dynamic>? platformData,
  }) async {
    try {
      final profile = SocialProfile(
        id: _firestore.collection('social_profiles').doc().id,
        userId: userId,
        platform: platform,
        platformId: platformId,
        username: username,
        displayName: displayName,
        email: email,
        avatarUrl: avatarUrl,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        connectedAt: DateTime.now(),
        platformData: platformData,
      );

      await _firestore
          .collection('social_profiles')
          .doc(profile.id)
          .set(profile.toMap());

      return profile;
    } catch (e) {
      print('Error connecting social profile: $e');
      rethrow;
    }
  }

  // Desconectar perfil social
  Future<void> disconnectSocialProfile(String profileId) async {
    try {
      await _firestore
          .collection('social_profiles')
          .doc(profileId)
          .update({
        'isActive': false,
        'disconnectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error disconnecting social profile: $e');
    }
  }

  // Obtener estadísticas de compartición
  Future<Map<String, dynamic>> getSharingStats(String userId) async {
    try {
      final sharesSnapshot = await _firestore
          .collection('social_shares')
          .where('userId', isEqualTo: userId)
          .get();

      final referralsSnapshot = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .get();

      final totalShares = sharesSnapshot.docs.length;
      final totalReferrals = referralsSnapshot.docs.length;
      final completedReferrals = referralsSnapshot.docs
          .where((doc) => doc['isCompleted'] == true)
          .length;

      // Agrupar por plataforma
      final platformStats = <String, int>{};
      for (final doc in sharesSnapshot.docs) {
        final platform = doc['platform'] as String;
        platformStats[platform] = (platformStats[platform] ?? 0) + 1;
      }

      return {
        'totalShares': totalShares,
        'totalReferrals': totalReferrals,
        'completedReferrals': completedReferrals,
        'conversionRate': totalReferrals > 0 
            ? (completedReferrals / totalReferrals * 100).toStringAsFixed(2) + '%'
            : '0%',
        'platformStats': platformStats,
        'totalEarned': completedReferrals * 50.0, // Assuming $50 per completed referral
      };
    } catch (e) {
      print('Error getting sharing stats: $e');
      return {};
    }
  }

  // Registrar acción de compartición
  Future<void> logShareAction({
    required String userId,
    required SocialPlatform platform,
    required String contentType,
    required String contentId,
    String? referralCode,
  }) async {
    try {
      await _firestore.collection('social_shares').add({
        'userId': userId,
        'platform': platform.name,
        'contentType': contentType,
        'contentId': contentId,
        'referralCode': referralCode,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging share action: $e');
    }
  }

  // Obtener información de plataforma
  Map<String, dynamic> getPlatformInfo(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.facebook:
        return {
          'name': 'Facebook',
          'icon': 'assets/icons/facebook.png',
          'color': '#1877F2',
          'shareUrl': 'https://www.facebook.com/sharer/sharer.php',
        };
      case SocialPlatform.twitter:
        return {
          'name': 'Twitter',
          'icon': 'assets/icons/twitter.png',
          'color': '#1DA1F2',
          'shareUrl': 'https://twitter.com/intent/tweet',
        };
      case SocialPlatform.instagram:
        return {
          'name': 'Instagram',
          'icon': 'assets/icons/instagram.png',
          'color': '#E4405F',
          'shareUrl': null, // Instagram doesn't support direct sharing via URL
        };
      case SocialPlatform.whatsapp:
        return {
          'name': 'WhatsApp',
          'icon': 'assets/icons/whatsapp.png',
          'color': '#25D366',
          'shareUrl': 'https://wa.me/',
        };
      case SocialPlatform.telegram:
        return {
          'name': 'Telegram',
          'icon': 'assets/icons/telegram.png',
          'color': '#0088CC',
          'shareUrl': 'https://t.me/share/url',
        };
      case SocialPlatform.linkedin:
        return {
          'name': 'LinkedIn',
          'icon': 'assets/icons/linkedin.png',
          'color': '#0077B5',
          'shareUrl': 'https://www.linkedin.com/sharing/share-offsite/',
        };
      case SocialPlatform.pinterest:
        return {
          'name': 'Pinterest',
          'icon': 'assets/icons/pinterest.png',
          'color': '#BD081C',
          'shareUrl': 'https://pinterest.com/pin/create/button/',
        };
      case SocialPlatform.tiktok:
        return {
          'name': 'TikTok',
          'icon': 'assets/icons/tiktok.png',
          'color': '#000000',
          'shareUrl': null, // TikTok doesn't support direct sharing via URL
        };
      case SocialPlatform.snapchat:
        return {
          'name': 'Snapchat',
          'icon': 'assets/icons/snapchat.png',
          'color': '#FFFC00',
          'shareUrl': null, // Snapchat doesn't support direct sharing via URL
        };
    }
  }
}
