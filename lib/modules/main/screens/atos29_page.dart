import 'dart:ui';
import 'package:flutter/material.dart';

const atosPrimary = Color(0xFF6A0F0F);
const atosDeep = Color(0xFF3A0808);
const atosAccent = Color(0xFF8E2A2A);

class Atos29Page extends StatelessWidget {
  const Atos29Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: atosDeep,
      body: Stack(
        children: [
          const _WineBackgroundClean(),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: false,
                  floating: false,
                  toolbarHeight: 180,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  centerTitle: true,
                  title: Image.asset(
                    "assets/images/logo_atos29_branco.png",
                    height: 200, // ✅ agora 100
                    fit: BoxFit.contain,
                  ),

                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TÍTULO
                        // Text(
                        //   "ATOS 29",
                        //   style: TextStyle(
                        //     fontWeight: FontWeight.w700, // 👈 menos grossa
                        //     fontSize: 26,               // 👈 maior
                        //     letterSpacing: 1.4,
                        //     color: Colors.white.withOpacity(0.95),
                        //   ),
                        // ),
                        const SizedBox(height: 16),

                        //TÍTULO
                        Text(
                          "CONTINUANDO O LEGADO…",
                          style: TextStyle(
                            fontWeight: FontWeight.w700, // 👈 menos grossa
                            fontSize: 19,              // 👈 maior
                            letterSpacing: 1.4,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                        // Text(
                        //   "CONTINUANDO O LEGADO…",
                        //   style: TextStyle(
                        //     fontWeight: FontWeight.w700,
                        //     fontSize: 19, // 👈 agora claramente maior
                        //     letterSpacing: 1.1,
                        //     color: Colors.white.withOpacity(0.86), // 👈 intermediária
                        //   ),
                        // ),

                        const SizedBox(height: 26),



                        _paragraph(
                          "Atos narra a ação da Igreja nascente, os passos dos primeiros cristãos e como os apóstolos e seus sucessores vivenciavam inúmeras situações",
                        ),

                        _paragraph(
                          "A Sagrada Escritura relata Atos dos Apóstolos até o capítulo 28. Assim, Atos 29 corresponde à continuação da Igreja instituída por Cristo e à conduta de sermos discípulos de hoje, dando continuidade à história e à missão",
                        ),

                        _paragraph(
                          "Escrever Atos 29 é uma enorme responsabilidade. Devemos voltar ao primeiro amor, viver e experimentar aquilo que os discípulos experimentavam, levar a Palavra como eles levavam, rezar como rezavam, seguir a Cristo como seguiam, ter a coragem e autoridade como tinham",
                        ),

                        _paragraph(
                          "A mudança genuína em nossas vidas só vai ocorrer se nos entregarmos de fato ao Espírito Santo, viver Pentecostes diariamente e assim anunciar o Evangelho com intrepidez",
                        ),

                        const SizedBox(height: 32),

                        Center(
                          child: Text(
                            "JOVENS ATOS 29",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 2.4,
                              color: Colors.white.withOpacity(0.55),
                            ),
                          ),
                        ),
                      ],
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

  static Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        text,
        textAlign: TextAlign.justify,
        style: TextStyle(
          fontSize: 15.6,
          height: 1.65,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.88),
        ),
      ),
    );
  }
}

/// ================== FUNDO ==================

class _WineBackgroundClean extends StatelessWidget {
  const _WineBackgroundClean();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [atosDeep, atosPrimary, atosAccent],
                stops: [0.0, 0.56, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.25),
                radius: 1.25,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.38),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.055,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.2),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
