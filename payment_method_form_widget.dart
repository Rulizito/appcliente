// ============================================================================
// widgets/payment_method_form_widget.dart - Widget de formulario para métodos de pago
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/payment_method_model.dart';

class PaymentMethodFormWidget extends StatefulWidget {
  final PaymentType paymentType;
  final Function(PaymentMethod) onSaved;
  final bool isLoading;

  const PaymentMethodFormWidget({
    Key? key,
    required this.paymentType,
    required this.onSaved,
    required this.isLoading,
  }) : super(key: key);

  @override
  State<PaymentMethodFormWidget> createState() => _PaymentMethodFormWidgetState();
}

class _PaymentMethodFormWidgetState extends State<PaymentMethodFormWidget> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para tarjetas
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  CardBrand? _selectedCardBrand;
  
  // Controladores para transferencia
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _cbuController = TextEditingController();
  final _aliasController = TextEditingController();
  
  // Controladores para billeteras
  final _walletProviderController = TextEditingController();
  final _walletEmailController = TextEditingController();
  final _walletPhoneController = TextEditingController();
  
  // Controladores para QR
  final _qrTypeController = TextEditingController();
  String? _selectedQrType;
  
  // Controladores para cripto
  final _cryptoTypeController = TextEditingController();
  final _cryptoAddressController = TextEditingController();
  String? _selectedCryptoType;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _cbuController.dispose();
    _aliasController.dispose();
    _walletProviderController.dispose();
    _walletEmailController.dispose();
    _walletPhoneController.dispose();
    _qrTypeController.dispose();
    _cryptoTypeController.dispose();
    _cryptoAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormHeader(),
          const SizedBox(height: 20),
          _buildSpecificForm(),
        ],
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            _getPaymentTypeIcon(widget.paymentType),
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getPaymentTypeName(widget.paymentType),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getPaymentTypeDescription(widget.paymentType),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificForm() {
    switch (widget.paymentType) {
      case PaymentType.creditCard:
      case PaymentType.debitCard:
        return _buildCardForm();
      case PaymentType.transfer:
        return _buildTransferForm();
      case PaymentType.qr:
        return _buildQRForm();
      case PaymentType.wallet:
        return _buildWalletForm();
      case PaymentType.crypto:
        return _buildCryptoForm();
      case PaymentType.cash:
        return _buildCashForm();
    }
  }

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Datos de la Tarjeta',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Tipo de tarjeta
        DropdownButtonFormField<CardBrand>(
          value: _selectedCardBrand,
          decoration: _buildInputDecoration('Tipo de tarjeta'),
          items: CardBrand.values.map((brand) {
            return DropdownMenuItem(
              value: brand,
              child: Text(brand.name.toUpperCase()),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCardBrand = value;
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Número de tarjeta
        TextFormField(
          controller: _cardNumberController,
          decoration: _buildInputDecoration('Número de tarjeta'),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
          ],
          validator: (value) {
            if (value == null || value.length < 13) {
              return 'Número de tarjeta inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        // Nombre del titular
        TextFormField(
          controller: _cardHolderController,
          decoration: _buildInputDecoration('Nombre del titular'),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El nombre es requerido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _expiryController,
                decoration: _buildInputDecoration('Vencimiento (MM/AA)'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                  _CardExpiryFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.length != 4) {
                    return 'Formato inválido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _cvvController,
                decoration: _buildInputDecoration('CVV'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length != 3) {
                    return 'CVV inválido';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Datos Bancarios',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _bankNameController,
          decoration: _buildInputDecoration('Banco'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El banco es requerido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _accountHolderController,
          decoration: _buildInputDecoration('Titular de la cuenta'),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El titular es requerido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _accountNumberController,
          decoration: _buildInputDecoration('Número de cuenta'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El número de cuenta es requerido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _cbuController,
          decoration: _buildInputDecoration('CBU'),
          keyboardType: TextInputType.number,
          inputFormatters: [LengthLimitingTextInputFormatter(22)],
          validator: (value) {
            if (value == null || value.length != 22) {
              return 'El CBU debe tener 22 dígitos';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _aliasController,
          decoration: _buildInputDecoration('Alias (opcional)'),
          validator: (value) {
            // El alias es opcional
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildQRForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configuración QR',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        DropdownButtonFormField<String>(
          value: _selectedQrType,
          decoration: _buildInputDecoration('Tipo de QR'),
          items: const [
            DropdownMenuItem(value: 'mercadopago', child: Text('Mercado Pago')),
            DropdownMenuItem(value: 'personal', child: Text('Personal Pay')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedQrType = value;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Seleccioná un tipo de QR';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        if (_selectedQrType == 'mercadopago') ...[
          const Text(
            'Se redirigirá a la app de Mercado Pago para completar el pago.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ] else if (_selectedQrType == 'personal') ...[
          const Text(
            'Escaneá el código QR con la app de Personal Pay.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildWalletForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Billetera Digital',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        DropdownButtonFormField<String>(
          value: _walletProviderController.text.isNotEmpty ? _walletProviderController.text : null,
          decoration: _buildInputDecoration('Proveedor'),
          items: const [
            DropdownMenuItem(value: 'mercadopago', child: Text('Mercado Pago')),
            DropdownMenuItem(value: 'uala', child: Text('Ualá')),
            DropdownMenuItem(value: 'modo', child: Text('Modo')),
            DropdownMenuItem(value: 'personal_pay', child: Text('Personal Pay')),
          ],
          onChanged: (value) {
            setState(() {
              _walletProviderController.text = value ?? '';
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Seleccioná un proveedor';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _walletEmailController,
          decoration: _buildInputDecoration('Email asociado'),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || !value.contains('@')) {
              return 'Email inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _walletPhoneController,
          decoration: _buildInputDecoration('Teléfono asociado (opcional)'),
          keyboardType: TextInputType.phone,
          validator: (value) {
            // El teléfono es opcional
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCryptoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Criptomonedas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        DropdownButtonFormField<String>(
          value: _selectedCryptoType,
          decoration: _buildInputDecoration('Tipo de cripto'),
          items: const [
            DropdownMenuItem(value: 'bitcoin', child: Text('Bitcoin (BTC)')),
            DropdownMenuItem(value: 'ethereum', child: Text('Ethereum (ETH)')),
            DropdownMenuItem(value: 'usdt', child: Text('Tether (USDT)')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedCryptoType = value;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Seleccioná un tipo de cripto';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _cryptoAddressController,
          decoration: _buildInputDecoration('Dirección de la billetera'),
          validator: (value) {
            if (value == null || value.length < 20) {
              return 'Dirección inválida';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        const Text(
          '⚠️ Las transacciones con criptomonedas son irreversibles. Verificá bien la dirección.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCashForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.money,
            color: Colors.green,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Pago en Efectivo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pagá cuando recibas tu pedido. Es el método más simple y seguro.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  IconData _getPaymentTypeIcon(PaymentType type) {
    switch (type) {
      case PaymentType.cash:
        return Icons.money;
      case PaymentType.creditCard:
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

  String _getPaymentTypeName(PaymentType type) {
    switch (type) {
      case PaymentType.cash:
        return 'Efectivo';
      case PaymentType.creditCard:
        return 'Tarjeta de Crédito';
      case PaymentType.debitCard:
        return 'Tarjeta de Débito';
      case PaymentType.transfer:
        return 'Transferencia Bancaria';
      case PaymentType.qr:
        return 'Pago QR';
      case PaymentType.wallet:
        return 'Billetera Digital';
      case PaymentType.crypto:
        return 'Criptomonedas';
    }
  }

  String _getPaymentTypeDescription(PaymentType type) {
    switch (type) {
      case PaymentType.cash:
        return 'Pagá cuando recibas tu pedido';
      case PaymentType.creditCard:
        return 'Visa, Mastercard, Amex, etc.';
      case PaymentType.debitCard:
        return 'Débito directo de tu cuenta';
      case PaymentType.transfer:
        return 'Desde cualquier banco argentino';
      case PaymentType.qr:
        return 'Escaneá el código QR';
      case PaymentType.wallet:
        return 'Ualá, Modo, Personal Pay';
      case PaymentType.crypto:
        return 'Bitcoin, Ethereum, etc.';
    }
  }
}

// Formateador para fecha de vencimiento de tarjeta
class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    
    if (text.length > 4) {
      text = text.substring(0, 4);
    }
    
    if (text.length == 2 && oldValue.text.length == 1) {
      text = '$text/';
    } else if (text.length == 2 && oldValue.text.length == 3) {
      text = text.substring(0, 1);
    }
    
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
