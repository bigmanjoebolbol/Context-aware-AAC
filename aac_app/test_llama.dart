import 'dart:io';
import 'package:flutter/material.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

void main() async {
  print("Testing llama_cpp_dart initialization...");
  try {
    LlamaParent llama = LlamaParent(
      LlamaLoad(
        path: "non_existent_path.gguf",
        modelParams: ModelParams()..nGpuLayers = 99,
        contextParams: ContextParams()..nCtx = 2048,
        samplingParams: SamplerParams(),
      ),
    );
    await llama.init();
    print("Init successful!");
  } catch (e, stack) {
    print("Failed: $e");
    print(stack);
  }
}
