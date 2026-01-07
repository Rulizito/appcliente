// ============================================================================
// services/mercado_pago_service.dart - Servicio moderno de Mercado Pago
// ============================================================================

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MercadoPagoService {
  static const String _accessToken = 'TEST-8604753178277983-010520-a5f8b1c8c5345e6a8a4f3a3b9b1e4b7__LA_LB__-284740948';
  static const String _publicKey = 'TEST-adb0d7b9-6b7f-4a1a-8c9a-9f1b2b3c4d5e';
  
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Crear preferencia de pago
  Future<Map<String, dynamic>> createPaymentPreference({
    required String orderId,
    required double amount,
    required String description,
    required String customerEmail,
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? payer,
  }) async {
    try {
      // Si no hay items, crear uno por defecto
      final defaultItems = items ?? [
        {
          'title': description,
          'description': description,
          'quantity': 1,
          'currency_id': 'ARS',
          'unit_price': amount,
        }
      ];

      // Datos del pagador por defecto
      final defaultPayer = payer ?? {
        'email': customerEmail,
        'name': 'Cliente Delivery App',
      };

      final preferenceData = {
        'items': defaultItems,
        'payer': defaultPayer,
        'payment_methods': {
          'excluded_payment_types': [
            {'id': 'ticket'},
            {'id': 'atm'},
          ],
          'installments': 12, // Permitir hasta 12 cuotas
        },
        'back_urls': {
          'success': 'https://delivery-app.com/payment/success',
          'failure': 'https://delivery-app.com/payment/failure',
          'pending': 'https://delivery-app.com/payment/pending',
        },
        'auto_return': 'approved',
        'notification_url': 'https://delivery-app.com/webhooks/mercadopago',
        'external_reference': orderId,
        'statement_descriptor': 'Delivery App',
      };

      // Llamar a Cloud Function para crear preferencia
      final result = await _functions
          .httpsCallable('createMercadoPagoPreference')
          .call(preferenceData);

      if (result.data['success'] == true) {
        return {
          'success': true,
          'preferenceId': result.data['preferenceId'],
          'initPoint': result.data['initPoint'],
        };
      } else {
        throw Exception(result.data['error'] ?? 'Error al crear preferencia');
      }
    } catch (e) {
      print('Error creando preferencia Mercado Pago: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Obtener métodos de pago disponibles
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.mercadopago.com/v1/payment_methods'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Error al obtener métodos de pago');
      }
    } catch (e) {
      print('Error obteniendo métodos de pago: $e');
      return [];
    }
  }

  // Obtener cuotas disponibles para una tarjeta
  Future<List<Map<String, dynamic>>> getInstallments({
    required double amount,
    required String paymentMethodId,
    String? bin,
  }) async {
    try {
      final uri = Uri.parse('https://api.mercadopago.com/v1/payment_methods/installments')
          .replace(queryParameters: {
        'access_token': _accessToken,
        'amount': amount.toString(),
        'payment_method_id': paymentMethodId,
        if (bin != null) 'bin': bin,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Error al obtener cuotas');
      }
    } catch (e) {
      print('Error obteniendo cuotas: $e');
      return [];
    }
  }

  // Abrir checkout de Mercado Pago en WebView
  Future<bool> openMercadoPagoCheckout({
    required BuildContext context,
    required String preferenceId,
    required String initPoint,
    Function(String)? onPaymentSuccess,
    Function(String)? onPaymentFailure,
    Function()? onPaymentPending,
  }) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MercadoPagoCheckoutScreen(
            initPoint: initPoint,
            preferenceId: preferenceId,
            onPaymentSuccess: onPaymentSuccess,
            onPaymentFailure: onPaymentFailure,
            onPaymentPending: onPaymentPending,
          ),
        ),
      );

      return result == true;
    } catch (e) {
      print('Error abriendo checkout: $e');
      return false;
    }
  }

  // Verificar estado de pago
  Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.mercadopago.com/v1/payments/$paymentId'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al verificar estado del pago');
      }
    } catch (e) {
      print('Error verificando pago: $e');
      return {};
    }
  }

  // Crear pago con QR (Mercado Pago QR)
  Future<Map<String, dynamic>> createQRPayment({
    required double amount,
    required String description,
    required String orderId,
  }) async {
    try {
      final paymentData = {
        'title': description,
        'description': description,
        'external_reference': orderId,
        'total_amount': amount,
        'expiration_date': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      };

      final result = await _functions
          .httpsCallable('createMercadoPagoQR')
          .call(paymentData);

      if (result.data['success'] == true) {
        return {
          'success': true,
          'qrData': result.data['qrData'],
          'qrUrl': result.data['qrUrl'],
          'inStoreOrderId': result.data['inStoreOrderId'],
        };
      } else {
        throw Exception(result.data['error'] ?? 'Error al crear QR');
      }
    } catch (e) {
      print('Error creando QR: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Guardar transacción en Firestore
  Future<void> saveTransaction({
    required String orderId,
    required String preferenceId,
    required double amount,
    required String status,
    String? paymentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('mercado_pago_transactions')
          .add({
        'orderId': orderId,
        'preferenceId': preferenceId,
        'paymentId': paymentId,
        'amount': amount,
        'status': status,
        'createdAt': DateTime.now().toIso8601String(),
        'metadata': metadata ?? {},
      });
    } catch (e) {
      print('Error guardando transacción: $e');
    }
  }
}

// Pantalla de Checkout de Mercado Pago
class MercadoPagoCheckoutScreen extends StatefulWidget {
  final String initPoint;
  final String preferenceId;
  final Function(String)? onPaymentSuccess;
  final Function(String)? onPaymentFailure;
  final Function()? onPaymentPending;

  const MercadoPagoCheckoutScreen({
    Key? key,
    required this.initPoint,
    required this.preferenceId,
    this.onPaymentSuccess,
    this.onPaymentFailure,
    this.onPaymentPending,
  }) : super(key: key);

  @override
  State<MercadoPagoCheckoutScreen> createState() => _MercadoPagoCheckoutScreenState();
}

class _MercadoPagoCheckoutScreenState extends State<MercadoPagoCheckoutScreen> {
  bool isLoading = true;
  String? paymentStatus;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            
            // Verificar si la URL contiene información de estado
            _checkPaymentStatus(url);
          },
          onNavigationRequest: (NavigationRequest request) async {
            // Permitir todas las navegaciones dentro del checkout
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initPoint));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mercado Pago'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  void _checkPaymentStatus(String url) {
    if (url.contains('collection_success')) {
      paymentStatus = 'approved';
    } else if (url.contains('collection_failure')) {
      paymentStatus = 'rejected';
    } else if (url.contains('collection_pending')) {
      paymentStatus = 'pending';
    }
  }

  void _handlePaymentReturn(String returnUrl) {
    if (returnUrl.contains('success')) {
      widget.onPaymentSuccess?.call(widget.preferenceId);
      Navigator.pop(context, true);
    } else if (returnUrl.contains('failure')) {
      widget.onPaymentFailure?.call('Pago rechazado');
      Navigator.pop(context, false);
    } else if (returnUrl.contains('pending')) {
      widget.onPaymentPending?.call();
      Navigator.pop(context, true);
    }
  }
}
