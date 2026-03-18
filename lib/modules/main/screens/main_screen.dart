import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'feed_page.dart';
import 'home_page.dart';
import 'santo_page.dart';
import 'calendario_page.dart';

// 🎨 cores do app
const atosPrimary = Color(0xFF6A0F0F);
const atosDeep = Color(0xFF3A0808);
const atosBg = Color(0xFFFAF9F7);

class MainScreen extends StatefulWidget {
  final String nickname;

  const MainScreen({
    super.key,
    required this.nickname,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _indiceAtual = 0;
  late final PageController _pageController;

  final List<Widget> _paginasFixas = const [
    FeedPage(),
    SantoPage(),
    CalendarioPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _indiceAtual);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppPrefetch.instance.warmUp();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _irParaPagina(int index) {
    setState(() => _indiceAtual = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginas = <Widget>[
      ..._paginasFixas,
      HomePage(nickname: widget.nickname),
    ];

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      extendBody: true,

      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _indiceAtual = i),
        physics: const BouncingScrollPhysics(),
        children: paginas,
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.white.withOpacity(0.70),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // risquinho divisor
                Container(
                  height: 1,
                  color: Colors.black.withOpacity(0.12),
                ),

                NavigationBarTheme(
                  data: const NavigationBarThemeData(
                    height: 56,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    indicatorColor: Colors.transparent,
                  ),
                  child: NavigationBar(
                    selectedIndex: _indiceAtual,
                    onDestinationSelected: _irParaPagina,
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                    destinations: [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined, color: cs.onSurfaceVariant),
                        selectedIcon: Icon(Icons.home, color: cs.primary),
                        label: 'Feed',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.church_outlined, color: cs.onSurfaceVariant),
                        selectedIcon: Icon(Icons.church, color: cs.primary),
                        label: 'Santo',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined, color: cs.onSurfaceVariant),
                        selectedIcon: Icon(Icons.calendar_month, color: cs.primary),
                        label: 'Agenda',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline, color: cs.onSurfaceVariant),
                        selectedIcon: Icon(Icons.person, color: cs.primary),
                        label: 'Perfil',
                      ),
                    ],
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppPrefetch {
  AppPrefetch._();
  static final instance = AppPrefetch._();

  final http.Client _client = http.Client();
  bool _didRun = false;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<void>> _inFlight = {};

  // --------- Ajuste de TTL por tipo ----------
  static const Duration ttlSanto = Duration(minutes: 30);
  static const Duration ttlLiturgia = Duration(minutes: 30);
  static const Duration ttlMissoes = Duration(minutes: 10);
  static const Duration ttlOracoes = Duration(hours: 24);
  static const Duration ttlNovenas = Duration(hours: 24);

  String _todayKey() {
    final now = DateTime.now();
    return "${now.year.toString().padLeft(4, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> warmUp() async {
    if (_didRun) return;
    _didRun = true;

    final hoje = DateTime.now();
    final santoUri = Uri.parse(
      "https://catolicoapp.com/wp-json/wp/v2/santos?dia=${hoje.day}&mes=${hoje.month}",
    );

    final liturgiaUri = Uri.parse("https://liturgia.up.railway.app/v2/");
    final missoesUri = Uri.parse("https://missions-api.onrender.com/missions");
    final oracoesUri = Uri.parse("https://oracoes-api.onrender.com/oracoes?lang=pt");
    final novenasUri = Uri.parse("https://novena-api.onrender.com/novenas");

    // Dispara tudo em paralelo (sem bloquear UI)
    await Future.wait([
      getJson(santoUri, ttl: ttlSanto, dayKey: _todayKey(), force: false),
      getJson(liturgiaUri, ttl: ttlLiturgia, dayKey: _todayKey(), force: false),
      getJson(missoesUri, ttl: ttlMissoes, force: false),
      getJson(oracoesUri, ttl: ttlOracoes, force: false),
      getJson(novenasUri, ttl: ttlNovenas, force: false),
    ]);
  }

  Future<dynamic> getJson(
      Uri uri, {
        required Duration ttl,
        String? dayKey,
        bool force = false,
        Map<String, String>? headers,
      }) async {
    final key = uri.toString();
    final now = DateTime.now();

    final cached = _cache[key];
    final isFresh = cached != null &&
        cached.updatedAt != null &&
        now.difference(cached.updatedAt!) <= ttl &&
        (dayKey == null || cached.dayKey == dayKey);

    if (!force && isFresh) return cached!.json;

    if (!force && cached?.json != null) {
      _refresh(uri, ttl: ttl, dayKey: dayKey, headers: headers);
      return cached!.json;
    }
    await _refresh(uri, ttl: ttl, dayKey: dayKey, headers: headers);
    return _cache[key]?.json;
  }

  dynamic getCached(Uri uri) => _cache[uri.toString()]?.json;

  Future<void> _refresh(
      Uri uri, {
        required Duration ttl,
        String? dayKey,
        Map<String, String>? headers,
      }) {
    final key = uri.toString();
    if (_inFlight.containsKey(key)) return _inFlight[key]!;

    final future = () async {
      try {
        final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) return;

        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        _cache[key] = _CacheEntry(
          json: decoded,
          updatedAt: DateTime.now(),
          dayKey: dayKey,
        );
      } catch (_) {
      } finally {
        _inFlight.remove(key);
      }
    }();

    _inFlight[key] = future;
    return future;
  }
}

class _CacheEntry {
  _CacheEntry({
    required this.json,
    required this.updatedAt,
    required this.dayKey,
  });

  final dynamic json;
  final DateTime? updatedAt;
  final String? dayKey;
}
