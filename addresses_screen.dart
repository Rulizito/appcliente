import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/address_model.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({Key? key}) : super(key: key);

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;

  // Eliminar dirección
  Future<void> _deleteAddress(String addressId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc(addressId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dirección eliminada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Establecer como dirección predeterminada
  Future<void> _setDefaultAddress(String addressId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();

      // Obtener todas las direcciones
      final addressesSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .get();

      // Poner todas como no predeterminadas
      for (var doc in addressesSnapshot.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }

      // Establecer la seleccionada como predeterminada
      final selectedRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc(addressId);
      
      batch.update(selectedRef, {'isDefault': true});

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dirección predeterminada actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Mostrar diálogo para confirmar eliminación
  void _confirmDelete(String addressId, String addressText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar dirección'),
        content: Text('¿Estás seguro de eliminar esta dirección?\n\n$addressText'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAddress(addressId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mis Direcciones'),
          backgroundColor: Colors.red,
        ),
        body: const Center(
          child: Text('Debes iniciar sesión'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Direcciones'),
        backgroundColor: Colors.red,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .orderBy('isDefault', descending: true)
            .snapshots(),
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

          final addresses = snapshot.data?.docs ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 100,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No tenés direcciones guardadas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Agregá una dirección para hacer pedidos más rápido',
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
              final addressData = addresses[index].data() as Map<String, dynamic>;
              final address = Address.fromMap(addressData);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: address.isDefault ? Colors.red : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (address.isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
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
                                const SizedBox(height: 4),
                                Text(
                                  address.fullAddress,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (address.reference != null && 
                                    address.reference!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Ref: ${address.reference}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!address.isDefault)
                            TextButton.icon(
                              onPressed: () => _setDefaultAddress(address.id),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Predeterminada'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          TextButton.icon(
                            onPressed: () {
                              // Navegar a editar
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddEditAddressScreen(
                                    address: address,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Editar'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _confirmDelete(
                              address.id,
                              address.fullAddress,
                            ),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Eliminar'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditAddressScreen(),
            ),
          );
        },
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Agregar dirección',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

// ============================================================================
// PANTALLA PARA AGREGAR/EDITAR DIRECCIÓN
// ============================================================================

class AddEditAddressScreen extends StatefulWidget {
  final Address? address;

  const AddEditAddressScreen({Key? key, this.address}) : super(key: key);

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cityController = TextEditingController();
  final _referenceController = TextEditingController();
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _streetController.text = widget.address!.street;
      _numberController.text = widget.address!.number;
      _apartmentController.text = widget.address!.apartment ?? '';
      _cityController.text = widget.address!.city;
      _referenceController.text = widget.address!.reference ?? '';
      _isDefault = widget.address!.isDefault;
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    _numberController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final addressId = widget.address?.id ?? 
          _firestore.collection('users').doc(user.uid).collection('addresses').doc().id;

      final address = Address(
        id: addressId,
        street: _streetController.text.trim(),
        number: _numberController.text.trim(),
        apartment: _apartmentController.text.trim().isEmpty 
            ? null 
            : _apartmentController.text.trim(),
        city: _cityController.text.trim(),
        reference: _referenceController.text.trim().isEmpty 
            ? null 
            : _referenceController.text.trim(),
        isDefault: _isDefault,
      );

      // Si se marca como predeterminada, actualizar las demás
      if (_isDefault) {
        final batch = _firestore.batch();

        // Obtener todas las direcciones
        final addressesSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .get();

        // Poner todas como no predeterminadas
        for (var doc in addressesSnapshot.docs) {
          batch.update(doc.reference, {'isDefault': false});
        }

        // Guardar la nueva dirección
        final newAddressRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .doc(addressId);
        
        batch.set(newAddressRef, address.toMap());

        await batch.commit();
      } else {
        // Solo guardar la dirección sin modificar las demás
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .doc(addressId)
            .set(address.toMap());
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.address == null 
                ? 'Dirección agregada' 
                : 'Dirección actualizada'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address == null 
            ? 'Agregar dirección' 
            : 'Editar dirección'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calle
              TextFormField(
                controller: _streetController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Calle',
                  hintText: 'Av. Corrientes',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresá la calle';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Número
              TextFormField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Número',
                  hintText: '1234',
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresá el número';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Departamento (opcional)
              TextFormField(
                controller: _apartmentController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Departamento (opcional)',
                  hintText: '5B',
                  prefixIcon: const Icon(Icons.apartment),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Ciudad
              TextFormField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Ciudad',
                  hintText: 'Buenos Aires',
                  prefixIcon: const Icon(Icons.location_city),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresá la ciudad';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Referencia (opcional)
              TextFormField(
                controller: _referenceController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Referencia (opcional)',
                  hintText: 'Entre calle X y calle Y, portón verde',
                  prefixIcon: const Icon(Icons.info_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Checkbox de dirección predeterminada
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  title: const Text(
                    'Establecer como dirección predeterminada',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Se usará automáticamente en tus pedidos',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isDefault,
                  activeColor: Colors.red,
                  onChanged: (value) {
                    setState(() {
                      _isDefault = value ?? false;
                    });
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Botón guardar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.address == null ? 'Guardar' : 'Actualizar',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}