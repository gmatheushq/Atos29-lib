import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';

import 'menu_page.dart';
import 'share_post_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_cropper/image_cropper.dart';
import 'pedidos_oracoes.dart';

import 'exame_consciencia_page.dart';
import 'terco_page.dart';
import 'lectio_page.dart';
import 'notification_page.dart';

import 'package:dio/dio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:cloud_functions/cloud_functions.dart';

import 'jornada_page.dart';
import 'liturgia_page.dart';

part 'feed_post_actions_page.dart';

const atosPrimary = Color(0xFF6A0F0F);
const atosDeep = Color(0xFF3A0808);
const atosAccent = Color(0xFF8E2A2A);
const atosBg = Color(0xFFFAF9F7);
const atosCard = Colors.white;

const String kPostShareBaseUrl = "https://atos29.app/post/";
const String kAtosLogoAssetPath = "assets/images/logo78_4_5.png";

class _QuickItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  final bool isFeatured;
  final List<Color>? gradient;
  final Color? accent;

  const _QuickItem.featured({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required List<Color> gradient,
  })  : isFeatured = true,
        gradient = gradient,
        accent = null;

  const _QuickItem.soft({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required Color accent,
  })  : isFeatured = false,
        accent = accent,
        gradient = null;
}

class PostComposerPayload {
  final String titulo;
  final String texto;
  final List<File> images;
  final String? pollQuestion;
  final List<String> pollOptions;

  const PostComposerPayload({
    required this.titulo,
    required this.texto,
    this.images = const [],
    this.pollQuestion,
    this.pollOptions = const [],
  });

  bool get hasPoll =>
      (pollQuestion ?? "").trim().isNotEmpty &&
          pollOptions.where((e) => e.trim().isNotEmpty).length >= 2;

  bool get hasImages => images.isNotEmpty;
}

class PostComposerPage extends StatefulWidget {
  const PostComposerPage({
    super.key,
    required this.atosPrimary,
    required this.atosDeep,
    required this.onSubmit,
    this.isEditing = false,
    this.initialTitulo = "",
    this.initialTexto = "",
    this.initialPollQuestion,
    this.initialPollOptions = const [],
  });

  final Color atosPrimary;
  final Color atosDeep;
  final Future<void> Function(PostComposerPayload payload) onSubmit;
  final bool isEditing;
  final String initialTitulo;
  final String initialTexto;
  final String? initialPollQuestion;
  final List<String> initialPollOptions;

  @override
  State<PostComposerPage> createState() => _PostComposerPageState();
}

class _PostComposerPageState extends State<PostComposerPage> {
  final _tituloCtrl = TextEditingController();
  final _textoCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _cropping = false;
  final List<File> _images = [];

  bool _sending = false;
  bool _isPoll = false;
  final _pollQuestionCtrl = TextEditingController();
  final List<TextEditingController> _pollOptionCtrls = [];

  @override
  void initState() {
    super.initState();
    _tituloCtrl.text = widget.initialTitulo;
    _textoCtrl.text = widget.initialTexto;

    final initQ = (widget.initialPollQuestion ?? "").trim();
    final initOpts = widget.initialPollOptions
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    _isPoll = initQ.isNotEmpty && initOpts.length >= 2;

    _pollQuestionCtrl.text = initQ;

    if (initOpts.isNotEmpty) {
      for (final opt in initOpts) {
        _pollOptionCtrls.add(TextEditingController(text: opt));
      }
    }

    while (_pollOptionCtrls.length < 2) {
      _pollOptionCtrls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _textoCtrl.dispose();
    _pollQuestionCtrl.dispose();
    for (final c in _pollOptionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<File?> _cropFile(File file) async {
    setState(() => _cropping = true);

    try {
      final result = await ImageCropper().cropImage(
        sourcePath: file.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: "Cortar foto",
            toolbarColor: widget.atosDeep,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: widget.atosPrimary,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: "Cortar foto",
          ),
        ],
      );

      if (result == null) return null;
      return File(result.path);
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }

  Future<void> _pickAndCrop({required ImageSource source}) async {
    if (_cropping || _sending) return;

    if (source == ImageSource.gallery) {
      final xs = await _picker.pickMultiImage(imageQuality: 95);
      if (xs.isEmpty) return;

      for (final x in xs) {
        final cropped = await _cropFile(File(x.path));
        if (cropped != null && mounted) {
          setState(() => _images.add(cropped));
        }
      }
      return;
    }

    final XFile? x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (x == null) return;

    final cropped = await _cropFile(File(x.path));
    if (cropped == null) return;

    if (!mounted) return;
    setState(() => _images.add(cropped));
  }

  Future<void> _submit() async {
    if (_sending) return;

    final titulo = _tituloCtrl.text.trim();
    final texto = _textoCtrl.text.trim();

    final pollQuestion = _pollQuestionCtrl.text.trim();
    final pollOptions = _pollOptionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // validações
    final hasImages = _images.isNotEmpty;

    if (titulo.isEmpty && texto.isEmpty && !_isPoll && !hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Coloque uma foto, ou um título, ou um texto")),
      );
      return;
    }

    if (_isPoll) {
      if (pollQuestion.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Digite a pergunta da enquete")),
        );
        return;
      }
      if (pollOptions.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Coloque pelo menos 2 opções")),
        );
        return;
      }
    }

    setState(() => _sending = true);

    try {
      await widget.onSubmit(
        PostComposerPayload(
          titulo: titulo,
          texto: texto,
          images: List<File>.from(_images),
          pollQuestion: _isPoll ? pollQuestion : null,
          pollOptions: _isPoll ? pollOptions : const [],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar: $e")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: atosBg,
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(78, 4, 5, 1),
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isEditing ? "Editar post" : "Novo post",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : _submit,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white, // "Salvar"/"Postar" branco
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: _sending
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Text(widget.isEditing ? "Salvar" : "Postar"),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        children: [

          const SizedBox(height: 10),
          TextField(
            controller: _tituloCtrl,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: "Título (opcional)",
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: widget.atosPrimary.withOpacity(0.55),
                  width: 2,
                ),
              ),
            ),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textoCtrl,
            minLines: 6,
            maxLines: 12,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: "Escreva aqui...",
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: widget.atosPrimary.withOpacity(0.55),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                "Fotos",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withOpacity(0.75),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: (_cropping || _sending)
                    ? null
                    : () => _pickAndCrop(source: ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text("Galeria"),
                style: TextButton.styleFrom(
                  foregroundColor: widget.atosPrimary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: (_cropping || _sending)
                    ? null
                    : () => _pickAndCrop(source: ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text("Câmera"),
                style: TextButton.styleFrom(
                  foregroundColor: widget.atosPrimary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (_cropping) ...[
            const SizedBox(height: 8),
            Row(
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text("Cortando imagem..."),
              ],
            ),
          ],
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(_images.length, (i) {
                final f = _images[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        f,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () => setState(() => _images.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                "Enquete",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withOpacity(0.75),
                ),
              ),
              const Spacer(),
              Switch(
                value: _isPoll,
                onChanged: (v) => setState(() {
                  _isPoll = v;

                  if (!_isPoll) {
                    _pollQuestionCtrl.clear();
                    for (final c in _pollOptionCtrls) {
                      c.clear();
                    }
                  } else {
                    while (_pollOptionCtrls.length < 2) {
                      _pollOptionCtrls.add(TextEditingController());
                    }
                  }
                }),
                activeColor: widget.atosPrimary,
              ),
            ],
          ),
          if (_isPoll) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _pollQuestionCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: "Pergunta da enquete",
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: widget.atosPrimary.withOpacity(0.55),
                    width: 2,
                  ),
                ),
              ),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...List.generate(_pollOptionCtrls.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _pollOptionCtrls[i],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: "Opção ${i + 1}",
                    enabledBorder: UnderlineInputBorder(
                      borderSide:
                      BorderSide(color: Colors.black.withOpacity(0.12)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.atosPrimary.withOpacity(0.55),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _pollOptionCtrls.add(TextEditingController());
                  });
                },
                child: Text(
                  "+ Adicionar opção",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: widget.atosPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected
                ? Colors.black.withOpacity(0.65)
                : Colors.black.withOpacity(0.10),
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final Map<String, Uint8List> _profileBytesCache = {};

  bool _posting = false;
  bool _cropping = false;
  bool _isAdminCached = false;

  String _getMisterioDoDia() {
    final w = DateTime.now().weekday; // 1..7
    if (w == DateTime.monday || w == DateTime.saturday) return "Gozosos";
    if (w == DateTime.tuesday || w == DateTime.friday) return "Dolorosos";
    if (w == DateTime.thursday) return "Luminosos";
    return "Gloriosos";
  }

  String _labelMisterioDoDia() {
    final w = DateTime.now().weekday;
    final grupo = _getMisterioDoDia();

    final dia = switch (w) {
      DateTime.monday => "segunda",
      DateTime.tuesday => "terça",
      DateTime.wednesday => "quarta",
      DateTime.thursday => "quinta",
      DateTime.friday => "sexta",
      DateTime.saturday => "sábado",
      _ => "domingo",
    };

    return "$grupo • $dia";
  }

  @override
  void initState() {
    super.initState();
    _loadAdminCached();
  }

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 22,
    offset: const Offset(0, 10),
  );

  // ====== AVATAR (totalmente redondo) ======
  static const double _avatarSize = 45;

  Widget _avatarFallback({required Color cor}) {
    return SizedBox(
      width: _avatarSize,
      height: _avatarSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cor,
          border: Border.all(
            color: Colors.white.withOpacity(0.22),
            width: 2,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.person_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }


  Widget _avatarUser({
    required String? photoUrl,
    required Color cor,
  }) {
    final url = (photoUrl ?? "").trim();

    if (url.isEmpty) {
      return _avatarFallback(cor: cor);
    }

    return SizedBox(
      width: _avatarSize,
      height: _avatarSize,
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(cor: cor),
        ),
      ),
    );
  }


  Future<void> _loadAdminCached() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      if (mounted) setState(() => _isAdminCached = false);
      return;
    }

    try {
      final snap = await _firestore.collection('users').doc(u.uid).get();
      final role = (snap.data()?['role'] ?? 'user').toString();
      final ok = role == 'admin' || role == 'moderator' || role == 'owner';

      if (mounted) setState(() => _isAdminCached = ok);
    } catch (_) {
      if (mounted) setState(() => _isAdminCached = false);
    }
  }

  Future<Map<String, dynamic>> _getNovenaAtivaPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final nome = prefs.getString('novena_ativa_nome') ?? "Nenhuma novena ativa";
    final dia = prefs.getInt('novena_ativa_dia') ?? 0;

    final bool ativa = nome.trim().isNotEmpty && nome != "Nenhuma novena ativa";
    return {"ativa": ativa, "nome": nome, "dia": dia};
  }

  Future<void> _abrirFormularioDireto() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostComposerPage(
          atosPrimary: atosPrimary,
          atosDeep: atosDeep,
          onSubmit: (payload) async {
            await _criarPostDoComposer(payload);
          },
        ),
      ),
    );
  }

  Future<void> _abrirEditarTelaCheia(DocumentSnapshot doc) async {
    final item = doc.data() as Map<String, dynamic>? ?? {};

    final String titulo = (item['titulo'] ?? '').toString();
    final String texto = (item['texto'] ?? '').toString();
    final cor = atosPrimary;

    final poll = item['poll'];
    String? pollQuestion;
    List<String> pollOptions = [];

    if (poll is Map<String, dynamic>) {
      pollQuestion = (poll['question'] ?? '').toString();
      final opts = poll['options'];
      if (opts is List) {
        pollOptions = opts
            .map((e) {
          if (e is Map<String, dynamic>) return (e['text'] ?? '').toString();
          return e?.toString() ?? '';
        })
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostComposerPage(
          atosPrimary: atosPrimary,
          atosDeep: atosDeep,
          isEditing: true,
          initialTitulo: titulo,
          initialTexto: texto,
          initialPollQuestion: pollQuestion,
          initialPollOptions: pollOptions,
          onSubmit: (payload) async {
            final hasPoll = payload.hasPoll;

            await doc.reference.update({
              "titulo": payload.titulo.trim(),
              "texto": payload.texto.trim(),
              "corValue": atosPrimary.value,

              "tracejado": false,
              "status": "published",
              "poll": hasPoll
                  ? {
                "question": payload.pollQuestion,
                "options": payload.pollOptions
                    .map((t) => {"text": t, "votes": 0})
                    .toList(),
                "voters": <String, int>{},
              }
                  : null,

              "updatedAt": FieldValue.serverTimestamp(),
            });
          },
        ),
      ),
    );
  }

  int _corPorTipo(String tipo) {
    switch (tipo) {
      case "Aviso":
        return atosAccent.value;
      case "Recado":
        return atosDeep.value;
      case "Post":
      default:
        return atosPrimary.value;
    }
  }

  Future<void> _criarPostDoComposer(PostComposerPayload payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Usuário não autenticado");

    final List<String> imageUrls = await _uploadImages(payload.images);

    String userName = "Membro";
    String? userPhotoUrl;

    try {
      final snap = await _firestore.collection('users').doc(user.uid).get();
      final data = snap.data() ?? {};

      userName =
          (data['userName'] ?? data['name'] ?? user.displayName ?? "Membro")
              .toString();
      userPhotoUrl = (data['photoUrl'] as String?)?.trim();
      if (userPhotoUrl != null && userPhotoUrl!.isEmpty) userPhotoUrl = null;
    } catch (_) {
      userName = user.displayName ?? "Membro";
      userPhotoUrl = null;
    }

    final hasPoll = payload.hasPoll;

    await _firestore.collection('posts').add({
      "uid": user.uid,
      "userName": userName,
      "userPhotoUrl": userPhotoUrl,

      "titulo": payload.titulo.trim(),
      "texto": payload.texto.trim(),
      "corValue": atosPrimary.value,

      "tracejado": false,
      "curtidas": <String>[],
      "imageUrls": imageUrls,

      if (imageUrls.length == 1) "imageUrl": imageUrls.first,

      "createdAt": FieldValue.serverTimestamp(),
      "status": "published",

      "poll": hasPoll
          ? {
        "question": (payload.pollQuestion ?? "").trim(),
        "options": payload.pollOptions
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .map((t) => {"text": t, "votes": 0})
            .toList(),
        "voters": <String, int>{},
      }
          : null,
    });
  }

  Future<void> _notificarPostAdmin(DocumentSnapshot doc, Map<String, dynamic> item) async {
    // garante cache atualizado
    if (!_isAdminCached) {
      await _loadAdminCached();
    }
    if (!_isAdminCached) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Apenas administradores podem notificar")),
      );
      return;
    }

    try {

      final fresh = await doc.reference.get();
      final freshItem = fresh.data() as Map<String, dynamic>? ?? {};

      final titulo = (freshItem['titulo'] ?? '').toString().trim();
      final texto  = (freshItem['texto'] ?? '').toString().trim();

      final imageUrls = _extractImageUrls(freshItem);
      final poll = _extractPoll(freshItem);

      final pollQuestion = (poll?['question'] ?? '').toString().trim();
      List<String> pollOptions = [];
      if (poll != null && poll['options'] is List) {
        pollOptions = (poll['options'] as List)
            .map((e) => e is Map ? (e['text'] ?? '').toString() : e.toString())
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      final hasPoll = pollQuestion.isNotEmpty && pollOptions.length >= 2;

      final payload = <String, dynamic>{
        "screen": "post",
        "postId": fresh.id,
        "titulo": titulo,
        "texto": texto,
        "imageUrls": imageUrls,
        "imageUrl": imageUrls.isNotEmpty ? imageUrls.first : null,
        "hasPoll": hasPoll,
        "pollQuestion": hasPoll ? pollQuestion : null,
        "pollOptions": hasPoll ? pollOptions : <String>[],
        "shareLink": "$kPostShareBaseUrl${fresh.id}",
      };

      final callable = FirebaseFunctions.instance.httpsCallable('notifyPost');
      await callable.call(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notificação enviada")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao notificar: $e")),
      );
    }
  }


  void _abrirImagemFullscreen(List<String> urls, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) {
        return _FullscreenGallery(
          urls: urls,
          initialIndex: initialIndex,
          onDownload: (url) => _baixarImagem(url),
        );
      },
    );
  }

  void _abrirImagemLocalFullscreen(List<File> files, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) {
        return _FullscreenLocalGallery(
          files: files,
          initialIndex: initialIndex,
        );
      },
    );
  }

  // ====== helper: pega imageUrls com compatibilidade (imageUrl antigo) ======
  List<String> _extractImageUrls(Map<String, dynamic> item) {
    final dynamic list = item['imageUrls'];
    if (list is List) {
      return list.whereType<String>().where((e) => e.trim().isNotEmpty).toList();
    }
    final String? old = item['imageUrl'] as String?;
    if (old != null && old.trim().isNotEmpty) return [old.trim()];
    return [];
  }

  // ====== IMAGENS DO POST (GRID NOVO IGUAL SHARE) ======
  Widget _postImagesGridPreview(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return _FeedImageGrid(
      urls: urls,
      onOpen: (index) => _abrirImagemFullscreen(urls, index),
      placeholderBuilder: () => const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(color: atosPrimary, strokeWidth: 2),
        ),
      ),
    );
  }

  // ================= ENQUETE NO FEED =================

  Map<String, dynamic>? _extractPoll(Map<String, dynamic> item) {
    final p = item['poll'];
    if (p is Map<String, dynamic>) return p;
    if (p is Map) return Map<String, dynamic>.from(p);
    return null;
  }

  Widget _pollCard({
    required DocumentSnapshot doc,
    required Map<String, dynamic> poll,
    required Color cor,
  }) {
    final String question = (poll['question'] ?? '').toString().trim();
    final List optionsRaw =
    (poll['options'] is List) ? (poll['options'] as List) : [];
    final Map votersRaw = (poll['voters'] is Map) ? (poll['voters'] as Map) : {};

    if (question.isEmpty || optionsRaw.length < 2) {
      return const SizedBox.shrink();
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool hasVoted = myUid.isNotEmpty && votersRaw.containsKey(myUid);
    final int myIndex = hasVoted ? (votersRaw[myUid] as int? ?? -1) : -1;

    final options = optionsRaw
        .map((e) =>
    e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .toList();

    int totalVotes = 0;
    for (final o in options) {
      final v = (o['votes'] is int)
          ? (o['votes'] as int)
          : int.tryParse("${o['votes']}") ?? 0;
      totalVotes += v;
    }

    Future<void> vote(int index) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final ref = doc.reference;

      await _firestore.runTransaction((tx) async {
        final fresh = await tx.get(ref);
        final data = fresh.data() as Map<String, dynamic>?;

        final pollNow = data?['poll'];
        if (pollNow is! Map) return;

        final Map<String, dynamic> pollMap = Map<String, dynamic>.from(pollNow);

        final Map<String, dynamic> votersNow = (pollMap['voters'] is Map)
            ? Map<String, dynamic>.from(pollMap['voters'] as Map)
            : {};

        final List optsNow =
        (pollMap['options'] is List) ? List.from(pollMap['options'] as List) : [];

        if (index < 0 || index >= optsNow.length) return;

        final int? previousIndex =
        votersNow.containsKey(uid) ? (votersNow[uid] as int?) : null;
        if (previousIndex == index) return;

        if (previousIndex != null &&
            previousIndex >= 0 &&
            previousIndex < optsNow.length) {
          final Map<String, dynamic> prevOpt =
          Map<String, dynamic>.from(optsNow[previousIndex] as Map);
          final int prevVotes = (prevOpt['votes'] is int)
              ? prevOpt['votes'] as int
              : int.tryParse("${prevOpt['votes']}") ?? 0;

          prevOpt['votes'] = (prevVotes - 1).clamp(0, 1 << 31);
          optsNow[previousIndex] = prevOpt;
        }

        final Map<String, dynamic> newOpt =
        Map<String, dynamic>.from(optsNow[index] as Map);
        final int newVotes = (newOpt['votes'] is int)
            ? newOpt['votes'] as int
            : int.tryParse("${newOpt['votes']}") ?? 0;

        newOpt['votes'] = newVotes + 1;
        optsNow[index] = newOpt;

        votersNow[uid] = index;

        pollMap['options'] = optsNow;
        pollMap['voters'] = votersNow;

        tx.update(ref, {'poll': pollMap});
      });
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_rounded, size: 18, color: cor.withOpacity(0.75)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black.withOpacity(0.78),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(options.length, (i) {
            final String text = (options[i]['text'] ?? '').toString();
            final int votes = (options[i]['votes'] is int)
                ? (options[i]['votes'] as int)
                : int.tryParse("${options[i]['votes']}") ?? 0;

            final double pct =
            totalVotes <= 0 ? 0 : (votes / totalVotes).clamp(0.0, 1.0);
            final bool selected = hasVoted && myIndex == i;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => vote(i),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: selected ? cor.withOpacity(0.10) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? cor.withOpacity(0.35)
                          : Colors.black.withOpacity(0.06),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.black.withOpacity(0.75),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            hasVoted ? "$votes" : "",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
                      if (hasVoted) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: Colors.black.withOpacity(0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                cor.withOpacity(0.75)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 2),
          Text(
            hasVoted ? "$totalVotes voto(s)" : "Toque para votar",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.black.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }

  // ====== POST EM LISTA ======
  Widget _postListItem(DocumentSnapshot doc) {
    final item = doc.data() as Map<String, dynamic>;

    final int corValue = (item['corValue'] is int)
        ? (item['corValue'] as int)
        : atosPrimary.value;
    final cor = Color(corValue);


    final List curtidas = item['curtidas'] ?? [];
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final bool curtidoPorMim = curtidas.contains(myUid);
    final bool meuPost = myUid.isNotEmpty && myUid == (item['uid'] ?? "");

    final String titulo = (item['titulo'] ?? "").toString();
    final String texto = (item['texto'] ?? "").toString();

    final bool tracejado = item['tracejado'] == true;

    final String postUserName = (item['userName'] ?? "Membro").toString();
    final String postUid = (item['uid'] ?? '').toString();

    final String? postPhotoFromPost = (item['userPhotoUrl'] is String)
        ? (item['userPhotoUrl'] as String).trim()
        : null;

    final String? postPhotoFinal =
    (postPhotoFromPost != null && postPhotoFromPost.isNotEmpty)
        ? postPhotoFromPost
        : null;

    final List<String> imageUrls = _extractImageUrls(item);

    final poll = _extractPoll(item);

    Widget header() {
      if (postUid.isEmpty) {
        return Row(
          children: [
            _avatarUser(photoUrl: null, cor: cor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    postUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.82),
                      letterSpacing: -0.2,
                    ),
                  ),

                ],
              ),
            ),
          ],
        );
      }

      return StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(postUid).snapshots(),
        builder: (context, snapUser) {
          final data = snapUser.data?.data() as Map<String, dynamic>?;

          final profileName =
          (data?['userName'] ?? data?['name'] ?? data?['displayName'] ?? '')
              .toString()
              .trim();
          final nameToShow = profileName.isNotEmpty ? profileName : postUserName;

          final String? photoUrlPerfil = (data?['photoUrl'] as String?)?.trim();
          final String? userDocPhoto =
          (photoUrlPerfil != null && photoUrlPerfil.isNotEmpty)
              ? photoUrlPerfil
              : null;

          final String? finalPhoto = postPhotoFinal ?? userDocPhoto;

          final nickRaw = (data?['nickname'] ??
              data?['username'] ??
              data?['handle'] ??
              "")
              .toString()
              .trim();
          final nick = nickRaw.isEmpty ? "" : nickRaw.toLowerCase();

          return Row(
            children: [
              _avatarUser(photoUrl: finalPhoto, cor: cor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameToShow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black.withOpacity(0.82),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (nick.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        "@$nick",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      );
    }
    // ============================================================

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: atosCard,
        borderRadius: BorderRadius.circular(24),
        border: tracejado
            ? Border.all(color: cor.withOpacity(0.55), width: 1.6)
            : Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [_softShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: header()),
                      if (meuPost || _isAdminCached)
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: Colors.black.withOpacity(0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onSelected: (v) async {
                            if (v == "delete") {
                              await _confirmarEDeletarPost(doc);
                              return;
                            }
                            if (v == "edit") {
                              await _abrirEditarTelaCheia(doc);
                              return;
                            }
                            if (v == "notify") {
                              await _notificarPostAdmin(doc, item);
                              return;
                            }
                          },
                          itemBuilder: (_) => [
                            if (meuPost)
                              const PopupMenuItem(
                                value: "edit",
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded, size: 18),
                                    SizedBox(width: 10),
                                    Text("Editar"),
                                  ],
                                ),
                              ),
                            if (_isAdminCached)
                              const PopupMenuItem(
                                value: "notify",
                                child: Row(
                                  children: [
                                    Icon(Icons.notifications_active_rounded, size: 18),
                                    SizedBox(width: 10),
                                    Text("Notificar"),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: "delete",
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18),
                                  SizedBox(width: 10),
                                  Text("Deletar"),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ✅ TÍTULO
                  if (titulo.trim().isNotEmpty) ...[
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: Colors.black.withOpacity(0.82),
                      ),
                    ),
                  ],

                  // ✅ TEXTO / LEGENDA
                  if (texto.trim().isNotEmpty) ...[
                    if (titulo.trim().isNotEmpty) const SizedBox(height: 8),
                    Text(
                      texto,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: Colors.black.withOpacity(0.62),
                      ),
                    ),
                  ],

                  // ✅ ENQUETE (se tiver)
                  if (poll != null) _pollCard(doc: doc, poll: poll, cor: cor),

                  // espaço antes das imagens, só se houver conteúdo acima
                  if (titulo.trim().isNotEmpty ||
                      texto.trim().isNotEmpty ||
                      poll != null ||
                      imageUrls.isNotEmpty)
                    const SizedBox(height: 12),

                  // ✅ IMAGENS (agora ficam abaixo de tudo e acima das ações)
                  if (imageUrls.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18), // 👈 bordas arredondadas
                      child: _postImagesGridPreview(imageUrls),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ✅ AÇÕES (curtir / compartilhar / baixar) ficam por último
                  Row(
                    children: [
                      _ActionPill(
                        icon: curtidoPorMim
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: "${curtidas.length}",
                        active: curtidoPorMim,
                        onTap: () => _alternarCurtida(doc.id, curtidas),
                      ),
                      const SizedBox(width: 10),

                      StreamBuilder<DocumentSnapshot>(
                        stream: postUid.isNotEmpty
                            ? _firestore.collection('users').doc(postUid).snapshots()
                            : null,
                        builder: (context, snapUser) {
                          final data = snapUser.data?.data() as Map<String, dynamic>?;
                          final String? photoUrlPerfil =
                          (data?['photoUrl'] as String?)?.trim();

                          final String? userDocPhoto =
                          (photoUrlPerfil != null && photoUrlPerfil.isNotEmpty)
                              ? photoUrlPerfil
                              : null;

                          final String? finalProfileUrl = postPhotoFinal ?? userDocPhoto;
                          final String userNameForShare = postUserName;

                          return _ActionPill(
                            icon: Icons.ios_share_rounded,
                            label: "Compartilhar",
                            onTap: () async {
                              Uint8List? bytes = (finalProfileUrl != null && finalProfileUrl.isNotEmpty)
                                  ? await _getProfileBytesCached(finalProfileUrl)
                                  : null;

                              bytes ??= await _buildIconAvatarPngBytes(cor: cor);

                              if (!context.mounted) return;

                              String? pollQuestion;
                              List<String> pollOptions = [];
                              List<int> pollVotes = [];
                              int? pollSelectedIndex;

                              final poll = _extractPoll(item);
                              if (poll != null) {
                                pollQuestion = (poll['question'] ?? '').toString().trim();

                                final optsRaw = poll['options'];
                                if (optsRaw is List) {
                                  pollOptions = optsRaw
                                      .map((e) {
                                    if (e is Map) return (e['text'] ?? '').toString();
                                    return e.toString();
                                  })
                                      .map((s) => s.trim())
                                      .where((s) => s.isNotEmpty)
                                      .toList();

                                  pollVotes = optsRaw.map((e) {
                                    if (e is Map) {
                                      final v = e['votes'];
                                      if (v is int) return v;
                                      return int.tryParse("$v") ?? 0;
                                    }
                                    return 0;
                                  }).toList();
                                }

                                final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
                                final voters = poll['voters'];
                                if (myUid.isNotEmpty && voters is Map && voters.containsKey(myUid)) {
                                  final idx = voters[myUid];
                                  if (idx is int) {
                                    pollSelectedIndex = idx;
                                  } else {
                                    pollSelectedIndex = int.tryParse("$idx");
                                  }
                                }
                              }

                              final hasPoll = (pollQuestion ?? '').trim().isNotEmpty && pollOptions.length >= 2;

                              // ✅ Se NÃO tiver enquete: não mostra modal nenhum
                              if (!hasPoll) {
                                await SharePostCard.openPreviewAndShare(
                                  context: context,
                                  shareLink: "$kPostShareBaseUrl${doc.id}",
                                  userName: userNameForShare,
                                  tipo: "",

                                  corTipo: cor,
                                  titulo: titulo,
                                  texto: texto,
                                  imageUrls: imageUrls,
                                  pollQuestion: null,
                                  pollOptions: const [],
                                  pollVotes: const [],
                                  pollSelectedIndex: null,
                                  pollShowResults: true,
                                  profileBytes: bytes,
                                  logoAssetPathLight: "assets/images/logo_atos29_branco.png",
                                  logoAssetPathDark: "assets/images/logo78_4_5.png",
                                  appName: "ATOS 29",
                                  logo: Icons.church_rounded,
                                );
                                return;
                              }

                              // ✅ Se tiver enquete: aí sim pergunta “Mostrar meu voto”
                              bool showMyVote = false;

                              final res = await showModalBottomSheet<bool>(
                                context: context,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                builder: (_) {
                                  bool local = false;
                                  return StatefulBuilder(
                                    builder: (context, setSt) {
                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              "Compartilhar enquete",
                                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                            ),
                                            const SizedBox(height: 10),
                                            SwitchListTile(
                                              value: local,
                                              onChanged: (v) => setSt(() => local = v),
                                              title: const Text("Mostrar meu voto"),
                                              subtitle: const Text("Se desligado, fica como voto secreto."),
                                              activeColor: atosPrimary,
                                            ),
                                            const SizedBox(height: 10),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: () => Navigator.pop(context, local),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: atosPrimary,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                ),
                                                child: const Text(
                                                  "Continuar",
                                                  style: TextStyle(fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );

                              showMyVote = res == true;

                              await SharePostCard.openPreviewAndShare(
                                context: context,
                                shareLink: "$kPostShareBaseUrl${doc.id}",
                                userName: userNameForShare,
                                tipo: "",
                                corTipo: cor,
                                titulo: titulo,
                                texto: texto,
                                imageUrls: imageUrls,
                                pollQuestion: pollQuestion,
                                pollOptions: pollOptions,
                                pollVotes: pollVotes,
                                pollSelectedIndex: showMyVote ? pollSelectedIndex : null,
                                pollShowResults: true,
                                profileBytes: bytes,
                                logoAssetPathLight: "assets/images/logo_atos29_branco.png",
                                logoAssetPathDark: "assets/images/logo78_4_5.png",
                                appName: "ATOS 29",
                                logo: Icons.church_rounded,
                              );
                            },

                          );
                        },
                      ),

                      if (imageUrls.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        _ActionPill(
                          icon: Icons.download_rounded,
                          label: "Baixar",
                          onTap: () => _baixarImagem(imageUrls.first),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],

        ),
      ),
    );
  }

  Future<Uint8List> _buildIconAvatarPngBytes({required Color cor}) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 200.0;
    final bgPaint = Paint()..color = cor;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 4,
      borderPaint,
    );

    final icon = String.fromCharCode(Icons.person_rounded.codePoint);
    final tp = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(
          fontFamily: Icons.person_rounded.fontFamily,
          package: Icons.person_rounded.fontPackage,
          fontSize: 120,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset((size - tp.width) / 2, (size - tp.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }


  // ====== TOPO (carrossel horizontal) ======
  Widget _topQuickCarousel() {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<Map<String, dynamic>>(
      future: _getNovenaAtivaPrefs(),
      builder: (context, snap) {
        final bool novenaAtiva = (snap.data?["ativa"] == true);
        final String novenaNome = (snap.data?["nome"] ?? "").toString();
        final int novenaDia = (snap.data?["dia"] ?? 0) as int;

        final List<_QuickItem> items = [
          _QuickItem.featured(
            title: "Liturgia Diária",
            subtitle: "Leituras do Dia",
            icon: Icons.auto_stories_rounded,
            gradient: const [atosDeep, atosPrimary],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LiturgiaDiariaPage()),
            ),
          ),
          if (user != null && novenaAtiva)
            _QuickItem.featured(
              title: "Novena",
              subtitle: "Dia $novenaDia/9 • $novenaNome",
              icon: Icons.auto_awesome_rounded,
              gradient: const [atosDeep, atosPrimary],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JornadaPage()),
              ),
            ),
          _QuickItem.soft(
            title: "Lectio Divina",
            subtitle: "Leitura e meditação",
            icon: Icons.menu_book_rounded,
            accent: atosPrimary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LectioDivinaPage()),
            ),
          ),
          _QuickItem.soft(
            title: "Santo Terço",
            subtitle: "Hoje: ${_labelMisterioDoDia()}",
            icon: Icons.spa_rounded,
            accent: atosPrimary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TercoPage()),
            ),
          ),
          _QuickItem.soft(
            title: "Exame de Consciência",
            subtitle: "Reflexoões diária",
            icon: Icons.edit_note_outlined,
            accent: atosPrimary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExameConscienciaPage()),
            ),
          ),
          _QuickItem.soft(
            title: "Pedidos de Orações",
            subtitle: "Envie intenções e reze por alguém!",
            icon: Icons.volunteer_activism_rounded,
            accent: atosPrimary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PedidosOracoesPage()),
              );
            },
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
              child: Row(
                children: [
                  Text(
                    "Atalhos",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.2,
                      color: Colors.black.withOpacity(0.82),
                    ),
                  ),
                  // const Spacer(),
                  // Text(
                  //   "deslize",
                  //   style: TextStyle(
                  //     fontWeight: FontWeight.w800,
                  //     fontSize: 12,
                  //     color: Colors.black.withOpacity(0.35),
                  //   ),
                  // ),
                ],
              ),
            ),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 2, right: 2),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final it = items[index];
                  const double w = 220;

                  if (it.isFeatured) {
                    return SizedBox(
                      width: w,
                      child: _FeaturedCard(
                        title: it.title,
                        subtitle: it.subtitle,
                        icon: it.icon,
                        gradient: it.gradient!,
                        onTap: it.onTap,
                      ),
                    );
                  }

                  return SizedBox(
                    width: w,
                    child: _SoftCard(
                      title: it.title,
                      subtitle: it.subtitle,
                      icon: it.icon,
                      accent: it.accent!,
                      onTap: it.onTap,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: atosBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFAF9F7),
              Color(0xFFF3F1EE),
            ],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              toolbarHeight: 110,
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              floating: false,
              pinned: false,
              leading: IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Color.fromRGBO(78, 4, 5, 1),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MenuPage(),
                    ),
                  );
                },
              ),

              title: Image.asset(
                kAtosLogoAssetPath,
                height: 115,
                fit: BoxFit.contain,
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _NotificationBell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationPage()),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _abrirFormularioDireto,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: atosPrimary,
                          width: 2.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: const [
                          Icon(
                            Icons.add_rounded,
                            size: 22,
                            color: atosPrimary,
                          ),
                          Positioned(
                            left: 1.1,
                            child: Icon(
                              Icons.add_rounded,
                              size: 22,
                              color: atosPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              ],

            ),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('posts')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          "Erro ao carregar mural:\n${snapshot.error}",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: atosPrimary),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                    child: Column(
                      children: [
                        _topQuickCarousel(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              "Feed",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: -0.2,
                                color: atosDeep,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...docs.map(_postListItem),
                        const SizedBox(height: 90),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedImageGrid extends StatelessWidget {
  final Widget Function()? placeholderBuilder;

  const _FeedImageGrid({
    required this.urls,
    required this.onOpen,
    this.placeholderBuilder,
  });

  final List<String> urls;
  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    final shown = urls.take(4).toList();
    final remaining = urls.length - shown.length;

    const double h = 220;
    final Color gapColor = Colors.black.withOpacity(0.08);

    Widget gapW() => Container(width: 2, color: gapColor);
    Widget gapH() => Container(height: 2, color: gapColor);

    Widget tile(String url, int index) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onOpen(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black.withOpacity(0.06)),
              Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return placeholderBuilder?.call() ??
                      Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: atosPrimary,
                            value: progress.expectedTotalBytes != null
                                ? (progress.cumulativeBytesLoaded /
                                (progress.expectedTotalBytes ?? 1))
                                : null,
                          ),
                        ),
                      );
                },
                errorBuilder: (_, __, ___) {
                  return Container(color: Colors.black.withOpacity(0.10));
                },
              ),
            ],
          ),
        ),
      );
    }

    Widget lastWithPlusOverlay(String url, int index) {
      return Stack(
        fit: StackFit.expand,
        children: [
          tile(url, index),
          if (remaining > 0)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onOpen(index),
                child: Container(
                  color: Colors.black.withOpacity(0.62),
                  alignment: Alignment.center,
                  child: Text(
                    "+$remaining",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: -0,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    Widget layoutByCount() {
      final c = shown.length;

      if (c == 1) {
        return tile(shown[0], 0);
      }

      if (c == 2) {
        return Row(
          children: [
            Expanded(child: tile(shown[0], 0)),
            gapW(),
            Expanded(child: tile(shown[1], 1)),
          ],
        );
      }

      if (c == 3) {
        return Row(
          children: [
            Expanded(child: tile(shown[0], 0)),
            gapW(),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: tile(shown[1], 1)),
                  gapH(),
                  Expanded(child: tile(shown[2], 2)),
                ],
              ),
            ),
          ],
        );
      }

      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: tile(shown[0], 0)),
                gapW(),
                Expanded(child: tile(shown[1], 1)),
              ],
            ),
          ),
          gapH(),
          Expanded(
            child: Row(
              children: [
                Expanded(child: tile(shown[2], 2)),
                gapW(),
                Expanded(child: lastWithPlusOverlay(shown[3], 3)),
              ],
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: h,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: Container(
          color: gapColor,
          child: layoutByCount(),
        ),
      ),
    );
  }
}

// ================= Fullscreen Gallery (network) =================

class _FullscreenGallery extends StatefulWidget {
  const _FullscreenGallery({
    required this.urls,
    required this.initialIndex,
    required this.onDownload,
  });

  final List<String> urls;
  final int initialIndex;
  final Future<void> Function(String url) onDownload;

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double dragDy = 0;
    bool dragging = false;

    // thresholds
    const dismissDistance = 140.0;
    const dismissVelocity = 900.0;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: StatefulBuilder(
          builder: (context, setSt) {
            final progress = (dragDy.abs() / 260.0).clamp(0.0, 1.0);
            final bgOpacity = (0.92 * (1.0 - progress)).clamp(0.0, 0.92);
            final scale = (1.0 - (progress * 0.08)).clamp(0.92, 1.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(bgOpacity)),
                ),

                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,

                    onVerticalDragStart: (_) => setSt(() => dragging = true),
                    onVerticalDragUpdate: (d) =>
                        setSt(() => dragDy += d.delta.dy),
                    onVerticalDragEnd: (d) {
                      final v = d.velocity.pixelsPerSecond.dy.abs();
                      final dist = dragDy.abs();
                      final shouldDismiss =
                          dist > dismissDistance || v > dismissVelocity;

                      if (shouldDismiss) {
                        Navigator.pop(context);
                      } else {
                        setSt(() {
                          dragging = false;
                          dragDy = 0;
                        });
                      }
                    },

                    child: Center(
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: dragging ? 0 : 180),
                        curve: Curves.easeOut,
                        transform: Matrix4.identity()
                          ..translate(0.0, dragDy)
                          ..scale(scale, scale),
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: widget.urls.length,
                          onPageChanged: (i) => setState(() => _current = i),
                          itemBuilder: (_, i) {
                            return InteractiveViewer(
                              minScale: 1,
                              maxScale: 4,
                              child: Center(
                                child: Image.network(
                                  widget.urls[i],
                                  fit: BoxFit.contain,
                                  loadingBuilder: (c, child, p) {
                                    if (p == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                          color: atosPrimary),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Download
                Positioned(
                  top: 10,
                  left: 10,
                  child: _glassIconButton(
                    icon: Icons.download_rounded,
                    onTap: () => widget.onDownload(widget.urls[_current]),
                  ),
                ),

                // X
                Positioned(
                  top: 10,
                  right: 10,
                  child: _glassIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ),

                // contador
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Text(
                        "${_current + 1}/${widget.urls.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  Widget _glassIconButton({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withOpacity(0.10),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= Fullscreen Gallery (local files) =================

class _FullscreenLocalGallery extends StatefulWidget {
  const _FullscreenLocalGallery(
      {required this.files, required this.initialIndex});
  final List<File> files;
  final int initialIndex;

  @override
  State<_FullscreenLocalGallery> createState() => _FullscreenLocalGalleryState();
}

class _FullscreenLocalGalleryState extends State<_FullscreenLocalGallery> {
  late final PageController _controller;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.files.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(widget.files[i], fit: BoxFit.contain),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Material(
                    color: Colors.white.withOpacity(0.10),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Text(
                    "${_current + 1}/${widget.files.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= Widgets premium =================
class _PremiumFab extends StatelessWidget {
  const _PremiumFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: atosPrimary.withOpacity(0.92),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
                boxShadow: [
                  BoxShadow(
                    color: atosPrimary.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: const [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
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

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isWine =
        accent == atosPrimary || accent == atosAccent || accent == atosDeep;
    final Color base = isWine ? accent : atosPrimary;

    final List<Color> grad = [atosDeep, base];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
        boxShadow: const [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color.withOpacity(0.95),
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = active ? Colors.red : Colors.black.withOpacity(0.55);
    final Color textColor = Colors.black.withOpacity(0.70);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: textColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumField extends StatelessWidget {
  const _PremiumField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: atosCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.55),
          ),
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.35)),
        ),
        cursorColor: atosPrimary,
      ),
    );
  }
}

class _PrimaryCTA extends StatelessWidget {
  const _PrimaryCTA(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.22),
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: child,
        ),
      ),
    );
  }
}
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onTap});

  final VoidCallback onTap;

  static const Color atosPrimary = Color(0xFF6A0F0F);
  static const Color atosDeep = Color(0xFF3A0808);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffTs = Timestamp.fromDate(cutoff);

    final notifsQuery = FirebaseFirestore.instance
        .collection("admin_notifications")
        .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
        .orderBy('createdAt', descending: true);

    final readsQuery = (uid == null)
        ? null
        : FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notification_reads')
        .where('readAt', isGreaterThanOrEqualTo: cutoffTs);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: StreamBuilder<QuerySnapshot>(
          stream: notifsQuery.snapshots(),
          builder: (context, snapNotifs) {
            final notifDocs = snapNotifs.data?.docs ?? <QueryDocumentSnapshot>[];

            if (uid == null) {
              // não logado: só ícone, sem badge
              return Icon(
                Icons.notifications_rounded,
                size: 22,
                color: atosDeep.withOpacity(0.75),
              );
            }

            return StreamBuilder<QuerySnapshot>(
              stream: readsQuery!.snapshots(),
              builder: (context, snapReads) {
                final readDocs = snapReads.data?.docs ?? const [];
                final readIds = readDocs.map((d) => d.id).toSet();

                int unread = 0;
                final now = DateTime.now();

                DateTime? asDateTime(dynamic v) {
                  if (v == null) return null;
                  if (v is Timestamp) return v.toDate();
                  if (v is DateTime) return v;
                  return null;
                }

                for (final n in notifDocs) {
                  final m = (n.data() as Map<String, dynamic>? ?? {});
                  final createdAt = asDateTime(m['createdAt']);
                  if (createdAt == null) continue;

                  final expiresAt =
                      asDateTime(m['expiresAt']) ?? createdAt.add(const Duration(days: 30));

                  if (!expiresAt.isAfter(now)) continue;

                  if (!readIds.contains(n.id)) unread++;
                }


                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications_rounded,
                      size: 26,
                      color: atosDeep.withOpacity(0.75),
                    ),

                    if (unread > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: atosPrimary, // vinho
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            unread > 99 ? "99+" : "$unread",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
