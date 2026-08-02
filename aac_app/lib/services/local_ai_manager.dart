import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class LocalAiManager {
  // Using Qwen 2.5 0.5B Instruct GGUF as it's very small (~400MB)
  // Direct HuggingFace download link for a Q4_K_M quantized version
  static const String modelUrl = 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf?download=true';
  static const String modelFileName = 'qwen2.5-0.5b-q4.gguf';

  final Dio _dio = Dio();

  /// Checks if the device is theoretically capable of running the local model.
  Future<bool> checkHardwareSpecs() async {
    // In a production app, you would check for exact RAM (e.g., via system_info2)
    // For this prototype, we will just ensure it's a relatively modern OS.
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Require at least Android 10 (API 29)
        return androidInfo.version.sdkInt >= 29;
      } else if (Platform.isIOS) {
        // iOS devices generally handle memory better, we assume iPhone 11+ is fine
        return true;
      }
      return true; // Desktop
    } catch (e) {
      return false; // Safely fail
    }
  }

  /// Returns the absolute path where the model should be stored
  Future<String> getModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$modelFileName';
  }

  /// Checks if the model is already downloaded
  Future<bool> isModelDownloaded() async {
    final path = await getModelPath();
    final file = File(path);
    return await file.exists();
  }

  /// Deletes the local model to free up space
  Future<void> deleteModel() async {
    final path = await getModelPath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Downloads the model to the local device storage.
  /// Throws an exception if the download fails.
  Future<void> downloadModel({required void Function(double) onProgress}) async {
    final path = await getModelPath();
    
    try {
      await _dio.download(
        modelUrl,
        path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
          }
        },
        options: Options(
          // Important for large files to avoid timeout
          receiveTimeout: const Duration(hours: 1),
          sendTimeout: const Duration(minutes: 5),
        )
      );
    } catch (e) {
      // Clean up the partial file if the download fails
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      throw Exception('Failed to download model: $e');
    }
  }
}
