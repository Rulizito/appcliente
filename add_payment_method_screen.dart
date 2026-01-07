// ============================================================================
// screens/add_payment_method_screen.dart - Pantalla para agregar métodos de pago
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment_method_model.dart' as pm;
import '../services/payment_service.dart';
import '../widgets/payment_method_form_widget.dart';

class AddPaymentMethodScreen extends StatefulWidget {
  const AddPaymentMethodScreen({Key? key}) : super(key: key);

  @override
  State<AddPaymentMethodScreen> createState() => _AddPaymentMethodScreenState();
}

class _AddPaymentMethodScreenState extends State<AddPaymentMethodScreen> {
  final PaymentService _paymentService = PaymentService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  pm.PaymentType _selectedType = pm.PaymentType.cash;
  bool _isLoading = false;
  bool _isDefault = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Método de Pago'),
        backgroundColor: Colors.red,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleccioná el tipo de método de pago',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Lista de tipos de pago
            ...pm.PaymentType.values.map((type) => _buildPaymentTypeCard(type)),
            
            const SizedBox(height: 24),
            
            // Formulario dinámico según el tipo seleccionado
            PaymentMethodFormWidget(
              paymentType: _selectedType,
              onSaved: (pm.PaymentMethod method) async {
                await _savePaymentMethod(method);
              },
              isLoading: _isLoading,
            ),
            
            const SizedBox(height: 32),
            
            // Checkbox para método por defecto
            if (_selectedType != pm.PaymentType.cash) ...[
              Row(
                children: [
                  Checkbox(
                    value: _isDefault,
                    onChanged: (value) {
                      setState(() {
                        _isDefault = value ?? false;
                      });
                    },
                    activeColor: Colors.red,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Establecer como método de pago por defecto',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Guardando...'),
                        ],
                      )
                    : const Text(
                        'Guardar Método de Pago',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTypeCard(pm.PaymentType type) {
    final isSelected = _selectedType == type;
    final methodInfo = _getPaymentMethodInfo(type);
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
        HapticFeedback.lightImpact();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.red : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                methodInfo['icon'],
                color: isSelected ? Colors.white : Colors.grey.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    methodInfo['name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.red : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    methodInfo['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.red,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getPaymentMethodInfo(pm.PaymentType type) {
    switch (type) {
      case pm.PaymentType.cash:
        return {
          'name': 'Efectivo',
          'description': 'Paga cuando recibas tu pedido',
          'icon': Icons.money,
        };
      case pm.PaymentType.creditCard:
        return {
          'name': 'Tarjeta de Crédito',
          'description': 'Visa, Mastercard, Amex, etc.',
          'icon': Icons.credit_card,
        };
      case pm.PaymentType.debitCard:
        return {
          'name': 'Tarjeta de Débito',
          'description': 'Débito directo de tu cuenta',
          'icon': Icons.credit_card,
        };
      case pm.PaymentType.transfer:
        return {
          'name': 'Transferencia Bancaria',
          'description': 'Desde cualquier banco argentino',
          'icon': Icons.account_balance,
        };
      case pm.PaymentType.qr:
        return {
          'name': 'Pago QR',
          'description': 'Mercado Pago, Personal Pay',
          'icon': Icons.qr_code,
        };
      case pm.PaymentType.wallet:
        return {
          'name': 'Billeteras Digitales',
          'description': 'Ualá, Modo, etc.',
          'icon': Icons.wallet,
        };
      case pm.PaymentType.crypto:
        return {
          'name': 'Criptomonedas',
          'description': 'Bitcoin, Ethereum, etc.',
          'icon': Icons.currency_bitcoin,
        };
    }
  }

  Future<void> _savePaymentMethod(pm.PaymentMethod method) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Por ahora, creamos un método de pago básico
      // El método ya viene como parámetro

      await _paymentService.savePaymentMethod(method);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Método de pago agregado exitosamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar método de pago: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generateMethodId() {
    return '${_selectedType.toString().split('.').last}_${DateTime.now().millisecondsSinceEpoch}';
  }
}
