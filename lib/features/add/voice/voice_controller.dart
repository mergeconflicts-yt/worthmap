// P24 (SPEC 8.19; flow F04 steps 1–2): the X24/X25 voice state.
//
// The controller owns the listening state and the transcript. It never writes a
// payment, never stores audio and never reads a clock inside the domain. The
// filled review parses the transcript through the P10 parser (deterministic,
// on device) and marks the unsure fields for the person to check.
//
// A denial or an absent engine keeps manual entry (F04-B). Nothing is saved
// before Save (F04-C).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/speech/speech.dart';

/// The states of the voice flow (X87, X24, X25).
enum VoiceStage {
  /// The engine and permission are being checked.
  checking,

  /// X87 explains the microphone before the system prompt.
  permission,

  /// The permission was denied; typed entry stays.
  denied,

  /// No verified on-device engine; the screen starts nothing.
  unavailable,

  /// X24: the microphone is open and the transcript grows.
  listening,

  /// X25: the transcript is final and the form is filled.
  filled,

  /// No speech was recognised or the engine failed.
  failed,
}

/// X24/X25 state.
final class VoiceController extends ChangeNotifier {
  VoiceController({required this.port});

  final SpeechPort port;

  VoiceStage _stage = VoiceStage.checking;
  String _transcript = '';
  SpeechFailure? _failure;
  StreamSubscription<SpeechResult>? _subscription;
  bool _disposed = false;

  VoiceStage get stage => _stage;

  /// The transcript so far. Text only; no audio is retained.
  String get transcript => _transcript;

  SpeechFailure? get failure => _failure;

  /// True while the microphone is open.
  bool get isListening => _stage == VoiceStage.listening;

  /// Checks the engine and permission, then opens the microphone or states
  /// why it cannot (X87 for a first permission, a message otherwise).
  Future<void> initialize() async {
    final availability = await port.check();
    if (_disposed) {
      return;
    }
    switch (availability) {
      case SpeechAvailability.available:
        await startListening();
      case SpeechAvailability.needsPermission:
        _set(VoiceStage.permission);
      case SpeechAvailability.denied:
        _set(VoiceStage.denied);
      case SpeechAvailability.unavailable:
        _set(VoiceStage.unavailable);
    }
  }

  /// X87 "Allow microphone": one system request, then listen or deny.
  Future<void> requestPermission() async {
    final granted = await port.requestPermission();
    if (_disposed) {
      return;
    }
    if (!granted) {
      _set(VoiceStage.denied);
      return;
    }
    await startListening();
  }

  /// X87 "Not now" and a denial both keep typed entry.
  void declinePermission() => _set(VoiceStage.denied);

  /// Opens the microphone and starts one on-device recognition.
  Future<void> startListening() async {
    // The old subscription closes without blocking the new one; the new listen
    // replaces it on the port.
    unawaited(_subscription?.cancel());
    _subscription = null;
    _transcript = '';
    _failure = null;
    _set(VoiceStage.listening);
    _subscription = port.listen().listen(
      (SpeechResult result) {
        _transcript = result.text;
        if (!_disposed) {
          notifyListeners();
        }
      },
      onError: (Object _) {
        _failure = SpeechFailure.engineError;
        _set(VoiceStage.failed);
      },
    );
  }

  /// X24 "Stop": closes the microphone and holds the final transcript.
  Future<void> stop() async {
    unawaited(_subscription?.cancel());
    _subscription = null;
    // The state changes at once; the engine closes its microphone in the
    // background. No audio outlives the call.
    unawaited(port.stop());
    if (_disposed) {
      return;
    }
    if (_transcript.trim().isEmpty) {
      _failure = SpeechFailure.noSpeech;
      _set(VoiceStage.failed);
      return;
    }
    _failure = null;
    _set(VoiceStage.filled);
  }

  /// X25 "Speak again": clears the transcript and reopens the microphone.
  Future<void> speakAgain() async {
    _transcript = '';
    await startListening();
  }

  /// Close: stops recognition and clears the transcript (no record is written).
  Future<void> cancel() async {
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(port.cancel());
    _transcript = '';
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _set(VoiceStage stage) {
    if (_disposed) {
      return;
    }
    _stage = stage;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
