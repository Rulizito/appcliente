// ============================================================================
// services/cart_service.dart - Servicio de Carrito Persistente
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  // Guardar carrito en el almacenamiento local
  Future<void> saveCart({
    required String businessId,
    required String businessName,
    required Map<String, int> cart,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cartData = {
        'businessId': businessId,
        'businessName': businessName,
        'items': cart,
        'savedAt': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString('saved_cart', json.encode(cartData));
      print('✅ Carrito guardado: ${cart.length} items');
    } catch (e) {
      print('❌ Error al guardar carrito: $e');
    }
  }

  // Cargar carrito guardado
  Future<Map<String, dynamic>?> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartString = prefs.getString('saved_cart');
      
      if (cartString == null) return null;
      
      final cartData = json.decode(cartString) as Map<String, dynamic>;
      
      // Verificar que no sea muy antiguo (24 horas)
      final savedAt = DateTime.parse(cartData['savedAt']);
      final difference = DateTime.now().difference(savedAt);
      
      if (difference.inHours > 24) {
        await clearCart();
        return null;
      }
      
      // Convertir items de nuevo a Map<String, int>
      final items = (cartData['items'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as int),
      );
      
      return {
        'businessId': cartData['businessId'],
        'businessName': cartData['businessName'],
        'items': items,
      };
    } catch (e) {
      print('❌ Error al cargar carrito: $e');
      return null;
    }
  }

  // Limpiar carrito guardado
  Future<void> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_cart');
      print('🗑️ Carrito limpiado');
    } catch (e) {
      print('❌ Error al limpiar carrito: $e');
    }
  }

  // Verificar si hay un carrito guardado
  Future<bool> hasCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('saved_cart');
    } catch (e) {
      return false;
    }
  }
}