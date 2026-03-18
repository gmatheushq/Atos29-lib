import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

final FirebaseFunctions functions =
FirebaseFunctions.instanceFor(region: 'us-central1');

class UsersListPage extends StatelessWidget {
  const UsersListPage({super.key});

  static const Color vinhoProfundo = Color(0xFF3A0808);
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color paper = Color(0xFFFBFAF8);
  static const double kCoverHeight = 180.0;
  static const int kBioMaxChars = 120;

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 22,
    offset: const Offset(0, 10),
  );

  String _truncateBio(String s) {
    final t = s.trim();
    if (t.length <= kBioMaxChars) return t;
    return "${t.substring(0, kBioMaxChars).trimRight()}…";
  }

  String? _readUrl(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return s;
  }
  String _readText(Map<String, dynamic> data, String key,
      {String fallback = ''}) {
    final v = data[key];
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String? _readEmail(Map<String, dynamic> data) {
    final v = data['email'];
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return s;
  }

  Future<void> _contactByEmail(BuildContext context, String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Contato pelo app',
        'body': '',
      },
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Não consegui abrir o app de email 😕"),
          backgroundColor: vinhoProfundo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Future<bool> _isAdminOrMod() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;

    final snap =
    await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final role = (snap.data()?['role'] ?? 'user').toString();
    return role == 'admin' || role == 'moderator' || role == 'owner';
  }

  Future<void> _adminBanUser({
    required String targetUid,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
      'status': 'banned',
      'banReason': reason,
      'bannedUntil': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAdmin(
      action: 'users.ban',
      targetType: 'user',
      targetId: targetUid,
      metadata: {'reason': reason},
    );
  }

  Future<void> _adminUnbanUser({
    required String targetUid,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
      'status': 'active',
      'banReason': null,
      'bannedUntil': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAdmin(
      action: 'users.unban',
      targetType: 'user',
      targetId: targetUid,
      metadata: {'reason': reason},
    );
  }

  Future<void> _adminRestrictPosting({
    required String targetUid,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
      'canPost': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAdmin(
      action: 'users.restrict_posting',
      targetType: 'user',
      targetId: targetUid,
      metadata: {'reason': reason},
    );
  }

  Future<void> _adminRestorePosting({
    required String targetUid,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
      'canPost': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAdmin(
      action: 'users.restore_posting',
      targetType: 'user',
      targetId: targetUid,
      metadata: {'reason': reason},
    );
  }

  /// ⚠️ IMPORTANTE: Essas 2 ações precisam de Cloud Functions (Admin SDK)
  Future<void> _adminDeleteAccount({
    required BuildContext context,
    required String targetUid,
    required String reason,
  }) async {
    try {
      await functions.httpsCallable('adminDeleteAccount').call({
        'targetUid': targetUid,
        'reason': reason,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Conta deletada com sucesso")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao deletar conta: $e")),
      );
    }
  }

  Future<void> _adminDeleteAndBan({
    required BuildContext context,
    required String targetUid,
    required String reason,
  }) async {
    try {
      await functions.httpsCallable('adminDeleteAndBan').call({
        'targetUid': targetUid,
        'reason': reason,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Conta deletada e email banido")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao banir conta: $e")),
      );
    }
  }
  Future<void> _adminPromoteToAdmin({
    required BuildContext context,
    required String targetUid,
    required String reason,
  }) async {
    try {
      await functions.httpsCallable('promoteUserToAdmin').call({
        'targetUid': targetUid,
      });

      await _logAdmin(
        action: 'users.promote_admin',
        targetType: 'user',
        targetId: targetUid,
        metadata: {'reason': reason},
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Usuário promovido a admin"),
          backgroundColor: vinhoProfundo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao promover a admin: $e")),
      );
    }
  }

  Future<void> _adminRemoveAdminRole({
    required BuildContext context,
    required String targetUid,
    required String reason,
  }) async {
    try {
      await functions.httpsCallable('removeUserAdminRole').call({
        'targetUid': targetUid,
      });

      await _logAdmin(
        action: 'users.remove_admin',
        targetType: 'user',
        targetId: targetUid,
        metadata: {'reason': reason},
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Função de admin removida"),
          backgroundColor: vinhoProfundo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao remover função de admin: $e")),
      );
    }
  }

  Future<void> _logAdmin({
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? metadata,
  }) async {
    final actorUid = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance.collection('audit_logs').add({
      'actorUid': actorUid,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'metadata': metadata ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> _askReason(
      BuildContext context, {
        required String title,
        required String hint,
      }) async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: vinhoIdentidade,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Confirmar"),
            ),
          ],
        );
      },
    );

    if (ok != true) return null;

    final reason = controller.text.trim();
    if (reason.isEmpty) return "Sem motivo informado";
    return reason;
  }

  Future<bool?> _confirmDanger(
      BuildContext context, {
        required String title,
        required String message,
        required String confirmText,
      }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB00020),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAdminActionsSheet(
      BuildContext context, {
        required String targetUid,
        required String userLabel,
        required bool isBanned,
        required bool canPost,
        String? targetEmail,
        required bool isTargetAdmin,
        required bool isTargetOwner,
      }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              color: Colors.white,

              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // cabeçalho fixo
                  ListTile(
                    title: Text(
                      userLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      "Ações de administração",
                      style: TextStyle(color: Colors.black.withOpacity(0.55)),
                    ),
                  ),
                  const Divider(height: 1),

                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          if (!isTargetAdmin)
                            ListTile(
                              leading: const Icon(Icons.verified_user_rounded),
                              title: const Text("Promover a admin"),
                              subtitle: const Text(
                                  "Dá permissão de administrador para esse usuário."),
                              onTap: () => Navigator.pop(sheetCtx, "promote_admin"),
                            ),

                          if (isTargetAdmin && !isTargetOwner)
                            ListTile(
                              leading: const Icon(Icons.person_off_rounded),
                              title: const Text("Remover função de admin"),
                              subtitle: const Text(
                                  "Remove permissões de admin e volta para usuário comum."),
                              onTap: () => Navigator.pop(sheetCtx, "remove_admin"),
                            ),

                          if (isTargetOwner)
                            const ListTile(
                              leading: Icon(Icons.lock_rounded),
                              title: Text("Owner"),
                              subtitle:
                              Text("Não é possível remover a função do Owner."),
                            ),

                          if (!isBanned)
                            ListTile(
                              leading: const Icon(Icons.block_rounded),
                              title: const Text("Banir usuário"),
                              onTap: () => Navigator.pop(sheetCtx, "ban"),
                            )
                          else
                            ListTile(
                              leading:
                              const Icon(Icons.check_circle_outline_rounded),
                              title: const Text("Desbanir usuário"),
                              onTap: () => Navigator.pop(sheetCtx, "unban"),
                            ),

                          if (canPost)
                            ListTile(
                              leading: const Icon(Icons.lock_outline_rounded),
                              title: const Text("Remover permissão de postar"),
                              onTap: () => Navigator.pop(sheetCtx, "restrict"),
                            )
                          else
                            ListTile(
                              leading: const Icon(Icons.lock_open_rounded),
                              title: const Text("Devolver permissão de postar"),
                              onTap: () => Navigator.pop(sheetCtx, "restore"),
                            ),

                          if (targetEmail != null)
                            ListTile(
                              leading: const Icon(Icons.email_outlined),
                              title: const Text("Entrar em contato"),
                              subtitle: Text(targetEmail),
                              onTap: () => Navigator.pop(sheetCtx, "contact"),
                            ),

                          const Divider(height: 1),

                          ListTile(
                            leading: const Icon(Icons.delete_forever_rounded,
                                color: Colors.red),
                            title: const Text("Deletar conta (apaga tudo)"),
                            subtitle: const Text(
                                "Remove dados e exclui do Authentication."),
                            onTap: () => Navigator.pop(sheetCtx, "delete_account"),
                          ),
                          ListTile(
                            leading: const Icon(Icons.gpp_bad_rounded,
                                color: Colors.red),
                            title: const Text("Deletar e banir (por email)"),
                            subtitle: const Text(
                                "A pessoa não cria outra conta com esse email."),
                            onTap: () => Navigator.pop(sheetCtx, "delete_and_ban"),
                          ),

                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (action == null) return;

    if (action == "contact") {
      final email = targetEmail;
      if (email == null || email.trim().isEmpty) return;
      await _contactByEmail(context, email);
      return;
    }
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null && myUid == targetUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Você não pode aplicar essa ação em você mesmo."),
          backgroundColor: vinhoProfundo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    if (action == "promote_admin") {
      final reason = await _askReason(
        context,
        title: "Promover a admin",
        hint: "Motivo (ex: nova liderança, confiança, etc.)",
      );
      if (reason == null) return;

      final ok = await _confirmDanger(
        context,
        title: "Confirmar promoção?",
        message: "Esse usuário passará a ter poderes de administrador no app.",
        confirmText: "PROMOVER",
      );
      if (ok != true) return;

      await _adminPromoteToAdmin(
        context: context,
        targetUid: targetUid,
        reason: reason,
      );
      return;
    }

    if (action == "remove_admin") {
      final reason = await _askReason(
        context,
        title: "Remover função de admin",
        hint: "Motivo (ex: saiu da liderança, medida disciplinar, etc.)",
      );
      if (reason == null) return;

      final ok = await _confirmDanger(
        context,
        title: "Confirmar remoção?",
        message:
        "Esse usuário vai perder poderes de administrador e voltará a ser usuário comum.",
        confirmText: "REMOVER",
      );
      if (ok != true) return;

      await _adminRemoveAdminRole(
        context: context,
        targetUid: targetUid,
        reason: reason,
      );
      return;
    }

    if (action == "ban") {
      final reason = await _askReason(
        context,
        title: "Banir usuário",
        hint: "Motivo do ban (ex: ofensas, spam, etc.)",
      );
      if (reason == null) return;

      await _adminBanUser(targetUid: targetUid, reason: reason);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Usuário banido"),
          backgroundColor: vinhoProfundo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    if (action == "unban") {
      final reason = await _askReason(
        context,
        title: "Desbanir usuário",
        hint: "Motivo (ex: revisão concluída)",
      );
      if (reason == null) return;

      await _adminUnbanUser(targetUid: targetUid, reason: reason);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Usuário desbanido"),
          backgroundColor: vinhoProfundo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    if (action == "restrict") {
      final reason = await _askReason(
        context,
        title: "Remover permissão de postar",
        hint: "Motivo (ex: spam, flood, etc.)",
      );
      if (reason == null) return;

      await _adminRestrictPosting(targetUid: targetUid, reason: reason);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Permissão de postar removida"),
          backgroundColor: vinhoProfundo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    if (action == "restore") {
      final reason = await _askReason(
        context,
        title: "Devolver permissão de postar",
        hint: "Motivo (ex: liberado após revisão)",
      );
      if (reason == null) return;

      await _adminRestorePosting(targetUid: targetUid, reason: reason);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Permissão de postar devolvida"),
          backgroundColor: vinhoProfundo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    if (action == "delete_account") {
      final reason = await _askReason(
        context,
        title: "Deletar conta",
        hint: "Motivo da exclusão",
      );
      if (reason == null) return;

      final ok = await _confirmDanger(
        context,
        title: "Confirma deletar a conta?",
        message:
        "Isso vai apagar os dados e excluir o usuário do Authentication. Não dá pra desfazer.",
        confirmText: "DELETAR",
      );
      if (ok != true) return;

      await _adminDeleteAccount(
        context: context,
        targetUid: targetUid,
        reason: reason,
      );
      return;
    }

    if (action == "delete_and_ban") {
      final reason = await _askReason(
        context,
        title: "Deletar e banir",
        hint: "Motivo do banimento",
      );
      if (reason == null) return;

      final ok = await _confirmDanger(
        context,
        title: "Confirma deletar e banir?",
        message:
        "Vai apagar tudo e bloquear o email. A pessoa não conseguirá criar outra conta com esse email.",
        confirmText: "DELETAR E BANIR",
      );
      if (ok != true) return;

      await _adminDeleteAndBan(
        context: context,
        targetUid: targetUid,
        reason: reason,
      );
      return;
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: paper,
        foregroundColor: vinhoProfundo,
        title: const Text(
          "Jovens Atos 29",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<bool>(
        future: _isAdminOrMod(),
        builder: (context, roleSnap) {
          final isAdmin = roleSnap.data == true;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('nickname')
                .limit(25)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Erro ao carregar usuários"));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: vinhoIdentidade),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(child: Text("Nenhum usuário encontrado"));
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String? targetEmail = _readEmail(data);

                  final targetUid = doc.id;

                  final String nome = _readText(data, 'nome', fallback: 'Membro');

                  final String nick =
                  _readText(data, 'nickname', fallback: 'membro');
                  final String username = '@$nick';

                  final String bio = _readText(data, 'bio', fallback: '');
                  final String? photoUrl = _readUrl(data, 'photoUrl');
                  final String? coverUrl = _readUrl(data, 'coverUrl');

                  final bool hasBio = bio.trim().isNotEmpty;
                  final bool bioLonga = bio.trim().length > kBioMaxChars;
                  final String bioPreview = hasBio ? _truncateBio(bio) : "";

                  final bool isBanned =
                      (data['status'] ?? 'active').toString() == 'banned';
                  final bool canPost = (data['canPost'] ?? true) == true;
                  final role = (data['role'] ?? 'user').toString();
                  final bool isTargetAdmin =
                      role == 'admin' || role == 'moderator' || role == 'owner';
                  final bool isTargetOwner = role == 'owner';
                  final Color statusColor = isBanned
                      ? const Color(0xFFB00020)
                      : const Color(0xFF0A7A3D);
                  final Color postColor = canPost
                      ? const Color(0xFF0A7A3D)
                      : const Color(0xFFB00020);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                      boxShadow: [_softShadow],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ===== CAPA =====
                          if (coverUrl != null)
                            SizedBox(
                              height: kCoverHeight,
                              width: double.infinity,
                              child: Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _coverFallback(),
                              ),
                            )
                          else
                            _coverFallback(),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _UserAvatar(photoUrl: photoUrl),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              nome,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                          if (isAdmin)
                                            IconButton(
                                              tooltip: "Ações de admin",
                                              constraints: const BoxConstraints(
                                                minWidth: 40,
                                                minHeight: 40,
                                              ),
                                              padding: EdgeInsets.zero,
                                              onPressed: () =>
                                                  _openAdminActionsSheet(
                                                    context,
                                                    targetUid: targetUid,
                                                    userLabel: "$nome ($username)",
                                                    isBanned: isBanned,
                                                    canPost: canPost,
                                                    targetEmail: targetEmail,
                                                    isTargetAdmin: isTargetAdmin,
                                                    isTargetOwner: isTargetOwner,
                                                  ),
                                              icon: Icon(
                                                Icons.more_vert_rounded,
                                                color: vinhoProfundo
                                                    .withOpacity(0.55),
                                              ),
                                            ),
                                        ],
                                      ),

                                      Text(
                                        username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.1,
                                          color: Colors.black.withOpacity(0.55),
                                        ),
                                      ),

                                      const SizedBox(height: 8),
                                      if (hasBio) ...[
                                        Text(
                                          bioPreview,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.25,
                                            color:
                                            Colors.black.withOpacity(0.62),
                                          ),
                                        ),
                                        if (bioLonga) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            "Ler mais ›",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: vinhoIdentidade
                                                  .withOpacity(0.85),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ] else ...[
                                        Text(
                                          "Sem bio",
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.25,
                                            color:
                                            Colors.black.withOpacity(0.35),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                      if (isAdmin) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 6,
                                          children: [
                                            _MiniTag(
                                              text: isBanned
                                                  ? "BANIDO"
                                                  : "ATIVO",
                                              color: statusColor,
                                            ),
                                            _MiniTag(
                                              text: canPost
                                                  ? "PODE POSTAR"
                                                  : "BLOQUEADO POSTAR",
                                              color: postColor,
                                            ),
                                            _MiniTag(
                                              text: isTargetAdmin
                                                  ? "ADMIN"
                                                  : "USUÁRIO",
                                              color: isTargetAdmin
                                                  ? vinhoIdentidade
                                                  : Colors.black54,
                                            ),
                                            if (isTargetOwner)
                                              _MiniTag(
                                                text: "OWNER",
                                                color: vinhoProfundo,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      height: kCoverHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            vinhoProfundo,
            vinhoIdentidade,
          ],
        ),
      ),
    );
  }
}

// ===== Avatar do usuário =====
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.photoUrl});
  final String? photoUrl;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: vinhoIdentidade.withOpacity(0.12),
        backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
        child: !hasPhoto
            ? const Icon(Icons.person, color: vinhoIdentidade, size: 28)
            : null,
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 11.5,
        color: color.withOpacity(0.95),
        letterSpacing: 0.3,
      ),
    );
  }
}
