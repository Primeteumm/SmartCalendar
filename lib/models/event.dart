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
  });

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
    );
  }
}

