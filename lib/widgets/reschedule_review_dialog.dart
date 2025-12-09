import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/event_provider.dart';
import '../services/gemini_service.dart';
import '../models/event.dart';

class RescheduleReviewDialog extends StatefulWidget {
  const RescheduleReviewDialog({super.key});

  @override
  State<RescheduleReviewDialog> createState() => _RescheduleReviewDialogState();
}

class _RescheduleReviewDialogState extends State<RescheduleReviewDialog> {
  List<Map<String, dynamic>> _proposals = [];
  List<Event> _overdueEvents = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAndGenerateProposal();
  }

  Future<void> _loadAndGenerateProposal() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      
      // Get overdue and future events
      final overdueEvents = eventProvider.getOverdueEvents();
      final futureEvents = eventProvider.getFutureEvents();

      if (overdueEvents.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No overdue tasks found. Great job! 🎉';
        });
        return;
      }

      _overdueEvents = overdueEvents;

      // Convert to map format for AI
      final overdueForAI = overdueEvents.map((event) {
        return {
          'id': event.id,
          'title': event.title,
          'date': event.date.toIso8601String(),
          'time': event.time ?? 'All Day',
        };
      }).toList();

      final futureForAI = futureEvents.map((event) {
        return {
          'id': event.id,
          'title': event.title,
          'date': event.date.toIso8601String(),
          'time': event.time ?? 'All Day',
        };
      }).toList();

      // Get AI suggestions
      final suggestions = await GeminiService.suggestReschedule(
        overdueForAI,
        futureForAI,
      );

      if (suggestions.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not find suitable time slots. Try again later.';
        });
        return;
      }

      setState(() {
        _proposals = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error generating rescue plan: ${e.toString()}';
      });
    }
  }

  Future<void> _editProposedTime(int index) async {
    final proposal = _proposals[index];
    final currentStartTime = DateTime.parse(proposal['proposed_start_time']);

    // Show date picker
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentStartTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (selectedDate == null) return;

    // Show time picker
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentStartTime),
    );

    if (selectedTime == null) return;

    // Combine date and time
    final newDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Update the proposal
    setState(() {
      _proposals[index] = {
        ...proposal,
        'proposed_start_time': newDateTime.toIso8601String(),
        'proposed_end_time': newDateTime.add(const Duration(hours: 1)).toIso8601String(),
      };
    });
  }

  Future<void> _confirmAndSave() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      
      for (final proposal in _proposals) {
        final eventId = proposal['event_id'] as String;
        final newStartTime = DateTime.parse(proposal['proposed_start_time'] as String);
        await eventProvider.rescheduleEvent(eventId, newStartTime);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule updated successfully! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Error saving changes: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            Expanded(
              child: _buildBody(context),
            ),
            if (!_isLoading && _errorMessage == null && _proposals.isNotEmpty)
              _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.emergency,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Proposed New Plan',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing your schedule...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _errorMessage!.contains('Great job') ? Icons.check_circle_outline : Icons.error_outline,
              color: _errorMessage!.contains('Great job') ? Colors.green : Theme.of(context).colorScheme.error,
              size: 64,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _errorMessage!.contains('Great job') ? Colors.green : Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
            if (!_errorMessage!.contains('Great job'))
              const SizedBox(height: 16),
            if (!_errorMessage!.contains('Great job'))
              ElevatedButton(
                onPressed: _loadAndGenerateProposal,
                child: const Text('Try Again'),
              ),
          ],
        ),
      );
    }

    if (_proposals.isEmpty) {
      return const Center(
        child: Text('No proposals available.'),
      );
    }

    return ListView.builder(
      itemCount: _proposals.length,
      itemBuilder: (context, index) {
        final proposal = _proposals[index];
        final event = _overdueEvents.firstWhere(
          (e) => e.id == proposal['event_id'],
          orElse: () => _overdueEvents[0],
        );

        final originalTime = DateTime.parse(proposal['original_time'] as String);
        final proposedStartTime = DateTime.parse(proposal['proposed_start_time'] as String);
        final reason = proposal['reason'] as String? ?? 'Rescheduled';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${DateFormat('d MMM HH:mm').format(originalTime)} → ${DateFormat('d MMM HH:mm').format(proposedStartTime)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      iconSize: 20,
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () => _editProposedTime(index),
                      tooltip: 'Edit Time',
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reason: $reason',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _confirmAndSave,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm & Save'),
          ),
        ),
      ],
    );
  }
}

