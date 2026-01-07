// ============================================================================
// screens/payment_methods_screen.dart - Pantalla principal de métodos de pago
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment_method_model.dart';
import '../services/payment_service.dart';
import 'add_payment_method_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final PaymentService _paymentService = PaymentService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<PaymentMethod> _paymentMethods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await _paymentService.getUserPaymentMethods();
      setState(() {
        _paymentMethods = methods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar métodos de pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métodos de Pago'),
        backgroundColor: Colors.red,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToAddPaymentMethod,
            tooltip: 'Agregar método de pago',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paymentMethods.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPaymentMethods,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _paymentMethods.length,
                    itemBuilder: (context, index) {
                      return _buildPaymentMethodCard(_paymentMethods[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddPaymentMethod,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes métodos de pago',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega una tarjeta o método de pago para comenzar',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddPaymentMethod,
            icon: const Icon(Icons.add),
            label: const Text('Agregar método de pago'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icono del método de pago
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getPaymentMethodColor(method.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getPaymentMethodIcon(method.type),
                color: _getPaymentMethodColor(method.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Información del método
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPaymentMethodName(method),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPaymentMethodDescription(method),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (method.fee != null && method.fee! > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Comisión: \$${method.fee!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Badge de método por defecto
            if (method.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Por defecto',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            
            const SizedBox(width: 8),
            
            // Menú de opciones
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
              onSelected: (value) => _handleMenuAction(value, method),
              itemBuilder: (context) => [
                if (!method.isDefault)
                  const PopupMenuItem(
                    value: 'default',
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 16),
                        SizedBox(width: 8),
                        Text('Establecer por defecto'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPaymentMethodColor(PaymentType type) {
    switch (type) {
      case PaymentType.creditCard:
        return Colors.blue;
      case PaymentType.debitCard:
        return Colors.green;
      case PaymentType.qr:
        return Colors.purple;
      case PaymentType.transfer:
        return Colors.orange;
      case PaymentType.wallet:
        return Colors.red;
      case PaymentType.crypto:
        return Colors.amber;
      case PaymentType.cash:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentMethodIcon(PaymentType type) {
    switch (type) {
      case PaymentType.creditCard:
        return Icons.credit_card;
      case PaymentType.debitCard:
        return Icons.credit_card;
      case PaymentType.qr:
        return Icons.qr_code_scanner;
      case PaymentType.transfer:
        return Icons.account_balance;
      case PaymentType.wallet:
        return Icons.account_balance_wallet;
      case PaymentType.crypto:
        return Icons.currency_bitcoin;
      case PaymentType.cash:
        return Icons.money;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodName(PaymentMethod method) {
    switch (method.type) {
      case PaymentType.creditCard:
        return method.cardNumber != null 
            ? 'Tarjeta de Crédito ****${method.cardNumber!.substring(method.cardNumber!.length - 4)}'
            : 'Tarjeta de Crédito';
      case PaymentType.debitCard:
        return method.cardNumber != null 
            ? 'Tarjeta de Débito ****${method.cardNumber!.substring(method.cardNumber!.length - 4)}'
            : 'Tarjeta de Débito';
      case PaymentType.qr:
        return 'QR ${method.qrType?.toUpperCase() ?? 'MERCADO PAGO'}';
      case PaymentType.transfer:
        return 'Transferencia Bancaria';
      case PaymentType.wallet:
        return method.walletType?.toUpperCase() ?? 'Billetera Digital';
      case PaymentType.crypto:
        return 'Criptomonedas';
      case PaymentType.cash:
        return 'Efectivo';
      default:
        return 'Método de Pago';
    }
  }

  String _getPaymentMethodDescription(PaymentMethod method) {
    switch (method.type) {
      case PaymentType.creditCard:
        return method.cardHolderName ?? 'Titular no especificado';
      case PaymentType.debitCard:
        return method.cardHolderName ?? 'Titular no especificado';
      case PaymentType.qr:
        return 'Escanea el código QR para pagar';
      case PaymentType.transfer:
        return 'Transferencia desde tu banco';
      case PaymentType.wallet:
        return 'Paga con tu billetera digital';
      case PaymentType.crypto:
        return 'Paga con criptomonedas';
      case PaymentType.cash:
        return 'Paga cuando recibas el pedido';
      default:
        return 'Método de pago disponible';
    }
  }

  Future<void> _navigateToAddPaymentMethod() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPaymentMethodScreen(),
      ),
    );

    if (result == true) {
      _loadPaymentMethods(); // Recargar si se agregó un método
    }
  }

  void _handleMenuAction(String action, PaymentMethod method) async {
    switch (action) {
      case 'default':
        await _setDefaultPaymentMethod(method);
        break;
      case 'edit':
        // TODO: Implementar edición
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Función de edición próximamente'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case 'delete':
        await _deletePaymentMethod(method);
        break;
    }
  }

  Future<void> _setDefaultPaymentMethod(PaymentMethod method) async {
    try {
      await _paymentService.setDefaultPaymentMethod(method.id);
      _loadPaymentMethods();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Método de pago establecido por defecto'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al establecer método por defecto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePaymentMethod(PaymentMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar método de pago'),
        content: Text('¿Estás seguro de que quieres eliminar ${_getPaymentMethodName(method)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _paymentService.deletePaymentMethod(method.id);
        _loadPaymentMethods();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Método de pago eliminado'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar método de pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
