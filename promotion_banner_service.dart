// ============================================================================
// services/promotion_banner_service.dart - Servicio de Banners Promocionales
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/promotion_banner_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class PromotionBannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  // Obtener banners activos para el usuario actual
  Stream<List<PromotionBanner>> getActiveBannersForUser() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('promotion_banners')
        .where('isActive', isEqualTo: true)
        .where('startDate', isLessThanOrEqualTo: Timestamp.now())
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('priority', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final banners = snapshot.docs
              .map((doc) => PromotionBanner.fromFirestore(doc))
              .toList();

          // Filtrar banners para el usuario actual
          final userData = await _authService.getUserData(userId);
          final filteredBanners = banners.where((banner) {
            return banner.isForUser(userId, userData: userData);
          }).toList();

          return filteredBanners;
        });
  }

  // Obtener banners por tipo
  Stream<List<PromotionBanner>> getBannersByType(BannerType type) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('promotion_banners')
        .where('isActive', isEqualTo: true)
        .where('type', isEqualTo: type.value)
        .where('startDate', isLessThanOrEqualTo: Timestamp.now())
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('priority', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final banners = snapshot.docs
              .map((doc) => PromotionBanner.fromFirestore(doc))
              .toList();

          final userData = await _authService.getUserData(userId);
          return banners.where((banner) {
            return banner.isForUser(userId, userData: userData);
          }).toList();
        });
  }

  // Obtener banners hero (principales)
  Stream<List<PromotionBanner>> getHeroBanners() {
    return getBannersByType(BannerType.hero);
  }

  // Obtener banners de carrusel
  Stream<List<PromotionBanner>> getCarouselBanners() {
    return getBannersByType(BannerType.carousel);
  }

  // Obtener banners flash
  Stream<List<PromotionBanner>> getFlashBanners() {
    return getBannersByType(BannerType.flash);
  }

  // Obtener banners por categoría
  Stream<List<PromotionBanner>> getBannersForCategory(String categoryId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('promotion_banners')
        .where('isActive', isEqualTo: true)
        .where('targetCategories', arrayContains: categoryId)
        .where('startDate', isLessThanOrEqualTo: Timestamp.now())
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('priority', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final banners = snapshot.docs
              .map((doc) => PromotionBanner.fromFirestore(doc))
              .toList();

          final userData = await _authService.getUserData(userId);
          return banners.where((banner) {
            return banner.isForUser(userId, userData: userData);
          }).toList();
        });
  }

  // Obtener banners por negocio
  Stream<List<PromotionBanner>> getBannersForBusiness(String businessId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('promotion_banners')
        .where('isActive', isEqualTo: true)
        .where('targetBusinessIds', arrayContains: businessId)
        .where('startDate', isLessThanOrEqualTo: Timestamp.now())
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('priority', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final banners = snapshot.docs
              .map((doc) => PromotionBanner.fromFirestore(doc))
              .toList();

          final userData = await _authService.getUserData(userId);
          return banners.where((banner) {
            return banner.isForUser(userId, userData: userData);
          }).toList();
        });
  }

  // Registrar impresión de banner
  Future<void> recordImpression(String bannerId) async {
    try {
      final bannerRef = _firestore.collection('promotion_banners').doc(bannerId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(bannerRef);
        if (doc.exists) {
          final currentImpressions = doc.get('currentImpressions') ?? 0;
          transaction.update(bannerRef, {
            'currentImpressions': currentImpressions + 1,
            'updatedAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      print('Error recording impression: $e');
    }
  }

  // Registrar clic en banner
  Future<void> recordClick(String bannerId) async {
    try {
      final bannerRef = _firestore.collection('promotion_banners').doc(bannerId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(bannerRef);
        if (doc.exists) {
          final currentClicks = doc.get('currentClicks') ?? 0;
          transaction.update(bannerRef, {
            'currentClicks': currentClicks + 1,
            'updatedAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      print('Error recording click: $e');
    }
  }

  // Ejecutar acción del banner
  Future<bool> executeBannerAction(PromotionBanner banner, BuildContext context) async {
    try {
      // Registrar clic
      await recordClick(banner.id);

      switch (banner.action) {
        case BannerAction.none:
          return false;

        case BannerAction.navigate:
          if (banner.actionData != null) {
            Navigator.pushNamed(context, banner.actionData!);
          }
          return true;

        case BannerAction.coupon:
          if (banner.actionData != null) {
            // Navegar a pantalla de cupones o mostrar diálogo
            _showCouponDialog(context, banner.actionData!);
          }
          return true;

        case BannerAction.business:
          if (banner.actionData != null) {
            Navigator.pushNamed(
              context,
              '/business_detail',
              arguments: banner.actionData,
            );
          }
          return true;

        case BannerAction.category:
          if (banner.actionData != null) {
            // Navegar a lista de negocios por categoría
            _navigateToCategory(context, banner.actionData!);
          }
          return true;

        case BannerAction.search:
          if (banner.actionData != null) {
            // Navegar a búsqueda con término predefinido
            Navigator.pushNamed(
              context,
              '/enhanced_search',
              arguments: {'query': banner.actionData},
            );
          }
          return true;

        case BannerAction.share:
          await _shareBanner(context, banner);
          return true;

        case BannerAction.external:
          if (banner.externalUrl != null) {
            // Abrir URL externa (requiere url_launcher)
            _launchExternalUrl(banner.externalUrl!);
          }
          return true;

        case BannerAction.call:
          if (banner.actionData != null) {
            // Hacer llamada telefónica (requiere url_launcher)
            _makePhoneCall(banner.actionData!);
          }
          return true;

        case BannerAction.order:
          if (banner.actionData != null) {
            // Navegar a negocio para hacer pedido
            Navigator.pushNamed(
              context,
              '/business_detail',
              arguments: banner.actionData,
            );
          }
          return true;
      }
    } catch (e) {
      print('Error executing banner action: $e');
      return false;
    }
    return false;
  }

  // Crear banner nuevo (para admin)
  Future<String> createBanner(PromotionBanner banner) async {
    try {
      final docRef = await _firestore.collection('promotion_banners').add(banner.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating banner: $e');
      throw e;
    }
  }

  // Actualizar banner (para admin)
  Future<bool> updateBanner(String bannerId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('promotion_banners').doc(bannerId).update({
        ...updates,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error updating banner: $e');
      return false;
    }
  }

  // Eliminar banner (para admin)
  Future<bool> deleteBanner(String bannerId) async {
    try {
      await _firestore.collection('promotion_banners').doc(bannerId).delete();
      return true;
    } catch (e) {
      print('Error deleting banner: $e');
      return false;
    }
  }

  // Obtener estadísticas de banners (para admin)
  Future<Map<String, dynamic>> getBannerStats() async {
    try {
      final snapshot = await _firestore.collection('promotion_banners').get();
      final banners = snapshot.docs.map((doc) => PromotionBanner.fromFirestore(doc)).toList();

      final totalBanners = banners.length;
      final activeBanners = banners.where((b) => b.isCurrentlyActive).length;
      final totalImpressions = banners.fold(0, (sum, banner) => sum + banner.currentImpressions);
      final totalClicks = banners.fold(0, (sum, banner) => sum + banner.currentClicks);
      final ctr = totalImpressions > 0 ? (totalClicks / totalImpressions) * 100 : 0.0;

      // Estadísticas por tipo
      final statsByType = <String, int>{};
      for (final banner in banners) {
        statsByType[banner.type.value] = (statsByType[banner.type.value] ?? 0) + 1;
      }

      return {
        'totalBanners': totalBanners,
        'activeBanners': activeBanners,
        'totalImpressions': totalImpressions,
        'totalClicks': totalClicks,
        'ctr': ctr,
        'statsByType': statsByType,
      };
    } catch (e) {
      print('Error getting banner stats: $e');
      return {};
    }
  }

  // Métodos privados para acciones específicas
  void _showCouponDialog(BuildContext context, String couponCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¡Cupón Obtenido!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Has obtenido un cupón especial:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                couponCode,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Este cupón ha sido agregado a tu cuenta.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/coupons');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ver Cupones'),
          ),
        ],
      ),
    );
  }

  void _navigateToCategory(BuildContext context, String categoryId) {
    // Navegar a lista de negocios por categoría
    Navigator.pushNamed(
      context,
      '/business_list',
      arguments: {'categoryId': categoryId},
    );
  }

  Future<void> _shareBanner(BuildContext context, PromotionBanner banner) async {
    // Implementar compartir (requiere share package)
    final text = '${banner.title}\n${banner.description}\n¡Descarga la app!';
    
    // Aquí implementaríamos el compartir real
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compartiendo promoción...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _launchExternalUrl(String url) {
    // Implementar launcher (requiere url_launcher package)
    print('Launching URL: $url');
  }

  void _makePhoneCall(String phoneNumber) {
    // Implementar llamada (requiere url_launcher package)
    print('Calling: $phoneNumber');
  }

  // Obtener banners personalizados basados en comportamiento del usuario
  Stream<List<PromotionBanner>> getPersonalizedBanners() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('promotion_banners')
        .where('isActive', isEqualTo: true)
        .where('startDate', isLessThanOrEqualTo: Timestamp.now())
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('priority', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final banners = snapshot.docs
              .map((doc) => PromotionBanner.fromFirestore(doc))
              .toList();

          final userData = await _authService.getUserData(userId);
          
          // Filtrar y ordenar por personalización
          final personalizedBanners = banners.where((banner) {
            return banner.isForUser(userId, userData: userData);
          }).toList();

          // Ordenar por relevancia para el usuario
          _sortBannersByRelevance(personalizedBanners, userData);

          return personalizedBanners;
        });
  }

  // Ordenar banners por relevancia para el usuario
  void _sortBannersByRelevance(List<PromotionBanner> banners, Map<String, dynamic>? userData) {
    if (userData == null) return;

    banners.sort((a, b) {
      // Prioridad base
      int scoreA = a.priority;
      int scoreB = b.priority;

      // Ajustar según comportamiento del usuario
      if (userData['favoriteCategories'] != null) {
        final favoriteCategories = List<String>.from(userData['favoriteCategories']);
        
        // Bonus si el banner apunta a categorías favoritas
        if (a.targetCategories != null) {
          scoreA += favoriteCategories.where((cat) => a.targetCategories!.contains(cat)).length * 10;
        }
        if (b.targetCategories != null) {
          scoreB += favoriteCategories.where((cat) => b.targetCategories!.contains(cat)).length * 10;
        }
      }

      if (userData['favoriteBusinesses'] != null) {
        final favoriteBusinesses = List<String>.from(userData['favoriteBusinesses']);
        
        // Bonus si el banner apunta a negocios favoritos
        if (a.targetBusinessIds != null) {
          scoreA += favoriteBusinesses.where((biz) => a.targetBusinessIds!.contains(biz)).length * 15;
        }
        if (b.targetBusinessIds != null) {
          scoreB += favoriteBusinesses.where((biz) => b.targetBusinessIds!.contains(biz)).length * 15;
        }
      }

      // Bonus para usuarios nuevos en banners de primer pedido
      if (userData['orderCount'] == 0) {
        if (a.target == BannerTarget.new_users) scoreA += 20;
        if (b.target == BannerTarget.new_users) scoreB += 20;
      }

      // Bonus para usuarios recurrentes
      if (userData['orderCount'] != null && userData['orderCount'] > 5) {
        if (a.target == BannerTarget.returning) scoreA += 15;
        if (b.target == BannerTarget.returning) scoreB += 15;
      }

      return scoreB.compareTo(scoreA); // Mayor score primero
    });
  }
}
