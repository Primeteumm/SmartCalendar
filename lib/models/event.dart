import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class Event extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  String? time;

  @HiveField(4)
  String? description;

  @HiveField(5)
  double? latitude;

  @HiveField(6)
  double? longitude;

  @HiveField(7)
  String? locationName;

  @HiveField(8)
  String category; // Category: School, Work, Social, Health, General

  @HiveField(9)
  String colorHex; // Hex color code (e.g., "#FF0000")

  @HiveField(10)
  bool isCompleted; // Whether the event/task has been completed

  Event({
    required this.id,
    required this.title,
    required this.date,
    this.time,
    this.description,
    this.latitude,
    this.longitude,
    this.locationName,
    this.category = 'General',
    this.colorHex = '#808080', // Default grey
    this.isCompleted = false, // Default to not completed
  });

  /// Get the start time as DateTime (combines date and time string)
  DateTime get startTime {
    if (time == null || time!.isEmpty) {
      // All-day event, start at midnight
      return DateTime(date.year, date.month, date.day, 0, 0);
    }
    
    try {
      // Parse time string (format: "HH:mm" or "HH:mm:ss")
      final timeParts = time!.split(':');
      if (timeParts.isEmpty) {
        return DateTime(date.year, date.month, date.day, 0, 0);
      }
      
      final hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      
      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      // If parsing fails, return midnight
      return DateTime(date.year, date.month, date.day, 0, 0);
    }
  }

  /// Get the end time as DateTime (defaults to 1 hour after start, or end of day for all-day events)
  DateTime get endTime {
    if (time == null || time!.isEmpty) {
      // All-day event, end at end of day
      return DateTime(date.year, date.month, date.day, 23, 59);
    }
    
    try {
      // Parse time string and add 1 hour default duration
      final timeParts = time!.split(':');
      if (timeParts.isEmpty) {
        return DateTime(date.year, date.month, date.day, 23, 59);
      }
      
      final hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      
      final start = DateTime(date.year, date.month, date.day, hour, minute);
      return start.add(const Duration(hours: 1)); // Default 1 hour duration
    } catch (e) {
      // If parsing fails, return end of day
      return DateTime(date.year, date.month, date.day, 23, 59);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'time': time,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'category': category,
      'colorHex': colorHex,
      'isCompleted': isCompleted,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      time: json['time'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      locationName: json['locationName'],
      category: json['category'] ?? 'General',
      colorHex: json['colorHex'] ?? '#808080',
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

