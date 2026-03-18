// exame_consciencia_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExameConscienciaPage extends StatefulWidget {
  const ExameConscienciaPage({super.key});

  @override
  State<ExameConscienciaPage> createState() => _ExameConscienciaPageState();
}

class _ExameConscienciaPageState extends State<ExameConscienciaPage> {
  // ===== PALETA (vinho) =====
  static const Color vinhoProfundo = Color(0xFF4E0D0D);
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color vinhoDestaque = Color(0xFF8E2A2A);

  // ===== PALETA (papel / fundo claro) =====
  static const Color bgA = Color(0xFFF7F3F0);
  static const Color bgB = Color(0xFFF2EFEA);

  // ===== TEXTO (tema claro) =====
  static const Color ink = Color(0xFF171717);
  static const Color muted = Color(0xFF6B6B6B);

  static const double rCard = 22;

  // ===== Controllers (anotações) =====
  final _gratidao = TextEditingController();
  final _quedas = TextEditingController();
  final _raiz = TextEditingController();
  final _proposito = TextEditingController();

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _gratidao.dispose();
    _quedas.dispose();
    _raiz.dispose();
    _proposito.dispose();
    super.dispose();
  }

  // ===== Tipografia (claro) =====
  TextStyle get _title => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: ink.withOpacity(0.92),
  );

  TextStyle get _subtitle => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: muted.withOpacity(0.92),
    height: 1.35,
  );

  TextStyle get _sectionTag => TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.25,
    color: vinhoIdentidade.withOpacity(0.82),
  );

  TextStyle get _body => TextStyle(
    fontSize: 15.6,
    height: 1.65,
    color: ink.withOpacity(0.78),
    fontWeight: FontWeight.w600,
  );

  TextStyle get _italic => TextStyle(
    fontSize: 15.6,
    height: 1.65,
    fontStyle: FontStyle.italic,
    color: ink.withOpacity(0.75),
    fontWeight: FontWeight.w600,
  );

  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _gratidao.text = prefs.getString('exame_gratidao') ?? '';
      _quedas.text = prefs.getString('exame_quedas') ?? '';
      _raiz.text = prefs.getString('exame_raiz') ?? '';
      _proposito.text = prefs.getString('exame_proposito') ?? '';
      _carregando = false;
    });
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('exame_gratidao', _gratidao.text.trim());
    await prefs.setString('exame_quedas', _quedas.text.trim());
    await prefs.setString('exame_raiz', _raiz.text.trim());
    await prefs.setString('exame_proposito', _proposito.text.trim());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Exame salvo.", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: vinhoIdentidade,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _limpar() async {
    setState(() {
      _gratidao.clear();
      _quedas.clear();
      _raiz.clear();
      _proposito.clear();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('exame_gratidao');
    await prefs.remove('exame_quedas');
    await prefs.remove('exame_raiz');
    await prefs.remove('exame_proposito');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Anotações limpas.", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: vinhoIdentidade,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _abrirOracoes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => _GlassSheet(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const _Handle(),
              const SizedBox(height: 10),
              Text("Orações", style: _title),
              const SizedBox(height: 8),
              Divider(color: Colors.black.withOpacity(0.08), height: 18),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
                  children: const [
                    _PrayerCard(
                      title: "Ato de Contrição",
                      text:
                      "Meu Deus, arrependo-me de todo o coração de Vos ter ofendido; detesto os meus pecados, "
                          "não só pelo castigo que mereço, mas principalmente por ter Vos ofendido, que sois tão bom e digno de todo amor. "
                          "Prometo, com a vossa graça, emendar-me e evitar as ocasiões de pecado. Amém.",
                    ),
                    _PrayerCard(
                      title: "Salmo 50 (51) — Criai em mim um coração puro",
                      text:
                      "Criai em mim um coração puro, ó Deus, e renovai dentro de mim um espírito firme "
                          "Não me afasteis de vossa face e não retireis de mim vosso Santo Espírito",
                    ),
                    _PrayerCard(
                      title: "Pai-Nosso",
                      text:
                      "Pai-Nosso que estais nos céus, santificado seja o vosso Nome, venha a nós o vosso Reino, "
                          "seja feita a vossa vontade, assim na terra como no céu. "
                          "O pão nosso de cada dia nos dai hoje; perdoai-nos as nossas ofensas, "
                          "assim como nós perdoamos a quem nos tem ofendido; e não nos deixeis cair em tentação, "
                          "mas livrai-nos do mal. Amém.",
                    ),
                    _PrayerCard(
                      title: "Ave-Maria",
                      text:
                      "Ave-Maria, cheia de graça, o Senhor é convosco. Bendita sois vós entre as mulheres e bendito é o fruto do vosso ventre, Jesus. "
                          "Santa Maria, Mãe de Deus, rogai por nós, pecadores, agora e na hora de nossa morte. Amém.",
                    ),
                    _PrayerCard(
                      title: "Glória",
                      text:
                      "Glória ao Pai, e ao Filho e ao Espírito Santo, como era no princípio, agora e sempre. Amém.",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textoCampo({
    required String hint,
    required TextEditingController controller,
    int maxLines = 4,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 15.2,
          height: 1.55,
          color: ink.withOpacity(0.92),
          fontWeight: FontWeight.w600,
        ),
        cursorColor: vinhoIdentidade,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: muted.withOpacity(0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: vinhoProfundo,
        centerTitle: true,
        title: const Text(
          "Exame de Consciência",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        actions: [
          IconButton(
            tooltip: "Orações",
            onPressed: _abrirOracoes,
            icon: const Icon(Icons.menu_book_rounded),
          ),
        ],
      ),
      body: _ExameBg(
        child: SafeArea(
          child: _carregando
              ? Center(
            child: CircularProgressIndicator(color: vinhoDestaque.withOpacity(0.9)),
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            children: [
              // ===== HERO =====
              _GlassCard(
                radius: 26,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          "ANÔNIMO",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                            color: vinhoIdentidade.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Senhor, mostra-me meu dia como Tu o vês",
                      style: _title.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Silêncio, luz, gratidão, revisão do dia, arrependimento e propósito",
                      style: _subtitle,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _PrimaryButtonLight(
                            label: "SALVAR",
                            onTap: _salvar,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _GhostButton(
                          label: "LIMPAR",
                          onTap: _limpar,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== 1) PRESENÇA =====
              _SectionCard(
                tag: "1) PRESENÇA DE DEUS",
                title: "Silenciar e pedir luz",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Faça o sinal da cruz. Respire. Fique alguns segundos em silêncio.\n\n"
                          "Depois, reze com simplicidade:",
                      style: _body,
                    ),
                    const SizedBox(height: 12),
                    const _QuoteBox(
                      text:
                      "Vinde, Espírito Santo, iluminai minha mente e meu coração, "
                          "para que eu reconheça minhas faltas sem medo e a graça de Deus sem distração. Amém.",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== 2) GRATIDÃO =====
              _SectionCard(
                tag: "2) GRATIDÃO",
                title: "Onde Deus esteve presente hoje?",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Recorde 2–3 coisas concretas. Gratidão abre os olhos para a presença de Deus no cotidiano",
                      style: _body,
                    ),
                    const SizedBox(height: 12),
                    _textoCampo(
                      hint: "Escreva sua gratidão (ex.: ‘Obrigado pela paz na minha casa…’)",
                      controller: _gratidao,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== 3) REVISÃO DO DIA =====
              _SectionCard(
                tag: "3) REVISÃO DO DIA",
                title: "Passar o ‘filme’ do dia",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Volte aos momentos-chave (manhã, tarde, noite). Observe onde houve caridade e onde houve queda",
                      style: _body,
                    ),
                    const SizedBox(height: 14),
                    const _PromptBlock(
                      title: "Relação com Deus",
                      prompts: [
                        "Eu rezei hoje? Rezei com o coração ou por hábito?",
                        "Procurei a vontade de Deus nas decisões?",
                        "Murmúrios, desconfiança, pressa — onde apareceram?",
                      ],
                    ),
                    const SizedBox(height: 10),
                    const _PromptBlock(
                      title: "Relação com o próximo",
                      prompts: [
                        "Fui paciente e respeitoso nas palavras?",
                        "Julguei, ironizei, fui indiferente, feri alguém?",
                        "Evitei fofoca e conversas que não edificam?",
                      ],
                    ),
                    const SizedBox(height: 10),
                    const _PromptBlock(
                      title: "Relação comigo (hábitos e pureza)",
                      prompts: [
                        "Fui temperante (comida, telas, distrações, compulsões)?",
                        "Busquei pureza nos olhos, pensamentos e atitudes?",
                        "Fui fiel às minhas responsabilidades?",
                      ],
                    ),
                    const SizedBox(height: 12),
                    _textoCampo(
                      hint: "Anote o que pesa na consciência (sem detalhes desnecessários)",
                      controller: _quedas,
                      maxLines: 5,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===== 4) RAIZ + PROPÓSITO =====
              _SectionCard(
                tag: "4) ARREPENDIMENTO E PROPÓSITO",
                title: "Nomeie a raiz e escolha um passo",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Nem sempre o problema é só ‘o que eu fiz’, mas ‘por que eu caí’. "
                          "Nomear a raiz ajuda a combater a causa.",
                      style: _body,
                    ),
                    const SizedBox(height: 12),
                    _textoCampo(
                      hint: "Raiz de hoje (ex.: orgulho, medo, vaidade, raiva, preguiça, busca de aprovação...)",
                      controller: _raiz,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    _textoCampo(
                      hint: "Meu propósito para amanhã (ex.: ‘vou pedir perdão…’, ‘vou evitar tal ocasião…’, ‘rezar 10 min cedo…’)",
                      controller: _proposito,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    Text("Ato de contrição (para rezar agora)", style: _sectionTag),
                    const SizedBox(height: 10),
                    Text(
                      "Meu Deus, arrependo-me de todo o coração de Vos ter ofendido; detesto os meus pecados, "
                          "não só pelo castigo que mereço, mas principalmente por ter Vos ofendido, que sois tão bom e digno de todo amor. "
                          "Prometo, com a vossa graça, emendar-me e evitar as ocasiões de pecado. Amém.",
                      style: _italic,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _PrimaryButton(
                            label: "ORAÇÕES",
                            onTap: _abrirOracoes,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrimaryButtonLight(
                            label: "SALVAR",
                            onTap: _salvar,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  "Dica: para confissão, diga os pecados com simplicidade e confiança na misericórdia. "
                      "Evite justificar; foque na verdade e no desejo de conversão",
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== FUNDO (parecido com Lectio, mas com vinho sutil) ==================

class _ExameBg extends StatelessWidget {
  const _ExameBg({required this.child});
  final Widget child;

  // papel
  static const Color bgA = Color(0xFFF7F3F0);
  static const Color bgB = Color(0xFFF2ECE6);

  // vinhos
  static const Color vinhoBase = Color(0xFF6A0F0F);
  static const Color vinhoSuave = Color(0xFF8E2A2A);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgA,
            bgB,
            Color(0xFF932323),
            Color(0xEB4E070D),
          ],
          stops: [0.0, 0.0, 0.95, 1.0],
        ),
      ),
      child: child,
    );
  }
}


// ================== COMPONENTES ==================

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  static const Color vinhoIdentidade = _ExameConscienciaPageState.vinhoIdentidade;

  @override
  Widget build(BuildContext context) {
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: vinhoIdentidade.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    return box;
  }
}

class _SoftSurface extends StatelessWidget {
  const _SoftSurface({
    required this.child,
    this.radius = 16,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: child,
    );
  }
}

class _PrimaryButtonLight extends StatelessWidget {
  const _PrimaryButtonLight({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const Color vinhoIdentidade = _ExameConscienciaPageState.vinhoIdentidade;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.60),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
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
                color: vinhoIdentidade,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.tag,
    required this.title,
    required this.child,
  });

  final String tag;
  final String title;
  final Widget child;

  static const Color ink = _ExameConscienciaPageState.ink;
  static const Color muted = _ExameConscienciaPageState.muted;
  static const Color vinhoIdentidade = _ExameConscienciaPageState.vinhoIdentidade;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.25,
              color: vinhoIdentidade.withOpacity(0.95),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: ink.withOpacity(0.92),
            ),
          ),
          const SizedBox(height: 12),
          DefaultTextStyle(
            style: TextStyle(
              color: muted.withOpacity(0.95),
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PromptBlock extends StatelessWidget {
  const _PromptBlock({required this.title, required this.prompts});

  final String title;
  final List<String> prompts;

  static const Color ink = _ExameConscienciaPageState.ink;
  static const Color muted = _ExameConscienciaPageState.muted;

  @override
  Widget build(BuildContext context) {
    return _SoftSurface(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
              color: ink.withOpacity(0.90),
            ),
          ),
          const SizedBox(height: 10),
          ...prompts.map(
                (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "•",
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.1,
                      color: Colors.black.withOpacity(0.35),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 14.8,
                        height: 1.55,
                        color: ink.withOpacity(0.59),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteBox extends StatelessWidget {
  const _QuoteBox({required this.text});
  final String text;

  static const Color ink = _ExameConscienciaPageState.ink;

  @override
  Widget build(BuildContext context) {
    return _SoftSurface(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15.4,
          height: 1.65,
          fontStyle: FontStyle.italic,
          color: ink.withOpacity(0.95),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  static const Color vinhoIdentidade = _ExameConscienciaPageState.vinhoIdentidade;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: vinhoIdentidade,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: vinhoIdentidade.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: const Center(
            child: Text(
              "ORAÇÕES",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  static const Color vinhoIdentidade = _ExameConscienciaPageState.vinhoIdentidade;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: vinhoIdentidade,
          side: BorderSide(color: vinhoIdentidade.withOpacity(0.06)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.white.withOpacity(0.55),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.7),
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

// Bottom sheet “glass” claro, coerente com o tema claro
class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child});
  final Widget child;

  static const double rSheet = 30;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(rSheet)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(rSheet)),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.title, required this.text});
  final String title;
  final String text;

  static const Color ink = _ExameConscienciaPageState.ink;
  static const Color muted = _ExameConscienciaPageState.muted;
  static const Color vinhoIdentidade = _ExameConscienciaPageState.vinhoIdentidade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SoftSurface(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: vinhoIdentidade.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: TextStyle(
                fontSize: 15.2,
                height: 1.65,
                fontStyle: FontStyle.italic,
                color: muted.withOpacity(1.0),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Divider(color: Colors.black.withOpacity(0.06), height: 14),
            Text(
              "—",
              style: TextStyle(
                color: ink.withOpacity(0.25),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
