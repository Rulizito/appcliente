// ============================================================================
// screens/my_coupons_screen.dart - Mis Cupones Guardados
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/coupon_service.dart';
import '../services/auth_service.dart';
import '../models/coupon_model.dart';
import 'package:intl/intl.dart';

class MyCouponsScreen extends StatefulWidget {
  const MyCouponsScreen({Key? key}) : super(key: key);

  @override
  State<MyCouponsScreen> createState() => _MyCouponsScreenState();
}

class _MyCouponsScreenState extends State<MyCouponsScreen> {
  final _couponService = CouponService();
  final _authService = AuthService();

  void _copyCouponCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado 📋'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Inicia sesión para ver tus cupones'),
      );
    }

    return StreamBuilder<List<UserCoupon>>(
      stream: _couponService.getUserCoupons(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final userCoupons = snapshot.data ?? [];

        if (userCoupons.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wallet_outlined,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No tenés cupones guardados',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guardá cupones para usarlos cuando quieras',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Volver a la pestaña de cupones disponibles
                      DefaultTabController.of(context).animateTo(0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text(
                      'Ver Cupones Disponibles',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Contador de cupones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.red.shade700],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tus Cupones',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${userCoupons.length} disponibles',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_offer,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Lista de cupones
            ...userCoupons.map((userCoupon) {
              return FutureBuilder<Coupon?>(
                future: _couponService.getCouponDetails(userCoupon.couponId),
                builder: (context, couponSnapshot) {
                  if (!couponSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final coupon = couponSnapshot.data!;

                  return MyCouponCard(
                    coupon: coupon,
                    userCoupon: userCoupon,
                    onCopy: () => _copyCouponCode(coupon.code),
                  );
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

// Widget para cada cupón guardado
class MyCouponCard extends StatelessWidget {
  final Coupon coupon;
  final UserCoupon userCoupon;
  final VoidCallback onCopy;

  const MyCouponCard({
    Key? key,
    required this.coupon,
    required this.userCoupon,
    required this.onCopy,
  }) : super(key: key);

  Color _getSourceColor() {
    switch (coupon.source) {
      case CouponSource.achievement:
        return Colors.purple;
      case CouponSource.referral:
        return Colors.blue;
      case CouponSource.birthday:
        return Colors.pink;
      case CouponSource.firstOrder:
        return Colors.green;
      case CouponSource.loyalty:
        return Colors.amber;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceColor = _getSourceColor();
    final isExpiringSoon = coupon.isExpiringSoon;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isExpiringSoon
            ? Border.all(color: Colors.orange, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header con color
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sourceColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Descuento
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sourceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    coupon.discountText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Días restantes
                if (coupon.daysRemaining != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isExpiringSoon
                          ? Colors.orange
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isExpiringSoon ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${coupon.daysRemaining}d',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isExpiringSoon ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Código
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Código:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          coupon.code,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: sourceColor,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sourceColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Descripción
                Text(
                  coupon.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 12),

                // Info adicional
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (coupon.minAmount != null)
                      _buildInfoChip(
                        Icons.attach_money,
                        'Mín: \$${coupon.minAmount!.toInt()}',
                        sourceColor,
                      ),
                    if (coupon.isFirstOrderOnly)
                      _buildInfoChip(
                        Icons.looks_one,
                        'Primer pedido',
                        sourceColor,
                      ),
                    if (coupon.applicableCategories != null)
                      _buildInfoChip(
                        Icons.category,
                        coupon.applicableCategories!.join(', '),
                        sourceColor,
                      ),
                  ],
                ),

                // Alerta si está por vencer
                if (isExpiringSoon) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '¡Vence pronto! Úsalo antes de que expire',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}