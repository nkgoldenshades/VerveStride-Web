class PoseInterpreter {
  PoseInterpreter._();

  static Future<PoseInterpreter> create({required String assetPath}) async {
    throw UnsupportedError('Pose inference is not supported on web.');
  }

  void close() {}

  void run(Object input, Object output) {
    throw UnsupportedError('Pose inference is not supported on web.');
  }

  List<Tensor> getInputTensors() => [];
  List<Tensor> getOutputTensors() => [];
}

class Tensor {
  final String type;
  final List<int> shape;
  Tensor(this.type, this.shape);
}
