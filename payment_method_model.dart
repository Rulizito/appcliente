// ============================================================================
// models/payment_method_model.dart - Modelo de Métodos de Pago Completo
// ============================================================================

import 'package:flutter/material.dart';

enum PaymentType {
  cash,           // Efectivo
  creditCard,     // Tarjeta de crédito
  debitCard,      // Tarjeta de débito
  transfer,       // Transferencia bancaria
  qr,             // QR/Mercado Pago
  wallet,         // Billeteras digitales
  crypto,         // Criptomonedas
}

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  refunded,
}

enum CardBrand {
  visa,
  mastercard,
  amex,
  diners,
  discover,
  elo,
  hipercard,
  naranja,
  cabal,
}

class PaymentMethod {
  final String id;
  final PaymentType type;
  final String name;
  final String description;
  final IconData icon;
  final bool isActive;
  final double? fee; // Comisión del método
  final Map<String, dynamic>? config; // Configuración adicional
  
  // Datos para tarjetas
  final String? cardNumber;
  final String? cardHolderName;
  final String? expiryDate;
  final String? cvv;
  final CardBrand? cardBrand;
  
  // Datos para transferencias
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;
  final String? cbu;
  final String? alias;
  
  // Datos para billeteras digitales
  final String? walletProvider;
  final String? walletEmail;
  final String? walletPhone;
  final String? walletType;
  
  // Datos para QR
  final String? qrCode;
  final String? qrType; // mercadopago, personal, etc
  
  // Datos para cripto
  final String? cryptoAddress;
  final String? cryptoType;
  
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? lastUsed;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    this.isActive = true,
    this.fee,
    this.config,
    this.cardNumber,
    this.cardHolderName,
    this.expiryDate,
    this.cvv,
    this.cardBrand,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
    this.cbu,
    this.alias,
    this.walletProvider,
    this.walletEmail,
    this.walletPhone,
    this.walletType,
    this.qrCode,
    this.qrType,
    this.cryptoAddress,
    this.cryptoType,
    this.isDefault = false,
    required this.createdAt,
    this.lastUsed,
  });

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'description': description,
      'isActive': isActive,
      'fee': fee,
      'config': config,
      'cardNumber': cardNumber,
      'cardHolderName': cardHolderName,
      'expiryDate': expiryDate,
      'cardBrand': cardBrand?.name,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountHolder': accountHolder,
      'cbu': cbu,
      'alias': alias,
      'walletProvider': walletProvider,
      'walletEmail': walletEmail,
      'walletPhone': walletPhone,
      'walletType': walletType,
      'qrCode': qrCode,
      'qrType': qrType,
      'cryptoAddress': cryptoAddress,
      'cryptoType': cryptoType,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed?.toIso8601String(),
    };
  }

  // Crear desde Map
  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] ?? '',
      type: PaymentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PaymentType.cash,
      ),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      icon: _getIconForType(PaymentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PaymentType.cash,
      )),
      isActive: map['isActive'] ?? true,
      fee: map['fee']?.toDouble(),
      config: map['config'],
      cardNumber: map['cardNumber'],
      cardHolderName: map['cardHolderName'],
      expiryDate: map['expiryDate'],
      cvv: map['cvv'],
      cardBrand: map['cardBrand'] != null 
          ? CardBrand.values.firstWhere(
              (brand) => brand.name == map['cardBrand'],
              orElse: () => CardBrand.visa,
            )
          : null,
      bankName: map['bankName'],
      accountNumber: map['accountNumber'],
      accountHolder: map['accountHolder'],
      cbu: map['cbu'],
      alias: map['alias'],
      walletProvider: map['walletProvider'],
      walletEmail: map['walletEmail'],
      walletPhone: map['walletPhone'],
      walletType: map['walletType'],
      qrCode: map['qrCode'],
      qrType: map['qrType'],
      cryptoAddress: map['cryptoAddress'],
      cryptoType: map['cryptoType'],
      isDefault: map['isDefault'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      lastUsed: map['lastUsed'] != null ? DateTime.parse(map['lastUsed']) : null,
    );
  }

  // Helper para obtener el icono según el tipo
  static IconData _getIconForType(PaymentType type) {
    switch (type) {
      case PaymentType.cash:
        return Icons.money;
      case PaymentType.creditCard:
        return Icons.credit_card;
      case PaymentType.debitCard:
        return Icons.credit_card;
      case PaymentType.transfer:
        return Icons.account_balance;
      case PaymentType.qr:
        return Icons.qr_code;
      case PaymentType.wallet:
        return Icons.wallet;
      case PaymentType.crypto:
        return Icons.currency_bitcoin;
    }
  }

  String get maskedCardNumber {
    if (cardNumber == null || cardNumber!.length < 4) return '****';
    return '**** **** **** ${cardNumber!.substring(cardNumber!.length - 4)}';
  }

  String get maskedAccountNumber {
    if (accountNumber == null || accountNumber!.length < 4) return '****';
    return '****-${accountNumber!.substring(accountNumber!.length - 4)}';
  }

  String get displayInfo {
    switch (type) {
      case PaymentType.creditCard:
      case PaymentType.debitCard:
        return '${cardBrand?.name.toUpperCase() ?? 'CARD'} $maskedCardNumber';
      case PaymentType.transfer:
        return '$bankName - $maskedAccountNumber';
      case PaymentType.qr:
        return qrType == 'mercadopago' ? 'Mercado Pago' : 'Pago QR';
      case PaymentType.wallet:
        return walletProvider ?? 'Billetera Digital';
      case PaymentType.crypto:
        return '$cryptoType - ${cryptoAddress?.substring(0, 8)}...';
      case PaymentType.cash:
        return 'Pagar en efectivo';
    }
  }

  // Obtener métodos de pago disponibles
  static List<PaymentMethod> getAvailableMethods() {
    final now = DateTime.now();
    return [
      PaymentMethod(
        id: 'cash',
        type: PaymentType.cash,
        name: 'Efectivo',
        description: 'Paga cuando recibas tu pedido',
        icon: Icons.money,
        createdAt: now,
      ),
      PaymentMethod(
        id: 'credit_card',
        type: PaymentType.creditCard,
        name: 'Tarjeta de crédito',
        description: 'Visa, Mastercard, Amex, etc.',
        icon: Icons.credit_card,
        fee: 0.0,
        createdAt: now,
      ),
      PaymentMethod(
        id: 'debit_card',
        type: PaymentType.debitCard,
        name: 'Tarjeta de débito',
        description: 'Débito directo de tu cuenta',
        icon: Icons.credit_card,
        fee: 0.0,
        createdAt: now,
      ),
      PaymentMethod(
        id: 'transfer',
        type: PaymentType.transfer,
        name: 'Transferencia bancaria',
        description: 'Desde cualquier banco argentino',
        icon: Icons.account_balance,
        fee: 0.0,
        createdAt: now,
      ),
      PaymentMethod(
        id: 'mercadopago',
        type: PaymentType.qr,
        name: 'Mercado Pago',
        description: 'Paga con QR de Mercado Pago',
        icon: Icons.qr_code,
        fee: 0.0,
        config: {'qrType': 'mercadopago'},
        createdAt: now,
      ),
      PaymentMethod(
        id: 'personal_pay',
        type: PaymentType.qr,
        name: 'Personal Pay',
        description: 'Escaneá el QR de Personal',
        icon: Icons.qr_code,
        fee: 0.0,
        config: {'qrType': 'personal'},
        createdAt: now,
      ),
      PaymentMethod(
        id: 'uala',
        type: PaymentType.wallet,
        name: 'Ualá',
        description: 'Billetera digital Ualá',
        icon: Icons.wallet,
        fee: 0.0,
        createdAt: now,
      ),
      PaymentMethod(
        id: 'modo',
        type: PaymentType.wallet,
        name: 'Modo',
        description: 'Billetera digital de Mercado Pago',
        icon: Icons.wallet,
        fee: 0.0,
        createdAt: now,
      ),
      PaymentMethod(
        id: 'bitcoin',
        type: PaymentType.crypto,
        name: 'Bitcoin',
        description: 'Paga con criptomonedas',
        icon: Icons.currency_bitcoin,
        fee: 0.0,
        createdAt: now,
      ),
    ];
  }
}

class PaymentTransaction {
  final String id;
  final String orderId;
  final String userId;
  final PaymentMethod paymentMethod;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? transactionId;
  final String? authorizationCode;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  PaymentTransaction({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.paymentMethod,
    required this.amount,
    this.currency = 'ARS',
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.transactionId,
    this.authorizationCode,
    this.errorMessage,
    this.metadata,
  });

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) {
    return PaymentTransaction(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      userId: map['userId'] ?? '',
      paymentMethod: PaymentMethod.fromMap(map['paymentMethod']),
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'ARS',
      status: PaymentStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => PaymentStatus.pending,
      ),
      createdAt: DateTime.parse(map['createdAt']),
      processedAt: map['processedAt'] != null ? DateTime.parse(map['processedAt']) : null,
      transactionId: map['transactionId'],
      authorizationCode: map['authorizationCode'],
      errorMessage: map['errorMessage'],
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'userId': userId,
      'paymentMethod': paymentMethod.toMap(),
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'transactionId': transactionId,
      'authorizationCode': authorizationCode,
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }
}
