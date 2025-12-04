import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../models/event.dart';

class NotesSection extends StatelessWidget {
  final DateTime selectedDate;
  final List<Event> eventsOnDate;
  final List<Note> notesOnDate;
  final Function(Event) onEventTap;

  const NotesSection({
    super.key,
    required this.selectedDate,
    required this.eventsOnDate,
    required this.notesOnDate,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMMM yyyy', 'tr_TR');
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Notes for ${dateFormat.format(selectedDate)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (notesOnDate.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'No notes for this day',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          else
            ...notesOnDate.map((note) {
              final event = eventsOnDate.firstWhere(
                (e) => e.id == note.eventId,
                orElse: () => Event(
                  id: '',
                  title: 'Unknown Event',
                  date: selectedDate,
                ),
              );
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: ListTile(
                  title: Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(note.content),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('HH:mm', 'tr_TR').format(note.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  onTap: () => onEventTap(event),
                ),
              );
            }),
        ],
      ),
    );
  }
}

