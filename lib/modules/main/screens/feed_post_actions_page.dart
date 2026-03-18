part of 'feed_page.dart';

extension _FeedPostActions on _FeedPageState {
  // ====== helpers ======
  Future<void> _waitUiToSettle() async {

    await Future.delayed(const Duration(milliseconds: 80));
  }

  static const List<String> _blockedWords = [
    // 'palavrao1',
    // 'palavrao2',
    // 'ofensa1',
    // 'ofensa2',
  ];

  Future<bool> _isAdminOrMod() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;

    final snap = await _firestore.collection('users').doc(u.uid).get();
    final role = (snap.data()?['role'] ?? 'user').toString();

    return role == 'admin' || role == 'moderator' || role == 'owner';
  }

  Future<bool> _canCurrentUserDeletePost(DocumentSnapshot doc) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;

    final data = doc.data() as Map<String, dynamic>?;
    final postOwnerUid = (data?['uid'] ?? '').toString();

    if (postOwnerUid.isNotEmpty && postOwnerUid == u.uid) return true;

    // se não é dono, só pode se for admin/mod/owner
    return await _isAdminOrMod();
  }

  Future<void> _logAdminAction({
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? metadata,
  }) async {
    final actorUid = FirebaseAuth.instance.currentUser?.uid;

    await _firestore.collection('audit_logs').add({
      'actorUid': actorUid,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'metadata': metadata ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _normalizeText(String input) {
    var s = input.toLowerCase().trim();

    // remove acentos básicos
    s = s
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');

    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    // comprime espaços
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  bool _containsBlockedWord(String text) {
    if (_blockedWords.isEmpty) return false;

    final normalized = _normalizeText(text);

    // separa por palavras
    final words = normalized.split(' ');

    for (final w in words) {
      if (_blockedWords.contains(w)) return true;
    }

    // também detecta quando a pessoa cola tudo junto
    for (final bw in _blockedWords) {
      if (normalized.contains(bw)) return true;
    }

    return false;
  }

  Future<Map<String, dynamic>?> _getMyUserDoc() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    final snap = await _firestore.collection('users').doc(u.uid).get();
    return snap.data();
  }

  Future<bool> _canCurrentUserPost() async {
    final data = await _getMyUserDoc();
    if (data == null) return false;

    final status = (data['status'] ?? 'active').toString();

    final canPost = (data['canPost'] ?? true) == true;

    if (status == 'banned') return false;
    if (!canPost) return false;

    return true;
  }

  // ====== CROP ======

  Future<File?> _cropImageFile(File file) async {
    // trava anti-duplo clique/dupla abertura
    if (_cropping) return null;
    _cropping = true;

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cortar',
            toolbarColor: atosDeep,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: atosPrimary,
            initAspectRatio: CropAspectRatioPreset.original,
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.ratio3x2,
            ],

            lockAspectRatio: false,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Cortar',
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.ratio3x2,
            ],
          ),
        ],
      );

      if (cropped == null) return null;
      return File(cropped.path);
    } catch (e, st) {
      debugPrint("crop error: $e\n$st");
      return null;
    } finally {
      _cropping = false;
    }
  }

  // ====== AVATAR BYTE (para share) ======
  Future<Uint8List> _buildLetterAvatarPngBytes({
    required String userName,
    required Color cor,
    int size = 120,
  }) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final double s = size.toDouble();

    final bgPaint = Paint()..color = cor;

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.06;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(s * 0.38),
    );

    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    final String letter =
    (userName.trim().isNotEmpty ? userName.trim()[0] : "M").toUpperCase();

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: s * 0.52,
          color: Colors.white,
        ),
      ),
    )..layout();

    final offset = Offset(
      (s - textPainter.width) / 2,
      (s - textPainter.height) / 2 - (s * 0.02),
    );
    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List?> _downloadBytes(String url) async {
    final u = url.trim();
    if (u.isEmpty) return null;

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(u));
      final res = await req.close();
      if (res.statusCode != 200) return null;

      final chunks = <int>[];
      await for (final c in res) {
        chunks.addAll(c);
      }
      return Uint8List.fromList(chunks);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List?> _getProfileBytesCached(String url) async {
    if (url.isEmpty) return null;

    if (_profileBytesCache.containsKey(url)) {
      return _profileBytesCache[url];
    }

    final bytes = await _downloadBytes(url);

    if (bytes != null) {
      _profileBytesCache[url] = bytes;
    }

    return bytes;
  }

  // ====== UPLOAD DE IMAGENS ======
  Future<List<String>> _uploadImages(List<File> files) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || files.isEmpty) return [];

    final storage = FirebaseStorage.instance;
    debugPrint(">>> STORAGE bucket = ${storage.bucket}");

    final List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_$i.jpg";
      final ref = storage.ref().child("posts/${user.uid}/$fileName");

      final task = await ref.putFile(
        files[i],
        SettableMetadata(contentType: "image/jpeg"),
      );

      urls.add(await task.ref.getDownloadURL());
    }

    return urls;
  }

  // ====== BAIXAR IMAGEM (salvar na galeria) ======
  Future<void> _baixarImagem(String imageUrl) async {
    try {
      await Permission.photos.request();
      await Permission.storage.request();

      final dir = Directory.systemTemp;
      final filePath = "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

      await Dio().download(imageUrl, filePath);

      final result =
      await ImageGallerySaverPlus.saveFile(filePath, isReturnPathOfIOS: true);
      final ok = (result is Map && result['isSuccess'] == true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? "Imagem salva na galeria"
              : "Falha: tente novamente"),
          backgroundColor: atosDeep,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao baixar: $e"),
          backgroundColor: atosDeep,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  // --- POST ---
  Future<void> _postarNoFirebase({
    required String titulo,
    required String texto,
    required String tipo,
    required Color cor,
    required bool tracejado,
    required List<File> images,
  }) async {
    if (_posting) return;

    final hasTitle = titulo.trim().isNotEmpty;
    final hasText = texto.trim().isNotEmpty;
    final hasImages = images.isNotEmpty;

    if (!hasTitle && !hasText && !hasImages) return;

    final allowed = await _canCurrentUserPost();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Você não pode postar no momento"),
          backgroundColor: atosDeep,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    final fullText = "${titulo.trim()} ${texto.trim()}".trim();
    if (_containsBlockedWord(fullText)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          const Text("Seu texto contém palavras que não são permitidas"),
          backgroundColor: atosDeep,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    setState(() => _posting = true);

    try {
      final imageUrls = await _uploadImages(images);

      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;

      String userName = "Membro";
      String? userPhotoUrl;

      try {
        final snap = await _firestore.collection('users').doc(uid).get();
        final data = snap.data() ?? {};
        userName =
            (data['userName'] ?? data['name'] ?? user?.displayName ?? "Membro")
                .toString();
        userPhotoUrl = (data['photoUrl'] as String?)?.trim();
        if (userPhotoUrl != null && userPhotoUrl!.isEmpty) userPhotoUrl = null;
      } catch (_) {
        userName = user?.displayName ?? "Membro";
        userPhotoUrl = null;
      }

      await _firestore.collection('posts').add({
        "titulo": titulo.trim(),
        "texto": texto.trim(),
        "tipo": tipo,
        "corValue": cor.value,
        "tracejado": false,
        "uid": uid,
        "userPhotoUrl": userPhotoUrl,
        "userName": userName,
        "createdAt": FieldValue.serverTimestamp(),
        "curtidas": <String>[],
        "imageUrls": imageUrls,
        "status": "published",
        "poll": null,
      });
    } on FirebaseException catch (e) {
      debugPrint("STORAGE/FIREBASE ERROR code=${e.code} message=${e.message}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro Firebase: ${e.code}\n${e.message ?? ''}"),
          backgroundColor: atosDeep,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao postar: $e"),
          backgroundColor: atosDeep,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _confirmarEDeletarPost(DocumentSnapshot doc) async {
    final canDelete = await _canCurrentUserDeletePost(doc);

    if (!canDelete) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Você não tem permissão para deletar este post"),
          backgroundColor: atosDeep,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    final u = FirebaseAuth.instance.currentUser;
    final myUid = u?.uid ?? '';

    final data = doc.data() as Map<String, dynamic>?;
    final postOwnerUid = (data?['uid'] ?? '').toString();
    final isOwner = postOwnerUid.isNotEmpty && postOwnerUid == myUid;

    final bool? ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Deletar post?"),
          content: Text(
            isOwner
                ? "Essa ação não pode ser desfeita"
                : "Você está deletando um post de outro usuário (Admin). Essa ação não pode ser desfeita",
          ),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: atosPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Deletar"),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      await doc.reference.delete();

      // log (bom pra auditoria)
      await _logAdminAction(
        action: 'posts.delete',
        targetType: 'post',
        targetId: doc.id,
        metadata: {
          'deletedOwnerUid': postOwnerUid,
          'byAdmin': !isOwner,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text(!isOwner ? "Post removido (Admin)" : "Post deletado"),
          backgroundColor: atosDeep,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  // --- LIKE ---
  void _alternarCurtida(String docId, List curtidas) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final myUid = user.uid;

    if (curtidas.contains(myUid)) {
      _firestore.collection('posts').doc(docId).update({
        "curtidas": FieldValue.arrayRemove([myUid])
      });
    } else {
      _firestore.collection('posts').doc(docId).update({
        "curtidas": FieldValue.arrayUnion([myUid])
      });
    }
  }

  // ====== FAB abre direto o formulário ======
  void _abrirFormularioDireto() => _abrirFormulario();

  // ====== FORM EDITAR ======
  void _abrirFormularioEditar(DocumentSnapshot doc) {
    final item = doc.data() as Map<String, dynamic>;

    final tituloController =
    TextEditingController(text: (item['titulo'] ?? "").toString());
    final textoController =
    TextEditingController(text: (item['texto'] ?? "").toString());

    String? tipoSelecionado = (item['tipo'] ?? "Post").toString();
    Color? corSelecionada = Color(item['corValue'] ?? atosPrimary.value);

    bool tracejadoSelecionado = item['tracejado'] == true;

    final List<String> existingUrls = _extractImageUrls(item);
    final List<File> newImages = [];

    bool pickingImages = false;
    bool actionLock = false;

    Future<void> pickImages(
        BuildContext modalContext, StateSetter setModalState) async {
      if (pickingImages) return;
      pickingImages = true;

      try {
        final picked = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1600,
        );

        if (!modalContext.mounted) return;
        if (picked.isEmpty) return;

        setModalState(() {
          newImages.addAll(picked.map((x) => File(x.path)));
        });
      } catch (e) {
        debugPrint("pickImages edit error: $e");
      } finally {
        pickingImages = false;
      }
    }

    void toggleTipo(StateSetter setModalState, String label, Color cor,
        {bool tracejado = false}) {
      setModalState(() {
        final ativo = tipoSelecionado == label;
        if (ativo) {
          tipoSelecionado = null;
          corSelecionada = null;
          tracejadoSelecionado = false;
        } else {
          tipoSelecionado = label;
          corSelecionada = cor;
          tracejadoSelecionado = tracejado;
        }
      });
    }

    Widget tipoCard(StateSetter setModalState, String label, Color cor,
        {bool tracejado = false}) {
      final ativo = tipoSelecionado == label;

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => toggleTipo(setModalState, label, cor, tracejado: tracejado),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: ativo ? cor.withOpacity(0.12) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ativo ? cor.withOpacity(0.35) : Colors.black.withOpacity(0.06),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    color: Colors.black.withOpacity(0.78),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget imagesPreview(StateSetter setModalState) {
      if (existingUrls.isEmpty && newImages.isEmpty) {
        return const SizedBox.shrink();
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 190,
          child: PageView.builder(
            itemCount: existingUrls.length + newImages.length,
            itemBuilder: (context, index) {
              final bool isExisting = index < existingUrls.length;

              return GestureDetector(
                onTap: () async {
                  if (actionLock) return;
                  actionLock = true;

                  try {
                    if (isExisting) {
                      final action = await showModalBottomSheet<String>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        barrierColor: Colors.black.withOpacity(0.35),
                        builder: (_) => SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                color: Colors.white,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 10),
                                    Container(
                                      width: 44,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ListTile(
                                      leading: const Icon(Icons.remove_circle_outline_rounded),
                                      title: const Text("Remover do post"),
                                      onTap: () => Navigator.pop(context, "remove"),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.open_in_full_rounded),
                                      title: const Text("Ver"),
                                      onTap: () => Navigator.pop(context, "view"),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );

                      if (action == "view") {
                        _abrirImagemFullscreen(existingUrls, index);
                        return;
                      }
                      if (action == "remove") {
                        setModalState(() => existingUrls.removeAt(index));
                        return;
                      }
                    } else {
                      final localIndex = index - existingUrls.length;

                      final action = await showModalBottomSheet<String>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        barrierColor: Colors.black.withOpacity(0.35),
                        builder: (_) => SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                color: Colors.white,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 10),
                                    Container(
                                      width: 44,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ListTile(
                                      leading: const Icon(Icons.crop_rounded),
                                      title: const Text("Cortar"),
                                      onTap: () => Navigator.pop(context, "crop"),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.remove_circle_outline_rounded),
                                      title: const Text("Remover"),
                                      onTap: () => Navigator.pop(context, "remove"),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );

                      if (action == "remove") {
                        setModalState(() => newImages.removeAt(localIndex));
                        return;
                      }

                      if (action == "crop") {
                        if (_cropping) return;

                        await _waitUiToSettle();

                        final original = newImages[localIndex];
                        final cropped = await _cropImageFile(original);
                        if (cropped == null) return;

                        if (!context.mounted) return;
                        setModalState(() => newImages[localIndex] = cropped);
                        return;
                      }
                    }
                  } finally {
                    // destrava depois de um instante
                    await Future.delayed(const Duration(milliseconds: 120));
                    actionLock = false;
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isExisting)
                      Image.network(existingUrls[index], fit: BoxFit.cover)
                    else
                      Image.file(
                        newImages[index - existingUrls.length],
                        fit: BoxFit.cover,
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          "${index + 1}/${existingUrls.length + newImages.length}",
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
              );
            },
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final Color formAccent = corSelecionada ?? atosPrimary;

          Future<void> salvarEdicao() async {
            if (_posting) return;
            FocusScope.of(context).unfocus();

            final titulo = tituloController.text.trim();
            final texto = textoController.text.trim();

            final hasTitle = titulo.isNotEmpty;
            final hasText = texto.isNotEmpty;
            final hasImages = existingUrls.isNotEmpty || newImages.isNotEmpty;

            if (!hasTitle && !hasText && !hasImages) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: const Text("Não pode ficar vazio"),
                  backgroundColor: atosDeep,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
              return;
            }

            final fullText = "$titulo $texto".trim();
            if (_containsBlockedWord(fullText)) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: const Text("Seu texto contém palavras que não são permitidas"),
                  backgroundColor: atosDeep,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
              return;
            }

            setState(() => _posting = true);

            try {
              final newUrls = await _uploadImages(List<File>.from(newImages));
              final updatedUrls = [...existingUrls, ...newUrls];

              final tipoFinal =
              (tipoSelecionado == null || tipoSelecionado!.trim().isEmpty)
                  ? "Post"
                  : tipoSelecionado!.trim();

              final corFinal = corSelecionada ?? atosPrimary;
              final tracejadoFinal = false;

              await doc.reference.update({
                "titulo": titulo,
                "texto": texto,
                "tipo": tipoFinal,
                "corValue": corFinal.value,
                "tracejado": tracejadoFinal,
                "imageUrls": updatedUrls,
                "updatedAt": FieldValue.serverTimestamp(),
                "status": "published",
              });

              if (Navigator.canPop(context)) Navigator.pop(context);

              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: const Text("Post atualizado"),
                  backgroundColor: atosDeep,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text("Erro ao editar: $e"),
                  backgroundColor: atosDeep,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
            } finally {
              if (mounted) setState(() => _posting = false);
            }
          }

          return _GlassSheet(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 14,
                  bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Handle(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: formAccent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: formAccent.withOpacity(0.16)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, size: 16, color: formAccent),
                                const SizedBox(width: 8),
                                Text(
                                  "EDITAR POST",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    fontSize: 11,
                                    color: formAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close_rounded, color: Colors.black.withOpacity(0.45)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Tipo • toque de novo pra desmarcar",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          tipoCard(setModalState, "Recado", Colors.blue),
                          tipoCard(setModalState, "Aviso", Colors.orange),
                          // tipoCard(setModalState, "Ideia", Colors.green),
                          tipoCard(setModalState, "Importante", atosPrimary, tracejado: true),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _PremiumField(
                        controller: tituloController,
                        label: "Título (opcional)",
                        hint: "Ex: Aviso importante",
                      ),
                      const SizedBox(height: 12),
                      _PremiumField(
                        controller: textoController,
                        label: "Legenda (opcional)",
                        hint: "Escreva sua mensagem...",
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => pickImages(context, setModalState),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_library_rounded, color: formAccent),
                                    const SizedBox(width: 10),
                                    const Text(
                                      "Adicionar fotos",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: atosDeep,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (existingUrls.isNotEmpty || newImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        imagesPreview(setModalState),
                      ],
                      const SizedBox(height: 14),
                      _PrimaryCTA(
                        label: _posting ? "SALVANDO..." : "SALVAR",
                        color: formAccent,
                        onTap: _posting ? () {} : () => salvarEdicao(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ====== FORM NOVO POST ======
  void _abrirFormulario() {
    final tituloController = TextEditingController();
    final textoController = TextEditingController();

    String? tipoSelecionado;
    Color? corSelecionada;
    bool tracejadoSelecionado = false;
    final List<File> selectedImages = [];
    bool pickingImages = false;
    bool actionLock = false;

    Future<void> pickImages(
        BuildContext modalContext, StateSetter setModalState) async {
      if (pickingImages) return;
      pickingImages = true;

      try {
        final picked = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1600,
        );

        if (!modalContext.mounted) return;
        if (picked.isEmpty) return;

        setModalState(() {
          selectedImages.addAll(picked.map((x) => File(x.path)));
        });
      } catch (e) {
        debugPrint("pickImages error: $e");
      } finally {
        pickingImages = false;
      }
    }

    void toggleTipo(StateSetter setModalState, String label, Color cor,
        {bool tracejado = false}) {
      setModalState(() {
        final ativo = tipoSelecionado == label;
        if (ativo) {
          tipoSelecionado = null;
          corSelecionada = null;
          tracejadoSelecionado = false;
        } else {
          tipoSelecionado = label;
          corSelecionada = cor;
          tracejadoSelecionado = tracejado;
        }
      });
    }

    Widget tipoCard(StateSetter setModalState, String label, Color cor,
        {bool tracejado = false}) {
      final ativo = tipoSelecionado == label;

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => toggleTipo(setModalState, label, cor, tracejado: tracejado),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: ativo ? cor.withOpacity(0.12) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ativo ? cor.withOpacity(0.35) : Colors.black.withOpacity(0.06),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    color: Colors.black.withOpacity(0.78),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget imagesPreview(StateSetter setModalState) {
      if (selectedImages.isEmpty) return const SizedBox.shrink();

      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 190,
          child: PageView.builder(
            itemCount: selectedImages.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () async {
                  if (actionLock) return;
                  actionLock = true;

                  try {
                    final action = await showModalBottomSheet<String>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      barrierColor: Colors.black.withOpacity(0.35),
                      builder: (_) {
                        return SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                color: Colors.white,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 10),
                                    Container(
                                      width: 44,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ListTile(
                                      leading: const Icon(Icons.crop_rounded),
                                      title: const Text("Cortar"),
                                      onTap: () => Navigator.pop(context, "crop"),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.remove_circle_outline_rounded),
                                      title: const Text("Remover"),
                                      onTap: () => Navigator.pop(context, "remove"),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.open_in_full_rounded),
                                      title: const Text("Ver"),
                                      onTap: () => Navigator.pop(context, "view"),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );

                    if (action == null) return;

                    if (action == "view") {
                      _abrirImagemLocalFullscreen(List<File>.from(selectedImages), index);
                      return;
                    }

                    if (action == "remove") {
                      setModalState(() => selectedImages.removeAt(index));
                      return;
                    }

                    if (action == "crop") {
                      if (_cropping) return;

                      await _waitUiToSettle();

                      final original = selectedImages[index];
                      final cropped = await _cropImageFile(original);
                      if (cropped == null) return;

                      if (!context.mounted) return;
                      setModalState(() => selectedImages[index] = cropped);
                      return;
                    }
                  } finally {
                    await Future.delayed(const Duration(milliseconds: 120));
                    actionLock = false;
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(selectedImages[index], fit: BoxFit.cover),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Material(
                            color: Colors.black.withOpacity(0.25),
                            child: InkWell(
                              onTap: () => setModalState(() {
                                selectedImages.removeAt(index);
                              }),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Icon(Icons.close_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          "${index + 1}/${selectedImages.length}",
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
              );
            },
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final Color formAccent = corSelecionada ?? atosPrimary;

          Future<void> publicar() async {
            if (_posting) return;

            FocusScope.of(context).unfocus();

            final titulo = tituloController.text;
            final texto = textoController.text;

            final hasTitle = titulo.trim().isNotEmpty;
            final hasText = texto.trim().isNotEmpty;
            final hasImages = selectedImages.isNotEmpty;

            if (!hasTitle && !hasText && !hasImages) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: const Text(
                      "Coloque pelo menos uma foto, ou um título, ou uma legenda"),
                  backgroundColor: atosDeep,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
              return;
            }

            final allowed = await _canCurrentUserPost();
            if (!allowed) {
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: const Text("Você não pode postar no momento"),
                  backgroundColor: atosDeep,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
              return;
            }

            // ✅ trava 2: filtro de palavras (título + texto)
            final fullText = "${titulo.trim()} ${texto.trim()}".trim();
            if (_containsBlockedWord(fullText)) {
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: const Text("Seu texto contém palavras que não são permitidas. Mantenha a integridade da comunidade."),
                  backgroundColor: atosDeep,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
              return;
            }

            final tipoFinal =
            (tipoSelecionado == null || tipoSelecionado!.trim().isEmpty)
                ? "Post"
                : tipoSelecionado!.trim();
            final corFinal = corSelecionada ?? atosPrimary;

            final tracejadoFinal = false;

            if (Navigator.canPop(context)) Navigator.pop(context);

            await _postarNoFirebase(
              titulo: titulo,
              texto: texto,
              tipo: tipoFinal,
              cor: corFinal,
              tracejado: tracejadoFinal,
              images: List<File>.from(selectedImages),
            );
          }

          return _GlassSheet(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 14,
                  bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Handle(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: formAccent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: formAccent.withOpacity(0.16)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_note_rounded, size: 16, color: formAccent),
                                const SizedBox(width: 8),
                                Text(
                                  "NOVO POST",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    fontSize: 11,
                                    color: formAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close_rounded, color: Colors.black.withOpacity(0.45)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Tipo (opcional) • toque de novo pra desmarcar",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          tipoCard(setModalState, "Recado", Colors.blue),
                          tipoCard(setModalState, "Aviso", Colors.orange),
                          // tipoCard(setModalState, "Ideia", Colors.green),
                          tipoCard(setModalState, "Importante", atosPrimary, tracejado: true),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _PremiumField(
                        controller: tituloController,
                        label: "Título (opcional)",
                        hint: "Ex: Aviso importante",
                      ),
                      const SizedBox(height: 12),
                      _PremiumField(
                        controller: textoController,
                        label: "Legenda (opcional)",
                        hint: "Escreva sua mensagem...",
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => pickImages(context, setModalState),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_library_rounded, color: formAccent),
                                    const SizedBox(width: 10),
                                    Text(
                                      selectedImages.isEmpty
                                          ? "Adicionar fotos"
                                          : "Adicionar mais (${selectedImages.length})",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: atosDeep,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (selectedImages.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: () => setModalState(() => selectedImages.clear()),
                              icon: Icon(Icons.close_rounded, color: Colors.black.withOpacity(0.5)),
                            ),
                          ],
                        ],
                      ),
                      if (selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        imagesPreview(setModalState),
                      ],
                      const SizedBox(height: 14),
                      _PrimaryCTA(
                        label: _posting ? "PUBLICANDO..." : "PUBLICAR",
                        color: formAccent,
                        onTap: _posting ? () {} : () => publicar(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
