import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;
  final String nickname;
  final String editProfileRouteName;

  final Future<void> Function({
  required User user,
  required String nickname,
  }) onCreateProfile;

  const VerifyEmailPage({
    super.key,
    required this.email,
    required this.nickname,
    required this.editProfileRouteName,
    required this.onCreateProfile,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _timer;
  bool _sending = false;
  bool _creatingProfile = false;
  bool _navigated = false;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _checkVerified());
    _checkVerified();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerified();
    }
  }

  Future<void> _checkVerified() async {
    if (_navigated || _creatingProfile) return;

    final user = _auth.currentUser;
    if (user == null) return;

    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null) return;

    if (refreshed.emailVerified) {
      _timer?.cancel();
      setState(() => _creatingProfile = true);

      try {
        await widget.onCreateProfile(user: refreshed, nickname: widget.nickname);

        _navigated = true;
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, widget.editProfileRouteName);
      } catch (e) {
        if (!mounted) return;
        setState(() => _creatingProfile = false);
        _showSnack("Verificado, mas falhou ao criar perfil: $e");
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnack("Sessão inválida. Faça login novamente");
        return;
      }
      await user.sendEmailVerification();
      _showSnack("E-mail reenviado para ${widget.email}");
    } catch (e) {
      _showSnack("Erro ao reenviar: $e");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _sending || _creatingProfile;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3A0808),
                  Color(0xFF6A0F0F),
                  Color(0xFF8E2A2A),
                ],
              ),
            ),
          ),

          // Bolhas decorativas
          Positioned(
            top: -90,
            left: -60,
            child: _GlowBlob(size: 220, opacity: 0.22),
          ),
          Positioned(
            bottom: -110,
            right: -80,
            child: _GlowBlob(size: 260, opacity: 0.18),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          await _auth.signOut();
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "Verificar e-mail",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Confirme seu e-mail",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Enviamos um link de verificação para:",
                                style: TextStyle(color: Colors.white.withOpacity(.85)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.email,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                "Abra seu e-mail, clique no link e volte para o app"
                                    "Assim que confirmar, seu perfil será criado e você irá para editar seu perfil automaticamente",
                                style: TextStyle(color: Colors.white.withOpacity(.78)),
                              ),
                              const SizedBox(height: 18),

                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.10),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(.18)),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _creatingProfile
                                            ? "Criando seu perfil..."
                                            : "Aguardando verificação...",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              ElevatedButton(
                                onPressed: busy ? null : _resendEmail,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.indigo,
                                ),
                                child: Text(
                                  _sending ? "Enviando..." : "Reenviar e-mail",
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                              ),

                              const SizedBox(height: 10),
                              Text(
                                "Dica: confira também Spam/Lixo eletrônico.",
                                style: TextStyle(color: Colors.white.withOpacity(.65), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(.18)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final double opacity;
  const _GlowBlob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity),
            Colors.white.withOpacity(0),
          ],
        ),
      ),
    );
  }
}
