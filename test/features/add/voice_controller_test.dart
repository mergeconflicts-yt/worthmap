import 'package:contour/data/speech/speech.dart';
import 'package:contour/features/add/voice/voice_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_speech_port.dart';

void main() {
  test('an available engine opens the microphone and grows the transcript',
      () async {
    final port = ScriptedSpeechPort(parts: <String>['Spent 40']);
    final controller = VoiceController(port: port);

    await controller.initialize();
    await pumpEventQueue();

    expect(controller.stage, VoiceStage.listening);
    expect(port.listenCalls, 1);
    expect(controller.transcript, 'Spent 40');
    controller.dispose();
  });

  test('a first permission shows X87, then Allow opens the microphone',
      () async {
    final port = ScriptedSpeechPort(
      availability: SpeechAvailability.needsPermission,
      parts: <String>['Coffee 4'],
    );
    final controller = VoiceController(port: port);
    await controller.initialize();
    await pumpEventQueue();
    expect(controller.stage, VoiceStage.permission);
    expect(port.listenCalls, 0, reason: 'no request before the explainer');

    await controller.requestPermission();

    expect(port.permissionCalls, 1);
    expect(controller.stage, VoiceStage.listening);
    controller.dispose();
  });

  test('a denied permission keeps typed entry and starts nothing', () async {
    final port = ScriptedSpeechPort(
      availability: SpeechAvailability.needsPermission,
      granted: false,
    );
    final controller = VoiceController(port: port);
    await controller.initialize();
    await pumpEventQueue();
    await controller.requestPermission();

    expect(controller.stage, VoiceStage.denied);
    expect(port.listenCalls, 0);
    controller.dispose();
  });

  test('an unavailable engine starts no request', () async {
    final port = ScriptedSpeechPort(
      availability: SpeechAvailability.unavailable,
    );
    final controller = VoiceController(port: port);
    await controller.initialize();
    await pumpEventQueue();

    expect(controller.stage, VoiceStage.unavailable);
    expect(port.listenCalls, 0);
    expect(port.permissionCalls, 0);
    controller.dispose();
  });

  test('Stop holds the transcript and moves to the filled state', () async {
    final port = ScriptedSpeechPort(parts: <String>['Lunch 18 at Subway']);
    final controller = VoiceController(port: port);
    await controller.initialize();
    await pumpEventQueue();

    await controller.stop();

    expect(port.stopCalls, 1);
    expect(controller.stage, VoiceStage.filled);
    expect(controller.transcript, 'Lunch 18 at Subway');
    controller.dispose();
  });

  test('Stop with no words reports no speech and saves nothing', () async {
    final port = ScriptedSpeechPort(parts: <String>[]);
    final controller = VoiceController(port: port);
    await controller.initialize();
    await pumpEventQueue();

    await controller.stop();

    expect(controller.stage, VoiceStage.failed);
    expect(controller.failure, SpeechFailure.noSpeech);
    controller.dispose();
  });

  test('Speak again clears the transcript and reopens the microphone',
      () async {
    final port = ScriptedSpeechPort(parts: <String>['First']);
    final controller = VoiceController(port: port);
    await controller.initialize();
    await pumpEventQueue();
    await controller.stop();
    expect(controller.transcript, 'First');

    await controller.speakAgain();
    await pumpEventQueue();

    expect(controller.stage, VoiceStage.listening);
    expect(controller.transcript, 'First', reason: 'the scripted replay');
    expect(port.listenCalls, 2);
    controller.dispose();
  });

  test('Close cancels recognition and clears the transcript', () async {
    final port = ScriptedSpeechPort(parts: <String>['Some words']);
    final controller = VoiceController(port: port);
    await controller.initialize();
    await pumpEventQueue();

    await controller.cancel();

    expect(port.cancelCalls, 1);
    expect(controller.transcript, isEmpty);
    controller.dispose();
  });

  test('an engine error is a safe failed state', () async {
    final port = ScriptedSpeechPort(error: SpeechFailure.engineError);
    final controller = VoiceController(port: port);
    await controller.initialize();
    await pumpEventQueue();
    await pumpEventQueue();

    expect(controller.stage, VoiceStage.failed);
    expect(controller.failure, SpeechFailure.engineError);
    controller.dispose();
  });
}
