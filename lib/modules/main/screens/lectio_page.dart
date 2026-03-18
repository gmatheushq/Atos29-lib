import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class LectioDivinaPage extends StatefulWidget {
  const LectioDivinaPage({super.key});

  @override
  State<LectioDivinaPage> createState() => _LectioDivinaPageState();
}

class _LectioDivinaPageState extends State<LectioDivinaPage> {
  late Future<Map<String, dynamic>> _liturgiaFuture;

  // Paleta (mais atual)
  static const Color brand = Color(0xFF560405);
  static const Color bgA = Color(0xFFF7F3F0);
  static const Color bgB = Color(0xFFF2EFEA);
  static const Color ink = Color(0xFF171717);
  static const Color muted = Color(0xFF6B6B6B);


  @override
  void initState() {
    super.initState();
    _liturgiaFuture = buscarLiturgia();
  }

  Future<Map<String, dynamic>> buscarLiturgia() async {
    try {
      final url = Uri.parse('https://liturgia.up.railway.app/v2/');
      final resposta = await http.get(url).timeout(const Duration(seconds: 15));
      if (resposta.statusCode == 200) {
        return json.decode(utf8.decode(resposta.bodyBytes))
        as Map<String, dynamic>;
      }
      return {"erro": "Servidor respondeu ${resposta.statusCode}"};
    } catch (e) {
      return {"erro": "Falha ao buscar liturgia: $e"};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _GradientBg(
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _liturgiaFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: brand),
                );
              }

              final data = snapshot.data;
              if (snapshot.hasError || data == null || data['erro'] != null) {
                return _ErrorState(
                  message: (data?['erro'] ?? "Erro desconhecido").toString(),
                  onRetry: () =>
                      setState(() => _liturgiaFuture = buscarLiturgia()),
                );
              }

              final dados = data;
              final leituras = (dados['leituras'] as Map?) ?? {};
              final List<dynamic> listaEvangelho =
                  (leituras['evangelho'] as List?) ?? const [];
              final evangelho =
              listaEvangelho.isNotEmpty && listaEvangelho.first is Map
                  ? (listaEvangelho.first as Map)
                  : const {};

              final liturgiaTitulo =
                  dados['liturgia']?.toString() ?? "Liturgia Diária";

              return _HomeFlow(
                title: liturgiaTitulo,
                ref: evangelho['referencia']?.toString() ?? "Evangelho",
                gospelTitle: evangelho['titulo']?.toString() ?? "",
                onRefresh: () =>
                    setState(() => _liturgiaFuture = buscarLiturgia()),
                onStartAt: (index) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _LectioFlowPager(
                        initialIndex: index,
                        liturgiaTitulo: liturgiaTitulo,
                        evangelhoReferencia:
                        evangelho['referencia']?.toString() ?? "Evangelho",
                        evangelhoTitulo: evangelho['titulo']?.toString() ?? "",
                        evangelhoTexto: evangelho['texto']?.toString() ??
                            "Texto não disponível.",
                        onFinish: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                "Feito. Boa caminhada!",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              backgroundColor: brand,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// -------------------- HOME (mais “flow”, menos cards) --------------------

class _HomeFlow extends StatelessWidget {
  const _HomeFlow({
    required this.title,
    required this.ref,
    required this.gospelTitle,
    required this.onStartAt,
    required this.onRefresh,
  });

  final String title;
  final String ref;
  final String gospelTitle;
  final void Function(int index) onStartAt;
  final VoidCallback onRefresh;

  static const Color brand = _LectioDivinaPageState.brand;
  static const Color ink = _LectioDivinaPageState.ink;
  static const Color muted = _LectioDivinaPageState.muted;

  @override
  Widget build(BuildContext context) {
    return _MaxWidth(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: _TopRow(
                title: "Lectio Divina",
                subtitle: "Anônimo",
                onRefresh: onRefresh,
              ),

            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: _Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: brand.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gospelTitle.isEmpty ? "Evangelho do dia" : gospelTitle,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: ink.withOpacity(0.92),
                          ),
                        ),
                        const SizedBox(height: 6),

                      ],
                    ),

                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '“Não só de pão vive o homem, mas de toda a palavra que sai da boca de Deus”',
                          style: TextStyle(
                            color: muted.withOpacity(0.95),
                            height: 1.55,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "Mateus 4,4",
                            style: TextStyle(
                              color: muted.withOpacity(0.85),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    )

                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Text(
                "Passos",
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w900,
                  color: ink.withOpacity(0.9),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _StepRow(
                    n: 1,
                    title: "Lectio",
                    subtitle: "O que o Evangelho diz?",
                    onTap: () => onStartAt(0),
                  ),
                  _StepRow(
                    n: 2,
                    title: "Meditatio",
                    subtitle: "O que isso mexe em mim?",
                    onTap: () => onStartAt(1),
                  ),
                  _StepRow(
                    n: 3,
                    title: "Oratio",
                    subtitle: "Resposta simples a Deus",
                    onTap: () => onStartAt(2),
                  ),
                  _StepRow(
                    n: 4,
                    title: "Contemplatio",
                    subtitle: "Silêncio e contemplação",
                    onTap: () => onStartAt(3),
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: _Glass(
                      color: brand,
                      borderColor: brand.withOpacity(0.35),
                      shadow: [
                        BoxShadow(
                          color: brand.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Escreva ou faça uma reflexão mental, os cards são apenas para te guiar",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefresh;

  static const Color brand = _LectioDivinaPageState.brand;
  static const Color ink = _LectioDivinaPageState.ink;
  static const Color muted = _LectioDivinaPageState.muted;
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ink,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: vinhoIdentidade.withOpacity(0.70),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    subtitle, // "Anônimo"
                    style: TextStyle(
                      fontSize: 12.5,
                      color: muted.withOpacity(0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          color: brand.withOpacity(0.9),
          tooltip: "Atualizar",
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.n,
    required this.title,
    required this.subtitle,
    this.meta,
    required this.onTap,
  });

  final int n;
  final String title;
  final String subtitle;
  final String? meta;
  final VoidCallback onTap;

  static const Color brand = _LectioDivinaPageState.brand;
  static const Color ink = _LectioDivinaPageState.ink;
  static const Color muted = _LectioDivinaPageState.muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: _Glass(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 22, // mantém alinhado com o resto
              child: Text(
                "$n",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: brand.withOpacity(0.9),
                ),
              ),
            ),

            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      color: muted.withOpacity(0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (meta != null) ...[
              Text(
                meta!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: brand.withOpacity(0.85),
                ),
              ),
              const SizedBox(width: 6),
            ],


            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: brand.withOpacity(0.75)),
          ],
        ),
      ),
    );
  }
}

/// -------------------- PAGER (imersivo) --------------------

class _LectioFlowPager extends StatefulWidget {
  const _LectioFlowPager({
    required this.initialIndex,
    required this.liturgiaTitulo,
    required this.evangelhoReferencia,
    required this.evangelhoTitulo,
    required this.evangelhoTexto,
    required this.onFinish,
  });

  final int initialIndex;
  final String liturgiaTitulo;
  final String evangelhoReferencia;
  final String evangelhoTitulo;
  final String evangelhoTexto;
  final VoidCallback onFinish;

  @override
  State<_LectioFlowPager> createState() => _LectioFlowPagerState();
}

class _LectioFlowPagerState extends State<_LectioFlowPager> {
  late final PageController _controller;
  int _index = 0;

  late final List<TextEditingController> _notes;

  static const Color brand = _LectioDivinaPageState.brand;
  static const Color ink = _LectioDivinaPageState.ink;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _notes = List.generate(4, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _notes) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  String _normalizeGospel(String s) {
    var out = s;

    out = out
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll('&nbsp;', ' ');

    out = out.replaceAllMapped(
      RegExp(r'(\d+)([A-Za-zÀ-ÖØ-öø-ÿ])'),
          (m) => '${m[1]} ${m[2]}',
    );

    out = out.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    return out.trim();
  }

  String _titulo(int i) =>
      const ["Lectio", "Meditatio", "Oratio", "Contemplatio"][i];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _GradientBg(
        child: SafeArea(
          child: _MaxWidth(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: brand.withOpacity(0.9),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          _titulo(_index),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: ink,
                          ),
                        ),
                      ),
                      _MiniProgressDots(index: _index),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: [
                      _StepPage(
                        title: "Lectio",
                        kicker: "olhar o texto",
                        hint:
                        "Leia atentamente. Reflita sobre o que o Evangelho traz e guarde o que tocar você",
                        child: Column(
                          children: [
                            _Glass(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.menu_book_rounded,
                                        size: 18,
                                        color: brand.withOpacity(0.85),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.evangelhoReferencia,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w900,
                                                color: brand.withOpacity(0.92),
                                              ),
                                            ),
                                            if (widget.evangelhoTitulo
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                widget.evangelhoTitulo,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  height: 1.35,
                                                  fontWeight: FontWeight.w700,
                                                  color: ink.withOpacity(0.92),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _normalizeGospel(widget.evangelhoTexto),
                                    textAlign: TextAlign.justify,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      height: 1.75,
                                      color: ink.withOpacity(0.95),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _QuickQs(items: const [
                              "O que te tocou?",
                              "Qual frase você repetiria agora?",
                              "Identifique quem aparece na leitura e o que faz",
                            ]),
                            const SizedBox(height: 12),
                            _NoteField(
                              controller: _notes[0],
                              label: "Uma palavra/frase curta",
                              hint: "Ex.: “Paz”, “Segue-me”, “Confiança”…",
                            ),
                          ],
                        ),
                      ),
                      _StepPage(
                        title: "Meditatio",
                        kicker: "trazer pra vida",
                        hint: "O texto toca onde na sua história hoje?",
                        child: Column(
                          children: [
                            _QuickQs(items: const [
                              "Onde eu apareço nesse texto?",
                              "Qual atitude eu preciso ajustar?",
                              "O que Deus quer curar hoje?",
                            ]),
                            const SizedBox(height: 12),
                            _NoteField(
                              controller: _notes[1],
                              label:
                              "Deixe essas perguntas correrem pelo o seu ser",
                              hint: "Escreva ou medite, o que preferir",
                              maxLines: 6,
                            ),
                            const SizedBox(height: 12),
                            const _SoftTip(
                              icon: Icons.tips_and_updates_rounded,
                              text:
                              "Repete a frase escolhida por 30s. Sem pressa",
                            ),
                          ],
                        ),
                      ),
                      _StepPage(
                        title: "Oratio",
                        kicker: "responder a Deus",
                        hint: "Pode ser gratidão, pedido, louvor ou perdão",
                        child: Column(
                          children: [
                            const _SoftTip(
                              icon: Icons.waving_hand_rounded,
                              text:
                              "Começa assim: “Senhor Jesus, eu estou aqui…”\n\n Lembrete: Se preferir faça uma oração mental",
                            ),
                            const SizedBox(height: 12),
                            _NoteField(
                              controller: _notes[2],
                              label: "Minha oração",
                              hint: "Escreva como você conversa com Deus",
                              maxLines: 6,
                            ),
                            const SizedBox(height: 12),
                            const _SoftTip(
                              icon: Icons.favorite_rounded,
                              text: "Se travar: “Jesus, eu confio em vós”",
                            ),
                          ],
                        ),
                      ),
                      _StepPage(
                        title: "Contemplatio",
                        kicker: "silêncio",
                        hint: "Respira e repousa no que Deus tem para te falar",
                        child: Column(
                          children: [
                            const _SilenceTimerGlass(),
                            const SizedBox(height: 12),
                            _NoteField(
                              controller: _notes[3],
                              label: "Meu compromisso de hoje",
                              hint:
                              "Uma coisa pequena e possível que você pode fazer",
                              maxLines: 4,
                            ),
                            const SizedBox(height: 12),
                            const _SoftTip(
                              icon: Icons.check_circle_rounded,
                              text:
                              "Fecha com um gesto concreto: paz, caridade, perdão",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _BottomImmersiveNav(
                  index: _index,
                  onPrev: _index == 0 ? null : () => _go(_index - 1),
                  onNext: _index == 3 ? null : () => _go(_index + 1),
                  onFinish: _index == 3 ? widget.onFinish : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



  class _MiniProgressDots extends StatelessWidget {
  const _MiniProgressDots({required this.index});
  final int index;

  static const Color brand = _LectioDivinaPageState.brand;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? brand : brand.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.title,
    required this.kicker,
    required this.hint,
    required this.child,
  });

  final String title;
  final String kicker;
  final String hint;
  final Widget child;

  static const Color ink = _LectioDivinaPageState.ink;
  static const Color muted = _LectioDivinaPageState.muted;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kicker.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
              color: muted.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: ink,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: muted.withOpacity(0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          child,
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _QuickQs extends StatelessWidget {
  const _QuickQs({required this.items});
  final List<String> items;

  static const Color brand = _LectioDivinaPageState.brand;
  static const Color muted = _LectioDivinaPageState.muted;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: brand.withOpacity(0.85)),
              const SizedBox(width: 10),
              Text(
                "Perguntas rápidas",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: brand.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
                (q) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "• $q",
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 4,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  static const Color brand = _LectioDivinaPageState.brand;
  static const Color ink = _LectioDivinaPageState.ink;
  static const Color muted = _LectioDivinaPageState.muted;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: muted.withOpacity(0.9),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              filled: true,
              fillColor: brand.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: brand.withOpacity(0.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: brand.withOpacity(0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                BorderSide(color: brand.withOpacity(0.30), width: 1.2),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftTip extends StatelessWidget {
  const _SoftTip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  static const Color brand = _LectioDivinaPageState.brand;
  static const Color muted = _LectioDivinaPageState.muted;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Row(
        children: [
          Icon(icon, size: 18, color: brand.withOpacity(0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.2,
                height: 1.4,
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _BottomImmersiveNav extends StatelessWidget {
  const _BottomImmersiveNav({
    required this.index,
    required this.onPrev,
    required this.onNext,
    required this.onFinish,
  });

  final int index;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onFinish;

  static const Color brand = _LectioDivinaPageState.brand;
  static const Color muted = _LectioDivinaPageState.muted;

  Widget _shadowIcon({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool enabled,
  }) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      iconSize: 30,
      splashRadius: 22,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          // sombra
          Icon(
            icon,
            size: 30,
            color: Colors.black.withOpacity(0.28),
          ),
          // ícone principal
          Icon(
            icon,
            size: 30,
            color: enabled
                ? Colors.white
                : muted.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
      child: Row(
        children: [
          // ⬅️ Anterior
          _shadowIcon(
            icon: Icons.chevron_left_rounded,
            onPressed: onPrev,
            enabled: onPrev != null,
          ),

          // Contador central
          Expanded(
            child: Center(
              child: Text(
                "${index + 1} / 4",
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          _shadowIcon(
            icon: onFinish != null
                ? Icons.check_rounded
                : Icons.chevron_right_rounded,
            onPressed: onFinish ?? onNext,
            enabled: true,
          ),
        ],
      ),
    );
  }
}


/// -------------------- TIMER (mais clean + som) --------------------

class _SilenceTimerGlass extends StatelessWidget {
  const _SilenceTimerGlass();

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: const _SilenceTimer(),
    );
  }
}
class _SilenceTimer extends StatefulWidget {
  const _SilenceTimer();

  @override
  State<_SilenceTimer> createState() => _SilenceTimerState();
}

class _SilenceTimerState extends State<_SilenceTimer> {
  static const Color brand = _LectioDivinaPageState.brand;
  static const Color ink = _LectioDivinaPageState.ink;
  static const Color muted = _LectioDivinaPageState.muted;

  static const List<int> presets = [60, 120, 180];

  int _totalSeconds = 120;
  int _remaining = 120;
  int? _customSeconds;
  Timer? _timer;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _ding() async {
    await SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  void _setTotal(int seconds) {
    if (seconds < 30) seconds = 30;
    if (seconds > 30 * 60) seconds = 30 * 60; // até 30 min
    setState(() {
      _totalSeconds = seconds;
      _remaining = seconds;
    });
  }

  void _setPreset(int seconds) {
    if (_running) return;
    _setTotal(seconds);
  }

  void _start() {
    if (_running) return;
    setState(() => _running = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (_remaining <= 1) {
        _timer?.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
        });
        _ding();
        return;
      }

      setState(() => _remaining -= 1);
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remaining = _totalSeconds;
    });
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return "$m:$r";
  }

  String _label(int seconds) {
    final m = (seconds ~/ 60);
    return "${m} min";
  }

  String _currentLabel() {
    if (_totalSeconds < 60) return "${_totalSeconds}s";
    if (_totalSeconds % 60 == 0) return "${_totalSeconds ~/ 60} min";
    final m = (_totalSeconds / 60).toStringAsFixed(1).replaceAll('.', ',');
    return "$m min";
  }

  Future<void> _openCustomPicker() async {
    if (_running) return;

    int minutes = (_totalSeconds / 60).round().clamp(1, 30);

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void inc() => setSheetState(() {
              minutes = (minutes + 1).clamp(1, 30);
            });
            void dec() => setSheetState(() {
              minutes = (minutes - 1).clamp(1, 30);
            });

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: brand.withOpacity(0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Row(
                      children: [
                        Icon(Icons.timer_rounded,
                            size: 18, color: brand.withOpacity(0.85)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Tempo de silêncio",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: ink.withOpacity(0.92),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                          color: muted.withOpacity(0.7),
                        ),
                      ],
                    ),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Escolha quantos minutos você quer ficar em silêncio",
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: muted.withOpacity(0.95),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Stepper “bonito”
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: brand.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: brand.withOpacity(0.10)),
                      ),
                      child: Row(
                        children: [
                          _RoundIcon(
                            icon: Icons.remove_rounded,
                            onTap: minutes <= 1 ? null : dec,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  "$minutes",
                                  style: TextStyle(
                                    fontSize: 28,
                                    height: 1.0,
                                    fontWeight: FontWeight.w900,
                                    color: ink.withOpacity(0.92),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "minutos",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: muted.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _RoundIcon(
                            icon: Icons.add_rounded,
                            onTap: minutes >= 30 ? null : inc,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Aplicar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final secs = (minutes * 60).clamp(30, 30 * 60);
                          Navigator.pop(ctx, secs);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Aplicar",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
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

    if (result != null) {
      _customSeconds = result;
      _setTotal(result);
    }

  }


  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds == 0 ? 0.0 : (_remaining / _totalSeconds);
    final isDone = _remaining == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Silêncio",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: brand.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Respira. Se a mente correr, volta pra frase escolhida",
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: muted.withOpacity(0.95),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),

        Center(
          child: Column(
            children: [
              Text(
                _fmt(_remaining),
                style: TextStyle(
                  fontSize: 44,
                  height: 1.0,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w900,
                  color: ink.withOpacity(0.92),
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: brand.withOpacity(0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDone ? brand.withOpacity(0.45) : brand.withOpacity(0.85),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Tempo: ${_currentLabel()}",
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: muted.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        IgnorePointer(
          ignoring: _running,
          child: Opacity(
            opacity: _running ? 0.45 : 1,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        ...presets.map((s) {
                          final selected = s == _totalSeconds;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _setPreset(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected ? brand.withOpacity(0.10) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? brand.withOpacity(0.35)
                                        : brand.withOpacity(0.14),
                                  ),
                                ),
                                child: Text(
                                  _label(s),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: selected
                                        ? brand.withOpacity(0.92)
                                        : brand.withOpacity(0.75),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),

                        if (_customSeconds != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _running ? null : () => _setTotal(_customSeconds!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _totalSeconds == _customSeconds
                                      ? brand.withOpacity(0.10)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _totalSeconds == _customSeconds
                                        ? brand.withOpacity(0.35)
                                        : brand.withOpacity(0.14),
                                  ),
                                ),
                                child: Text(
                                  _label(_customSeconds!),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: _totalSeconds == _customSeconds
                                        ? brand.withOpacity(0.92)
                                        : brand.withOpacity(0.75),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),


                // ✏️ Só o lápis (sem pílula), alinhado com os presets
                IconButton(
                  onPressed: _openCustomPicker,
                  tooltip: "Personalizar tempo",
                  icon: const Icon(Icons.edit_rounded),
                  color: brand.withOpacity(0.78),
                ),
              ],
            ),
          ),
        ),


        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isDone ? _reset : (_running ? _pause : _start),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isDone ? "Reiniciar" : (_running ? "Pausar" : "Iniciar"),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: _running ? null : _reset,
              tooltip: "Reiniciar",
              icon: const Icon(Icons.restart_alt_rounded),
              color: brand.withOpacity(0.85),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  static const Color brand = _LectioDivinaPageState.brand;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: disabled ? Colors.black.withOpacity(0.03) : brand.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled ? Colors.black.withOpacity(0.06) : brand.withOpacity(0.16),
          ),
        ),
        child: Icon(
          icon,
          color: disabled ? Colors.black.withOpacity(0.25) : brand.withOpacity(0.85),
        ),
      ),
    );
  }
}



/// -------------------- ERROR --------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  static const Color brand = _LectioDivinaPageState.brand;
  static const Color ink = _LectioDivinaPageState.ink;
  static const Color muted = _LectioDivinaPageState.muted;

  @override
  Widget build(BuildContext context) {
    return _MaxWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopRow(
              title: "Lectio",
              subtitle: "offline por enquanto",
              onRefresh: onRetry,
            ),
            const SizedBox(height: 14),
            _Glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 20, color: brand.withOpacity(0.85)),
                      const SizedBox(width: 10),
                      const Text(
                        "Erro",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: muted.withOpacity(0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(foregroundColor: brand),
                    child: const Text(
                      "Tentar novamente",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientBg extends StatelessWidget {
  const _GradientBg({required this.child});
  final Widget child;

  static const Color bgA = _LectioDivinaPageState.bgA;
  static const Color bgB = _LectioDivinaPageState.bgB;
  static const Color brand = _LectioDivinaPageState.brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bgA,
            bgB,
            brand.withOpacity(0.80),
            brand.withOpacity(0.06),
          ],
          stops: const [0.0, 0.55, 1.0, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

      ),
      child: child,
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.onTap,
    this.padding,
    this.color,
    this.borderColor,
    this.shadow,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadow;

  static const Color brand = _LectioDivinaPageState.brand;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withOpacity(color == null ? 0.78 : 1.0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? brand.withOpacity(0.10)),
        boxShadow: shadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: child,
    );

    if (onTap == null) return box;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: box,
    );
  }
}

class _MaxWidth extends StatelessWidget {
  const _MaxWidth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
  }
}

