import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';
import '../models/note.dart';
import '../models/event_adapter.dart';
import '../models/note_adapter.dart';

class StorageService {
  static const String eventsBoxName = 'events';
  static const String notesBoxName = 'notes';

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(EventAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(NoteAdapter());
    }

    // Open boxes
    await Hive.openBox<Event>(eventsBoxName);
    await Hive.openBox<Note>(notesBoxName);
  }

  // Event operations
  static Box<Event> get eventsBox => Hive.box<Event>(eventsBoxName);

  static Future<void> saveEvent(Event event) async {
    await eventsBox.put(event.id, event);
  }

  static Event? getEvent(String id) {
    return eventsBox.get(id);
  }

  static List<Event> getAllEvents() {
    return eventsBox.values.toList();
  }

  static List<Event> getEventsByDate(DateTime date) {
    return eventsBox.values.where((event) {
      return event.date.year == date.year &&
          event.date.month == date.month &&
          event.date.day == date.day;
    }).toList();
  }

  static Future<void> deleteEvent(String id) async {
    await eventsBox.delete(id);
  }

  // Note operations
  static Box<Note> get notesBox => Hive.box<Note>(notesBoxName);

  static Future<void> saveNote(Note note) async {
    await notesBox.put(note.id, note);
  }

  static Note? getNote(String id) {
    return notesBox.get(id);
  }

  static List<Note> getAllNotes() {
    return notesBox.values.toList();
  }

  static List<Note> getNotesByEventId(String eventId) {
    return notesBox.values.where((note) => note.eventId == eventId).toList();
  }

  static List<Note> getNotesByDate(DateTime date) {
    final eventsOnDate = getEventsByDate(date);
    final eventIds = eventsOnDate.map((e) => e.id).toSet();
    return notesBox.values
        .where((note) => eventIds.contains(note.eventId))
        .toList();
  }

  static Future<void> deleteNote(String id) async {
    await notesBox.delete(id);
  }

  static Future<void> deleteNotesByEventId(String eventId) async {
    final notes = getNotesByEventId(eventId);
    for (var note in notes) {
      await notesBox.delete(note.id);
    }
  }
}

