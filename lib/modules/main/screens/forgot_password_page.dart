import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordPage({super.key, this.initialEmail});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const Color _bgWine = Color.fromRGBO(78, 4, 5, 1);

  final _emailController = TextEditingController();
  bool _loading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _emailController.text = (widget.initialEmail ?? '').trim();
  }

  void _showSnack(String message, {Duration duration = const Duration(seconds: 6)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  void _showCheckSpamSnack({required String extra}) {
    _showSnack(
      "$extra\n"
          "Caso não encontre, verifique a caixa de Spam ou Promoções",
    );
  }

  Future<void> _sendReset() async {
    if (_loading) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack("Digite seu e-mail");
      return;
    }

    setState(() => _loading = true);

    try {
      await _auth.sendPasswordResetEmail(email: email);

      _showCheckSpamSnack(
        extra: "Enviamos um link de redefinição para $email.",
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.pop(context); // volta pro login
    } on FirebaseAuthException catch (e) {
      String msg = "Não foi possível enviar o link";

      if (e.code == 'invalid-email') {
        msg = "E-mail inválido";
      } else if (e.code == 'user-not-found') {
        msg = "Não existe conta com esse e-mail";
      } else if (e.code == 'too-many-requests') {
        msg = "Muitas tentativas. Tente mais tarde";
      }

      _showSnack(msg);
    } catch (e) {
      _showSnack("Erro ao enviar link: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgWine,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Esqueci a senha",
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Digite o e-mail da sua conta. Vamos enviar um link para você redefinir sua senha",
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Se não encontrar o e-mail, verifique a caixa de Spam ou Promoções",
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // campo e-mail
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.mail_outline, color: Colors.white70),
                          hintText: "Seu e-mail",
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
                      ),
                      const SizedBox(height: 14),

                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        ElevatedButton(
                          onPressed: _sendReset,
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
                            "Enviar link",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(color: Colors.white.withOpacity(.35)),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            "Voltar",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // seta fixa no topo
            Positioned(
              top: 6,
              left: 6,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                iconSize: 18,
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
