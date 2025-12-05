import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/calendar_action.dart';

/// Service to parse calendar actions from AI responses
class CalendarActionParser {
  /// Extract JSON from AI response text
  /// Looks for JSON objects in the response, even if wrapped in markdown code blocks
  static CalendarAction? parseResponse(String response) {
    try {
      // Try to find JSON in the response
      String? jsonString = _extractJsonString(response);
      
      if (jsonString == null) {
        debugPrint('No JSON found in AI response');
        return null;
      }

      // Parse JSON
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate required fields
      if (!json.containsKey('title') || 
          !json.containsKey('datetime') || 
          !json.containsKey('type')) {
        debugPrint('Invalid JSON structure: missing required fields');
        return null;
      }

      // Create CalendarAction
      final action = CalendarAction.fromJson(json);
      
      // Validate the action
      if (!action.isValid()) {
        debugPrint('Invalid calendar action: ${action.toString()}');
        return null;
      }

      debugPrint('Successfully parsed calendar action: ${action.toString()}');
      return action;
    } catch (e) {
      debugPrint('Error parsing calendar action: $e');
      return null;
    }
  }

  /// Extract JSON string from response text
  /// Handles cases where JSON is wrapped in markdown code blocks or mixed with text
  static String? _extractJsonString(String response) {
    // Remove leading/trailing whitespace
    String cleaned = response.trim();

    // Try to find JSON in markdown code blocks (```json ... ``` or ``` ... ```)
    final codeBlockRegex = RegExp(r'```(?:json)?\s*\n?(.*?)\n?```', dotAll: true);
    final codeBlockMatch = codeBlockRegex.firstMatch(cleaned);
    if (codeBlockMatch != null) {
      cleaned = codeBlockMatch.group(1)?.trim() ?? cleaned;
    }

    // Try to find JSON object directly (starts with { and ends with })
    final jsonObjectRegex = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', dotAll: true);
    final jsonMatch = jsonObjectRegex.firstMatch(cleaned);
    if (jsonMatch != null) {
      return jsonMatch.group(0);
    }

    // If the whole response looks like JSON, try it
    if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
      return cleaned;
    }

    return null;
  }

  /// Check if response contains a calendar action intent
  static bool hasCalendarIntent(String response) {
    final lowerResponse = response.toLowerCase();
    final calendarKeywords = [
      'add',
      'create',
      'schedule',
      'remind',
      'event',
      'note',
      'appointment',
      'meeting',
      'task',
      'todo',
    ];
    
    return calendarKeywords.any((keyword) => lowerResponse.contains(keyword));
  }
}

