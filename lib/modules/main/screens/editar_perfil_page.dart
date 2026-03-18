import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditarPerfilPage extends StatefulWidget {
  final String nomeAtual;
  final String nicknameAtual;
  final String bioAtual;

  const EditarPerfilPage({
    super.key,
    required this.nomeAtual,
    required this.nicknameAtual,
    required this.bioAtual,
  });

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomeController;
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _birthController;
  late TextEditingController _emailController;

  DateTime? _birthDate;

  String? _pathPerfil;
  String? _pathCapa;
  bool _estaSalvando = false;

  // ===== Paleta =====
  static const Color vinhoProfundo = Color(0xFF3A0808);
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color vinhoDestaque = Color(0xFF8E2A2A);

  static const Color paper = Color(0xFFFBFAF8);
  static const double kCoverHeight = 200.0;
  static const int kNickMin = 4;
  static const int kNickMax = 20;

  // ====== verificação do nickname ======
  Timer? _nickDebounce;
  bool _checkingNick = false;
  bool? _nickDisponivel;
  String _nickMsg = "";
  bool _nickAutoDone = false;

  @override
  void initState() {
    super.initState();

    _nomeController = TextEditingController(text: widget.nomeAtual);
    _nicknameController = TextEditingController(text: widget.nicknameAtual);
    _bioController = TextEditingController(text: widget.bioAtual);
    _birthController = TextEditingController(text: "");
    _emailController = TextEditingController(text: "");

    _carregarImagensAtuais();
    _carregarEmailAtual();

    _nicknameController.addListener(_onNickChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _nickAutoDone = false;
      await _prepararNickInicial();
      _onNickChanged();
    });
  }

  @override
  void dispose() {
    _nickDebounce?.cancel();
    _nicknameController.removeListener(_onNickChanged);

    _nomeController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    _birthController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _nickValido(String s) => RegExp(r'^[a-z0-9._]+$').hasMatch(s);

  String _normalizarNick(String input) {
    return input.trim().toLowerCase().replaceAll(' ', '');
  }

  bool _isPlaceholderNick(String nick) {
    final n = _normalizarNick(nick);
    return n.isEmpty ||
        n == 'novo_membro' ||
        n == 'membro' ||
        n == 'usuario' ||
        n == 'user';
  }

  String _baseNickFromNomeOuEmail() {
    final nome = _nomeController.text.trim();
    if (nome.isNotEmpty) {
      final first = nome.split(RegExp(r'\s+')).first.trim().toLowerCase();
      final cleaned = first.replaceAll(RegExp(r'[^a-z0-9._]'), '');
      if (cleaned.isNotEmpty) return cleaned;
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.contains('@')) {
      final local = email.split('@').first.toLowerCase();
      final cleaned = local.replaceAll(RegExp(r'[^a-z0-9._]'), '');
      if (cleaned.isNotEmpty) return cleaned;
    }

    return 'membro';
  }

  String _limitNick(String s) {
    if (s.length <= kNickMax) return s;
    return s.substring(0, kNickMax);
  }

  Future<void> _prepararNickInicial() async {
    if (_nickAutoDone) return;
    _nickAutoDone = true;

    final atual = _normalizarNick(_nicknameController.text);

    if (_isPlaceholderNick(atual)) {

    } else {

      if (atual.isNotEmpty &&
          atual.length >= kNickMin &&
          atual.length <= kNickMax &&
          _nickValido(atual) &&
          !atual.startsWith('.') &&
          !atual.endsWith('.') &&
          !atual.startsWith('_') &&
          !atual.endsWith('_')) {
        return;
      }
    }

    String base = _baseNickFromNomeOuEmail();
    base = base.replaceAll(RegExp(r'\.+'), '.').replaceAll(RegExp(r'_+'), '_');
    base = base.replaceAll('.', '');
    base = base.replaceAll('_', '');

    if (base.length < kNickMin) {
      base = (base + 'membro').replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    base = _limitNick(base);

    // garante mínimo 4
    if (base.length < kNickMin) {
      base = (base + '0000').substring(0, kNickMin);
    }

    // se o base já está disponível, usa
    final okBase = await _isNickDisponivel(base);
    if (!mounted) return;

    if (okBase) {
      _nicknameController.text = base;
      _nicknameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _nicknameController.text.length),
      );
      return;
    }

    final rnd = Random();
    for (int i = 0; i < 15; i++) {
      final suffix = (rnd.nextInt(9000) + 1000).toString();
      var candidate = _limitNick('$base$suffix');
      if (candidate.length < kNickMin) continue;

      final ok = await _isNickDisponivel(candidate);
      if (!mounted) return;

      if (ok) {
        _nicknameController.text = candidate;
        _nicknameController.selection = TextSelection.fromPosition(
          TextPosition(offset: _nicknameController.text.length),
        );
        return;
      }
    }

    _nicknameController.text = base;
    _nicknameController.selection = TextSelection.fromPosition(
      TextPosition(offset: _nicknameController.text.length),
    );
  }

  String? _validarNickname(String? value) {
    final v = _normalizarNick(value ?? '');
    if (v.isEmpty) return "Escolha um @ (nickname)";
    if (v.length < kNickMin) return "Nickname inválido";
    if (!_nickValido(v)) return "Nickname inválido";
    if (v.startsWith('.') || v.endsWith('.')) return "Nickname inválido";
    if (v.startsWith('_') || v.endsWith('_')) return "Nickname inválido";
    return null;
  }

  void _onNickChanged() {
    _nickDebounce?.cancel();
    _nickDebounce = Timer(const Duration(milliseconds: 380), () async {
      final v = _normalizarNick(_nicknameController.text);

      if (v.isEmpty) {
        if (!mounted) return;
        setState(() {
          _checkingNick = false;
          _nickDisponivel = null;
          _nickMsg = "";
        });
        return;
      }

      if (v.length < kNickMin) {
        if (!mounted) return;
        setState(() {
          _checkingNick = false;
          _nickDisponivel = false;
          _nickMsg = "";
        });
        return;
      }

      if (!_nickValido(v) ||
          v.startsWith('.') ||
          v.endsWith('.') ||
          v.startsWith('_') ||
          v.endsWith('_')) {
        if (!mounted) return;
        setState(() {
          _checkingNick = false;
          _nickDisponivel = false;
          _nickMsg = "";
        });
        return;
      }

      // se é o atual, sempre ok
      if (v == _normalizarNick(widget.nicknameAtual)) {
        if (!mounted) return;
        setState(() {
          _checkingNick = false;
          _nickDisponivel = true;
          _nickMsg = "";
        });
        return;
      }

      await _checarDisponibilidadeNick(v);
    });
  }

  Future<bool> _isNickDisponivel(String nick) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final qs = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nick)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return true;
    return qs.docs.first.id == user.uid;
  }

  Future<void> _checarDisponibilidadeNick(String nick) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!mounted) return;
    setState(() {
      _checkingNick = true;
      _nickDisponivel = null;
      _nickMsg = "";
    });

    try {
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nick)
          .limit(1)
          .get();

      bool existe = false;

      if (qs.docs.isNotEmpty) {
        final doc = qs.docs.first;
        existe = doc.id != user.uid;
      }

      if (!mounted) return;
      setState(() {
        _checkingNick = false;
        _nickDisponivel = !existe;
        _nickMsg = existe ? "já existente" : "";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingNick = false;
        _nickDisponivel = null;
        _nickMsg = "";
      });
    }
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return "$dd/$mm/$yyyy";
  }

  Future<void> _carregarEmailAtual() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final authEmail = (user.email ?? "").trim();
    if (authEmail.isNotEmpty) {
      if (mounted) setState(() => _emailController.text = authEmail);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      final fsEmail = (data?['email'] ?? "").toString().trim();
      if (fsEmail.isNotEmpty && mounted) {
        setState(() => _emailController.text = fsEmail);
      }
    } catch (_) {}
  }

  Future<void> _carregarImagensAtuais() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    // 1) cache local
    final localPerfil = prefs.getString('user_path_perfil');
    final localCapa = prefs.getString('user_path_capa');

    final birthIso = prefs.getString('user_birthdate'); // ISO8601
    DateTime? cachedBirth;
    if (birthIso != null && birthIso.trim().isNotEmpty) {
      try {
        cachedBirth = DateTime.parse(birthIso);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _pathPerfil = localPerfil;
        _pathCapa = localCapa;
        if (cachedBirth != null) {
          _birthDate = cachedBirth;
          _birthController.text = _fmtDate(cachedBirth);
        }
      });
    }

    if (user != null) {
      try {
        final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data != null) {
          final photoUrl = (data['photoUrl'] ?? "") as String;
          final coverUrl = (data['coverUrl'] ?? "") as String;

          final nome = (data['nome'] ?? "") as String;
          final nick = (data['nickname'] ?? "") as String;
          final bio = (data['bio'] ?? "") as String;

          DateTime? birth;
          final bd = data['birthDate'];
          if (bd is Timestamp) birth = bd.toDate();
          if (bd is String && bd.trim().isNotEmpty) {
            try {
              birth = DateTime.parse(bd);
            } catch (_) {}
          }

          if (mounted) {
            setState(() {
              if (photoUrl.isNotEmpty) _pathPerfil = photoUrl;
              if (coverUrl.isNotEmpty) _pathCapa = coverUrl;

              if (nome.trim().isNotEmpty) _nomeController.text = nome.trim();
              if (nick.trim().isNotEmpty) _nicknameController.text = nick.trim();
              if (bio.trim().isNotEmpty) _bioController.text = bio.trim();

              if (birth != null) {
                _birthDate = birth;
                _birthController.text = _fmtDate(birth);
              }
            });
          }

          final currentNick = _normalizarNick(_nicknameController.text);
          if (_isPlaceholderNick(currentNick)) {
            _nickAutoDone = false;
            await _prepararNickInicial();
            _onNickChanged();
          }
        }
      } catch (_) {}
    }
  }

  ImageProvider? _resolveImage(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
    if (pathOrUrl.startsWith('http')) return NetworkImage(pathOrUrl);
    return FileImage(File(pathOrUrl));
  }

  // ====== PICK + CROP (CAPA fixo, PERFIL 1:1) ======
  Future<void> _pickAndCrop({required bool isCapa}) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2000,
    );

    if (image == null || !mounted) return;

    final double screenW = MediaQuery.of(context).size.width;

    final CropAspectRatio ratio = isCapa
        ? CropAspectRatio(ratioX: screenW, ratioY: kCoverHeight)
        : const CropAspectRatio(ratioX: 1, ratioY: 1);

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: isCapa ? 88 : 92,
        aspectRatio: ratio,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isCapa ? "Editar capa" : "Cortar foto",
            toolbarColor: vinhoProfundo,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: vinhoIdentidade,
            lockAspectRatio: true,
            hideBottomControls: true,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: isCapa ? "Editar capa" : "Cortar foto",
            aspectRatioLockEnabled: true,
            rotateButtonsHidden: true,
            resetButtonHidden: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (cropped == null || !mounted) return;

      setState(() {
        if (isCapa) {
          _pathCapa = cropped.path;
        } else {
          _pathPerfil = cropped.path;
        }
      });
    } catch (_) {}
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: "Selecione sua data de nascimento",
      cancelText: "Cancelar",
      confirmText: "OK",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: vinhoIdentidade,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _birthDate = picked;
      _birthController.text = _fmtDate(picked);
    });
  }

  Future<String> _uploadSeLocal({
    required String? pathOrUrl,
    required String storagePath,
  }) async {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return "";
    if (pathOrUrl.startsWith('http')) return pathOrUrl;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    final file = File(pathOrUrl);

    final ref = FirebaseStorage.instance.ref('$storagePath/${user.uid}.jpg');
    final snapshot = await ref.putFile(
      file,
      SettableMetadata(contentType: "image/jpeg"),
    );
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _salvarDados() async {
    if (_estaSalvando) return;

    FocusScope.of(context).unfocus();

    if (_checkingNick) return;
    if (_nickDisponivel != true) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _estaSalvando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final nome = _nomeController.text.trim();
      final nick = _normalizarNick(_nicknameController.text);

      final urlPerfil = await _uploadSeLocal(
        pathOrUrl: _pathPerfil,
        storagePath: 'perfis',
      );

      final urlCapa = await _uploadSeLocal(
        pathOrUrl: _pathCapa,
        storagePath: 'capas',
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'nome': nome,
        'nickname': nick,
        'bio': _bioController.text.trim(),
        'photoUrl': urlPerfil,
        'coverUrl': urlCapa,
        if (_birthDate != null) 'birthDate': Timestamp.fromDate(_birthDate!),
        'uid': user.uid,
        'email': (user.email ?? '').trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_nome', nome);
      await prefs.setString('user_nickname', nick);
      await prefs.setString('user_bio', _bioController.text.trim());
      if (_birthDate != null) {
        await prefs.setString('user_birthdate', _birthDate!.toIso8601String());
      }
      if (urlPerfil.isNotEmpty) await prefs.setString('user_path_perfil', urlPerfil);
      if (urlCapa.isNotEmpty) await prefs.setString('user_path_capa', urlCapa);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Informações salvas!"),
          backgroundColor: vinhoIdentidade,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao salvar: $e"),
          backgroundColor: vinhoProfundo,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } finally {
      if (mounted) setState(() => _estaSalvando = false);
    }
  }

  Widget? _nickSuffix() {
    final v = _normalizarNick(_nicknameController.text);

    if (_checkingNick) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.black.withOpacity(0.35),
          ),
        ),
      );
    }

    if (v.isNotEmpty && v.length < kNickMin) {
      return const Icon(Icons.cancel_rounded, size: 18, color: Colors.red);
    }

    if (_nickDisponivel == true) {
      return const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green);
    }

    if (_nickDisponivel == false) {
      return const Icon(Icons.cancel_rounded, size: 18, color: Colors.red);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final perfilImg = _resolveImage(_pathPerfil);
    final capaImg = _resolveImage(_pathCapa);

    final showNickMsg = _nickMsg.isNotEmpty && _nickDisponivel == false;

    return Scaffold(
      backgroundColor: paper,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Container(
                  height: kCoverHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: vinhoProfundo,
                    image: capaImg != null
                        ? DecorationImage(image: capaImg, fit: BoxFit.cover)
                        : null,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.10),
                          Colors.black.withOpacity(0.35),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 18,
                  bottom: 12,
                  child: _GlassPill(
                    icon: Icons.edit_rounded,
                    text: "Editar capa",
                    onTap: () => _pickAndCrop(isCapa: true),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _pickAndCrop(isCapa: false),
                    child: Container(
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
                        backgroundImage: perfilImg,
                        child: perfilImg == null
                            ? const Icon(Icons.camera_alt_rounded,
                            color: vinhoIdentidade, size: 24)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Editar Perfil",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            color: vinhoProfundo,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Toque na foto para editar",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _PremiumField(
                      label: "Nome",
                      hint: "Ex: João Silva",
                      controller: _nomeController,
                      validator: (v) {
                        final s = (v ?? "").trim();
                        if (s.isEmpty) return "Digite seu nome";
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _PremiumReadOnlyField(
                      label: "E-mail",
                      controller: _emailController,
                      hint: "—",
                      suffix: Icon(
                        Icons.lock_rounded,
                        color: Colors.black.withOpacity(0.35),
                        size: 18,
                      ),
                    ),

                    const SizedBox(height: 14),
                    _PremiumField(
                      label: "Nickname",
                      prefix: "@",
                      hint: "ex: joao.silva_29",
                      controller: _nicknameController,
                      validator: _validarNickname,
                      suffix: _nickSuffix(),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(kNickMax),
                        FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9._]')),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return newValue.copyWith(text: newValue.text.toLowerCase());
                        }),
                      ],
                    ),
                    if (showNickMsg) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _nickMsg,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _PremiumDateField(
                      label: "Data de nascimento",
                      controller: _birthController,
                      hint: "dd/mm/aaaa",
                      onTap: _pickBirthDate,
                    ),
                    const SizedBox(height: 14),
                    _PremiumField(
                      label: "Bio",
                      hint: "Escreva algo sobre sua caminhada...",
                      controller: _bioController,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 18),
                    _PrimaryCTA(
                      label: _estaSalvando ? "SALVANDO..." : "SALVAR",
                      loading: _estaSalvando,
                      onTap: _salvarDados,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Widgets premium =====

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withOpacity(0.14),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: Colors.white.withOpacity(0.95)),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      fontSize: 12,
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

class _PremiumField extends StatelessWidget {
  const _PremiumField({
    required this.label,
    required this.controller,
    this.prefix,
    this.hint,
    this.maxLines = 1,
    this.validator,
    this.inputFormatters,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String? prefix;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        inputFormatters: inputFormatters,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.black.withOpacity(0.82),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          suffixIcon: suffix,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.55),
          ),
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.35)),
          border: InputBorder.none,
        ),
        cursorColor: vinhoIdentidade,
        selectionControls: materialTextSelectionControls,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }
}

class _PremiumReadOnlyField extends StatelessWidget {
  const _PremiumReadOnlyField({
    required this.label,
    required this.controller,
    this.hint,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: TextFormField(
        controller: controller,
        readOnly: true,
        enabled: true,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.black.withOpacity(0.62),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.55),
          ),
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.35)),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _PremiumDateField extends StatelessWidget {
  const _PremiumDateField({
    required this.label,
    required this.controller,
    required this.onTap,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: IgnorePointer(
            child: TextFormField(
              controller: controller,
              readOnly: true,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black.withOpacity(0.82),
              ),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: InputBorder.none,
                suffixIcon: Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.black.withOpacity(0.45),
                ),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withOpacity(0.55),
                ),
                hintStyle: TextStyle(color: Colors.black.withOpacity(0.35)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryCTA extends StatelessWidget {
  const _PrimaryCTA({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;

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
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Text(
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
