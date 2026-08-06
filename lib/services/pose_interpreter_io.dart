import 'package:tflite_flutter/tflite_flutter.dart';

class PoseInterpreter {
  PoseInterpreter._(this._interpreter);

  final Interpreter _interpreter;

  static Future<PoseInterpreter> create({required String assetPath}) async {
    final interpreter = await Interpreter.fromAsset(assetPath);
    return PoseInterpreter._(interpreter);
  }

  void close() {
    _interpreter.close();
  }

  void run(Object input, Object output) {
    _interpreter.run(input, output);
  }

  List<Tensor> getInputTensors() => _interpreter.getInputTensors();
  List<Tensor> getOutputTensors() => _interpreter.getOutputTensors();
}
