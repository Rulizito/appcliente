// ============================================================================
// services/location_service.dart
// ============================================================================

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Verificar si los servicios de ubicación están habilitados
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Verificar permisos de ubicación
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  // Solicitar permisos de ubicación
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  // Obtener la ubicación actual del usuario
  Future<Position?> getCurrentLocation() async {
    try {
      // Verificar si el servicio está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Servicio de ubicación deshabilitado');
        return null;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ Permisos de ubicación denegados');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Permisos de ubicación denegados permanentemente');
        return null;
      }

      // Obtener ubicación actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('✅ Ubicación obtenida: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error al obtener ubicación: $e');
      return null;
    }
  }

  // Calcular distancia entre dos puntos (en kilómetros)
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convertir a km
  }

  // Obtener dirección a partir de coordenadas
  Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) return null;

      Placemark place = placemarks[0];
      
      String address = '';
      if (place.street != null && place.street!.isNotEmpty) {
        address += place.street!;
      }
      if (place.subLocality != null && place.subLocality!.isNotEmpty) {
        if (address.isNotEmpty) address += ', ';
        address += place.subLocality!;
      }
      if (place.locality != null && place.locality!.isNotEmpty) {
        if (address.isNotEmpty) address += ', ';
        address += place.locality!;
      }

      return address.isNotEmpty ? address : null;
    } catch (e) {
      print('❌ Error al obtener dirección: $e');
      return null;
    }
  }

  // Obtener coordenadas a partir de una dirección
  Future<Location?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isEmpty) return null;
      return locations[0];
    } catch (e) {
      print('❌ Error al obtener coordenadas: $e');
      return null;
    }
  }

  // Formatear distancia para mostrar
  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)} m';
    } else {
      return '${distanceInKm.toStringAsFixed(1)} km';
    }
  }

  // Abrir configuración de ubicación
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  // Abrir configuración de permisos de la app
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}