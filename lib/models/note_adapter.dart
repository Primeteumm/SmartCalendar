import 'package:hive/hive.dart';
import 'note.dart';

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 1;

  @override
  Note read(BinaryReader reader) {
    final hasTitle = reader.readBool();
    return Note(
      id: reader.readString(),
      eventId: reader.readString(),
      content: reader.readString(),
      createdAt: DateTime.parse(reader.readString()),
      title: hasTitle ? reader.readString() : null,
      date: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer.writeBool(obj.title != null);
    writer.writeString(obj.id);
    writer.writeString(obj.eventId);
    writer.writeString(obj.content);
    writer.writeString(obj.createdAt.toIso8601String());
    if (obj.title != null) writer.writeString(obj.title!);
    writer.writeString(obj.date.toIso8601String());
  }
}

