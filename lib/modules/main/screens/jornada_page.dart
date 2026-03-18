import 'dart:convert';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'oracoes_page.dart';
import 'novena_page.dart';
import 'lectio_page.dart';
import 'terco_page.dart';
import 'exame_consciencia_page.dart';
import 'package:atos29/core/notifications/novena_sync_service.dart';

class JornadaPage extends StatefulWidget {
  const JornadaPage({super.key, this.initialFocusDailyMission = false});

  final bool initialFocusDailyMission;

  @override
  State<JornadaPage> createState() => _JornadaPageState();
}

class _JornadaPageState extends State<JornadaPage> {
  // ===== NOVENA =====
  double _progresso = 0.0;
  String _nome = "Nenhuma novena ativa";
  int _dia = 0;
  String _novenaId = "";

  String _ultimaOracaoData = "";

  final PageController _topController = PageController(viewportFraction: 1.0);
  int _topIndex = 0;

  // ===== TOKENS =====
  static const Color vinhoProfundo = Color(0xFF560405);
  static const Color vinhoIdentidade = Color(0xFF6B1515);
  static const Color vinhoDestaque = Color(0xFF8E2A2A);

  static const Color paper = Color(0xFFFBFAF8);
  static const double rCard = 22;

  static const String _apiUrl = 'https://novena-api.onrender.com/novenas';

  static const Color verdeSolido = Color(0xFF0E7A3A);

  @override
  void initState() {
    super.initState();
    _carregar();

    if (widget.initialFocusDailyMission) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _topIndex = 0);
        _topController.jumpToPage(0);

      });
    }
  }



  @override
  void dispose() {
    _topController.dispose();
    super.dispose();
  }
  String _todayKey() {
    final d = DateTime.now();
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  DateTime _parseKey(String key) {
    final p = key.split('-').map((e) => int.tryParse(e) ?? 0).toList();
    if (p.length != 3) return DateTime(1970);
    return DateTime(p[0], p[1], p[2]);
  }

  bool _isSameDayKey(String a, String b) => a == b;

  bool _isBeforeTodayKey(String dateKey) {
    if (dateKey.isEmpty) return false;
    final d = _parseKey(dateKey);
    final today = _parseKey(_todayKey());
    return d.isBefore(today);
  }



  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();

    String nome = prefs.getString('novena_ativa_nome') ?? "Nenhuma novena ativa";
    String novenaId = prefs.getString('novena_ativa_id') ?? "";
    int dia = prefs.getInt('novena_ativa_dia') ?? 0;

    String ultimaData = prefs.getString('novena_ultima_oracao_data') ?? "";
    final String today = _todayKey();

    final bool temNovenaAtiva = novenaId.isNotEmpty && nome != "Nenhuma novena ativa";
    final bool diaValido = dia >= 1 && dia <= 9;

    if (temNovenaAtiva && diaValido && ultimaData.isNotEmpty && ultimaData != today) {
      if (_isBeforeTodayKey(ultimaData)) {
        dia = (dia + 1).clamp(1, 9);
        ultimaData = "";

        await prefs.setInt('novena_ativa_dia', dia);
        await prefs.setString('novena_ultima_oracao_data', ultimaData);
      }
    }

    setState(() {
      _nome = nome;
      _novenaId = novenaId;
      _dia = dia;
      _progresso = (_dia / 9).clamp(0.0, 1.0);
      _ultimaOracaoData = ultimaData;
    });

    await NovenaSyncService.syncFromPrefsToUserDoc();
  }


  Future<void> _ajustarDiaNovena(int novoDia) async {
    final prefs = await SharedPreferences.getInstance();
    final diaAjustado = novoDia.clamp(0, 9);

    await prefs.setInt('novena_ativa_dia', diaAjustado);
    await prefs.setString('novena_ultima_oracao_data', "");

    await NovenaSyncService.syncFromPrefsToUserDoc();
    await _carregar();
  }


  Future<void> _marcarNovenaRezadaHoje() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('novena_ultima_oracao_data', _todayKey());

    await NovenaSyncService.syncFromPrefsToUserDoc();
    await _carregar();
  }




  Future<Map<String, dynamic>> _fetchNovenaDay({
    required String novenaId,
    required int day,
  }) async {
    final url = Uri.parse('$_apiUrl/$novenaId/dias/$day/roteiro');

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 12));

      final body = utf8.decode(resp.bodyBytes);

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded;
        throw Exception("JSON inesperado (não é Map) no dia $day");
      }

      // >>> aqui você enxerga o real problema <<<
      final preview = body.length > 180 ? "${body.substring(0, 180)}..." : body;
      throw Exception("HTTP ${resp.statusCode} ao buscar dia $day: $preview");
    } on TimeoutException {
      throw Exception("Timeout ao buscar dia $day");
    } catch (e) {
      throw Exception("Falha ao buscar dia $day: $e");
    }
  }

  // ===================== ESTILOS =====================
  TextStyle get _title => const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: vinhoProfundo,
    letterSpacing: -0.4,
  );

  TextStyle get _subtitle => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: Colors.black.withOpacity(0.55),
  );

  TextStyle get _chip => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.1,
    color: vinhoIdentidade,
  );

  // ===================== NAVEGAÇÃO =====================
  void _abrirLectioDivina() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const LectioDivinaPage()),
  );

  void _abrirExameConsciencia() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ExameConscienciaPage()),
  );

  Future<void> _abrirCatalogoNovenas() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ListaNovenasPage()),
    );
    if (ok == true) await _carregar();
  }

  // ===================== NOVENA: MODAL =====================
  void _abrirMeditacaoNovena() {
    if (_novenaId.isEmpty || _nome == "Nenhuma novena ativa") {
      _mostrarAviso("Selecione uma novena em 'Novenário' primeiro");
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (context, scrollController) => _GlassSheet(
            child: Builder(
              builder: (context) {
                final int currentDay = (_dia <= 0) ? 1 : _dia.clamp(1, 9);

                return FutureBuilder<Map<String, dynamic>>(
                  key: ValueKey('novena_${_novenaId}_day_$currentDay'),
                  future: _fetchNovenaDay(novenaId: _novenaId, day: currentDay),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: vinhoIdentidade),
                      );
                    }
                    if (snap.hasError) {
                      return ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                        children: [
                          const _Handle(),
                          _buildControleDias(setModalState),
                          const SizedBox(height: 16),
                          Text(
                            "Erro ao carregar o dia $currentDay",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snap.error.toString(),
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: Colors.black.withOpacity(0.60),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),

                          _PrimaryButton(
                            label: "TENTAR NOVAMENTE",
                            onTap: () {
                              setModalState(() {});
                            },
                          ),
                        ],
                      );
                    }

                    final data = snap.data!;
                    final blocks = data["blocks"] as List? ?? [];
                    final String dayTitle =
                    (data["dia"]?["titulo"] ?? "Dia $currentDay").toString();

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
                      children: [
                        const _Handle(),

                        _buildControleDias(setModalState),

                        const SizedBox(height: 14),

                        _buildTags(currentDay),

                        const SizedBox(height: 14),

                        Text(dayTitle, style: _title),

                        const Divider(height: 32),
                        ...blocks.map((b) => _buildSection(b)).toList(),
                        const SizedBox(height: 20),

                        _PrimaryButton(
                          label: (_dia >= 9 && _ultimaOracaoData == _todayKey())
                              ? "FINALIZAR NOVENA"
                              : (_dia >= 9 ? "CONCLUIR DIA 9" : "CONCLUIR DIA $currentDay"),
                          onTap: () async {
                            await _marcarNovenaRezadaHoje();

                            if (mounted) Navigator.pop(context);

                            if (_dia >= 9) {
                              // se concluiu o dia 9 hoje, pode finalizar imediatamente
                              _finalizarNovena();

                            } else {
                              _mostrarAviso("Oração concluída!");
                            }
                          },
                        ),

                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ===================== ORAÇÕES =====================
  void _abrirCardOracoes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => _GlassSheet(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const _Handle(),
              const SizedBox(height: 10),
              Text("Orações do Dia", style: _title),
              const SizedBox(height: 10),
              Divider(color: Colors.black.withOpacity(0.08), height: 18),
              Expanded(
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: vinhoIdentidade,
                        unselectedLabelColor: Colors.black.withOpacity(0.35),
                        indicatorColor: vinhoDestaque,
                        indicatorWeight: 2.5,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(icon: Icon(Icons.wb_sunny_outlined), text: "Manhã"),
                          Tab(icon: Icon(Icons.restaurant), text: "Alimentos"),
                          Tab(icon: Icon(Icons.bedtime_outlined), text: "Noite"),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _conteudoOracao(
                              "Oração da Manhã",
                              "Senhor! No silêncio deste dia que amanhece, venho pedir-te a paz, a sabedoria e a força."
                                  "Quero olhar hoje o mundo com olhos cheios de amor, ser paciente, compreensivo, manso e prudente."
                                  "Quero ver os meus irmãos além das aparências, quero vê-los como Tu mesmo os vês, e assim não ver senão o bem em cada um."
                                  "Cerra meus ouvidos a toda calúnia. Guarda minha língua de toda maldade. Que só de bençãos se encha meu espírito."
                                  "Que eu seja tão bondoso e alegre, que todos quantos se achegarem a mim sintam tua presença."
                                  "Reveste-me de Tua beleza, Senhor, e que no decurso deste dia eu Te revele a todos.\n\nAmém.",
                            ),
                            _conteudoOracao(
                              "Orações dos Alimentos",
                              "BÊNÇÃO DOS ALIMENTOS\n\n"
                                  "Abençoai, Senhor, estes alimentos que por Vossa bondade vamos receber, "
                                  "e dignai-vos conduzir-nos à mesa celestial. "
                                  "Dais o pão a quem tem fome e sede de justiça a quem tem pão. "
                                  "Que esta refeição nos dê forças para servir aos nossos irmãos e irmãs. "
                                  "Por Cristo, nosso Senhor.\n\n"
                                  "Amém.\n\n"
                                  "\n"
                                  "PROVIDÊNCIA SANTÍSSIMA DO ETERNO, ONIPOTENTE E MISERICORDIOSÍSSIMO DEUS, "
                                  "QUE TUDO TENDES PROVIDENCIADO E PROVIDENCIAREIS PARA O NOSSO BEM, "
                                  "PROVIDENCIAI EM TODAS AS NOSSAS NECESSIDADES SEJA SEMPRE FEITA A VOSSA SANTÍSSIMA VONTADE.\n\n"
                                  "AMÉM!",
                            ),
                            _conteudoOracao(
                              "Exame de Consciência",
                              "1. Coloque-se na presença de Deus.\n"
                                  "2. Agradeça pelas graças de hoje.\n"
                                  "3. Peça luz para reconhecer seus erros.\n"
                                  "4. Peça perdão e faça um propósito para amanhã.\n\n"
                                  "Oração: Em Vossas mãos, Senhor, entrego o meu espírito. Vós me redimistes, Senhor, Deus fiel.\n\nAmém.",
                            ),
                          ],
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
    );
  }

  Widget _conteudoOracao(String titulo, String texto) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      child: Column(
        children: [
          _Chip(icon: Icons.menu_book_rounded, text: titulo.toUpperCase()),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.65,
              fontStyle: FontStyle.italic,
              color: Colors.black.withOpacity(0.74),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== CONFISSÕES =====================
  void _abrirHorariosConfissao() {
    final diaHoje = DateTime.now().weekday;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => _GlassSheet(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const _Handle(),
              const SizedBox(height: 10),
              Text("Horários de Confissão", style: _title),
              const SizedBox(height: 10),
              Divider(color: Colors.black.withOpacity(0.08), height: 18),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  children: [
                    _itemDiaConfissao("Terça-feira", ["18:30 - Capela Santa Clara"], diaHoje == 2),
                    _itemDiaConfissao(
                      "Quarta-feira",
                      [
                        "09:00 às 11:30 - Matriz São Joaquim",
                        "16:00 às 19:00 - Capela Rosa Mística",
                        "18:30 - Capela Santa Cecília"
                      ],
                      diaHoje == 3,
                    ),
                    _itemDiaConfissao("Quinta-feira", ["09:00 às 11:30 - Matriz São Joaquim"], diaHoje == 4),
                    _itemDiaConfissao("Sexta-feira", ["09:00 às 11:30 - Matriz São Joaquim"], diaHoje == 5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemDiaConfissao(String dia, List<String> horarios, bool isHoje) {
    const Color vinhoSolido = Color(0xFF560405); // rgb(86,4,5)

    final Color bg = isHoje ? vinhoSolido : Colors.white;
    final Color titleColor = isHoje ? Colors.white : Colors.black.withOpacity(0.82);
    final Color timeIconColor = isHoje ? Colors.white.withOpacity(0.92) : vinhoDestaque.withOpacity(0.85);
    final Color textColor = isHoje ? Colors.white.withOpacity(0.88) : Colors.black.withOpacity(0.72);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(rCard),
        border: Border.all(
          color: isHoje ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isHoje ? 0.16 : 0.06),
            blurRadius: isHoje ? 26 : 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dia,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 10),
          ...horarios.map(
                (h) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: timeIconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: isHoje ? FontWeight.w700 : FontWeight.w400,
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
  // ===================== MISSAS =====================
  void _abrirHorariosMissa() {
    final diaHoje = DateTime.now().weekday; // 1=seg ... 7=dom

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => _GlassSheet(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.80,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const _Handle(),
              const SizedBox(height: 10),
              Text("Horários de Missa", style: _title),
              const SizedBox(height: 10),
              Divider(color: Colors.black.withOpacity(0.08), height: 18),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  children: [
                    // ------- SEMANAIS -------
                    _secaoTitulo("Semanais"),

                    _itemDiaMissa(
                      "Terça-feira",
                      ["19:30 - Capela Santa Clara"],
                      diaHoje == 2,
                    ),

                    _itemDiaMissa(
                      "Quarta-feira",
                      [
                        "19:00 - Capela Santa Maria dos Anjos",
                        "19:30 - Capela Nossa Senhora Rosa Mística",
                        "19:30 - Capela Santa Cecília",
                      ],
                      diaHoje == 3,
                    ),

                    _itemDiaMissa(
                      "Quinta-feira",
                      [
                        "06:30 - Matriz São Joaquim",
                        "19:30 - Matriz São Joaquim",
                      ],
                      diaHoje == 4,
                    ),

                    _itemDiaMissa(
                      "Sexta-feira",
                      [
                        "19:30 - Capela Nosso Senhor dos Passos",
                        "19:30 - 3ª sexta-feira do mês: Missa na Capela do NACRI",
                      ],
                      diaHoje == 5,
                    ),

                    const SizedBox(height: 10),

                    // ------- DOMINICAIS -------
                    _secaoTitulo("Dominicais"),

                    _itemDiaMissa(
                      "Sábado",
                      [
                        "17:00 - Matriz São Joaquim",
                        "19:00 - Capela Nosso Senhor dos Passos",
                      ],
                      diaHoje == 6,
                    ),

                    _itemDiaMissa(
                      "Domingo",
                      [
                        "07:00 - Matriz São Joaquim",
                        "08:30 - Capela Santa Cecília",
                        "10:00 - Matriz São Joaquim",
                        "11:00 - Capela Santa Maria dos Anjos",
                        "18:00 - Capela Nossa Senhora Rosa Mística",
                        "19:00 - Matriz São Joaquim",
                      ],
                      diaHoje == 7,
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

  Widget _secaoTitulo(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: vinhoDestaque.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.black.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemDiaMissa(String dia, List<String> horarios, bool isHoje) {
    const Color vinhoSolido = Color(0xFF560405);

    final Color bg = isHoje ? vinhoSolido : Colors.white;
    final Color titleColor = isHoje ? Colors.white : Colors.black.withOpacity(0.82);
    final Color timeIconColor = isHoje ? Colors.white.withOpacity(0.92) : vinhoDestaque.withOpacity(0.85);
    final Color textColor = isHoje ? Colors.white.withOpacity(0.88) : Colors.black.withOpacity(0.72);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(rCard),
        border: Border.all(
          color: isHoje ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isHoje ? 0.16 : 0.06),
            blurRadius: isHoje ? 26 : 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dia,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 10),
          ...horarios.map(
                (h) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.access_time, size: 14, color: timeIconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        color: textColor,
                        fontWeight: isHoje ? FontWeight.w700 : FontWeight.w400,
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


  // ===================== HELPERS UI (NOVENA) =====================
  Widget _buildSection(dynamic s) {
    final type = (s["type"] ?? "text").toString();
    final title = (s["title"] ?? "").toString().trim();
    final text = (s["text"] ?? "").toString().trim();

    String norm(String v) => v
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[()]+'), '')
        .trim();

    final tTitle = norm(title);
    final tText = norm(text);

    // ✅ remove o bloco duplicado que vem em "EM SEGUIDA" repetindo as orações
    final bool pareceDuplicadoDePedidoPessoal =
        (tTitle == "em seguida" || tTitle == "pedido pessoal") &&
            (tText.contains("pai-nosso") || tText.contains("pai nosso")) &&
            tText.contains("ave-maria") &&
            (tText.contains("gloria ao pai") || tText.contains("glória ao pai"));

    // regra: se for "EM SEGUIDA" e o texto é só repetição das orações, não renderiza
    if (tTitle == "em seguida" && pareceDuplicadoDePedidoPessoal) {
      return const SizedBox.shrink();
    }

    // ---------- Renderização ----------
    // Se for oração, renderiza como oração (caixa)
    if (type == "prayer" || type.contains("oracao") || type.contains("sinal")) {
      // título opcional
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(title.toUpperCase(), style: _chip.copyWith(color: vinhoDestaque)),
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: vinhoDestaque.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      );
    }

    // Se tiver título (ex: "EM SEGUIDA"), renderiza título + texto normal
    if (title.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: _chip.copyWith(color: vinhoDestaque)),
            const SizedBox(height: 8),
            if (text.isNotEmpty) Text(text, style: const TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    // Texto simples
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildControleDias(void Function(void Function()) setModalState) {
    return _NovenaDayControl(
      diaAtual: _dia,
      onPrev: _dia > 1
          ? () async {
        await _ajustarDiaNovena(_dia - 1);
        setModalState(() {});
      }
          : null,
      onNext: _dia < 9
          ? () async {
        await _ajustarDiaNovena(_dia + 1);
        setModalState(() {});
      }
          : null,
    );
  }

  Widget _buildTags(int day) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      "DIA $day/9",
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
        color: Colors.black.withOpacity(0.55),
      ),
    ),
  );

  void _mostrarAviso(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: vinhoIdentidade),
  );

  void _finalizarNovena() async {
    final prefs = await SharedPreferences.getInstance();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Novena Concluída!", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.remove('novena_ativa_nome');
              await prefs.remove('novena_ativa_id');
              await prefs.remove('novena_ativa_dia');
              await prefs.remove('novena_ultima_oracao_data');

              await NovenaSyncService.syncFromPrefsToUserDoc();

              if (!context.mounted) return;
              Navigator.pop(context);
              _carregar();
            },
            child: const Text(
              "Encerrar",
              style: TextStyle(color: vinhoIdentidade, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }


  // ===================== TOPO: CARDS DESLIZÁVEIS =====================
  Widget _topSlider() {
    final bool ativa = _nome != "Nenhuma novena ativa";

    // ✅ verde só se rezou HOJE
    final bool rezouHoje = ativa && (_ultimaOracaoData == _todayKey());

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView(
            controller: _topController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _topIndex = i),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6), // 👈 menor
                child: _DailyMissionTopCard(),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _CardBase(
                  // ✅ NOVO: cor dinâmica (verde quando rezou hoje)
                  color: rezouHoje ? verdeSolido : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // topo: ícone + status
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white.withOpacity(0.95),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                rezouHoje
                                    ? "Novena rezada hoje"
                                    : (ativa ? "Novena em andamento" : "Sem novena ativa"),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.88),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (ativa)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                                ),
                                child: Text(
                                  "DIA $_dia/9",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // título
                        Text(
                          ativa ? _nome : "Escolha uma novena",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: Colors.white,
                            height: 1.05,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const Spacer(),

                        // progresso
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _progresso,
                            minHeight: 10,
                            backgroundColor: Colors.white.withOpacity(0.18),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // botão (branco)
                        _PrimaryButtonLight(
                          label: ativa ? "ABRIR NOVENA" : "ABRIR CATÁLOGO",
                          onTap: ativa ? _abrirMeditacaoNovena : _abrirCatalogoNovenas,
                          textColor: rezouHoje ? verdeSolido : null, // ✅ verde quando card verde
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Dot(active: _topIndex == 0),
            const SizedBox(width: 8),
            _Dot(active: _topIndex == 1),
          ],
        ),
      ],
    );
  }

  // ===================== TELA PRINCIPAL =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: paper,
        foregroundColor: vinhoProfundo,
        centerTitle: true,
        title: const Text(
          "Minha Jornada",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: _topSlider(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
              children: [
                _MenuCard(
                  title: "Exame de Consciência",
                  subtitle: "Reflexão, gratidão e propósito do dia",
                  icon: Icons.edit_note_outlined,
                  onTap: _abrirExameConsciencia,
                ),
                _MenuCard(
                  title: "Santo Terço",
                  subtitle: "Reze seu terço diário",
                  icon: Icons.spa_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TercoPage()),
                    );
                  },
                ),
                _MenuCard(
                  title: "Orações Diárias",
                  subtitle: "Manhã, Alimentos e Noite",
                  icon: Icons.whatshot_rounded,
                  onTap: _abrirCardOracoes,
                ),
                _MenuCard(
                  title: "Orações",
                  subtitle: "Catálogo Orações",
                  icon: Icons.menu_book_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OracoesPage()),
                    );
                  },
                ),
                _MenuCard(
                  title: "Confissões",
                  subtitle: "Horários e locais na Paróquia",
                  icon: Icons.church_rounded,
                  onTap: _abrirHorariosConfissao,
                ),
                _MenuCard(
                  title: "Horários de Missa",
                  subtitle: "Semanais e Dominicais",
                  icon: Icons.schedule_rounded,
                  onTap: _abrirHorariosMissa,
                ),

                _MenuCard(
                  title: "Lectio Divina",
                  subtitle: "Ler, Meditar, Rezar e Contemplar",
                  icon: Icons.menu_book,
                  onTap: _abrirLectioDivina,
                ),
                _MenuCard(
                  title: "Novenário",
                  subtitle: "Catálogo de Novenas",
                  icon: Icons.auto_awesome,
                  onTap: _abrirCatalogoNovenas,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== UI COMPONENTS =====================

class _CardBase extends StatelessWidget {
  const _CardBase({required this.child, this.color});
  final Widget child;

  // ✅ NOVO: permite mudar cor (verde quando rezou hoje)
  final Color? color;

  static const Color vinhoSolido = Color(0xFF560405); // rgb(86,4,5)

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: color ?? vinhoSolido,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: active ? 18 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: active ? vinhoIdentidade.withOpacity(0.35) : Colors.black.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  static const double rCard = 22;
  static const Color vinhoSolido = Color(0xFF560405); // rgb(86,4,5)

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rCard),
        color: vinhoSolido,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(rCard),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.80),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.80)),
              ],
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

  static const double rSheet = 30;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(rSheet)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(rSheet)),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: child,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.subtle = false});

  final IconData icon;
  final String text;
  final bool subtle;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color vinhoDestaque = Color(0xFF8E2A2A);

  @override
  Widget build(BuildContext context) {
    final Color base = subtle ? vinhoDestaque : vinhoIdentidade;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: base.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: base.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: base.withOpacity(0.95)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: base.withOpacity(0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipLight extends StatelessWidget {
  const _ChipLight({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.95)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: vinhoIdentidade,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: vinhoIdentidade.withOpacity(0.22),
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
    );
  }
}
class _PrimaryButtonLight extends StatelessWidget {
  const _PrimaryButtonLight({
    required this.label,
    required this.onTap,
    this.textColor,
  });

  final String label;
  final VoidCallback onTap;

  // ✅ NOVO: permite trocar a cor do texto
  final Color? textColor;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white, // ✅ branco sólido
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
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
              style: TextStyle(
                color: textColor ?? vinhoIdentidade, // ✅ agora é dinâmico
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NovenaDayControl extends StatelessWidget {
  const _NovenaDayControl({
    required this.diaAtual,
    required this.onPrev,
    required this.onNext,
    this.window = 5, // 3, 4 ou 5
    this.total = 9,
  });

  final int diaAtual; // 0..9 (no seu app)
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final int window; // quantidade de bolinhas visíveis
  final int total;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    final int foco = (diaAtual <= 0) ? 1 : diaAtual.clamp(1, total);

    final int w = window.clamp(3, 7);
    final int half = w ~/ 2;

    int start = foco - half;
    int end = foco + half;

    if (start < 1) {
      end += (1 - start);
      start = 1;
    }
    if (end > total) {
      start -= (end - total);
      end = total;
    }
    start = start.clamp(1, total);
    end = end.clamp(1, total);

    final days = <int>[];
    for (int d = start; d <= end; d++) {
      days.add(d);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12), // 👈 AJUSTE AQUI
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _BareArrow(icon: Icons.chevron_left_rounded, onTap: onPrev),
          const SizedBox(width: 6),
          ...days.map((d) {
            final bool isFocus = d == foco;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _DotPill(day: d, isFocus: isFocus),
            );
          }).toList(),
          const SizedBox(width: 6),
          _BareArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _DotPill extends StatelessWidget {
  const _DotPill({required this.day, required this.isFocus});

  final int day;
  final bool isFocus;

  static const Color vinhoDestaque = Color(0xFF8E2A2A);

  @override
  Widget build(BuildContext context) {
    final double size = isFocus ? 22 : 8;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFocus ? vinhoDestaque : Colors.black.withOpacity(0.18),
        boxShadow: isFocus
            ? [
          BoxShadow(
            color: vinhoDestaque.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ]
            : null,
      ),
      child: isFocus
          ? Text(
        "$day",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          height: 1,
        ),
      )
          : null,
    );
  }
}

class _BareArrow extends StatelessWidget {
  const _BareArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2), // bem compacto
        child: Icon(
          icon,
          size: 22,
          color: disabled ? Colors.black.withOpacity(0.25) : vinhoIdentidade,
        ),
      ),
    );
  }
}

// ===================== MISSÃO DO DIA (inalterado) =====================

class _DailyMissionTopCard extends StatefulWidget {
  const _DailyMissionTopCard();

  @override
  State<_DailyMissionTopCard> createState() => _DailyMissionTopCardState();
}


class _DailyMissionTopCardState extends State<_DailyMissionTopCard> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  static const String apiUrl = "https://missions-api.onrender.com/missions";

  static const Color _green1 = Color(0xFF0E7A3A);
  static const Color _green2 = Color(0xFF1BAA5B);
  static const Color _green3 = Color(0xFF0B5F2D);

  static const Color _vinho1 = Color(0xFF7A1A1A);
  static const Color _vinho2 = Color(0xFF9B3A3A);
  static const Color _vinho3 = Color(0xFF5A1212);

  String _todayKey() {
    final d = DateTime.now();
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  int _hash(String s) {
    int h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  Future<List<Map<String, dynamic>>> _loadMissions() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) throw Exception("Erro ao carregar missões");
    final decoded = jsonDecode(res.body);
    final list = decoded['missions'] as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Map<String, dynamic> _pickMission(List<Map<String, dynamic>> missions, String uid, String date) {
    if (missions.isEmpty) throw Exception("Lista de missões vazia");
    final idx = _hash("$uid|$date") % missions.length;
    return missions[idx];
  }

  DocumentReference _doc(String uid, String date) {
    return _firestore.collection('users').doc(uid).collection('daily_missions').doc(date);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    Widget shell({required bool done, required Widget child}) {
      const Color vinhoSolido = Color(0xFF560405); // rgb(86,4,5)
      const Color verdeSolido = Color(0xFF0E7A3A);

      return AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: done ? verdeSolido : vinhoSolido,
          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: child,
        ),
      );
    }

    if (user == null) {
      return shell(
        done: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Center(
            child: Text(
              "Entre para ver sua missão do dia.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    final uid = user.uid;
    final dateKey = _todayKey();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadMissions(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return shell(
            done: false,
            child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2)),
          );
        }

        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return shell(
            done: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Center(
                child: Text(
                  "Não foi possível carregar a missão do dia.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.90), fontWeight: FontWeight.w800),
                ),
              ),
            ),
          );
        }

        final mission = _pickMission(snap.data!, uid, dateKey);
        final title = mission['titulo']?.toString().trim();
        final desc = mission['descricao']?.toString().trim();
        final missionId = mission['id'] ?? 0;

        return StreamBuilder<DocumentSnapshot>(
          stream: _doc(uid, dateKey).snapshots(),
          builder: (context, s) {
            final done = (s.data?.data() as Map<String, dynamic>?)?['completed'] == true;

            Future<void> toggleDone() async {
              try {
                await _doc(uid, dateKey).set(
                  {
                    "missionId": missionId,
                    "completed": !done,
                    "updatedAt": FieldValue.serverTimestamp(),
                    if (!done) "completedAt": FieldValue.serverTimestamp(),
                  },
                  SetOptions(merge: true),
                );
                if (!mounted) return;
                HapticFeedback.lightImpact();
              } on FirebaseException catch (e) {
                if (!mounted) return;

                final msg = (e.code == 'permission-denied')
                    ? "Sem permissão para salvar. Ajuste as regras do Firestore."
                    : "Erro ao salvar: ${e.message ?? e.code}";

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg), backgroundColor: Colors.black.withOpacity(0.85)),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text("Erro inesperado ao salvar."), backgroundColor: Colors.black.withOpacity(0.85)),
                );
              }
            }

            return shell(
              done: done,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // header
                    Row(
                      children: [
                        Icon(
                          done ? Icons.verified_rounded : Icons.task_alt_rounded,
                          color: Colors.white.withOpacity(0.96),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Missão do dia",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withOpacity(0.96),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: toggleDone,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.30)),
                            ),
                            child: Text(
                              done ? "Feito" : "Concluir",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // título (sem caixa)
                    Text(
                      title?.isNotEmpty == true ? title! : "Missão sem título",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.98),
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (desc?.isNotEmpty == true)
                      Text(
                        desc!,
                        maxLines: done ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          color: Colors.white.withOpacity(0.88),
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                    const Spacer(),

                    if (done)
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Missão concluída",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
