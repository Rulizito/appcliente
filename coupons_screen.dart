// ============================================================================
// screens/coupons_screen.dart - Pantalla de Cupones Disponibles
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/coupon_service.dart';
import '../services/auth_service.dart';
import '../models/coupon_model.dart';
import 'package:intl/intl.dart';
import 'my_coupons_screen.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({Key? key}) : super(key: key);

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> with SingleTickerProviderStateMixin {
  final _couponService = CouponService();
  final _authService = AuthService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveCoupon(Coupon coupon) async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inició sesión para guardar cupones'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await _couponService.saveUserCoupon(
      userId: user.uid,
      couponId: coupon.id,
      couponCode: coupon.code,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? '¡Cupón guardado! 🎉' 
              : 'Error al guardar cupón'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cupones'),
        backgroundColor: Colors.red,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Disponibles', icon: Icon(Icons.local_offer)),
            Tab(text: 'Mis Cupones', icon: Icon(Icons.wallet)),
          ],
        ),
        actions: user != null ? [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // TODO: Ir a historial de cupones usados
            },
            tooltip: 'Historial',
          ),
        ] : null,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableCoupons(),
          user != null 
              ? MyCouponsScreen() 
              : _buildLoginPrompt(),
        ],
      ),
    );
  }

  Widget _buildAvailableCoupons() {
    return StreamBuilder<List<Coupon>>(
      stream: _couponService.getAvailableCoupons(),
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

        final coupons = snapshot.data ?? [];

        if (coupons.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No hay cupones disponibles',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vuelve pronto para ver ofertas exclusivas',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Separar cupones destacados
        final featuredCoupons = coupons.where((c) => c.isFeatured).toList();
        final regularCoupons = coupons.where((c) => !c.isFeatured).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (featuredCoupons.isNotEmpty) ...[
              const Text(
                '⭐ Destacados',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...featuredCoupons.map((coupon) => CouponCard(
                coupon: coupon,
                onSave: () => _saveCoupon(coupon),
                onCopy: () => _copyCouponCode(coupon.code),
              )),
              const SizedBox(height: 24),
            ],
            if (regularCoupons.isNotEmpty) ...[
              const Text(
                '🎟️ Todos los cupones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...regularCoupons.map((coupon) => CouponCard(
                coupon: coupon,
                onSave: () => _saveCoupon(coupon),
                onCopy: () => _copyCouponCode(coupon.code),
              )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLoginPrompt() {
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
              'Inicia sesión para ver tus cupones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Navegar a login
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'Iniciar Sesión',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para la tarjeta de cupón
class CouponCard extends StatelessWidget {
  final Coupon coupon;
  final VoidCallback onSave;
  final VoidCallback onCopy;

  const CouponCard({
    Key? key,
    required this.coupon,
    required this.onSave,
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

  String _getSourceText() {
    switch (coupon.source) {
      case CouponSource.achievement:
        return '🏆 Logro Desbloqueado';  // Tu texto
      case CouponSource.referral:
        return '👥 Referido';
      case CouponSource.birthday:
        return '🎂 Cumpleaños';
      case CouponSource.firstOrder:
        return '🎉 Primer pedido';
      case CouponSource.loyalty:
        return '💎 Lealtad';
      default:
        return '🎟️ General';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceColor = _getSourceColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            sourceColor,
            sourceColor.withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: sourceColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Patrón de fondo
            Positioned.fill(
              child: CustomPaint(
                painter: CouponPatternPainter(),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge de origen
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getSourceText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Descuento
                      Text(
                        coupon.discountText,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Código
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          coupon.code,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: sourceColor,
                            letterSpacing: 2,
                          ),
                        ),
                        InkWell(
                          onTap: onCopy,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: sourceColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.copy,
                              size: 18,
                              color: sourceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Descripción
                  Text(
                    coupon.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
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
                        ),
                      if (coupon.daysRemaining != null)
                        _buildInfoChip(
                          Icons.access_time,
                          '${coupon.daysRemaining} días',
                          isWarning: coupon.isExpiringSoon,
                        ),
                      if (coupon.isFirstOrderOnly)
                        _buildInfoChip(
                          Icons.looks_one,
                          'Primer pedido',
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.wallet),
                      label: const Text('Guardar Cupón'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: sourceColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isWarning 
            ? Colors.orange.withOpacity(0.3)
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Painter para el patrón de fondo del cupón
class CouponPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}