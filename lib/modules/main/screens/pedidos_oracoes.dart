// pedidos_oracoes.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class _CandleBackgroundBlurred extends StatelessWidget {
  const _CandleBackgroundBlurred();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // base bem escura (pra manter contraste)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF140606),
                  Color(0xFF2A0B0B),
                  Color(0xFF120505),
                ],
              ),
            ),
          ),

          IgnorePointer(
            child: Opacity(
              opacity: 0.60,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: const _AnimatedCandleArt(),
              ),
            ),
          ),

          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.15),
                  radius: 1.1,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedCandleArt extends StatefulWidget {
  const _AnimatedCandleArt();

  @override
  State<_AnimatedCandleArt> createState() => _AnimatedCandleArtState();
}

class _AnimatedCandleArtState extends State<_AnimatedCandleArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value; // 0..1
        return CustomPaint(
          painter: _CandlePainter(t: t),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.50, size.height * 0.8);

    final candleW = size.shortestSide * 0.50;
    final candleH = size.shortestSide * 0.94;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center + Offset(0, candleH * 0.08),
        width: candleW,
        height: candleH,
      ),
      Radius.circular(candleW * 0.20),
    );

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.55),
          Colors.white.withOpacity(0.22),
          Colors.white.withOpacity(0.40),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(bodyRect.outerRect);

    canvas.drawRRect(bodyRect, bodyPaint);

    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawRRect(bodyRect.inflate(candleW * 0.35), glowPaint);

    // pavio
    final wickStart = center + Offset(0, -candleH * 0.48);
    final wickEnd = wickStart + Offset(0, candleH * 0.11);
    final wickPaint = Paint()
      ..strokeWidth = candleW * 0.06
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withOpacity(0.35);
    canvas.drawLine(wickStart, wickEnd, wickPaint);

    // chama (anima)
    final flicker = math.sin(t * math.pi * 2) * 0.5 + 0.5; // 0..1
    final sway = math.sin(t * math.pi * 2) * (candleW * 0.07); // lateral

    final flameCenter = wickStart + Offset(sway, -candleH * 0.10);
    final flameH = candleH * (0.30 + flicker * 0.3);
    final flameW = candleW * (0.22 + flicker * 0.03);

    final flamePath = Path();
    flamePath.moveTo(flameCenter.dx, flameCenter.dy - flameH * 0.55);
    flamePath.quadraticBezierTo(
      flameCenter.dx + flameW * 0.55,
      flameCenter.dy - flameH * 0.10,
      flameCenter.dx,
      flameCenter.dy + flameH * 0.45,
    );
    flamePath.quadraticBezierTo(
      flameCenter.dx - flameW * 0.55,
      flameCenter.dy - flameH * 0.10,
      flameCenter.dx,
      flameCenter.dy - flameH * 0.55,
    );
    flamePath.close();

    // chama: gradiente quente
    final flamePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.25),
        radius: 0.95,
        colors: [
          const Color(0xFFFFF3C4).withOpacity(0.90),
          const Color(0xFFFFB74D).withOpacity(0.72),
          const Color(0xFFFF6F00).withOpacity(0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCenter(
        center: flameCenter,
        width: flameW * 2.8,
        height: flameH * 2.8,
      ));

    // glow da chama
    final flameGlow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32)
      ..color = const Color(0xFFFFC107).withOpacity(0.18);

    canvas.drawPath(flamePath, flameGlow);
    canvas.drawPath(flamePath, flamePaint);

    // “luz” espalhando no fundo
    final lightPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80)
      ..color = const Color(0xFFFFD180).withOpacity(0.10);

    canvas.drawCircle(flameCenter + const Offset(0, 10), candleW * 1.6, lightPaint);
  }

  @override
  bool shouldRepaint(covariant _CandlePainter oldDelegate) => oldDelegate.t != t;
}


const atosPrimary = Color(0xFF6A0F0F); // vinho identidade
const atosDeep = Color(0xFF79151A); // vinho profundo
const atosAccent = Color(0xFF8E2A2A); // vinho destaque

class PedidosOracoesPage extends StatefulWidget {
  const PedidosOracoesPage({super.key});

  @override
  State<PedidosOracoesPage> createState() => _PedidosOracoesPageState();
}

class _PedidosOracoesPageState extends State<PedidosOracoesPage> {
  final _firestore = FirebaseFirestore.instance;
  final _textCtrl = TextEditingController();
  bool _sending = false;
  bool _isAdmin = false;

  final List<String> _sugestoes = const [
    "Por uma aprovação",
    "Por uma entrevista de emprego",
    "Por cura e libertação",
    "Por um familiar doente",
    "Por paz na família",
    "Por reconciliação",
    "Por um casamento",
    "Por vocação",
    "Por força na fé",
    "Por uma ação de graças",
    "Pela Igreja",
    "Pelos jovens",
  ];

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.12),
    blurRadius: 26,
    offset: const Offset(0, 16),
  );

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection("users").doc(user.uid).get();
      final role = (doc.data()?["role"] ?? "").toString();
      final isAdmin = ["admin", "moderator", "owner"].contains(role);

      if (!mounted) return;
      setState(() => _isAdmin = isAdmin);
    } catch (_) {}
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _applySugestao(String s) {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    setState(() {
      final t = _textCtrl.text.trim();
      _textCtrl.text = t.isEmpty ? s : "$t\n$s";
      _textCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _textCtrl.text.length),
      );
    });
  }

  void _openComposerSheet() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.58),
      builder: (_) {
        return _GlassSheet(
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 14,
                bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Handle(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _IconBadge(
                        icon: Icons.volunteer_activism_rounded,
                        color: atosPrimary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Escreva sua intenção",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -0.2,
                            color: Colors.black.withOpacity(0.82),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PremiumField(
                    controller: _textCtrl,
                    label: "Intenção",
                    hint: "Escreva do seu jeito…",
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Sugestões",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        color: Colors.black.withOpacity(0.50),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _sugestoes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final s = _sugestoes[i];
                        return _SugestaoChip(
                          text: s,
                          onTap: () => _applySugestao(s),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _PrimaryCTA(
                          label: _sending ? "ENVIANDO..." : "ENVIAR",
                          color: atosPrimary,
                          onTap: _sending ? null : _sendPedidoAnonimo,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Text(
                    "Seu pedido será enviado de forma anônima",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.40),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendPedidoAnonimo() async {
    final raw = _textCtrl.text.trim();
    if (raw.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Faça login para enviar um pedido")),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await _firestore.collection("pedidos_oracoes").add({
        "texto": raw,
        "createdAt": FieldValue.serverTimestamp(),
        "uid": user.uid,
        "anonimo": true,
      });

      _textCtrl.clear();
      if (mounted) Navigator.pop(context);
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível enviar agora")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteIfMine(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? "";
    if (uid.isEmpty) return;

    final data = doc.data() as Map<String, dynamic>? ?? {};
    final owner = (data["uid"] ?? "").toString();
    if (owner != uid) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Apagar pedido?"),
        content: const Text("Isso remove o pedido do mural"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Apagar"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await doc.reference.delete();
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  Future<void> _deleteAsAdmin(DocumentSnapshot doc) async {
    if (!_isAdmin) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Remover pedido (moderação)?"),
        content: const Text(
          "Você está removendo um pedido de outra pessoa.\nEssa ação não pode ser desfeita.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remover"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await doc.reference.delete();
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: atosDeep,
      body: Stack(
        children: [
          const _CandleBackgroundBlurred(),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: false,
                  floating: false,
                  toolbarHeight: 120,

                  leading: Padding(
                    padding: const EdgeInsets.only(left: 6, top: 4),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white.withOpacity(0.95),
                      splashRadius: 22,
                      tooltip: "Voltar",
                    ),
                  ),

                  centerTitle: true,
                  title: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Image.asset(
                      "assets/images/logo_atos29_branco.png",
                      height: 130,
                      fit: BoxFit.contain,
                    ),
                  ),
                  actions: const [],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                    child: _HeroWelcomeCard(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: Row(
                      children: [
                        Text(
                          "Mural de intenções",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -0.2,
                            color: Colors.white.withOpacity(0.92),
                          ),
                        ),
                        const Spacer(),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 18,
                              color: Colors.white.withOpacity(0.80),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Anônimo",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: Colors.white.withOpacity(0.75),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection("pedidos_oracoes")
                        .orderBy("createdAt", descending: true)
                        .limit(60)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Center(
                            child: Text(
                              "Erro ao carregar",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        );
                      }
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 28),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
                          child: _EmptyState(onNew: _openComposerSheet),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
                        child: Column(
                          children: docs.map(_pedidoCard).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            right: 18,
            bottom: 18,
            child: _PremiumFab(onTap: _openComposerSheet),
          ),
        ],
      ),
    );
  }

  Widget _pedidoCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final texto = (data["texto"] ?? "").toString();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final owner = (data["uid"] ?? "").toString();

    final isMine = uid.isNotEmpty && owner == uid;
    final canDeleteAsAdmin = _isAdmin && uid.isNotEmpty && !isMine;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [_softShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.white.withOpacity(0.10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _CandleIcon(),
                      const Spacer(),

                      if (isMine)
                        _DeleteAction(
                          label: "Apagar",
                          tone: _DeleteTone.mine,
                          onTap: () => _deleteIfMine(doc),
                        )
                      else if (canDeleteAsAdmin)
                        _DeleteAction(
                          label: "Remover",
                          tone: _DeleteTone.admin,
                          onTap: () => _deleteAsAdmin(doc),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    texto,
                    style: TextStyle(
                      fontSize: 14.2,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.90),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ================== FUNDO VINHO (SEM “RETÂNGULOS”) ==================

class _WineBackgroundCleanNoRects extends StatelessWidget {
  const _WineBackgroundCleanNoRects();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [atosDeep, atosPrimary, atosAccent],
                stops: [0.0, 0.56, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.25),
                radius: 1.25,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.38),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ================== HEADER (CITAÇÃO) ==================

class _HeroWelcomeCard extends StatelessWidget {
  const _HeroWelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            constraints: const BoxConstraints(minHeight: 140),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "“Nada vale tanto como a oração. Ela torna possível aquilo que é impossível, fácil o que é difícil.”",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 14.5,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    "- São João Crisóstomo",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Ainda não tem intenções aqui",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Colors.white.withOpacity(0.92),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Escreva a primeira e a comunidade já acolhe em oração",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: Colors.white.withOpacity(0.80),
            ),
          ),
          const SizedBox(height: 14),
          _GlassSmallCta(
            label: "Escrever",
            icon: Icons.edit_rounded,
            onTap: onNew,
          ),
        ],
      ),
    );
  }
}

/// ================== COMPONENTES ==================

class _CandleIcon extends StatelessWidget {
  const _CandleIcon();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.local_fire_department_rounded,
      size: 22,
      color: Colors.white.withOpacity(0.92),
    );
  }
}

enum _DeleteTone { mine, admin }

class _DeleteAction extends StatelessWidget {
  const _DeleteAction({
    required this.onTap,
    required this.label,
    required this.tone,
  });

  final VoidCallback onTap;
  final String label;
  final _DeleteTone tone;

  @override
  Widget build(BuildContext context) {
    final isAdmin = tone == _DeleteTone.admin;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin) ...[
              Icon(
                Icons.admin_panel_settings_rounded,
                size: 16,
                color: Colors.white.withOpacity(0.88),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                letterSpacing: -0.1,
                color: isAdmin
                    ? Colors.amber.withOpacity(0.95)
                    : Colors.white.withOpacity(0.88),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SugestaoChip extends StatelessWidget {
  const _SugestaoChip({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                color: Colors.black.withOpacity(0.70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSmallCta extends StatelessWidget {
  const _GlassSmallCta({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withOpacity(0.12),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Icon(icon, color: color.withOpacity(0.95)),
    );
  }
}

class _PremiumFab extends StatelessWidget {
  const _PremiumFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.white.withOpacity(0.14),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  )
                ],
              ),
              child:
              const Icon(Icons.edit_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumField extends StatelessWidget {
  const _PremiumField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.55),
          ),
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.35)),
        ),
        cursorColor: atosPrimary,
      ),
    );
  }
}

class _PrimaryCTA extends StatelessWidget {
  const _PrimaryCTA({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: child,
        ),
      ),
    );
  }
}
