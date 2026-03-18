import 'dart:io';
import 'package:flutter/services.dart';

class InstagramStoriesShare {
  static const MethodChannel _channel = MethodChannel('atos29/instagram_stories');

  static Future<void> shareSticker({
    required File stickerFile,
    String backgroundTop = "#000000",
    String backgroundBottom = "#000000",
  }) async {
    await _channel.invokeMethod('shareToStories', {
      'stickerPath': stickerFile.path,
      'bgTop': backgroundTop,
      'bgBottom': backgroundBottom,
    });
  }
}
