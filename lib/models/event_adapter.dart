import 'package:hive/hive.dart';
import 'event.dart';

class EventAdapter extends TypeAdapter<Event> {
  @override
  final int typeId = 0;

  @override
  Event read(BinaryReader reader) {
    final hasTime = reader.readBool();
    final hasDescription = reader.readBool();
    final hasLatitude = reader.readBool();
    final hasLongitude = reader.readBool();
    final hasLocationName = reader.readBool();
    
    final event = Event(
      id: reader.readString(),
      title: reader.readString(),
      date: DateTime.parse(reader.readString()),
      time: hasTime ? reader.readString() : null,
      description: hasDescription ? reader.readString() : null,
      latitude: hasLatitude ? reader.readDouble() : null,
      longitude: hasLongitude ? reader.readDouble() : null,
      locationName: hasLocationName ? reader.readString() : null,
    );
    
    // Read category and colorHex if they exist (for backward compatibility)
    try {
      final hasCategory = reader.readBool();
      if (hasCategory) {
        event.category = reader.readString();
        event.colorHex = reader.readString();
      }
    } catch (e) {
      // Old format, use defaults
      event.category = 'General';
      event.colorHex = '#808080';
    }
    
    // Read isCompleted if it exists (for backward compatibility)
    try {
      event.isCompleted = reader.readBool();
    } catch (e) {
      // Old format, default to false
      event.isCompleted = false;
    }
    
    return event;
  }

  @override
  void write(BinaryWriter writer, Event obj) {
    writer.writeBool(obj.time != null);
    writer.writeBool(obj.description != null);
    writer.writeBool(obj.latitude != null);
    writer.writeBool(obj.longitude != null);
    writer.writeBool(obj.locationName != null);
    
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.date.toIso8601String());
    if (obj.time != null) writer.writeString(obj.time!);
    if (obj.description != null) writer.writeString(obj.description!);
    if (obj.latitude != null) writer.writeDouble(obj.latitude!);
    if (obj.longitude != null) writer.writeDouble(obj.longitude!);
    if (obj.locationName != null) writer.writeString(obj.locationName!);
    
    // Write category and colorHex
    writer.writeBool(true); // Always has category now
    writer.writeString(obj.category);
    writer.writeString(obj.colorHex);
    
    // Write isCompleted
    writer.writeBool(obj.isCompleted);
  }
}

