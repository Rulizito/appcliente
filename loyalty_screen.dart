// ============================================================================
// screens/loyalty_screen.dart - Pantalla Principal de Lealtad
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/loyalty_model.dart';
import '../services/loyalty_service.dart';
import '../services/auth_service.dart';
import '../widgets/loyalty_tier_widget.dart';
import '../widgets/loyalty_reward_widget.dart';
import 'package:intl/intl.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({Key? key}) : super(key: key);

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen>
    with SingleTickerProviderStateMixin {
  final _loyaltyService = LoyaltyService();
  final _authService = AuthService();
  late TabController _tabController;

  // Datos del programa y usuario
  LoyaltyProgram? _program;
  UserLoyalty? _userLoyalty;
  List<LoyaltyReward> _rewards = [];
  List<LoyaltyTransaction> _transactions = [];
  Map<String, dynamic>? _userStats;

  // Estado de carga
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadLoyaltyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLoyaltyData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Usuario no autenticado';
          _isLoading = false;
        });
        return;
      }

      // Cargar datos en paralelo
      await Future.wait([
        _loadProgram(),
        _loadUserLoyalty(user.uid),
        _loadRewards(user.uid),
        _loadTransactions(user.uid),
        _loadUserStats(user.uid),
      ]);
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProgram() async {
    _program = await _loyaltyService.getActiveProgram().first;
  }

  Future<void> _loadUserLoyalty(String userId) async {
    _userLoyalty = await _loyaltyService.getUserLoyalty(userId).first;
  }

  Future<void> _loadRewards(String userId) async {
    if (_userLoyalty != null) {
      _rewards = await _loyaltyService.getAvailableRewards(userId, _userLoyalty!.currentTier).first;
    }
  }

  Future<void> _loadTransactions(String userId) async {
    _transactions = await _loyaltyService.getUserTransactions(userId).first;
  }

  Future<void> _loadUserStats(String userId) async {
    _userStats = await _loyaltyService.getUserLoyaltyStats(userId);
  }

  Future<void> _redeemReward(LoyaltyReward reward) async {
    if (_userLoyalty == null || _program == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Canje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que quieres canjear esta recompensa?'),
            const SizedBox(height: 16),
            Text(
              reward.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              reward.description,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Costo: ${reward.pointsCost} puntos',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final result = await _loyaltyService.redeemReward(
                userId: _authService.currentUser!.uid,
                rewardId: reward.id,
                programId: _program!.id,
              );

              if (result['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadLoyaltyData(); // Recargar datos
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Canjear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5), // Colors.grey[50]
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5), // Colors.grey[50]
        appBar: AppBar(
          title: const Text('Programa de Lealtad'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadLoyaltyData,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_program == null || _userLoyalty == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5), // Colors.grey[50]
        appBar: AppBar(
          title: const Text('Programa de Lealtad'),
          backgroundColor: Colors.red,
        ),
        body: const Center(
          child: Text('No hay programa de lealtad activo'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Colors.grey[50]
      appBar: AppBar(
        title: const Text(
          'Programa de Lealtad',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Inicio', icon: Icon(Icons.home)),
            Tab(text: 'Recompensas', icon: Icon(Icons.card_giftcard)),
            Tab(text: 'Niveles', icon: Icon(Icons.emoji_events)),
            Tab(text: 'Historial', icon: Icon(Icons.history)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadLoyaltyData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHomeTab(),
          _buildRewardsTab(),
          _buildTiersTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner del programa
          _buildProgramBanner(),
          
          const SizedBox(height: 20),
          
          // Tarjeta de puntos
          LoyaltyPointsDisplay(
            currentPoints: _userLoyalty!.currentPoints,
            pointsEarnedToday: _userStats?['pointsEarnedToday'] ?? 0,
            pointsSpentToday: _userStats?['pointsSpentToday'] ?? 0,
            onHistoryTap: () => _tabController.animateTo(3),
          ),
          
          const SizedBox(height: 20),
          
          // Nivel actual y progreso
          Row(
            children: [
              Expanded(
                child: LoyaltyTierWidget(
                  currentTier: _userLoyalty!.currentTier,
                  currentPoints: _userLoyalty!.currentPoints,
                  pointsToNextTier: _userLoyalty!.pointsToNextTier,
                  progress: _userLoyalty!.progressToNextTier,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LoyaltyStreakWidget(
                  streakDays: _userLoyalty!.streakDays,
                  lastActivityDate: _userLoyalty!.lastActivityDate,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Estadísticas rápidas
          _buildQuickStats(),
          
          const SizedBox(height: 20),
          
          // Recompensas destacadas
          _buildFeaturedRewards(),
        ],
      ),
    );
  }

  Widget _buildProgramBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.red[400]!,
            Colors.red[600]!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Programa de Lealtad',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _program!.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _program!.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tus Estadísticas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Ganados',
                    '${_userLoyalty!.totalPointsEarned}',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Total Canjeados',
                    '${_userLoyalty!.totalPointsSpent}',
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Recompensas',
                    '${_userStats?['redeemedRewardsCount'] ?? 0}',
                    Icons.card_giftcard,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Streak',
                    '${_userLoyalty!.streakDays} días',
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedRewards() {
    final featuredRewards = _rewards.take(3).toList();
    
    if (featuredRewards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recompensas Destacadas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...featuredRewards.map((reward) {
          final canRedeem = reward.canUserRedeem(_userLoyalty!);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LoyaltyRewardCard(
              reward: reward,
              userPoints: _userLoyalty!.currentPoints,
              userTier: _userLoyalty!.currentTier,
              canRedeem: canRedeem,
              onRedeem: () => _redeemReward(reward),
              onTap: () => _tabController.animateTo(1),
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _tabController.animateTo(1),
          child: const Text('Ver todas las recompensas'),
        ),
      ],
    );
  }

  Widget _buildRewardsTab() {
    return LoyaltyRewardList(
      rewards: _rewards,
      userPoints: _userLoyalty!.currentPoints,
      userTier: _userLoyalty!.currentTier,
      onRedeem: _redeemReward,
    );
  }

  Widget _buildTiersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Nivel actual
          LoyaltyTierCard(
            tier: _userLoyalty!.currentTier,
            currentPoints: _userLoyalty!.currentPoints,
            isCurrentTier: true,
            isUnlocked: true,
            benefits: _getTierBenefits(_userLoyalty!.currentTier),
          ),
          
          const SizedBox(height: 20),
          
          // Otros niveles
          ...LoyaltyTier.values.where((tier) => tier != _userLoyalty!.currentTier).map((tier) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LoyaltyTierCard(
                tier: tier,
                currentPoints: _userLoyalty!.currentPoints,
                isCurrentTier: false,
                isUnlocked: _userLoyalty!.currentTier.index >= tier.index,
                benefits: _getTierBenefits(tier),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen del Mes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryItem(
                          'Ganados',
                          '${_userStats?['pointsEarnedThisMonth'] ?? 0}',
                          Icons.trending_up,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryItem(
                          'Canjeados',
                          '${_userStats?['pointsSpentThisMonth'] ?? 0}',
                          Icons.trending_down,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Historial de transacciones
          const Text(
            'Historial de Transacciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          if (_transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No hay transacciones registradas'),
              ),
            )
          else
            ..._transactions.map((transaction) {
              return _buildTransactionItem(transaction);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(LoyaltyTransaction transaction) {
    final isEarned = transaction.isEarned;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEarned ? Colors.green[100] : Colors.red[100],
          child: Icon(
            isEarned ? Icons.add : Icons.remove,
            color: isEarned ? Colors.green : Colors.red,
          ),
        ),
        title: Text(transaction.description),
        subtitle: Text(
          DateFormat('dd MMM yyyy, HH:mm').format(transaction.createdAt),
        ),
        trailing: Text(
          '${isEarned ? '+' : '-'}${transaction.points.abs()}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isEarned ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  List<String> _getTierBenefits(LoyaltyTier tier) {
    switch (tier) {
      case LoyaltyTier.bronze:
        return [
          '1 punto por cada \$10 gastados',
          'Acceso a recompensas básicas',
          'Soporte por email',
        ];
      case LoyaltyTier.silver:
        return [
          '2 puntos por cada \$10 gastados',
          'Descuentos exclusivos del 5%',
          'Envío gratis en pedidos mayores a \$20',
          'Soporte prioritario',
        ];
      case LoyaltyTier.gold:
        return [
          '3 puntos por cada \$10 gastados',
          'Descuentos exclusivos del 10%',
          'Envío gratis en todos los pedidos',
          'Acceso a recompensas premium',
          'Soporte por teléfono',
        ];
      case LoyaltyTier.platinum:
        return [
          '5 puntos por cada \$10 gastados',
          'Descuentos exclusivos del 15%',
          'Envío gratis y prioritario',
          'Acceso a eventos exclusivos',
          'Doble puntos los fines de semana',
          'Soporte VIP 24/7',
        ];
      case LoyaltyTier.diamond:
        return [
          '10 puntos por cada \$10 gastados',
          'Descuentos exclusivos del 20%',
          'Envío gratis y prioritario',
          'Acceso a eventos exclusivos',
          'Triple puntos todos los días',
          'Recompensas personalizadas',
          'Soporte VIP dedicado',
          'Invitaciones a lanzamientos',
        ];
    }
  }
}
