import 'package:flutter_tts/flutter_tts.dart';

class AudioFeedbackService {
  final FlutterTts _tts = FlutterTts();

  Future<void> init() async {
    try {
      await _tts.setLanguage("th-TH");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
  }
}