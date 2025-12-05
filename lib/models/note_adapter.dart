import 'package:hive/hive.dart';
import 'note.dart';

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 1;

  @override
  Note read(BinaryReader reader) {
    final hasTitle = reader.readBool();
    final note = Note(
      id: reader.readString(),
      eventId: reader.readString(),
      content: reader.readString(),
      createdAt: DateTime.parse(reader.readString()),
      title: hasTitle ? reader.readString() : null,
      date: DateTime.parse(reader.readString()),
    );
    
    // Read location fields if they exist (for backward compatibility)
    try {
      final hasLocation = reader.readBool();
      if (hasLocation) {
        note.latitude = reader.readDouble();
        note.longitude = reader.readDouble();
        final hasLocationName = reader.readBool();
        note.locationName = hasLocationName ? reader.readString() : null;
      }
    } catch (e) {
      // Old format, location fields don't exist
    }
    
    return note;
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
    
    // Write location fields
    final hasLocation = obj.latitude != null && obj.longitude != null;
    writer.writeBool(hasLocation);
    if (hasLocation) {
      writer.writeDouble(obj.latitude!);
      writer.writeDouble(obj.longitude!);
      writer.writeBool(obj.locationName != null);
      if (obj.locationName != null) writer.writeString(obj.locationName!);
    }
  }
}

