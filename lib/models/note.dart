import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class Note extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String eventId;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  String? title;

  @HiveField(5)
  DateTime date;

  @HiveField(6)
  double? latitude;

  @HiveField(7)
  double? longitude;

  @HiveField(8)
  String? locationName;

  Note({
    required this.id,
    required this.eventId,
    required this.content,
    required this.createdAt,
    this.title,
    required this.date,
    this.latitude,
    this.longitude,
    this.locationName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'title': title,
      'date': date.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      eventId: json['eventId'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      title: json['title'],
      date: DateTime.parse(json['date']),
      latitude: json['latitude'],
      longitude: json['longitude'],
      locationName: json['locationName'],
    );
  }
}

