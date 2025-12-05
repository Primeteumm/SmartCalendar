import 'dart:convert';
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

  /// Get upcoming notes for the next N days as formatted text
  /// Used for AI context injection
  String getUpcomingNotesAsText({int days = 14}) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    
    // Filter notes within the date range
    final upcomingNotes = _notes.where((note) {
      return note.date.isAfter(now.subtract(const Duration(days: 1))) &&
             note.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
    
    // Sort by date
    upcomingNotes.sort((a, b) => a.date.compareTo(b.date));
    
    if (upcomingNotes.isEmpty) {
      return 'No upcoming notes in the next $days days.';
    }
    
    // Format notes as text
    final buffer = StringBuffer();
    for (final note in upcomingNotes) {
      final dateStr = '${note.date.year}-${note.date.month.toString().padLeft(2, '0')}-${note.date.day.toString().padLeft(2, '0')}';
      final timeStr = note.date.hour == 12 && note.date.minute == 0 
          ? 'All Day' 
          : '${note.date.hour.toString().padLeft(2, '0')}:${note.date.minute.toString().padLeft(2, '0')}';
      
      // Extract note content (may be JSON or plain text)
      String noteContent = note.content;
      try {
        // Try to parse as JSON to extract note_content
        final json = jsonDecode(note.content);
        if (json is Map && json.containsKey('note_content')) {
          noteContent = json['note_content'] as String;
        }
      } catch (_) {
        // If not JSON, use content as-is
      }
      
      final displayTitle = note.title ?? noteContent.split('\n').first.split('.').first.trim();
      buffer.writeln('$dateStr $timeStr: $displayTitle');
      if (noteContent != displayTitle && noteContent.length > displayTitle.length) {
        buffer.writeln('  Details: $noteContent');
      }
    }
    
    return buffer.toString();
  }

}

