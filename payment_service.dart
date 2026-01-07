// ============================================================================
// services/payment_service.dart - Servicio completo de pagos ACTUALIZADO
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../models/payment_method_model.dart' as pm;
import '../models/order_model.dart' as order_model;
import 'mercado_pago_service.dart';

class PaymentService {
  static const String publicKey = 'TEST-a15543e9-6f72-4a45-a5c8-ab89039e5528';
  
  final _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MercadoPagoService _mercadoPagoService = MercadoPagoService();

  // URLs de APIs (reemplazar con URLs reales en producción)
  static const String _mercadopagoApiUrl = 'https://api.mercadopago.com/v1';
  static const String _stripeApiUrl = 'https://api.stripe.com/v1';

  // Stream de transacciones del usuario
  Stream<List<pm.PaymentTransaction>> getUserTransactions() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('payment_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => pm.PaymentTransaction.fromMap(doc.data()))
            .toList());
  }

  // Guardar método de pago
  Future<String> savePaymentMethod(pm.PaymentMethod paymentMethod) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Si es el método por defecto, quitar el defecto de los demás
      if (paymentMethod.isDefault) {
        await _removeDefaultFromOtherMethods(userId);
      }

      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payment_methods')
          .add(paymentMethod.toMap());

      return docRef.id;
    } catch (e) {
      throw Exception('Error al guardar método de pago: $e');
    }
  }

  // Obtener métodos de pago del usuario
  Future<List<pm.PaymentMethod>> getUserPaymentMethods() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payment_methods')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => pm.PaymentMethod.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener métodos de pago: $e');
    }
  }

  // Eliminar método de pago
  Future<void> deletePaymentMethod(String methodId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('payment_methods')
          .doc(methodId)
          .update({'isActive': false});
    } catch (e) {
      throw Exception('Error al eliminar método de pago: $e');
    }
  }

  // Establecer método por defecto
  Future<void> setDefaultPaymentMethod(String methodId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _removeDefaultFromOtherMethods(userId);

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('payment_methods')
          .doc(methodId)
          .update({'isDefault': true});
    } catch (e) {
      throw Exception('Error al establecer método por defecto: $e');
    }
  }

  // Procesar pago con Mercado Pago (NUEVO MÉTODO MODERNO)
  Future<bool> processMercadoPagoPayment({
    required BuildContext context,
    required String orderId,
    required double amount,
    required String description,
    String customerEmail = '',
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Obtener email del usuario
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final email = customerEmail.isNotEmpty ? customerEmail : userDoc.data()?['email'] ?? '';

      // PASO 1: Crear preferencia con el servicio moderno
      final preferenceResult = await _mercadoPagoService.createPaymentPreference(
        orderId: orderId,
        amount: amount,
        description: description,
        customerEmail: email,
      );

      if (!preferenceResult['success']) {
        throw Exception(preferenceResult['error'] ?? 'Error al crear preferencia');
      }

      // PASO 2: Abrir checkout con WebView
      final success = await _mercadoPagoService.openMercadoPagoCheckout(
        context: context,
        preferenceId: preferenceResult['preferenceId'],
        initPoint: preferenceResult['initPoint'],
        onPaymentSuccess: (paymentId) async {
          // Guardar transacción exitosa
          await _mercadoPagoService.saveTransaction(
            orderId: orderId,
            preferenceId: preferenceResult['preferenceId'],
            amount: amount,
            status: 'approved',
            paymentId: paymentId,
          );
        },
        onPaymentFailure: (error) async {
          // Guardar transacción fallida
          await _mercadoPagoService.saveTransaction(
            orderId: orderId,
            preferenceId: preferenceResult['preferenceId'],
            amount: amount,
            status: 'rejected',
          );
        },
        onPaymentPending: () async {
          // Guardar transacción pendiente
          await _mercadoPagoService.saveTransaction(
            orderId: orderId,
            preferenceId: preferenceResult['preferenceId'],
            amount: amount,
            status: 'pending',
          );
        },
      );

      return success;
    } catch (e) {
      print('Error en pago Mercado Pago: $e');
      return false;
    }
  }

  // Procesar pago con Stripe (nuevo método)
  Future<bool> processStripePayment({
    required String orderId,
    required double amount,
    required String currency,
    required String paymentMethodId,
  }) async {
    try {
      // PASO 1: Crear Payment Intent en el backend
      final result = await _functions
          .httpsCallable('createStripePaymentIntent')
          .call({
        'orderId': orderId,
        'amount': amount,
        'currency': currency.toLowerCase(),
        'paymentMethodId': paymentMethodId,
      });
      
      if (result.data['success'] != true) {
        throw Exception('Error al crear payment intent');
      }
      
      final clientSecret = result.data['clientSecret'];
      
      // PASO 2: Confirmar el pago con Stripe
      final paymentResult = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );
      
      return paymentResult.status == PaymentIntentsStatus.Succeeded;
    } catch (e) {
      print('Error en pago Stripe: $e');
      return false;
    }
  }

  // Procesar pago completo
  Future<pm.PaymentTransaction> processPayment({
    required String orderId,
    required pm.PaymentMethod paymentMethod,
    required double amount,
    String currency = 'ARS',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Crear transacción inicial
      final transaction = pm.PaymentTransaction(
        id: _generateTransactionId(),
        orderId: orderId,
        userId: userId,
        paymentMethod: paymentMethod,
        amount: amount,
        currency: currency,
        status: pm.PaymentStatus.pending,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      // Guardar transacción en Firestore
      await _firestore
          .collection('payment_transactions')
          .doc(transaction.id)
          .set(transaction.toMap());

      // Procesar según el tipo de pago
      pm.PaymentStatus finalStatus;
      String? transactionId;
      String? authorizationCode;
      String? errorMessage;

      switch (paymentMethod.type) {
        case pm.PaymentType.creditCard:
        case pm.PaymentType.debitCard:
          final result = await _processCardPayment(transaction, paymentMethod);
          finalStatus = result['status'];
          transactionId = result['transactionId'];
          authorizationCode = result['authorizationCode'];
          errorMessage = result['errorMessage'];
          break;

        case pm.PaymentType.qr:
          final result = await _processQRPayment(transaction, paymentMethod);
          finalStatus = result['status'];
          transactionId = result['transactionId'];
          authorizationCode = result['authorizationCode'];
          errorMessage = result['errorMessage'];
          break;

        case pm.PaymentType.transfer:
          final result = await _processTransferPayment(transaction, paymentMethod);
          finalStatus = result['status'];
          transactionId = result['transactionId'];
          authorizationCode = result['authorizationCode'];
          errorMessage = result['errorMessage'];
          break;

        case pm.PaymentType.wallet:
          final result = await _processWalletPayment(transaction, paymentMethod);
          finalStatus = result['status'];
          transactionId = result['transactionId'];
          authorizationCode = result['authorizationCode'];
          errorMessage = result['errorMessage'];
          break;

        case pm.PaymentType.crypto:
          final result = await _processCryptoPayment(transaction, paymentMethod);
          finalStatus = result['status'];
          transactionId = result['transactionId'];
          authorizationCode = result['authorizationCode'];
          errorMessage = result['errorMessage'];
          break;

        case pm.PaymentType.cash:
          // El pago en efectivo se marca como completado cuando se entrega
          finalStatus = pm.PaymentStatus.pending;
          break;

        default:
          finalStatus = pm.PaymentStatus.failed;
          errorMessage = 'Método de pago no soportado';
      }

      // Actualizar transacción con el resultado
      final updatedTransaction = pm.PaymentTransaction(
        id: transaction.id,
        orderId: transaction.orderId,
        userId: transaction.userId,
        paymentMethod: transaction.paymentMethod,
        amount: transaction.amount,
        currency: transaction.currency,
        status: finalStatus,
        createdAt: transaction.createdAt,
        processedAt: DateTime.now(),
        transactionId: transactionId,
        authorizationCode: authorizationCode,
        errorMessage: errorMessage,
        metadata: metadata,
      );

      await _firestore
          .collection('payment_transactions')
          .doc(transaction.id)
          .update(updatedTransaction.toMap());

      return updatedTransaction;
    } catch (e) {
      throw Exception('Error al procesar pago: $e');
    }
  }

  // Procesar pago con tarjeta
  Future<Map<String, dynamic>> _processCardPayment(
    pm.PaymentTransaction transaction,
    pm.PaymentMethod paymentMethod,
  ) async {
    try {
      // Simulación de procesamiento con Stripe/Mercado Pago
      // En producción, aquí iría la llamada real a la API
      
      // Validar datos de la tarjeta
      if (!_validateCardData(paymentMethod)) {
        return {
          'status': pm.PaymentStatus.failed,
          'errorMessage': 'Datos de tarjeta inválidos',
        };
      }

      // Simular llamada a API
      await Future.delayed(const Duration(seconds: 2));

      // Simular respuesta exitosa
      return {
        'status': pm.PaymentStatus.completed,
        'transactionId': 'card_${DateTime.now().millisecondsSinceEpoch}',
        'authorizationCode': 'AUTH${DateTime.now().millisecondsSinceEpoch}',
      };
    } catch (e) {
      return {
        'status': pm.PaymentStatus.failed,
        'errorMessage': 'Error al procesar tarjeta: $e',
      };
    }
  }

  // Procesar pago QR
  Future<Map<String, dynamic>> _processQRPayment(
    pm.PaymentTransaction transaction,
    pm.PaymentMethod paymentMethod,
  ) async {
    try {
      if (paymentMethod.qrType == 'personal') {
        return await _processPersonalPayQR(transaction);
      } else {
        return {
          'status': pm.PaymentStatus.failed,
          'errorMessage': 'Tipo de QR no soportado',
        };
      }
    } catch (e) {
      return {
        'status': pm.PaymentStatus.failed,
        'errorMessage': 'Error al procesar QR: $e',
      };
    }
  }

  // Procesar QR de Personal Pay
  Future<Map<String, dynamic>> _processPersonalPayQR(pm.PaymentTransaction transaction) async {
    try {
      // Simulación de procesamiento de Personal Pay
      await Future.delayed(const Duration(seconds: 1));

      return {
        'status': pm.PaymentStatus.completed,
        'transactionId': 'pp_${DateTime.now().millisecondsSinceEpoch}',
        'authorizationCode': 'PP_QR_${DateTime.now().millisecondsSinceEpoch}',
      };
    } catch (e) {
      return {
        'status': pm.PaymentStatus.failed,
        'errorMessage': 'Error en Personal Pay: $e',
      };
    }
  }

  // Procesar transferencia bancaria
  Future<Map<String, dynamic>> _processTransferPayment(
    pm.PaymentTransaction transaction,
    pm.PaymentMethod paymentMethod,
  ) async {
    try {
      // Validar datos bancarios
      if (!_validateBankData(paymentMethod)) {
        return {
          'status': pm.PaymentStatus.failed,
          'errorMessage': 'Datos bancarios inválidos',
        };
      }

      // Simular procesamiento de transferencia
      await Future.delayed(const Duration(seconds: 3));

      return {
        'status': pm.PaymentStatus.completed,
        'transactionId': 'transfer_${DateTime.now().millisecondsSinceEpoch}',
        'authorizationCode': 'BANK_${DateTime.now().millisecondsSinceEpoch}',
      };
    } catch (e) {
      return {
        'status': pm.PaymentStatus.failed,
        'errorMessage': 'Error en transferencia: $e',
      };
    }
  }

  // Procesar pago con billetera digital
  Future<Map<String, dynamic>> _processWalletPayment(
    pm.PaymentTransaction transaction,
    pm.PaymentMethod paymentMethod,
  ) async {
    try {
      // Simular procesamiento según el proveedor
      await Future.delayed(const Duration(seconds: 1));

      return {
        'status': pm.PaymentStatus.completed,
        'transactionId': '${paymentMethod.walletProvider}_${DateTime.now().millisecondsSinceEpoch}',
        'authorizationCode': '${paymentMethod.walletProvider?.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}',
      };
    } catch (e) {
      return {
        'status': pm.PaymentStatus.failed,
        'errorMessage': 'Error en billetera: $e',
      };
    }
  }

  // Procesar pago con criptomonedas
  Future<Map<String, dynamic>> _processCryptoPayment(
    pm.PaymentTransaction transaction,
    pm.PaymentMethod paymentMethod,
  ) async {
    try {
      // Validar dirección de cripto
      if (!_validateCryptoAddress(paymentMethod)) {
        return {
          'status': pm.PaymentStatus.failed,
          'errorMessage': 'Dirección de cripto inválida',
        };
      }

      // Simular procesamiento de cripto
      await Future.delayed(const Duration(seconds: 5));

      return {
        'status': pm.PaymentStatus.completed,
        'transactionId': 'crypto_${DateTime.now().millisecondsSinceEpoch}',
        'authorizationCode': 'CRYPTO_${DateTime.now().millisecondsSinceEpoch}',
      };
    } catch (e) {
      return {
        'status': pm.PaymentStatus.failed,
        'errorMessage': 'Error en cripto: $e',
      };
    }
  }

  // Generar QR para pago
  Future<String> generatePaymentQR({
    required String orderId,
    required double amount,
    required pm.PaymentMethod paymentMethod,
  }) async {
    try {
      switch (paymentMethod.type) {
        case pm.PaymentType.qr:
          if (paymentMethod.qrType == 'personal') {
            return await _generatePersonalPayQR(orderId, amount);
          }
          break;
        
        case pm.PaymentType.transfer:
          return await _generateTransferQR(paymentMethod);
        
        default:
          throw Exception('Tipo de pago no genera QR');
      }
      
      throw Exception('No se pudo generar QR');
    } catch (e) {
      throw Exception('Error al generar QR: $e');
    }
  }

  // Generar QR de Personal Pay
  Future<String> _generatePersonalPayQR(String orderId, double amount) async {
    final qrData = {
      'orderId': orderId,
      'amount': amount,
      'currency': 'ARS',
      'provider': 'personal_pay',
    };

    await Future.delayed(const Duration(seconds: 1));
    
    return 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(jsonEncode(qrData))}';
  }

  // Generar QR de transferencia
  Future<String> _generateTransferQR(pm.PaymentMethod paymentMethod) async {
    final qrData = {
      'type': 'bank_transfer',
      'cbu': paymentMethod.cbu,
      'alias': paymentMethod.alias,
      'bank': paymentMethod.bankName,
      'account': paymentMethod.maskedAccountNumber,
    };

    await Future.delayed(const Duration(seconds: 1));
    
    return 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(jsonEncode(qrData))}';
  }

  // Validar datos de tarjeta
  bool _validateCardData(pm.PaymentMethod paymentMethod) {
    if (paymentMethod.cardNumber == null || paymentMethod.cardNumber!.length < 13) {
      return false;
    }
    if (paymentMethod.cardHolderName == null || paymentMethod.cardHolderName!.isEmpty) {
      return false;
    }
    if (paymentMethod.expiryDate == null) {
      return false;
    }
    if (paymentMethod.cvv == null || paymentMethod.cvv!.length < 3) {
      return false;
    }
    return true;
  }

  // Validar datos bancarios
  bool _validateBankData(pm.PaymentMethod paymentMethod) {
    if (paymentMethod.cbu == null || paymentMethod.cbu!.length < 22) {
      return false;
    }
    if (paymentMethod.accountHolder == null || paymentMethod.accountHolder!.isEmpty) {
      return false;
    }
    return true;
  }

  // Validar dirección de cripto
  bool _validateCryptoAddress(pm.PaymentMethod paymentMethod) {
    if (paymentMethod.cryptoAddress == null || paymentMethod.cryptoAddress!.length < 20) {
      return false;
    }
    return true;
  }

  // Quitar método por defecto de otros métodos
  Future<void> _removeDefaultFromOtherMethods(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('payment_methods')
        .where('isDefault', isEqualTo: true)
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.update({'isDefault': false});
    }
  }

  // Generar ID de transacción único
  String _generateTransactionId() {
    return 'txn_${DateTime.now().millisecondsSinceEpoch}_${_auth.currentUser?.uid ?? 'guest'}';
  }

  // Obtener transacción por ID
  Future<pm.PaymentTransaction?> getTransactionById(String transactionId) async {
    try {
      final doc = await _firestore
          .collection('payment_transactions')
          .doc(transactionId)
          .get();

      if (doc.exists) {
        return pm.PaymentTransaction.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener transacción: $e');
    }
  }

  // Cancelar transacción
  Future<void> cancelTransaction(String transactionId, String? reason) async {
    try {
      await _firestore
          .collection('payment_transactions')
          .doc(transactionId)
          .update({
            'status': pm.PaymentStatus.cancelled.name,
            'errorMessage': reason,
            'processedAt': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      throw Exception('Error al cancelar transacción: $e');
    }
  }

  // Reembolsar transacción
  Future<void> refundTransaction(String transactionId, double? amount) async {
    try {
      final transaction = await getTransactionById(transactionId);
      if (transaction == null) throw Exception('Transacción no encontrada');

      final refundAmount = amount ?? transaction.amount;

      await _firestore
          .collection('payment_transactions')
          .doc(transactionId)
          .update({
            'status': pm.PaymentStatus.refunded.name,
            'processedAt': DateTime.now().toIso8601String(),
            'metadata': {
              ...(transaction.metadata ?? {}),
              'refundAmount': refundAmount,
              'refundedAt': DateTime.now().toIso8601String(),
            },
          });
    } catch (e) {
      throw Exception('Error al reembolsar transacción: $e');
    }
  }

  // Abrir billetera externa
  Future<bool> launchExternalWallet(pm.PaymentMethod paymentMethod) async {
    try {
      String url;
      
      switch (paymentMethod.walletProvider?.toLowerCase()) {
        case 'mercadopago':
          url = 'https://www.mercadopago.com.ar';
          break;
        case 'uala':
          url = 'https://www.uala.com.ar';
          break;
        case 'modo':
          url = 'https://www.modo.com.ar';
          break;
        default:
          return false;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}