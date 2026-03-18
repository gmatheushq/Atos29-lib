import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'legal_page.dart';

// ✅ tela de verificação
import 'verify_email_page.dart';

// ✅ serviço que cria perfil só depois da verificação
import '../services/user_profile_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const Color _bgWine = Color.fromRGBO(78, 4, 5, 1);

  // ⚖️ versões (pra você poder atualizar termos no futuro)
  static const String _termsVersion = '1.0';
  static const String _privacyVersion = '1.0';

  final _formKey = GlobalKey<FormState>();
  bool _autovalidate = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _birthDateController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _loading = false;
  bool _obscure = true;

  DateTime? _birthDate;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  void _showCheckSpamSnack({String? extra}) {
    final msg = (extra == null || extra.trim().isEmpty)
        ? "Enviamos um e-mail para você\n"
        "Caso não encontre, verifique a caixa de Spam ou Promoções"
        : "$extra\n"
        "Caso não encontre, verifique a caixa de Spam ou Promoções";

    _showSnack(msg);
  }


  String? _validateName(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return "Informe seu nome";
    if (v.length < 2) return "Nome muito curto";
    return null;
  }

  String? _validateEmail(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return "Informe seu e-mail";
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
    if (!ok) return "E-mail inválido";
    return null;
  }

  String? _validatePassword(String? raw) {
    final v = (raw ?? '');
    if (v.trim().isEmpty) return "Informe uma senha";
    if (v.length < 6) return "A senha deve ter pelo menos 6 caracteres";
    return null;
  }

  DateTime? _parseBirthDateFromRaw(String raw) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw.trim());
    if (m == null) return null;

    final dd = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    final yyyy = int.parse(m.group(3)!);

    if (yyyy < 1900) return null;
    if (mm < 1 || mm > 12) return null;
    if (dd < 1 || dd > 31) return null;

    final d = DateTime(yyyy, mm, dd);
    final isSame = d.year == yyyy && d.month == mm && d.day == dd;
    if (!isSame) return null;

    final now = DateTime.now();
    if (d.isAfter(DateTime(now.year, now.month, now.day))) return null;

    return d;
  }

  DateTime? _parseBirthDate() {
    return _parseBirthDateFromRaw(_birthDateController.text);
  }

  String? _validateBirthDate(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return "Informe sua data de nascimento";
    final d = _parseBirthDateFromRaw(v);
    if (d == null) return "Use o formato dd/mm/aaaa";
    return null;
  }

  // ---------------- NICKNAME AUTO (ÚNICO) ----------------

  String _normalizeBase(String input) {
    final lower = input.toLowerCase().trim();

    final replaced = lower
        .replaceAll(RegExp(r'[áàâã]'), 'a')
        .replaceAll(RegExp(r'[éèê]'), 'e')
        .replaceAll(RegExp(r'[íìî]'), 'i')
        .replaceAll(RegExp(r'[óòôõ]'), 'o')
        .replaceAll(RegExp(r'[úùû]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c');

    final only = replaced.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (only.isEmpty) return 'membro';
    return only;
  }

  Future<bool> _nicknameExists(String nickname) async {
    final snap = await _firestore
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<String> _generateAvailableNickname(String baseName) async {
    final base = _normalizeBase(baseName);

    if (!await _nicknameExists(base)) return base;

    for (int i = 2; i < 2000; i++) {
      final candidate = '$base$i';
      if (!await _nicknameExists(candidate)) return candidate;
    }

    return '$base${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _upsertUserDoc({
    required User user,
    required String nickname,
    required String email,
    required String name,
    DateTime? birthDate,
  }) async {
    final ref = _firestore.collection('users').doc(user.uid);

    final data = <String, dynamic>{
      'uid': user.uid,
      'email': email,
      'name': name,
      'nickname': nickname,
      'emailVerified': user.emailVerified,
      'termsAccepted': true,
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'termsVersion': _termsVersion,
      'privacyVersion': _privacyVersion,
      'role': 'user',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (birthDate != null) {
      data['birthDate'] = Timestamp.fromDate(birthDate);
    }

    await ref.set(data, SetOptions(merge: true));
  }

  Future<String> _ensureNickname(User user, String baseName) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final nick = (data['nickname'] ?? '').toString().trim();
      if (nick.isNotEmpty) return nick;
    }

    return _generateAvailableNickname(baseName);
  }

  // ---------------- CADASTRO EMAIL/SENHA ----------------

  Future<void> _criarContaComEmail() async {
    if (_loading) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() => _autovalidate = true);
      return;
    }

    setState(() {
      _loading = true;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final birth = _parseBirthDate();

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw Exception("Usuário nulo após createUserWithEmailAndPassword");
      }

      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
      }

      final nickname = await _generateAvailableNickname(
        name.isNotEmpty ? name : (user.displayName ?? 'membro'),
      );

      await _upsertUserDoc(
        user: user,
        nickname: nickname,
        email: email,
        birthDate: birth!,
        name: name,
      );

      await user.sendEmailVerification();

      if (!mounted) return;

      _showCheckSpamSnack(extra: "Enviamos um e-mail de confirmação");

      await Future.delayed(const Duration(milliseconds: 450));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(
            email: email,
            nickname: nickname,
            editProfileRouteName: '/editProfile',
            onCreateProfile: ({required User user, required String nickname}) async {
              await UserProfileService.ensureProfileCreated(
                user: user,
                nickname: nickname,
              );
            },
          ),
        ),
      );

    } on FirebaseAuthException catch (e) {
      String msg = "Não foi possível criar a conta";

      if (e.code == 'email-already-in-use') {
        msg = "Esse e-mail já está em uso";
      } else if (e.code == 'invalid-email') {
        msg = "E-mail inválido";
      } else if (e.code == 'weak-password') {
        msg = "Senha fraca. Use uma senha mais forte.";
      } else if (e.code == 'network-request-failed') {
        msg = "Sem conexão. Verifique sua internet.";
      }

      _showSnack(msg);
    } catch (e) {
      _showSnack("Erro ao criar conta: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- CADASTRO/LOGIN COM GOOGLE ----------------

  Future<void> _continuarComGoogle() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) throw Exception("Usuário nulo após Google sign in");

      final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;

      final name = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (user.displayName ?? '').trim();

      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
      }

      final birth = _parseBirthDate();

      final baseForNick = name.isNotEmpty ? name : (user.displayName ?? 'membro');
      final nickname = await _ensureNickname(user, baseForNick);

      await _upsertUserDoc(
        user: user,
        nickname: nickname,
        email: user.email ?? _emailController.text.trim(),
        name: name.isNotEmpty ? name : 'Membro',
        birthDate: birth,
      );

      await user.reload();
      if (!mounted) return;

      if (isNewUser) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/editProfile',
              (route) => false,
        );
        return;
      }

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = "Erro ao continuar com Google";
      if (e.code == 'account-exists-with-different-credential') {
        msg = "Esse e-mail já está cadastrado com outro método de login.";
      } else if (e.code == 'network-request-failed') {
        msg = "Sem conexão. Verifique sua internet.";
      }
      _showSnack(msg);
    } catch (e) {
      _showSnack("Erro ao continuar com Google: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(1900, 1, 1);
    final last = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Selecione sua data de nascimento',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _bgWine,
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
      _birthDateController.text =
      "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const footerHeight = 44.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _bgWine,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  14,
                  22,
                  18 + bottomInset + footerHeight,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autovalidate
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 22),
                            child: Image.asset(
                              "assets/images/logo_atos29_branco.png",
                              width: 150,
                              height: 150,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        _Input(
                          controller: _nameController,
                          hint: "Nome",
                          icon: Icons.person_outline,
                          keyboardType: TextInputType.name,
                          validator: _validateName,
                        ),
                        const SizedBox(height: 12),

                        _Input(
                          controller: _emailController,
                          hint: "E-mail",
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 12),

                        _Input(
                          controller: _passwordController,
                          hint: "Senha",
                          icon: Icons.lock_outline,
                          obscureText: _obscure,
                          validator: _validatePassword,
                          suffix: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _Input(
                          controller: _birthDateController,
                          hint: "Data de nascimento (dd/mm/aaaa)",
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.datetime,
                          validator: _validateBirthDate,
                          suffix: IconButton(
                            onPressed: _selectBirthDate,
                            icon: const Icon(Icons.calendar_today, color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 14),

                        const SizedBox(height: 10),

                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          ElevatedButton(
                            onPressed: _criarContaComEmail,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.white,
                              foregroundColor: _bgWine,
                              elevation: 0,
                            ),
                            child: const Text(
                              "Criar conta",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          OutlinedButton(
                            onPressed: _continuarComGoogle,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(color: Colors.white.withOpacity(.35)),
                              foregroundColor: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  "assets/images/google_logo.png",
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "Continuar com Google",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                runAlignment: WrapAlignment.center,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    "Ao criar conta você concorda com os nossos ",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.72),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LegalPage(
                                            title: "Termos de Serviço",
                                            assetPath: "assets/legal/termos.txt",
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      "Termos de serviço",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        decoration: TextDecoration.underline,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    " e ",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.72),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LegalPage(
                                            title: "Política de Privacidade",
                                            assetPath: "assets/legal/privacidade.txt",
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      "Política de privacidade",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        decoration: TextDecoration.underline,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    ".",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "Já possuo uma conta",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: IgnorePointer(
                child: Text(
                  "ATOS 29",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
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

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _Input({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      inputFormatters: hint.toLowerCase().contains('data de nascimento')
          ? [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
        LengthLimitingTextInputFormatter(10),
      ]
          : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffix,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(.55)),
        filled: true,
        fillColor: Colors.white.withOpacity(.10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.20)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.45)),
        ),
        errorStyle: TextStyle(
          color: Colors.white.withOpacity(0.90),
          fontWeight: FontWeight.w700,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.45)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.60)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
