import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/swim_session.dart';

class FirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreService(this._db, this._auth);

  String get _uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('users').doc(_uid).collection('sessions');

  // Sauvegarde une session → retourne l'id Firestore
  Future<String> saveSession(SwimSession session) async {
    final ref = await _sessions.add(session.toFirestore());
    return ref.id;
  }

  // Stream de toutes les sessions triées par date (pour l'historique)
  Stream<List<SwimSession>> watchSessions() {
    return _sessions
        .orderBy('started_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SwimSession.fromFirestore(doc))
            .toList());
  }

  // Récupère les N dernières sessions (pour le dashboard)
  Future<List<SwimSession>> fetchRecentSessions({int limit = 5}) async {
    final snap = await _sessions
        .orderBy('started_at', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((doc) => SwimSession.fromFirestore(doc)).toList();
  }

  // Supprime une session
  Future<void> deleteSession(String sessionId) =>
      _sessions.doc(sessionId).delete();


  // Supprime toutes les sessions de l'utilisateur (avant suppression du compte)
  Future<void> deleteAllUserData() async {
    final snap = await _sessions.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}




// Providers
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});

final sessionsStreamProvider = StreamProvider<List<SwimSession>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.watchSessions();
});
