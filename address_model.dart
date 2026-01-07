// ============================================================================
// models/address_model.dart
// ============================================================================

class Address {
  final String id;
  final String street;
  final String number;
  final String? apartment;
  final String city;
  final String? reference;
  final bool isDefault;
  final DateTime? lastUsed; // Nueva: última vez que se usó
  final int usageCount; // Nueva: cuántas veces se usó

  Address({
    required this.id,
    required this.street,
    required this.number,
    this.apartment,
    required this.city,
    this.reference,
    this.isDefault = false,
    this.lastUsed,
    this.usageCount = 0,
  });

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'street': street,
      'number': number,
      'apartment': apartment,
      'city': city,
      'reference': reference,
      'isDefault': isDefault,
      'lastUsed': lastUsed?.toIso8601String(),
      'usageCount': usageCount,
    };
  }

  // Crear desde Map de Firestore
  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'] ?? '',
      street: map['street'] ?? '',
      number: map['number'] ?? '',
      apartment: map['apartment'],
      city: map['city'] ?? '',
      reference: map['reference'],
      isDefault: map['isDefault'] ?? false,
      lastUsed: map['lastUsed'] != null 
          ? DateTime.parse(map['lastUsed']) 
          : null,
      usageCount: map['usageCount'] ?? 0,
    );
  }

  // Dirección completa como string
  String get fullAddress {
    String address = '$street $number';
    if (apartment != null && apartment!.isNotEmpty) {
      address += ', Depto $apartment';
    }
    address += ', $city';
    return address;
  }

  // Crear copia con campos actualizados
  Address copyWith({
    String? id,
    String? street,
    String? number,
    String? apartment,
    String? city,
    String? reference,
    bool? isDefault,
    DateTime? lastUsed,
    int? usageCount,
  }) {
    return Address(
      id: id ?? this.id,
      street: street ?? this.street,
      number: number ?? this.number,
      apartment: apartment ?? this.apartment,
      city: city ?? this.city,
      reference: reference ?? this.reference,
      isDefault: isDefault ?? this.isDefault,
      lastUsed: lastUsed ?? this.lastUsed,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}