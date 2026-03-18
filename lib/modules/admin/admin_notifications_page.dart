import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  // ====== PALLETA ======
  static const Color kPrimary = Color(0xFF4E0405); // rgb(78, 4, 5)
  static const Color kBg = Colors.white;
  static const Color kText = Colors.black;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  String _topic = 'all'; // all | admins
  bool _sending = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _templatesCol = 'admin_notification_templates';

  String _search = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  // ===================== ENVIAR =====================
  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty) {
      _snack('Informe um título');
      return;
    }

    setState(() => _sending = true);

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('adminSendByTopic');

      await callable.call({
        'topic': _topic, // all | admins
        'title': title,
        'body': body,
        'payloadData': {'screen': 'home'},
      });

      if (!mounted) return;

      _snack('Notificação enviada');
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _snack('Erro: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      _snack('Erro: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ===================== TEMPLATES =====================
  void _loadTemplate({required String title, required String body}) {
    _titleCtrl.text = title;
    _bodyCtrl.text = body;
    _snack('Template carregado no formulário');
  }

  Future<void> _saveCurrentAsTemplate() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty) {
      _snack('Informe um título para salvar');
      return;
    }

    try {
      await _firestore.collection(_templatesCol).add({
        'title': title,
        'titleLower': title.toLowerCase(),
        'body': body,
        'pinned': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _snack('Template salvo');
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao salvar template: $e');
    }
  }

  Future<void> _togglePinned(String docId, bool currentPinned) async {
    try {
      await _firestore.collection(_templatesCol).doc(docId).update({
        'pinned': !currentPinned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao fixar/desafixar: $e');
    }
  }

  Future<void> _deleteTemplate(String docId) async {
    try {
      await _firestore.collection(_templatesCol).doc(docId).delete();
      if (!mounted) return;
      _snack('Template excluído');
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao excluir: $e');
    }
  }

  List<QueryDocumentSnapshot> _sortTemplates(List<QueryDocumentSnapshot> docs) {
    final q = _search.trim().toLowerCase();

    final filtered = docs.where((d) {
      final m = d.data() as Map<String, dynamic>;
      final title = (m['title'] ?? '').toString();
      if (q.isEmpty) return true;
      return title.toLowerCase().contains(q);
    }).toList();

    filtered.sort((a, b) {
      final ma = a.data() as Map<String, dynamic>;
      final mb = b.data() as Map<String, dynamic>;
      final pa = (ma['pinned'] ?? false) == true;
      final pb = (mb['pinned'] ?? false) == true;

      if (pa != pb) return pa ? -1 : 1;

      final ta = (ma['titleLower'] ??
          (ma['title'] ?? '').toString().toLowerCase())
          .toString();
      final tb = (mb['titleLower'] ??
          (mb['title'] ?? '').toString().toLowerCase())
          .toString();
      return ta.compareTo(tb);
    });

    return filtered;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    // Theme local (sem pastel)
    final theme = base.copyWith(
      scaffoldBackgroundColor: kBg,
      colorScheme: base.colorScheme.copyWith(
        primary: kPrimary,
        onPrimary: Colors.white,
        surface: kBg,
        onSurface: kText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kBg,
        foregroundColor: kText,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(color: Colors.black.withOpacity(0.12)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 2),
        ),
        labelStyle: const TextStyle(color: kText),
        prefixIconColor: kText,
      ),
      cardTheme: const CardThemeData(
        color: kBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: Color(0x1F000000)), // preto ~12%
        ),
      ),

      textTheme: base.textTheme.apply(
        bodyColor: kText,
        displayColor: kText,
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Painel de Notificações'),
          actions: [
            IconButton(
              tooltip: 'Salvar template do formulário',
              onPressed: _saveCurrentAsTemplate,
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ====== 1) ENVIAR (AGORA EM CIMA) ======
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _HeaderCard(
                        title: 'Criar notificação',
                        subtitle: 'Pushs enviados para o tipo de usuários selecionado',
                        trailing: TextButton.icon(
                          onPressed: () {
                            _titleCtrl.clear();
                            _bodyCtrl.clear();
                          },
                          label: const Text('Limpar'),
                          style: TextButton.styleFrom(foregroundColor: kPrimary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SendCard(
                        titleCtrl: _titleCtrl,
                        bodyCtrl: _bodyCtrl,
                        topic: _topic,
                        sending: _sending,
                        onTopicChanged: (v) => setState(() => _topic = v),
                        onSend: _send,
                        onSaveTemplate: _saveCurrentAsTemplate,
                      ),
                      const SizedBox(height: 18),
                      Divider(thickness: 1, height: 1),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),

              // ====== 2) TEMPLATES (AGORA EMBAIXO) ======
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _HeaderCard(
                        title: 'Templates',
                        subtitle: 'Toque em um template para preencher o formulário',
                        trailing: FilledButton.icon(
                          onPressed: _saveCurrentAsTemplate,
                          icon: const Icon(Icons.add),
                          label: const Text('Salvar atual'),
                          style: FilledButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Buscar por título',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection(_templatesCol).snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const SliverToBoxAdapter(
                        child: _EmptyState(
                          icon: Icons.error_outline,
                          title: 'Erro ao carregar templates',
                          subtitle: 'Tente novamente em instantes',
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }

                    final docs = _sortTemplates(
                      snap.data!.docs.cast<QueryDocumentSnapshot>(),
                    );

                    if (docs.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: _EmptyState(
                          icon: Icons.bookmarks_outlined,
                          title: 'Nenhum template salvo',
                          subtitle: 'Crie uma notificação acima e toque em “Salvar atual”',
                        ),
                      );
                    }

                    return SliverList.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final d = docs[i];
                        final m = d.data() as Map<String, dynamic>;
                        final title = (m['title'] ?? '').toString();
                        final body = (m['body'] ?? '').toString();
                        final pinned = (m['pinned'] ?? false) == true;

                        return _TemplateTile(
                          title: title.isEmpty ? '(sem título)' : title,
                          bodyPreview: body,
                          pinned: pinned,
                          onTap: () => _loadTemplate(title: title, body: body),
                          onPin: () => _togglePinned(d.id, pinned),
                          onDelete: () => _confirmDelete(docId: d.id, title: title),
                          onUse: () => _loadTemplate(title: title, body: body),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete({required String docId, required String title}) async {
    final t = title.trim().isEmpty ? '(sem título)' : title.trim();

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35), // fundo escuro igual “admin”
      builder: (ctx) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            dialogTheme: const DialogThemeData(
              backgroundColor: kBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                side: BorderSide(color: Color(0x1F000000)),
              ),
            ),
          ),
          child: AlertDialog(
            title: const Text(
              'Excluir template?',
              style: TextStyle(
                color: kText,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              'Você vai excluir: "$t".\nEssa ação não pode ser desfeita',
              style: TextStyle(color: Colors.black.withOpacity(0.85)),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kText,
                  side: BorderSide(color: Colors.black.withOpacity(0.25)),
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      await _deleteTemplate(docId);
    }
  }
}

// ===================== COMPONENTES =====================

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: t.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SendCard extends StatelessWidget {
  static const Color kPrimary = Color(0xFF4E0405);

  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;

  final String topic;
  final bool sending;

  final ValueChanged<String> onTopicChanged;
  final VoidCallback onSend;
  final VoidCallback onSaveTemplate;

  const _SendCard({
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.topic,
    required this.sending,
    required this.onTopicChanged,
    required this.onSend,
    required this.onSaveTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enviar para', style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _TopicSegment(
              value: topic,
              onChanged: onTopicChanged,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Mensagem'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: sending ? null : onSend,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(sending ? 'Enviando...' : 'Enviar'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary),
                  ),
                  onPressed: onSaveTemplate,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Salvar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicSegment extends StatelessWidget {
  static const Color kPrimary = Color(0xFF4E0405);

  final String value;
  final ValueChanged<String> onChanged;

  const _TopicSegment({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = <String>{value};

    return SegmentedButton<String>(
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return Colors.black;
        }),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return kPrimary;
          return Colors.white;
        }),

        side: MaterialStateProperty.all(
          BorderSide(color: Colors.black.withOpacity(0.18)),
        ),
      ),
      segments: const [
        ButtonSegment(
          value: 'all',
          label: Text('Todos'),
          icon: Icon(Icons.verified_user_outlined),
        ),
        ButtonSegment(
          value: 'admins',
          label: Text('Admins'),
          icon: Icon(Icons.admin_panel_settings_outlined),
        ),
      ],
      selected: selected,
      onSelectionChanged: (s) {
        final v = s.isEmpty ? 'all' : s.first;
        onChanged(v);
      },
    );
  }
}

class _TemplateTile extends StatelessWidget {
  static const Color kPrimary = Color(0xFF4E0405);

  final String title;
  final String bodyPreview;
  final bool pinned;

  final VoidCallback onTap;
  final VoidCallback onUse;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const _TemplateTile({
    required this.title,
    required this.bodyPreview,
    required this.pinned,
    required this.onTap,
    required this.onUse,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = bodyPreview.trim().isEmpty ? 'Sem mensagem' : bodyPreview.trim();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pinned ? kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.12)),
                ),
                child: Icon(
                  pinned ? Icons.push_pin_rounded : Icons.notifications_none_rounded,
                  color: pinned ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (pinned)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: kPrimary, width: 1),
                            ),
                            child: const Text(
                              'Fixado',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black.withOpacity(0.75)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onUse,
                          icon: const Icon(Icons.input_rounded, size: 18),
                          label: const Text('Usar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimary,
                            side: const BorderSide(color: kPrimary),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onPin,
                          icon: Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 18),
                          label: Text(pinned ? 'Desafixar' : 'Fixar'),
                          style: TextButton.styleFrom(foregroundColor: Colors.black),
                        ),
                        TextButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Excluir'),
                          style: TextButton.styleFrom(foregroundColor: Colors.black),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 34, color: Colors.black),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black.withOpacity(0.75)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
