// ============================================================================
// services/notification_analytics_service.dart - Servicio de Análisis de Notificaciones
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/notification_preference_model.dart';
import '../models/notification_template_model.dart';

class NotificationAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener estadísticas generales del sistema
  Stream<Map<String, dynamic>> getSystemAnalytics() {
    return _firestore
        .collection('notification_analytics')
        .snapshots()
        .map((snapshot) {
          final analytics = snapshot.docs
              .map((doc) => NotificationAnalytics.fromFirestore(doc))
              .toList();

          return _calculateSystemStats(analytics);
        });
  }

  // Obtener estadísticas por período
  Future<Map<String, dynamic>> getAnalyticsByPeriod(
    DateTime startDate,
    DateTime endDate, {
    String? userId,
    NotificationType? type,
    NotificationChannel? channel,
  }) async {
    try {
      Query query = _firestore.collection('notification_analytics')
          .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.value);
      }

      if (channel != null) {
        query = query.where('channel', isEqualTo: channel.value);
      }

      final snapshot = await query.get();
      final analytics = snapshot.docs
          .map((doc) => NotificationAnalytics.fromFirestore(doc))
          .toList();

      return _calculatePeriodStats(analytics, startDate, endDate);
    } catch (e) {
      print('Error getting analytics by period: $e');
      return {};
    }
  }

  // Obtener estadísticas de rendimiento de plantillas
  Stream<Map<String, Map<String, dynamic>>> getTemplatePerformance() {
    return _firestore
        .collection('notification_templates')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((templatesSnapshot) async {
      final templatePerformance = <String, Map<String, dynamic>>{};

      for (final templateDoc in templatesSnapshot.docs) {
        final template = NotificationTemplate.fromFirestore(templateDoc);
        
        final analyticsQuery = await _firestore
            .collection('notification_analytics')
            .where('type', isEqualTo: template.type.value)
            .get();

        final analytics = analyticsQuery.docs
            .map((doc) => NotificationAnalytics.fromFirestore(doc))
            .toList();

        templatePerformance[template.id] = _calculateTemplateStats(template, analytics);
      }

      return templatePerformance;
    });
  }

  // Obtener tendencias de engagement
  Future<Map<String, dynamic>> getEngagementTrends({
    int days = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('notification_analytics')
          .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final analytics = snapshot.docs
          .map((doc) => NotificationAnalytics.fromFirestore(doc))
          .toList();

      return _calculateEngagementTrends(analytics, startDate, endDate);
    } catch (e) {
      print('Error getting engagement trends: $e');
      return {};
    }
  }

  // Obtener análisis de usuarios activos
  Future<Map<String, dynamic>> getActiveUsersAnalysis({
    int days = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('notification_analytics')
          .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final analytics = snapshot.docs
          .map((doc) => NotificationAnalytics.fromFirestore(doc))
          .toList();

      return _calculateActiveUsersStats(analytics);
    } catch (e) {
      print('Error getting active users analysis: $e');
      return {};
    }
  }

  // Obtener análisis de horarios óptimos
  Future<Map<String, dynamic>> getOptimalSendTimes({
    int days = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('notification_analytics')
          .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final analytics = snapshot.docs
          .map((doc) => NotificationAnalytics.fromFirestore(doc))
          .toList();

      return _calculateOptimalSendTimes(analytics);
    } catch (e) {
      print('Error getting optimal send times: $e');
      return {};
    }
  }

  // Obtener análisis de segmentación
  Future<Map<String, dynamic>> getSegmentationAnalysis() async {
    try {
      final snapshot = await _firestore
          .collection('notification_analytics')
          .get();

      final analytics = snapshot.docs
          .map((doc) => NotificationAnalytics.fromFirestore(doc))
          .toList();

      return _calculateSegmentationStats(analytics);
    } catch (e) {
      print('Error getting segmentation analysis: $e');
      return {};
    }
  }

  // Obtener predictivo de engagement
  Future<Map<String, dynamic>> getEngagementPrediction(String userId) async {
    try {
      // Obtener historial del usuario
      final userSnapshot = await _firestore
          .collection('notification_analytics')
          .where('userId', isEqualTo: userId)
          .orderBy('sentAt', descending: true)
          .limit(100)
          .get();

      final userAnalytics = userSnapshot.docs
          .map((doc) => NotificationAnalytics.fromFirestore(doc))
          .toList();

      return _calculateEngagementPrediction(userAnalytics);
    } catch (e) {
      print('Error getting engagement prediction: $e');
      return {};
    }
  }

  // Generar reporte completo
  Future<Map<String, dynamic>> generateComprehensiveReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final reportStartDate = startDate ?? now.subtract(const Duration(days: 30));
      final reportEndDate = endDate ?? now;

      final [
        systemStats,
        templatePerformance,
        engagementTrends,
        activeUsersStats,
        optimalSendTimes,
        segmentationStats,
      ] = await Future.wait([
        getAnalyticsByPeriod(reportStartDate, reportEndDate),
        _getTemplatePerformanceData(),
        getEngagementTrends(days: reportEndDate.difference(reportStartDate).inDays),
        getActiveUsersAnalysis(days: reportEndDate.difference(reportStartDate).inDays),
        getOptimalSendTimes(days: reportEndDate.difference(reportStartDate).inDays),
        getSegmentationAnalysis(),
      ]);

      return {
        'period': {
          'startDate': reportStartDate.toIso8601String(),
          'endDate': reportEndDate.toIso8601String(),
          'days': reportEndDate.difference(reportStartDate).inDays,
        },
        'systemStats': systemStats,
        'templatePerformance': templatePerformance,
        'engagementTrends': engagementTrends,
        'activeUsersStats': activeUsersStats,
        'optimalSendTimes': optimalSendTimes,
        'segmentationStats': segmentationStats,
        'generatedAt': now.toIso8601String(),
      };
    } catch (e) {
      print('Error generating comprehensive report: $e');
      return {};
    }
  }

  // Métodos de cálculo privados
  Map<String, dynamic> _calculateSystemStats(List<NotificationAnalytics> analytics) {
    final totalSent = analytics.length;
    final totalDelivered = analytics.where((a) => a.isDelivered).length;
    final totalOpened = analytics.where((a) => a.isOpened).length;
    final totalClicked = analytics.where((a) => a.isClicked).length;

    final uniqueUsers = analytics.map((a) => a.userId).toSet().length;

    return {
      'totalSent': totalSent,
      'totalDelivered': totalDelivered,
      'totalOpened': totalOpened,
      'totalClicked': totalClicked,
      'uniqueUsers': uniqueUsers,
      'deliveryRate': totalSent > 0 ? totalDelivered / totalSent : 0.0,
      'openRate': totalDelivered > 0 ? totalOpened / totalDelivered : 0.0,
      'clickRate': totalOpened > 0 ? totalClicked / totalOpened : 0.0,
      'engagementRate': totalDelivered > 0 ? 
          (totalOpened + totalClicked) / (totalDelivered * 2) : 0.0,
    };
  }

  Map<String, dynamic> _calculatePeriodStats(
    List<NotificationAnalytics> analytics,
    DateTime startDate,
    DateTime endDate,
  ) {
    final baseStats = _calculateSystemStats(analytics);
    
    // Estadísticas por día
    final dailyStats = <String, Map<String, dynamic>>{};
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      final dayAnalytics = analytics.where((a) {
        final sentDate = DateTime(a.sentAt.year, a.sentAt.month, a.sentAt.day);
        final checkDate = DateTime(date.year, date.month, date.day);
        return sentDate.isAtSameMomentAs(checkDate);
      }).toList();

      dailyStats[dateKey] = _calculateSystemStats(dayAnalytics);
    }

    // Estadísticas por tipo
    final statsByType = <String, Map<String, dynamic>>{};
    for (final type in NotificationType.values) {
      final typeAnalytics = analytics.where((a) => a.type == type).toList();
      if (typeAnalytics.isNotEmpty) {
        statsByType[type.value] = _calculateSystemStats(typeAnalytics);
      }
    }

    // Estadísticas por canal
    final statsByChannel = <String, Map<String, dynamic>>{};
    for (final channel in NotificationChannel.values) {
      final channelAnalytics = analytics.where((a) => a.channel == channel).toList();
      if (channelAnalytics.isNotEmpty) {
        statsByChannel[channel.value] = _calculateSystemStats(channelAnalytics);
      }
    }

    return {
      ...baseStats,
      'dailyStats': dailyStats,
      'statsByType': statsByType,
      'statsByChannel': statsByChannel,
    };
  }

  Map<String, dynamic> _calculateTemplateStats(
    NotificationTemplate template,
    List<NotificationAnalytics> analytics,
  ) {
    final baseStats = _calculateSystemStats(analytics);
    
    // Tiempos promedio
    final avgTimeToOpen = analytics
        .where((a) => a.timeToOpen != null)
        .map((a) => a.timeToOpen!.inSeconds)
        .toList();
    
    final avgTimeToClick = analytics
        .where((a) => a.timeToClick != null)
        .map((a) => a.timeToClick!.inSeconds)
        .toList();

    return {
      ...baseStats,
      'templateName': template.name,
      'templateType': template.type.displayName,
      'avgTimeToOpen': avgTimeToOpen.isNotEmpty 
          ? avgTimeToOpen.reduce((a, b) => a + b) / avgTimeToOpen.length 
          : 0.0,
      'avgTimeToClick': avgTimeToClick.isNotEmpty 
          ? avgTimeToClick.reduce((a, b) => a + b) / avgTimeToClick.length 
          : 0.0,
      'performance': _calculatePerformanceScore(baseStats),
    };
  }

  Map<String, dynamic> _calculateEngagementTrends(
    List<NotificationAnalytics> analytics,
    DateTime startDate,
    DateTime endDate,
  ) {
    // Agrupar por día
    final dailyEngagement = <String, double>{};
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      final dayAnalytics = analytics.where((a) {
        final sentDate = DateTime(a.sentAt.year, a.sentAt.month, a.sentAt.day);
        final checkDate = DateTime(date.year, date.month, date.day);
        return sentDate.isAtSameMomentAs(checkDate);
      }).toList();

      final dayStats = _calculateSystemStats(dayAnalytics);
      dailyEngagement[dateKey] = dayStats['engagementRate'] ?? 0.0;
    }

    // Calcular tendencia
    final engagementValues = dailyEngagement.values.toList();
    double trend = 0.0;
    if (engagementValues.length > 1) {
      final firstWeek = engagementValues.take(7).reduce((a, b) => a + b) / 
          engagementValues.take(7).length;
      final lastWeek = engagementValues.skip(engagementValues.length - 7)
          .reduce((a, b) => a + b) / 7;
      trend = ((lastWeek - firstWeek) / firstWeek) * 100;
    }

    return {
      'dailyEngagement': dailyEngagement,
      'trend': trend,
      'trendDirection': trend > 0 ? 'up' : trend < 0 ? 'down' : 'stable',
      'averageEngagement': engagementValues.isNotEmpty 
          ? engagementValues.reduce((a, b) => a + b) / engagementValues.length 
          : 0.0,
    };
  }

  Map<String, dynamic> _calculateActiveUsersStats(List<NotificationAnalytics> analytics) {
    final userStats = <String, Map<String, dynamic>>{};
    
    // Agrupar por usuario
    final userGroups = <String, List<NotificationAnalytics>>{};
    for (final analytic in analytics) {
      userGroups.putIfAbsent(analytic.userId, () => []).add(analytic);
    }

    // Calcular estadísticas por usuario
    for (final entry in userGroups.entries) {
      final userAnalytics = entry.value;
      final stats = _calculateSystemStats(userAnalytics);
      
      userStats[entry.key] = {
        'totalNotifications': userAnalytics.length,
        'engagementRate': stats['engagementRate'] ?? 0.0,
        'lastActivity': userAnalytics
            .map((a) => a.sentAt)
            .reduce((a, b) => a.isAfter(b) ? a : b)
            .toIso8601String(),
      };
    }

    // Segmentar usuarios por engagement
    final highEngagement = userStats.values
        .where((stats) => stats['engagementRate'] > 0.7)
        .length;
    final mediumEngagement = userStats.values
        .where((stats) => stats['engagementRate'] >= 0.3 && stats['engagementRate'] <= 0.7)
        .length;
    final lowEngagement = userStats.values
        .where((stats) => stats['engagementRate'] < 0.3)
        .length;

    return {
      'totalActiveUsers': userStats.length,
      'highEngagementUsers': highEngagement,
      'mediumEngagementUsers': mediumEngagement,
      'lowEngagementUsers': lowEngagement,
      'userStats': userStats,
      'engagementDistribution': {
        'high': highEngagement / userStats.length,
        'medium': mediumEngagement / userStats.length,
        'low': lowEngagement / userStats.length,
      },
    };
  }

  Map<String, dynamic> _calculateOptimalSendTimes(List<NotificationAnalytics> analytics) {
    final hourlyStats = <int, Map<String, dynamic>>{};
    
    // Agrupar por hora del día
    for (int hour = 0; hour < 24; hour++) {
      final hourAnalytics = analytics.where((a) => a.sentAt.hour == hour).toList();
      final stats = _calculateSystemStats(hourAnalytics);
      
      hourlyStats[hour] = {
        'sent': hourAnalytics.length,
        'engagementRate': stats['engagementRate'] ?? 0.0,
        'openRate': stats['openRate'] ?? 0.0,
        'clickRate': stats['clickRate'] ?? 0.0,
      };
    }

    // Encontrar mejores horas
    final sortedByEngagement = hourlyStats.entries.toList()
      ..sort((a, b) => b.value['engagementRate'].compareTo(a.value['engagementRate']));

    return {
      'hourlyStats': hourlyStats,
      'bestHours': sortedByEngagement.take(3).map((e) => e.key).toList(),
      'worstHours': sortedByEngagement.reversed.take(3).map((e) => e.key).toList(),
      'peakHour': sortedByEngagement.first.key,
      'peakEngagement': sortedByEngagement.first.value['engagementRate'],
    };
  }

  Map<String, dynamic> _calculateSegmentationStats(List<NotificationAnalytics> analytics) {
    // Segmentación por tipo de notificación
    final typeSegmentation = <String, Map<String, dynamic>>{};
    for (final type in NotificationType.values) {
      final typeAnalytics = analytics.where((a) => a.type == type).toList();
      if (typeAnalytics.isNotEmpty) {
        final stats = _calculateSystemStats(typeAnalytics);
        typeSegmentation[type.value] = {
          'count': typeAnalytics.length,
          'engagementRate': stats['engagementRate'] ?? 0.0,
          'performance': _calculatePerformanceScore(stats),
        };
      }
    }

    // Segmentación por canal
    final channelSegmentation = <String, Map<String, dynamic>>{};
    for (final channel in NotificationChannel.values) {
      final channelAnalytics = analytics.where((a) => a.channel == channel).toList();
      if (channelAnalytics.isNotEmpty) {
        final stats = _calculateSystemStats(channelAnalytics);
        channelSegmentation[channel.value] = {
          'count': channelAnalytics.length,
          'engagementRate': stats['engagementRate'] ?? 0.0,
          'performance': _calculatePerformanceScore(stats),
        };
      }
    }

    return {
      'typeSegmentation': typeSegmentation,
      'channelSegmentation': channelSegmentation,
    };
  }

  Map<String, dynamic> _calculateEngagementPrediction(List<NotificationAnalytics> userAnalytics) {
    if (userAnalytics.isEmpty) {
      return {
        'predictedEngagement': 0.0,
        'confidence': 0.0,
        'recommendations': ['Insufficient data for prediction'],
      };
    }

    // Calcular métricas históricas
    final recentAnalytics = userAnalytics.take(20).toList();
    final stats = _calculateSystemStats(recentAnalytics);
    
    // Calcular tendencia reciente
    final engagementTrend = _calculateRecentTrend(recentAnalytics);
    
    // Predicción simple basada en tendencia y promedio
    double predictedEngagement = stats['engagementRate'] ?? 0.0;
    if (engagementTrend['direction'] == 'up') {
      predictedEngagement *= 1.1; // +10%
    } else if (engagementTrend['direction'] == 'down') {
      predictedEngagement *= 0.9; // -10%
    }

    // Calcular confianza basada en cantidad de datos
    final confidence = (userAnalytics.length / 100.0).clamp(0.0, 1.0);

    // Generar recomendaciones
    final recommendations = <String>[];
    if (predictedEngagement < 0.3) {
      recommendations.add('Consider optimizing send times');
      recommendations.add('Review notification content');
    } else if (predictedEngagement > 0.7) {
      recommendations.add('Current strategy is working well');
    }

    return {
      'predictedEngagement': predictedEngagement,
      'confidence': confidence,
      'recentTrend': engagementTrend,
      'recommendations': recommendations,
      'dataPoints': userAnalytics.length,
    };
  }

  Map<String, dynamic> _calculateRecentTrend(List<NotificationAnalytics> analytics) {
    if (analytics.length < 5) {
      return {'direction': 'stable', 'change': 0.0};
    }

    final recent = analytics.take(5).map((a) => a.engagementRate).toList();
    final older = analytics.skip(5).take(5).map((a) => a.engagementRate).toList();

    if (older.isEmpty) {
      return {'direction': 'stable', 'change': 0.0};
    }

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;
    
    final change = ((recentAvg - olderAvg) / olderAvg) * 100;

    return {
      'direction': change > 5 ? 'up' : change < -5 ? 'down' : 'stable',
      'change': change,
      'recentAvg': recentAvg,
      'olderAvg': olderAvg,
    };
  }

  double _calculatePerformanceScore(Map<String, dynamic> stats) {
    final deliveryRate = stats['deliveryRate'] ?? 0.0;
    final openRate = stats['openRate'] ?? 0.0;
    final clickRate = stats['clickRate'] ?? 0.0;
    
    // Ponderación: delivery (30%), open (40%), click (30%)
    return (deliveryRate * 0.3) + (openRate * 0.4) + (clickRate * 0.3);
  }

  Future<Map<String, Map<String, dynamic>>> _getTemplatePerformanceData() async {
    final templatesSnapshot = await _firestore
        .collection('notification_templates')
        .where('isActive', isEqualTo: true)
        .get();

    final templatePerformance = <String, Map<String, dynamic>>{};

    for (final templateDoc in templatesSnapshot.docs) {
      final template = NotificationTemplate.fromFirestore(templateDoc);
      
      final analyticsQuery = await _firestore
          .collection('notification_analytics')
          .where('type', isEqualTo: template.type.value)
          .get();

      final analytics = analyticsQuery.docs
          .map((doc) => NotificationAnalytics.fromFirestore(doc))
          .toList();

      templatePerformance[template.id] = _calculateTemplateStats(template, analytics);
    }

    return templatePerformance;
  }

  // Métodos públicos para obtener estadísticas del usuario actual
  Stream<Map<String, dynamic>> getCurrentUserAnalytics() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value({});
    
    return _firestore
        .collection('notification_analytics')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final analytics = snapshot.docs
              .map((doc) => NotificationAnalytics.fromFirestore(doc))
              .toList();
          return _calculateSystemStats(analytics);
        });
  }

  Future<Map<String, dynamic>> getCurrentUserPrediction() {
    final user = _auth.currentUser;
    if (user == null) return Future.value({});
    return getEngagementPrediction(user.uid);
  }
}
