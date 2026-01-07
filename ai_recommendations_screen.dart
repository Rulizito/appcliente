import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_recommendation_service.dart';
import '../widgets/detailed_recommendation_card.dart';

class AIRecommendationsScreen extends StatefulWidget {
  const AIRecommendationsScreen({Key? key}) : super(key: key);

  @override
  State<AIRecommendationsScreen> createState() => _AIRecommendationsScreenState();
}

class _AIRecommendationsScreenState extends State<AIRecommendationsScreen>
    with TickerProviderStateMixin {
  final AIRecommendationService _recommendationService = AIRecommendationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late TabController _tabController;
  
  List<Recommendation> _allRecommendations = [];
  List<Recommendation> _businessRecommendations = [];
  List<Recommendation> _timeRecommendations = [];
  List<Recommendation> _locationRecommendations = [];
  
  bool _isLoading = true;
  String? _error;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _userId = _auth.currentUser?.uid;
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Cargar todas las recomendaciones
      final allRecs = await _recommendationService.getPersonalizedRecommendations(
        _userId!,
        limit: 20,
        types: [RecommendationType.hybrid],
      );

      // Cargar recomendaciones por tipo
      final businessRecs = await _recommendationService.getPersonalizedRecommendations(
        _userId!,
        limit: 15,
        types: [RecommendationType.content_based],
      );

      final timeRecs = await _recommendationService.getPersonalizedRecommendations(
        _userId!,
        limit: 15,
        types: [RecommendationType.time_based],
      );

      final locationRecs = await _recommendationService.getPersonalizedRecommendations(
        _userId!,
        limit: 15,
        types: [RecommendationType.location_based],
      );

      setState(() {
        _allRecommendations = allRecs;
        _businessRecommendations = businessRecs;
        _timeRecommendations = timeRecs;
        _locationRecommendations = locationRecs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar recomendaciones: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomendaciones IA'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Todas las recomendaciones
                    _buildAllRecommendationsTab(),
                    
                    // Recomendaciones de negocios
                    _buildBusinessRecommendationsTab(),
                    
                    // Recomendaciones basadas en tiempo
                    _buildTimeRecommendationsTab(),
                    
                    // Recomendaciones basadas en ubicación
                    _buildLocationRecommendationsTab(),
                  ],
                ),
    );
  }

  Widget _buildAllRecommendationsTab() {
    if (_allRecommendations.isEmpty) {
      return const Center(
        child: Text(
          'No hay recomendaciones disponibles',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Calcular estadísticas
    final avgScore = _allRecommendations.isNotEmpty
        ? _allRecommendations.map((r) => r.score).reduce((a, b) => a + b) / _allRecommendations.length
        : 0.0;

    return Column(
      children: [
        // Header con estadísticas
        _buildStatsHeader(),
        const SizedBox(height: 16),
        
        // Recomendaciones principales
        _buildMainRecommendations(),
        const SizedBox(height: 24),
        
        // Lista detallada
        ..._allRecommendations.map((recommendation) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DetailedRecommendationCard(
            recommendation: recommendation,
            userId: _userId!,
            onBusinessTap: _onBusinessTap,
            onFeedback: _onFeedback,
          ),
        )),
        
        // Espacio al final
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildMainRecommendations() {
    if (_allRecommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    // Mostrar las primeras 3 recomendaciones como principales
    final topRecommendations = _allRecommendations.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recomendaciones Principales',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: topRecommendations.length,
            itemBuilder: (context, index) {
              final recommendation = topRecommendations[index];
              return Container(
                width: 300,
                margin: const EdgeInsets.only(right: 12),
                child: DetailedRecommendationCard(
                  recommendation: recommendation,
                  userId: _userId!,
                  onBusinessTap: _onBusinessTap,
                  onFeedback: _onFeedback,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessRecommendationsTab() {
    if (_businessRecommendations.isEmpty) {
      return const Center(
        child: Text(
          'No hay recomendaciones de negocios disponibles',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        // Header con estadísticas
        _buildStatsHeader(),
        const SizedBox(height: 16),
        
        // Lista de recomendaciones de negocios
        ..._businessRecommendations.map((recommendation) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DetailedRecommendationCard(
            recommendation: recommendation,
            userId: _userId!,
            onBusinessTap: _onBusinessTap,
            onFeedback: _onFeedback,
          ),
        )),
        
        // Espacio al final
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildTimeRecommendationsTab() {
    if (_timeRecommendations.isEmpty) {
      return const Center(
        child: Text(
          'No hay recomendaciones basadas en tiempo disponibles',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        // Header con estadísticas
        _buildStatsHeader(),
        const SizedBox(height: 16),
        
        // Lista de recomendaciones de tiempo
        ..._timeRecommendations.map((recommendation) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DetailedRecommendationCard(
            recommendation: recommendation,
            userId: _userId!,
            onBusinessTap: _onBusinessTap,
            onFeedback: _onFeedback,
          ),
        )),
        
        // Espacio al final
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildLocationRecommendationsTab() {
    if (_locationRecommendations.isEmpty) {
      return const Center(
        child: Text(
          'No hay recomendaciones basadas en ubicación disponibles',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        // Header con estadísticas
        _buildStatsHeader(),
        const SizedBox(height: 16),
        
        // Lista de recomendaciones de ubicación
        ..._locationRecommendations.map((recommendation) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DetailedRecommendationCard(
            recommendation: recommendation,
            userId: _userId!,
            onBusinessTap: _onBusinessTap,
            onFeedback: _onFeedback,
          ),
        )),
        
        // Espacio al final
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple, Colors.purple.withOpacity(0.8)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estadísticas de IA',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatItem('Total', '${_allRecommendations.length}', Icons.list),
                    const SizedBox(width: 16),
                    _buildStatItem('Tipos de IA', '4', Icons.auto_awesome),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.trending_up,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _onBusinessTap(String businessId) {
    // Navegar a detalles del negocio
    Navigator.pushNamed(context, '/business_detail', arguments: {
      'businessId': businessId,
    });
  }

  void _onFeedback(bool isPositive) {
    // Implementar feedback para mejorar recomendaciones
    _showFeedbackSnackBar(isPositive);
  }

  void _showFeedbackSnackBar(bool isPositive) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPositive 
              ? '¡Gracias! Tu feedback ayudará a mejorar las recomendaciones.'
              : 'Gracias por tu feedback. Lo usaremos para mejorar.',
        ),
        backgroundColor: isPositive ? Colors.green : Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
