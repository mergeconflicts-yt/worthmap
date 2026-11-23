// P24 (SPEC 8.19): the platform speech binding behind the port.
//
// The native side reports a verification record: engine name, version, an
// on-device flag and a verified flag. This adapter mounts only when both flags
// are true. Any missing plugin, timeout or false flag resolves to
// `unavailable`; there is no cloud fallback and no retry to a server (SPEC
// 8.19).
//
// The engine audio stays inside the platform recogniser. The channel carries
// text only, and `cancel` tells the native side to delete temporary audio.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'speech.dart';

/// The method channel name. The native builder implements the same name.
const String speechChannelName = 'contour/speech';

/// The event channel name for partial transcripts.
const String speechEventChannelName = 'contour/speech_events';

/// A method-channel binding. Fail closed by default.
final class PlatformSpeechPort implements SpeechPort {
  PlatformSpeechPort({
    MethodChannel? channel,
    EventChannel? events,
  })  : _channel = channel ?? const MethodChannel(speechChannelName),
        _events = events ?? const EventChannel(speechEventChannelName);

  final MethodChannel _channel;
  final EventChannel _events;
  StreamSubscription<Object?>? _active;

  @override
  Future<SpeechAvailability> check() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('check');
      if (result == null) {
        return SpeechAvailability.unavailable;
      }
      final verified = result['verified'] == true;
      final onDevice = result['onDevice'] == true;
      if (!verified || !onDevice) {
        return SpeechAvailability.unavailable;
      }
      return switch (result['permission']) {
        'granted' => SpeechAvailability.available,
        'denied' => SpeechAvailability.denied,
        _ => SpeechAvailability.needsPermission,
      };
    } on MissingPluginException {
      return SpeechAvailability.unavailable;
    } on PlatformException {
      return SpeechAvailability.unavailable;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Stream<SpeechResult> listen() {
    final controller = StreamController<SpeechResult>();
    _active = _events.receiveBroadcastStream().listen(
      (Object? event) {
        if (event is! Map) {
          return;
        }
        final text = event['text'];
        if (text is! String) {
          return;
        }
        controller.add(
          SpeechResult(text: text, isFinal: event['final'] == true),
        );
      },
      onError: (Object error) {
        controller.addError(
          error is SpeechException
              ? error
              : const SpeechException(SpeechFailure.engineError),
        );
      },
      cancelOnError: false,
    );
    controller.onCancel = () async {
      await _active?.cancel();
      _active = null;
    };
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Nothing is listening; the stream closes on its own.
    } on PlatformException {
      // The engine already stopped.
    }
  }

  @override
  Future<void> cancel() async {
    await _active?.cancel();
    _active = null;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // No native side to clean.
    } on PlatformException {
      // The native side already cleaned its temporary audio.
    }
  }

  @override
  Future<void> dispose() async {
    await cancel();
  }
}
