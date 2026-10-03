import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  // Escuchar el estado de autenticación (usuario logueado o no)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Iniciar sesión con Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Iniciar el flujo de autenticación de Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // 2. Obtener los detalles de autenticación del usuario
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Crear una nueva credencial
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Iniciar sesión en Firebase con la credencial
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error en signInWithGoogle: $e');
      return null;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error en signOut: $e');
    }
  }
}
