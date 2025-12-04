import 'package:hive/hive.dart';
import 'note.dart';

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 1;

  @override
  Note read(BinaryReader reader) {
    return Note(
      id: reader.readString(),
      eventId: reader.readString(),
      content: reader.readString(),
      createdAt: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.eventId);
    writer.writeString(obj.content);
    writer.writeString(obj.createdAt.toIso8601String());
  }
}

