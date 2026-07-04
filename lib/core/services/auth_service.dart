import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth;
  AuthService(this._auth);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS
            ? '450499877642-n7lb6icqa83q3scen009uv60v4srrnrr.apps.googleusercontent.com'
            : null,
        serverClientId: '450499877642-6lvg9s5du6l1kjk9a75u4qkd2u01oljb.apps.googleusercontent.com',
      );
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      return _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> signInWithApple() async {
    final appleProvider = AppleAuthProvider();
    appleProvider.addScope('email');
    appleProvider.addScope('name');

    return _auth.signInWithProvider(appleProvider);
  }


  Future<void> signOut() async {
    await GoogleSignIn.instance.disconnect();
    await _auth.signOut();
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      // Supprime tous les documents de la sous-collection sessions
      final sessionsSnapshot = await userDocRef.collection('sessions').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in sessionsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Puis le document utilisateur lui-même
      await userDocRef.delete();

      // Enfin le compte Auth
      await user.delete();
    } catch (e) {
      rethrow;
    }
  }
}


final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});