// ============================================================================
// services/address_history_service.dart
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/address_model.dart';

class AddressHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Registrar uso de una dirección
  Future<void> recordAddressUsage({
    required String userId,
    required String addressId,
  }) async {
    try {
      final addressRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .doc(addressId);

      final addressDoc = await addressRef.get();
      
      if (!addressDoc.exists) return;

      final currentUsageCount = addressDoc.data()?['usageCount'] ?? 0;

      await addressRef.update({
        'lastUsed': DateTime.now().toIso8601String(),
        'usageCount': currentUsageCount + 1,
      });

      print('✅ Uso de dirección registrado');
    } catch (e) {
      print('❌ Error al registrar uso de dirección: $e');
    }
  }

  // Obtener direcciones recientes (ordenadas por última vez usadas)
  Stream<List<Address>> getRecentAddresses(String userId, {int limit = 5}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('addresses')
        .where('lastUsed', isNull: false)
        .orderBy('lastUsed', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Address.fromMap(doc.data()))
          .toList();
    });
  }

  // Obtener direcciones más usadas
  Stream<List<Address>> getMostUsedAddresses(String userId, {int limit = 5}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('addresses')
        .where('usageCount', isGreaterThan: 0)
        .orderBy('usageCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Address.fromMap(doc.data()))
          .toList();
    });
  }

  // Obtener todas las direcciones ordenadas por uso reciente
  Future<List<Address>> getAllAddressesByRecent(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .get();

      final addresses = snapshot.docs
          .map((doc) => Address.fromMap(doc.data()))
          .toList();

      // Ordenar: primero las recientes, luego las que nunca se usaron
      addresses.sort((a, b) {
        if (a.lastUsed == null && b.lastUsed == null) return 0;
        if (a.lastUsed == null) return 1;
        if (b.lastUsed == null) return -1;
        return b.lastUsed!.compareTo(a.lastUsed!);
      });

      return addresses;
    } catch (e) {
      print('❌ Error al obtener direcciones: $e');
      return [];
    }
  }

  // Obtener estadísticas de direcciones
  Future<Map<String, dynamic>> getAddressStats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .get();

      int totalAddresses = snapshot.docs.length;
      int usedAddresses = 0;
      int totalUsages = 0;
      Address? mostUsed;

      for (var doc in snapshot.docs) {
        final address = Address.fromMap(doc.data());
        if (address.usageCount > 0) {
          usedAddresses++;
          totalUsages += address.usageCount;
        }

        if (mostUsed == null || address.usageCount > mostUsed.usageCount) {
          mostUsed = address;
        }
      }

      return {
        'totalAddresses': totalAddresses,
        'usedAddresses': usedAddresses,
        'totalUsages': totalUsages,
        'mostUsed': mostUsed,
      };
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      return {
        'totalAddresses': 0,
        'usedAddresses': 0,
        'totalUsages': 0,
        'mostUsed': null,
      };
    }
  }

  // Limpiar historial (eliminar información de uso)
  Future<void> clearHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .get();

      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'lastUsed': null,
          'usageCount': 0,
        });
      }

      await batch.commit();
      print('✅ Historial limpiado');
    } catch (e) {
      print('❌ Error al limpiar historial: $e');
    }
  }

  // Formatear tiempo desde el último uso
  String formatLastUsed(DateTime? lastUsed) {
    if (lastUsed == null) return 'Nunca usada';

    final now = DateTime.now();
    final difference = now.difference(lastUsed);

    if (difference.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Hace $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
    } else {
      final months = (difference.inDays / 30).floor();
      return 'Hace $months ${months == 1 ? 'mes' : 'meses'}';
    }
  }
}