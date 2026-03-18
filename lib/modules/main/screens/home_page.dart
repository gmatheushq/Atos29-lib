import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'community_wall_editor_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:palette_generator/palette_generator.dart';

import 'jornada_page.dart';
import 'editar_perfil_page.dart';

import 'package:atos29/modules/admin/admin_notifications_page.dart';

class HomePage extends StatefulWidget {
  final String nickname;
  const HomePage({super.key, required this.nickname});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== Paleta premium (vinho) + base clara =====
  static const Color vinhoProfundo = Color(0xFF3A0808);
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color vinhoDestaque = Color(0xFF8E2A2A);

  static const Color paper = Color(0xFFFBFAF8);

  // ===== VERSÍCULO DO DIA =====
  bool _versiculoLoading = true;
  String _versiculoTexto = "";
  String _versiculoRef = "";
  String _versiculoErro = "";
  DateTime? _versiculoFetchedAt;

  // ✅ fonte do versículo do dia (HTML)
  static const String _versiculoDoDiaUrl = 'https://www.bibliaon.com/versiculo_do_dia/';

  // ===== NOVO: cores vindas da CAPA =====
  Color? _coverPrimary;
  Color? _coverSecondary;
  String? _lastCoverUrl;
  bool _loadingCoverPalette = false;

  TextStyle get _hTitle => const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
    color: vinhoProfundo,
  );

  TextStyle get _subtitle => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: Colors.black.withOpacity(0.55),
  );

  @override
  void initState() {
    super.initState();
    _buscarVersiculoDoDia();
  }

  // ===== Helpers de cor (para ficar bonito/legível em qualquer capa) =====
  bool _isDark(Color c) => c.computeLuminance() < 0.42;

  Color _mix(Color a, Color b, double t) {
    return Color.lerp(a, b, t) ?? a;
  }

  Color _ensureReadableOnCard(Color base) {
    final lum = base.computeLuminance();
    if (lum > 0.85) return _mix(base, Colors.black, 0.25);
    if (lum < 0.10) return _mix(base, Colors.white, 0.25);
    return base;
  }

  Color _fallbackPrimary() => vinhoIdentidade;
  Color _fallbackSecondary() => vinhoDestaque;

  Future<void> _extractCoverPalette(String url) async {
    if (_loadingCoverPalette) return;
    _loadingCoverPalette = true;

    try {
      final provider = NetworkImage(url);

      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        maximumColorCount: 18,
        size: const Size(220, 120),
        timeout: const Duration(seconds: 6),
      );

      Color? primary =
          palette.dominantColor?.color ?? palette.vibrantColor?.color ?? palette.mutedColor?.color;

      Color? secondary = palette.darkVibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.darkMutedColor?.color ??
          palette.lightMutedColor?.color ??
          palette.vibrantColor?.color ??
          palette.mutedColor?.color;

      if (primary == null && secondary == null) {

        if (mounted) {
          setState(() {
            _coverPrimary = null;
            _coverSecondary = null;
          });
        }
        return;
      }

      primary = _ensureReadableOnCard(primary ?? secondary!);
      secondary = _ensureReadableOnCard(secondary ?? primary);

      // Se primary e secondary ficaram iguais demais, dá um "empurrão"
      if ((primary.value ^ secondary.value).abs() < 0x000F0F0F) {
        secondary = _mix(secondary, _isDark(primary) ? Colors.white : Colors.black, 0.18);
      }

      if (mounted) {
        setState(() {
          _coverPrimary = primary;
          _coverSecondary = secondary;
        });
      }
    } catch (e) {
      debugPrint("PALETTE ERROR: $e");
      if (mounted) {
        setState(() {
          _coverPrimary = null;
          _coverSecondary = null;
        });
      }
    } finally {
      _loadingCoverPalette = false;
    }
  }

  // ===================== VERSÍCULO DO DIA (parse HTML) =====================
  Future<void> _buscarVersiculoDoDia() async {
    setState(() {
      _versiculoLoading = true;
      _versiculoErro = "";
    });

    try {
      final resp = await http.get(Uri.parse(_versiculoDoDiaUrl)).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        throw Exception("Status ${resp.statusCode}");
      }

      final html = utf8.decode(resp.bodyBytes);

      // remove scripts/styles (reduz ruído)
      String plain = html
          .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '\n');

      // troca tags por quebras de linha
      plain = plain.replaceAll(RegExp(r'<[^>]+>'), '\n');

      // normaliza espaços
      plain = plain
          .replaceAll('\r', '')
          .replaceAll(RegExp(r'\n{2,}'), '\n')
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .join('\n');

      final lines = plain.split('\n');

      int idx = lines.indexWhere((l) => l.toLowerCase() == 'versiculo de hoje');
      if (idx == -1) {
        idx = lines.indexWhere((l) => l.toLowerCase().contains('versiculo de hoje'));
      }
      if (idx == -1) {
        throw Exception("Não foi possível encontrar o 'Versículo de Hoje'");
      }

      String? verseLine;
      String? refLine;

      // varre as próximas linhas pegando: texto, referência
      for (int i = idx + 1; i < (idx + 12).clamp(0, lines.length); i++) {
        final l = lines[i];

        // ignora data tipo: "quinta, 29 de janeiro de 2026"
        final isDate = (l.contains(',') && RegExp(r'\b20\d{2}\b').hasMatch(l)) ||
            RegExp(r'^\s*(segunda|terça|terca|quarta|quinta|sexta|sábado|sabado|domingo)\b',
                caseSensitive: false)
                .hasMatch(l) ||
            RegExp(
                r'\b(janeiro|fevereiro|março|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)\b',
                caseSensitive: false)
                .hasMatch(l);

        if (isDate) continue;

        final isRef = RegExp(r'.+\s+\d+\:\d+').hasMatch(l);
        if (verseLine != null && refLine == null && isRef) {
          refLine = l;
          break;
        }

        if (verseLine == null && l.length >= 8 && !l.toLowerCase().contains('gostou')) {
          verseLine = l;
        }
      }

      if (verseLine == null || refLine == null) {
        throw Exception("Não consegui extrair texto e referência do versículo");
      }

      if (!mounted) return;
      setState(() {
        _versiculoTexto = verseLine!;
        _versiculoRef = refLine!;
        _versiculoFetchedAt = DateTime.now();
        _versiculoLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _versiculoErro = "Não foi possível carregar o versículo do dia";
        _versiculoLoading = false;
        _versiculoTexto = "";
        _versiculoRef = "";
      });
    }
  }

  Widget _versiculoDoDiaCard({required Color primary, required Color secondary}) {
    final shadow = BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 22,
      offset: const Offset(0, 10),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [shadow],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: primary.withOpacity(0.90)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Versículo do dia",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.78),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _buscarVersiculoDoDia,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.refresh_rounded, color: Colors.black.withOpacity(0.45), size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_versiculoLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: primary.withOpacity(0.85),
                  ),
                ),
              )
            else if (_versiculoErro.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _versiculoErro,
                  style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w700),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _versiculoTexto,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                      color: Colors.black.withOpacity(0.62),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _versiculoRef,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ================== MURAL (Firestore) ==================

  IconData _iconFromName(String name) {
    const map = <String, IconData>{
      'event_available': Icons.event_available,
      'auto_awesome': Icons.auto_awesome,
      'campaign': Icons.campaign,
      'info': Icons.info,
      'groups': Icons.groups,
      'church': Icons.church,
      'warning': Icons.warning_amber_rounded,
      'favorite': Icons.favorite_rounded,
    };
    return map[name] ?? Icons.campaign;
  }

  Future<void> _setMuralGlobalVisible(bool value) async {
    await _firestore.collection('settings').doc('community_wall').set(
      {
        'visibleForUsers': value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _toggleItemVisible(String docId, bool value) async {
    await _firestore.collection('community_wall').doc(docId).update({
      'visible': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteItem(String docId) async {
    await _firestore.collection('community_wall').doc(docId).delete();
  }

  Future<void> _openCreateOrEditWallItem({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityWallEditorPage(doc: doc),
      ),
    );
  }



  Widget _communityWallSection({required bool isAdmin}) {
    final settingsRef = _firestore.collection('settings').doc('community_wall');

    return StreamBuilder<DocumentSnapshot>(
      stream: settingsRef.snapshots(),
      builder: (context, snapSettings) {
        final settings = snapSettings.data?.data() as Map<String, dynamic>?;
        final muralOn = (settings?['visibleForUsers'] ?? true) == true;

        final query = _firestore
            .collection('community_wall')
            .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        )
            .orderBy('createdAt', descending: true);


        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("Mural da Comunidade", style: _hTitle.copyWith(fontSize: 18)),
                const Spacer(),
                if (isAdmin) ...[
                  IconButton(
                    tooltip: muralOn ? "Ocultar mural para usuários" : "Mostrar mural para usuários",
                    onPressed: () => _setMuralGlobalVisible(!muralOn),
                    icon: Icon(
                      muralOn ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: muralOn ? vinhoIdentidade.withOpacity(0.92) : Colors.black.withOpacity(0.35),
                    ),
                  ),
                  IconButton(
                    tooltip: "Adicionar",
                    onPressed: () => _openCreateOrEditWallItem(),
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: vinhoIdentidade.withOpacity(0.9),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (!isAdmin && !muralOn)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text("Sem avisos no momento", style: _subtitle),
              ),
            if (muralOn || isAdmin)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(

              stream: isAdmin ? query.snapshots() : query.where('visible', isEqualTo: true).snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    debugPrint("MURAL ERROR: ${snap.error}");
                    return const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text("Erro ao carregar mural"),
                    );
                  }

                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text("Sem avisos no momento", style: _subtitle),
                    );
                  }

                  return Column(
                    children: docs.map((DocumentSnapshot docSnap) {
                      final d = docSnap as DocumentSnapshot<Map<String, dynamic>>;
                      final m = d.data() ?? {};

                      final title = (m['title'] ?? '').toString();
                      final subtitle = (m['subtitle'] ?? '').toString();
                      final iconName = (m['icon'] ?? 'campaign').toString();
                      final color = Color((m['color'] ?? Colors.orange.value) as int);
                      final visible = (m['visible'] ?? true) == true;

                      return Stack(
                        children: [
                          _NoticeCard(
                            titulo: title.isEmpty ? "(sem título)" : title,
                            subtitulo: subtitle,
                            icone: _iconFromName(iconName),
                            cor: color,
                            showChevron: !isAdmin,
                          ),
                          if (isAdmin)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: visible ? "Ocultar este item" : "Mostrar este item",
                                    onPressed: () => _toggleItemVisible(d.id, !visible),
                                    icon: Icon(
                                      visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                      color: visible
                                          ? vinhoIdentidade.withOpacity(0.95)
                                          : Colors.black.withOpacity(0.45),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: "Ações",
                                    onSelected: (v) async {
                                      if (v == "edit") {
                                        await _openCreateOrEditWallItem(doc: d);
                                      } else if (v == "delete") {
                                        await _deleteItem(d.id);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: "edit", child: Text("Editar")),
                                      PopupMenuItem(value: "delete", child: Text("Excluir")),
                                    ],
                                    icon: Icon(Icons.more_vert_rounded, color: Colors.black.withOpacity(0.55)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Usuário não autenticado")),
      );
    }

    return Scaffold(
      backgroundColor: paper,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar perfil"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;

          final String nome = (userData?['nome'] ?? "").toString().trim().isNotEmpty
              ? (userData?['nome']).toString().trim()
              : "Membro";

          final String nickname = (userData?['nickname'] ?? widget.nickname).toString().trim();
          final String bio = (userData?['bio'] ?? "Bem-vindo à minha jornada de fé!").toString();

          final String? photoUrl = (userData?['photoUrl'] as String?)?.trim();
          final String? coverUrl = (userData?['coverUrl'] as String?)?.trim();

          final String username = "@$nickname";

          final role = (userData?['role'] ?? 'user').toString();
          final isAdmin = role == 'admin' || role == 'moderator' || role == 'owner';

          // ===== NOVO: dispara extração de cor quando a capa mudar =====
          final safeCover = (coverUrl != null && coverUrl.isNotEmpty) ? coverUrl : null;
          if (safeCover != null && safeCover != _lastCoverUrl) {
            _lastCoverUrl = safeCover;
            // evita setState durante build: agenda para depois do frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _extractCoverPalette(safeCover);
            });
          } else if (safeCover == null && _lastCoverUrl != null) {
            _lastCoverUrl = null;
            _coverPrimary = null;
            _coverSecondary = null;
          }

          final Color journeyPrimary = _coverPrimary ?? _fallbackPrimary();
          final Color journeySecondary = _coverSecondary ?? _fallbackSecondary();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ===== CAPA =====
              SliverToBoxAdapter(
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: vinhoProfundo,
                    image: (coverUrl != null && coverUrl.isNotEmpty)
                        ? DecorationImage(
                      image: NetworkImage(coverUrl),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                ),
              ),

              // ===== PERFIL =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileAvatar(photoUrl: photoUrl),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    nome,
                                    style: _hTitle.copyWith(fontSize: 20),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: "Editar perfil",
                                  icon: Icon(
                                    Icons.manage_accounts_rounded,
                                    color: vinhoProfundo.withOpacity(0.85),
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditarPerfilPage(
                                        nomeAtual: (userData?['nome'] ?? nickname).toString(),
                                        nicknameAtual: nickname,
                                        bioAtual: bio,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(username, style: _subtitle),
                            const SizedBox(height: 6),
                            Text(
                              bio,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.85,
                                color: Colors.black.withOpacity(0.62),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== CONTEÚDO =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAdmin) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
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
                              Expanded(
                                child: Text(
                                  "Painel de Notificações • Admin",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black.withOpacity(0.78),
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AdminNotificationsPage()),
                                ),
                                child: const Text('Abrir'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      _PremiumJourneyCard(
                        primary: journeyPrimary,
                        secondary: journeySecondary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const JornadaPage()),
                        ),
                      ),

                      const SizedBox(height: 14),

                      _versiculoDoDiaCard(primary: journeyPrimary, secondary: journeySecondary),

                      const SizedBox(height: 22),

                      _communityWallSection(isAdmin: isAdmin),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ========================= AVATAR + CARDS =========================

// ===== Avatar =====
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl});
  final String? photoUrl;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: vinhoIdentidade.withOpacity(0.10),
        backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
        child: !hasPhoto ? const Icon(Icons.person, size: 34, color: vinhoIdentidade) : null,
      ),
    );
  }
}

class _PremiumJourneyCard extends StatefulWidget {
  const _PremiumJourneyCard({
    required this.onTap,
    required this.primary,
    required this.secondary,
  });

  final VoidCallback onTap;
  final Color primary;
  final Color secondary;

  @override
  State<_PremiumJourneyCard> createState() => _PremiumJourneyCardState();
}

class _PremiumJourneyCardState extends State<_PremiumJourneyCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final p1 = Color.lerp(Colors.black, widget.primary, 0.82) ?? widget.primary;
    final p2 = Color.lerp(Colors.black, widget.secondary, 0.68) ?? widget.secondary;

    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: widget.primary.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: -5,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    p1.withOpacity(0.94),
                    p2.withOpacity(0.88),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Círculos decorativos sutis
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: -30,
                    bottom: -30,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.04),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Conteúdo principal
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ícone + título
                        Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                "Minha Jornada",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 23,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Subtítulo
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up_rounded,
                              color: Colors.white.withOpacity(0.85),
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Continue sua caminhada de fé",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Barra de progresso simples
                        Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              height: 5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.85),
                                    Colors.white.withOpacity(0.75),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Texto motivacional
                        Text(
                          "Toque para explorar",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 0.2,
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
      ),
    );
  }
}

// ===== Avisos =====
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.cor,
    this.showChevron = true,
  });

  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final shadow = BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 18,
      offset: const Offset(0, 8),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [shadow],
      ),
      child: Row(
        children: [
          Icon(icone, color: cor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black.withOpacity(0.82),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (showChevron)
            Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35))
          else
            const SizedBox(width: 18),
        ],
      ),
    );
  }
}
