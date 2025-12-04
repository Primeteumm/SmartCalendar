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

  Note({
    required this.id,
    required this.eventId,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      eventId: json['eventId'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

