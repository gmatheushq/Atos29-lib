import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminGuard {
  static final _firestore = FirebaseFirestore.instance;

  static Future<String> getMyRole() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return 'user';

    final snap = await _firestore.collection('users').doc(u.uid).get();
    final data = snap.data();
    return (data?['role'] ?? 'user').toString();
  }

  static Future<bool> isAdminOrMod() async {
    final role = await getMyRole();
    return role == 'admin' || role == 'moderator' || role == 'owner';
  }

  static Future<bool> isOwner() async {
    final role = await getMyRole();
    return role == 'owner';
  }
}
