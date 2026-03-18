import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ListaNovenasPage extends StatefulWidget {
  const ListaNovenasPage({super.key});

  @override
  State<ListaNovenasPage> createState() => _ListaNovenasPageState();
}

class _ListaNovenasPageState extends State<ListaNovenasPage> {
  // ===== PALETA (vinho) =====
  static const Color vinhoProfundo = Color(0xFF3A0808);
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color vinhoDestaque = Color(0xFF8E2A2A);

  static const Color paper = Color(0xFFFBFAF8);
  static const Color cardBase = Colors.white;

  static const double rCard = 18;

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 22,
    offset: const Offset(0, 10),
  );

  final TextEditingController _searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _bancoNovenas = [];
  List<Map<String, dynamic>> _filtradas = [];

  bool _loading = false;
  String? _erro;

  // =========================
  // CONFIG: SUA API AQUI
  // =========================
  static const String _apiUrl = 'https://novena-api.onrender.com/novenas';

  @override
  void initState() {
    super.initState();
    _filtradas = List.from(_bancoNovenas);
    _searchCtrl.addListener(() => _filtrar(_searchCtrl.text));
    _carregarNovenas();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _hardRefresh() async {
    if (_loading) return;

    _SantoImageService.clearCache();

    // 2) limpa cache em disco/memória do CachedNetworkImage
    // (DefaultCacheManager é o cache padrão usado por ele)
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}

    // 3) chama a API de novo
    await _carregarNovenas();
  }

  // =========================
  // API
  // =========================
  Future<void> _carregarNovenas() async {
    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      final url = Uri.parse(_apiUrl).replace(queryParameters: {
        "limit": "200",
        "offset": "0",
        "ts": DateTime.now().millisecondsSinceEpoch.toString(),
      });

      final resp = await http.get(
        url,
        headers: const {
          "Cache-Control": "no-cache",
          "Pragma": "no-cache",
        },
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        setState(() {
          _erro = "Falha ao carregar (${resp.statusCode}).";
          _loading = false;
        });
        return;
      }

      final decoded = jsonDecode(resp.body);

      // { items: [ ... ] }
      final List list =
      (decoded is Map && decoded['items'] is List) ? decoded['items'] : <dynamic>[];

      String _mesFromPeriodo(String inicio, String fim) {
        String s = inicio.trim();
        if (s.isEmpty) s = fim.trim();
        if (s.isEmpty) return "OUTROS";

        final m = RegExp(r'(\d{1,2})\D+(\d{1,2})').firstMatch(s);
        if (m == null) return "OUTROS";

        final mesNum = int.tryParse(m.group(2) ?? "");
        if (mesNum == null || mesNum < 1 || mesNum > 12) return "OUTROS";

        const map = <int, String>{
          1: "Janeiro",
          2: "Fevereiro",
          3: "Março",
          4: "Abril",
          5: "Maio",
          6: "Junho",
          7: "Julho",
          8: "Agosto",
          9: "Setembro",
          10: "Outubro",
          11: "Novembro",
          12: "Dezembro",
        };
        return map[mesNum] ?? "OUTROS";
      }

      String _santoQueryFromTitulo(String titulo) {
        var t = titulo.trim();

        // remove prefixo "Novena ..."
        t = t.replaceAll(RegExp(r'^novena\s+', caseSensitive: false), '');

        // remove somente NO COMEÇO: "a ", "ao ", "à "
        t = t.replaceAll(RegExp(r'^(a|ao|à)\s+', caseSensitive: false), '');

        // normaliza alguns padrões comuns no começo
        t = t.replaceAll(
          RegExp(r'^nossa\s+senhora\s+', caseSensitive: false),
          'Nossa Senhora ',
        );
        t = t.replaceAll(RegExp(r'^santa\s+', caseSensitive: false), 'Santa ');
        t = t.replaceAll(RegExp(r'^sao\s+', caseSensitive: false), 'São ');
        t = t.replaceAll(RegExp(r'^santo\s+', caseSensitive: false), 'Santo ');

        // casos com apóstrofo
        t = t.replaceAll("SANT'ANA", "Santa Ana");
        t = t.replaceAll("SANT’ANA", "Santa Ana");

        // espaços
        t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

        // title case simples
        t = t.split(' ').map((w) {
          if (w.isEmpty) return w;
          if (w.length == 1) return w.toUpperCase();
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        }).join(' ');

        // correções comuns
        t = t.replaceAll("Sao ", "São ");
        t = t.replaceAll("Sao", "São");

        return t.trim();
      }

      final novenas = list.map<Map<String, dynamic>>((e) {
        final inicio = (e["periodo_inicio"] ?? "").toString().trim();
        final fim = (e["periodo_fim"] ?? "").toString().trim();
        final periodo = (inicio.isNotEmpty && fim.isNotEmpty)
            ? "$inicio - $fim"
            : (inicio.isNotEmpty ? inicio : (fim.isNotEmpty ? fim : ""));

        final mesCalculado = _mesFromPeriodo(inicio, fim);

        final titulo = (e["titulo"] ?? "").toString();
        final santoQuery = _santoQueryFromTitulo(titulo);

        return {
          "novenaId": (e["slug"] ?? e["id"] ?? "").toString(),
          "nome": titulo,
          "label": (e["subtitulo"] ?? "").toString(),
          "periodo": periodo,
          "mes": mesCalculado,
          "type": "",
          "daysCount": 9,

          // mantido só para busca/filtro
          "santoQuery": santoQuery,
        };
      }).toList();

      const ordemMes = <String, int>{
        "Janeiro": 1,
        "Fevereiro": 2,
        "Março": 3,
        "Abril": 4,
        "Maio": 5,
        "Junho": 6,
        "Julho": 7,
        "Agosto": 8,
        "Setembro": 9,
        "Outubro": 10,
        "Novembro": 11,
        "Dezembro": 12,
        "OUTROS": 13,
      };

      novenas.sort((a, b) {
        final ma = (a["mes"] ?? "").toString();
        final mb = (b["mes"] ?? "").toString();
        final oa = ordemMes[ma] ?? 999;
        final ob = ordemMes[mb] ?? 999;
        if (oa != ob) return oa.compareTo(ob);
        final na = (a["nome"] ?? "").toString();
        final nb = (b["nome"] ?? "").toString();
        return na.compareTo(nb);
      });

      setState(() {
        _bancoNovenas
          ..clear()
          ..addAll(novenas);
        _filtradas = List.from(_bancoNovenas);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _erro = "Erro ao carregar: $e";
        _loading = false;
      });
    }
  }

  void _filtrar(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtradas = List.from(_bancoNovenas);
      } else {
        _filtradas = _bancoNovenas.where((n) {
          final nome = (n['nome'] ?? "").toString().toLowerCase();
          final mes = (n['mes'] ?? "").toString().toLowerCase();
          final periodo = (n['periodo'] ?? "").toString().toLowerCase();
          final type = (n['type'] ?? "").toString().toLowerCase();
          final label = (n['label'] ?? "").toString().toLowerCase();
          final daysCount = (n['daysCount'] ?? "").toString().toLowerCase();
          final santoQuery = (n['santoQuery'] ?? "").toString().toLowerCase();

          return nome.contains(query) ||
              santoQuery.contains(query) ||
              mes.contains(query) ||
              periodo.contains(query) ||
              type.contains(query) ||
              label.contains(query) ||
              daysCount.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _selecionarNovena(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('novena_ativa_nome', (item['nome'] ?? "Novena").toString());
    await prefs.setString('novena_ativa_id', (item['novenaId'] ?? "").toString());
    await prefs.setInt('novena_ativa_dia', 1);

    await prefs.setString('novena_ativa_label', (item['label'] ?? "").toString());
    await prefs.setString('novena_ativa_type', (item['type'] ?? "").toString());
    await prefs.setString('novena_ativa_periodo', (item['periodo'] ?? "").toString());

    if (!mounted) return;
    Navigator.pop(context, true);
  }

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
          "Catálogo de Novenas",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        actions: [
          IconButton(
            tooltip: "Atualizar",
            onPressed: _loading ? null : _hardRefresh,
            icon: Icon(Icons.refresh_rounded, color: vinhoIdentidade.withOpacity(0.95)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // ===== BUSCA =====
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: Container(
              decoration: BoxDecoration(
                color: cardBase,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [_softShadow],
              ),
              child: TextField(
                controller: _searchCtrl,
                cursorColor: vinhoIdentidade,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Buscar novena, santo, mês...",
                  hintStyle: TextStyle(color: Colors.black.withOpacity(0.35)),
                  prefixIcon: Icon(Icons.search, color: vinhoIdentidade.withOpacity(0.85)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
          ),

          if (_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: vinhoIdentidade.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Carregando da API...",
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.55),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

          if (_erro != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: vinhoDestaque.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: vinhoDestaque.withOpacity(0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: vinhoIdentidade),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _erro!,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.72),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _hardRefresh,
                      child: const Text("Tentar"),
                    ),
                  ],
                ),
              ),
            ),

          // ===== LISTA =====
          Expanded(
            child: _filtradas.isEmpty
                ? Center(
              child: Text(
                _loading ? "Carregando..." : "Nenhuma novena encontrada",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
                : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
              itemCount: _filtradas.length,
              itemBuilder: (context, i) {
                final item = _filtradas[i];

                final bool mostrarCabecalho =
                    i == 0 || (_filtradas[i - 1]['mes'] ?? "") != (item['mes'] ?? "");

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mostrarCabecalho) _HeaderMes(mes: (item['mes'] ?? "").toString()),
                    _NovenaTile(
                      nome: (item['nome'] ?? "").toString(),
                      periodo: (item['periodo'] ?? "").toString(),
                      type: (item['type'] ?? "").toString(),
                      daysCount: (item['daysCount'] ?? "").toString(),
                      label: (item['label'] ?? "").toString(),
                      santoQuery: (item['santoQuery'] ?? "").toString(),
                      onTap: () => _selecionarNovena(item),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _HeaderMes extends StatelessWidget {
  const _HeaderMes({required this.mes});
  final String mes;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    if (mes.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Text(
            mes.toUpperCase(),
            style: const TextStyle(
              color: vinhoIdentidade,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: Colors.black.withOpacity(0.10), height: 1),
          ),
        ],
      ),
    );
  }
}

class _SantoImageService {
  static final Map<String, String?> _cache = {};

  static void clearCache() => _cache.clear();

  static const String _base = "https://novena-api.onrender.com";

  static Future<String?> getThumbUrlByQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    if (_cache.containsKey(q)) return _cache[q];

    try {
      final url = Uri.parse("$_base/imagens?q=${Uri.encodeComponent(q)}");
      final resp = await http.get(url).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        _cache[q] = null;
        return null;
      }

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final image = (decoded is Map) ? (decoded["match"]?["image"]?.toString() ?? "") : "";

      _cache[q] = image.isNotEmpty ? image : null;
      return _cache[q];
    } catch (_) {
      _cache[q] = null;
      return null;
    }
  }
}

class _NovenaTile extends StatelessWidget {
  const _NovenaTile({
    required this.nome,
    required this.periodo,
    required this.type,
    required this.daysCount,
    required this.label,
    required this.santoQuery,
    required this.onTap,
  });

  final String nome;
  final String periodo;
  final String type;
  final String daysCount;
  final String label;
  final String santoQuery;
  final VoidCallback onTap;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color vinhoDestaque = Color(0xFF8E2A2A);

  static const double _avatarSize = 56;
  static const double _avatarRadius = 20;

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 18,
    offset: const Offset(0, 8),
  );

  String _limitar13(String s) {
    final t = s.trim();
    if (t.length <= 13) return t;
    return "${t.substring(0, 10)}...";
  }

  void _mostrarPeriodoDetalhado(BuildContext context, String periodoCompleto) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Período"),
        content: Text(periodoCompleto),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _abrirImagem(BuildContext context, String url, String titulo) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "fechar",
      barrierColor: Colors.black.withOpacity(0.78),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) {
        return SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 5.0,
                      panEnabled: true,
                      scaleEnabled: true,
                      child: Hero(
                        tag: "santo_$url",
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: vinhoIdentidade.withOpacity(0.9),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Text(
                                "Não foi possível carregar a imagem",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static const double _imgW = 88;

  Widget _leftFallback() {
    return Container(
      width: _imgW,
      height: double.infinity,
      decoration: BoxDecoration(
        color: vinhoDestaque.withOpacity(0.10),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.account_circle_rounded,
        color: vinhoIdentidade.withOpacity(0.85),
        size: 36,
      ),
    );
  }

  Widget _leftImage(BuildContext context, String url) {
    return InkWell(
      onTap: () => _abrirImagem(context, url, nome),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => Container(
          color: Colors.black.withOpacity(0.04),
          alignment: Alignment.center,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: vinhoIdentidade.withOpacity(0.8),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _leftFallback(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_ListaNovenasPageState.rCard),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [_softShadow],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_ListaNovenasPageState.rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(_ListaNovenasPageState.rCard),
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(_ListaNovenasPageState.rCard),
                    bottomLeft: Radius.circular(_ListaNovenasPageState.rCard),
                  ),
                  child: SizedBox(
                    width: _imgW,
                    height: double.infinity,
                    child: FutureBuilder<String?>(
                      future: _SantoImageService.getThumbUrlByQuery(santoQuery),
                      builder: (context, snap) {
                        final url = snap.data;
                        if (url == null || url.isEmpty) return _leftFallback();
                        return _leftImage(context, url);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Colors.black.withOpacity(0.82),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (periodo.trim().isNotEmpty)
                              GestureDetector(
                                onTap: () =>
                                    _mostrarPeriodoDetalhado(context, periodo.trim()),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: 14,
                                      color: vinhoIdentidade.withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _limitar13(periodo),
                                      style: TextStyle(
                                        color: vinhoIdentidade.withOpacity(0.9),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (type.trim().isNotEmpty)
                              _MiniPill(
                                text: type,
                                tint: vinhoDestaque.withOpacity(0.10),
                                border: vinhoDestaque.withOpacity(0.16),
                                textColor: vinhoDestaque,
                                icon: Icons.category_rounded,
                              ),
                          ],
                        ),


                        if (label.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            label,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.62),
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
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

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.text,
    required this.tint,
    required this.border,
    required this.textColor,
    required this.icon,
    this.onTap,
  });

  final String text;
  final Color tint;
  final Color border;
  final Color textColor;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: child,
      ),
    );
  }
}
