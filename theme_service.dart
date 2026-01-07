// ============================================================================
// services/theme_service.dart - Servicio de Tema Oscuro MEJORADO
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // Cargar preferencia guardada
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      notifyListeners();
      print('🌙 Tema cargado: ${_isDarkMode ? "Oscuro" : "Claro"}');
    } catch (e) {
      print('Error al cargar tema: $e');
    }
  }

  // Cambiar tema
  Future<void> toggleTheme() async {
    try {
      _isDarkMode = !_isDarkMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      notifyListeners();
      print('🌙 Tema cambiado a: ${_isDarkMode ? "Oscuro" : "Claro"}');
    } catch (e) {
      print('Error al guardar tema: $e');
    }
  }

  // Establecer tema específico
  Future<void> setTheme(bool isDark) async {
    try {
      _isDarkMode = isDark;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
      notifyListeners();
    } catch (e) {
      print('Error al establecer tema: $e');
    }
  }

  // Tema claro
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Colores principales
      primarySwatch: Colors.red,
      primaryColor: Colors.red,
      scaffoldBackgroundColor: Colors.grey[50],
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Botones
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.red,
        ),
      ),
      
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
      ),
      
      // Text
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.grey[900]),
        bodyMedium: TextStyle(color: Colors.grey[800]),
      ),
    );
  }

  // ============================================================================
  // TEMA OSCURO MEJORADO - SÚPER VISIBLE Y FACHERO 😎
  // ============================================================================
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Colores principales
      primarySwatch: Colors.red,
      primaryColor: const Color(0xFFFF5252), // Rojo más brillante
      scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Negro profundo
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A), // Gris muy oscuro
        foregroundColor: Color(0xFFE0E0E0), // Gris claro en vez de blanco
        elevation: 0,
        centerTitle: false,
      ),
      
      // Cards - MUY VISIBLE
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E), // Gris oscuro para cards
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Botones - MUY VISIBLE
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5252), // Rojo brillante
          foregroundColor: const Color(0xFFE0E0E0), // Gris claro en vez de blanco
          elevation: 4,
          shadowColor: const Color(0xFFFF5252).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF5252),
          side: const BorderSide(color: Color(0xFFFF5252), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFF5252),
        ),
      ),
      
      // Inputs - MUY VISIBLE
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C), // Fondo gris oscuro
        labelStyle: const TextStyle(color: Color(0xFFB0B0B0)), // Gris claro para labels
        hintStyle: const TextStyle(color: Color(0xFF707070)), // Gris medio para hints
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 2),
        ),
      ),
      
      // Bottom Navigation - MUY VISIBLE
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1A1A),
        selectedItemColor: Color(0xFFFF5252), // Rojo brillante
        unselectedItemColor: Color(0xFF808080), // Gris claro
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // Text - MUY LEGIBLE (SIN BLANCO)
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Color(0xFFE0E0E0)), // Gris muy claro
        displayMedium: TextStyle(color: Color(0xFFE0E0E0)),
        displaySmall: TextStyle(color: Color(0xFFE0E0E0)),
        headlineLarge: TextStyle(color: Color(0xFFE0E0E0)),
        headlineMedium: TextStyle(color: Color(0xFFE0E0E0)),
        headlineSmall: TextStyle(color: Color(0xFFE0E0E0)),
        titleLarge: TextStyle(color: Color(0xFFE0E0E0)),
        titleMedium: TextStyle(color: Color(0xFFE0E0E0)),
        titleSmall: TextStyle(color: Color(0xFFD0D0D0)),
        bodyLarge: TextStyle(color: Color(0xFFD0D0D0)), // Gris claro
        bodyMedium: TextStyle(color: Color(0xFFB0B0B0)), // Gris medio
        bodySmall: TextStyle(color: Color(0xFF909090)),
        labelLarge: TextStyle(color: Color(0xFFD0D0D0)),
        labelMedium: TextStyle(color: Color(0xFFB0B0B0)),
        labelSmall: TextStyle(color: Color(0xFF909090)),
      ),
      
      // Divider - VISIBLE
      dividerColor: const Color(0xFF404040),
      
      // Icon - VISIBLE
      iconTheme: const IconThemeData(
        color: Color(0xFFB0B0B0),
      ),
      
      // ListTile - VISIBLE
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFFE0E0E0),
        iconColor: Color(0xFFB0B0B0),
      ),
      
      // Dialog - VISIBLE
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        titleTextStyle: const TextStyle(
          color: Color(0xFFE0E0E0), // Gris claro en vez de blanco
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFFB0B0B0),
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Colores de superficie (SIN BLANCO)
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF5252),
        secondary: Color(0xFFFF5252),
        surface: Color(0xFF1E1E1E),
        background: Color(0xFF0A0A0A),
        error: Color(0xFFCF6679),
        onPrimary: Color(0xFFE0E0E0), // Gris claro en vez de blanco
        onSecondary: Color(0xFFE0E0E0), // Gris claro en vez de blanco
        onSurface: Color(0xFFE0E0E0),
        onBackground: Color(0xFFE0E0E0),
        onError: Color(0xFFE0E0E0), // Gris claro en vez de blanco
        brightness: Brightness.dark,
      ),
    );
  }
}