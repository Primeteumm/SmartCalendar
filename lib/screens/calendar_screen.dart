import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../providers/note_provider.dart';
import '../widgets/dynamic_calendar.dart';
import '../widgets/view_mode_selector.dart';
import '../widgets/notes_section.dart';
import '../widgets/add_event_dialog.dart';
import '../widgets/event_selection_screen.dart';
import '../widgets/add_note_dialog.dart';
import '../models/event.dart';
import '../models/note.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.weekly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<EventProvider, NoteProvider>(
        builder: (context, eventProvider, noteProvider, child) {
          final eventsOnDate = eventProvider.getEventsByDate(_selectedDate);
          final notesOnDate = noteProvider.getNotesByDate(_selectedDate);

          return Column(
            children: [
              // View mode selector
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ViewModeSelector(
                  selectedMode: _viewMode,
                  onModeChanged: (mode) {
                    setState(() {
                      _viewMode = mode;
                    });
                  },
                ),
              ),
              // Calendar
              Expanded(
                child: DynamicCalendar(
                  selectedDate: _selectedDate,
                  events: eventProvider.events,
                  onDateSelected: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  viewMode: _viewMode,
                ),
              ),
              // Notes section
              NotesSection(
                selectedDate: _selectedDate,
                eventsOnDate: eventsOnDate,
                notesOnDate: notesOnDate,
                onEventTap: (event) {
                  // Show event details or edit
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add_note',
            onPressed: () async {
              final eventProvider = Provider.of<EventProvider>(context, listen: false);
              final eventsOnDate = eventProvider.getEventsByDate(_selectedDate);
              
              if (eventsOnDate.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No events on this day. Add an event first.'),
                  ),
                );
                return;
              }

              final selectedEvent = await Navigator.of(context).push<Event>(
                MaterialPageRoute(
                  builder: (context) => EventSelectionScreen(
                    selectedDate: _selectedDate,
                    events: eventProvider.events,
                  ),
                ),
              );

              if (selectedEvent != null && mounted) {
                final note = await showDialog<Note>(
                  context: context,
                  builder: (context) => AddNoteDialog(event: selectedEvent),
                );

                if (note != null) {
                  await Provider.of<NoteProvider>(context, listen: false)
                      .addNote(note);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note added successfully')),
                    );
                  }
                }
              }
            },
            child: const Icon(Icons.note_add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add_event',
            onPressed: () async {
              final event = await showDialog<Event>(
                context: context,
                builder: (context) => AddEventDialog(initialDate: _selectedDate),
              );

              if (event != null) {
                await Provider.of<EventProvider>(context, listen: false)
                    .addEvent(event);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event added successfully')),
                  );
                }
              }
            },
            child: const Icon(Icons.event),
          ),
        ],
      ),
    );
  }
}

