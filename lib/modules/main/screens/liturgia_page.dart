import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LiturgiaDiariaPage extends StatefulWidget {
  const LiturgiaDiariaPage({super.key});

  @override
  State<LiturgiaDiariaPage> createState() => _LiturgiaDiariaPageState();
}

class _LiturgiaDiariaPageState extends State<LiturgiaDiariaPage> {

  static const Color atosPrimary = Color.fromRGBO(86, 4, 5, 1);

  bool _carregando = true;
  Map<String, dynamic>? _dados;
  String _erro = '';

  @override
  void initState() {
    super.initState();
    _buscarLiturgia();
  }

  Future<void> _buscarLiturgia() async {
    final url = Uri.parse('https://liturgia.up.railway.app/');

    try {
      final resposta = await http.get(url).timeout(const Duration(seconds: 15));

      if (resposta.statusCode == 200) {
        if (mounted) {
          setState(() {
            _dados = json.decode(utf8.decode(resposta.bodyBytes));
            _carregando = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _erro = "Erro ao carregar (Status: ${resposta.statusCode})";
            _carregando = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = "Verifique sua conexão com a internet";
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Carregando..."),
          backgroundColor: Colors.white,
          foregroundColor: atosPrimary,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: atosPrimary),
        ),
      );
    }

    if (_erro.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Aviso"),
          backgroundColor: Colors.white,
          foregroundColor: atosPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 50, color: Colors.grey),
              const SizedBox(height: 10),
              Text(_erro),
              TextButton(
                onPressed: _buscarLiturgia,
                child: const Text(
                  "Tentar Novamente",
                  style: TextStyle(
                    color: atosPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dynamic segunda = _dados?['segundaLeitura'];
    final bool temSegundaLeitura = segunda != null &&
        segunda.toString().isNotEmpty &&
        !segunda.toString().toLowerCase().contains("não há");

    return DefaultTabController(
      length: temSegundaLeitura ? 4 : 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: atosPrimary,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "Liturgia Diária",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: atosPrimary,
            unselectedLabelColor: Colors.black.withOpacity(0.55),
            indicatorColor: atosPrimary,
            indicatorWeight: 3,
            tabs: [
              const Tab(text: "1ª Leitura"),
              const Tab(text: "Salmo"),
              if (temSegundaLeitura) const Tab(text: "2ª Leitura"),
              const Tab(text: "Evangelho"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTextoView(_dados?['primeiraLeitura'], "Primeira Leitura"),
            _buildTextoView(_dados?['salmo'], "Salmo Responsorial"),
            if (temSegundaLeitura)
              _buildTextoView(_dados?['segundaLeitura'], "Segunda Leitura"),
            _buildTextoView(_dados?['evangelho'], "Evangelho"),
          ],
        ),
      ),
    );
  }

  Widget _buildTextoView(dynamic dado, String titulo) {
    String textoFinal = "";
    String referencia = "";
    String refrao = "";

    if (dado is String) {
      textoFinal = dado;
    } else if (dado is Map) {
      textoFinal = dado['texto'] ?? dado['trecho'] ?? "Texto indisponível";
      referencia = (dado['referencia'] ?? "").toString();
      refrao = (dado['refrao'] ?? "").toString();
    } else {
      textoFinal = "Não foi possível carregar o conteúdo";
    }

    // Espaço após números de versículos
    textoFinal = textoFinal.replaceAllMapped(
      RegExp(r'(\d+)([A-Za-zÀ-ÿ])'),
          (match) => '${match.group(1)} ${match.group(2)}',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: atosPrimary,
              letterSpacing: 0.6,
            ),
          ),
          if (referencia.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              referencia,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.black54,
              ),
            ),
          ],

          if (refrao.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              refrao,
              style: const TextStyle(
                fontSize: 18,
                height: 1.6,
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
                color: Colors.black87,
              ),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            textoFinal,
            style: const TextStyle(
              fontSize: 18,
              height: 1.6,
              color: Colors.black87,
              fontFamily: 'serif',
            ),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
