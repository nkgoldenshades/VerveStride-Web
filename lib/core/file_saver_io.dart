import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class FileSaver {
  static Future<String> saveText({
    required String fileName,
    required String content,
  }) async {
    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } on MissingPluginException {
      dir = Directory.systemTemp;
    } catch (_) {
      dir = Directory.systemTemp;
    }
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(content);
    return file.path;
  }

  static Future<String> saveBytes({
    required String fileName,
    required List<int> bytes,
  }) async {
    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } on MissingPluginException {
      dir = Directory.systemTemp;
    } catch (_) {
      dir = Directory.systemTemp;
    }
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
