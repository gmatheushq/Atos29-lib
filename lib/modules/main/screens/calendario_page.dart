import 'dart:convert';
import 'dart:ui';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarioPage extends StatefulWidget {
  const CalendarioPage({super.key});

  @override
  State<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage> {
  // ===== DNA vinho/paper =====
  static const Color vinhoProfundo = Color(0xFF3A0808);
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  static const Color paper = Color(0xFFFBFAF8);
  static const Color cardBase = Colors.white;

  static const String _prefsRecentColorsKey = 'recent_event_colors_v1';

  ThemeData _neutralTimePickerTheme(BuildContext context) {
    final base = Theme.of(context);

    const Color surface = Colors.white;
    const Color onSurface = Colors.black87;

    // Ponteiro/bolinha (neutro)
    const Color accent = Colors.black;

    // Fundo do chip selecionado (hora/minuto lá em cima)
    final Color selectedBg = Colors.black.withOpacity(0.08);

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: surface,
        onSurface: onSurface,

        onPrimary: Colors.white,
        // texto/ícone em cima do primary (bolinha)
        onSecondary: Colors.white,

        primaryContainer: selectedBg,
        onPrimaryContainer: onSurface,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,

        hourMinuteColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.black.withOpacity(0.08);
          }
          return Colors.black.withOpacity(0.03);
        }),
        hourMinuteTextColor:
        MaterialStateColor.resolveWith((states) => onSurface),

        dayPeriodColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.black.withOpacity(0.08);
          }
          return Colors.black.withOpacity(0.03);
        }),
        dayPeriodTextColor:
        MaterialStateColor.resolveWith((states) => onSurface),

        dialHandColor: Colors.black,

        dialTextColor: MaterialStateColor.resolveWith((states) {
          if (!states.contains(MaterialState.selected)) {
            return Colors.black87;
          }
          return Colors.white;
        }),

        dialBackgroundColor: Colors.black.withOpacity(0.06),
        entryModeIconColor: Colors.black,

        helpTextStyle: TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.black.withOpacity(0.55),
        ),

        hourMinuteTextStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 44,
          letterSpacing: -1,
        ),

        dayPeriodTextStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.black87,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  ThemeData _neutralDatePickerTheme(BuildContext context) {
    final base = Theme.of(context);

    const Color surface = Colors.white;
    const Color onSurface = Colors.black87;
    const Color accent = Colors.black;

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.black87,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  final List<int> _basePalette = <int>[
    vinhoIdentidade.value,
    0xFF0F766E, // neutros iniciais só pra 1ª vez (depois vira recentes)
    0xFFC62828,
    0xFF2563EB,
    0xFFD4B46A,
    0xFF1F1F1F,
  ];

  Color _clamp01Color(Color c) => c; // só pra ficar claro que usamos clamp abaixo

  Color _shiftLightness(Color base, double delta) {
    final hsl = HSLColor.fromColor(base);
    final newL = (hsl.lightness + delta).clamp(0.0, 1.0);
    return hsl.withLightness(newL).toColor();
  }

  LinearGradient _safeGradientFromInt(int colorValue) {
    final base = Color(colorValue);

    final darker = _shiftLightness(base, -0.10);
    final lighter = _shiftLightness(base, 0.10);

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [darker, base, lighter],
      stops: const [0.0, 0.55, 1.0],
    );
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
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(message),
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
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                confirmText,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _adminOnlyEventSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3A0808),
            Color(0xFF6A0F0F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Text(
                  "ADM",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Criar evento (visível só para admins)",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _adminScopeButton(
                  label: "Cancelar", icon: Icons.close_rounded, onTap: () {
                // aqui você pode limpar seleção depois se quiser
                _toast("Cancelado");
              }),
              const SizedBox(width: 10),
              _adminScopeButton(
                  label: "Todos", icon: Icons.public_rounded, onTap: () {
                _toast("Modo: Todos");
              }),
              const SizedBox(width: 10),
              _adminScopeButton(
                  label: "Admin", icon: Icons.lock_rounded, onTap: () {
                _toast("Modo: Admin");
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adminScopeButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== NOVO: TAG/SEGMENTOS (ADMIN/TODOS) =====================
  Widget _scopeTag({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.black : Colors.black.withOpacity(0.10),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : Colors.black.withOpacity(0.75),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== NOVO: BADGE DO CARD (ADMIN SÓ VÊ) =====================
  Widget _scopeBadge(String scope, {required bool onDark}) {
    final isAdminScope = scope == "admin";
    final text = isAdminScope ? "ADMIN" : "TODOS";

    final bg = onDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.06);
    final fg = onDark ? Colors.white : Colors.black.withOpacity(0.75);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.10),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.6,
          color: fg,
        ),
      ),
    );
  }

  List<int> _recentColors = <int>[];

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 22,
    offset: const Offset(0, 10),
  );

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  CalendarFormat _format = CalendarFormat.month;

  bool _refreshing = false;

  // ===== Confissão local (somente usuário) =====
  Set<String> _diasConfessados = {};
  final Map<String, String> _horaConfissaoPorDia = {}; // YYYY-MM-DD => HH:mm

  // ===== Eventos gerais (Firestore) =====
  final Map<String, List<_AdminEvent>> _eventsByDay = {};
  final Set<String> _monthsLoaded = {}; // "YYYY-MM"

  // ===== Admin flag =====
  bool _isAdmin = false;

  // ===================== utils =====================
  String _formatarChave(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _formatarChaveMes(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}";

  String _fmtDataCurta(DateTime d) {
    const meses = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"];
    return "${d.day} ${meses[d.month - 1]} ${d.year}";
  }

  String _fmtMesAno(DateTime d) {
    const meses = [
      "Janeiro",
      "Fevereiro",
      "Março",
      "Abril",
      "Maio",
      "Junho",
      "Julho",
      "Agosto",
      "Setembro",
      "Outubro",
      "Novembro",
      "Dezembro"
    ];
    return "${meses[d.month - 1]} ${d.year}";
  }

  String _normalizeSpacing(String input) {
    var s = input.replaceAll(RegExp(r'<[^>]*>'), '');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8216;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&#8230;', '...')
        .trim();
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAllMapped(
      RegExp(r'([a-zà-ÿ])([A-ZÀ-Ý])'),
          (m) => "${m.group(1)} ${m.group(2)}",
    );
    s = s.replaceAll(RegExp(r'\s*[:\-]\s*'), ': ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _errToText(Object e) {
    if (e is FirebaseException) {
      return "${e.code}: ${e.message ?? ''}".trim();
    }
    return e.toString();
  }

  Widget _glassSheet({required Widget child}) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: child,
        ),
      ),
    );
  }

  _AdminEvent? _findAdminEventById(String id) {
    for (final list in _eventsByDay.values) {
      for (final e in list) {
        if (e.id == id) return e;
      }
    }
    return null;
  }

  Future<void> _openEventActions(Map<String, dynamic> ev) async {
    final isAdminEvent = ev['isAdminEvent'] == true;
    if (!isAdminEvent) return;

    final id = (ev['id'] ?? '').toString();
    final found = _findAdminEventById(id);
    if (found == null) {
      _toast("Evento não encontrado");
      return;
    }

    if (!_isAdmin) {
      _toast("Somente admins podem editar");
      return;
    }

    await _openAdminEventDialog(editing: found);
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = _selectedDay!;
    _bootstrap();
  }

  Future<void> _loadRecentColors() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsRecentColorsKey) ?? const [];

    final parsed = <int>[];
    for (final s in list) {
      final v = int.tryParse(s);
      if (v != null) parsed.add(v);
    }

    final max = _basePalette.length - 1;
    final seen = <int>{};
    final dedup = <int>[];
    for (final v in parsed) {
      if (v == vinhoIdentidade.value) continue;
      if (seen.add(v)) dedup.add(v);
    }
    _recentColors = dedup.take(max).toList();
    if (_recentColors.isEmpty) {
      _recentColors = _basePalette.skip(1).take(max).toList();
    } else {
      while (_recentColors.length < max) {
        _recentColors.add(_recentColors.last);
      }
      _recentColors = _recentColors.take(max).toList();
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveRecentColors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsRecentColorsKey,
      _recentColors.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _rememberColor(int colorValue) async {

    if (colorValue == vinhoIdentidade.value) return;

    final max = _basePalette.length - 1;

    _recentColors.remove(colorValue);
    _recentColors.insert(0, colorValue);

    if (_recentColors.length > max) {
      _recentColors = _recentColors.take(max).toList();
    } else {
      while (_recentColors.length < max) {
        _recentColors.add(colorValue);
      }
    }

    await _saveRecentColors();
    if (mounted) setState(() {});
  }

  List<int> _currentPalette() {
    final max = _basePalette.length - 1;

    final merged = <int>[vinhoIdentidade.value];

    if (_recentColors.isEmpty) {
      merged.addAll(_basePalette.skip(1).take(max));
    } else {
      merged.addAll(_recentColors.take(max));
    }

    return merged.take(_basePalette.length).toList();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadIsAdmin(),
      _carregarConfissoes(),
      _carregarHorasConfissao(),
      _loadRecentColors(),
    ]);
    await _carregarEventosDoMes(_focusedDay);
  }

  // ===================== Admin check =====================
  Future<void> _loadIsAdmin() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      if (mounted) setState(() => _isAdmin = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      final role = (snap.data()?['role'] ?? 'user').toString();
      final ok = role == 'admin' || role == 'owner' || role == 'moderator';
      if (mounted) setState(() => _isAdmin = ok);
    } catch (e) {
      debugPrint("ERRO _loadIsAdmin: ${_errToText(e)}");
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  // ================= Confissão (local) =================
  Future<void> _carregarConfissoes() async {
    final prefs = await SharedPreferences.getInstance();
    final datasRaw = prefs.getStringList('dias_confessados');
    if (datasRaw != null) {
      setState(() => _diasConfessados = datasRaw.toSet());
    }
  }

  Future<void> _carregarHorasConfissao() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('horas_confissao_json');
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (k is String && v is String) {
            _horaConfissaoPorDia[k] = v;
          }
        });
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _persistirHorasConfissao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'horas_confissao_json',
      json.encode(_horaConfissaoPorDia),
    );
  }

  Future<TimeOfDay?> _pickHora(BuildContext context) async {
    return showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) {
        return Theme(
          data: _neutralTimePickerTheme(ctx),
          child: child!,
        );
      },
    );
  }

  Future<void> _alternarConfissaoComHora() async {
    if (_selectedDay == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = _selectedDay!;

    final selectedDate = DateTime(d.year, d.month, d.day);

    if (selectedDate.isAfter(today)) {
      _toast("Você não pode marcar confissão em data futura.");
      return;
    }

    if (selectedDate.isAfter(today)) {
      _toast("Você não pode marcar confissão em data futura.");
      return;
    }

    final chave = _formatarChave(d);
    final prefs = await SharedPreferences.getInstance();

    final jaMarcado = _diasConfessados.contains(chave);

    if (!jaMarcado) {
      final picked = await _pickHora(context);
      if (picked == null) return;

      if (isSameDay(d, now)) {
        final pickedDateTime = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        if (pickedDateTime.isAfter(now)) {
          _toast("Não dá pra marcar um horário no futuro.");
          return;
        }
      }

      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      _horaConfissaoPorDia[chave] = "$hh:$mm";
      await _persistirHorasConfissao();

      setState(() => _diasConfessados.add(chave));
    } else {
      setState(() => _diasConfessados.remove(chave));
      _horaConfissaoPorDia.remove(chave);
      await _persistirHorasConfissao();
    }

    await prefs.setStringList('dias_confessados', _diasConfessados.toList());
  }

  // ================= Eventos gerais (Firestore) =================
  Future<void> _carregarEventosDoMes(DateTime focus) async {
    final keyMonth = _formatarChaveMes(focus);
    if (_monthsLoaded.contains(keyMonth)) return;

    final year = focus.year;
    final month = focus.month;

    final first = DateTime(year, month, 1);
    final last = DateTime(year, month, DateUtils.getDaysInMonth(year, month));

    final firstKey = _formatarChave(first);
    final lastKey = _formatarChave(last);

    try {
      final qs = await FirebaseFirestore.instance
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: firstKey)
          .where('date', isLessThanOrEqualTo: lastKey)
          .orderBy('date')
          .orderBy('time')
          .get();

      for (final doc in qs.docs) {
        final ev = _AdminEvent.fromDoc(doc);

        if (ev.scope == 'admin' && !_isAdmin) continue;

        (_eventsByDay[ev.date] ??= []).add(ev);
      }

      _monthsLoaded.add(keyMonth);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("ERRO _carregarEventosDoMes: ${_errToText(e)}");
      _toast("Falhou ao carregar eventos: ${_errToText(e)}");
    }
  }

  Future<void> _createOrUpdateEvent({
    _AdminEvent? editing,
    required String title,
    required String date,
    required String time,
    required String label,
    required int colorValue,
    required String scope,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (editing == null) {
      await FirebaseFirestore.instance.collection('events').add({
        'title': title,
        'date': date,
        'time': time,
        'label': label,
        'color': colorValue,
        'scope': scope,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance.collection('events').doc(editing.id).update({
        'title': title,
        'date': date,
        'time': time,
        'label': label,
        'color': colorValue,
        'scope': scope,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    _monthsLoaded.clear();
    _eventsByDay.clear();
    await _carregarEventosDoMes(_focusedDay);
    if (mounted) setState(() {});
  }

  Future<void> _deleteEvent(_AdminEvent ev) async {
    await FirebaseFirestore.instance.collection('events').doc(ev.id).delete();
    _monthsLoaded.clear();
    _eventsByDay.clear();
    await _carregarEventosDoMes(_focusedDay);
    if (mounted) setState(() {});
  }

  // ================= Eventos (admin + confissão) =================
  List<Map<String, dynamic>> _getEventosDoDia(DateTime day) {
    final chave = _formatarChave(day);
    final List<Map<String, dynamic>> eventos = [];

    final list = _eventsByDay[chave] ?? const [];
    for (final e in list) {
      eventos.add({
        'id': e.id,
        'titulo': e.title,
        'hora': e.time,
        'tipo': e.label,
        'color': e.colorValue,
        'scope': e.scope,
        'isAdminEvent': true,
      });
    }

    if (_diasConfessados.contains(chave)) {
      final hora = _horaConfissaoPorDia[chave];
      eventos.add({
        "titulo": "Confissão Realizada",
        "hora": hora == null ? "Realizado" : hora,
        "tipo": "Confissão",
        "isAdminEvent": false,
        "color": 0xFF0F766E,
      });
    }

    return eventos;
  }

  // ================= Ações modernas =================
  Future<void> _refreshAll() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    await Future.wait([
      _loadIsAdmin(),
      _carregarConfissoes(),
      _carregarHorasConfissao(),
    ]);

    _monthsLoaded.clear();
    _eventsByDay.clear();
    await _carregarEventosDoMes(_focusedDay);

    if (mounted) setState(() => _refreshing = false);
  }

  void _toggleFormat() {
    setState(() {
      _format = _format == CalendarFormat.month ? CalendarFormat.twoWeeks : CalendarFormat.month;
    });
  }

  // ===================== RGB Picker =====================
  Future<Color?> _pickRgbColorDialog(Color initial) async {
    Color temp = initial;

    return showDialog<Color>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            "Escolher cor",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black.withOpacity(0.82),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          content: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 44,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: temp,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ColorPicker(
                    pickerColor: temp,
                    onColorChanged: (c) => setLocal(() => temp = c),
                    enableAlpha: false,
                    hexInputBar: true,
                    displayThumbColor: true,
                    portraitOnly: true,
                    pickerAreaHeightPercent: 0.68,
                    labelTypes: const [
                      ColorLabelType.hex,
                      ColorLabelType.rgb,
                    ],
                  ),
                ],
              );
            },
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black.withOpacity(0.65),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: vinhoIdentidade,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(ctx, temp),
              child: const Text(
                "Usar cor",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _rgbSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.65)),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, 255),
            min: 0,
            max: 255,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.75)),
          ),
        ),
      ],
    );
  }

  Widget _chipButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool center = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        alignment: center ? Alignment.center : Alignment.centerLeft, // 👈 aqui
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
          center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: vinhoIdentidade),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black.withOpacity(0.75),
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdminEventDialog({_AdminEvent? editing}) async {
    final initialDay =
    editing != null ? _parseDateKey(editing.date) : (_selectedDay ?? _focusedDay);

    final titleCtrl = TextEditingController(text: editing?.title ?? "");
    final labelCtrl = TextEditingController(text: editing?.label ?? "Evento");
    final timeCtrl = TextEditingController(text: editing?.time ?? "17:00");

    DateTime pickedDate = initialDay;
    int pickedColor = editing?.colorValue ?? vinhoIdentidade.value;
    String pickedScope = editing?.scope ?? "all";
    if (!_isAdmin) pickedScope = "all";

    Future<void> pickDate(
        BuildContext ctx,
        void Function(VoidCallback fn) setLocal,
        ) async {
      final d = await showDatePicker(
        context: ctx,
        initialDate: pickedDate,
        firstDate: DateTime(2024, 1, 1),
        lastDate: DateTime(2030, 12, 31),
        builder: (c, child) {
          return Theme(
            data: _neutralDatePickerTheme(c),
            child: child!,
          );
        },
      );

      if (d != null) {
        setLocal(() => pickedDate = d);
      }
    }

    Future<void> pickTime(
        BuildContext ctx,
        void Function(VoidCallback fn) setLocal,
        ) async {
      final current =
          _parseTime(timeCtrl.text) ?? const TimeOfDay(hour: 19, minute: 0);

      final t = await showTimePicker(
        context: ctx,
        initialTime: current,
        builder: (c, child) {
          return Theme(
            data: _neutralTimePickerTheme(c),
            child: child!,
          );
        },
      );

      if (t != null) {
        final hh = t.hour.toString().padLeft(2, '0');
        final mm = t.minute.toString().padLeft(2, '0');
        setLocal(() => timeCtrl.text = "$hh:$mm");
      }
    }

    List<int> palette() => _currentPalette();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Widget field({
              required TextEditingController controller,
              required String label,
              String? hint,
            }) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: TextField(
                  controller: controller,
                  scrollPadding: const EdgeInsets.only(bottom: 120),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    labelText: label,
                    hintText: hint,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
                ),
              );
            }

            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: _glassSheet(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // handle
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // header
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                editing == null ? "Novo evento" : "Editar evento",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: -0.2,
                                  color: Colors.black.withOpacity(0.82),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.black.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        field(
                          controller: titleCtrl,
                          label: "Título",
                          hint: "Ex: Reunião de Jovens",
                        ),
                        const SizedBox(height: 10),
                        field(
                          controller: labelCtrl,
                          label: "Legenda / Tipo",
                          hint: "Ex: Evento",
                        ),

                        const SizedBox(height: 12),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _chipButton(
                                  icon: Icons.date_range_rounded,
                                  label: _formatarChave(pickedDate),
                                  onTap: () => pickDate(ctx, setLocal),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _chipButton(
                                  icon: Icons.access_time_rounded,
                                  label: _formatHHmm(timeCtrl.text),
                                  center: true,
                                  onTap: () => pickTime(ctx, setLocal),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // cor
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.black.withOpacity(0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.palette_rounded,
                                      size: 18, color: vinhoIdentidade),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Cor do evento",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black.withOpacity(0.70),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Color(pickedColor),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black.withOpacity(0.18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final c in palette())
                                    InkWell(
                                      onTap: () async {
                                        await _rememberColor(c);
                                        setLocal(() => pickedColor = c);
                                      },
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(c),
                                          border: Border.all(
                                            color: pickedColor == c
                                                ? Colors.black.withOpacity(0.70)
                                                : Colors.black.withOpacity(0.10),
                                            width: pickedColor == c ? 2.2 : 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  InkWell(
                                    onTap: () async {
                                      final chosen =
                                      await _pickRgbColorDialog(Color(pickedColor));
                                      if (chosen != null) {
                                        await _rememberColor(chosen.value);
                                        setLocal(() => pickedColor = chosen.value);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                            color: Colors.black.withOpacity(0.12)),
                                        color: Colors.black.withOpacity(0.02),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.tune_rounded, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            "RGB",
                                            style: TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        if (_isAdmin) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.black.withOpacity(0.08)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _scopeTag(
                                    label: "TODOS",
                                    icon: Icons.public_rounded,
                                    selected: pickedScope == "all",
                                    onTap: () => setLocal(() => pickedScope = "all"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _scopeTag(
                                    label: "ADMIN",
                                    icon: Icons.lock_rounded,
                                    selected: pickedScope == "admin",
                                    onTap: () => setLocal(() => pickedScope = "admin"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            if (editing != null) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: Colors.red.withOpacity(0.30)),
                                    foregroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final ok = await _confirmDanger(
                                      context,
                                      title: "Remover evento?",
                                      message:
                                      "Isso vai remover o evento para todos os usuários",
                                      confirmText: "REMOVER",
                                    );
                                    if (ok == true) {
                                      try {
                                        await _deleteEvent(editing);
                                        _toast("Evento removido");
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      } catch (e) {
                                        _toast("Falhou ao remover: ${_errToText(e)}");
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                                  label: const Text(
                                    "REMOVER",
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  foregroundColor: Colors.black.withOpacity(0.70),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(color: Colors.black.withOpacity(0.10)),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  "CANCELAR",
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: vinhoIdentidade,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  final title = titleCtrl.text.trim();
                                  final label = labelCtrl.text.trim();
                                  final time = timeCtrl.text.trim();

                                  if (title.isEmpty) {
                                    _toast("Informe um título");
                                    return;
                                  }
                                  if (_parseTime(time) == null) {
                                    _toast("Hora inválida. Use HH:mm");
                                    return;
                                  }

                                  final dateKey = _formatarChave(pickedDate);

                                  try {
                                    await _createOrUpdateEvent(
                                      editing: editing,
                                      title: title,
                                      date: dateKey,
                                      time: time,
                                      label: label.isEmpty ? "Evento" : label,
                                      colorValue: pickedColor,
                                      scope: pickedScope,
                                    );

                                    _toast(editing == null
                                        ? "Evento salvo"
                                        : "Evento atualizado");

                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    _toast("Falhou ao salvar: ${_errToText(e)}");
                                  }
                                },
                                child: const Text(
                                  "SALVAR",
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  DateTime _parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  String _formatHHmm(String input) {
    final clean = input.replaceAll(' ', '');
    final parts = clean.split(':');
    if (parts.length != 2) return clean;

    final hh = parts[0].trim().padLeft(2, '0');
    final mm = parts[1].trim().padLeft(2, '0');
    return "$hh:$mm";
  }

  TimeOfDay? _parseTime(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay ?? DateTime.now();
    final chaveSelecionada = _formatarChave(selected);
    final bool isConfessado = _diasConfessados.contains(chaveSelecionada);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final selectedDay = _selectedDay ?? _focusedDay;
    final selectedDateOnly = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

    final bool isFutureDay = selectedDateOnly.isAfter(today);


    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: paper,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Calendário",
              style: TextStyle(
                color: vinhoProfundo,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _fmtDataCurta(selected),
              style: TextStyle(
                color: Colors.black.withOpacity(0.55),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: "Adicionar evento",
              onPressed: () => _openAdminEventDialog(),
              icon: Icon(Icons.add_circle_rounded, color: vinhoIdentidade),
            ),
          IconButton(
            tooltip: "Alternar mês/2 semanas",
            onPressed: _toggleFormat,
            icon: Icon(
              _format == CalendarFormat.month ? Icons.view_week_rounded : Icons.calendar_month_rounded,
              color: vinhoIdentidade,
            ),
          ),
          IconButton(
            tooltip: "Atualizar",
            onPressed: _refreshAll,
            icon: Icon(
              _refreshing ? Icons.sync_rounded : Icons.refresh_rounded,
              color: vinhoIdentidade,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: vinhoIdentidade,
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 10, bottom: 40),
          child: Column(
            children: [
              // ===== CALENDÁRIO =====
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBase,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                  boxShadow: [_softShadow],
                ),
                child: TableCalendar(
                  locale: 'pt_BR',
                  firstDay: DateTime(2024, 1, 1),
                  lastDay: DateTime(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _format,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) async {
                    setState(() => _focusedDay = focusedDay);
                    await _carregarEventosDoMes(focusedDay);
                  },
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: -0.2,
                      color: vinhoProfundo,
                    ),
                    leftChevronIcon: const Icon(Icons.chevron_left, color: vinhoIdentidade),
                    rightChevronIcon: const Icon(Icons.chevron_right, color: vinhoIdentidade),
                    headerPadding: const EdgeInsets.symmetric(vertical: 14),
                    titleTextFormatter: (date, locale) => _fmtMesAno(date),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.45),
                      fontSize: 11.5,
                    ),
                    weekendStyle: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.45),
                      fontSize: 11.5,
                    ),
                  ),
                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                    isTodayHighlighted: false,
                  ),
                  eventLoader: (day) => _getEventosDoDia(day),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();

                      int? colorValue;
                      for (final e in events) {
                        if (e is Map && e['isAdminEvent'] == true && e['color'] is int) {
                          colorValue = e['color'] as int;
                          break;
                        }
                      }

                      return Positioned(
                        bottom: 6,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Color(colorValue ?? vinhoIdentidade.value).withOpacity(0.85),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ===== CONFISSÃO (local) =====
              // ===== CONFISSÃO (local) =====
              if (!isFutureDay)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PremiumButton(
                    active: isConfessado,
                    onTap: _alternarConfissaoComHora,
                    label: isConfessado
                        ? "Confissão Registrada"
                        : "Marcar Confissão (anônimo)",
                    icon: isConfessado
                        ? Icons.check_circle_rounded
                        : Icons.lock_rounded,
                  ),
                ),



              const SizedBox(height: 16),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.list_alt_rounded, size: 20, color: Colors.black.withOpacity(0.35)),
                    const SizedBox(width: 8),
                    Text(
                      "Compromissos do Dia",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black.withOpacity(0.82),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              _buildListaCompromissos(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaCompromissos() {
    final DateTime day = _selectedDay ?? _focusedDay;
    final eventos = _getEventosDoDia(day);

    if (eventos.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, color: Colors.black.withOpacity(0.25), size: 28),
            const SizedBox(height: 10),
            Text(
              "Nada por aqui",
              style: TextStyle(
                color: Colors.black.withOpacity(0.70),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "A administração adiciona os compromissos",
              style: TextStyle(
                color: Colors.black.withOpacity(0.45),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: eventos.length,
      itemBuilder: (context, index) {
        final ev = eventos[index];

        final bool isAdminEvent = ev['isAdminEvent'] == true;

        final String tipo = (ev['tipo'] ?? '').toString();
        final bool isConfissao = tipo == "Confissão";

        // cor do card (admin vem do firestore; confissão você já força verde no map)
        final int colorValue = (ev['color'] is int) ? ev['color'] as int : vinhoIdentidade.value;

        final bool useGradient = isAdminEvent || isConfissao;

        final bool onDark = ThemeData.estimateBrightnessForColor(Color(colorValue)) == Brightness.dark;

        final titleColor = onDark ? Colors.white : Colors.black.withOpacity(0.85);
        final subColor = onDark ? Colors.white.withOpacity(0.78) : Colors.black.withOpacity(0.55);
        final trailColor = onDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.18);

        final horaRaw = (ev['hora'] ?? "—").toString();
        final horaOk = horaRaw.contains(':') ? _formatHHmm(horaRaw) : _normalizeSpacing(horaRaw);

        final String scope = (ev['scope'] ?? 'all').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: useGradient ? _safeGradientFromInt(colorValue) : null,
                  color: useGradient ? null : cardBase,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: useGradient ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),

                  leading: _eventLeading(ev, onDark: onDark),

                  title: Text(
                    _normalizeSpacing((ev['titulo'] ?? "").toString()),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: titleColor,
                    ),
                  ),
                  subtitle: Text(
                    "$horaOk  ${_normalizeSpacing((ev['tipo'] ?? "").toString())}",
                    style: TextStyle(
                      color: subColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isAdmin && isAdminEvent) ...[
                        _scopeBadge(scope, onDark: onDark),
                        const SizedBox(width: 8),
                      ],
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: trailColor),
                    ],
                  ),
                  onTap: () => _openEventActions(ev),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _eventLeading(Map<String, dynamic> ev, {bool onDark = false}) {
    final tipo = (ev['tipo'] ?? "").toString();

    final bool isConfissao = tipo == "Confissão";
    final bool isPreceito = tipo == "Preceito";

    final IconData icon = isConfissao
        ? Icons.verified_rounded
        : (isPreceito ? Icons.star_rounded : Icons.event_rounded);

    if (onDark) {
      return Icon(icon, color: Colors.white, size: 22);
    }

    final Color accent = isConfissao
        ? const Color(0xFF0F766E)
        : (isPreceito ? const Color(0xFFC62828) : vinhoIdentidade);

    return Icon(icon, color: accent, size: 22);
  }
}

// ===================== Model =====================
class _AdminEvent {
  final String id;
  final String title;
  final String date; // YYYY-MM-DD
  final String time; // HH:mm
  final String label;
  final int colorValue;
  final String scope;

  const _AdminEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.label,
    required this.colorValue,
    required this.scope,
  });

  static _AdminEvent fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _AdminEvent(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      date: (data['date'] ?? '').toString(),
      time: (data['time'] ?? '').toString(),
      label: (data['label'] ?? 'Evento').toString(),
      colorValue: (data['color'] is int) ? data['color'] as int : const Color(0xFF6A0F0F).value,
      scope: (data['scope'] ?? 'all').toString(),
    );
  }
}

// ===================== CTA premium do app =====================
class _PremiumButton extends StatelessWidget {
  const _PremiumButton({
    required this.active,
    required this.onTap,
    required this.label,
    required this.icon,
  });

  final bool active;
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    final Color bg = active ? const Color(0xFF0F766E) : Colors.white;
    final Color fg = active ? Colors.white : vinhoIdentidade;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? Colors.transparent : vinhoIdentidade.withOpacity(0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: fg,
                      letterSpacing: -0.1,
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
