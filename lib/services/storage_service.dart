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

      // Handle notes box with robust error recovery
      bool notesBoxOpened = false;
      int retryCount = 0;
      const maxRetries = 2;
      
      while (!notesBoxOpened && retryCount <= maxRetries) {
        try {
          if (Hive.isBoxOpen(notesBoxName)) {
            // Box is already open, verify it works
            try {
              final box = Hive.box<Note>(notesBoxName);
              // Try a simple operation to verify box is not corrupted
              box.length; // This will throw if box is corrupted
              debugPrint('Notes box already open and verified');
              notesBoxOpened = true;
            } catch (verifyError) {
              debugPrint('Notes box is open but corrupted, closing it...');
              try {
                final box = Hive.box<Note>(notesBoxName);
                await box.close();
              } catch (closeError) {
                debugPrint('Error closing corrupted box: $closeError');
              }
              // Will retry to recreate
            }
          } else {
            // Box is not open, try to open it
            await Hive.openBox<Note>(notesBoxName);
            debugPrint('Notes box opened successfully');
            notesBoxOpened = true;
          }
        } catch (e) {
          retryCount++;
          debugPrint('Error opening notes box (attempt $retryCount): $e');
          
          if (retryCount > maxRetries) {
            debugPrint('Max retries reached for notes box');
            break;
          }
          
          // Try to fix the corrupted box
          try {
            debugPrint('Attempting to fix corrupted notes box...');
            
            // Close box if it's marked as open
            if (Hive.isBoxOpen(notesBoxName)) {
              try {
                final box = Hive.box<Note>(notesBoxName);
                await box.close();
                debugPrint('Closed corrupted notes box');
              } catch (closeError) {
                debugPrint('Error closing box: $closeError');
              }
            }
            
            // Wait to ensure file is released
            await Future.delayed(const Duration(milliseconds: 200));
            
            // Delete the corrupted box file
            try {
              await Hive.deleteBoxFromDisk(notesBoxName);
              debugPrint('Corrupted notes box deleted from disk');
            } catch (deleteError) {
              debugPrint('Error deleting box file: $deleteError');
              // Continue anyway, will try to open new box
            }
            
            // Wait before recreating
            await Future.delayed(const Duration(milliseconds: 200));
            
            // Will retry opening in next iteration
          } catch (recoveryError) {
            debugPrint('Error during box recovery: $recoveryError');
          }
        }
      }
      
      if (!notesBoxOpened) {
        debugPrint('WARNING: Notes box could not be opened after $maxRetries attempts');
        debugPrint('App will continue with limited functionality (notes will not be saved)');
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
      if (!Hive.isBoxOpen(notesBoxName)) {
        debugPrint('WARNING: Notes box is not open, cannot save note');
        return;
      }
      await notesBox.put(note.id, note);
    } catch (e) {
      debugPrint('Error saving note: $e');
      // Don't rethrow - allow app to continue
    }
  }

  static Note? getNote(String id) {
    try {
      if (!Hive.isBoxOpen(notesBoxName)) {
        debugPrint('WARNING: Notes box is not open, cannot get note');
        return null;
      }
      return notesBox.get(id);
    } catch (e) {
      debugPrint('Error getting note: $e');
      return null;
    }
  }

  static List<Note> getAllNotes() {
    try {
      if (!Hive.isBoxOpen(notesBoxName)) {
        debugPrint('WARNING: Notes box is not open, returning empty list');
        return [];
      }
      return notesBox.values.toList();
    } catch (e) {
      debugPrint('Error getting all notes: $e');
      return [];
    }
  }

  static List<Note> getNotesByEventId(String eventId) {
    try {
      if (!Hive.isBoxOpen(notesBoxName)) {
        debugPrint('WARNING: Notes box is not open, returning empty list');
        return [];
      }
      return notesBox.values.where((note) => note.eventId == eventId).toList();
    } catch (e) {
      debugPrint('Error getting notes by event id: $e');
      return [];
    }
  }

  static List<Note> getNotesByDate(DateTime date) {
    try {
      if (!Hive.isBoxOpen(notesBoxName)) {
        debugPrint('WARNING: Notes box is not open, returning empty list');
        return [];
      }
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
      if (!Hive.isBoxOpen(notesBoxName)) {
        debugPrint('WARNING: Notes box is not open, cannot delete note');
        return;
      }
      await notesBox.delete(id);
    } catch (e) {
      debugPrint('Error deleting note: $e');
      // Don't rethrow - allow app to continue
    }
  }

  static Future<void> deleteNotesByEventId(String eventId) async {
    try {
      if (!Hive.isBoxOpen(notesBoxName)) {
        debugPrint('WARNING: Notes box is not open, cannot delete notes');
        return;
      }
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
      // Don't rethrow - allow app to continue
    }
  }
}

