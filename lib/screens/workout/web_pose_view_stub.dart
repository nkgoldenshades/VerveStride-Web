import 'package:flutter/widgets.dart';

class WebPoseView extends StatelessWidget {
  const WebPoseView({
    super.key,
    required this.overlayEnabled,
    required this.onStatus,
    this.onKeypoints,
  });

  final bool overlayEnabled;
  final ValueChanged<String> onStatus;
  final void Function(List<Map<String, dynamic>>)? onKeypoints;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('WebPoseView is only available on web platform.'),
    );
  }
}