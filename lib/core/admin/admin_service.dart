import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> _log({
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? metadata,
  }) async {
    final actor = FirebaseAuth.instance.currentUser?.uid;
    await _firestore.collection('audit_logs').add({
      'actorUid': actor,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'metadata': metadata ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ===== USERS =====
  static Future<void> banUser({
    required String userId,
    required String reason,
    DateTime? until,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'status': 'banned',
      'banReason': reason,
      'bannedUntil': until,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _log(
      action: 'users.ban',
      targetType: 'user',
      targetId: userId,
      metadata: {'reason': reason, 'until': until?.toIso8601String()},
    );
  }

  static Future<void> unbanUser({
    required String userId,
    required String reason,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'status': 'active',
      'banReason': null,
      'bannedUntil': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _log(
      action: 'users.unban',
      targetType: 'user',
      targetId: userId,
      metadata: {'reason': reason},
    );
  }

  static Future<void> restrictPosting({
    required String userId,
    required String reason,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'canPost': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _log(
      action: 'users.restrict_posting',
      targetType: 'user',
      targetId: userId,
      metadata: {'reason': reason},
    );
  }

  static Future<void> restorePosting({
    required String userId,
    required String reason,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'canPost': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _log(
      action: 'users.restore_posting',
      targetType: 'user',
      targetId: userId,
      metadata: {'reason': reason},
    );
  }

  // ===== POSTS =====
  static Future<void> softDeletePost({
    required String postId,
    required String reason,
  }) async {
    final actor = FirebaseAuth.instance.currentUser?.uid;

    await _firestore.collection('posts').doc(postId).update({
      'status': 'deleted',
      'deleteReason': reason,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': actor,
    });

    await _log(
      action: 'posts.delete',
      targetType: 'post',
      targetId: postId,
      metadata: {'reason': reason},
    );
  }
}
