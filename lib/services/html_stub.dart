class Blob {
  Blob(List<Object?> parts);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';

  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  AnchorElement({String? href});

  void setAttribute(String name, String value) {}

  void click() {}
}
