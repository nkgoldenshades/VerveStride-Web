class JsObject {
  const JsObject();

  dynamic callMethod(String method, [List<dynamic>? args]) {
    return null;
  }

  dynamic operator [](Object? key) {
    return null;
  }
}

class StubContext {
  const StubContext();

  dynamic callMethod(String method, [List<dynamic>? args]) {
    return null;
  }
}

const StubContext context = StubContext();
