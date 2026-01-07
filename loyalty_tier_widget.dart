// ============================================================================
// widgets/loyalty_tier_widget.dart - Widget de Nivel de Lealtad
// ============================================================================

import 'package:flutter/material.dart';
import '../models/loyalty_model.dart';

class LoyaltyTierWidget extends StatelessWidget {
  final LoyaltyTier currentTier;
  final int currentPoints;
  final int pointsToNextTier;
  final double progress;
  final bool showProgress;
  final double? size;

  const LoyaltyTierWidget({
    Key? key,
    required this.currentTier,
    required this.currentPoints,
    required this.pointsToNextTier,
    required this.progress,
    this.showProgress = true,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final widgetSize = size ?? 120.0;
    
    return Container(
      width: widgetSize,
      height: widgetSize,
      child: Stack(
        children: [
          // Círculo de progreso
          if (showProgress && currentTier != LoyaltyTier.diamond)
            Positioned.fill(
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(currentTier.color),
              ),
            ),
          
          // Contenido central
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono del nivel
                Icon(
                  currentTier.icon,
                  size: widgetSize * 0.3,
                  color: currentTier.color,
                ),
                
                const SizedBox(height: 4),
                
                // Nombre del nivel
                Text(
                  currentTier.displayName,
                  style: TextStyle(
                    fontSize: widgetSize * 0.12,
                    fontWeight: FontWeight.bold,
                    color: currentTier.color,
                  ),
                ),
                
                // Puntos actuales
                Text(
                  currentPoints.toString(),
                  style: TextStyle(
                    fontSize: widgetSize * 0.15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                
                // Puntos para siguiente nivel
                if (showProgress && currentTier != LoyaltyTier.diamond)
                  Text(
                    '+$pointsToNextTier',
                    style: TextStyle(
                      fontSize: widgetSize * 0.1,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoyaltyTierCard extends StatelessWidget {
  final LoyaltyTier tier;
  final int currentPoints;
  final bool isCurrentTier;
  final bool isUnlocked;
  final List<String> benefits;

  const LoyaltyTierCard({
    Key? key,
    required this.tier,
    required this.currentPoints,
    required this.isCurrentTier,
    required this.isUnlocked,
    required this.benefits,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final requiredPoints = _getRequiredPoints(tier);
    final isAchieved = currentPoints >= requiredPoints;
    
    return Card(
      elevation: isCurrentTier ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrentTier 
            ? BorderSide(color: tier.color, width: 2)
            : BorderSide.none,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isCurrentTier
              ? LinearGradient(
                  colors: [
                    tier.color.withOpacity(0.1),
                    tier.color.withOpacity(0.05),
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con nivel
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUnlocked ? tier.color.withOpacity(0.2) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      tier.icon,
                      color: isUnlocked ? tier.color : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier.displayName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? tier.color : Colors.grey,
                          ),
                        ),
                        Text(
                          '$requiredPoints puntos',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrentTier)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: tier.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ACTUAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                ),
              ],
              ),
              
              const SizedBox(height: 16),
              
              // Progreso
              if (!isAchieved && !isCurrentTier) ...[
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (currentPoints / requiredPoints).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tier.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(currentPoints / requiredPoints * 100).toInt()}% completado',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Beneficios
              Text(
                'Beneficios:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ...benefits.map((benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: isUnlocked ? tier.color : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        benefit,
                        style: TextStyle(
                          fontSize: 12,
                          color: isUnlocked ? Colors.black87 : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  int _getRequiredPoints(LoyaltyTier tier) {
    switch (tier) {
      case LoyaltyTier.bronze:
        return 0;
      case LoyaltyTier.silver:
        return 500;
      case LoyaltyTier.gold:
        return 1500;
      case LoyaltyTier.platinum:
        return 5000;
      case LoyaltyTier.diamond:
        return 15000;
    }
  }
}

class LoyaltyPointsDisplay extends StatelessWidget {
  final int currentPoints;
  final int pointsEarnedToday;
  final int pointsSpentToday;
  final VoidCallback? onHistoryTap;

  const LoyaltyPointsDisplay({
    Key? key,
    required this.currentPoints,
    this.pointsEarnedToday = 0,
    this.pointsSpentToday = 0,
    this.onHistoryTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.amber[400]!,
              Colors.amber[600]!,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.stars,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Mis Puntos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (onHistoryTap != null)
                    IconButton(
                      onPressed: onHistoryTap,
                      icon: const Icon(
                        Icons.history,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Puntos actuales
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      currentPoints.toString(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'puntos',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Estadísticas del día
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+$pointsEarnedToday',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'ganados hoy',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.trending_down,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '-$pointsSpentToday',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'usados hoy',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoyaltyStreakWidget extends StatelessWidget {
  final int streakDays;
  final DateTime lastActivityDate;

  const LoyaltyStreakWidget({
    Key? key,
    required this.streakDays,
    required this.lastActivityDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysSinceLastActivity = now.difference(lastActivityDate).inDays;
    final isActive = daysSinceLastActivity <= 1;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive ? Colors.orange[50] : Colors.grey[50],
        ),
        child: Column(
          children: [
            // Icono con animación
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive ? Colors.orange[200] : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                color: isActive ? Colors.orange[800] : Colors.grey[600],
                size: 32,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Días de streak
            Text(
              '$streakDays',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.orange[800] : Colors.grey[600],
              ),
            ),
            
            Text(
              'días seguidos',
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.orange[600] : Colors.grey[500],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.orange[200] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? '¡Activo!' : 'Inactivo',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.orange[800] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
