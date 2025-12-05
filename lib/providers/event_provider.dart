import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../services/storage_service.dart';

class EventProvider with ChangeNotifier {
  List<Event> _events = [];
  Event? _selectedEvent;

  List<Event> get events => _events;
  Event? get selectedEvent => _selectedEvent;

  EventProvider() {
    loadEvents();
  }

  Future<void> loadEvents() async {
    _events = StorageService.getAllEvents();
    notifyListeners();
  }

  Future<void> addEvent(Event event) async {
    await StorageService.saveEvent(event);
    _events = StorageService.getAllEvents();
    notifyListeners();
  }

  Future<void> updateEvent(Event event) async {
    await StorageService.saveEvent(event);
    _events = StorageService.getAllEvents();
    notifyListeners();
  }

  Future<void> deleteEvent(String id) async {
    await StorageService.deleteEvent(id);
    await StorageService.deleteNotesByEventId(id);
    _events = StorageService.getAllEvents();
    if (_selectedEvent?.id == id) {
      _selectedEvent = null;
    }
    notifyListeners();
  }

  List<Event> getEventsByDate(DateTime date) {
    return StorageService.getEventsByDate(date);
  }

  void selectEvent(Event? event) {
    _selectedEvent = event;
    notifyListeners();
  }

  List<Event> getEventsWithLocation() {
    return _events.where((event) =>
        event.latitude != null && event.longitude != null).toList();
  }

  /// Get upcoming events for the next N days as formatted text
  /// Used for AI context injection
  String getUpcomingEventsAsText({int days = 14}) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    
    // Filter events within the date range
    final upcomingEvents = _events.where((event) {
      return event.date.isAfter(now.subtract(const Duration(days: 1))) &&
             event.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
    
    // Sort by date
    upcomingEvents.sort((a, b) => a.date.compareTo(b.date));
    
    if (upcomingEvents.isEmpty) {
      return 'No upcoming events in the next $days days.';
    }
    
    // Format events as text
    final buffer = StringBuffer();
    for (final event in upcomingEvents) {
      final dateStr = '${event.date.year}-${event.date.month.toString().padLeft(2, '0')}-${event.date.day.toString().padLeft(2, '0')}';
      final timeStr = event.time ?? 'All Day';
      buffer.writeln('$dateStr $timeStr: ${event.title}');
      if (event.description != null && event.description!.isNotEmpty) {
        buffer.writeln('  Note: ${event.description}');
      }
      if (event.locationName != null && event.locationName!.isNotEmpty) {
        buffer.writeln('  Location: ${event.locationName}');
      }
    }
    
    return buffer.toString();
  }
}

