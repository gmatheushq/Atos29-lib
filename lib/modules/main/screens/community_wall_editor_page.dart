import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class CommunityWallEditorPage extends StatefulWidget {
  const CommunityWallEditorPage({
    super.key,
    this.doc,
  });

  final DocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<CommunityWallEditorPage> createState() => _CommunityWallEditorPageState();
}

class _CommunityWallEditorPageState extends State<CommunityWallEditorPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== Paleta premium (vinho) + base clara =====
  static const Color vinhoProfundo = Color(0xFF3A0808);
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color vinhoDestaque = Color(0xFF8E2A2A);
  static const Color paper = Color(0xFFFBFAF8);

  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;

  String _topicKey = "campaign";
  int _colorValue = Colors.orange.value;

  bool _visible = true;
  bool _saving = false;
  bool get _isEditing => widget.doc != null;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _topicsSub;
  final List<_Topic> _topics = [];
  bool _topicsLoadedOnce = false;
  bool _canManageTopics = true; // se PERMISSION_DENIED, vira false

  static const List<String> _iconPool = [
    'campaign',
    'event_available',
    'auto_awesome',
    'info',
    'groups',
    'church',
    'warning',
    'favorite',
    'celebration',
    'local_fire_department',
    'volunteer_activism',
    'handshake',
    'school',
    'menu_book',
    'music_note',
    'mic',
    'live_tv',
    'restaurant',
    'sports_soccer',
    'sports_basketball',
    'fitness_center',
    'medical_services',
    'flag',
    'place',
    'map',
    'photo_camera',
    'videocam',
    'attach_money',
    'work',
    'build',
    'lightbulb',
    'emoji_people',
    'park',
    'pets',
    'child_friendly',
    'access_time',
    'notifications',
  ];

  // defaults (sempre disponíveis)
  static const List<_Topic> _defaultTopics = [
    _Topic(key: 'campaign', label: 'Campanha', iconName: 'campaign', isDefault: true),
    _Topic(key: 'event', label: 'Evento', iconName: 'event_available', isDefault: true),
    _Topic(key: 'highlight', label: 'Destaque', iconName: 'auto_awesome', isDefault: true),
    _Topic(key: 'info', label: 'Info', iconName: 'info', isDefault: true),
    _Topic(key: 'warning', label: 'Atenção', iconName: 'warning', isDefault: true),
    _Topic(key: 'community', label: 'Comunidade', iconName: 'groups', isDefault: true),
    _Topic(key: 'church', label: 'Igreja', iconName: 'church', isDefault: true),
    _Topic(key: 'love', label: 'Coração', iconName: 'favorite', isDefault: true),
  ];

  static const List<int> _quickColors = [
    0xFF6A0F0F, // vinho identidade
    0xFF8E2A2A, // vinho destaque
    0xFFFF9800, // laranja
    0xFF9C27B0, // roxo
    0xFF4CAF50, // verde
    0xFFF44336, // vermelho
    0xFF2196F3, // azul
    0xFF009688, // teal
    0xFF1F1F1F, // quase preto
    0xFF607D8B, // blue grey
  ];

  @override
  void initState() {
    super.initState();

    final data = widget.doc?.data();

    _titleCtrl = TextEditingController(text: (data?['title'] ?? '').toString());
    _subtitleCtrl = TextEditingController(text: (data?['subtitle'] ?? '').toString());

    // compat: se seu doc antigo usa "icon", aproveita
    _topicKey = (data?['topicKey'] ?? data?['icon'] ?? 'campaign').toString();
    _colorValue = (data?['color'] ?? Colors.orange.value) as int;
    _visible = (data?['visible'] ?? true) == true;
    _topics
      ..clear()
      ..addAll(_defaultTopics);
    _topicsLoadedOnce = true;

    _listenTopics();
  }

  void _listenTopics() {
    _topicsSub?.cancel();

    _topicsSub = _firestore
        .collection('community_wall_topics')
        .orderBy('label')
        .snapshots()
        .listen((snap) {
      _canManageTopics = true;

      final custom = snap.docs.map((d) {
        final m = d.data();
        final key = (m['key'] ?? d.id).toString().trim();
        final label = (m['label'] ?? key).toString().trim();
        final iconName = (m['iconName'] ?? 'campaign').toString().trim();
        final safeKey = key.isEmpty ? 'topico' : key;

        return _Topic(
          key: safeKey,
          label: label.isEmpty ? safeKey : label,
          iconName: iconName.isEmpty ? 'campaign' : iconName,
          isDefault: false,
        );
      }).toList();

      final merged = <String, _Topic>{};
      for (final t in _defaultTopics) merged[t.key] = t;
      for (final t in custom) merged[t.key] = t;

      final list = merged.values.toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

      final hasCurrent = list.any((t) => t.key == _topicKey);
      if (!hasCurrent && list.isNotEmpty) {
        _topicKey = list.first.key;
      }

      if (!mounted) return;
      setState(() {
        _topics
          ..clear()
          ..addAll(list);
        _topicsLoadedOnce = true;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _canManageTopics = false;
        _topicsLoadedOnce = true;
        _topics
          ..clear()
          ..addAll(_defaultTopics);

        if (!_topics.any((t) => t.key == _topicKey)) {
          _topicKey = _topics.first.key;
        }
      });
    });
  }

  @override
  void dispose() {
    _topicsSub?.cancel();
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  // -------- Icon mapping --------
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

      'celebration': Icons.celebration,
      'local_fire_department': Icons.local_fire_department,
      'volunteer_activism': Icons.volunteer_activism,
      'handshake': Icons.handshake,
      'school': Icons.school,
      'menu_book': Icons.menu_book,
      'music_note': Icons.music_note,
      'mic': Icons.mic,
      'live_tv': Icons.live_tv,
      'restaurant': Icons.restaurant,
      'sports_soccer': Icons.sports_soccer,
      'sports_basketball': Icons.sports_basketball,
      'fitness_center': Icons.fitness_center,
      'medical_services': Icons.medical_services,
      'flag': Icons.flag,
      'place': Icons.place,
      'map': Icons.map,
      'photo_camera': Icons.photo_camera,
      'videocam': Icons.videocam,
      'attach_money': Icons.attach_money,
      'work': Icons.work,
      'build': Icons.build,
      'lightbulb': Icons.lightbulb,
      'emoji_people': Icons.emoji_people,
      'park': Icons.park,
      'pets': Icons.pets,
      'child_friendly': Icons.child_friendly,
      'access_time': Icons.access_time,
      'notifications': Icons.notifications,
    };
    return map[name] ?? Icons.campaign;
  }

  _Topic _currentTopic() {
    final found = _topics.where((t) => t.key == _topicKey);
    if (found.isNotEmpty) return found.first;
    return _topics.isNotEmpty ? _topics.first : _defaultTopics.first;
  }

  Widget _fieldContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------- SAVE ----------------
  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final subtitle = _subtitleCtrl.text.trim();

    if (title.isEmpty) {
      _showSnack("Informe um título");
      return;
    }

    setState(() => _saving = true);

    final topic = _currentTopic();

    final payload = <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'topicKey': _topicKey,
      'icon': topic.iconName, // compat
      'color': _colorValue,
      'visible': _visible,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.doc == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('community_wall').add(payload);
      } else {
        await _firestore.collection('community_wall').doc(widget.doc!.id).update(payload);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack("Erro ao publicar: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------- TOPIC PICKER (icons only) ----------------
  Future<void> _openTopicPickerSheet() async {
    if (!_topicsLoadedOnce) return;

    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Escolher ícone",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black.withOpacity(0.85),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _topics.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (ctx, i) {
                    final t = _topics[i];
                    final isSelected = t.key == _topicKey;

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, t.key),
                      child: Container(
                        decoration: BoxDecoration(
                          color: paper,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Colors.black.withOpacity(0.55)
                                : Colors.black.withOpacity(0.10),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _iconFromName(t.iconName),
                            color: isSelected
                                ? vinhoIdentidade
                                : Colors.black.withOpacity(0.55),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  "Toque no ícone para selecionar",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _topicKey = selected);
    }
  }


  // ---------------- CREATE TOPIC (name + icon grid) ----------------
  Future<void> _openCreateTopicDialog() async {
    if (!_canManageTopics) {
      _showSnack("Sem permissão para criar tópicos");
      return;
    }

    final nameCtrl = TextEditingController();
    String iconName = 'campaign';

    final createdKey = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text("Criar tipo de tópico"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nome do tópico",
                        hintText: "Ex: Oração, Aviso, Reunião...",
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Escolha um ícone",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black.withOpacity(0.70),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _iconPool.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (ctx, i) {
                        final name = _iconPool[i];
                        final isSelected = name == iconName;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setLocal(() => iconName = name),
                          child: Container(
                            decoration: BoxDecoration(
                              color: paper,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.10),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                _iconFromName(name),
                                color: isSelected ? vinhoIdentidade : Colors.black.withOpacity(0.55),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final label = nameCtrl.text.trim();
                    if (label.isEmpty) return;

                    final key = _slugify(label);

                    try {
                      final ref = _firestore.collection('community_wall_topics').doc(key);
                      await ref.set({
                        'key': key,
                        'label': label,
                        'iconName': iconName,
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx, key);
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text("Erro ao criar tópico: $e")),
                      );
                    }
                  },
                  child: const Text("Salvar"),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();

    if (createdKey != null && mounted) {
      setState(() => _topicKey = createdKey);
    }
  }

  static String _slugify(String input) {
    var s = input.toLowerCase().trim();
    s = s
        .replaceAll(RegExp(r'[áàâã]'), 'a')
        .replaceAll(RegExp(r'[éèê]'), 'e')
        .replaceAll(RegExp(r'[íìî]'), 'i')
        .replaceAll(RegExp(r'[óòôõ]'), 'o')
        .replaceAll(RegExp(r'[úùû]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c');
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    s = s.replaceAll(RegExp(r'^_|_$'), '');
    if (s.isEmpty) s = 'topico';
    return s;
  }

  // ===================== COLOR PICKER (do Calendário) =====================

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
                  // preview
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

  Future<void> _openColorPickerLikeCalendar() async {
    final chosen = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Cor do aviso",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black.withOpacity(0.85),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // preview
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(_colorValue),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withOpacity(0.10)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "#${Color(_colorValue).value.toRadixString(16).padLeft(8, '0').toUpperCase()}",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black.withOpacity(0.70),
                          fontFamily: 'monospace',
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // cores rápidas (bolinhas)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Cores rápidas",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.70),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final v in _quickColors)
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.pop(ctx, v),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(v),
                            border: Border.all(
                              color: _colorValue == v
                                  ? Colors.black.withOpacity(0.70)
                                  : Colors.black.withOpacity(0.10),
                              width: _colorValue == v ? 2.2 : 1,
                            ),
                          ),
                        ),
                      ),

                    // botão RGB (abre o mesmo dialog do calendário)
                    InkWell(
                      onTap: () async {
                        final c = await _pickRgbColorDialog(Color(_colorValue));
                        if (c != null && ctx.mounted) {
                          Navigator.pop(ctx, c.value);
                        }
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.black.withOpacity(0.12)),
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

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null && mounted) {
      setState(() => _colorValue = chosen);
    }
  }

  // ---------------- UI FIELDS ----------------

  Widget _topicFieldIconsOnly() {
    final t = _currentTopic();
    final iconData = _iconFromName(t.iconName);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openTopicPickerSheet,
      child: _fieldContainer(
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Icon(iconData, color: vinhoIdentidade),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Ícone do aviso",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withOpacity(0.70),
                ),
              ),
            ),
            Icon(Icons.grid_view_rounded, color: Colors.black.withOpacity(0.38)),
          ],
        ),
      ),
    );
  }

  Widget _colorFieldCalendarPicker() {
    final c = Color(_colorValue);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openColorPickerLikeCalendar,
      child: _fieldContainer(
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black.withOpacity(0.10)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Cor do ícone",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withOpacity(0.70),
                ),
              ),
            ),
            Icon(Icons.palette_outlined, color: Colors.black.withOpacity(0.38)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _currentTopic();
    final cor = Color(_colorValue);
    final iconData = _iconFromName(t.iconName);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewInsets = MediaQuery.of(context).viewInsets;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(14, 10, 14, viewInsets.bottom + 14),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ===== Header =====
                          Container(
                            padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  vinhoProfundo,
                                  vinhoIdentidade,
                                  vinhoDestaque.withOpacity(0.95),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(iconData, color: Colors.white.withOpacity(0.95), size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isEditing ? "Editar aviso" : "Novo aviso",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16.8,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Mural da Comunidade",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: "Fechar",
                                  onPressed: () => Navigator.pop(context, false),
                                  icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.92)),
                                ),
                              ],
                            ),
                          ),

                          // ===== Body =====
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Preview do card
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: paper,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(iconData, color: cor, size: 30),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _titleCtrl.text.trim().isEmpty ? "Título do aviso" : _titleCtrl.text.trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black.withOpacity(0.82),
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _subtitleCtrl.text.trim().isEmpty
                                                  ? "Subtítulo / descrição curta"
                                                  : _subtitleCtrl.text.trim(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.black.withOpacity(0.55),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        _visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                        color: Colors.black.withOpacity(0.35),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),

                                _fieldContainer(
                                  child: TextField(
                                    controller: _titleCtrl,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      labelText: "Título",
                                      border: InputBorder.none,
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black.withOpacity(0.55),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                _fieldContainer(
                                  child: TextField(
                                    controller: _subtitleCtrl,
                                    onChanged: (_) => setState(() {}),
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText: "Subtítulo",
                                      border: InputBorder.none,
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black.withOpacity(0.55),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                if (!_topicsLoadedOnce)
                                  const LinearProgressIndicator(minHeight: 2)
                                else
                                  _topicFieldIconsOnly(),

                                const SizedBox(height: 10),

                                _colorFieldCalendarPicker(),

                                const SizedBox(height: 10),

                                InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => setState(() => _visible = !_visible),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: paper,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                          color: _visible ? vinhoIdentidade.withOpacity(0.95) : Colors.black.withOpacity(0.45),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _visible ? "Começar visível" : "Começar oculto",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Colors.black.withOpacity(0.78),
                                            ),
                                          ),
                                        ),
                                        Icon(Icons.chevron_right_rounded, color: Colors.black.withOpacity(0.30)),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: _saving ? null : () => Navigator.pop(context, false),
                                        child: Text(
                                          "Cancelar",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black.withOpacity(0.55),
                                          ),
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
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          elevation: 0,
                                        ),
                                        onPressed: _saving ? null : _save,
                                        child: _saving
                                            ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                            : Text(_isEditing ? "Salvar" : "Publicar"),
                                      ),
                                    ),
                                  ],
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
          },
        ),
      ),
    );
  }
}

class _Topic {
  final String key;
  final String label;
  final String iconName;
  final bool isDefault;

  const _Topic({
    required this.key,
    required this.label,
    required this.iconName,
    required this.isDefault,
  });
}
