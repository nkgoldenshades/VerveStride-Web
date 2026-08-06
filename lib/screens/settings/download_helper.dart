// Platform-agnostic download helper
// Uses conditional exports to provide web or mobile implementation

export 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';
