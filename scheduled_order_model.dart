import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScheduledOrder {
  final String id;
  final String userId;
  final String businessId;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double tip;
  final double total;
  final String deliveryAddress;
  final String paymentMethod;
  final String? paymentType;
  final DateTime scheduledDateTime;
  final DateTime createdAt;
  final ScheduledOrderStatus status;
  final String? notes;
  final Map<String, dynamic>? preferences;
  final List<String>? reminderTimes;
  final bool isRecurring;
  final RecurrencePattern? recurrencePattern;
  final DateTime? lastReminderSent;
  final int estimatedPreparationTime;
  final int estimatedDeliveryTime;
  final String? specialInstructions;

  ScheduledOrder({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    this.tip = 0,
    required this.total,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.paymentType,
    required this.scheduledDateTime,
    required this.createdAt,
    this.status = ScheduledOrderStatus.pending,
    this.notes,
    this.preferences,
    this.reminderTimes,
    this.isRecurring = false,
    this.recurrencePattern,
    this.lastReminderSent,
    this.estimatedPreparationTime = 15,
    this.estimatedDeliveryTime = 30,
    this.specialInstructions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'businessId': businessId,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'tip': tip,
      'total': total,
      'deliveryAddress': deliveryAddress,
      'paymentMethod': paymentMethod,
      'paymentType': paymentType,
      'scheduledDateTime': Timestamp.fromDate(scheduledDateTime),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
      'notes': notes,
      'preferences': preferences,
      'reminderTimes': reminderTimes,
      'isRecurring': isRecurring,
      'recurrencePattern': recurrencePattern?.toMap(),
      'lastReminderSent': lastReminderSent != null 
          ? Timestamp.fromDate(lastReminderSent!) 
          : null,
      'estimatedPreparationTime': estimatedPreparationTime,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'specialInstructions': specialInstructions,
    };
  }

  factory ScheduledOrder.fromMap(Map<String, dynamic> map) {
    return ScheduledOrder(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      businessId: map['businessId'] ?? '',
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList() ?? [],
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      deliveryFee: (map['deliveryFee'] ?? 0).toDouble(),
      tip: (map['tip'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      deliveryAddress: map['deliveryAddress'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      paymentType: map['paymentType'],
      scheduledDateTime: (map['scheduledDateTime'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: ScheduledOrderStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => ScheduledOrderStatus.pending,
      ),
      notes: map['notes'],
      preferences: map['preferences'],
      reminderTimes: List<String>.from(map['reminderTimes'] ?? []),
      isRecurring: map['isRecurring'] ?? false,
      recurrencePattern: map['recurrencePattern'] != null
          ? RecurrencePattern.fromMap(map['recurrencePattern'])
          : null,
      lastReminderSent: map['lastReminderSent'] != null
          ? (map['lastReminderSent'] as Timestamp).toDate()
          : null,
      estimatedPreparationTime: map['estimatedPreparationTime'] ?? 15,
      estimatedDeliveryTime: map['estimatedDeliveryTime'] ?? 30,
      specialInstructions: map['specialInstructions'],
    );
  }

  ScheduledOrder copyWith({
    String? id,
    String? userId,
    String? businessId,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    double? tip,
    double? total,
    String? deliveryAddress,
    String? paymentMethod,
    String? paymentType,
    DateTime? scheduledDateTime,
    DateTime? createdAt,
    ScheduledOrderStatus? status,
    String? notes,
    Map<String, dynamic>? preferences,
    List<String>? reminderTimes,
    bool? isRecurring,
    RecurrencePattern? recurrencePattern,
    DateTime? lastReminderSent,
    int? estimatedPreparationTime,
    int? estimatedDeliveryTime,
    String? specialInstructions,
  }) {
    return ScheduledOrder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      businessId: businessId ?? this.businessId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      tip: tip ?? this.tip,
      total: total ?? this.total,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentType: paymentType ?? this.paymentType,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      preferences: preferences ?? this.preferences,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      lastReminderSent: lastReminderSent ?? this.lastReminderSent,
      estimatedPreparationTime: estimatedPreparationTime ?? this.estimatedPreparationTime,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  String get statusText {
    switch (status) {
      case ScheduledOrderStatus.pending:
        return 'Pendiente';
      case ScheduledOrderStatus.confirmed:
        return 'Confirmado';
      case ScheduledOrderStatus.preparing:
        return 'Preparando';
      case ScheduledOrderStatus.ready:
        return 'Listo';
      case ScheduledOrderStatus.on_way:
        return 'En camino';
      case ScheduledOrderStatus.delivered:
        return 'Entregado';
      case ScheduledOrderStatus.cancelled:
        return 'Cancelado';
      case ScheduledOrderStatus.no_show:
        return 'No se presentó';
      default:
        return 'Desconocido';
    }
  }

  bool get isOverdue {
    return DateTime.now().isAfter(scheduledDateTime) && 
           status != ScheduledOrderStatus.delivered && 
           status != ScheduledOrderStatus.cancelled;
  }

  Duration get timeUntilScheduled {
    return scheduledDateTime.difference(DateTime.now());
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final Map<String, dynamic>? customizations;
  final String? notes;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.customizations,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'customizations': customizations,
      'notes': notes,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      customizations: map['customizations'],
      notes: map['notes'],
    );
  }
}

enum ScheduledOrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  on_way,
  delivered,
  cancelled,
  no_show,
}

class RecurrencePattern {
  final RecurrenceType type;
  final int interval;
  final List<int>? daysOfWeek; // 1-7 (Lunes-Domingo)
  final List<int>? daysOfMonth; // 1-31
  final DateTime? endDate;
  final int? maxOccurrences;

  RecurrencePattern({
    required this.type,
    required this.interval,
    this.daysOfWeek,
    this.daysOfMonth,
    this.endDate,
    this.maxOccurrences,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'interval': interval,
      'daysOfWeek': daysOfWeek,
      'daysOfMonth': daysOfMonth,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'maxOccurrences': maxOccurrences,
    };
  }

  factory RecurrencePattern.fromMap(Map<String, dynamic> map) {
    return RecurrencePattern(
      type: RecurrenceType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => RecurrenceType.daily,
      ),
      interval: map['interval'] ?? 1,
      daysOfWeek: map['daysOfWeek'] != null 
          ? List<int>.from(map['daysOfWeek']) 
          : null,
      daysOfMonth: map['daysOfMonth'] != null 
          ? List<int>.from(map['daysOfMonth']) 
          : null,
      endDate: map['endDate'] != null 
          ? (map['endDate'] as Timestamp).toDate() 
          : null,
      maxOccurrences: map['maxOccurrences'],
    );
  }

  DateTime? getNextOccurrence(DateTime fromDate) {
    DateTime nextDate = fromDate;

    switch (type) {
      case RecurrenceType.daily:
        nextDate = fromDate.add(Duration(days: interval));
        break;
      case RecurrenceType.weekly:
        if (daysOfWeek != null && daysOfWeek!.isNotEmpty) {
          nextDate = _getNextWeeklyDate(fromDate);
        } else {
          nextDate = fromDate.add(Duration(days: 7 * interval));
        }
        break;
      case RecurrenceType.monthly:
        if (daysOfMonth != null && daysOfMonth!.isNotEmpty) {
          nextDate = _getNextMonthlyDate(fromDate);
        } else {
          nextDate = DateTime(fromDate.year, fromDate.month + interval, fromDate.day);
        }
        break;
      case RecurrenceType.yearly:
        nextDate = DateTime(fromDate.year + interval, fromDate.month, fromDate.day);
        break;
    }

    // Verificar si no excede la fecha de fin
    if (endDate != null && nextDate.isAfter(endDate!)) {
      return null;
    }

    return nextDate;
  }

  DateTime _getNextWeeklyDate(DateTime fromDate) {
    DateTime nextDate = fromDate;
    int currentDay = fromDate.weekday; // 1-7 (Lunes-Domingo)
    
    // Encontrar el próximo día de la semana válido
    for (int i = 1; i <= 7; i++) {
      int checkDay = (currentDay - 1 + i) % 7 + 1;
      if (daysOfWeek!.contains(checkDay)) {
        nextDate = fromDate.add(Duration(days: i));
        break;
      }
    }

    // Si el intervalo es mayor a 1, ajustar según el intervalo
    if (interval > 1) {
      nextDate = nextDate.add(Duration(days: 7 * (interval - 1)));
    }

    return nextDate;
  }

  DateTime _getNextMonthlyDate(DateTime fromDate) {
    DateTime nextDate = fromDate;
    int currentDay = fromDate.day;
    
    // Encontrar el próximo día del mes válido
    daysOfMonth!.sort();
    for (int day in daysOfMonth!) {
      if (day > currentDay) {
        nextDate = DateTime(fromDate.year, fromDate.month, day);
        break;
      }
    }
    
    // Si no encontramos un día en el mes actual, vamos al siguiente mes
    if (nextDate.day == currentDay) {
      nextDate = DateTime(fromDate.year, fromDate.month + 1, daysOfMonth!.first);
    }

    // Si el intervalo es mayor a 1, ajustar según el intervalo
    if (interval > 1) {
      int monthsToAdd = interval - 1;
      nextDate = DateTime(nextDate.year, nextDate.month + monthsToAdd, nextDate.day);
    }

    return nextDate;
  }
}

enum RecurrenceType {
  daily,
  weekly,
  monthly,
  yearly,
}

class BusinessAvailability {
  final String businessId;
  final Map<int, List<TimeSlot>> weeklySchedule; // Día 1-7 (Lunes-Domingo)
  final List<DateTime> holidays;
  final List<DateTime> specialDates;
  final int maxOrdersPerSlot;
  final int minPreparationTime;
  final int maxPreparationTime;
  final bool acceptsScheduledOrders;
  final TimeSlot? businessHours;

  BusinessAvailability({
    required this.businessId,
    required this.weeklySchedule,
    this.holidays = const [],
    this.specialDates = const [],
    this.maxOrdersPerSlot = 10,
    this.minPreparationTime = 15,
    this.maxPreparationTime = 120,
    this.acceptsScheduledOrders = true,
    this.businessHours,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'weeklySchedule': weeklySchedule.map((key, value) => 
        MapEntry(key.toString(), value.map((slot) => slot.toMap()).toList())),
      'holidays': holidays.map((date) => Timestamp.fromDate(date)).toList(),
      'specialDates': specialDates.map((date) => Timestamp.fromDate(date)).toList(),
      'maxOrdersPerSlot': maxOrdersPerSlot,
      'minPreparationTime': minPreparationTime,
      'maxPreparationTime': maxPreparationTime,
      'acceptsScheduledOrders': acceptsScheduledOrders,
      'businessHours': businessHours?.toMap(),
    };
  }

  factory BusinessAvailability.fromMap(Map<String, dynamic> map) {
    return BusinessAvailability(
      businessId: map['businessId'] ?? '',
      weeklySchedule: (map['weeklySchedule'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          int.parse(key),
          (value as List<dynamic>).map((slot) => TimeSlot.fromMap(slot)).toList(),
        ),
      ),
      holidays: (map['holidays'] as List<dynamic>?)
          ?.map((date) => (date as Timestamp).toDate())
          .toList() ?? [],
      specialDates: (map['specialDates'] as List<dynamic>?)
          ?.map((date) => (date as Timestamp).toDate())
          .toList() ?? [],
      maxOrdersPerSlot: map['maxOrdersPerSlot'] ?? 10,
      minPreparationTime: map['minPreparationTime'] ?? 15,
      maxPreparationTime: map['maxPreparationTime'] ?? 120,
      acceptsScheduledOrders: map['acceptsScheduledOrders'] ?? true,
      businessHours: map['businessHours'] != null 
          ? TimeSlot.fromMap(map['businessHours'])
          : null,
    );
  }

  bool isAvailable(DateTime dateTime) {
    if (!acceptsScheduledOrders) return false;
    
    // Verificar si es día festivo
    if (holidays.any((holiday) => 
        holiday.year == dateTime.year && 
        holiday.month == dateTime.month && 
        holiday.day == dateTime.day)) {
      return false;
    }

    // Verificar horario semanal
    final dayOfWeek = dateTime.weekday; // 1-7 (Lunes-Domingo)
    final timeSlots = weeklySchedule[dayOfWeek] ?? [];
    
    if (timeSlots.isEmpty) return false;
    
    final currentTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
    
    return timeSlots.any((slot) => 
        slot.startTime.hour <= currentTime.hour && 
        slot.endTime.hour >= currentTime.hour &&
        (slot.startTime.hour < currentTime.hour || 
         slot.startTime.minute <= currentTime.minute) &&
        (slot.endTime.hour > currentTime.hour || 
         slot.endTime.minute >= currentTime.minute));
  }

  List<TimeSlot> getAvailableSlots(DateTime date) {
    final dayOfWeek = date.weekday;
    return weeklySchedule[dayOfWeek] ?? [];
  }
}

class TimeSlot {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int maxOrders;
  final int currentOrders;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.maxOrders = 10,
    this.currentOrders = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'maxOrders': maxOrders,
      'currentOrders': currentOrders,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    final startTimeStr = map['startTime'] as String;
    final endTimeStr = map['endTime'] as String;
    
    final startTimeParts = startTimeStr.split(':');
    final endTimeParts = endTimeStr.split(':');
    
    return TimeSlot(
      startTime: TimeOfDay(
        hour: int.parse(startTimeParts[0]),
        minute: int.parse(startTimeParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endTimeParts[0]),
        minute: int.parse(endTimeParts[1]),
      ),
      maxOrders: map['maxOrders'] ?? 10,
      currentOrders: map['currentOrders'] ?? 0,
    );
  }

  bool get isAvailable => currentOrders < maxOrders;

  String get formattedTime => 
      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - '
      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
}
