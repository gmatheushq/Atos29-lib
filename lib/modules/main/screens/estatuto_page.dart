import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_core/theme.dart';

const atosPrimary = Color(0xFF6A0F0F);
const atosDeep = Color(0xFF3A0808);
const atosBg = Color(0xFFFAF9F7);

class EstatutoPage extends StatefulWidget {
  const EstatutoPage({super.key});

  @override
  State<EstatutoPage> createState() => _EstatutoPageState();
}

class _EstatutoPageState extends State<EstatutoPage> {
  String? _erro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: atosBg,
      appBar: AppBar(
        backgroundColor: atosBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: atosDeep),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Estatuto Atos 29",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.85),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ✅ Fundo branco durante o loading (sem roxo)
          SfPdfViewerTheme(
            data: SfPdfViewerThemeData(
              backgroundColor: Colors.white,
              progressBarColor: atosPrimary,
            ),
            child: SfPdfViewer.asset(
              'assets/pdfs/estatuto_atos29.pdf',
              canShowScrollHead: false,
              canShowScrollStatus: false,
              onDocumentLoadFailed: (details) {
                debugPrint("PDF LOAD FAILED: ${details.error}");
                debugPrint("PDF LOAD FAILED DESC: ${details.description}");
                if (mounted) {
                  setState(() {
                    _erro = "${details.error}\n${details.description}";
                  });
                }
              },
            ),
          ),

          if (_erro != null)
            Positioned.fill(
              child: Container(
                color: atosBg,
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: Text(
                    "Não foi possível carregar o Estatuto\n\n$_erro",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
