import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/business_chat_service.dart';
import '../models/chat_model.dart';

class ChatInputWidget extends StatefulWidget {
  final String conversationId;
  final VoidCallback onSendLocation;
  final VoidCallback onSendFile;
  final VoidCallback onSendImage;
  final VoidCallback onSendAudio;
  final VoidCallback onSendVideo;

  const ChatInputWidget({
    Key? key,
    required this.conversationId,
    required this.onSendLocation,
    this.onSendFile,
    this.onSendImage,
    this.onSendAudio,
    this.onSendVideo,
  }) : super(key: key);

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final BusinessChatService _chatService = BusinessChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Campo de texto
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Escribe un mensaje...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 4,
            onChanged: (value) {
              if (value.isNotEmpty) {
                _chatService.sendTypingIndicator(widget.conversationId);
              } else {
                _chatService.stopTypingIndicator(widget.conversationId);
              }
            },
          ),
          const SizedBox(height: 8),
          
          // Botones de acciones
          Row(
            children: [
              // Botón de enviar
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_messageController.text.isNotEmpty) {
                      _chatService.sendMessage(
                        widget.conversationId,
                        _messageController.text,
                        ChatMessageType.text,
                      );
                      _messageController.clear();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Enviar'),
                ),
              ),
              const SizedBox(width: 8),
              
              // Botones adicionales
              IconButton(
                onPressed: () {
                  _chatService.sendMessage(
                    widget.conversationId,
                    '📍 Ubicación actual',
                    ChatMessageType.location,
                  );
                },
                icon: const Icon(Icons.location_on),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                ),
              ),
              const SizedBox(width: 4),
              
              IconButton(
                onPressed: () {
                  widget.onSendFile();
                },
                icon: const Icon(Icons.attach_file),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                ),
              ),
              const SizedBox(width: 4),
              
              IconButton(
                onPressed: () {
                  widget.onSendImage();
                },
                icon: const Icon(Icons.image),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                ),
              ),
              const SizedBox(width: 4),
              
              IconButton(
                onPressed: () {
                  widget.onSendAudio();
                },
                icon: const Icon(Icons.mic),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                ),
              ),
              const SizedBox(width: 4),
              
              IconButton(
                onPressed: () {
                  widget.onSendVideo();
                },
                icon: const Icon(Icons.videocam),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
