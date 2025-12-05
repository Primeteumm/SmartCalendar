import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/calendar_action.dart';

/// Service to parse calendar actions from AI responses
class CalendarActionParser {
  /// Extract JSON from AI response text
  /// Looks for JSON objects in the response, even if wrapped in markdown code blocks
  /// Returns CalendarAction with fallback mechanisms to ensure it never fails
  static CalendarAction? parseResponse(String response) {
    try {
      // Try to find JSON in the response
      String? jsonString = _extractJsonString(response);
      
      if (jsonString == null) {
        debugPrint('No JSON found in AI response, attempting fallback');
        // Fallback: Try to create a note from the response itself
        return _createFallbackAction(response);
      }

      // Parse JSON
      Map<String, dynamic> json;
      try {
        json = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Failed to parse JSON: $e, attempting fallback');
        return _createFallbackAction(response);
      }
      
      // Validate required fields - new format requires note_content
      final hasNewFormat = json.containsKey('note_content') && json.containsKey('datetime');
      final hasOldFormat = json.containsKey('title') && json.containsKey('datetime');
      
      if (!hasNewFormat && !hasOldFormat) {
        debugPrint('Invalid JSON structure: missing required fields, attempting fallback');
        return _createFallbackAction(response);
      }

      // Create CalendarAction
      CalendarAction action;
      try {
        action = CalendarAction.fromJson(json);
      } catch (e) {
        debugPrint('Failed to create CalendarAction from JSON: $e, attempting fallback');
        return _createFallbackAction(response);
      }
      
      // Validate the action
      if (!action.isValid()) {
        debugPrint('Invalid calendar action: ${action.toString()}, attempting fallback');
        return _createFallbackAction(response);
      }

      debugPrint('Successfully parsed calendar action: ${action.toString()}');
      return action;
    } catch (e) {
      debugPrint('Error parsing calendar action: $e, attempting fallback');
      return _createFallbackAction(response);
    }
  }

  /// Create a fallback CalendarAction from response text
  /// This ensures we always capture user requests even if JSON parsing fails
  static CalendarAction _createFallbackAction(String response) {
    final now = DateTime.now();
    // Use 12:00:00 as default time
    final defaultDateTime = DateTime(now.year, now.month, now.day, 12, 0, 0);
    
    // Clean the response text
    String cleanContent = response.trim();
    
    // Remove markdown code blocks if present
    cleanContent = cleanContent.replaceAll(RegExp(r'```[a-z]*\n?'), '').replaceAll('```', '').trim();
    
    // Remove JSON-like structures if present
    cleanContent = cleanContent.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
    
    // If content is empty, use a default message
    if (cleanContent.isEmpty) {
      cleanContent = 'Calendar note';
    }
    
    debugPrint('Creating fallback action with content: $cleanContent');
    
    return CalendarAction(
      noteContent: cleanContent,
      datetime: defaultDateTime,
      isAllDay: true,
      type: 'note',
    );
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

