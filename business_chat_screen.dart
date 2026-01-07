// ============================================================================
// widgets/business_chat_screen_simple.dart - Versión simplificada para corregir errores
// ============================================================================

import 'package:flutter/material.dart';
import '../services/business_chat_service.dart';

class BusinessChatScreen extends StatefulWidget {
  final String conversationId;
  final String businessName;
  final String? businessId;
  final String? businessLogo;

  const BusinessChatScreen({
    Key? key,
    required this.conversationId,
    required this.businessName,
    this.businessId,
    this.businessLogo,
  }) : super(key: key);

  @override
  State<BusinessChatScreen> createState() => _BusinessChatScreenState();
}

class _BusinessChatScreenState extends State<BusinessChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final BusinessChatService _chatService = BusinessChatService();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.businessName),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          // Lista de mensajes (placeholder)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Chat con ${widget.businessName}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          
          // Input de mensaje
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (_messageController.text.isNotEmpty) {
                      // Aquí iría la lógica de envío
                      print('Enviando mensaje: ${_messageController.text}');
                      _messageController.clear();
                    }
                  },
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
