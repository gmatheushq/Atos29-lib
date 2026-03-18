import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'feed_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  static const String kAdminCollection = "admin_notifications";
  static const String kPublicCollection = "public_notifications";

  bool _marking = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadIsAdmin();
    _markAllAsReadValid();
  }

  // =========================
  // ADMIN CHECK
  // =========================
  Future<void> _loadIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      final role = (data['role'] ?? '').toString().toLowerCase();

      final isAdmin = (data['isAdmin'] == true) ||
          (data['admin'] == true) ||
          (role == 'admin' || role == 'moderator' || role == 'owner');

      debugPrint("ROLE=$role  isAdmin=$isAdmin  uid=${user.uid}");

      if (mounted) setState(() => _isAdmin = isAdmin);
    } catch (e) {
      debugPrint("Erro _loadIsAdmin: $e");
    }
  }

  // =========================
  // "APAGAR PRA TODOS" (ADMIN) — só faz sentido pra admin_notifications
  // =========================
  Future<void> _confirmDeleteForAll(String docId, String source) async {
    if (!_isAdmin) return;
    if (source != kAdminCollection) return; // não apaga public/user por aqui

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Apagar para todos?"),
        content: const Text("Essa ação não pode ser desfeita"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Apagar",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: const Color.fromRGBO(78, 4, 5, 1),
              ),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection(kAdminCollection).doc(docId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notificação apagada para todos")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao apagar: $e")),
      );
    }
  }

  // =========================
  // "APAGAR PRA MIM" (SWIPE)
  // - user notifications: apaga o doc da subcollection do usuário
  // - public/admin: marca como deleted em notification_reads
  // =========================
  Stream<QuerySnapshot<Map<String, dynamic>>> _readsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notification_reads')
        .snapshots();
  }

  String _readKey(String source, String docId) => "${source}_$docId";

  Set<String> _deletedKeysFromReads(QuerySnapshot<Map<String, dynamic>> snap) {
    final out = <String>{};
    for (final d in snap.docs) {
      final m = d.data();
      final deletedAt = m['deletedAt'];
      final deleted = m['deleted'] == true;
      if (deleted || deletedAt != null) out.add(d.id);
    }
    return out;
  }

  Future<void> _deleteForMe({
    required String source,
    required String docId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // se for inbox do usuário, pode deletar o doc real
    if (source == 'user') {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(docId)
            .delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notificação apagada")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao apagar: $e")),
        );
      }
      return;
    }

    // public/admin: "apagar pra mim" via marker
    final key = _readKey(source, docId);
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notification_reads')
        .doc(key);

    try {
      await ref.set(
        {
          'deletedAt': FieldValue.serverTimestamp(),
          'deleted': true,
          'source': source,
          'docId': docId,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Notificação apagada"),
          action: SnackBarAction(
            label: "Desfazer",
            onPressed: () async {
              await ref.set(
                {
                  'deletedAt': FieldValue.delete(),
                  'deleted': FieldValue.delete(),
                },
                SetOptions(merge: true),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao apagar: $e")),
      );
    }
  }

  // =========================
  // MARK AS READ (válidas) — somente public + (se admin) admin_notifications
  // =========================
  Future<void> _markAllAsReadValid() async {
    if (_marking) return;
    _marking = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // pega deletadas do usuário (pra não marcar como lida algo já "apagado pra mim")
      final deletedSnap = await firestore
          .collection('users')
          .doc(uid)
          .collection('notification_reads')
          .get();

      final deletedKeys = <String>{};
      for (final d in deletedSnap.docs) {
        final m = d.data();
        if (m['deleted'] == true || m['deletedAt'] != null) deletedKeys.add(d.id);
      }

      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final cutoffTs = Timestamp.fromDate(cutoff);

      final now = DateTime.now();
      final batch = firestore.batch();
      int writes = 0;

      // ---------- PUBLIC ----------
      final publicSnap = await firestore
          .collection(kPublicCollection)
          .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
          .get();

      for (final doc in publicSnap.docs) {
        final key = _readKey(kPublicCollection, doc.id);
        if (deletedKeys.contains(key)) continue;

        final m = doc.data();

        final createdAt = _asDateTime(m['createdAt']);
        if (createdAt == null) continue;

        final expiresAt =
            _asDateTime(m['expiresAt']) ?? createdAt.add(const Duration(days: 30));
        if (!expiresAt.isAfter(now)) continue;

        final ref = firestore
            .collection('users')
            .doc(uid)
            .collection('notification_reads')
            .doc(key);

        batch.set(
          ref,
          {
            'readAt': FieldValue.serverTimestamp(),
            'source': kPublicCollection,
            'docId': doc.id,
          },
          SetOptions(merge: true),
        );
        writes++;
      }

      // ---------- ADMIN (só se admin) ----------
      if (_isAdmin) {
        final adminSnap = await firestore
            .collection(kAdminCollection)
            .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
            .get();

        for (final doc in adminSnap.docs) {
          final key = _readKey(kAdminCollection, doc.id);
          if (deletedKeys.contains(key)) continue;

          final m = doc.data();

          final createdAt = _asDateTime(m['createdAt']);
          if (createdAt == null) continue;

          final expiresAt =
              _asDateTime(m['expiresAt']) ?? createdAt.add(const Duration(days: 30));
          if (!expiresAt.isAfter(now)) continue;

          final ref = firestore
              .collection('users')
              .doc(uid)
              .collection('notification_reads')
              .doc(key);

          batch.set(
            ref,
            {
              'readAt': FieldValue.serverTimestamp(),
              'source': kAdminCollection,
              'docId': doc.id,
            },
            SetOptions(merge: true),
          );
          writes++;
        }
      }

      if (writes > 0) {
        await batch.commit();
      }
    } catch (_) {}
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffTs = Timestamp.fromDate(cutoff);

    return Scaffold(
      backgroundColor: atosBg,
      appBar: AppBar(
        backgroundColor: atosBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: atosDeep),
        title: const Text(
          "Notificações",
          style: TextStyle(fontWeight: FontWeight.w900, color: atosPrimary),
        ),
      ),
      body: Builder(
        builder: (context) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) {
            return _stateMessage("Você precisa estar logado.");
          }

          // streams
          final publicQuery = firestore
              .collection(kPublicCollection)
              .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
              .orderBy('createdAt', descending: true);

          final userQuery = firestore
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .orderBy('createdAt', descending: true);

          final adminQuery = firestore
              .collection(kAdminCollection)
              .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
              .orderBy('createdAt', descending: true);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _readsStream(uid),
            builder: (context, readsSnap) {
              final deletedKeys = (readsSnap.hasData)
                  ? _deletedKeysFromReads(readsSnap.data!)
                  : <String>{};

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: publicQuery.snapshots(),
                builder: (context, publicSnap) {
                  if (publicSnap.hasError) {
                    return _stateMessage(
                        "Erro ao carregar notificações\n${publicSnap.error}");
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: userQuery.snapshots(),
                    builder: (context, userSnap) {
                      if (userSnap.hasError) {
                        return _stateMessage(
                            "Erro ao carregar notificações\n${userSnap.error}");
                      }

                      // se for admin, adiciona mais um stream; se não, segue com lista
                      if (_isAdmin) {
                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: adminQuery.snapshots(),
                          builder: (context, adminSnap) {
                            if (adminSnap.hasError) {
                              return _stateMessage(
                                  "Erro ao carregar notificações\n${adminSnap.error}");
                            }
                            return _buildList(
                              deletedKeys: deletedKeys,
                              publicDocs: publicSnap.data?.docs ?? const [],
                              userDocs: userSnap.data?.docs ?? const [],
                              adminDocs: adminSnap.data?.docs ?? const [],
                            );
                          },
                        );
                      }

                      return _buildList(
                        deletedKeys: deletedKeys,
                        publicDocs: publicSnap.data?.docs ?? const [],
                        userDocs: userSnap.data?.docs ?? const [],
                        adminDocs: const [],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildList({
    required Set<String> deletedKeys,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> publicDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> adminDocs,
  }) {
    final now = DateTime.now();

    // normaliza tudo em uma lista única
    final items = <_NotifItem>[];

    // public
    for (final d in publicDocs) {
      final m = d.data();
      final createdAt = _asDateTime(m['createdAt']);
      if (createdAt == null) continue;

      final expiresAt =
          _asDateTime(m['expiresAt']) ?? createdAt.add(const Duration(days: 30));
      if (!expiresAt.isAfter(now)) continue;

      final key = _readKey(kPublicCollection, d.id);
      if (deletedKeys.contains(key)) continue;

      items.add(_NotifItem(
        source: kPublicCollection,
        docId: d.id,
        data: m,
        createdAt: createdAt,
        expiresAt: expiresAt,
      ));
    }

    // user inbox (não expira automaticamente, mas se tiver expiresAt usa)
    for (final d in userDocs) {
      final m = d.data();
      final createdAt = _asDateTime(m['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);

      final expiresAt =
          _asDateTime(m['expiresAt']) ?? createdAt.add(const Duration(days: 3650)); // "quase nunca"
      // não filtra por expiração pro user inbox; mas se vier expiresAt no doc, respeita
      if (_asDateTime(m['expiresAt']) != null && !expiresAt.isAfter(now)) continue;

      items.add(_NotifItem(
        source: 'user',
        docId: d.id,
        data: m,
        createdAt: createdAt,
        expiresAt: expiresAt,
      ));
    }

    // admin
    for (final d in adminDocs) {
      final m = d.data();
      final createdAt = _asDateTime(m['createdAt']);
      if (createdAt == null) continue;

      final expiresAt =
          _asDateTime(m['expiresAt']) ?? createdAt.add(const Duration(days: 30));
      if (!expiresAt.isAfter(now)) continue;

      final key = _readKey(kAdminCollection, d.id);
      if (deletedKeys.contains(key)) continue;

      items.add(_NotifItem(
        source: kAdminCollection,
        docId: d.id,
        data: m,
        createdAt: createdAt,
        expiresAt: expiresAt,
      ));
    }

    // ordena por createdAt desc
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (items.isEmpty) {
      return _stateMessage("Nenhuma notificação nos últimos 30 dias");
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
          child: Text(
            "As notificações expiram automaticamente em 30 dias",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.45),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              final m = item.data;

              final String title =
              (m['title'] ?? m['titulo'] ?? "Notificação").toString();
              final String body =
              (m['body'] ?? m['texto'] ?? m['message'] ?? "").toString();

              final Color color = _asColor(m['color']) ?? atosPrimary;
              final IconData icon = _iconFromName(
                (m['icon'] ?? m['icone'] ?? "notifications").toString(),
              );

              // admin delete icon só aparece se:
              // - user é admin
              // - item veio do admin_notifications
              final canAdminDeleteForAll =
                  _isAdmin && item.source == kAdminCollection;

              return Dismissible(
                key: ValueKey("notif_${item.source}_${item.docId}"),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(78, 4, 5, 0.85),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 18),
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                confirmDismiss: (_) async => true,
                onDismissed: (_) => _deleteForMe(source: item.source, docId: item.docId),
                child: _NotificationCard(
                  docId: item.docId,
                  isAdmin: canAdminDeleteForAll,
                  onDelete: () => _confirmDeleteForAll(item.docId, item.source),
                  title: title,
                  body: body,
                  icon: icon,
                  color: color,
                  createdAt: item.createdAt,
                  expiresAt: item.expiresAt,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // =========================
  // HELPERS
  // =========================
  static Widget _stateMessage(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black.withOpacity(0.55),
          ),
        ),
      ),
    );
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static Color? _asColor(dynamic v) {
    if (v == null) return null;
    if (v is int) return Color(v);
    return null;
  }

  static IconData _iconFromName(String name) {
    const map = <String, IconData>{
      "notifications": Icons.notifications_rounded,
      "campaign": Icons.campaign_rounded,
      "info": Icons.info_rounded,
      "warning": Icons.warning_amber_rounded,
      "event": Icons.event_rounded,
      "church": Icons.church_rounded,
      "favorite": Icons.favorite_rounded,
      "auto_stories": Icons.auto_stories_rounded,
    };
    return map[name] ?? Icons.notifications_rounded;
  }
}

class _NotifItem {
  _NotifItem({
    required this.source,
    required this.docId,
    required this.data,
    required this.createdAt,
    required this.expiresAt,
  });

  final String source; // 'public_notifications' | 'admin_notifications' | 'user'
  final String docId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime expiresAt;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.docId,
    required this.isAdmin,
    required this.onDelete,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.createdAt,
    required this.expiresAt,
    this.onTap,
  });

  final String docId;
  final bool isAdmin; // aqui agora significa "pode apagar pra todos?"
  final VoidCallback onDelete;

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final DateTime createdAt;
  final DateTime expiresAt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shadow = BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 22,
      offset: const Offset(0, 10),
    );

    final createdStr = _formatDate(context, createdAt);
    final expiresStr = _formatDate(context, expiresAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [shadow],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    icon,
                    color: color.withOpacity(0.95),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                letterSpacing: -0.2,
                                color: Color(0xFF2B2B2B),
                              ),
                            ),
                          ),
                          if (isAdmin)
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: onDelete, // apagar para todos
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 8, top: 2, right: 2, bottom: 2),
                                child: Icon(
                                  Icons.delete_rounded,
                                  size: 20,
                                  color: Colors.red.withOpacity(0.85),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (body.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: Colors.black.withOpacity(0.62),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        "Enviado: $createdStr • Expira: $expiresStr",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: Colors.black.withOpacity(0.50),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime dt) {
    final loc = MaterialLocalizations.of(context);
    return "${loc.formatDecimal(dt.day).padLeft(2, '0')}/"
        "${loc.formatDecimal(dt.month).padLeft(2, '0')}/"
        "${dt.year}";
  }
}
