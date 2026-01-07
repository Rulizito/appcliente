import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Prefijo para diferenciar clientes
  static const String _emailPrefix = 'cliente_';

  // Agregar prefijo al email
  String _addPrefix(String email) {
    return '$_emailPrefix$email';
  }

  // Obtener usuario actual
  User? get currentUser => _auth.currentUser;

  // Stream del estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Registro con email y contraseña
  Future<Map<String, dynamic>> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      // Agregar prefijo al email para Firebase Auth
      final prefixedEmail = _addPrefix(email);
      
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: prefixedEmail,
        password: password,
      );

      // Guardar información en Firestore (con email SIN prefijo)
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email, // Email original sin prefijo
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'customer',
        'appType': 'clientes', // Identificar de qué app viene
      });

      await userCredential.user!.updateDisplayName(name);

      return {
        'success': true,
        'message': '¡Cuenta creada exitosamente!',
        'user': userCredential.user,
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'La contraseña es muy débil';
          break;
        case 'email-already-in-use':
          errorMessage = 'Ya existe una cuenta de cliente con este email';
          break;
        case 'invalid-email':
          errorMessage = 'El email no es válido';
          break;
        default:
          errorMessage = 'Error al crear la cuenta: ${e.message}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error inesperado: $e',
      };
    }
  }

  // Login con email y contraseña
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Agregar prefijo al email
      final prefixedEmail = _addPrefix(email);
      
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: prefixedEmail,
        password: password,
      );

      return {
        'success': true,
        'message': '¡Inicio de sesión exitoso!',
        'user': userCredential.user,
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No existe una cuenta de cliente con este email';
          break;
        case 'wrong-password':
          errorMessage = 'Contraseña incorrecta';
          break;
        case 'invalid-email':
          errorMessage = 'El email no es válido';
          break;
        case 'user-disabled':
          errorMessage = 'Esta cuenta ha sido deshabilitada';
          break;
        case 'invalid-credential':
          errorMessage = 'Credenciales inválidas';
          break;
        default:
          errorMessage = 'Error al iniciar sesión: ${e.message}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error inesperado: $e',
      };
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Obtener datos del usuario desde Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error al obtener datos del usuario: $e');
      return null;
    }
  }

  // Restablecer contraseña
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      final prefixedEmail = _addPrefix(email);
      await _auth.sendPasswordResetEmail(email: prefixedEmail);
      return {
        'success': true,
        'message': 'Email de recuperación enviado. Revisá tu correo.',
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No existe una cuenta con este email';
          break;
        case 'invalid-email':
          errorMessage = 'El email no es válido';
          break;
        default:
          errorMessage = 'Error: ${e.message}';
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error inesperado: $e',
      };
    }
  }
  // ============================================================================
  // ACTUALIZAR DATOS DEL PERFIL
  // ============================================================================

  Future<Map<String, dynamic>> updateUserProfile({
    required String uid,
    required String name,
    String? phone,
    String? birthDate,
  }) async {
    try {
      // Actualizar en Firestore
      await _firestore.collection('users').doc(uid).update({
        'name': name,
        'phone': phone,
        'birthDate': birthDate,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar nombre en Firebase Auth
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
      }

      return {
        'success': true,
        'message': '¡Perfil actualizado exitosamente!',
      };
    } on FirebaseException catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error inesperado: $e',
      };
    }
  }

  // Cambiar contraseña
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'No hay usuario autenticado',
        };
      }

      // Re-autenticar con la contraseña actual
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Cambiar contraseña
      await user.updatePassword(newPassword);

      return {
        'success': true,
        'message': '¡Contraseña cambiada exitosamente!',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Error al cambiar contraseña';
    
      if (e.code == 'wrong-password') {
        message = 'La contraseña actual es incorrecta';
      } else if (e.code == 'weak-password') {
        message = 'La nueva contraseña es muy débil';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error inesperado: $e',
      };
    }
  }
}