import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


import 'package:cross_file/cross_file.dart';

class SantoPage extends StatefulWidget {
  const SantoPage({super.key});

  @override
  State<SantoPage> createState() => _SantoPageState();
}

class _SantoPageState extends State<SantoPage> {
  late Future<Map<String, dynamic>> _santoFuture;

  @override
  void initState() {
    super.initState();
    _santoFuture = buscarSanto();
  }

  String _obterDataFormatada() {
    final meses = [
      'JANEIRO','FEVEREIRO','MARÇO','ABRIL','MAIO','JUNHO',
      'JULHO','AGOSTO','SETEMBRO','OUTUBRO','NOVEMBRO','DEZEMBRO'
    ];
    final hoje = DateTime.now();
    return "${hoje.day} DE ${meses[hoje.month - 1]}";
  }

  Future<Map<String, dynamic>> buscarSanto() async {
    try {
      final hoje = DateTime.now();
      final url = Uri.parse(
        'https://catolicoapp.com/wp-json/wp/v2/santos?dia=${hoje.day}&mes=${hoje.month}',
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final list = json.decode(utf8.decode(resp.bodyBytes)) as List;
        if (list.isNotEmpty) {
          final s = list.first;
          return {
            "nome": s['title']?['rendered'] ?? "Santo do Dia",
            "imagem": s['imagem_destacada'] ?? "",
            "texto": _limparTexto(s['content']?['rendered'] ?? ""),
          };
        }
      }
      throw Exception();
    } catch (_) {
      return {
        "nome": "Santo do Dia",
        "imagem": "",
        "texto": "Erro ao carregar história",
      };
    }
  }

  String _limparTexto(String html) {
    return html
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAllMapped(
      RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)),
    )
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Future<void> _compartilhar(
      String nome, String texto, String urlImagem) async {
    final resp = await http.get(Uri.parse(urlImagem));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/santo.jpg');
    await file.writeAsBytes(resp.bodyBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: "Santo do dia: $nome\n\n$texto\n\n\n— Compartilhado pelo ATOS 29 —",

    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _santoFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final santo = snapshot.data!;
          final nome = santo["nome"];
          final texto = santo["texto"];
          final imagem = santo["imagem"].toString().isNotEmpty
              ? santo["imagem"]
              : "https://images.unsplash.com/photo-1548625361-195feee10f8c";

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ===== IMAGEM QUE DESLIZA (PARALLAX) =====
              SliverAppBar(
                pinned: false,
                floating: false,
                stretch: true,
                expandedHeight: 360,
                backgroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imagem,
                        fit: BoxFit.cover,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black54,
                              Colors.transparent,
                              Colors.black87,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 26,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _obterDataFormatada(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nome.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.white),
                    onPressed: () => _compartilhar(nome, texto, imagem),
                  ),
                ],
              ),

              // ===== CONTEÚDO =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "RELATO HISTÓRICO",
                        style: TextStyle(
                          color: Colors.brown.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        texto,
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.8,
                          color: Colors.black.withOpacity(0.78),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
