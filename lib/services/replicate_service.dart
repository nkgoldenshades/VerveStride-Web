import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

/// Service for interacting with Replicate API for image, video, and audio generation
/// Uses Firebase Cloud Functions to bypass CORS restrictions
class ReplicateService {
  // Model versions (these are stable and well-tested)
  static const String _imageModel = 'stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b';
  static const String _videoModel = 'anotherjesse/zeroscope-v2-xl:9f747673945c62801b13b84701c783929c0ee784e4748ec062204894dda1a351';
  static const String _audioModel = 'meta/musicgen:671ac645ce5e552cc63a54a2bbff63fcf798043055d2dac5fc9e36a837eedcfb';

  /// Generate an image from a text prompt
  /// Returns image bytes on success, null on failure
  static Future<Uint8List?> generateImage(String prompt) async {
    try {
      debugPrint('🎨 [Replicate] Generating image: ${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}...');
      
      // Create prediction via Cloud Function
      final prediction = await _createPrediction(
        model: _imageModel,
        input: {
          'prompt': prompt,
          'negative_prompt': 'ugly, blurry, low quality, distorted',
          'width': 1024,
          'height': 1024,
          'num_outputs': 1,
        },
      );

      if (prediction == null) {
        debugPrint('❌ [Replicate] Failed to create image prediction');
        return null;
      }

      debugPrint('⏳ [Replicate] Waiting for prediction to complete...');
      // Wait for completion
      final result = await _waitForPrediction(prediction['id']);
      if (result == null) {
        debugPrint('❌ [Replicate] Image generation timed out or failed');
        return null;
      }
      
      if (result['output'] == null) {
        debugPrint('❌ [Replicate] No output in result: ${result}');
        return null;
      }

      // Download image
      final imageUrl = result['output'][0] as String;
      debugPrint('🎨 [Replicate] Downloading image from: $imageUrl');
      
      final response = await http.get(Uri.parse(imageUrl)).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏱️ [Replicate] Image download timed out');
          throw Exception('Download timed out');
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ [Replicate] Image generated successfully (${response.bodyBytes.length} bytes)');
        return response.bodyBytes;
      }

      debugPrint('❌ [Replicate] Failed to download image: ${response.statusCode}');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ [Replicate] Image generation error: $e');
      debugPrint('❌ [Replicate] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Generate a video from a text prompt
  /// Returns video URL on success (videos are too large to return as bytes), null on failure
  static Future<String?> generateVideo(String prompt, {int durationSeconds = 5}) async {
    try {
      debugPrint('🎬 [Replicate] Generating video: ${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}...');
      debugPrint('🎬 [Replicate] Duration: ${durationSeconds}s');
      
      // Zeroscope doesn't support duration parameter, it generates ~3-4 second videos
      final prediction = await _createPrediction(
        model: _videoModel,
        input: {
          'prompt': prompt,
          'negative_prompt': 'ugly, blurry, low quality, distorted, static',
          'num_frames': 24, // ~1 second at 24fps
          'num_inference_steps': 50,
        },
      );

      if (prediction == null) {
        debugPrint('❌ [Replicate] Failed to create video prediction');
        return null;
      }

      // Wait for completion (videos take longer)
      final result = await _waitForPrediction(prediction['id'], maxWaitSeconds: 180);
      if (result == null || result['output'] == null) {
        debugPrint('❌ [Replicate] Video generation failed or timed out');
        return null;
      }

      final videoUrl = result['output'] as String;
      debugPrint('✅ [Replicate] Video generated successfully: $videoUrl');
      return videoUrl;
    } catch (e) {
      debugPrint('❌ [Replicate] Video generation error: $e');
      return null;
    }
  }

  /// Generate audio/music from a text prompt
  /// Returns audio URL on success, null on failure
  static Future<String?> generateAudio(String prompt, {int durationSeconds = 30}) async {
    try {
      debugPrint('🎵 [Replicate] Generating audio: ${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}...');
      debugPrint('🎵 [Replicate] Duration: ${durationSeconds}s');
      
      final prediction = await _createPrediction(
        model: _audioModel,
        input: {
          'prompt': prompt,
          'duration': durationSeconds,
          'model_version': 'stereo-large', // Best quality
          'output_format': 'mp3',
          'normalization_strategy': 'peak',
        },
      );

      if (prediction == null) {
        debugPrint('❌ [Replicate] Failed to create audio prediction');
        return null;
      }

      // Wait for completion
      final result = await _waitForPrediction(prediction['id'], maxWaitSeconds: 120);
      if (result == null || result['output'] == null) {
        debugPrint('❌ [Replicate] Audio generation failed or timed out');
        return null;
      }

      final audioUrl = result['output'] as String;
      debugPrint('✅ [Replicate] Audio generated successfully: $audioUrl');
      return audioUrl;
    } catch (e) {
      debugPrint('❌ [Replicate] Audio generation error: $e');
      return null;
    }
  }

  /// Create a prediction (start generation) via Cloud Function
  static Future<Map<String, dynamic>?> _createPrediction({
    required String model,
    required Map<String, dynamic> input,
  }) async {
    try {
      debugPrint('🔄 [Replicate] Creating prediction via Cloud Function');
      debugPrint('🔄 [Replicate] Model: $model');
      
      final callable = FirebaseFunctions.instance.httpsCallable('replicateProxy');
      final result = await callable.call({
        'action': 'create',
        'model': model,
        'input': input,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏱️ [Replicate] Create prediction timed out after 30s');
          throw Exception('Request timed out');
        },
      );

      if (result.data['success'] == true) {
        final prediction = result.data['prediction'] as Map<String, dynamic>;
        debugPrint('✅ [Replicate] Prediction created: ${prediction['id']}');
        return prediction;
      }

      debugPrint('❌ [Replicate] Create prediction failed');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ [Replicate] Create prediction error: $e');
      debugPrint('❌ [Replicate] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Wait for a prediction to complete via Cloud Function
  static Future<Map<String, dynamic>?> _waitForPrediction(
    String predictionId, {
    int maxWaitSeconds = 90,
  }) async {
    final startTime = DateTime.now();
    final callable = FirebaseFunctions.instance.httpsCallable('replicateProxy');
    
    while (DateTime.now().difference(startTime).inSeconds < maxWaitSeconds) {
      try {
        final result = await callable.call({
          'action': 'get',
          'predictionId': predictionId,
        });

        if (result.data['success'] == true) {
          final prediction = result.data['prediction'] as Map<String, dynamic>;
          final status = prediction['status'] as String;

          debugPrint('🔄 [Replicate] Prediction status: $status');

          if (status == 'succeeded') {
            return prediction;
          } else if (status == 'failed' || status == 'canceled') {
            debugPrint('❌ [Replicate] Prediction failed: ${prediction['error']}');
            return null;
          }

          // Still processing, wait and retry
          await Future.delayed(const Duration(seconds: 2));
        } else {
          debugPrint('❌ [Replicate] Get prediction failed');
          return null;
        }
      } catch (e) {
        debugPrint('❌ [Replicate] Wait prediction error: $e');
        return null;
      }
    }

    debugPrint('⏱️ [Replicate] Prediction timed out after ${maxWaitSeconds}s');
    return null;
  }
}
