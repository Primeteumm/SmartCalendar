import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// Callback for real-time transcription updates
typedef TranscriptionCallback = void Function(String text);

/// Service for handling voice input and speech-to-text conversion
class VoiceService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _isInitialized = false;
  static bool _isListening = false;

  /// Initialize the speech-to-text service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('Microphone permission denied');
        return false;
      }

      // Initialize speech-to-text
      final available = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: $error');
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );

      _isInitialized = available;
      debugPrint('VoiceService initialized: $available');
      return available;
    } catch (e) {
      debugPrint('Error initializing VoiceService: $e');
      return false;
    }
  }

  /// Check if speech recognition is available
  static bool get isAvailable => _isInitialized && _speech.isAvailable;

  /// Check if currently listening
  static bool get isListening => _isListening;

  /// Start listening for speech input
  /// Returns the recognized text when listening stops
  static Future<String?> listen({
    TranscriptionCallback? onTranscription,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return null;
      }
    }

    if (_isListening) {
      debugPrint('Already listening');
      return null;
    }

    try {
      String? finalResult;
      
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          
          // Call real-time callback
          if (onTranscription != null) {
            onTranscription(text);
          }

          // If result is final, store it
          if (result.finalResult) {
            finalResult = text;
            _isListening = false;
          }
        },
        listenFor: const Duration(seconds: 30), // Max 30 seconds
        pauseFor: const Duration(seconds: 3), // Pause after 3 seconds of silence
        partialResults: true, // Get real-time results
        localeId: 'tr_TR', // Turkish locale (can be made configurable)
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation, // Better for commands
      );

      _isListening = true;
      debugPrint('Started listening...');

      // Wait for listening to complete (max 35 seconds)
      int waitCount = 0;
      while (_isListening && waitCount < 70) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }

      // If still listening, stop it
      if (_isListening) {
        await stop();
      }

      return finalResult?.trim().isNotEmpty == true ? finalResult : null;
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      _isListening = false;
      return null;
    }
  }

  /// Stop listening
  static Future<void> stop() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      debugPrint('Stopped listening');
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
      _isListening = false;
    }
  }

  /// Cancel listening
  static Future<void> cancel() async {
    try {
      await _speech.cancel();
      _isListening = false;
      debugPrint('Cancelled listening');
    } catch (e) {
      debugPrint('Error cancelling speech recognition: $e');
      _isListening = false;
    }
  }

  /// Check microphone permission
  static Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  static Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
}

