// P05 / P24 (SPEC 8.19; flow F04): the local speech port.
//
// Rule: on-device recognition only. A port implementation must fail closed
// when the engine cannot prove on-device operation; it may never fall back to
// a server. The app holds no audio: a transcript leaves the port as text, and
// the port deletes its temporary audio as soon as a result is final.
//
// No platform package is imported here (AGENTS 6.7, 11). The native binding
// sits behind this interface; tests use a scripted port.
library;

/// SPEC 8.19: whether voice input can start, and why not.
enum SpeechAvailability {
  /// An on-device engine is present and verified for this build.
  available,

  /// The microphone permission is not granted yet (X87 explains it first).
  needsPermission,

  /// The permission was denied; manual entry stays available (F04-B).
  denied,

  /// No verified on-device engine; the screen states it and starts nothing.
  unavailable,
}

/// Safe failure codes (no transcript, audio or identifier in the text).
enum SpeechFailure {
  /// The engine is absent or cannot prove on-device operation.
  unavailable,

  /// The permission is missing.
  permissionDenied,

  /// No speech was recognised.
  noSpeech,

  /// The engine reported an error.
  engineError,
}

/// A typed speech failure. It holds a code only (AGENTS 2.6).
class SpeechException implements Exception {
  const SpeechException(this.code);

  final SpeechFailure code;

  @override
  String toString() => 'SpeechException(${code.name})';
}

/// One recognition event.
final class SpeechResult {
  const SpeechResult({required this.text, required this.isFinal});

  /// The transcript so far. It is text only; no audio leaves the engine.
  final String text;

  /// True when the engine will not extend this transcript.
  final bool isFinal;
}

/// The speech port. One call sequence is check, permission, listen, stop.
abstract interface class SpeechPort {
  /// The engine and permission state. Never opens the microphone.
  Future<SpeechAvailability> check();

  /// Asks for the microphone permission once (X87 explains it first).
  Future<bool> requestPermission();

  /// Starts on-device recognition. The stream emits partial and one final
  /// transcript. The microphone closes when the subscription cancels or
  /// [stop] runs.
  Stream<SpeechResult> listen();

  /// Ends recognition and keeps the final transcript.
  Future<void> stop();

  /// Ends recognition and discards the transcript and any temporary audio.
  Future<void> cancel();

  /// Releases the engine.
  Future<void> dispose();
}

/// The factual unavailable state: no engine, no microphone request.
///
/// The app composition mounts this until a native binding passes the SPEC 8.19
/// verification record (P24-ENGINE-EVIDENCE).
final class UnavailableSpeechPort implements SpeechPort {
  const UnavailableSpeechPort();

  @override
  Future<SpeechAvailability> check() async => SpeechAvailability.unavailable;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Stream<SpeechResult> listen() => Stream<SpeechResult>.error(
        const SpeechException(SpeechFailure.unavailable),
      );

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
