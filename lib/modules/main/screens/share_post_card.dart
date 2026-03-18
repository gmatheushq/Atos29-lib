// share_post_card.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'instagram_stories_share.dart';

class SharePostCard {
  SharePostCard._();

  static String _buildAtHandleFromName(String userName) {
    final raw = userName.trim().toLowerCase();
    final noSpaces = raw.replaceAll(' ', '');
    final cleaned = noSpaces.replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    final handle = cleaned.isNotEmpty ? cleaned : "membro";
    return "@$handle".toLowerCase();
  }

  // ===================== SAVE =====================

  static Future<void> saveToGallery({
    required BuildContext context,
    required Uint8List pngBytes,
  }) async {
    try {

      if (Platform.isIOS) {
        final st = await Permission.photosAddOnly.request();
        if (!st.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Permissão negada para salvar nas Fotos"),
              ),
            );
          }
          return;
        }
      } else if (Platform.isAndroid) {
        final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        if (sdk <= 32) {
          final st = await Permission.storage.request();
          if (!st.isGranted) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                  Text("Permissão negada (Android <= 12). Status: $st"),
                ),
              );
            }
            return;
          }
        }
      }

      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: "atos29_${DateTime.now().millisecondsSinceEpoch}",
      );

      debugPrint("SAVE RESULT => $result");

      final ok = (result["isSuccess"] == true) || (result["success"] == true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? "Salvo na galeria" : "Falhou ao salvar: $result"),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e")),
        );
      }
    }
  }

  // ===================== LOADING =====================

  static Future<T> _runWithLoading<T>({
    required BuildContext context,
    required Future<T> Function() task,
    String label = "Preparando…",
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );

    try {
      return await task();
    } finally {
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  static Future<void> _precacheNetworkImages(
      BuildContext context,
      List<String> urls,
      ) async {
    final top = urls.take(4).toList();
    for (final u in top) {
      final url = u.trim();
      if (url.isEmpty) continue;
      try {
        await precacheImage(NetworkImage(url), context);
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  // ===================== ENTRY =====================

  static Future<void> openPreviewAndShare({
    required BuildContext context,
    required String shareLink,
    required String userName,
    required String tipo,
    required Color corTipo,
    required String titulo,
    required String texto,
    required List<String> imageUrls,

    String? pollQuestion,
    List<String> pollOptions = const [],
    List<int> pollVotes = const [],
    int? pollSelectedIndex,
    bool pollShowResults = true,

    Uint8List? profileBytes,
    String? logoAssetPathLight,
    String? logoAssetPathDark,
    String? profileFallbackLetter,
    String appName = "ATOS 29",
    IconData logo = Icons.church_rounded,
  }) async {
    final String tipoFinal =
    (tipo.trim().isEmpty || tipo.trim().toLowerCase() == "post")
        ? _buildAtHandleFromName(userName)
        : tipo;

    // normaliza enquete
    final pq = (pollQuestion ?? "").trim();
    final po =
    pollOptions.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final pv = List<int>.from(pollVotes);
    while (pv.length < po.length) pv.add(0);
    if (pv.length > po.length) pv.removeRange(po.length, pv.length);

    final hasPoll = pq.isNotEmpty && po.length >= 2;

    final selected = (pollSelectedIndex != null &&
        pollSelectedIndex! >= 0 &&
        pollSelectedIndex! < po.length)
        ? pollSelectedIndex
        : null;

    Uint8List? singlePhotoBytes;
    Size? singlePhotoSize;

    if (imageUrls.length == 1) {
      singlePhotoBytes = await _runWithLoading<Uint8List?>(
        context: context,
        label: "Carregando foto…",
        task: () async {
          try {
            return await _downloadBytes(imageUrls.first);
          } catch (_) {
            return null;
          }
        },
      );

      if (singlePhotoBytes != null) {
        try {
          singlePhotoSize = await _decodeImageSize(singlePhotoBytes);
        } catch (_) {}
      }
    } else if (imageUrls.length > 1) {
      await _runWithLoading<void>(
        context: context,
        label: "Carregando fotos…",
        task: () async => _precacheNetworkImages(context, imageUrls),
      );
    }

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) {
        return _SharePreviewSheet(
          appName: appName,
          logo: logo,
          profileBytes: profileBytes,
          logoAssetPathLight: logoAssetPathLight,
          logoAssetPathDark: logoAssetPathDark,
          profileFallbackLetter: profileFallbackLetter,
          shareLink: shareLink,
          userName: userName,
          tipo: tipoFinal,
          corTipo: corTipo,
          titulo: titulo,
          texto: texto,
          imageUrls: imageUrls,
          singlePhotoBytes: singlePhotoBytes,
          singlePhotoSize: singlePhotoSize,
          pollQuestion: hasPoll ? pq : null,
          pollOptions: hasPoll ? po : const [],
          pollVotes: hasPoll ? pv : const [],
          pollSelectedIndex: hasPoll ? selected : null,
          pollShowResults: pollShowResults,
        );
      },
    );
  }

  // ===================== CAPTURE CARD (PNG) =====================

  static Future<Uint8List> _buildCardPng({
    required BuildContext context,
    required _ShareTheme theme,
    required String appName,
    required IconData logo,
    required Uint8List? profileBytes,
    required String? logoAssetPathLight,
    required String? logoAssetPathDark,
    required String? profileFallbackLetter,
    required String userName,
    required String tipo,
    required Color corTipo,
    required String titulo,
    required String texto,
    required List<String> imageUrls,
    required Uint8List? singlePhotoBytes,
    required Size? singlePhotoSize,
    required bool showHandle,
    required String? pollQuestion,
    required List<String> pollOptions,
    required List<int> pollVotes,
    required int? pollSelectedIndex,
    required bool pollShowResults,

    bool withShadow = false,
  }) async {
    final Widget card = _ShareCardWidget(
      theme: theme,
      appName: appName,
      logo: logo,
      profileBytes: profileBytes,
      logoAssetPathLight: logoAssetPathLight,
      logoAssetPathDark: logoAssetPathDark,
      profileFallbackLetter: profileFallbackLetter,
      userName: userName,
      tipo: tipo,
      corTipo: corTipo,
      titulo: titulo,
      texto: texto,
      imageUrls: imageUrls,
      singlePhotoBytes: singlePhotoBytes,
      singlePhotoSize: singlePhotoSize,
      withShadow: withShadow,

      pollQuestion: pollQuestion,
      pollOptions: pollOptions,
      pollVotes: pollVotes,
      pollSelectedIndex: pollSelectedIndex,
      pollShowResults: pollShowResults,
    );

    final Widget cardWithHandle = showHandle
        ? _CardWithHandle(
      card: card,
      handleChild: _HandleLinkBadge(
        text: "Atos 29",
        iconColor: Colors.white.withOpacity(0.86),
        textColor: Colors.white.withOpacity(0.86),
      ),
      withShadow: withShadow,
    )
        : (withShadow
        ? Padding(
      padding: const EdgeInsets.all(34),
      child: card,
    )
        : card);

    final Widget tree = Material(
      color: Colors.transparent,
      child: MediaQuery(
        data: MediaQuery.of(context),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: cardWithHandle),
        ),
      ),
    );

    return _captureWidgetToPng(
      context: context,
      child: tree,
      pixelRatio: 3.0,
    );
  }

  // ===================== INSTAGRAM =====================

  static Future<void> _shareToInstagramStory({
    required BuildContext context,
    required String shareLink,
    required _ShareTheme theme,
    required String appName,
    required IconData logo,
    required Uint8List? profileBytes,
    required String? logoAssetPathLight,
    required String? logoAssetPathDark,
    required String? profileFallbackLetter,
    required String userName,
    required String tipo,
    required Color corTipo,
    required String titulo,
    required String texto,
    required List<String> imageUrls,
    required Uint8List? singlePhotoBytes,
    required Size? singlePhotoSize,
    required bool showHandle,
    required String? pollQuestion,
    required List<String> pollOptions,
    required List<int> pollVotes,
    required int? pollSelectedIndex,
    required bool pollShowResults,
  }) async {
    if (imageUrls.length > 1) {
      await _runWithLoading<void>(
        context: context,
        label: "Preparando para Instagram…",
        task: () async => _precacheNetworkImages(context, imageUrls),
      );
    }

    final pngBytes = await _buildCardPng(
      context: context,
      theme: theme,
      appName: appName,
      logo: logo,
      profileBytes: profileBytes,
      logoAssetPathLight: logoAssetPathLight,
      logoAssetPathDark: logoAssetPathDark,
      profileFallbackLetter: profileFallbackLetter,
      userName: userName,
      tipo: tipo,
      corTipo: corTipo,
      titulo: titulo,
      texto: texto,
      imageUrls: imageUrls,
      singlePhotoBytes: singlePhotoBytes,
      singlePhotoSize: singlePhotoSize,
      showHandle: showHandle,
      withShadow: true,

      pollQuestion: pollQuestion,
      pollOptions: pollOptions,
      pollVotes: pollVotes,
      pollSelectedIndex: pollSelectedIndex,
      pollShowResults: pollShowResults,
    );

    final file = await _writeTempPng(pngBytes);

    try {
      await InstagramStoriesShare.shareSticker(
        stickerFile: file,
        backgroundTop: "#2A0A0A",
        backgroundBottom: "#6A0F0F",
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao abrir Instagram: $e")),
        );
      }
    }
  }

  // ===================== SHARE IMAGE (WhatsApp etc) =====================

  static Future<void> _shareAsImage({
    required BuildContext context,
    required Uint8List pngBytes,
    required String subject,
    String? text,
  }) async {
    final file = await _writeTempPng(pngBytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: "image/png")],
      subject: subject,
      text: text,
    );
  }

  // ===================== CAPTURE (widget->png) =====================

  static Future<Uint8List> _captureWidgetToPng({
    required BuildContext context,
    required Widget child,
    double pixelRatio = 3,
  }) async {
    final repaintKey = GlobalKey();
    final overlay = Overlay.of(context);
    if (overlay == null) throw Exception("Overlay não encontrado");

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: -10000,
          top: -10000,
          child: Material(
            color: Colors.transparent,
            child: RepaintBoundary(
              key: repaintKey,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: MediaQuery(
                  data: MediaQuery.of(context),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    await Future<void>.delayed(const Duration(milliseconds: 90));
    await WidgetsBinding.instance.endOfFrame;

    final renderObject = repaintKey.currentContext?.findRenderObject();
    final boundary = renderObject is RenderRepaintBoundary ? renderObject : null;

    if (boundary == null) {
      entry.remove();
      throw Exception("Boundary não encontrado");
    }

    if (boundary.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await WidgetsBinding.instance.endOfFrame;
    }

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    entry.remove();

    if (byteData == null) throw Exception("Falha ao converter PNG");
    return byteData.buffer.asUint8List();
  }

  static Future<File> _writeTempPng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/share.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<Uint8List> _downloadBytes(String url) async {
    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}");
      final chunks = <int>[];
      await for (final c in res) {
        chunks.addAll(c);
      }
      return Uint8List.fromList(chunks);
    } finally {
      client.close(force: true);
    }
  }
}

// ===================== THEMES =====================

enum _ShareTheme { vinho, brancoVinho, pretoVinho }

class _ThemeSpec {
  final Color bg;
  final Color fg;
  final Color muted;
  final Color accent;
  final bool useGradient;
  final List<Color> gradient;

  const _ThemeSpec({
    required this.bg,
    required this.fg,
    required this.muted,
    required this.accent,
    required this.useGradient,
    required this.gradient,
  });
}

_ThemeSpec _specFor(_ShareTheme t, Color corTipo) {
  const vinho = Color(0xFF6A0F0F);
  const deep = Color(0xFF3A0808);

  switch (t) {
    case _ShareTheme.vinho:
      return _ThemeSpec(
        bg: deep,
        fg: Colors.white,
        muted: Colors.white.withOpacity(0.80),
        accent: corTipo,
        useGradient: true,
        gradient: [deep, vinho],
      );

    case _ShareTheme.brancoVinho:
      return _ThemeSpec(
        bg: const Color(0xFFFFFFFF),
        fg: const Color(0xFF0E0E10),
        muted: const Color(0xFF0E0E10).withOpacity(0.62),
        accent: vinho,
        useGradient: false,
        gradient: const [],
      );

    case _ShareTheme.pretoVinho:
      return _ThemeSpec(
        bg: const Color(0xFF000000),
        fg: Colors.white,
        muted: Colors.white.withOpacity(0.74),
        accent: vinho,
        useGradient: false,
        gradient: const [],
      );
  }
}

// ===================== helpers (image size) =====================

Future<Size> _decodeImageSize(Uint8List bytes) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, (img) => completer.complete(img));
  final img = await completer.future;
  final s = Size(img.width.toDouble(), img.height.toDouble());
  img.dispose();
  return s;
}

// ===================== PREVIEW SHEET =====================

class _SharePreviewSheet extends StatefulWidget {
  const _SharePreviewSheet({
    required this.appName,
    required this.logo,
    required this.profileBytes,
    required this.logoAssetPathLight,
    required this.logoAssetPathDark,
    required this.profileFallbackLetter,
    required this.shareLink,
    required this.userName,
    required this.tipo,
    required this.corTipo,
    required this.titulo,
    required this.texto,
    required this.imageUrls,
    required this.singlePhotoBytes,
    required this.singlePhotoSize,
    required this.pollQuestion,
    required this.pollOptions,
    required this.pollVotes,
    required this.pollSelectedIndex,
    required this.pollShowResults,
  });

  final String appName;
  final IconData logo;

  final Uint8List? profileBytes;
  final String? logoAssetPathLight;
  final String? logoAssetPathDark;
  final String? profileFallbackLetter;

  final String shareLink;
  final String userName;
  final String tipo;
  final Color corTipo;
  final String titulo;
  final String texto;

  final List<String> imageUrls;
  final Uint8List? singlePhotoBytes;
  final Size? singlePhotoSize;

  final String? pollQuestion;
  final List<String> pollOptions;
  final List<int> pollVotes;
  final int? pollSelectedIndex;
  final bool pollShowResults;

  @override
  State<_SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends State<_SharePreviewSheet> {
  _ShareTheme _theme = _ShareTheme.vinho;
  bool _busy = false;

  // toggle do handle
  bool _showHandle = true;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final double previewMaxH = h * 0.62;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: 14 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      child: Row(
                        children: [
                          Text(
                            "Pré-visualização",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black.withOpacity(0.86),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.black.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // toggle handle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 18,
                                  color: Colors.black.withOpacity(0.70),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Atos 29",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black.withOpacity(0.70),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Switch(
                            value: _showHandle,
                            onChanged: (v) => setState(() => _showHandle = v),
                          ),
                        ],
                      ),
                    ),

                    // preview
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: previewMaxH),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: _previewCard(),
                          ),
                        ),
                      ),
                    ),

                    // themes
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ThemePill(
                              label: "Vinho",
                              active: _theme == _ShareTheme.vinho,
                              onTap: () => setState(
                                      () => _theme = _ShareTheme.vinho),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ThemePill(
                              label: "Branca",
                              active: _theme == _ShareTheme.brancoVinho,
                              onTap: () => setState(
                                      () => _theme = _ShareTheme.brancoVinho),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ThemePill(
                              label: "Preta",
                              active: _theme == _ShareTheme.pretoVinho,
                              onTap: () => setState(
                                      () => _theme = _ShareTheme.pretoVinho),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionIconButton(
                              icon: Icons.download_rounded,
                              busy: _busy,
                              onTap: () async {
                                setState(() => _busy = true);
                                try {
                                  final png =
                                  await SharePostCard._buildCardPng(
                                    context: context,
                                    theme: _theme,
                                    appName: widget.appName,
                                    logo: widget.logo,
                                    profileBytes: widget.profileBytes,
                                    logoAssetPathLight:
                                    widget.logoAssetPathLight,
                                    logoAssetPathDark:
                                    widget.logoAssetPathDark,
                                    profileFallbackLetter:
                                    widget.profileFallbackLetter,
                                    userName: widget.userName,
                                    tipo: widget.tipo,
                                    corTipo: widget.corTipo,
                                    titulo: widget.titulo,
                                    texto: widget.texto,
                                    imageUrls: widget.imageUrls,
                                    singlePhotoBytes: widget.singlePhotoBytes,
                                    singlePhotoSize: widget.singlePhotoSize,
                                    showHandle: _showHandle,
                                    withShadow: false,

                                    pollQuestion: widget.pollQuestion,
                                    pollOptions: widget.pollOptions,
                                    pollVotes: widget.pollVotes,
                                    pollSelectedIndex: widget.pollSelectedIndex,
                                    pollShowResults: widget.pollShowResults,
                                  );

                                  await SharePostCard.saveToGallery(
                                    context: context,
                                    pngBytes: png,
                                  );
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionIconButton(
                              icon: Icons.ios_share_rounded,
                              busy: _busy,
                              onTap: () async {
                                setState(() => _busy = true);
                                try {
                                  final png =
                                  await SharePostCard._buildCardPng(
                                    context: context,
                                    theme: _theme,
                                    appName: widget.appName,
                                    logo: widget.logo,
                                    profileBytes: widget.profileBytes,
                                    logoAssetPathLight:
                                    widget.logoAssetPathLight,
                                    logoAssetPathDark:
                                    widget.logoAssetPathDark,
                                    profileFallbackLetter:
                                    widget.profileFallbackLetter,
                                    userName: widget.userName,
                                    tipo: widget.tipo,
                                    corTipo: widget.corTipo,
                                    titulo: widget.titulo,
                                    texto: widget.texto,
                                    imageUrls: widget.imageUrls,
                                    singlePhotoBytes: widget.singlePhotoBytes,
                                    singlePhotoSize: widget.singlePhotoSize,
                                    showHandle: _showHandle,

                                    pollQuestion: widget.pollQuestion,
                                    pollOptions: widget.pollOptions,
                                    pollVotes: widget.pollVotes,
                                    pollSelectedIndex: widget.pollSelectedIndex,
                                    pollShowResults: widget.pollShowResults,
                                  );

                                  await SharePostCard._shareAsImage(
                                    context: context,
                                    pngBytes: png,
                                    subject: widget.appName,
                                    text: widget.shareLink,
                                  );
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionIconButton(
                              assetPath: "assets/images/instagram.png",
                              busy: _busy,
                              onTap: () async {
                                setState(() => _busy = true);
                                try {
                                  await SharePostCard._shareToInstagramStory(
                                    context: context,
                                    shareLink: widget.shareLink,
                                    theme: _theme,
                                    appName: widget.appName,
                                    logo: widget.logo,
                                    profileBytes: widget.profileBytes,
                                    logoAssetPathLight:
                                    widget.logoAssetPathLight,
                                    logoAssetPathDark:
                                    widget.logoAssetPathDark,
                                    profileFallbackLetter:
                                    widget.profileFallbackLetter,
                                    userName: widget.userName,
                                    tipo: widget.tipo,
                                    corTipo: widget.corTipo,
                                    titulo: widget.titulo,
                                    texto: widget.texto,
                                    imageUrls: widget.imageUrls,
                                    singlePhotoBytes: widget.singlePhotoBytes,
                                    singlePhotoSize: widget.singlePhotoSize,
                                    showHandle: _showHandle,

                                    pollQuestion: widget.pollQuestion,
                                    pollOptions: widget.pollOptions,
                                    pollVotes: widget.pollVotes,
                                    pollSelectedIndex: widget.pollSelectedIndex,
                                    pollShowResults: widget.pollShowResults,
                                  );

                                  if (mounted && Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  }
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewCard() {
    final Widget card = _ShareCardWidget(
      theme: _theme,
      appName: widget.appName,
      logo: widget.logo,
      profileBytes: widget.profileBytes,
      logoAssetPathLight: widget.logoAssetPathLight,
      logoAssetPathDark: widget.logoAssetPathDark,
      profileFallbackLetter: widget.profileFallbackLetter,
      userName: widget.userName,
      tipo: widget.tipo,
      corTipo: widget.corTipo,
      titulo: widget.titulo,
      texto: widget.texto,
      imageUrls: widget.imageUrls,
      singlePhotoBytes: widget.singlePhotoBytes,
      singlePhotoSize: widget.singlePhotoSize,

      pollQuestion: widget.pollQuestion,
      pollOptions: widget.pollOptions,
      pollVotes: widget.pollVotes,
      pollSelectedIndex: widget.pollSelectedIndex,
      pollShowResults: widget.pollShowResults,
    );

    if (!_showHandle) return card;

    return _CardWithHandle(
      card: card,
      handleChild: _HandleLinkBadge(
        text: "Atos 29",
        iconColor: Colors.white.withOpacity(0.86),
        textColor: Colors.white.withOpacity(0.86),
      ),
    );
  }
}

// ===================== BUTTONS =====================

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    this.icon,
    this.assetPath,
    required this.onTap,
    required this.busy,
  });

  final IconData? icon;
  final String? assetPath;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: busy ? null : onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF6A0F0F), Color(0xFF8A1A1A)],
          ),
        ),
        child: Center(
          child: busy
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : (assetPath != null
              ? Image.asset(
            assetPath!,
            width: 28,
            height: 28,
            color: Colors.white,
          )
              : Icon(icon, color: Colors.white, size: 26)),
        ),
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  const _ThemePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.black.withOpacity(0.07) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? Colors.black.withOpacity(0.16) : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: Colors.black.withOpacity(0.78),
          ),
        ),
      ),
    );
  }
}

// ===================== HANDLE (outside) =====================

class _HandleLinkBadge extends StatelessWidget {
  const _HandleLinkBadge({
    required this.text,
    required this.iconColor,
    required this.textColor,
  });

  final String text;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.link_rounded,
          size: 16,
          color: iconColor,
          shadows: [
            Shadow(
              blurRadius: 16,
              offset: const Offset(0, 2),
              color: Colors.black.withOpacity(0.35),
            ),
          ],
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.4,
            color: textColor,
            shadows: [
              Shadow(
                blurRadius: 16,
                offset: const Offset(0, 2),
                color: Colors.black.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardWithHandle extends StatelessWidget {
  const _CardWithHandle({
    required this.card,
    required this.handleChild,
    this.withShadow = false,
    super.key,
  });

  final Widget card;
  final Widget handleChild;
  final bool withShadow;

  static const Offset kHandleOffset = Offset(-5, 5);

  // espaço extra pra sombra não cortar (simétrico!)
  static const double _shadowPad = 34;

  // espaço pro handle "sair" pra fora embaixo
  static const double _handlePadBottom = 46;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        withShadow ? _shadowPad : 0,
        withShadow ? _shadowPad : 0,
        withShadow ? _shadowPad : 0,
        _handlePadBottom + (withShadow ? _shadowPad : 0),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            left: 10,
            bottom: -18,
            child: Transform.translate(
              offset: kHandleOffset,
              child: handleChild,
            ),
          ),
        ],
      ),
    );
  }
}


// ===================== CARD =====================

class _ShareCardWidget extends StatelessWidget {
  const _ShareCardWidget({
    required this.theme,
    required this.appName,
    required this.logo,
    required this.profileBytes,
    required this.logoAssetPathLight,
    required this.logoAssetPathDark,
    required this.profileFallbackLetter,
    required this.userName,
    required this.tipo,
    required this.corTipo,
    required this.titulo,
    required this.texto,
    required this.imageUrls,
    required this.singlePhotoBytes,
    required this.singlePhotoSize,
    required this.pollQuestion,
    required this.pollOptions,
    required this.pollVotes,
    required this.pollSelectedIndex,
    required this.pollShowResults,

    this.withShadow = false,
    super.key,
  });

  final bool withShadow;

  final _ShareTheme theme;
  final String appName;
  final IconData logo;
  final Uint8List? profileBytes;

  final String? logoAssetPathLight;
  final String? logoAssetPathDark;
  final String? profileFallbackLetter;

  final String userName;
  final String tipo;
  final Color corTipo;
  final String titulo;
  final String texto;

  final List<String> imageUrls;
  final Uint8List? singlePhotoBytes;
  final Size? singlePhotoSize;

  final String? pollQuestion;
  final List<String> pollOptions;
  final List<int> pollVotes;
  final int? pollSelectedIndex;
  final bool pollShowResults;

  @override
  Widget build(BuildContext context) {
    final double cardW = withShadow ? 344 : 360;

    const double radius = 22;

    final spec = _specFor(theme, corTipo);

    final bool hasGrid = imageUrls.length > 1;
    final bool hasSingle = imageUrls.length == 1 && singlePhotoBytes != null;
    final BoxShadow outerShadow = BoxShadow(
      color: Colors.black.withOpacity(0.18),
      blurRadius: 18,
      spreadRadius: 2,
      offset: const Offset(0, 6),
    );


    // poll normalized
    final pq = (pollQuestion ?? "").trim();
    final po = pollOptions.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final pv = List<int>.from(pollVotes);
    while (pv.length < po.length) pv.add(0);
    if (pv.length > po.length) pv.removeRange(po.length, pv.length);

    final hasPoll = pq.isNotEmpty && po.length >= 2;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: withShadow ? [outerShadow] : [],

      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: cardW,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: spec.useGradient ? null : spec.bg,
            gradient: spec.useGradient
                ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: spec.gradient,
            )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                fg: spec.fg,
                muted: spec.muted,
                accent: spec.accent,
                logo: logo,
                appName: appName,
                userName: userName,
                tipo: tipo,
                profileBytes: profileBytes,
                logoAssetPathLight: logoAssetPathLight,
                logoAssetPathDark: logoAssetPathDark,
                profileFallbackLetter: profileFallbackLetter,
              ),
              const SizedBox(height: 10),
              if (titulo.trim().isNotEmpty)
                Text(
                  titulo.trim(),
                  style: TextStyle(
                    color: spec.fg,
                    fontSize: 18.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    height: 1.12,
                  ),
                ),
              if (texto.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  texto.trim(),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: spec.muted,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],

              if (hasPoll) ...[
                const SizedBox(height: 12),
                _PollBlockResults(
                  theme: theme,
                  question: pq,
                  options: po,
                  votes: pv,
                  selectedIndex: pollSelectedIndex,
                  showResults: pollShowResults,
                  accent: spec.accent,
                ),
              ],

              if ((hasGrid || hasSingle) &&
                  (titulo.trim().isNotEmpty ||
                      texto.trim().isNotEmpty ||
                      hasPoll))
                const SizedBox(height: 12),
              if (hasGrid)
                _ShareNetworkImageGrid(
                  urls: imageUrls,
                  theme: theme,
                ),
              if (hasSingle)
                _PhotoBlockSmart3x4(
                  bytes: singlePhotoBytes!,
                  theme: theme,
                  imageSize: singlePhotoSize,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollBlockResults extends StatelessWidget {
  const _PollBlockResults({
    required this.theme,
    required this.question,
    required this.options,
    required this.votes,
    required this.accent,
    this.selectedIndex,
    this.showResults = true,
  });

  final _ShareTheme theme;
  final String question;
  final List<String> options;
  final List<int> votes;
  final Color accent;

  final int? selectedIndex;
  final bool showResults;

  @override
  Widget build(BuildContext context) {
    final bool dark = theme != _ShareTheme.brancoVinho;

    final bool hasVoted = true; // força sempre mostrar

    final Color iconColor = dark ? Colors.white : const Color(0xFF6A0F0F);

    final Color cardBg =
    dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.02);

    final Color cardBorder =
    dark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.06);

    final Color titleColor =
    dark ? Colors.white : Colors.black.withOpacity(0.78);

    final Color subColor =
    dark ? Colors.white.withOpacity(0.75) : Colors.black.withOpacity(0.45);

    int totalVotes = 0;
    for (final v in votes) {
      totalVotes += (v < 0 ? 0 : v);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_rounded, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...List.generate(options.length, (i) {
            final text = options[i];
            final v = (i < votes.length) ? (votes[i] < 0 ? 0 : votes[i]) : 0;

            final double pct =
            totalVotes <= 0 ? 0 : (v / totalVotes).clamp(0.0, 1.0);

            final bool selected =
            (selectedIndex != null && selectedIndex == i);

            final bool selectedWhite = dark && selected;

            final Color optBg = selected
                ? (selectedWhite
                ? Colors.white.withOpacity(0.92)
                : accent.withOpacity(dark ? 0.18 : 0.10))
                : (dark ? Colors.black.withOpacity(0.18) : Colors.white);

            final Color optBorder = selected
                ? (selectedWhite
                ? Colors.white.withOpacity(0.70)
                : accent.withOpacity(dark ? 0.45 : 0.35))
                : (dark
                ? Colors.white.withOpacity(0.10)
                : Colors.black.withOpacity(0.06));

            final Color optText = selectedWhite
                ? const Color(0xFF0E0E10) // texto escuro no fundo branco
                : (dark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.75));

            final Color countColor = selectedWhite
                ? const Color(0xFF0E0E10).withOpacity(0.55)
                : (dark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.45));


            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  color: optBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: optBorder, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: optText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        if (showResults)
                          Text(
                            "$v",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: countColor,
                            ),
                          ),
                      ],
                    ),

                    if (showResults) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor:
                          (dark ? Colors.white : Colors.black).withOpacity(0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme == _ShareTheme.vinho
                                ? Colors.white.withOpacity(0.9)
                                : accent.withOpacity(0.75),
                          ),

                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 2),
          Text(
            (showResults) ? "$totalVotes voto(s)" : "Toque para votar",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoBlockSmart3x4 extends StatelessWidget {
  const _PhotoBlockSmart3x4({
    required this.bytes,
    required this.theme,
    required this.imageSize,
  });

  final Uint8List bytes;
  final _ShareTheme theme;
  final Size? imageSize;

  static const double _maxAspect = 3 / 4;

  @override
  Widget build(BuildContext context) {
    const double innerW = 360 - (16 * 2);
    final bool dark = theme != _ShareTheme.brancoVinho;

    final double realAspect =
    (imageSize != null && imageSize!.height > 0)
        ? (imageSize!.width / imageSize!.height)
        : _maxAspect;

    final bool tooTall = realAspect < _maxAspect;

    final double boxAspect = tooTall ? _maxAspect : realAspect;
    final BoxFit fit = tooTall ? BoxFit.cover : BoxFit.contain;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: innerW,
        child: AspectRatio(
          aspectRatio: boxAspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                bytes,
                fit: fit,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (dark ? Colors.black : Colors.white).withOpacity(0.08),
                      Colors.transparent,
                      (dark ? Colors.black : Colors.white).withOpacity(0.10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareNetworkImageGrid extends StatelessWidget {
  const _ShareNetworkImageGrid({
    required this.urls,
    required this.theme,
  });

  final List<String> urls;
  final _ShareTheme theme;

  @override
  Widget build(BuildContext context) {
    final shown = urls.take(4).toList();
    final remaining = urls.length - shown.length;

    const double w = 360 - (16 * 2);
    const double h = 210;

    final bool dark = theme != _ShareTheme.brancoVinho;

    final Color gapColor =
    dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08);

    Widget tile(String url) {
      return ClipRect(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.high,
          loadingBuilder: (c, child, p) {
            if (p == null) return child;
            return Container(
              color: gapColor,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(color: gapColor),
        ),
      );
    }

    Widget lastWithPlusOverlay(String url) {
      return Stack(
        fit: StackFit.expand,
        children: [
          tile(url),
          if (remaining > 0)
            Container(
              color: Colors.black.withOpacity(0.45),
              alignment: Alignment.center,
              child: Text(
                "+$remaining",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ),
        ],
      );
    }

    Widget gapW() => Container(width: 2, color: gapColor);
    Widget gapH() => Container(height: 2, color: gapColor);

    Widget layoutByCount() {
      final c = shown.length;

      if (c == 2) {
        return Row(
          children: [
            Expanded(child: tile(shown[0])),
            gapW(),
            Expanded(child: tile(shown[1])),
          ],
        );
      }

      if (c == 3) {
        return Row(
          children: [
            Expanded(child: tile(shown[0])),
            gapW(),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: tile(shown[1])),
                  gapH(),
                  Expanded(child: tile(shown[2])),
                ],
              ),
            ),
          ],
        );
      }

      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: tile(shown[0])),
                gapW(),
                Expanded(child: tile(shown[1])),
              ],
            ),
          ),
          gapH(),
          Expanded(
            child: Row(
              children: [
                Expanded(child: tile(shown[2])),
                gapW(),
                Expanded(child: lastWithPlusOverlay(shown[3])),
              ],
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: w,
        height: h,
        child: Container(
          color: gapColor,
          child: layoutByCount(),
        ),
      ),
    );
  }
}

// ===================== HEADER =====================

class _Header extends StatelessWidget {
  const _Header({
    required this.fg,
    required this.muted,
    required this.accent,
    required this.logo,
    required this.appName,
    required this.userName,
    required this.tipo,
    this.profileBytes,
    this.logoAssetPathLight,
    this.logoAssetPathDark,
    this.profileFallbackLetter,
  });

  final Color fg;
  final Color muted;
  final Color accent;
  final IconData logo;
  final String appName;
  final String userName;
  final String tipo;

  final Uint8List? profileBytes;
  final String? logoAssetPathLight;
  final String? logoAssetPathDark;
  final String? profileFallbackLetter;

  @override
  Widget build(BuildContext context) {
    final u = userName.trim().isEmpty ? "Membro" : userName.trim();

    Widget fallbackBox() {
      final bool isLightTheme = fg != Colors.white;

      final String letter = (profileFallbackLetter?.trim().isNotEmpty == true)
          ? profileFallbackLetter!.trim()[0].toUpperCase()
          : (u.isNotEmpty ? u[0].toUpperCase() : "M");

      final Color bg = isLightTheme ? accent : Colors.white;
      final Color textColor = isLightTheme ? Colors.white : accent;

      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.hardEdge,
        child: Container(
          width: 48,
          height: 48,
          color: bg,
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 21,
              color: textColor,
            ),
          ),
        ),
      );
    }

    Widget leftAvatar() {
      if (profileBytes != null) {
        return ClipOval(
          child: Image.memory(
            profileBytes!,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => fallbackBox(),
          ),
        );
      }
      return fallbackBox();
    }

    Widget rightLogoOrText() {
      final bool darkBg = fg == Colors.white;
      final String chosenPath =
      (darkBg ? (logoAssetPathLight ?? "") : (logoAssetPathDark ?? "")).trim();

      if (chosenPath.isNotEmpty) {
        return Image.asset(
          chosenPath,
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            appName,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              fontSize: 12,
            ),
          ),
        );
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(logo, color: fg, size: 18),
          const SizedBox(width: 6),
          Text(
            appName,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        leftAvatar(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                u,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "@${userName.trim().toLowerCase().replaceAll(' ', '')}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        rightLogoOrText(),
      ],
    );
  }
}
