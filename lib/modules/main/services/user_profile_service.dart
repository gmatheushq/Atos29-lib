import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cria o perfil do usuário no Firestore somente se não existir.
  /// - Gera nickname (sem @) automaticamente e garante que seja único.
  /// - Bio inicia vazia.
  /// - Adiciona campos de moderação/admin com defaults seguros:
  ///   role=user, canPost=true, status=active
  static Future<void> ensureProfileCreated({
    required User user,
    required String nickname, // aqui é "nome/apelido" que você já tinha usando displayName
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);

    // Já existe? então só marca verificado/updated e sai
    final existing = await docRef.get();
    if (existing.exists) {
      final data = existing.data() as Map<String, dynamic>?;

      await docRef.set({
        'emailVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'email': user.email ?? '',

        // ✅ defaults só se não existirem (pra não quebrar rules futuras)
        if (data?['role'] == null) 'role': 'user', // user | moderator | admin | owner
        if (data?['canPost'] == null) 'canPost': true,
        if (data?['status'] == null) 'status': 'active', // active | banned
        if (data?['banReason'] == null) 'banReason': null,
        if (data?['bannedUntil'] == null) 'bannedUntil': null,
      }, SetOptions(merge: true));
      return;
    }

    final displayNome = (user.displayName ?? '').trim();
    final email = (user.email ?? '').trim();

    // ✅ Nome do perfil (campo 'nome' que sua tela usa)
    final nomePerfil = _bestName(
      preferred: nickname,
      displayName: displayNome,
      email: email,
    );

    // ✅ Base do nickname (sem @)
    final baseNick = _makeBaseNick(nomePerfil, email);

    // ✅ Gera nickname único (consulta no Firestore)
    final uniqueNick = await _generateUniqueNickname(baseNick);

    await docRef.set({
      // ✅ compatível com sua EditarPerfilPage
      'nome': nomePerfil,
      'nickname': uniqueNick, // sem "@"
      'bio': '', // ✅ bio em branco no cadastro

      'email': email,
      'uid': user.uid,

      'idade': 0,
      'progressoJornada': 0.0,

      // 🔐 ADMIN / MODERAÇÃO (defaults seguros)
      'role': 'user', // user | moderator | admin | owner
      'canPost': true,
      'status': 'active', // active | banned
      'banReason': null,
      'bannedUntil': null,

      'emailVerified': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
  }

  /// Escolhe o melhor nome para iniciar o perfil.
  static String _bestName({
    required String preferred,
    required String displayName,
    required String email,
  }) {
    final p = preferred.trim();
    if (p.isNotEmpty) return p;

    final d = displayName.trim();
    if (d.isNotEmpty) return d;

    if (email.contains('@')) {
      return email.split('@').first.trim();
    }

    return 'Novo Membro';
  }

  /// Cria base do nickname a partir do nome OU do email.
  /// Sem acentos, minúsculo, só [a-z0-9._]
  static String _makeBaseNick(String nome, String email) {
    final raw = nome.trim().isNotEmpty
        ? nome.trim()
        : (email.contains('@') ? email.split('@').first.trim() : 'novo_membro');

    final normalized = _normalizeToNick(raw);

    // fallback se por algum motivo ficou vazio
    if (normalized.isEmpty) return 'novo_membro';

    // evita começar/terminar com . ou _
    return _trimDotUnderscore(normalized);
  }

  /// Normaliza para [a-z0-9._]
  static String _normalizeToNick(String input) {
    var s = input.trim().toLowerCase();

    // remove acentos básicos
    s = s
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');

    // espaços viram ponto
    s = s.replaceAll(RegExp(r'\s+'), '.');

    // remove caracteres inválidos
    s = s.replaceAll(RegExp(r'[^a-z0-9._]'), '');

    // comprime .. e __ repetidos
    s = s.replaceAll(RegExp(r'\.{2,}'), '.');
    s = s.replaceAll(RegExp(r'_{2,}'), '_');

    // limita tamanho (evita nick gigante)
    if (s.length > 20) s = s.substring(0, 20);

    return s;
  }

  static String _trimDotUnderscore(String s) {
    var out = s;
    while (out.startsWith('.') || out.startsWith('_')) {
      out = out.substring(1);
      if (out.isEmpty) return 'novo_membro';
    }
    while (out.endsWith('.') || out.endsWith('_')) {
      out = out.substring(0, out.length - 1);
      if (out.isEmpty) return 'novo_membro';
    }
    return out;
  }

  /// Gera nickname único.
  /// Se existir, tenta base_2, base_3, ... até achar um livre.
  static Future<String> _generateUniqueNickname(String base) async {
    // 1) tenta o base direto
    if (!await _nicknameExists(base)) return base;

    // 2) tenta com sufixo incremental
    // limite para evitar loop infinito (prático)
    for (int i = 2; i <= 9999; i++) {
      final candidate = '${base}_$i';
      if (!await _nicknameExists(candidate)) return candidate;
    }

    // 3) fallback final (improvável)
    return '${base}_${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  static Future<bool> _nicknameExists(String nick) async {
    final q = await _firestore
        .collection('users')
        .where('nickname', isEqualTo: nick)
        .limit(1)
        .get();

    return q.docs.isNotEmpty;
  }
}
