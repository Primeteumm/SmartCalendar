/// Model representing a calendar action (event or note) from AI assistant
class CalendarAction {
  // Legacy fields for backward compatibility
  final String? title;
  final String? description;
  final String? type; // "event" or "note" - deprecated, all actions are notes now
  
  // New required fields
  final String noteContent; // MANDATORY - The full detail of the note
  final DateTime datetime; // MANDATORY - ISO 8601 datetime
  final bool isAllDay; // Optional - true if no specific time is given
  final String category; // Category: School, Work, Social, Health, General
  final String colorHex; // Hex color code (e.g., "#FF0000")

  CalendarAction({
    this.title, // Optional for backward compatibility
    this.description, // Optional
    this.type, // Optional, defaults to "note"
    required this.noteContent, // MANDATORY
    required this.datetime, // MANDATORY
    this.isAllDay = false, // Default to false
    this.category = 'General', // Default category
    this.colorHex = '#808080', // Default grey
  });

  /// Create from JSON map - supports both old and new formats
  factory CalendarAction.fromJson(Map<String, dynamic> json) {
    // Support new format with note_content
    if (json.containsKey('note_content')) {
      return CalendarAction(
        noteContent: json['note_content'] as String,
        datetime: DateTime.parse(json['datetime'] as String),
        isAllDay: json['is_all_day'] as bool? ?? false,
        category: json['category'] as String? ?? 'General',
        colorHex: json['color_hex'] as String? ?? '#808080',
        // Legacy fields for backward compatibility
        title: json['title'] as String?,
        description: json['description'] as String?,
        type: json['type'] as String? ?? 'note',
      );
    }
    
    // Support old format with title (for backward compatibility)
    if (json.containsKey('title')) {
      return CalendarAction(
        title: json['title'] as String,
        description: json['description'] as String?,
        datetime: DateTime.parse(json['datetime'] as String),
        type: json['type'] as String? ?? 'note',
        // Use title as noteContent for old format
        noteContent: json['title'] as String,
        isAllDay: json['is_all_day'] as bool? ?? false,
        category: json['category'] as String? ?? 'General',
        colorHex: json['color_hex'] as String? ?? '#808080',
      );
    }
    
    // Fallback: use description or empty string
    throw FormatException('Invalid JSON format: missing note_content or title');
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'note_content': noteContent,
      'datetime': datetime.toIso8601String(),
      'is_all_day': isAllDay,
      'category': category,
      'color_hex': colorHex,
      // Include legacy fields for backward compatibility
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
    };
  }

  /// Validate the calendar action
  bool isValid() {
    return noteContent.isNotEmpty && 
           datetime.isAfter(DateTime(2000));
  }

  /// Get display title (for UI compatibility)
  String get displayTitle {
    return title ?? noteContent.split('\n').first.split('.').first.trim();
  }

  @override
  String toString() {
    return 'CalendarAction(noteContent: $noteContent, datetime: $datetime, isAllDay: $isAllDay)';
  }
}

