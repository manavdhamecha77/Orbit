import 'package:flutter/services.dart';

import 'dart:async';

class LlmService {
  static const MethodChannel _channel = MethodChannel('offline_ai/llm');
  static const EventChannel _streamChannel = EventChannel(
    'offline_ai/llm_stream',
  );

  Future<String> initialize() async {
    final result = await _channel.invokeMethod<String>('loadModel');
    return result ?? 'Default Model';
  }

  Future<String> pickModel() async {
    final result = await _channel.invokeMethod<String>('pickModel');
    return result ?? 'Default Model';
  }

  Future<void> stopGeneration() async {
    await _channel.invokeMethod('stopGeneration');
  }

  Stream<String> generate(String prompt) async* {
    final controller = StreamController<String>();
    final subscription = _streamChannel
        .receiveBroadcastStream()
        .cast<String>()
        .listen((chunk) {
          if (chunk == '__DONE__') {
            controller.close();
          } else {
            controller.add(chunk);
          }
        }, onError: controller.addError);
    final generation = _channel.invokeMethod<String>('generate', {
      'prompt': prompt,
    });
    unawaited(
      generation.then(
        (_) {
          if (!controller.isClosed) controller.close();
        },
        onError: (Object error, StackTrace stack) {
          if (!controller.isClosed) controller.addError(error, stack);
          if (!controller.isClosed) controller.close();
        },
      ),
    );
    try {
      yield* controller.stream;
    } finally {
      await subscription.cancel();
      await controller.close();
    }
  }
}
