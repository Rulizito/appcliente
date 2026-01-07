// ============================================================================
// widgets/loyalty_reward_widget.dart - Widget de Recompensas de Lealtad
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/loyalty_model.dart';

class LoyaltyRewardCard extends StatelessWidget {
  final LoyaltyReward reward;
  final int userPoints;
  final LoyaltyTier userTier;
  final bool canRedeem;
  final VoidCallback? onRedeem;
  final VoidCallback? onTap;

  const LoyaltyRewardCard({
    Key? key,
    required this.reward,
    required this.userPoints,
    required this.userTier,
    required this.canRedeem,
    this.onRedeem,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: canRedeem ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: canRedeem ? Colors.white : Colors.grey[50],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen o header
              if (reward.imageUrl != null && reward.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: reward.imageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      color: _getRewardTypeColor().withOpacity(0.1),
                      child: Center(
                        child: Icon(
                          _getRewardTypeIcon(),
                          size: 40,
                          color: _getRewardTypeColor(),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    color: _getRewardTypeColor().withOpacity(0.1),
                  ),
                  child: Center(
                    child: Icon(
                      _getRewardTypeIcon(),
                      size: 40,
                      color: _getRewardTypeColor(),
                    ),
                  ),
                ),
              
              // Contenido
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título y tipo
                      Text(
                        reward.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Descripción
                      Text(
                        reward.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Detalles del reward
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getRewardTypeColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getRewardTypeIcon(),
                              size: 16,
                              color: _getRewardTypeColor(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reward.formattedRewardText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _getRewardTypeColor(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Footer con puntos y nivel requerido
                      Row(
                        children: [
                          // Puntos requeridos
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: canRedeem ? Colors.amber[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.stars,
                                  size: 14,
                                  color: canRedeem ? Colors.amber[800] : Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${reward.pointsCost}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: canRedeem ? Colors.amber[800] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Nivel requerido
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: reward.requiredTier.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  reward.requiredTier.icon,
                                  size: 12,
                                  color: reward.requiredTier.color,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  reward.requiredTier.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: reward.requiredTier.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Botón de canje
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canRedeem ? onRedeem : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canRedeem ? Colors.red : Colors.grey[300],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            canRedeem ? 'Canjear ahora' : _getCannotRedeemReason(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRewardTypeColor() {
    switch (reward.type) {
      case RewardType.discount:
        return Colors.green;
      case RewardType.percentage:
        return Colors.blue;
      case RewardType.free_delivery:
        return Colors.purple;
      case RewardType.free_item:
        return Colors.orange;
      case RewardType.points_bonus:
        return Colors.amber;
      case RewardType.upgrade:
        return Colors.indigo;
      case RewardType.exclusive:
        return Colors.pink;
    }
  }

  IconData _getRewardTypeIcon() {
    switch (reward.type) {
      case RewardType.discount:
        return Icons.local_offer;
      case RewardType.percentage:
        return Icons.percent;
      case RewardType.free_delivery:
        return Icons.delivery_dining;
      case RewardType.free_item:
        return Icons.fastfood;
      case RewardType.points_bonus:
        return Icons.stars;
      case RewardType.upgrade:
        return Icons.trending_up;
      case RewardType.exclusive:
        return Icons.verified;
    }
  }

  String _getCannotRedeemReason() {
    if (userPoints < reward.pointsCost) {
      return 'Necesitas ${reward.pointsCost - userPoints} puntos más';
    }
    if (userTier.index < reward.requiredTier.index) {
      return 'Nivel ${reward.requiredTier.displayName} requerido';
    }
    if (!reward.isAvailable) {
      return 'No disponible';
    }
    return 'No disponible';
  }
}

class LoyaltyRewardList extends StatelessWidget {
  final List<LoyaltyReward> rewards;
  final int userPoints;
  final LoyaltyTier userTier;
  final Function(LoyaltyReward)? onRedeem;
  final Function(LoyaltyReward)? onTap;

  const LoyaltyRewardList({
    Key? key,
    required this.rewards,
    required this.userPoints,
    required this.userTier,
    this.onRedeem,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.card_giftcard,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Recompensas Disponibles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rewards.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Lista de recompensas
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];
              final canRedeem = reward.canUserRedeem(
                UserLoyalty(
                  id: '',
                  userId: '',
                  programId: '',
                  currentPoints: userPoints,
                  totalPointsEarned: 0,
                  totalPointsSpent: 0,
                  currentTier: userTier,
                  tierUpgradeDate: DateTime.now(),
                  lastActivityDate: DateTime.now(),
                  lastActionDates: {},
                  transactions: [],
                  createdAt: DateTime.now(),
                ),
              );
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LoyaltyRewardCard(
                  reward: reward,
                  userPoints: userPoints,
                  userTier: userTier,
                  canRedeem: canRedeem,
                  onRedeem: () => onRedeem?.call(reward),
                  onTap: () => onTap?.call(reward),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_giftcard_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay recompensas disponibles',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pronto habrá nuevas recompensas para ti',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoyaltyRewardGrid extends StatelessWidget {
  final List<LoyaltyReward> rewards;
  final int userPoints;
  final LoyaltyTier userTier;
  final Function(LoyaltyReward)? onRedeem;
  final Function(LoyaltyReward)? onTap;

  const LoyaltyRewardGrid({
    Key? key,
    required this.rewards,
    required this.userPoints,
    required this.userTier,
    this.onRedeem,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.grid_view,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Todas las Recompensas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        
        // Grid de recompensas
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];
              final canRedeem = reward.canUserRedeem(
                UserLoyalty(
                  id: '',
                  userId: '',
                  programId: '',
                  currentPoints: userPoints,
                  totalPointsEarned: 0,
                  totalPointsSpent: 0,
                  currentTier: userTier,
                  tierUpgradeDate: DateTime.now(),
                  lastActivityDate: DateTime.now(),
                  lastActionDates: {},
                  transactions: [],
                  createdAt: DateTime.now(),
                ),
              );
              
              return LoyaltyRewardCard(
                reward: reward,
                userPoints: userPoints,
                userTier: userTier,
                canRedeem: canRedeem,
                onRedeem: () => onRedeem?.call(reward),
                onTap: () => onTap?.call(reward),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_view_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay recompensas disponibles',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pronto habrá nuevas recompensas para ti',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
