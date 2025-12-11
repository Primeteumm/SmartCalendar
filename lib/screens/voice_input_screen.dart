import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_service.dart';
import '../services/gemini_service.dart';
import '../providers/event_provider.dart';
import '../providers/note_provider.dart';
import '../models/event.dart';
import '../models/note.dart';
import 'package:intl/intl.dart';

/// Screen for recording voice brain dump with multiple mixed intents
class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with SingleTickerProviderStateMixin {
  String _transcribedText = '';
  bool _isListening = false;
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveformAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _waveformAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    VoiceService.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    // Check and request permission
    final hasPermission = await VoiceService.checkPermission();
    if (!hasPermission) {
      final granted = await VoiceService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Initialize voice service
    final initialized = await VoiceService.initialize();
    if (!initialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _transcribedText = '';
    });

    _animationController.repeat();

    // Start listening
    final result = await VoiceService.listen(
      onTranscription: (text) {
        if (mounted) {
          setState(() {
            _transcribedText = text;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isListening = false;
        if (result != null && result.isNotEmpty) {
          _transcribedText = result;
        }
      });
      _animationController.stop();
      _animationController.reset();
    }
  }

  Future<void> _stopListening() async {
    await VoiceService.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
      _animationController.stop();
      _animationController.reset();
    }
  }

  Future<void> _processBrainDump() async {
    if (_transcribedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please record something first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Send to AI for processing
      final result = await GeminiService.processBrainDump(_transcribedText);

      if (result.isEmpty) {
        throw Exception('No items extracted from brain dump');
      }

      // Parse and save items
      final summary = await _saveBrainDumpItems(result);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _transcribedText = '';
        });

        // Show summary dialog
        _showSummaryDialog(summary);
      }
    } catch (e) {
      debugPrint('Error processing brain dump: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<Map<String, int>> _saveBrainDumpItems(List<Map<String, dynamic>> items) async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);

    int eventsCount = 0;
    int tasksCount = 0;
    int notesCount = 0;

    for (final item in items) {
      try {
        final type = item['type'] as String? ?? 'note';
        final title = item['title'] as String? ?? 'Untitled';
        final description = item['description'] as String?;

        if (type == 'event') {
          // Create Event
          final datetimeStr = item['datetime'] as String?;
          DateTime eventDate;
          String? eventTime;

          if (datetimeStr != null && datetimeStr.isNotEmpty) {
            try {
              eventDate = DateTime.parse(datetimeStr);
              eventTime = DateFormat('HH:mm').format(eventDate);
            } catch (e) {
              eventDate = DateTime.now();
            }
          } else {
            eventDate = DateTime.now();
          }

          final category = item['category'] as String? ?? 'General';
          final colorHex = item['color_hex'] as String? ?? '#808080';

          final event = Event(
            id: '${DateTime.now().millisecondsSinceEpoch}_$eventsCount',
            title: title,
            date: eventDate,
            time: eventTime,
            description: description,
            category: category,
            colorHex: colorHex,
            isCompleted: false,
          );

          await eventProvider.addEvent(event);
          eventsCount++;
        } else if (type == 'task') {
          // Create Event as Task (using isCompleted field)
          final priority = item['priority'] as String? ?? 'medium';
          final dueDateStr = item['due_date'] as String?;
          DateTime taskDate;

          if (dueDateStr != null && dueDateStr.isNotEmpty) {
            try {
              taskDate = DateTime.parse(dueDateStr);
            } catch (e) {
              taskDate = DateTime.now();
            }
          } else {
            taskDate = DateTime.now();
          }

          // Map priority to color
          String colorHex = '#808080';
          if (priority == 'high') {
            colorHex = '#FF0000';
          } else if (priority == 'medium') {
            colorHex = '#FFA500';
          } else {
            colorHex = '#00FF00';
          }

          final event = Event(
            id: '${DateTime.now().millisecondsSinceEpoch}_task_$tasksCount',
            title: title,
            date: taskDate,
            description: description,
            category: 'General',
            colorHex: colorHex,
            isCompleted: false, // Task is not completed
          );

          await eventProvider.addEvent(event);
          tasksCount++;
        } else {
          // Create Note
          final noteDateStr = item['date'] as String?;
          DateTime noteDate;

          if (noteDateStr != null && noteDateStr.isNotEmpty) {
            try {
              noteDate = DateTime.parse(noteDateStr);
            } catch (e) {
              noteDate = DateTime.now();
            }
          } else {
            noteDate = DateTime.now();
          }

          final category = item['category'] as String? ?? 'General';
          final colorHex = item['color_hex'] as String? ?? '#808080';

          final note = Note(
            id: '${DateTime.now().millisecondsSinceEpoch}_note_$notesCount',
            eventId: '',
            content: description ?? title,
            createdAt: DateTime.now(),
            title: title,
            date: noteDate,
            category: category,
            colorHex: colorHex,
          );

          await noteProvider.addNote(note);
          notesCount++;
        }
      } catch (e) {
        debugPrint('Error saving brain dump item: $e');
        // Continue with next item
      }
    }

    return {
      'events': eventsCount,
      'tasks': tasksCount,
      'notes': notesCount,
    };
  }

  void _showSummaryDialog(Map<String, int> summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            const Text('Brain Dump Processed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary['events']! > 0)
              Text('✅ Created ${summary['events']} event${summary['events']! > 1 ? 's' : ''}'),
            if (summary['tasks']! > 0)
              Text('✅ Added ${summary['tasks']} task${summary['tasks']! > 1 ? 's' : ''}'),
            if (summary['notes']! > 0)
              Text('✅ Saved ${summary['notes']} note${summary['notes']! > 1 ? 's' : ''}'),
            if (summary['events'] == 0 && summary['tasks'] == 0 && summary['notes'] == 0)
              const Text('No items were extracted from your brain dump.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Close voice input screen too
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Brain Dump'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Speak naturally about events, tasks, and notes. I\'ll organize them automatically.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Microphone button with animation
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Waveform visualization
                      if (_isListening)
                        AnimatedBuilder(
                          animation: _waveformAnimation,
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(200, 100),
                              painter: WaveformPainter(_waveformAnimation.value),
                            );
                          },
                        ),
                      const SizedBox(height: 40),

                      // Microphone button
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isListening ? _pulseAnimation.value : 1.0,
                            child: GestureDetector(
                              onTap: _isListening ? _stopListening : _startListening,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: _isListening
                                        ? [
                                            theme.colorScheme.primary,
                                            theme.colorScheme.primary.withOpacity(0.7),
                                          ]
                                        : [
                                            theme.colorScheme.surfaceContainerHighest,
                                            theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                                          ],
                                  ),
                                  boxShadow: _isListening
                                      ? [
                                          BoxShadow(
                                            color: theme.colorScheme.primary.withOpacity(0.5),
                                            blurRadius: 30,
                                            spreadRadius: 10,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  _isListening ? Icons.mic : Icons.mic_none,
                                  size: 60,
                                  color: _isListening
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Status text
                      Text(
                        _isListening
                            ? 'Listening...'
                            : _isProcessing
                                ? 'Processing...'
                                : 'Tap to start recording',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: _isListening
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Transcribed text display
              if (_transcribedText.isNotEmpty || _isListening)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _transcribedText.isEmpty
                          ? 'Listening...'
                          : _transcribedText,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing || _isListening
                          ? null
                          : () {
                              setState(() {
                                _transcribedText = '';
                              });
                            },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing || _isListening || _transcribedText.isEmpty
                          ? null
                          : _processBrainDump,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_isProcessing ? 'Processing...' : 'Process'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
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

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  final double animationValue;

  WaveformPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    const waveCount = 5;
    final waveWidth = size.width / waveCount;

    for (int i = 0; i < waveCount; i++) {
      final x = i * waveWidth + waveWidth / 2;
      final amplitude = 30 * (0.5 + 0.5 * ((animationValue + i * 0.2) % 1.0));
      final path = Path();
      path.moveTo(x, centerY - amplitude);
      path.quadraticBezierTo(
        x + waveWidth / 4,
        centerY - amplitude * 1.5,
        x + waveWidth / 2,
        centerY,
      );
      path.quadraticBezierTo(
        x + waveWidth * 3 / 4,
        centerY + amplitude * 1.5,
        x + waveWidth,
        centerY + amplitude,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

