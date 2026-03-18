// menu_page.dart (ou onde estiver o MenuPage + CatecismoPage)

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'sobre_app_page.dart';
import 'estatuto_page.dart';
import 'atos29_page.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'pedidos_oracoes.dart';
import 'users_list_page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

const atosPrimary = Color(0xFF6A0F0F);
const atosDeep = Color(0xFF3A0808);
const atosBg = Color(0xFFFAF9F7);

const String _kPrayerLastReadMsKey = "prayer_last_read_ms";

const String _kSupportEmail = "atos29.app@gmail.com";

class CatecismoPage extends StatefulWidget {
  const CatecismoPage({super.key});

  @override
  State<CatecismoPage> createState() => _CatecismoPageState();
}

class _CatecismoPageState extends State<CatecismoPage> {
  late final WebViewController _controller;
  bool _loading = true;
  WebResourceError? _error;

  static const String _url =
      "https://www.vatican.va/archive/cathechism_po/index_new/prima-pagina-cic_po.html";

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = err;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(_url));

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMixedContentMode(MixedContentMode.alwaysAllow);
    }
  }

  Future<void> _abrirNoNavegador() async {
    final uri = Uri.parse(_url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: atosBg,
      appBar: AppBar(
        backgroundColor: atosBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: atosDeep),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Catecismo",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.85),
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Recarregar",
            onPressed: () => _controller.reload(),
            icon: Icon(Icons.refresh_rounded,
                color: Colors.black.withOpacity(0.55)),
          ),
          IconButton(
            tooltip: "Abrir no navegador",
            onPressed: _abrirNoNavegador,
            icon: Icon(Icons.open_in_new_rounded,
                color: Colors.black.withOpacity(0.55)),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: atosBg.withOpacity(0.35),
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: atosPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_error != null)
            Positioned.fill(
              child: Container(
                color: atosBg,
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            color: atosPrimary.withOpacity(0.85), size: 34),
                        const SizedBox(height: 10),
                        Text(
                          "Não foi possível carregar no app",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.82),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Abra no navegador para acessar normalmente",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withOpacity(0.50),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: atosPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _abrirNoNavegador,
                                child: const Text(
                                  "Abrir no navegador",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _controller.reload(),
                          child: Text(
                            "Tentar novamente",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black.withOpacity(0.70),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  static const List<String> _topicsToClear = ["all", "admins"];

  Widget _prayerUnreadBadge() {
    return FutureBuilder<int>(
      future: SharedPreferences.getInstance()
          .then((p) => p.getInt(_kPrayerLastReadMsKey) ?? 0),
      builder: (context, snapPrefs) {
        final lastReadMs = snapPrefs.data ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("pedidos_oracoes")
              .orderBy("createdAt", descending: true)
              .limit(25)
              .snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];

            int unread = 0;
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              final ts = data["createdAt"];
              if (ts is Timestamp && ts.millisecondsSinceEpoch > lastReadMs) {
                unread++;
              }
            }

            if (unread <= 0) return const SizedBox.shrink();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: atosPrimary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: atosPrimary.withOpacity(0.22)),
              ),
              child: Text(
                "+$unread",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: atosPrimary.withOpacity(0.95),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _markPrayersAsRead() async {
    final q = await FirebaseFirestore.instance
        .collection("pedidos_oracoes")
        .orderBy("createdAt", descending: true)
        .limit(1)
        .get();

    int newestMs = DateTime.now().millisecondsSinceEpoch;
    if (q.docs.isNotEmpty) {
      final data = q.docs.first.data();
      final ts = data["createdAt"];
      if (ts is Timestamp) newestMs = ts.millisecondsSinceEpoch;
    }

    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getInt(_kPrayerLastReadMsKey) ?? 0;
    if (newestMs > old) {
      await prefs.setInt(_kPrayerLastReadMsKey, newestMs);
    }
  }

  Future<void> _abrirEmailSuporte(BuildContext context) async {
    final uri = Uri(
      scheme: "mailto",
      path: _kSupportEmail,
      queryParameters: {"subject": "Suporte • Atos 29"},
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível abrir o app de e-mail")),
      );
    }
  }

  // ✅ NOVO: copiar e-mail
  Future<void> _copiarEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _kSupportEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("E-mail de suporte copiado!")),
      );
    }
  }

  void _abrirSuporteAjuda(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.support_agent_rounded,
                      size: 30,
                      color: atosPrimary.withOpacity(0.95),
                    ),

                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Suporte / Ajuda",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.black.withOpacity(0.84),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _kSupportEmail,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: "Fechar",
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded,
                          color: Colors.black.withOpacity(0.45)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: atosPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _abrirEmailSuporte(context);
                        },
                        icon: const Icon(Icons.email_rounded,
                            color: Colors.white),
                        label: const Text(
                          "Enviar e-mail",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side:
                          BorderSide(color: Colors.black.withOpacity(0.12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _copiarEmail(context);
                        },
                        icon: Icon(Icons.copy_rounded,
                            color: Colors.black.withOpacity(0.70)),
                        label: Text(
                          "Copiar e-mail",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.78),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Se preferir, mande um print do problema e descreva o que aconteceu.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Colors.black.withOpacity(0.48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _clearPushSession() async {
    try {
      for (final t in _topicsToClear) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(t);
      }
    } catch (_) {}

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _clearLocalSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
  }

  Future<void> _secureLogout(BuildContext context) async {
    final googleSignIn = GoogleSignIn();

    await _clearPushSession();
    await _clearLocalSessionData();

    await FirebaseAuth.instance.signOut();

    try {
      await googleSignIn.signOut();
    } catch (_) {}
    try {
      await googleSignIn.disconnect();
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget item({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
      Widget? trailingBeforeChevron,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: atosPrimary, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: Colors.black.withOpacity(0.82),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: Colors.black.withOpacity(0.48),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingBeforeChevron != null) ...[
                trailingBeforeChevron,
                const SizedBox(width: 10),
              ],
              Icon(Icons.chevron_right_rounded,
                  color: Colors.black.withOpacity(0.35)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: atosBg,
      appBar: AppBar(
        backgroundColor: atosBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: atosDeep),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Menu",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.85),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: [
            // ===== INSTITUCIONAL =====
            Text(
              "Institucional",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black.withOpacity(0.60),
              ),
            ),
            const SizedBox(height: 10),
            item(
              icon: Icons.description_rounded,
              title: "Estatuto Atos 29",
              subtitle: "Identidade, missão e fundamentos",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EstatutoPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            item(
              icon: Icons.auto_stories_rounded,
              title: "Atos 29",
              subtitle: "A continuidade da Igreja viva",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Atos29Page()),
                );
              },
            ),
            const SizedBox(height: 12),
            item(
              icon: Icons.menu_book_rounded,
              title: "Catecismo da Igreja Católica",
              subtitle: "Doutrina e ensinamentos oficiais",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CatecismoPage()),
                );
              },
            ),
            const SizedBox(height: 22),

            // ===== COMUNIDADE =====
            Text(
              "Comunidade",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black.withOpacity(0.60),
              ),
            ),
            const SizedBox(height: 10),
            item(
              icon: Icons.groups_rounded,
              title: "Jovens Atos 29",
              subtitle: "Acessar a página da comunidade",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsersListPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            item(
              icon: Icons.volunteer_activism_rounded,
              title: "Pedidos de Oração",
              subtitle: "Intenções da comunidade",
              trailingBeforeChevron: _prayerUnreadBadge(),
              onTap: () async {
                await _markPrayersAsRead();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PedidosOracoesPage()),
                );
              },
            ),
            const SizedBox(height: 22),

            // ===== APP =====
            Text(
              "Aplicativo",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black.withOpacity(0.60),
              ),
            ),
            const SizedBox(height: 10),
            item(
              icon: Icons.info_outline_rounded,
              title: "Sobre o App",
              subtitle: "Versão e informações",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SobreAppPage()),
                );
              },

            ),
            const SizedBox(height: 12),
            item(
              icon: Icons.support_agent_rounded,
              title: "Suporte / Ajuda",
              subtitle: "Fale com a gente: $_kSupportEmail",
              onTap: () => _abrirSuporteAjuda(context),
            ),
            const SizedBox(height: 12),

            item(
              icon: Icons.logout_rounded,
              title: "Sair",
              subtitle: "Encerrar sessão",
              onTap: () async {
                Navigator.pop(context);
                await _secureLogout(context);
              },
            ),

            const SizedBox(height: 12),

            item(
              icon: Icons.delete_forever_rounded,
              title: "Excluir conta",
              subtitle: "Apagar permanentemente seus dados",
              onTap: () async {
                Navigator.pop(context);
                if (!context.mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeleteAccountPage()),
                );
              },
            ),

            const SizedBox(height: 26),
            Center(
              child: Text(
                "ATOS 29 • v1.0",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.black.withOpacity(0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  bool _hasPasswordProvider = false;
  bool _hasGoogleProvider = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final providers = user?.providerData ?? [];
    _hasPasswordProvider = providers.any((p) => p.providerId == "password");
    _hasGoogleProvider = providers.any((p) => p.providerId == "google.com");
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteDocsWhereFieldEquals({
    required String collection,
    required String field,
    required String uid,
  }) async {
    final fs = FirebaseFirestore.instance;

    while (true) {
      final q = await fs
          .collection(collection)
          .where(field, isEqualTo: uid)
          .limit(250)
          .get();

      if (q.docs.isEmpty) break;

      final batch = fs.batch();
      for (final d in q.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteSubcollectionDocs({
    required DocumentReference<Map<String, dynamic>> parentRef,
    required String subcollection,
  }) async {
    final fs = FirebaseFirestore.instance;

    while (true) {
      final q = await parentRef.collection(subcollection).limit(250).get();
      if (q.docs.isEmpty) break;

      final batch = fs.batch();
      for (final d in q.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteUserDataFromFirestore(String uid) async {
    final fs = FirebaseFirestore.instance;

    final userRef = fs.collection("users").doc(uid);

    await _deleteSubcollectionDocs(
      parentRef: userRef,
      subcollection: "daily_missions",
    ).catchError((_) {});

    await _deleteDocsWhereFieldEquals(
      collection: "pedidos_oracoes",
      field: "userId",
      uid: uid,
    ).catchError((_) {});
    await _deleteDocsWhereFieldEquals(
      collection: "pedidos_oracoes",
      field: "uid",
      uid: uid,
    ).catchError((_) {});
    await _deleteDocsWhereFieldEquals(
      collection: "pedidos_oracoes",
      field: "authorId",
      uid: uid,
    ).catchError((_) {});

    await _deleteDocsWhereFieldEquals(
      collection: "posts",
      field: "uid",
      uid: uid,
    ).catchError((_) {});

    await userRef.delete().catchError((_) {});
  }

  Future<void> _reauthenticate(User user) async {
    if (_hasPasswordProvider) {
      final password = _passCtrl.text.trim();
      if (password.isEmpty) {
        throw FirebaseAuthException(
          code: "missing-password",
          message: "Digite sua senha para confirmar",
        );
      }

      final email = user.email?.trim();
      if (email == null || email.isEmpty) {
        throw FirebaseAuthException(
          code: "missing-email",
          message: "Não foi possível obter o e-mail da sua conta. Fale com o suporte",
        );
      }

      final cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      return;
    }

    if (_hasGoogleProvider) {
      final googleSignIn = GoogleSignIn();
      final gUser = await googleSignIn.signIn();
      if (gUser == null) {
        throw FirebaseAuthException(
          code: "google-cancelled",
          message: "Login do Google cancelado",
        );
      }
      final gAuth = await gUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await user.reauthenticateWithCredential(cred);
      return;
    }

    throw FirebaseAuthException(
      code: "unsupported-provider",
      message:
      "Seu método de login não é suportado para exclusão aqui. Entre em contato com o suporte",
    );
  }


  Future<void> _clearPushAndLocal() async {
    // tópicos + token
    try {
      for (final t in ["all", "admins"]) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(t);
      }
    } catch (_) {}

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}

    // prefs
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
  }

  Future<void> _confirmAndDelete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack("Você não está logado");
      return;
    }

    if (!_hasPasswordProvider && !_hasGoogleProvider) {
      _snack(
        "Sua conta usa um método de login diferente (ex.: Apple). Para excluir, reautentique pelo mesmo método ou fale com o suporte",
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Excluir conta?"),
          content: const Text(
            "Isso vai apagar permanentemente sua conta e seus dados. Essa ação não pode ser desfeita",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "Excluir",
                style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() => _loading = true);

    try {
      await _reauthenticate(user);

      final uid = user.uid;

      await _deleteUserDataFromFirestore(uid);

      await user.delete();

      final googleSignIn = GoogleSignIn();
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      try {
        await googleSignIn.disconnect();
      } catch (_) {}

      await _clearPushAndLocal();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == "wrong-password") {
        _snack("Senha incorreta.");
      } else if (e.code == "missing-password") {
        _snack("Digite sua senha para confirmar.");
      } else if (e.code == "missing-email") {
        _snack("Não foi possível obter o e-mail da conta. Fale com o suporte.");
      } else if (e.code == "google-cancelled") {
        _snack("Você cancelou o login do Google.");
      } else if (e.code == "requires-recent-login") {
        _snack("Faça login novamente e tente excluir.");
      } else {
        _snack(e.message ?? "Erro ao excluir conta.");
      }
    } catch (_) {
      if (mounted) _snack("Não foi possível excluir a conta. Tente novamente.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: atosBg,
      appBar: AppBar(
        backgroundColor: atosBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: atosDeep),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "Excluir conta",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.85),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasPasswordProvider
                          ? "Confirme sua senha"
                          : "Confirme sua identidade",
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hasPasswordProvider
                          ? "Para sua segurança, digite sua senha para excluir a conta."
                          : "Para sua segurança, vamos pedir uma confirmação pelo Google para excluir a conta.",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_hasPasswordProvider)
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        enabled: !_loading,
                        decoration: InputDecoration(
                          labelText: "Senha",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          suffixIcon: IconButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                      ),

                    if (!_hasPasswordProvider && _hasGoogleProvider)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: atosPrimary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: atosPrimary.withOpacity(0.14)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.g_mobiledata_rounded,
                                size: 26,
                                color: atosPrimary.withOpacity(0.9)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Ao tocar em excluir, vai abrir a confirmação do Google.",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black.withOpacity(0.65),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _loading ? null : _confirmAndDelete,
                icon: _loading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.delete_forever_rounded,
                    color: Colors.white),
                label: Text(
                  _loading ? "Excluindo..." : "Excluir conta permanentemente",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Atenção: essa ação não pode ser desfeita.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: Colors.black.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
