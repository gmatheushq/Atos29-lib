import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class OracoesPage extends StatefulWidget {
  const OracoesPage({super.key});

  @override
  State<OracoesPage> createState() => _OracoesPageState();
}

class _OracoesPageState extends State<OracoesPage> {
  // ===== PALETA =====
  static const Color vinhoProfundo = Color(0xFF3A0808);
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color paper = Color(0xFFFBFAF8);

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 22,
    offset: const Offset(0, 10),
  );

  static const String apiBaseUrl = 'https://oracoes-api.onrender.com';

  bool _loading = true;
  String _erro = '';

  List<dynamic> _oracoes = [];
  List<dynamic> _oracoesFiltradas = [];

  // ===== BUSCA =====
  bool _searching = false;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // ===== SCROLL POR ÍNDICE =====
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
  ItemPositionsListener.create();

  bool _sumarioAberto = false;

  final ScrollController _sumarioScrollController = ScrollController();

  int? _highlightedIndex;

  @override
  void initState() {
    super.initState();
    _buscarOracoes(forceRefresh: false);
  }

  @override
  void dispose() {
    _sumarioScrollController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ================= API =================
  Future<void> _buscarOracoes({required bool forceRefresh}) async {
    setState(() {
      _loading = true;
      _erro = '';
      if (forceRefresh) {
        _oracoes.clear();
        _oracoesFiltradas.clear();
      }
    });

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$apiBaseUrl/oracoes?lang=pt&_ts=$ts');

      final res = await http.get(
        uri,
        headers: const {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      if (res.statusCode != 200) throw Exception('Erro ${res.statusCode}');

      final decoded = jsonDecode(res.body);
      final list = decoded is Map ? decoded['items'] : decoded;
      final items = (list as List?) ?? [];

      items.sort((a, b) {
        final ta = (a['titulo'] ?? '').toString().toLowerCase();
        final tb = (b['titulo'] ?? '').toString().toLowerCase();
        return ta.compareTo(tb);
      });

      setState(() {
        _oracoes = items;
        _oracoesFiltradas = items;
        _loading = false;
      });

      if (_query.isNotEmpty) _filtrar(_query);
    } catch (_) {
      setState(() {
        _erro = 'Não foi possível carregar as orações';
        _loading = false;
      });
    }
  }

  // ================= BUSCA =================
  void _filtrar(String q) {
    final query = q.trim().toLowerCase();

    setState(() {
      _query = query;

      if (query.isEmpty) {
        _oracoesFiltradas = _oracoes;
      } else {
        _oracoesFiltradas = _oracoes.where((o) {
          final titulo = (o['titulo'] ?? '').toString().toLowerCase();
          final pt = (o['pt'] ?? '').toString().toLowerCase();
          final la = (o['la'] ?? '').toString().toLowerCase();

          return titulo.contains(query) ||
              pt.contains(query) ||
              la.contains(query);
        }).toList();
      }
    });

    if (_sumarioScrollController.hasClients) {
      _sumarioScrollController.jumpTo(0);
    }
  }

  void _abrirBusca() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  void _fecharBusca() {
    _searchCtrl.clear();
    _filtrar('');
    setState(() => _searching = false);
    _searchFocus.unfocus();
  }

  // ================= SCROLL + HIGHLIGHT =================
  void _scrollToIndex(int indexDaOracao) {
    setState(() {
      _sumarioAberto = false;
      _highlightedIndex = indexDaOracao;
    });

    _itemScrollController.scrollTo(
      index: indexDaOracao + 1,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _highlightedIndex = null);
    });
  }

  // ================= SUMÁRIO (COM SCROLLBAR) =================
  Widget _Sumario() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(0),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [_softShadow],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _sumarioAberto = !_sumarioAberto),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 26, 16),

              child: Row(
                children: [
                  const Icon(Icons.list_alt_rounded, color: vinhoIdentidade),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Sumário',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _sumarioAberto ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: vinhoIdentidade,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            crossFadeState: _sumarioAberto
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: Scrollbar(
                    controller: _sumarioScrollController,
                    thumbVisibility: true,
                    thickness: 3,
                    radius: const Radius.circular(999),
                    child: ListView.separated(
                      controller: _sumarioScrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(26, 16, 26, 16),

                      itemCount: _oracoesFiltradas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final o = _oracoesFiltradas[i];
                        final titulo = (o['titulo'] ?? '').toString();

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _scrollToIndex(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    titulo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: vinhoIdentidade,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: paper,
        foregroundColor: vinhoProfundo,
        centerTitle: true,
        title: !_searching
            ? const Text(
          'Orações',
          style: TextStyle(fontWeight: FontWeight.w900),
        )
            : TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          autofocus: true,
          onChanged: _filtrar,
          decoration: const InputDecoration(
            hintText: 'Buscar oração...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              !_searching ? Icons.search : Icons.close,
              color: vinhoIdentidade,
            ),
            onPressed: () {
              if (!_searching) {
                _abrirBusca();
              } else {
                _fecharBusca();
              }
            },
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_rounded),
            color: vinhoIdentidade,
            onPressed:
            _loading ? null : () => _buscarOracoes(forceRefresh: true),
          ),
        ],
      ),
      body: _loading
          ? Center(
        child: CircularProgressIndicator(
          color: vinhoIdentidade,
          strokeWidth: 2.6,
        ),
      )
          : _erro.isNotEmpty
          ? _ErroState(
        mensagem: _erro,
        onRetry: () => _buscarOracoes(forceRefresh: true),
      )
          : RefreshIndicator(
        color: vinhoIdentidade,
        onRefresh: () => _buscarOracoes(forceRefresh: true),
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 26),
          itemCount: _oracoesFiltradas.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return _Sumario();

            final index = i - 1;
            final o = _oracoesFiltradas[index];

            return _OracaoCard(
              titulo: o['titulo'] ?? '',
              textoPt: o['pt'] ?? '',
              textoLa: o['la'] ?? '',
              shadow: _softShadow,
              highlighted: index == _highlightedIndex,
            );
          },
        ),
      ),
    );
  }
}

// ================= CARD =================

class _OracaoCard extends StatefulWidget {
  const _OracaoCard({
    required this.titulo,
    required this.textoPt,
    required this.textoLa,
    required this.shadow,
    this.highlighted = false,
  });

  final String titulo;
  final String textoPt;
  final String textoLa;
  final BoxShadow shadow;
  final bool highlighted;

  @override
  State<_OracaoCard> createState() => _OracaoCardState();
}

class _OracaoCardState extends State<_OracaoCard> {
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  int _page = 0;

  void _next() {
    if (_page < 1) setState(() => _page++);
  }

  void _prev() {
    if (_page > 0) setState(() => _page--);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(0),
          border: Border.all(
            color: widget.highlighted
                ? vinhoIdentidade.withOpacity(0.6)
                : Colors.black.withOpacity(0.06),
            width: widget.highlighted ? 1.4 : 1,
          ),
          boxShadow: widget.highlighted
              ? [
            BoxShadow(
              color: vinhoIdentidade.withOpacity(0.28),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ]
              : [widget.shadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 26, 10),
              child: Text(
                widget.titulo,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

            GestureDetector(
              onHorizontalDragEnd: (d) {
                if (d.primaryVelocity == null) return;
                if (d.primaryVelocity! < -40) _next();
                if (d.primaryVelocity! > 40) _prev();
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  final offset = Tween<Offset>(
                    begin: Offset(_page == 0 ? -0.05 : 0.05, 0),
                    end: Offset.zero,
                  ).animate(anim);

                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: offset,
                      child: child,
                    ),
                  );
                },
                child: _TextoOracao(
                  key: ValueKey(_page),
                  _page == 0 ? widget.textoPt : widget.textoLa,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _DotsIndicator(
                index: _page,
                onTap: (i) => setState(() => _page = i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= COMPONENTES =================

class _TextoOracao extends StatelessWidget {
  const _TextoOracao(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 16, 26, 12),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15.5,
          height: 1.7,
          fontStyle: FontStyle.italic,
          color: Colors.black.withOpacity(0.74),
        ),
      ),
    );
  }
}

/// Indicador ORIGINAL (duas "barrinhas")
class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({
    required this.index,
    required this.onTap,
  });

  final int index;
  final void Function(int) onTap;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  Widget _dot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 22 : 10,
      height: 6,
      decoration: BoxDecoration(
        color: active ? vinhoIdentidade : vinhoIdentidade.withOpacity(0.28),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(onTap: () => onTap(0), child: _dot(index == 0)),
        const SizedBox(width: 8),
        GestureDetector(onTap: () => onTap(1), child: _dot(index == 1)),
      ],
    );
  }
}

class _ErroState extends StatelessWidget {
  const _ErroState({
    required this.mensagem,
    required this.onRetry,
  });

  final String mensagem;
  final VoidCallback onRetry;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: vinhoIdentidade),
            const SizedBox(height: 14),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                "Tentar novamente",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
