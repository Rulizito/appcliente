import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scheduled_order_model.dart';
import '../services/scheduled_order_service.dart';
import '../models/business_model.dart' as business_model;
import '../models/order_model.dart' as order_model;

class ScheduleOrderWidget extends StatefulWidget {
  final String businessId;
  final String businessName;
  final Map<String, dynamic> cart;
  final double total;
  final Function(ScheduledOrder) onOrderScheduled;

  const ScheduleOrderWidget({
    Key? key,
    required this.businessId,
    required this.businessName,
    required this.cart,
    required this.total,
    required this.onOrderScheduled,
  }) : super(key: key);

  @override
  State<ScheduleOrderWidget> createState() => _ScheduleOrderWidgetState();
}

class _ScheduleOrderWidgetState extends State<ScheduleOrderWidget> {
  final ScheduledOrderService _service = ScheduledOrderService();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<String> _selectedReminders = [];
  RecurrencePattern? _recurrencePattern;
  String _notes = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Programar Pedido',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          
          // Selector de fecha
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(
              _selectedDate != null 
                  ? 'Fecha: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                  : 'Seleccionar fecha',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectDate,
          ),
          
          // Selector de hora
          ListTile(
            leading: const Icon(Icons.access_time),
            title: Text(
              _selectedTime != null 
                  ? 'Hora: ${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                  : 'Seleccionar hora',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectTime,
          ),
          
          // Recordatorios
          ExpansionTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Recordatorios'),
            children: [
              CheckboxListTile(
                title: const Text('1 día antes'),
                value: _selectedReminders.contains('1_day'),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedReminders.add('1_day');
                    } else {
                      _selectedReminders.remove('1_day');
                    }
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('1 hora antes'),
                value: _selectedReminders.contains('1_hour'),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedReminders.add('1_hour');
                    } else {
                      _selectedReminders.remove('1_hour');
                    }
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('30 minutos antes'),
                value: _selectedReminders.contains('30_min'),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedReminders.add('30_min');
                    } else {
                      _selectedReminders.remove('30_min');
                    }
                  });
                },
              ),
            ],
          ),
          
          // Notas
          TextField(
            decoration: const InputDecoration(
              labelText: 'Notas o instrucciones especiales',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (value) {
              _notes = value;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Botón de programar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSchedule() ? _scheduleOrder : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Programar Pedido',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canSchedule() {
    return _selectedDate != null && _selectedTime != null && !_isLoading;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _scheduleOrder() async {
    if (!_canSchedule()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Convertir carrito a OrderItem
      final items = widget.cart.entries.map((entry) {
        return OrderItem(
          productId: entry.key,
          productName: entry.key,
          quantity: entry.value as int,
          price: 0.0, // Esto debería venir del producto
        );
      }).toList();

      final scheduledOrder = ScheduledOrder(
        id: '',
        userId: '', // Esto debería venir del usuario actual
        businessId: widget.businessId,
        items: items,
        subtotal: widget.total,
        deliveryFee: 0.0,
        total: widget.total,
        deliveryAddress: '', // Esto debería venir del usuario
        paymentMethod: 'cash',
        scheduledDateTime: scheduledDateTime,
        createdAt: DateTime.now(),
        notes: _notes.isNotEmpty ? _notes : null,
        reminderTimes: _selectedReminders,
        isRecurring: _recurrencePattern != null,
        recurrencePattern: _recurrencePattern,
      );

      final createdOrder = await _service.createScheduledOrder(
        businessId: widget.businessId,
        items: items,
        subtotal: widget.total,
        deliveryFee: 0.0,
        total: widget.total,
        deliveryAddress: '', // Esto debería venir del usuario
        paymentMethod: 'cash',
        scheduledDateTime: scheduledDateTime,
        notes: _notes.isNotEmpty ? _notes : null,
        reminderTimes: _selectedReminders,
        isRecurring: _recurrencePattern != null,
        recurrencePattern: _recurrencePattern,
      );
      widget.onOrderScheduled(createdOrder);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Pedido programado exitosamente!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al programar pedido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
