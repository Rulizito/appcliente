// ============================================================================
// services/search_history_service.dart
// Servicio para guardar y recuperar historial de búsquedas
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SearchHistoryService {
  // Singleton para que solo haya una instancia
  static final SearchHistoryService _instance = SearchHistoryService._internal();
  factory SearchHistoryService() => _instance;
  SearchHistoryService._internal();

  // Clave para guardar en SharedPreferences
  static const String _key = 'search_history';
  static const int _maxHistory = 10; // Máximo 10 búsquedas guardadas

  // ============================================================================
  // GUARDAR BÚSQUEDA
  // ============================================================================
  Future<void> saveSearch(String query) async {
    try {
      if (query.trim().isEmpty) return; // No guardar búsquedas vacías

      final prefs = await SharedPreferences.getInstance();
      
      // Obtener historial actual
      List<String> history = await getSearchHistory();
      
      // Si la búsqueda ya existe, eliminarla (para ponerla al principio)
      history.remove(query.trim());
      
      // Agregar al principio
      history.insert(0, query.trim());
      
      // Mantener solo las últimas 10
      if (history.length > _maxHistory) {
        history = history.sublist(0, _maxHistory);
      }
      
      // Guardar como JSON
      await prefs.setString(_key, jsonEncode(history));
      
      print('✅ Búsqueda guardada: $query');
    } catch (e) {
      print('❌ Error al guardar búsqueda: $e');
    }
  }

  // ============================================================================
  // OBTENER HISTORIAL
  // ============================================================================
  Future<List<String>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString(_key);
      
      if (historyJson == null || historyJson.isEmpty) {
        return [];
      }
      
      // Decodificar JSON
      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded.map((item) => item.toString()).toList();
      
    } catch (e) {
      print('❌ Error al cargar historial: $e');
      return [];
    }
  }

  // ============================================================================
  // ELIMINAR UNA BÚSQUEDA ESPECÍFICA
  // ============================================================================
  Future<void> removeSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = await getSearchHistory();
      
      history.remove(query);
      
      await prefs.setString(_key, jsonEncode(history));
      print('✅ Búsqueda eliminada: $query');
    } catch (e) {
      print('❌ Error al eliminar búsqueda: $e');
    }
  }

  // ============================================================================
  // LIMPIAR TODO EL HISTORIAL
  // ============================================================================
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      print('✅ Historial de búsquedas limpiado');
    } catch (e) {
      print('❌ Error al limpiar historial: $e');
    }
  }

  // ============================================================================
  // VERIFICAR SI HAY HISTORIAL
  // ============================================================================
  Future<bool> hasHistory() async {
    final history = await getSearchHistory();
    return history.isNotEmpty;
  }
}