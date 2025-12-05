import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/event.dart';

class AddNoteDialog extends StatefulWidget {
  final Event event;

  const AddNoteDialog({super.key, required this.event});

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final note = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventId: widget.event.id,
        content: _contentController.text,
        createdAt: DateTime.now(),
      date: DateTime.now(),
      );
      Navigator.of(context).pop(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Note',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Event: ${widget.event.title}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Note Content *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter your note...',
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a note';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Add Note'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

