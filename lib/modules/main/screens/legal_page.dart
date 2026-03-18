import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LegalPage extends StatelessWidget {
  final String title;
  final String assetPath;

  const LegalPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: SelectableText(snapshot.data!),
            ),
          );
        },
      ),
    );
  }
}
