/// Model representing a calendar action (event or note) from AI assistant
class CalendarAction {
  final String title;
  final String? description;
  final DateTime datetime;
  final String type; // "event" or "note"

  CalendarAction({
    required this.title,
    this.description,
    required this.datetime,
    required this.type,
  });

  /// Create from JSON map
  factory CalendarAction.fromJson(Map<String, dynamic> json) {
    return CalendarAction(
      title: json['title'] as String,
      description: json['description'] as String?,
      datetime: DateTime.parse(json['datetime'] as String),
      type: json['type'] as String,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'datetime': datetime.toIso8601String(),
      'type': type,
    };
  }

  /// Validate the calendar action
  bool isValid() {
    return title.isNotEmpty && 
           (type == 'event' || type == 'note') &&
           datetime.isAfter(DateTime(2000));
  }

  @override
  String toString() {
    return 'CalendarAction(title: $title, type: $type, datetime: $datetime)';
  }
}

