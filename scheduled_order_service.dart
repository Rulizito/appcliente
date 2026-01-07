import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scheduled_order_model.dart';
import '../models/order_model.dart' as order_model;
import '../models/business_model.dart' as business_model;
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduledOrderService {
  static final ScheduledOrderService _instance = ScheduledOrderService._internal();
  factory ScheduledOrderService() => _instance;
  ScheduledOrderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Streams para actualizaciones en tiempo real
  Stream<List<ScheduledOrder>> getUserScheduledOrders(String userId) {
    return _firestore
        .collection('scheduled_orders')
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledDateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ScheduledOrder.fromMap(doc.data()))
            .toList());
  }

  Stream<List<ScheduledOrder>> getBusinessScheduledOrders(String businessId) {
    return _firestore
        .collection('scheduled_orders')
        .where('businessId', isEqualTo: businessId)
        .orderBy('scheduledDateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ScheduledOrder.fromMap(doc.data()))
            .toList());
  }

  // Crear pedido programado
  Future<ScheduledOrder> createScheduledOrder({
    required String businessId,
    required List<OrderItem> items,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required String deliveryAddress,
    required String paymentMethod,
    required DateTime scheduledDateTime,
    String? notes,
    Map<String, dynamic>? preferences,
    List<String>? reminderTimes,
    bool isRecurring = false,
    RecurrencePattern? recurrencePattern,
    String? specialInstructions,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Verificar disponibilidad del negocio
      final availability = await getBusinessAvailability(businessId);
      if (!availability.isAvailable(scheduledDateTime)) {
        throw Exception('El negocio no está disponible en la fecha y hora seleccionadas');
      }

      // Verificar capacidad del horario
      final availableSlots = availability.getAvailableSlots(scheduledDateTime);
      final currentTime = TimeOfDay(
        hour: scheduledDateTime.hour,
        minute: scheduledDateTime.minute,
      );

      bool slotAvailable = false;
      for (final slot in availableSlots) {
        if (_isTimeInSlot(currentTime, slot) && slot.isAvailable) {
          slotAvailable = true;
          break;
        }
      }

      if (!slotAvailable) {
        throw Exception('No hay disponibilidad en el horario seleccionado');
      }

      final scheduledOrder = ScheduledOrder(
        id: _firestore.collection('scheduled_orders').doc().id,
        userId: userId,
        businessId: businessId,
        items: items,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        tip: 0,
        total: total,
        deliveryAddress: deliveryAddress,
        paymentMethod: paymentMethod,
        scheduledDateTime: scheduledDateTime,
        createdAt: DateTime.now(),
        notes: notes,
        preferences: preferences,
        reminderTimes: reminderTimes ?? ['1h', '30m', '10m'],
        isRecurring: isRecurring,
        recurrencePattern: recurrencePattern,
        specialInstructions: specialInstructions,
      );

      // Guardar pedido programado
      await _firestore
          .collection('scheduled_orders')
          .doc(scheduledOrder.id)
          .set(scheduledOrder.toMap());

      // Actualizar contador de pedidos en el horario
      await _updateSlotCount(businessId, scheduledDateTime);

      // Configurar recordatorios
      await _scheduleReminders(scheduledOrder);

      // Enviar notificación de confirmación
      await _sendConfirmationNotification(scheduledOrder);

      return scheduledOrder;
    } catch (e) {
      print('Error creating scheduled order: $e');
      rethrow;
    }
  }

  // Actualizar estado de pedido programado
  Future<void> updateOrderStatus(String orderId, ScheduledOrderStatus status) async {
    try {
      await _firestore
          .collection('scheduled_orders')
          .doc(orderId)
          .update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Enviar notificación de cambio de estado
      final orderDoc = await _firestore
          .collection('scheduled_orders')
          .doc(orderId)
          .get();

      if (orderDoc.exists) {
        final order = ScheduledOrder.fromMap(orderDoc.data()!);
        await _sendStatusNotification(order, status.name);
      }
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  // Cancelar pedido programado
  Future<void> cancelScheduledOrder(String orderId, String? reason) async {
    try {
      final orderDoc = await _firestore
          .collection('scheduled_orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Pedido no encontrado');
      }

      final order = ScheduledOrder.fromMap(orderDoc.data()!);

      // Verificar políticas de cancelación
      final timeUntilOrder = order.scheduledDateTime.difference(DateTime.now());
      if (timeUntilOrder.inHours < 2) {
        throw Exception('No se puede cancelar el pedido con menos de 2 horas de anticipación');
      }

      await _firestore
          .collection('scheduled_orders')
          .doc(orderId)
          .update({
        'status': ScheduledOrderStatus.cancelled.name,
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Liberar espacio en el horario
      await _updateSlotCount(order.businessId, order.scheduledDateTime, decrement: true);

      // Enviar notificación de cancelación
      await _sendCancellationNotification(order, reason);

      // Cancelar recordatorios
      await _cancelReminders(orderId);
    } catch (e) {
      print('Error cancelling scheduled order: $e');
      rethrow;
    }
  }

  // Obtener disponibilidad del negocio
  Future<BusinessAvailability> getBusinessAvailability(String businessId) async {
    try {
      final doc = await _firestore
          .collection('business_availability')
          .doc(businessId)
          .get();

      if (doc.exists) {
        return BusinessAvailability.fromMap(doc.data()!);
      }

      // Crear disponibilidad por defecto
      return _createDefaultAvailability(businessId);
    } catch (e) {
      print('Error getting business availability: $e');
      return _createDefaultAvailability(businessId);
    }
  }

  // Actualizar disponibilidad del negocio
  Future<void> updateBusinessAvailability(
    String businessId,
    BusinessAvailability availability,
  ) async {
    try {
      await _firestore
          .collection('business_availability')
          .doc(businessId)
          .set(availability.toMap());
    } catch (e) {
      print('Error updating business availability: $e');
    }
  }

  // Obtener horarios disponibles para una fecha
  Future<List<TimeSlot>> getAvailableTimeSlots(String businessId, DateTime date) async {
    try {
      final availability = await getBusinessAvailability(businessId);
      
      if (!availability.isAvailable(date)) {
        return [];
      }

      final dayOfWeek = date.weekday;
      final timeSlots = availability.weeklySchedule[dayOfWeek] ?? [];

      // Filtrar horarios que ya pasaron si es hoy
      if (date.day == DateTime.now().day) {
        final now = TimeOfDay.now();
        return timeSlots.where((slot) => 
            slot.endTime.hour > now.hour || 
            (slot.endTime.hour == now.hour && slot.endTime.minute > now.minute)
        ).toList();
      }

      return timeSlots;
    } catch (e) {
      print('Error getting available time slots: $e');
      return [];
    }
  }

  // Crear pedido recurrente
  Future<List<ScheduledOrder>> createRecurringOrder({
    required String businessId,
    required List<OrderItem> items,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required String deliveryAddress,
    required String paymentMethod,
    required DateTime startDate,
    required RecurrencePattern recurrencePattern,
    String? notes,
    Map<String, dynamic>? preferences,
    List<String>? reminderTimes,
    String? specialInstructions,
  }) async {
    try {
      final orders = <ScheduledOrder>[];
      DateTime currentDate = startDate;

      // Crear pedidos según el patrón de recurrencia
      while (currentDate.isBefore(recurrencePattern.endDate ?? DateTime(2100))) {
        final order = await createScheduledOrder(
          businessId: businessId,
          items: items,
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          total: total,
          deliveryAddress: deliveryAddress,
          paymentMethod: paymentMethod,
          scheduledDateTime: currentDate,
          notes: notes,
          preferences: preferences,
          reminderTimes: reminderTimes,
          isRecurring: true,
          recurrencePattern: recurrencePattern,
          specialInstructions: specialInstructions,
        );

        orders.add(order);

        // Obtener próxima ocurrencia
        final nextDate = recurrencePattern.getNextOccurrence(currentDate);
        if (nextDate == null) break;

        currentDate = nextDate;

        // Verificar límite de ocurrencias
        if (recurrencePattern.maxOccurrences != null &&
            orders.length >= recurrencePattern.maxOccurrences!) {
          break;
        }
      }

      return orders;
    } catch (e) {
      print('Error creating recurring order: $e');
      rethrow;
    }
  }

  // Obtener estadísticas de pedidos programados
  Future<Map<String, dynamic>> getScheduledOrderStats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('scheduled_orders')
          .where('userId', isEqualTo: userId)
          .get();

      final orders = snapshot.docs
          .map((doc) => ScheduledOrder.fromMap(doc.data()))
          .toList();

      final totalOrders = orders.length;
      final completedOrders = orders
          .where((order) => order.status == ScheduledOrderStatus.delivered)
          .length;
      final cancelledOrders = orders
          .where((order) => order.status == ScheduledOrderStatus.cancelled)
          .length;
      final pendingOrders = orders
          .where((order) => order.status == ScheduledOrderStatus.pending ||
                        order.status == ScheduledOrderStatus.confirmed)
          .length;

      final totalSpent = orders
          .where((order) => order.status == ScheduledOrderStatus.delivered)
          .fold<double>(0, (sum, order) => sum + order.total);

      return {
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'cancelledOrders': cancelledOrders,
        'pendingOrders': pendingOrders,
        'totalSpent': totalSpent,
        'averageOrderValue': completedOrders > 0 ? totalSpent / completedOrders : 0,
        'completionRate': totalOrders > 0 ? (completedOrders / totalOrders) * 100 : 0,
      };
    } catch (e) {
      print('Error getting scheduled order stats: $e');
      return {};
    }
  }

  // Métodos privados
  BusinessAvailability _createDefaultAvailability(String businessId) {
    final weeklySchedule = <int, List<TimeSlot>>{};
    
    // Horario por defecto: 10:00 - 22:00 todos los días
    for (int day = 1; day <= 7; day++) {
      weeklySchedule[day] = [
        TimeSlot(
          startTime: const TimeOfDay(hour: 10, minute: 0),
          endTime: const TimeOfDay(hour: 22, minute: 0),
          maxOrders: 20,
        ),
      ];
    }

    return BusinessAvailability(
      businessId: businessId,
      weeklySchedule: weeklySchedule,
      minPreparationTime: 15,
      maxPreparationTime: 60,
      acceptsScheduledOrders: true,
      businessHours: TimeSlot(
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 22, minute: 0),
      ),
    );
  }

  bool _isTimeInSlot(TimeOfDay time, TimeSlot slot) {
    final timeInMinutes = time.hour * 60 + time.minute;
    final startInMinutes = slot.startTime.hour * 60 + slot.startTime.minute;
    final endInMinutes = slot.endTime.hour * 60 + slot.endTime.minute;

    return timeInMinutes >= startInMinutes && timeInMinutes <= endInMinutes;
  }

  Future<void> _updateSlotCount(
    String businessId,
    DateTime dateTime, {
    bool decrement = false,
  }) async {
    try {
      final availability = await getBusinessAvailability(businessId);
      final dayOfWeek = dateTime.weekday;
      final timeSlots = availability.weeklySchedule[dayOfWeek] ?? [];

      final currentTime = TimeOfDay(
        hour: dateTime.hour,
        minute: dateTime.minute,
      );

      for (final slot in timeSlots) {
        if (_isTimeInSlot(currentTime, slot)) {
          final updatedSlot = TimeSlot(
            startTime: slot.startTime,
            endTime: slot.endTime,
            maxOrders: slot.maxOrders,
            currentOrders: decrement
                ? (slot.currentOrders - 1).clamp(0, slot.maxOrders)
                : (slot.currentOrders + 1).clamp(0, slot.maxOrders),
          );

          // Actualizar el slot en la base de datos
          await _firestore
              .collection('business_availability')
              .doc(businessId)
              .update({
            'weeklySchedule.$dayOfWeek': timeSlots.map((s) => s.toMap()).toList(),
          });

          break;
        }
      }
    } catch (e) {
      print('Error updating slot count: $e');
    }
  }

  Future<void> _scheduleReminders(ScheduledOrder order) async {
    try {
      final reminderTimes = order.reminderTimes ?? ['1h', '30m', '10m'];
      
      for (final reminderTime in reminderTimes) {
        Duration delay;
        
        switch (reminderTime) {
          case '1h':
            delay = const Duration(hours: 1);
            break;
          case '30m':
            delay = const Duration(minutes: 30);
            break;
          case '10m':
            delay = const Duration(minutes: 10);
            break;
          case '1d':
            delay = const Duration(days: 1);
            break;
          default:
            continue;
        }

        final reminderDateTime = order.scheduledDateTime.subtract(delay);
        
        if (reminderDateTime.isAfter(DateTime.now())) {
          // Aquí se programaría la notificación
          // Por ahora, solo guardamos en la base de datos
          await _firestore
              .collection('scheduled_reminders')
              .add({
            'orderId': order.id,
            'userId': order.userId,
            'reminderTime': reminderTime,
            'scheduledFor': Timestamp.fromDate(reminderDateTime),
            'isSent': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error scheduling reminders: $e');
    }
  }

  Future<void> _cancelReminders(String orderId) async {
    try {
      final reminders = await _firestore
          .collection('scheduled_reminders')
          .where('orderId', isEqualTo: orderId)
          .where('isSent', isEqualTo: false)
          .get();

      for (final doc in reminders.docs) {
        await doc.reference.update({'isSent': true});
      }
    } catch (e) {
      print('Error cancelling reminders: $e');
    }
  }

  Future<void> _sendConfirmationNotification(ScheduledOrder order) async {
    await _notificationService.sendScheduledOrderConfirmation(order.toMap());
  }

  Future<void> _sendStatusNotification(
    ScheduledOrder order,
    String status,
  ) async {
    await _notificationService.sendScheduledOrderStatusUpdate(order.toMap(), status);
  }

  Future<void> _sendCancellationNotification(
    ScheduledOrder order,
    String? reason,
  ) async {
    await _notificationService.sendScheduledOrderCancellation(order.toMap(), reason ?? 'Cancelado por el usuario');
  }

  // Verificar pedidos vencidos
  Future<void> checkOverdueOrders() async {
    try {
      final now = DateTime.now();
      final overdueOrders = await _firestore
          .collection('scheduled_orders')
          .where('scheduledDateTime', isLessThan: now)
          .where('status', whereIn: [
            ScheduledOrderStatus.pending.name,
            ScheduledOrderStatus.confirmed.name,
          ])
          .get();

      for (final doc in overdueOrders.docs) {
        final order = ScheduledOrder.fromMap(doc.data()!);
        
        // Marcar como no se presentó si ha pasado mucho tiempo
        if (now.difference(order.scheduledDateTime).inMinutes > 30) {
          await updateOrderStatus(order.id, ScheduledOrderStatus.no_show);
        }
      }
    } catch (e) {
      print('Error checking overdue orders: $e');
    }
  }

  // Obtener próximos pedidos
  Future<List<ScheduledOrder>> getUpcomingOrders(String userId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('scheduled_orders')
          .where('userId', isEqualTo: userId)
          .where('scheduledDateTime', isGreaterThan: now)
          .where('status', whereIn: [
            ScheduledOrderStatus.pending.name,
            ScheduledOrderStatus.confirmed.name,
          ])
          .orderBy('scheduledDateTime', descending: false)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => ScheduledOrder.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting upcoming orders: $e');
      return [];
    }
  }
}
