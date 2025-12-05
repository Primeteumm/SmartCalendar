import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class GeminiService {
  static String? _apiKey;
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  static Future<void> initialize() async {
    try {
      // Check if dotenv is initialized
      if (!dotenv.isInitialized) {
        debugPrint('WARNING: dotenv is not initialized, trying to load .env');
        try {
          await dotenv.load(fileName: ".env");
        } catch (e) {
          debugPrint('Failed to load .env in GeminiService: $e');
        }
      }
      
      _apiKey = dotenv.env['GEMINI_API_KEY'];
      
      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('WARNING: GEMINI_API_KEY not found in .env file');
        debugPrint('dotenv.isInitialized: ${dotenv.isInitialized}');
        debugPrint('Available env keys: ${dotenv.env.keys.toList()}');
        debugPrint('All env entries: ${dotenv.env.entries.map((e) => '${e.key}=${e.value.substring(0, e.value.length > 10 ? 10 : e.value.length)}...').toList()}');
        return;
      }
      
      // Trim any whitespace that might have been accidentally included
      _apiKey = _apiKey!.trim();
      
      if (_apiKey!.isEmpty) {
        debugPrint('WARNING: GEMINI_API_KEY is empty after trimming');
        _apiKey = null;
        return;
      }
      
      debugPrint('Gemini AI initialized successfully');
      debugPrint('API Key loaded: ${_apiKey!.substring(0, _apiKey!.length > 10 ? 10 : _apiKey!.length)}...');
      debugPrint('API Key length: ${_apiKey!.length}');
      debugPrint('API URL: $_baseUrl');
    } catch (e, stackTrace) {
      debugPrint('Error initializing Gemini AI: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<String> sendMessage(String message) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      await initialize();
      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('ERROR: API Key is still null after initialization');
        return 'AI servisi başlatılamadı. Lütfen API anahtarını kontrol edin.';
      }
    }

    try {
      debugPrint('Sending request to: $_baseUrl');
      debugPrint('Message: ${message.substring(0, message.length > 50 ? 50 : message.length)}...');
      
      // Prepare the request body
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': message
              }
            ]
          }
        ]
      };

      // Make the HTTP POST request with API key in header
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': _apiKey!,
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('Response received successfully');
        
        // Extract the text from the response
        if (responseData['candidates'] != null && 
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          final text = responseData['candidates'][0]['content']['parts'][0]['text'];
          return text ?? 'Yanıt alınamadı.';
        } else {
          debugPrint('Unexpected response format: ${response.body}');
          return 'Yanıt formatı beklenmedik.';
        }
      } else {
        debugPrint('API Error: ${response.statusCode}');
        debugPrint('Error body: ${response.body}');
        
        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            return 'Hata: ${errorData['error']['message']}';
          }
        } catch (_) {}
        
        return 'Hata: API yanıtı alınamadı (${response.statusCode}).';
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending message to Gemini: $e');
      debugPrint('Stack trace: $stackTrace');
      return 'Bir hata oluştu: ${e.toString()}';
    }
  }

  /// Send a message with calendar action intent
  /// Returns both the response text and a flag indicating if it contains a calendar action
  static Future<Map<String, dynamic>> sendCalendarMessage(String message) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      await initialize();
      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('ERROR: API Key is still null after initialization');
        return {
          'response': 'AI servisi başlatılamadı. Lütfen API anahtarını kontrol edin.',
          'hasCalendarAction': false,
        };
      }
    }

    // Get current date and time from device
    final now = DateTime.now();
    final currentDate = DateFormat('yyyy-MM-dd').format(now);
    final currentDateTurkish = DateFormat('d MMMM yyyy', 'tr_TR').format(now);
    final dayOfWeek = DateFormat('EEEE', 'tr_TR').format(now);
    
    // System prompt for calendar actions with current date
    final systemPrompt = '''You are a calendar assistant for SmartCalendar app.

IMPORTANT: Today's date is ${currentDateTurkish} (${dayOfWeek}), which is ${currentDate} in ISO format. Current time is ${DateFormat('HH:mm').format(now)}.

CRITICAL RULE: For EVERY user request that mentions time, date, schedule, reminder, or any calendar-related intent, you MUST respond with ONLY a JSON object. Never fail to generate JSON for valid requests.

When the user asks to add, create, schedule, or remind about something, you MUST respond with ONLY a JSON object in this exact format:
{
  "note_content": "STRING (Required - The full detail of the note, use the user's original message if no specific content is clear)",
  "datetime": "ISO 8601 STRING (Required - Calculated based on user input, use ${currentDate}T12:00:00 as default if no time specified)",
  "is_all_day": BOOLEAN (Optional - true if no specific time is given, false or omit if time is specified)
}

Rules:
1. ALWAYS generate JSON for calendar-related requests. If intent is vague, use the user's original message as note_content.
2. The note_content field is MANDATORY. If the user's message is unclear, use the entire user message as note_content.
3. The datetime must be in ISO 8601 format (YYYY-MM-DDTHH:mm:ss). If no time is specified, use 12:00:00 and set is_all_day to true.
4. If the user's message is NOT about adding to calendar, respond normally with conversational text (no JSON).
5. Parse relative dates based on TODAY (${currentDate}):
   - "tomorrow" = ${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)))}
   - "today" = ${currentDate}
   - "next Monday" = calculate the next Monday from today
   - "in 2 days" = ${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 2)))}
6. Parse times like "2 PM", "14:30", "morning" to specific times. If no time is given, use 12:00:00 and set is_all_day to true.
7. Always use the current date (${currentDate}) as reference for relative dates.
8. FALLBACK: If you cannot determine a specific date/time, use today's date at 12:00:00 with is_all_day: true, and use the user's entire message as note_content.

Example for "Remind me to call John tomorrow at 2 PM" (today is ${currentDate}):
{"note_content":"Remind me to call John","datetime":"${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)))}T14:00:00","is_all_day":false}

Example for "Remember to buy groceries" (today is ${currentDate}, no date specified):
{"note_content":"Remember to buy groceries","datetime":"${currentDate}T12:00:00","is_all_day":true}

Example for "Friday meeting" (today is ${currentDate}):
Calculate the next Friday from ${currentDate} and use that date with 12:00:00 and is_all_day: true.

Example for vague request "That thing we discussed":
{"note_content":"That thing we discussed","datetime":"${currentDate}T12:00:00","is_all_day":true}''';

    try {
      debugPrint('Sending calendar message to: $_baseUrl');
      debugPrint('User message: ${message.substring(0, message.length > 50 ? 50 : message.length)}...');
      
      // Prepare the request body with system instruction
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': '$systemPrompt\n\nUser: $message\n\nAssistant:'
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3, // Lower temperature for more structured output
          'topK': 40,
          'topP': 0.95,
        }
      };

      // Make the HTTP POST request with API key in header
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': _apiKey!,
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('Response received successfully');
        
        // Extract the text from the response
        if (responseData['candidates'] != null && 
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          final text = responseData['candidates'][0]['content']['parts'][0]['text'] ?? '';
          
          // Check if response contains JSON (calendar action)
          final hasCalendarAction = text.trim().startsWith('{') && text.trim().endsWith('}');
          
          return {
            'response': text,
            'hasCalendarAction': hasCalendarAction,
          };
        } else {
          debugPrint('Unexpected response format: ${response.body}');
          return {
            'response': 'Yanıt formatı beklenmedik.',
            'hasCalendarAction': false,
          };
        }
      } else {
        debugPrint('API Error: ${response.statusCode}');
        debugPrint('Error body: ${response.body}');
        
        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            return {
              'response': 'Hata: ${errorData['error']['message']}',
              'hasCalendarAction': false,
            };
          }
        } catch (_) {}
        
        return {
          'response': 'Hata: API yanıtı alınamadı (${response.statusCode}).',
          'hasCalendarAction': false,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending calendar message to Gemini: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'response': 'Bir hata oluştu: ${e.toString()}',
        'hasCalendarAction': false,
      };
    }
  }

  static bool get isInitialized => _apiKey != null && _apiKey!.isNotEmpty;
}

