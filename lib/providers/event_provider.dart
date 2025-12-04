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
}

