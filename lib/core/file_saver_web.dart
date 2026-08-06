import 'dart:html' as html;

class FileSaver {
  static Future<String> saveText({
    required String fileName,
    required String content,
    String mimeType = 'application/json;charset=utf-8',
  }) async {
    final bytes = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(bytes);

    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
    return fileName;
  }

  static Future<String> saveBytes({
    required String fileName,
    required List<int> bytes,
    String mimeType =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  }) async {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
    return fileName;
  }
}
