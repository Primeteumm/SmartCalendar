import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../services/storage_service.dart';

class NoteProvider with ChangeNotifier {
  List<Note> _notes = [];

  List<Note> get notes => _notes;

  NoteProvider() {
    loadNotes();
  }

  Future<void> loadNotes() async {
    _notes = StorageService.getAllNotes();
    notifyListeners();
  }

  Future<void> addNote(Note note) async {
    await StorageService.saveNote(note);
    // Reload all notes to ensure consistency
    _notes = StorageService.getAllNotes();
    notifyListeners();
    debugPrint('Note added: ${note.id}, Total notes: ${_notes.length}');
    debugPrint('Note date: ${note.date}, Title: ${note.title}');
  }

  Future<void> updateNote(Note note) async {
    await StorageService.saveNote(note);
    _notes = StorageService.getAllNotes();
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await StorageService.deleteNote(id);
    _notes = StorageService.getAllNotes();
    notifyListeners();
  }

  List<Note> getNotesByEventId(String eventId) {
    return StorageService.getNotesByEventId(eventId);
  }

  List<Note> getNotesByDate(DateTime date) {
    return StorageService.getNotesByDate(date);
  }
}

