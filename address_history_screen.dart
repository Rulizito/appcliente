// ============================================================================
// screens/address_history_screen.dart
// ============================================================================

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/address_history_service.dart';
import '../models/address_model.dart';

class AddressHistoryScreen extends StatefulWidget {
  final Function(Address)? onAddressSelected;

  const AddressHistoryScreen({
    Key? key,
    this.onAddressSelected,
  }) : super(key: key);

  @override
  State<AddressHistoryScreen> createState() => _AddressHistoryScreenState();
}

class _AddressHistoryScreenState extends State<AddressHistoryScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _historyService = AddressHistoryService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Historial de Direcciones'),
          backgroundColor: Colors.red,
        ),
        body: const Center(
          child: Text('Debes iniciar sesión'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Direcciones'),
        backgroundColor: Colors.red,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Recientes', icon: Icon(Icons.access_time)),
            Tab(text: 'Más usadas', icon: Icon(Icons.trending_up)),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Limpiar historial'),
                  ],
                ),
                onTap: () {
                  Future.delayed(Duration.zero, () => _showClearHistoryDialog());
                },
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Estadísticas'),
                  ],
                ),
                onTap: () {
                  Future.delayed(Duration.zero, () => _showStatsDialog(user.uid));
                },
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecentAddresses(user.uid),
          _buildMostUsedAddresses(user.uid),
        ],
      ),
    );
  }

  Widget _buildRecentAddresses(String userId) {
    return StreamBuilder<List<Address>>(
      stream: _historyService.getRecentAddresses(userId, limit: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final addresses = snapshot.data ?? [];

        if (addresses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay direcciones recientes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usá una dirección en un pedido para que aparezca aquí',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: addresses.length,
          itemBuilder: (context, index) {
            final address = addresses[index];
            return AddressHistoryCard(
              address: address,
              showLastUsed: true,
              onTap: widget.onAddressSelected != null
                  ? () {
                      widget.onAddressSelected!(address);
                      Navigator.pop(context);
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildMostUsedAddresses(String userId) {
    return StreamBuilder<List<Address>>(
      stream: _historyService.getMostUsedAddresses(userId, limit: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final addresses = snapshot.data ?? [];

        if (addresses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay direcciones usadas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hacé algunos pedidos para ver tus direcciones más usadas',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: addresses.length,
          itemBuilder: (context, index) {
            final address = addresses[index];
            return AddressHistoryCard(
              address: address,
              showUsageCount: true,
              rank: index + 1,
              onTap: widget.onAddressSelected != null
                  ? () {
                      widget.onAddressSelected!(address);
                      Navigator.pop(context);
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  void _showClearHistoryDialog() {
    final user = _authService.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: const Text(
          '¿Estás seguro de que querés limpiar el historial de uso de direcciones?\n\n'
          'Esto no eliminará las direcciones, solo su historial de uso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _historyService.clearHistory(user.uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Historial limpiado'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Limpiar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog(String userId) async {
    final stats = await _historyService.getAddressStats(userId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estadísticas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow(
              'Total de direcciones',
              '${stats['totalAddresses']}',
              Icons.location_on,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              'Direcciones usadas',
              '${stats['usedAddresses']}',
              Icons.check_circle,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              'Total de usos',
              '${stats['totalUsages']}',
              Icons.trending_up,
            ),
            if (stats['mostUsed'] != null) ...[
              const Divider(height: 24),
              const Text(
                'Dirección más usada:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (stats['mostUsed'] as Address).fullAddress,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '${(stats['mostUsed'] as Address).usageCount} veces',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.red, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Widget para cada tarjeta de dirección en el historial
class AddressHistoryCard extends StatelessWidget {
  final Address address;
  final bool showLastUsed;
  final bool showUsageCount;
  final int? rank;
  final VoidCallback? onTap;

  const AddressHistoryCard({
    Key? key,
    required this.address,
    this.showLastUsed = false,
    this.showUsageCount = false,
    this.rank,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final historyService = AddressHistoryService();

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: address.isDefault
              ? Border.all(color: Colors.red, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ranking o ícono
            if (rank != null)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getRankColor(rank!),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              Icon(
                Icons.location_on,
                color: address.isDefault ? Colors.red : Colors.grey,
                size: 36,
              ),

            const SizedBox(width: 16),

            // Información
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.isDefault)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PREDETERMINADA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    address.fullAddress,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (showLastUsed)
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          historyService.formatLastUsed(address.lastUsed),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  if (showUsageCount)
                    Row(
                      children: [
                        Icon(
                          Icons.repeat,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Usada ${address.usageCount} ${address.usageCount == 1 ? 'vez' : 'veces'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.brown[300]!;
      default:
        return Colors.blue;
    }
  }
}