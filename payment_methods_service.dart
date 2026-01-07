// ============================================================================
// services/payment_methods_service.dart - Servicio de Métodos de Pago
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_method_model.dart';
import 'package:flutter/material.dart';

class PaymentMethodsService {
  static final PaymentMethodsService _instance = PaymentMethodsService._internal();
  factory PaymentMethodsService() => _instance;
  PaymentMethodsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener métodos de pago disponibles (desde Firestore o locales)
  Future<List<PaymentMethod>> getAvailablePaymentMethods() async {
    try {
      // Primero intentar obtener desde Firestore
      final snapshot = await _firestore
          .collection('payment_methods')
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => PaymentMethod.fromMap(doc.data()))
            .toList();
      }
    } catch (e) {
      print('Error obteniendo métodos de pago desde Firestore: $e');
    }

    // Si no hay en Firestore, usar los métodos locales
    return PaymentMethod.getAvailableMethods();
  }

  // Procesar pago según el método seleccionado
  Future<Map<String, dynamic>> processPayment({
    required PaymentMethod paymentMethod,
    required String orderId,
    required double amount,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      switch (paymentMethod.type) {
        case PaymentType.cash:
          return await _processCashPayment(orderId, amount, orderData);
        
        case PaymentType.creditCard:
        case PaymentType.debitCard:
          return await _processCardPayment(orderId, amount, orderData);
        
        case PaymentType.transfer:
          return await _processTransferPayment(orderId, amount, orderData);
        
        case PaymentType.qr:
          return await _processQRPayment(orderId, amount, orderData);
        
        case PaymentType.wallet:
          return await _processWalletPayment(orderId, amount, orderData);
        
        default:
          throw Exception('Método de pago no soportado');
      }
    } catch (e) {
      print('Error procesando pago: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Procesar pago en efectivo
  Future<Map<String, dynamic>> _processCashPayment(
    String orderId, 
    double amount, 
    Map<String, dynamic> orderData
  ) async {
    // Para efectivo, solo registramos el método
    await _firestore.collection('orders').doc(orderId).update({
      'paymentMethod': 'cash',
      'paymentStatus': 'pending',
      'paymentDetails': {
        'type': 'cash',
        'amount': amount,
        'status': 'pending_payment_on_delivery',
      },
    });

    return {
      'success': true,
      'message': 'Pago en efectivo registrado. Pagarás al recibir.',
      'paymentStatus': 'pending',
    };
  }

  // Procesar pago con tarjeta
  Future<Map<String, dynamic>> _processCardPayment(
    String orderId, 
    double amount, 
    Map<String, dynamic> orderData
  ) async {
    // Aquí iría la integración con pasarelas de pago
    // Por ahora, simulamos el proceso
    
    await _firestore.collection('orders').doc(orderId).update({
      'paymentMethod': 'card',
      'paymentStatus': 'processing',
      'paymentDetails': {
        'type': 'card',
        'amount': amount,
        'status': 'processing',
        'processedAt': DateTime.now(),
      },
    });

    return {
      'success': true,
      'message': 'Procesando pago con tarjeta...',
      'paymentStatus': 'processing',
    };
  }

  // Procesar pago por transferencia
  Future<Map<String, dynamic>> _processTransferPayment(
    String orderId, 
    double amount, 
    Map<String, dynamic> orderData
  ) async {
    // Generar datos para transferencia
    final transferData = {
      'bank': 'Banco Ejemplo',
      'accountType': 'Cuenta Corriente',
      'accountNumber': '1234567890123456789012',
      'cbu': '123456789012345678901234567890',
      'alias': 'delivery.ejemplo.mp',
      'amount': amount,
      'reference': orderId,
    };

    await _firestore.collection('orders').doc(orderId).update({
      'paymentMethod': 'transfer',
      'paymentStatus': 'pending_transfer',
      'paymentDetails': {
        'type': 'transfer',
        'transferData': transferData,
        'status': 'waiting_for_transfer',
        'expiresAt': DateTime.now().add(Duration(hours: 2)),
      },
    });

    return {
      'success': true,
      'message': 'Datos de transferencia generados',
      'paymentStatus': 'pending_transfer',
      'transferData': transferData,
    };
  }

  // Procesar pago con QR
  Future<Map<String, dynamic>> _processQRPayment(
    String orderId, 
    double amount, 
    Map<String, dynamic> orderData
  ) async {
    // Aquí iría la integración con Mercado Pago QR
    final qrData = {
      'qrUrl': 'https://mpago.la/abc123def456',
      'qrCode': '00020101021132240000COMERCIO12345678901234567890',
      'amount': amount,
      'expiresAt': DateTime.now().add(Duration(minutes: 30)),
    };

    await _firestore.collection('orders').doc(orderId).update({
      'paymentMethod': 'qr',
      'paymentStatus': 'pending_qr',
      'paymentDetails': {
        'type': 'qr',
        'qrData': qrData,
        'status': 'waiting_for_qr_payment',
      },
    });

    return {
      'success': true,
      'message': 'Código QR generado',
      'paymentStatus': 'pending_qr',
      'qrData': qrData,
    };
  }

  // Procesar pago con billeteras digitales
  Future<Map<String, dynamic>> _processWalletPayment(
    String orderId, 
    double amount, 
    Map<String, dynamic> orderData
  ) async {
    final walletData = {
      'availableWallets': ['Ualá', 'Modo', 'Personal Pay', 'Bimo'],
      'amount': amount,
      'reference': orderId,
    };

    await _firestore.collection('orders').doc(orderId).update({
      'paymentMethod': 'wallet',
      'paymentStatus': 'pending_wallet',
      'paymentDetails': {
        'type': 'wallet',
        'walletData': walletData,
        'status': 'waiting_for_wallet_payment',
      },
    });

    return {
      'success': true,
      'message': 'Seleccioná tu billetera digital',
      'paymentStatus': 'pending_wallet',
      'walletData': walletData,
    };
  }

  // Verificar estado del pago
  Future<Map<String, dynamic>> checkPaymentStatus(String orderId) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      final orderData = orderDoc.data() ?? {};
      
      final paymentStatus = orderData['paymentStatus'] ?? 'unknown';
      final paymentDetails = orderData['paymentDetails'] ?? {};

      return {
        'success': true,
        'paymentStatus': paymentStatus,
        'paymentDetails': paymentDetails,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Confirmar pago manualmente (para transferencias y otros métodos)
  Future<bool> confirmPayment(String orderId, String paymentMethod) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': 'paid',
        'paymentDetails.status': 'confirmed',
        'paymentDetails.confirmedAt': DateTime.now(),
        'status': 'confirmed', // Cambiar el estado del pedido también
      });

      return true;
    } catch (e) {
      print('Error confirmando pago: $e');
      return false;
    }
  }
}
