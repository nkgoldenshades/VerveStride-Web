// Web-only implementation for rendering camera + skeleton via TFJS MoveNet.

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class WebPoseView extends StatefulWidget {
  const WebPoseView({
    super.key,
    required this.overlayEnabled,
    required this.onStatus,
    this.onKeypoints,
  });

  final bool overlayEnabled;
  final ValueChanged<String> onStatus;
  final void Function(List<Map<String, dynamic>>)? onKeypoints;

  // Public method to request camera permissions
  Future<bool> requestCameraPermission() async {
    // This method should be called from the state, not the widget
    // Remove this method as it's not needed
    return false;
  }

  @override
  State<WebPoseView> createState() => _WebPoseViewState();
}

class _WebPoseViewState extends State<WebPoseView> {
  late final String _viewType;
  late final String _containerId;

  Timer? _poller;
  Timer? _initRetry;
  bool _inited = false;
  int _initAttempts = 0;

  @override
  void initState() {
    super.initState();

    _viewType = 'movenet-web-view-${DateTime.now().microsecondsSinceEpoch}';
    _containerId = 'movenet-container-${DateTime.now().microsecondsSinceEpoch}';

    // Create a host div for JS to attach video+canvas.
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final div = html.DivElement()
        ..id = _containerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.position = 'relative'
        ..style.overflow = 'hidden'
        ..style.backgroundColor = 'black';

      // Avoid the platform view stealing focus/keyboard events on web.
      div.tabIndex = -1;
      div.setAttribute('aria-hidden', 'true');
      return div;
    });

    // Init after first frame so the HtmlElementView is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleInitRetry();
    });

    _poller = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollStatus();
      _syncOverlay();
    });
    
    // Register keypoint callback if provided
    if (widget.onKeypoints != null) {
      _registerKeypointCallback();
    }
  }
  
  void _registerKeypointCallback() {
    debugPrint('🔍 _registerKeypointCallback() called');
    
    final bridge = jsBridge();
    if (bridge == null) {
      debugPrint('⚠️ Bridge not available, retrying in 500ms');
      // Retry later
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.onKeypoints != null) {
          _registerKeypointCallback();
        }
      });
      return;
    }
    
    debugPrint('✅ Bridge found, registering callback');
    
    try {
      // Create a JavaScript function from Dart callback
      void keypointHandler(keypointsJs) {
        if (keypointsJs is! js.JsArray) {
          debugPrint('⚠️ Keypoints not a JsArray');
          return;
        }
        
        debugPrint('📍 Keypoints received from JS: ${keypointsJs.length} points');
        
        if (!mounted || widget.onKeypoints == null) {
          debugPrint('⚠️ Skipping keypoints: mounted=$mounted, callback=${widget.onKeypoints != null}');
          return;
        }
        
        try {
          final length = keypointsJs.length;
          
          // Convert JavaScript array to Dart list
          final keypoints = <Map<String, dynamic>>[];
          for (var i = 0; i < length; i++) {
            final kp = keypointsJs[i];
            if (kp is js.JsObject) {
              keypoints.add({
                'index': kp['index'] ?? i,
                'x': (kp['x'] as num?)?.toDouble() ?? 0.0,
                'y': (kp['y'] as num?)?.toDouble() ?? 0.0,
                'confidence': (kp['confidence'] as num?)?.toDouble() ?? 0.0,
              });
            }
          }
          
          debugPrint('✅ Converted ${keypoints.length} keypoints, calling Flutter callback');
          
          // Call Flutter callback
          widget.onKeypoints!(keypoints);
        } catch (e) {
          debugPrint('❌ Error processing keypoints: $e');
        }
      }
      
      // Wrap as JS function
      final callback = js.JsFunction.withThis(keypointHandler);
      
      bridge.callMethod('setKeypointCallback', [callback]);
      debugPrint('✅ Keypoint callback registered successfully');
    } catch (e) {
      debugPrint('❌ Error registering keypoint callback: $e');
    }
  }

  @override
  void didUpdateWidget(covariant WebPoseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overlayEnabled != widget.overlayEnabled) {
      _syncOverlay();
    }
  }

  void _scheduleInitRetry() {
    _initRetry?.cancel();
    _initRetry = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (_inited) {
        _initRetry?.cancel();
        _initRetry = null;
        return;
      }
      _tryInitJs();
    });
  }

  void _tryInitJs() {
    if (_inited) return;

    _initAttempts++;
    if (_initAttempts == 1 || _initAttempts % 10 == 0) {
      widget.onStatus('web: init attempt $_initAttempts');
    }

    final container = html.document.getElementById(_containerId);
    if (container == null) {
      return;
    }

    final bridge = jsBridge();
    if (bridge == null) return;

    try {
      bridge.callMethod('init', <Object?>[_containerId]);
      _inited = true;
      widget.onStatus('web: init');
    } catch (e) {
      widget.onStatus('web: init failed: $e');
    }
  }

  void _syncOverlay() {
    final bridge = jsBridge();
    if (bridge == null) return;

    try {
      bridge.callMethod('setOverlayEnabled', <Object?>[widget.overlayEnabled]);
    } catch (_) {
      // ignore
    }
  }

  void _pollStatus() {
    final bridge = jsBridge();
    if (bridge == null) return;

    try {
      final status = bridge.callMethod('getStatus', const <Object?>[]);
      if (status is js.JsObject) {
        final s = status['status']?.toString() ?? 'unknown';
        final fps = status['fps'];
        final lastError = status['lastError']?.toString();
        
        String statusMessage = 'web: $s';
        if (fps is num) {
          statusMessage += ' (${fps.toStringAsFixed(0)} fps)';
        }
        
        // Show specific error messages for camera issues
        if (lastError != null && lastError.isNotEmpty) {
          if (lastError.contains('permission')) {
            statusMessage = 'web: Camera permission denied - Click camera icon to allow';
          } else if (lastError.contains('found')) {
            statusMessage = 'web: No camera found';
          } else if (lastError.contains('in use')) {
            statusMessage = 'web: Camera already in use';
          } else {
            statusMessage = 'web: $lastError';
          }
        }
        
        widget.onStatus(statusMessage);
      } else if (status is Map) {
        final s = status['status']?.toString() ?? 'unknown';
        final fps = status['fps'];
        final lastError = status['lastError']?.toString();
        
        String statusMessage = 'web: $s';
        if (fps is num) {
          statusMessage += ' (${fps.toStringAsFixed(0)} fps)';
        }
        
        if (lastError != null && lastError.isNotEmpty) {
          if (lastError.contains('permission')) {
            statusMessage = 'web: Camera permission denied - Click camera icon to allow';
          } else if (lastError.contains('found')) {
            statusMessage = 'web: No camera found';
          } else if (lastError.contains('in use')) {
            statusMessage = 'web: Camera already in use';
          } else {
            statusMessage = 'web: $lastError';
          }
        }
        
        widget.onStatus(statusMessage);
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    _initRetry?.cancel();

    // Ensure the platform view container is removed to avoid invisible overlays
    // that can steal focus and break TextField typing on Flutter Web.
    try {
      html.document.getElementById(_containerId)?.remove();
    } catch (_) {
      // ignore
    }

    final bridge = jsBridge();
    if (bridge != null) {
      try {
        bridge.callMethod('stop', const <Object?>[]);
      } catch (_) {
        // ignore
      }
    }

    super.dispose();
  }

  js.JsObject? jsBridge() {
    final b = js.context['movenetBridge'];
    if (b is js.JsObject) return b;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return SizedBox(
          width: c.maxWidth,
          height: c.maxHeight,
          child: ClipRect(
            child: HtmlElementView(viewType: _viewType),
          ),
        );
      },
    );
  }
}