import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:atos29/modules/main/screens/register_page.dart';
import 'forgot_password_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> subscribeTopicsAfterLogin() async {
  await FirebaseMessaging.instance.subscribeToTopic('all');
  // se tiver admin:
  await FirebaseMessaging.instance.subscribeToTopic('admins');
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _bgWine = Color.fromRGBO(78, 4, 5, 1);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _loading = false;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _ensureUserDoc(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'role': 'user',
        'verified': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  void _log(Object? msg) {
    // ignore: avoid_print
    debugPrint("LOGIN: $msg");
  }

  Future<void> _mostrarEsqueciSenhaDialog() async {
    final emailInicial = _emailController.text.trim();
    final controller = TextEditingController(text: emailInicial);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Esqueci a senha"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: "Digite seu e-mail",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = controller.text.trim();
                if (email.isEmpty) {
                  _showSnack("Digite seu e-mail");
                  return;
                }

                try {
                  await _auth.sendPasswordResetEmail(email: email);
                  if (mounted) Navigator.pop(ctx);
                  _showSnack("Enviamos um link de redefinição para $email");
                } on FirebaseAuthException catch (e) {
                  String msg = "Não foi possível enviar o link";

                  if (e.code == 'invalid-email') {
                    msg = "E-mail inválido";
                  } else if (e.code == 'user-not-found') {
                    msg = "Não existe conta com esse e-mail";
                  } else if (e.code == 'too-many-requests') {
                    msg = "Muitas tentativas. Tente mais tarde";
                  }

                  _log("RESET ERROR: ${e.code} ${e.message}");
                  _showSnack(msg);
                } catch (e) {
                  _log("RESET ERROR: $e");
                  _showSnack("Erro ao enviar link: $e");
                }
              },
              child: const Text("Enviar link"),
            ),
          ],
        );
      },
    );
  }

  // ---------------- LOGIN COM E-MAIL ----------------
  Future<void> _entrarComEmail() async {
    if (_loading) return;

    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showSnack("Preencha e-mail e senha");
      return;
    }

    setState(() => _loading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        await _ensureUserDoc(u);
        await subscribeTopicsAfterLogin();
      }

    } on FirebaseAuthException catch (e) {
      _log("EMAIL LOGIN ERROR: ${e.code} ${e.message}");

      String msg = "Erro ao entrar";

      if (e.code == 'user-not-found') {
        msg = "Usuário não encontrado";
      } else if (e.code == 'wrong-password') {
        msg = "Senha incorreta";
      } else if (e.code == 'invalid-email') {
        msg = "E-mail inválido";
      } else if (e.code == 'user-disabled') {
        msg = "Usuário desativado";
      } else if (e.code == 'too-many-requests') {
        msg = "Muitas tentativas. Tente mais tarde.";
      } else if (e.code == 'network-request-failed') {
        msg = "Sem conexão. Verifique sua internet.";
      } else if (e.code == 'invalid-credential') {
        msg = "Credenciais inválidas. Confira e-mail e senha.";
      }

      _showSnack(msg);
    } catch (e) {
      _log("EMAIL LOGIN ERROR (generic): $e");
      _showSnack("Erro ao entrar: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _irParaCadastro() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  // ---------------- LOGIN COM GOOGLE ----------------
  Future<void> _entrarComGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _showSnack("Login cancelado");
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);

      final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        try {
          await userCred.user?.delete();
        } catch (e) {
          _log("DELETE NEW USER ERROR: $e");
        }

        await _googleSignIn.signOut();
        await _auth.signOut();

        if (!mounted) return;
        _showSnack("Essa conta Google ainda não tem cadastro. Crie uma conta primeiro.");

        _irParaCadastro();
        return;
      }

      final u = userCred.user;
      if (u != null) {
        await _ensureUserDoc(u);
        await subscribeTopicsAfterLogin();
      }

    } on FirebaseAuthException catch (e) {
      _log("GOOGLE FIREBASE ERROR: ${e.code} ${e.message}");
      _showSnack("Erro Firebase (Google): ${e.code}");
    } catch (e) {
      _log("GOOGLE LOGIN ERROR: $e");
      _showSnack("Erro ao entrar com Google: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    final u = FirebaseAuth.instance.currentUser;
    debugPrint("AUTH currentUser: ${u?.uid}  email=${u?.email}");

  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                  constraints: const BoxConstraints(maxWidth: 420),
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

                      // E-mail
                      _Input(
                        controller: _emailController,
                        hint: "E-mail",
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),

                      // Senha
                      _Input(
                        controller: _passwordController,
                        hint: "Senha",
                        icon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      const SizedBox(height: 14),

                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        // Entrar
                        ElevatedButton(
                          onPressed: _entrarComEmail,
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
                            "Entrar",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        OutlinedButton(
                          onPressed: _entrarComGoogle,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: Colors.white.withOpacity(.35),
                            ),
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
                                "Entrar com Google",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordPage(
                                      initialEmail: _emailController.text.trim(),
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                "Esqueci a senha",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.92),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _irParaCadastro,
                              child: Text(
                                "Criar conta",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.92),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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
                    color: Colors.white.withOpacity(0.35),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                    fontSize: 12,
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

  const _Input({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(.55)),
        filled: true,
        fillColor: Colors.white.withOpacity(.10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(.35)),
        ),
      ),
    );
  }
}
