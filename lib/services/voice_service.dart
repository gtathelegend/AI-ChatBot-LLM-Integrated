import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;

  Future<bool> init() async {
    _available = await _speech.initialize();
    return _available;
  }

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  void startListening(void Function(String) onResult) {
    if (!_available) return;
    _speech.listen(
      onResult: (val) => onResult(val.recognizedWords),
      listenMode: stt.ListenMode.dictation,
    );
  }

  void stopListening() {
    _speech.stop();
  }
}
