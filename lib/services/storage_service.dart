import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';
import '../models/note.dart';
import '../models/event_adapter.dart';
import '../models/note_adapter.dart';

class StorageService {
  static const String eventsBoxName = 'events';
  static const String notesBoxName = 'notes';

  static Future<void> init() async {
    try {
      // Initialize Hive
      await Hive.initFlutter();
      debugPrint('Hive.initFlutter completed');
      
      // Register adapters
      try {
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(EventAdapter());
          debugPrint('EventAdapter registered');
        }
      } catch (e) {
        debugPrint('Error registering EventAdapter: $e');
      }
      
      try {
        if (!Hive.isAdapterRegistered(1)) {
          Hive.registerAdapter(NoteAdapter());
          debugPrint('NoteAdapter registered');
        }
      } catch (e) {
        debugPrint('Error registering NoteAdapter: $e');
      }

      // Open boxes with error handling
      try {
        if (!Hive.isBoxOpen(eventsBoxName)) {
          await Hive.openBox<Event>(eventsBoxName);
          debugPrint('Events box opened successfully');
        } else {
          debugPrint('Events box already open');
        }
      } catch (e, stackTrace) {
        debugPrint('Error opening events box: $e');
        debugPrint('Stack trace: $stackTrace');
        // Try to continue with notes box
      }

      try {
        if (!Hive.isBoxOpen(notesBoxName)) {
          await Hive.openBox<Note>(notesBoxName);
          debugPrint('Notes box opened successfully');
        } else {
          debugPrint('Notes box already open');
        }
      } catch (e, stackTrace) {
        debugPrint('Error opening notes box: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      // Verify boxes are open
      if (Hive.isBoxOpen(eventsBoxName) && Hive.isBoxOpen(notesBoxName)) {
        debugPrint('StorageService initialized successfully');
      } else {
        debugPrint('WARNING: Some boxes failed to open');
        debugPrint('Events box open: ${Hive.isBoxOpen(eventsBoxName)}');
        debugPrint('Notes box open: ${Hive.isBoxOpen(notesBoxName)}');
      }
    } catch (e, stackTrace) {
      debugPrint('Critical error in StorageService.init: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - let app continue
    }
  }

  // Event operations
  static Box<Event> get eventsBox {
    if (!Hive.isBoxOpen(eventsBoxName)) {
      debugPrint('WARNING: Events box is not open!');
      throw HiveError('Events box is not open. Did you forget to call Hive.openBox()?');
    }
    return Hive.box<Event>(eventsBoxName);
  }

  static Future<void> saveEvent(Event event) async {
    try {
      await eventsBox.put(event.id, event);
    } catch (e) {
      debugPrint('Error saving event: $e');
      rethrow;
    }
  }

  static Event? getEvent(String id) {
    try {
      return eventsBox.get(id);
    } catch (e) {
      debugPrint('Error getting event: $e');
      return null;
    }
  }

  static List<Event> getAllEvents() {
    try {
      return eventsBox.values.toList();
    } catch (e) {
      debugPrint('Error getting all events: $e');
      return [];
    }
  }

  static List<Event> getEventsByDate(DateTime date) {
    try {
      return eventsBox.values.where((event) {
        return event.date.year == date.year &&
            event.date.month == date.month &&
            event.date.day == date.day;
      }).toList();
    } catch (e) {
      debugPrint('Error getting events by date: $e');
      return [];
    }
  }

  static Future<void> deleteEvent(String id) async {
    try {
      await eventsBox.delete(id);
    } catch (e) {
      debugPrint('Error deleting event: $e');
      rethrow;
    }
  }

  // Note operations
  static Box<Note> get notesBox {
    if (!Hive.isBoxOpen(notesBoxName)) {
      debugPrint('WARNING: Notes box is not open!');
      throw HiveError('Notes box is not open. Did you forget to call Hive.openBox()?');
    }
    return Hive.box<Note>(notesBoxName);
  }

  static Future<void> saveNote(Note note) async {
    try {
      await notesBox.put(note.id, note);
    } catch (e) {
      debugPrint('Error saving note: $e');
      rethrow;
    }
  }

  static Note? getNote(String id) {
    try {
      return notesBox.get(id);
    } catch (e) {
      debugPrint('Error getting note: $e');
      return null;
    }
  }

  static List<Note> getAllNotes() {
    try {
      return notesBox.values.toList();
    } catch (e) {
      debugPrint('Error getting all notes: $e');
      return [];
    }
  }

  static List<Note> getNotesByEventId(String eventId) {
    try {
      return notesBox.values.where((note) => note.eventId == eventId).toList();
    } catch (e) {
      debugPrint('Error getting notes by event id: $e');
      return [];
    }
  }

  static List<Note> getNotesByDate(DateTime date) {
    try {
      // Normalize dates to compare only year, month, day (ignore time)
      final normalizedDate = DateTime(date.year, date.month, date.day);
      
      return notesBox.values.where((note) {
        // Normalize note date to compare only year, month, day
        final normalizedNoteDate = DateTime(note.date.year, note.date.month, note.date.day);
        
        // Check if note has a direct date match
        if (normalizedNoteDate == normalizedDate) {
          return true;
        }
        // Also check if note is linked to an event on this date
        if (note.eventId.isNotEmpty) {
          final eventsOnDate = getEventsByDate(date);
          return eventsOnDate.any((e) => e.id == note.eventId);
        }
        return false;
      }).toList();
    } catch (e) {
      debugPrint('Error getting notes by date: $e');
      return [];
    }
  }

  static Future<void> deleteNote(String id) async {
    try {
      await notesBox.delete(id);
    } catch (e) {
      debugPrint('Error deleting note: $e');
      rethrow;
    }
  }

  static Future<void> deleteNotesByEventId(String eventId) async {
    try {
      final notes = getNotesByEventId(eventId);
      for (var note in notes) {
        try {
          await notesBox.delete(note.id);
        } catch (e) {
          debugPrint('Error deleting note ${note.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error deleting notes by event id: $e');
      rethrow;
    }
  }
}

