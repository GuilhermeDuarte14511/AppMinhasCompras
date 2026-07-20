import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../application/ports.dart';

class SpeechToTextShoppingVoiceRecognitionService
    implements ShoppingVoiceRecognitionService {
  SpeechToTextShoppingVoiceRecognitionService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function(String status) onStatus,
  }) {
    return _speech.initialize(
      onError: (SpeechRecognitionError error) => onError(error.errorMsg),
      onStatus: onStatus,
    );
  }

  @override
  Future<void> startListening({
    required void Function(ShoppingVoiceRecognitionUpdate update) onResult,
    String localeId = 'pt_BR',
  }) async {
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(
          ShoppingVoiceRecognitionUpdate(
            words: result.recognizedWords,
            isFinal: result.finalResult,
          ),
        );
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        localeId: localeId,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Future<void> stopListening() => _speech.stop();

  @override
  Future<void> cancelListening() => _speech.cancel();
}
