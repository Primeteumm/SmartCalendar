import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class GeminiService {
  static String? _apiKey;
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

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
        return 'AI service could not be initialized. Please check your API key.';
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
          return text ?? 'No response received.';
        } else {
          debugPrint('Unexpected response format: ${response.body}');
          return 'Unexpected response format.';
        }
      } else {
        debugPrint('API Error: ${response.statusCode}');
        debugPrint('Error body: ${response.body}');
        
        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            return 'Error: ${errorData['error']['message']}';
          }
        } catch (_) {}
        
        return 'Error: Could not get API response (${response.statusCode}).';
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending message to Gemini: $e');
      debugPrint('Stack trace: $stackTrace');
      return 'An error occurred: ${e.toString()}';
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
          'response': 'AI service could not be initialized. Please check your API key.',
          'hasCalendarAction': false,
        };
      }
    }

    // Get current date and time from device
    final now = DateTime.now();
    final currentDate = DateFormat('yyyy-MM-dd').format(now);
    final currentDateEnglish = DateFormat('d MMMM yyyy', 'en_US').format(now);
    final dayOfWeek = DateFormat('EEEE', 'en_US').format(now);
    
    // System prompt for calendar actions with current date
    final systemPrompt = '''You are a calendar assistant for SmartCalendar app.

IMPORTANT: Today's date is ${currentDateEnglish} (${dayOfWeek}), which is ${currentDate} in ISO format. Current time is ${DateFormat('HH:mm').format(now)}.

CRITICAL RULE: For EVERY user request that mentions time, date, schedule, reminder, or any calendar-related intent, you MUST respond with ONLY a JSON object. Never fail to generate JSON for valid requests.

When the user asks to add, create, schedule, or remind about something, you MUST respond with ONLY a JSON object in this exact format:
{
  "note_content": "STRING (Required - The full detail of the note, use the user's original message if no specific content is clear)",
  "datetime": "ISO 8601 STRING (Required - Calculated based on user input, use ${currentDate}T12:00:00 as default if no time specified)",
  "is_all_day": BOOLEAN (Optional - true if no specific time is given, false or omit if time is specified),
  "category": "STRING (Required - Must be one of: School, Work, Social, Health, General)",
  "color_hex": "STRING (Required - Hex color code matching the category: School=#FF0000, Work=#0000FF, Social=#FFA500, Health=#00FF00, General=#808080)"
}

CATEGORY ASSIGNMENT RULES:
- "School": Exams, classes, homework, study sessions, academic events → Color: #FF0000 (Red)
- "Work": Meetings, deadlines, work tasks, professional events → Color: #0000FF (Blue)
- "Social": Parties, hangouts, dates, social gatherings, friends → Color: #FFA500 (Orange)
- "Health": Gym, doctor appointments, workouts, medical, fitness → Color: #00FF00 (Green)
- "General": Everything else, vague requests, unclear intent → Color: #808080 (Grey)

Analyze the event content carefully and assign the most appropriate category. Examples:
- "Math Exam" → category: "School", color_hex: "#FF0000"
- "Gym session" → category: "Health", color_hex: "#00FF00"
- "Team meeting" → category: "Work", color_hex: "#0000FF"
- "Birthday party" → category: "Social", color_hex: "#FFA500"
- "Remind me to..." (vague) → category: "General", color_hex: "#808080"

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
{"note_content":"Remind me to call John","datetime":"${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)))}T14:00:00","is_all_day":false,"category":"General","color_hex":"#808080"}

Example for "Math Exam next Monday" (today is ${currentDate}):
{"note_content":"Math Exam","datetime":"[calculate next Monday]T09:00:00","is_all_day":false,"category":"School","color_hex":"#FF0000"}

Example for "Gym session tomorrow" (today is ${currentDate}):
{"note_content":"Gym session","datetime":"${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)))}T18:00:00","is_all_day":false,"category":"Health","color_hex":"#00FF00"}

Example for "Team meeting Friday" (today is ${currentDate}):
{"note_content":"Team meeting","datetime":"[calculate next Friday]T14:00:00","is_all_day":false,"category":"Work","color_hex":"#0000FF"}

Example for "Birthday party Saturday" (today is ${currentDate}):
{"note_content":"Birthday party","datetime":"[calculate next Saturday]T19:00:00","is_all_day":false,"category":"Social","color_hex":"#FFA500"}

Example for vague request "That thing we discussed":
{"note_content":"That thing we discussed","datetime":"${currentDate}T12:00:00","is_all_day":true,"category":"General","color_hex":"#808080"}''';

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
            'response': 'Unexpected response format.',
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
              'response': 'Error: ${errorData['error']['message']}',
              'hasCalendarAction': false,
            };
          }
        } catch (_) {}
        
        return {
            'response': 'Error: Could not get API response (${response.statusCode}).',
          'hasCalendarAction': false,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending calendar message to Gemini: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'response': 'An error occurred: ${e.toString()}',
        'hasCalendarAction': false,
      };
    }
  }

  /// Process a brain dump text and extract multiple items (events, tasks, notes)
  /// Returns a list of parsed items
  static Future<List<Map<String, dynamic>>> processBrainDump(String brainDumpText) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      await initialize();
      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('ERROR: API Key is still null after initialization');
        return [];
      }
    }

    // Get current date and time from device
    final now = DateTime.now();
    final currentDate = DateFormat('yyyy-MM-dd').format(now);
    final currentDateEnglish = DateFormat('d MMMM yyyy', 'en_US').format(now);
    final dayOfWeek = DateFormat('EEEE', 'en_US').format(now);
    final currentTime = DateFormat('HH:mm').format(now);

    // System prompt for brain dump processing
    final systemPrompt = '''You are an intelligent personal secretary for SmartCalendar app.

IMPORTANT: Current Time: ${currentDateEnglish} (${dayOfWeek}), which is ${currentDate} in ISO format. Current time is ${currentTime}.

TASK: Analyze the user's raw stream of consciousness text (brain dump). Identify distinct items and categorize them.

CATEGORIES:
- "event": Has a specific date/time (e.g., "Meeting tomorrow at 2 PM", "Physics exam on Dec 15")
- "task": A todo item or reminder without specific time (e.g., "Buy milk", "Call Mom", "Finish homework")
- "note": General information or note (e.g., "Remember that John likes coffee", "Project deadline is next month")

OUTPUT FORMAT - JSON ARRAY:
You MUST respond with ONLY a JSON ARRAY. Each item in the array represents one distinct item extracted from the brain dump.

[
  {
    "type": "event",  // Required: "event", "task", or "note"
    "title": "STRING (Required - Short title)", 
    "datetime": "ISO 8601 STRING (Required for events - Format: YYYY-MM-DDTHH:mm:ss. Calculate based on current context: ${currentDate})",
    "description": "STRING (Optional - Additional details)",
    "category": "STRING (Optional - School, Work, Social, Health, General)",
    "color_hex": "STRING (Optional - Hex color code)"
  },
  {
    "type": "task",
    "title": "STRING (Required)",
    "description": "STRING (Optional)",
    "priority": "STRING (Optional - high, medium, low)",
    "due_date": "ISO 8601 STRING (Optional - Format: YYYY-MM-DDTHH:mm:ss)"
  },
  {
    "type": "note",
    "title": "STRING (Required)",
    "description": "STRING (Optional - Full note content)",
    "date": "ISO 8601 STRING (Optional - Format: YYYY-MM-DDTHH:mm:ss)"
  }
]

RULES:
1. Extract ALL distinct items from the brain dump. Don't miss anything.
2. For events: Must have datetime field. Parse relative dates based on TODAY (${currentDate}):
   - "tomorrow" = ${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)))}
   - "next Monday" = calculate the next Monday from today
   - "Dec 15" = ${now.year}-12-15 (or next year if already passed)
   - If no time specified, use 12:00:00
3. For tasks: If no due_date, use today's date. Priority can be inferred from urgency words.
4. For notes: Use today's date if not specified.
5. Be smart about categorization:
   - School/Education keywords → category: "School", color_hex: "#FF0000"
   - Work/Professional keywords → category: "Work", color_hex: "#0000FF"
   - Social/Friends keywords → category: "Social", color_hex: "#FFA500"
   - Health/Fitness keywords → category: "Health", color_hex: "#00FF00"
   - Default → category: "General", color_hex: "#808080"
6. If the brain dump is empty or contains no actionable items, return an empty array [].

EXAMPLES:

Input: "Remind me to buy milk and I have a physics exam tomorrow at 9 AM"
Output:
[
  {
    "type": "task",
    "title": "Buy milk",
    "description": "Remind me to buy milk",
    "priority": "medium",
    "due_date": "${currentDate}T12:00:00"
  },
  {
    "type": "event",
    "title": "Physics exam",
    "datetime": "${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)))}T09:00:00",
    "description": "Physics exam",
    "category": "School",
    "color_hex": "#FF0000"
  }
]

Input: "Meeting with Ali on Friday at 2 PM, call Mom this weekend, remember that project deadline is next month"
Output:
[
  {
    "type": "event",
    "title": "Meeting with Ali",
    "datetime": "[calculate next Friday]T14:00:00",
    "description": "Meeting with Ali",
    "category": "Work",
    "color_hex": "#0000FF"
  },
  {
    "type": "task",
    "title": "Call Mom",
    "description": "Call Mom this weekend",
    "priority": "medium",
    "due_date": "${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 6)))}T12:00:00"
  },
  {
    "type": "note",
    "title": "Project deadline",
    "description": "Project deadline is next month",
    "date": "${currentDate}T12:00:00"
  }
]

Now analyze this brain dump and return ONLY the JSON array:''';

    try {
      debugPrint('Processing brain dump: ${brainDumpText.substring(0, brainDumpText.length > 50 ? 50 : brainDumpText.length)}...');

      // Prepare the request body
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': '$systemPrompt\n\nUser Brain Dump:\n$brainDumpText\n\nAssistant (JSON array only):'
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

      // Make the HTTP POST request
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': _apiKey!,
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('Brain dump response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Extract the text from the response
        if (responseData['candidates'] != null &&
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          final text = responseData['candidates'][0]['content']['parts'][0]['text'] ?? '';
          
          debugPrint('Brain dump AI response: $text');

          // Extract JSON array from response
          String? jsonString = _extractJsonArray(text);
          
          if (jsonString == null) {
            debugPrint('No JSON array found in response');
            return [];
          }

          // Parse JSON array
          try {
            final jsonArray = jsonDecode(jsonString) as List;
            final items = jsonArray.map((item) => item as Map<String, dynamic>).toList();
            
            debugPrint('Successfully parsed ${items.length} items from brain dump');
            return items;
          } catch (e) {
            debugPrint('Error parsing JSON array: $e');
            return [];
          }
        } else {
          debugPrint('Unexpected response format: ${response.body}');
          return [];
        }
      } else {
        debugPrint('API Error: ${response.statusCode}');
        debugPrint('Error body: ${response.body}');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('Error processing brain dump: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Extract JSON array from response text
  static String? _extractJsonArray(String response) {
    // Remove leading/trailing whitespace
    String cleaned = response.trim();

    // Try to find JSON in markdown code blocks
    final codeBlockRegex = RegExp(r'```(?:json)?\s*\n?(.*?)\n?```', dotAll: true);
    final codeBlockMatch = codeBlockRegex.firstMatch(cleaned);
    if (codeBlockMatch != null) {
      cleaned = codeBlockMatch.group(1)?.trim() ?? cleaned;
    }

    // Try to find JSON array directly (starts with [ and ends with ])
    final jsonArrayRegex = RegExp(r'\[[^\]]*(?:\[[^\]]*\][^\]]*)*\]', dotAll: true);
    final jsonMatch = jsonArrayRegex.firstMatch(cleaned);
    if (jsonMatch != null) {
      return jsonMatch.group(0);
    }

    // If the whole response looks like a JSON array, try it
    if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
      return cleaned;
    }

    return null;
  }

  /// Scan an image and extract calendar events
  /// 
  /// [imageBase64] - Base64 encoded image string
  /// [mimeType] - MIME type of the image (e.g., 'image/jpeg', 'image/png')
  /// Returns a list of CalendarAction objects extracted from the image
  static Future<List<Map<String, dynamic>>> scanScheduleImage(
    String imageBase64,
    String mimeType,
  ) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      await initialize();
      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('ERROR: API Key is still null after initialization');
        return [];
      }
    }

    // Get current date and time from device
    final now = DateTime.now();
    final currentDate = DateFormat('yyyy-MM-dd').format(now);
    final currentDateEnglish = DateFormat('d MMMM yyyy', 'en_US').format(now);
    final dayOfWeek = DateFormat('EEEE', 'en_US').format(now);
    
    // System prompt for extracting events from image
    final systemPrompt = '''You are a calendar assistant for SmartCalendar app that analyzes images of schedules, flyers, or event documents.

IMPORTANT: Today's date is ${currentDateEnglish} (${dayOfWeek}), which is ${currentDate} in ISO format. Current time is ${DateFormat('HH:mm').format(now)}.

TASK: Analyze the provided image (which is likely a schedule, exam timetable, class syllabus, or event flyer). Extract EVERY event, appointment, exam, meeting, or important date mentioned in the image.

CRITICAL: You MUST respond with ONLY a JSON ARRAY. Each item in the array represents one event.

OUTPUT FORMAT - JSON ARRAY:
[
  {
    "note_content": "STRING (Required - The full description of the event, e.g., 'Math Final Exam' or 'Dentist Appointment')",
    "datetime": "ISO 8601 STRING (Required - Format: YYYY-MM-DDTHH:mm:ss. Calculate year based on current context if missing. Use ${currentDate} as reference)",
    "is_all_day": BOOLEAN (Optional - true if no specific time is given, false or omit if time is specified)
  },
  ... (more items)
]

RULES:
1. Extract ALL events from the image. Do not miss any dates or appointments.
2. The note_content field is MANDATORY. Use the exact text from the image if possible, or create a clear description.
3. The datetime must be in ISO 8601 format (YYYY-MM-DDTHH:mm:ss).
4. If the image shows dates without years, use the current year (${now.year}) or the next year if the date has already passed this year.
5. If no time is specified for an event, use 12:00:00 and set is_all_day to true.
6. Parse relative dates based on TODAY (${currentDate}):
   - "Monday" = next Monday from today
   - "Oct 12" = ${now.year}-10-12 (or next year if already passed)
   - "Tomorrow" = ${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)))}
7. If you cannot determine a specific date/time, use today's date at 12:00:00 with is_all_day: true.
8. Return an empty array [] if no events are found in the image.

EXAMPLE OUTPUT:
[
  {
    "note_content": "Math Final Exam",
    "datetime": "${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 7)))}T14:00:00",
    "is_all_day": false
  },
  {
    "note_content": "Physics Lab Session",
    "datetime": "${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 3)))}T10:00:00",
    "is_all_day": false
  },
  {
    "note_content": "Holiday - No Classes",
    "datetime": "${DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 10)))}T12:00:00",
    "is_all_day": true
  }
]

Now analyze the image and return ONLY the JSON array, no other text.''';

    try {
      debugPrint('Scanning schedule image with Gemini API');
      debugPrint('Image size: ${imageBase64.length} characters (Base64)');
      debugPrint('MIME type: $mimeType');
      
      // Prepare the request body with image and text
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': systemPrompt
              },
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': imageBase64
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2, // Lower temperature for more structured output
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
          
          debugPrint('AI Response: ${text.substring(0, text.length > 200 ? 200 : text.length)}...');
          
          // Parse JSON array from response
          final events = _parseEventsFromResponse(text);
          debugPrint('Parsed ${events.length} events from image');
          
          return events;
        } else {
          debugPrint('Unexpected response format: ${response.body}');
          return [];
        }
      } else {
        debugPrint('API Error: ${response.statusCode}');
        debugPrint('Error body: ${response.body}');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('Error scanning schedule image: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Parse JSON array from AI response text
  /// Handles cases where JSON is wrapped in markdown code blocks or mixed with text
  static List<Map<String, dynamic>> _parseEventsFromResponse(String response) {
    try {
      // Remove leading/trailing whitespace
      String cleaned = response.trim();

      // Try to find JSON array in markdown code blocks (```json ... ``` or ``` ... ```)
      final codeBlockRegex = RegExp(r'```(?:json)?\s*\n?(\[.*?\])\n?```', dotAll: true);
      final codeBlockMatch = codeBlockRegex.firstMatch(cleaned);
      if (codeBlockMatch != null) {
        cleaned = codeBlockMatch.group(1)?.trim() ?? cleaned;
      }

      // Try to find JSON array directly (starts with [ and ends with ])
      final jsonArrayRegex = RegExp(r'\[[^\]]*(?:\[[^\]]*\][^\]]*)*\]', dotAll: true);
      final jsonMatch = jsonArrayRegex.firstMatch(cleaned);
      if (jsonMatch != null) {
        cleaned = jsonMatch.group(0) ?? cleaned;
      }

      // If the whole response looks like JSON array, try it
      if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
        final decoded = jsonDecode(cleaned) as List;
        return decoded.cast<Map<String, dynamic>>();
      }

      // Try to parse as-is
      final decoded = jsonDecode(cleaned) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error parsing events from response: $e');
      debugPrint('Response text: ${response.substring(0, response.length > 500 ? 500 : response.length)}');
      return [];
    }
  }

  /// Ask a question about the calendar schedule
  /// 
  /// [userQuestion] - The user's question about their schedule
  /// [calendarContext] - Formatted text containing upcoming events/notes
  /// Returns the AI's response as a string
  static Future<String> askCalendar(String userQuestion, String calendarContext) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      await initialize();
      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('ERROR: API Key is still null after initialization');
        return 'AI service could not be initialized. Please check your API key.';
      }
    }

    // Get current date and time from device
    final now = DateTime.now();
    final currentTime = DateFormat('HH:mm').format(now);
    final currentDateEnglish = DateFormat('d MMMM yyyy', 'en_US').format(now);
    final dayOfWeek = DateFormat('EEEE', 'en_US').format(now);
    
    // System prompt for calendar Q&A
    final systemPrompt = '''You are a helpful personal secretary for SmartCalendar app.

Current Time: ${now.toIso8601String()} (${currentDateEnglish}, ${dayOfWeek}, ${currentTime})

Here is the user's upcoming schedule for the next 14 days:

${calendarContext}

CRITICAL RULES:
1. Answer the user's question based ONLY on the schedule provided above.
2. If the schedule is empty for a specific day or time period, explicitly say so. Do not invent events.
3. If the user asks about a date/time that is not in the schedule, tell them there are no events scheduled for that period.
4. Be friendly, concise, and helpful.
5. Use English language for your responses.
6. When mentioning dates, use the format from the schedule (YYYY-MM-DD) or natural language.
7. If asked about availability, check the schedule and identify free time slots.
8. Do not make up or assume events that are not in the schedule.

User's Question: $userQuestion

Assistant:''';

    try {
      debugPrint('Asking calendar question: ${userQuestion.substring(0, userQuestion.length > 50 ? 50 : userQuestion.length)}...');
      
      // Prepare the request body
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': systemPrompt
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7, // Balanced temperature for conversational responses
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
          return text.isNotEmpty ? text : 'No response received.';
        } else {
          debugPrint('Unexpected response format: ${response.body}');
          return 'Unexpected response format.';
        }
      } else {
        debugPrint('API Error: ${response.statusCode}');
        debugPrint('Error body: ${response.body}');
        
        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            return 'Error: ${errorData['error']['message']}';
          }
        } catch (_) {}
        
        return 'Error: Could not get API response (${response.statusCode}).';
      }
    } catch (e, stackTrace) {
      debugPrint('Error asking calendar question: $e');
      debugPrint('Stack trace: $stackTrace');
      return 'An error occurred: ${e.toString()}';
    }
  }

  /// Generate a personalized daily morning briefing
  /// 
  /// [events] - List of upcoming events/notes for today
  /// [weather] - Current weather information (e.g., "Ankara: 15°C, Rainy")
  /// [userName] - User's name for personalization
  /// [cityName] - Optional city name for location-based personalization
  /// Returns AI-generated briefing text
  static Future<String> generateDailyBriefing(
    List<Map<String, dynamic>> events,
    String weather,
    String userName, {
    String? cityName,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      await initialize();
      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('ERROR: API Key is still null after initialization');
        return 'Daily briefing could not be generated. Please check your API key.';
      }
    }

    // Get current date and time from device
    final now = DateTime.now();
    final currentDate = DateFormat('d MMMM yyyy', 'en_US').format(now);
    final dayOfWeek = DateFormat('EEEE', 'en_US').format(now);
    
    // Format events as text
    String eventsText = 'No events scheduled for today.';
    if (events.isNotEmpty) {
      final buffer = StringBuffer();
      for (final event in events) {
        final title = event['title'] ?? event['note_content'] ?? 'Event';
        final time = event['time'] ?? event['datetime'] ?? 'All Day';
        buffer.writeln('- $time: $title');
      }
      eventsText = buffer.toString();
    }
    
    // Build location context
    final locationContext = cityName != null && cityName.isNotEmpty
        ? 'User Location: $cityName\n- Weather: $weather'
        : '- Weather: $weather';

    // System prompt for daily briefing
    final systemPrompt = '''You are a cheerful, energetic personal assistant for SmartCalendar app.

Current Context:
- User Name: $userName
- Date: $currentDate ($dayOfWeek)
$locationContext
- Today's Schedule:
$eventsText

Task: Write a 2-3 sentence morning briefing in English.

Rules:
1. Personalize the greeting with the user's name ($userName).${cityName != null && cityName.isNotEmpty ? ' If relevant, you can mention the city ($cityName) in a natural way.' : ''}
2. Give specific advice based on the weather (e.g., "It will rain, don't forget your umbrella" for rain, "It's a sunny day, you can spend time outdoors" for clear weather).
3. Highlight the most important event from today's schedule. If there are no events, mention that they have a free day.
4. Be friendly, energetic, and encouraging.
5. Keep it concise (2-3 sentences maximum).
6. Use English language.

Output: Plain text only, no markdown, no JSON, just the briefing text.

Example format:
"Hello $userName!${cityName != null && cityName.isNotEmpty ? ' Good morning from $cityName!' : ''} Today is $currentDate, $dayOfWeek. Weather: $weather. [Weather advice]. [Schedule highlight]. Have a great day!"

Now generate the briefing:''';

    try {
      debugPrint('Generating daily briefing for: $userName');
      
      // Prepare the request body
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': systemPrompt
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.8, // Higher temperature for more creative, friendly responses
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
        debugPrint('Briefing response received successfully');
        
        // Extract the text from the response
        if (responseData['candidates'] != null && 
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          final text = responseData['candidates'][0]['content']['parts'][0]['text'] ?? '';
          return text.isNotEmpty ? text.trim() : 'Daily briefing could not be generated.';
        } else {
          debugPrint('Unexpected response format: ${response.body}');
          return 'Unexpected daily briefing format.';
        }
      } else {
        debugPrint('API Error: ${response.statusCode}');
        debugPrint('Error body: ${response.body}');
        
        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            return 'Error: ${errorData['error']['message']}';
          }
        } catch (_) {}
        
        return 'Daily briefing could not be retrieved (${response.statusCode}).';
      }
    } catch (e, stackTrace) {
      debugPrint('Error generating daily briefing: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Check if it's a network error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('socketexception') || 
          errorString.contains('failed host lookup') ||
          errorString.contains('network') ||
          errorString.contains('connection')) {
        return 'İnternet bağlantısı yok. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.';
      }
      
      // Check if it's an API key error
      if (errorString.contains('api key') || 
          errorString.contains('unauthorized') ||
          errorString.contains('403') ||
          errorString.contains('401')) {
        return 'API anahtarı geçersiz veya eksik. Lütfen ayarlardan API anahtarınızı kontrol edin.';
      }
      
      // Generic error message in Turkish
      return 'Günlük özet oluşturulurken bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
    }
  }

  /// Generate AI-driven insights for analytics report
  /// 
  /// [categoryData] - Map of category -> hours spent
  /// [period] - Time period (e.g., "Last 7 Days" or "Last 30 Days")
  /// Returns AI-generated insights as formatted text
  static Future<String> generateReportInsight(
    Map<String, double> categoryData,
    String period,
  ) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      await initialize();
      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('ERROR: API Key is still null after initialization');
        return 'AI insights could not be generated. Please check your API key.';
      }
    }

    // Format category data for prompt
    final dataText = categoryData.entries
        .map((e) => '${e.key}: ${e.value.toStringAsFixed(1)} hours')
        .join(', ');
    
    final totalHours = categoryData.values.fold(0.0, (sum, hours) => sum + hours);

    // System prompt for life coach insights
    final systemPrompt = '''You are a strict but motivating life coach analyzing time distribution data.

Time Distribution Data:
$dataText
Total Hours: ${totalHours.toStringAsFixed(1)} hours
Period: $period

Task: Generate exactly 3 bullet points of feedback:
1. PRAISE: What the user did well (highlight the category with most hours or good balance)
2. CRITIQUE: What needs improvement (mention missing or low categories, especially Health/Sports)
3. INSIGHT: An interesting observation (e.g., most active day, category balance, trends)

Rules:
- Be direct and honest but encouraging
- Use specific numbers from the data
- Keep each bullet point to 1-2 sentences
- Use English language
- Format as plain text with bullet points (use • or -)

Output format:
• [Praise point]
• [Critique point]
• [Insight point]

Now generate the insights:''';

    try {
      debugPrint('Generating report insights for period: $period');
      debugPrint('Category data: $categoryData');

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': systemPrompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7, // Balanced for analytical but friendly tone
          'topK': 40,
          'topP': 0.95,
        }
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': _apiKey!,
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('Insights response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final text = responseData['candidates']?[0]['content']?['parts']?[0]?['text'] ?? 
                     'Insights could not be generated.';
        debugPrint('Insights generated: $text');
        return text.trim();
      } else {
        debugPrint('API Error generating insights: ${response.statusCode} - ${response.body}');
        return 'Insights could not be generated. An error occurred.';
      }
    } catch (e, stackTrace) {
      debugPrint('Error generating report insights: $e');
      debugPrint('Stack trace: $stackTrace');
      return 'Insights could not be generated. An error occurred: ${e.toString()}';
    }
  }

  /// Suggest reschedule plan for overdue tasks
  ///
  /// [overdueTasks] - List of overdue events that need rescheduling
  /// [fixedFutureEvents] - List of future events that cannot be moved (constraints)
  /// Returns a list of reschedule suggestions with new times
  static Future<List<Map<String, dynamic>>> suggestReschedule(
    List<Map<String, dynamic>> overdueTasks,
    List<Map<String, dynamic>> fixedFutureEvents,
  ) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      await initialize();
      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('ERROR: API Key is still null after initialization');
        return [];
      }
    }

    final now = DateTime.now();
    final currentDate = DateFormat('yyyy-MM-dd').format(now);
    final currentTime = DateFormat('HH:mm').format(now);

    // Format overdue tasks
    final overdueText = overdueTasks.map((task) {
      final originalDate = DateTime.parse(task['date']);
      final originalTime = task['time'] ?? 'All Day';
      return 'ID: ${task['id']}, Title: ${task['title']}, Original: ${DateFormat('yyyy-MM-dd').format(originalDate)} $originalTime';
    }).join('\n');

    // Format fixed future events
    final fixedText = fixedFutureEvents.isEmpty
        ? 'No fixed events scheduled.'
        : fixedFutureEvents.map((event) {
            final eventDate = DateTime.parse(event['date']);
            final eventTime = event['time'] ?? 'All Day';
            return '${DateFormat('yyyy-MM-dd').format(eventDate)} $eventTime: ${event['title']}';
          }).join('\n');

    final systemPrompt = '''You are a Time Management Expert for a calendar application.

Current Time: $currentDate $currentTime

Task: Reschedule these Overdue Tasks:
$overdueText

Constraint: Do NOT overlap with these Fixed Events:
$fixedText

Strategy: 
- Fill empty slots after Current Time ($currentTime) TODAY if available
- If today is full, move to TOMORROW morning (prefer 08:00-12:00)
- Avoid overlapping with fixed events
- Space tasks at least 1 hour apart
- For all-day tasks, suggest a specific time (prefer morning)

Output: Return ONLY a JSON array of objects:
[
  {
    "event_id": "id_1",
    "original_time": "ISO8601_STRING",
    "proposed_start_time": "ISO8601_STRING",
    "proposed_end_time": "ISO8601_STRING",
    "reason": "Brief explanation"
  },
  ...
]

IMPORTANT:
- Use ISO 8601 format: YYYY-MM-DDTHH:mm:ss
- Output ONLY the JSON array, no other text
- If no suitable slots found, return empty array: []''';

    try {
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': systemPrompt
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3, // Moderate temperature for creative but logical scheduling
          'topK': 40,
          'topP': 0.95,
        }
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': _apiKey!,
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('Reschedule plan response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['candidates'] != null &&
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          String text = responseData['candidates'][0]['content']['parts'][0]['text'] ?? '';

          // Clean the response (remove markdown code blocks if present)
          text = text.trim();
          if (text.startsWith('```json')) {
            text = text.substring(7);
          }
          if (text.startsWith('```')) {
            text = text.substring(3);
          }
          if (text.endsWith('```')) {
            text = text.substring(0, text.length - 3);
          }
          text = text.trim();

          // Parse JSON array
          try {
            final List<dynamic> suggestions = jsonDecode(text);
            return suggestions.map<Map<String, dynamic>>((s) {
              return {
                'event_id': s['event_id'] as String,
                'original_time': s['original_time'] as String,
                'proposed_start_time': s['proposed_start_time'] as String,
                'proposed_end_time': s['proposed_end_time'] as String? ?? s['proposed_start_time'] as String,
                'reason': s['reason'] as String? ?? 'Rescheduled',
              };
            }).toList();
          } catch (e) {
            debugPrint('Error parsing reschedule suggestions: $e');
            debugPrint('Response text: $text');
            return [];
          }
        }
      }

      debugPrint('Failed to get reschedule plan. Status: ${response.statusCode}');
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error generating reschedule plan: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  static bool get isInitialized => _apiKey != null && _apiKey!.isNotEmpty;
}

