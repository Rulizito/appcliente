import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/business_chat_service.dart';
import '../models/chat_model.dart';
import '../models/business_model.dart' as business_model;
import '../widgets/business_chat_screen.dart';

class BusinessChatListScreen extends StatefulWidget {
  const BusinessChatListScreen({Key? key}) : super(key: key);

  @override
  State<BusinessChatListScreen> createState() => _BusinessChatListScreenState();
}

class _BusinessChatListScreenState extends State<BusinessChatListScreen>
    with TickerProviderStateMixin {
  final BusinessChatService _chatService = BusinessChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  
  List<BusinessChatConversation> _conversations = [];
  List<BusinessChatConversation> _filteredConversations = [];
  bool _isLoading = true;
  String? _userId;
  String _searchQuery = '';
  bool _isSearching = false;

  late TabController _tabController;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
    _tabController = TabController(length: 2, vsync: this);
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener conversaciones no leídas para el badge
      final unreadConversations = await _chatService.getUnreadConversations(
        _userId!,
        'customer',
      );
      
      setState(() {
        _unreadCount = unreadConversations.length;
      });
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  void _filterConversations(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _isSearching = query.isNotEmpty;
      
      if (query.isEmpty) {
        _filteredConversations = _conversations;
      } else {
        _filteredConversations = _conversations.where((conversation) {
          return conversation.businessName.toLowerCase().contains(query) ||
              conversation.lastMessage?.toLowerCase().contains(query) == true;
        }).toList();
      }
    });
  }

  Future<void> _refreshConversations() async {
    setState(() {
      _isLoading = true;
    });
    
    // Simular recarga
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _isLoading = false;
    });
  }

  void _openChat(BusinessChatConversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessChatScreen(
          conversationId: conversation.id,
          businessId: conversation.businessId,
          businessName: conversation.businessName,
          businessLogo: conversation.businessLogo,
        ),
      ),
    );
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => const NewChatDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _userId == null
          ? _buildNotLoggedInState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildConversationsList(),
                _buildUnreadConversationsList(),
              ],
            ),
      floatingActionButton: _userId != null
          ? FloatingActionButton(
              onPressed: _showNewChatDialog,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.chat, color: Colors.white),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Mensajes'),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: [
          Tab(
            text: 'Todas',
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No leídas'),
                if (_unreadCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _refreshConversations,
          icon: const Icon(Icons.refresh),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'search':
                _showSearchDialog();
                break;
              case 'settings':
                _showSettings();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'search',
              child: Row(
                children: [
                  Icon(Icons.search, size: 20),
                  SizedBox(width: 8),
                  Text('Buscar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20),
                  SizedBox(width: 8),
                  Text('Configuración'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotLoggedInState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Inicia sesión para chatear con negocios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Comunícate directamente con tus negocios favoritos',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    return RefreshIndicator(
      onRefresh: _refreshConversations,
      child: StreamBuilder<List<BusinessChatConversation>>(
        stream: _chatService.getCustomerConversations(_userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final conversations = snapshot.data ?? [];
          
          if (conversations.isEmpty) {
            return _buildEmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No hay conversaciones',
              subtitle: 'Inicia un chat con un negocio para comenzar',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _buildConversationTile(conversation);
            },
          );
        },
      ),
    );
  }

  Widget _buildUnreadConversationsList() {
    return StreamBuilder<List<BusinessChatConversation>>(
      stream: _chatService.getCustomerConversations(_userId!).map(
        (conversations) => conversations.where((c) => c.unreadCount > 0).toList(),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final unreadConversations = snapshot.data ?? [];
        
        if (unreadConversations.isEmpty) {
          return _buildEmptyState(
            icon: Icons.mark_email_read,
            title: 'No hay mensajes no leídos',
            subtitle: 'Todos tus mensajes están al día',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: unreadConversations.length,
          itemBuilder: (context, index) {
            final conversation = unreadConversations[index];
            return _buildConversationTile(conversation);
          },
        );
      },
    );
  }

  Widget _buildConversationTile(BusinessChatConversation conversation) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[200],
          backgroundImage: conversation.businessLogo.isNotEmpty
              ? CachedNetworkImageProvider(conversation.businessLogo)
              : null,
          child: conversation.businessLogo.isEmpty
              ? const Icon(Icons.store, color: Colors.grey)
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.businessName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              conversation.lastMessage ?? 'No hay mensajes',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(conversation.lastMessageTime),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () => _openChat(conversation),
        onLongPress: () => _showConversationOptions(conversation),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar conversaciones'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre de negocio o mensaje...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onChanged: _filterConversations,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _showConversationOptions(BusinessChatConversation conversation) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mark_email_read, color: Colors.blue),
              title: const Text('Marcar como leído'),
              onTap: () async {
                Navigator.pop(context);
                await _chatService.markMessagesAsRead(conversation.id, _userId!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.orange),
              title: const Text('Archivar conversación'),
              onTap: () async {
                Navigator.pop(context);
                await _chatService.archiveConversation(conversation.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar conversación'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(conversation);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.grey),
              title: const Text('Ver información del negocio'),
              onTap: () {
                Navigator.pop(context);
                // Navegar a detalles del negocio
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BusinessChatConversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar conversación'),
        content: Text(
          '¿Estás seguro de que quieres eliminar la conversación con ${conversation.businessName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _chatService.deleteConversation(conversation.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    Navigator.pushNamed(context, '/chat_settings');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return '${date.day}/${date.month}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class NewChatDialog extends StatefulWidget {
  const NewChatDialog({Key? key}) : super(key: key);

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final TextEditingController _searchController = TextEditingController();
  final BusinessChatService _chatService = BusinessChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<business_model.Business> _businesses = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchBusinesses(String query) async {
    if (query.isEmpty) {
      setState(() {
        _businesses = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simular búsqueda de negocios
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Aquí se buscarían negocios reales
      setState(() {
        _businesses = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo chat'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar negocio...',
                prefixIcon: Icon(Icons.search),
              ),
              autofocus: true,
              onChanged: _searchBusinesses,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_businesses.isEmpty)
              Text(
                'Busca un negocio para iniciar un chat',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _businesses.length,
                  itemBuilder: (context, index) {
                    final business = _businesses[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: business.logo != null
                            ? CachedNetworkImageProvider(business.logo!)
                            : null,
                        child: business.logo == null
                            ? const Icon(Icons.store)
                            : null,
                      ),
                      title: Text(business.name),
                      subtitle: Text(business.categories.join(', ')),
                      onTap: () async {
                        Navigator.pop(context);
                        
                        // Crear o obtener la conversación
                        final userId = _auth.currentUser?.uid;
                        if (userId != null) {
                          final conversation = await _chatService.getOrCreateConversation(
                            userId,
                            business.id,
                          );
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BusinessChatScreen(
                                conversationId: conversation.id,
                                businessId: business.id,
                                businessName: business.name,
                                businessLogo: business.logo,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
