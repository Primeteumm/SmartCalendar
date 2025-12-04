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

  Event({
    required this.id,
    required this.title,
    required this.date,
    this.time,
    this.description,
    this.latitude,
    this.longitude,
    this.locationName,
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
    );
  }
}

