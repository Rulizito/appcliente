// ============================================================================
// services/advanced_search_service.dart - Servicio de Búsqueda Avanzada
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_model.dart';

// Opciones de filtro - Movidas fuera de la clase
class SearchFilters {
  String? query;
  String? category;
  List<String>? categories;
  double? minRating;
  double? maxPrice;
  bool? freeDelivery;
  bool? openNow;
  String? sortBy; // 'rating', 'distance', 'delivery_fee', 'name'
  bool ascending;
  double? userLatitude;
  double? userLongitude;
  double? maxDistance; // en km
  List<String>? paymentMethods;
  List<String>? tags;

  SearchFilters({
    this.query,
    this.category,
    this.categories,
    this.minRating,
    this.maxPrice,
    this.freeDelivery,
    this.openNow,
    this.sortBy = 'rating',
    this.ascending = false,
    this.userLatitude,
    this.userLongitude,
    this.maxDistance,
    this.paymentMethods,
    this.tags,
  });

  Map<String, dynamic> toMap() {
    return {
      'query': query,
      'category': category,
      'categories': categories,
      'minRating': minRating,
      'maxPrice': maxPrice,
      'freeDelivery': freeDelivery,
      'openNow': openNow,
      'sortBy': sortBy,
      'ascending': ascending,
      'userLatitude': userLatitude,
      'userLongitude': userLongitude,
      'maxDistance': maxDistance,
      'paymentMethods': paymentMethods,
      'tags': tags,
    };
  }
}

class AdvancedSearchService {
  static final AdvancedSearchService _instance = AdvancedSearchService._internal();
  factory AdvancedSearchService() => _instance;
  AdvancedSearchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Búsqueda avanzada con filtros
  Future<List<Business>> searchBusinesses(SearchFilters filters) async {
    try {
      Query query = _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true);

      // Aplicar filtros básicos
      if (filters.category != null) {
        query = query.where('category', isEqualTo: filters.category);
      }

      if (filters.freeDelivery != null) {
        query = query.where('freeDelivery', isEqualTo: filters.freeDelivery);
      }

      if (filters.minRating != null) {
        query = query.where('rating', isGreaterThanOrEqualTo: filters.minRating);
      }

      if (filters.maxPrice != null) {
        query = query.where('averagePrice', isLessThanOrEqualTo: filters.maxPrice);
      }

      // Obtener resultados
      final snapshot = await query.get();
      List<Business> businesses = snapshot.docs
          .map((doc) => Business.fromFirestore(doc))
          .toList();

      // Aplicar filtros complejos (que requieren procesamiento posterior)
      if (filters.categories != null && filters.categories!.isNotEmpty) {
        businesses = businesses.where((business) {
          return filters.categories!.any((category) =>
              business.categories.contains(category) ||
              business.category == category);
        }).toList();
      }

      if (filters.paymentMethods != null && filters.paymentMethods!.isNotEmpty) {
        businesses = businesses.where((business) {
          return filters.paymentMethods!.any((method) =>
              business.paymentMethods.contains(method));
        }).toList();
      }

      if (filters.tags != null && filters.tags!.isNotEmpty) {
        businesses = businesses.where((business) {
          return filters.tags!.any((tag) =>
              business.tags.contains(tag) ||
              business.name.toLowerCase().contains(tag.toLowerCase()) ||
              business.description.toLowerCase().contains(tag.toLowerCase()));
        }).toList();
      }

      if (filters.openNow == true) {
        businesses = businesses.where((business) => business.isOpenNow).toList();
      }

      if (filters.userLatitude != null && 
          filters.userLongitude != null && 
          filters.maxDistance != null) {
        businesses = businesses.where((business) {
          final distance = business.distanceFrom(
            filters.userLatitude!,
            filters.userLongitude!,
          );
          return distance <= filters.maxDistance!;
        }).toList();
      }

      // Búsqueda por texto
      if (filters.query != null && filters.query!.isNotEmpty) {
        final searchQuery = filters.query!.toLowerCase();
        businesses = businesses.where((business) {
          return business.name.toLowerCase().contains(searchQuery) ||
              business.description.toLowerCase().contains(searchQuery) ||
              business.category.toLowerCase().contains(searchQuery) ||
              business.tags.any((tag) => tag.toLowerCase().contains(searchQuery));
        }).toList();
      }

      // Ordenar resultados
      _sortBusinesses(businesses, filters);

      return businesses;
    } catch (e) {
      print('Error en búsqueda avanzada: $e');
      return [];
    }
  }

  // Ordenar negocios según criterios
  void _sortBusinesses(List<Business> businesses, SearchFilters filters) {
    businesses.sort((a, b) {
      int result = 0;

      switch (filters.sortBy) {
        case 'rating':
          result = a.rating.compareTo(b.rating);
          break;
        case 'name':
          result = a.name.compareTo(b.name);
          break;
        case 'delivery_fee':
          result = a.deliveryFee.compareTo(b.deliveryFee);
          break;
        case 'distance':
          if (filters.userLatitude != null && filters.userLongitude != null) {
            final distanceA = a.distanceFrom(
              filters.userLatitude!,
              filters.userLongitude!,
            );
            final distanceB = b.distanceFrom(
              filters.userLatitude!,
              filters.userLongitude!,
            );
            result = distanceA.compareTo(distanceB);
          }
          break;
        case 'review_count':
          result = a.reviewCount.compareTo(b.reviewCount);
          break;
        case 'price':
          result = a.averagePrice.compareTo(b.averagePrice);
          break;
        default:
          result = a.rating.compareTo(b.rating);
      }

      return filters.ascending ? result : -result;
    });
  }

  // Obtener categorías disponibles
  Future<List<String>> getAvailableCategories() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .get();

      Set<String> categories = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['category'] != null) {
          categories.add(data['category'] as String);
        }
        if (data['categories'] != null) {
          categories.addAll(List<String>.from(data['categories']));
        }
      }

      return categories.toList()..sort();
    } catch (e) {
      print('Error obteniendo categorías: $e');
      return [];
    }
  }

  // Obtener tags populares
  Future<List<String>> getPopularTags() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .get();

      Map<String, int> tagCounts = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['tags'] != null) {
          final tags = List<String>.from(data['tags']);
          for (var tag in tags) {
            tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
          }
        }
      }

      // Ordenar por frecuencia y devolver los más populares
      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTags.take(20).map((e) => e.key).toList();
    } catch (e) {
      print('Error obteniendo tags populares: $e');
      return [];
    }
  }

  // Obtener métodos de pago disponibles
  Future<List<String>> getAvailablePaymentMethods() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .get();

      Set<String> paymentMethods = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['paymentMethods'] != null) {
          paymentMethods.addAll(List<String>.from(data['paymentMethods']));
        }
      }

      return paymentMethods.toList()..sort();
    } catch (e) {
      print('Error obteniendo métodos de pago: $e');
      return [];
    }
  }

  // Búsqueda por sugerencias (autocomplete)
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.length < 2) return [];

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .get();

      Set<String> suggestions = {};
      final searchQuery = query.toLowerCase();

      for (var doc in snapshot.docs) {
        final business = Business.fromFirestore(doc);
        
        // Sugerir nombres que coincidan
        if (business.name.toLowerCase().startsWith(searchQuery)) {
          suggestions.add(business.name);
        }
        
        // Sugerir categorías que coincidan
        if (business.category.toLowerCase().startsWith(searchQuery)) {
          suggestions.add(business.category);
        }
        
        // Sugerir tags que coincidan
        for (var tag in business.tags) {
          if (tag.toLowerCase().startsWith(searchQuery)) {
            suggestions.add(tag);
          }
        }
      }

      return suggestions.take(10).toList()..sort();
    } catch (e) {
      print('Error obteniendo sugerencias: $e');
      return [];
    }
  }

  // Búsqueda geográfica (negocios cercanos)
  Future<List<Business>> findNearbyBusinesses(
    double latitude,
    double longitude, {
    double radius = 5.0, // km
    String? category,
  }) async {
    try {
      final filters = SearchFilters(
        userLatitude: latitude,
        userLongitude: longitude,
        maxDistance: radius,
        category: category,
        sortBy: 'distance',
        ascending: true,
      );

      return await searchBusinesses(filters);
    } catch (e) {
      print('Error buscando negocios cercanos: $e');
      return [];
    }
  }
}
