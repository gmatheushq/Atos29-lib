import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NovenaSyncService {
  static const _kNome = 'novena_ativa_nome';
  static const _kId = 'novena_ativa_id';
  static const _kDia = 'novena_ativa_dia';
  static const _kUltima = 'novena_ultima_oracao_data';

  static Future<void> syncFromPrefsToUserDoc() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[NOVENA_SYNC] user == null (não logado)');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      final nome = prefs.getString(_kNome) ?? 'Nenhuma novena ativa';
      final novenaId = prefs.getString(_kId) ?? '';
      final dia = prefs.getInt(_kDia) ?? 0;
      final ultimaData = prefs.getString(_kUltima) ?? '';

      final temNovenaAtiva = novenaId.isNotEmpty && nome != 'Nenhuma novena ativa';

      final payload = <String, dynamic>{
        'novena': {
          'active': temNovenaAtiva,
          'id': novenaId,
          'title': nome,
          'day': dia,
          'lastPrayedDate': ultimaData, // "YYYY-MM-DD" ou ""
          'updatedAt': FieldValue.serverTimestamp(),
        },
      };

      debugPrint('[NOVENA_SYNC] uid=${user.uid}');
      debugPrint('[NOVENA_SYNC] payload=$payload');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      debugPrint('[NOVENA_SYNC] ✅ gravou em users/${user.uid}');
    } catch (e, st) {
      debugPrint('[NOVENA_SYNC] ❌ ERRO: $e');
      debugPrint('$st');
    }
  }
}
