import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';
import 'legal_page.dart';

const atosPrimary = Color(0xFF6A0F0F);
const atosBg = Color(0xFFFAF9F7);

const String _kSupportEmail = "atos29.app@gmail.com";

class SobreAppPage extends StatefulWidget {
  const SobreAppPage({super.key});

  @override
  State<SobreAppPage> createState() => _SobreAppPageState();
}

class _SobreAppPageState extends State<SobreAppPage> {
  String _version = "";
  String _build = "";

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = info.version.trim();
      _build = info.buildNumber.trim();
    });
  }

  void _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copiado!")),
    );
  }

  Future<void> _abrirEmailSuporte(BuildContext context) async {
    final uri = Uri(
      scheme: "mailto",
      path: _kSupportEmail,
      queryParameters: {"subject": "Suporte • Atos 29"},
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível abrir o app de e-mail")),
      );
    }
  }

  Future<void> _copiarEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _kSupportEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("E-mail de suporte copiado!")),
      );
    }
  }

  void _abrirSuporteAjuda(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.support_agent_rounded,
                      size: 30,
                      color: atosPrimary.withOpacity(0.95),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Suporte / Ajuda",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.black.withOpacity(0.84),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _kSupportEmail,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: "Fechar",
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.black.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: atosPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _abrirEmailSuporte(context);
                        },
                        icon: const Icon(Icons.email_rounded, color: Colors.white),
                        label: const Text(
                          "Enviar e-mail",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: Colors.black.withOpacity(0.12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _copiarEmail(context);
                        },
                        icon: Icon(
                          Icons.copy_rounded,
                          color: Colors.black.withOpacity(0.70),
                        ),
                        label: Text(
                          "Copiar e-mail",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.78),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Se preferir, mande um print do problema e descreva o que aconteceu.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Colors.black.withOpacity(0.48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            Icon(icon, color: atosPrimary, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      color: Colors.black.withOpacity(0.82),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: Colors.black.withOpacity(0.48),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing,
            ] else ...[
              Icon(Icons.chevron_right_rounded,
                  color: Colors.black.withOpacity(0.35)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          height: 1.35,
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: Colors.black.withOpacity(0.68),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasInfo = _version.isNotEmpty && _build.isNotEmpty;
    final vText = hasInfo ? "v$_version (build $_build)" : "";

    return Scaffold(
      backgroundColor: atosBg,
      appBar: AppBar(
        backgroundColor: atosBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Sobre o App",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.85),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ATOS 29",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.black.withOpacity(0.85),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "O que é o Atos 29 App?",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.black.withOpacity(0.82),
                  ),
                ),
                const SizedBox(height: 12),

                _paragraph(
                  "O livro dos Atos dos Apóstolos narra a ação da Igreja nascente, os passos dos primeiros cristãos e o testemunho dos apóstolos, guiados pelo Espírito Santo, anunciando o Evangelho em meio aos desafios do seu tempo.",
                ),
                _paragraph(
                  "A Sagrada Escritura relata essa história até o capítulo 28. O Atos 29 representa a continuidade dessa missão: a Igreja viva hoje, chamada a dar seguimento à obra iniciada por Cristo e a viver, no tempo presente, o discipulado cristão.",
                ),
                _paragraph(
                  "Viver o Atos 29 é assumir a missão da Igreja hoje, utilizando também as ferramentas da atualidade para evangelizar, formar e reunir. Inspirados pelo ardor missionário de São João Paulo II e pelo testemunho de Carlo Acutis, que viu a tecnologia como um dom de Deus a serviço do Evangelho, somos chamados a anunciar Cristo também nos ambientes digitais.",
                ),
                _paragraph(
                  "Escrever Atos 29 é uma grande responsabilidade. Significa voltar ao primeiro amor, viver e experimentar aquilo que os primeiros discípulos viveram, anunciar a Palavra com fidelidade, rezar com profundidade e seguir a Cristo com coragem e confiança em Deus.",
                ),
                _paragraph(
                  "A verdadeira transformação em nossas vidas acontece quando nos entregamos plenamente ao Espírito Santo, vivendo um Pentecostes diário e anunciando o Evangelho com atitudes, testemunho e amor concreto.",
                ),
                _paragraph(
                  "Nesse caminho, o App Atos 29 nasce como uma iniciativa para elevar espiritualmente a caminhada pessoal de cada pessoa, promovendo oração, convivência e missão, apoiando a vivência da fé no dia a dia.",
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          _tile(
            icon: Icons.privacy_tip_rounded,
            title: "Política de privacidade",
            subtitle: "Como seus dados são tratados",
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
          ),
          const SizedBox(height: 12),

          _tile(
            icon: Icons.description_rounded,
            title: "Termos de uso",
            subtitle: "Regras e condições do aplicativo",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalPage(
                    title: "Termos de Uso",
                    assetPath: "assets/legal/termos.txt",
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          _tile(
            icon: Icons.support_agent_rounded,
            title: "Suporte",
            subtitle: _kSupportEmail,
            onTap: () => _abrirSuporteAjuda(context),
          ),

          const SizedBox(height: 22),

          Center(
            child: Text(
              "Desenvolvido por Atos 29",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black.withOpacity(0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
