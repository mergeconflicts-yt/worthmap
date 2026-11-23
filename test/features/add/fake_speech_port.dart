import 'dart:async';

import 'package:contour/data/speech/speech.dart';

/// A scripted on-device speech port for the P24 tests. It reads no microphone.
final class ScriptedSpeechPort implements SpeechPort {
  ScriptedSpeechPort({
    this.availability = SpeechAvailability.available,
    this.granted = true,
    List<String>? parts,
    this.error,
  }) : parts = parts ?? <String>['Spent 40 dollars on coffee today'];

  SpeechAvailability availability;
  bool granted;
  List<String> parts;
  SpeechFailure? error;

  int checkCalls = 0;
  int permissionCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;

  StreamController<SpeechResult>? _active;

  @override
  Future<SpeechAvailability> check() async {
    checkCalls += 1;
    return availability;
  }

  @override
  Future<bool> requestPermission() async {
    permissionCalls += 1;
    return granted;
  }

  @override
  Stream<SpeechResult> listen() {
    listenCalls += 1;
    final controller = StreamController<SpeechResult>();
    _active = controller;
    final failure = error;
    if (failure != null) {
      controller.addError(SpeechException(failure));
      return controller.stream;
    }
    for (final part in parts) {
      controller.add(SpeechResult(text: part, isFinal: false));
    }
    controller.add(
      SpeechResult(text: parts.isEmpty ? '' : parts.last, isFinal: true),
    );
    return controller.stream;
  }

  /// Pushes one partial transcript from the engine.
  void emit(String text) {
    final controller = _active;
    if (controller != null && !controller.isClosed) {
      controller.add(SpeechResult(text: text, isFinal: false));
    }
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
    await _active?.close();
    _active = null;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _active?.close();
    _active = null;
  }
}
