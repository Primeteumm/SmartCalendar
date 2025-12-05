import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/event_provider.dart';
import '../providers/note_provider.dart';
import '../widgets/dynamic_calendar.dart';
import '../widgets/notes_section.dart';
import '../widgets/view_mode_selector.dart';
import '../screens/add_note_screen.dart';
import '../models/note.dart';
import '../widgets/scan_schedule_dialog.dart';
import '../widgets/daily_briefing_dialog.dart';
import '../services/open_meteo_service.dart';
import '../services/gemini_service.dart';
import 'settings_screen.dart';
import 'ai_assistant_screen.dart';
import 'dart:convert';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.monthly;
  
  // Draggable AI button position
  Offset _aiButtonPosition = const Offset(20, 100);
  bool _isDragging = false;
  static const double _buttonSize = 64.0;
  static const double _snapThreshold = 50.0; // Distance from edge to snap

  // Daily briefing state
  bool _isLoadingBriefing = false;

  // DraggableScrollableSheet controller
  final DraggableScrollableController _draggableScrollableController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _loadAiButtonPosition();
    // Check for user name and load briefing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserNameAndLoadBriefing();
    });
  }

  @override
  void dispose() {
    _draggableScrollableController.dispose();
    super.dispose();
  }

  void _toggleSheetPosition() {
    final currentSize = _draggableScrollableController.size;
    
    // Toggle between middle (0.3) and max (0.9)
    double nextSize = currentSize < 0.6 ? 0.9 : 0.3;
    
    _draggableScrollableController.animateTo(
      nextSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadAiButtonPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble('ai_button_x') ?? 20.0;
    final y = prefs.getDouble('ai_button_y') ?? 100.0;
    setState(() {
      _aiButtonPosition = Offset(x, y);
    });
  }

  Future<void> _saveAiButtonPosition(Offset position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ai_button_x', position.dx);
    await prefs.setDouble('ai_button_y', position.dy);
  }

  /// Check if user name exists, show dialog if not, then load briefing
  Future<void> _checkUserNameAndLoadBriefing() async {
    final prefs = await SharedPreferences.getInstance();
    String? userName = prefs.getString('user_name');

    if (userName == null || userName.isEmpty) {
      // Show name dialog
      final name = await _showNameDialog();
      if (name != null && name.isNotEmpty) {
        await prefs.setString('user_name', name);
        userName = name;
      } else {
        // User cancelled, don't show briefing
        return;
      }
    }

    // Load briefing with user name
    await _loadDailyBriefing(userName);
  }

  /// Show modern dialog to ask for user's name
  Future<String?> _showNameDialog() async {
    final nameController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  'Hoş Geldiniz!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SmartCalendar\'a hoş geldiniz',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                ),
                const SizedBox(height: 24),
                // Text Field
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Adınız nedir?',
                    hintText: 'Adınızı girin',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (value) {
                    final name = value.trim();
                    if (name.isNotEmpty) {
                      Navigator.of(context).pop(name);
                    }
                  },
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          'İptal',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isNotEmpty) {
                            Navigator.of(context).pop(name);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: const Text('Kaydet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Load daily briefing with weather and schedule
  Future<void> _loadDailyBriefing(String userName) async {
    if (_isLoadingBriefing) return;

    setState(() {
      _isLoadingBriefing = true;
    });

    try {
      // Get today's events and notes
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      final today = DateTime.now();
      final todayEvents = eventProvider.getEventsByDate(today);
      final todayNotes = noteProvider.getNotesByDate(today);

      // Combine events and notes
      final todaySchedule = <Map<String, dynamic>>[];
      
      // Add events
      for (final event in todayEvents) {
        todaySchedule.add({
          'title': event.title,
          'time': event.time ?? 'All Day',
          'datetime': event.date.toIso8601String(),
        });
      }
      
      // Add notes
      for (final note in todayNotes) {
        // Extract note content (may be JSON or plain text)
        String noteContent = note.content;
        try {
          final json = jsonDecode(note.content);
          if (json is Map && json.containsKey('note_content')) {
            noteContent = json['note_content'] as String;
          }
        } catch (_) {
          // If not JSON, use content as-is
        }
        
        final displayTitle = note.title ?? noteContent.split('\n').first.split('.').first.trim();
        final timeStr = note.date.hour == 12 && note.date.minute == 0
            ? 'All Day'
            : '${note.date.hour.toString().padLeft(2, '0')}:${note.date.minute.toString().padLeft(2, '0')}';
        
        todaySchedule.add({
          'title': displayTitle,
          'note_content': noteContent,
          'time': timeStr,
          'datetime': note.date.toIso8601String(),
        });
      }

      // Sort by time
      todaySchedule.sort((a, b) {
        final aTime = a['time'] as String;
        final bTime = b['time'] as String;
        if (aTime == 'All Day') return 1;
        if (bTime == 'All Day') return -1;
        return aTime.compareTo(bTime);
      });

      // Fetch weather
      final weather = await OpenMeteoService.getCurrentWeather();

      // Generate briefing
      final briefing = await GeminiService.generateDailyBriefing(
        todaySchedule,
        weather,
        userName,
      );

      if (mounted) {
        setState(() {
          _isLoadingBriefing = false;
        });
        
        // Show full-screen dialog
        DailyBriefingDialog.show(context, briefing);
      }
    } catch (e) {
      debugPrint('Error loading daily briefing: $e');
      if (mounted) {
        setState(() {
          _isLoadingBriefing = false;
        });
      }
    }
  }


  /// Snap button to nearest edge if close enough
  Offset _snapToEdge(Offset position, double screenWidth, double screenHeight) {
    double x = position.dx;
    double y = position.dy;

    // Check left edge
    if (x < _snapThreshold) {
      x = 0;
    }
    // Check right edge
    else if (x > screenWidth - _buttonSize - _snapThreshold) {
      x = screenWidth - _buttonSize;
    }

    // Check top edge
    if (y < _snapThreshold) {
      y = 0;
    }
    // Check bottom edge
    else if (y > screenHeight - _buttonSize - _snapThreshold) {
      y = screenHeight - _buttonSize;
    }

    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartCalendar'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: 'Takvimi Tara',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ScanScheduleDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer2<EventProvider, NoteProvider>(
        builder: (context, eventProvider, noteProvider, child) {
          final eventsOnDate = eventProvider.getEventsByDate(_selectedDate);
          final notesOnDate = noteProvider.getNotesByDate(_selectedDate);

          final theme = Theme.of(context);
          
          return Stack(
            children: [
              // Calendar - takes full screen
              SizedBox(
                height: MediaQuery.of(context).size.height,
                child: DynamicCalendar(
                  selectedDate: _selectedDate,
                  events: eventProvider.events,
                  notes: noteProvider.notes,
                  onDateSelected: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  viewMode: _viewMode,
                  onViewModeChanged: (mode) {
                    setState(() {
                      _viewMode = mode;
                    });
                  },
                ),
              ),
              // Draggable Notes section
              DraggableScrollableSheet(
                controller: _draggableScrollableController,
                initialChildSize: 0.3,
                minChildSize: 0.3,
                maxChildSize: 0.9,
                snap: true,
                snapSizes: const [0.3, 0.9],
                builder: (context, scrollController) {
                  return NotesSection(
                selectedDate: _selectedDate,
                eventsOnDate: eventsOnDate,
                notesOnDate: notesOnDate,
                    scrollController: scrollController,
                onEventTap: (event) {
                  // Show event details or edit
                },
                onDragHandleTap: _toggleSheetPosition,
                  );
                },
              ),
              // Draggable AI Assistant Button
              Positioned(
                left: _aiButtonPosition.dx,
                top: _aiButtonPosition.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _isDragging = true;
                      final newPosition = _aiButtonPosition + details.delta;
                      final screenWidth = MediaQuery.of(context).size.width;
                      final screenHeight = MediaQuery.of(context).size.height;
                      
                      // Constrain to screen bounds
                      final constrainedPosition = Offset(
                        newPosition.dx.clamp(0.0, screenWidth - _buttonSize),
                        newPosition.dy.clamp(0.0, screenHeight - _buttonSize),
                      );
                      
                      _aiButtonPosition = constrainedPosition;
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isDragging = false;
                      final screenWidth = MediaQuery.of(context).size.width;
                      final screenHeight = MediaQuery.of(context).size.height;
                      
                      // Snap to nearest edge
                      _aiButtonPosition = _snapToEdge(
                        _aiButtonPosition,
                        screenWidth,
                        screenHeight,
                      );
                    });
                    _saveAiButtonPosition(_aiButtonPosition);
                  },
                  child: _buildDraggableAiButton(theme),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
            onPressed: () async {
          final note = await Navigator.of(context).push<Note>(
                MaterialPageRoute(
              builder: (context) => AddNoteScreen(initialDate: _selectedDate),
              fullscreenDialog: true,
            ),
                );

          if (note != null && mounted) {
            await Provider.of<NoteProvider>(context, listen: false).addNote(note);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note added successfully')),
                    );
                  }
              }
            },
        child: const Icon(Icons.add),
          ),
    );
  }

  Widget _buildDraggableAiButton(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      transform: Matrix4.identity()..scale(_isDragging ? 1.1 : 1.0),
      child: Container(
        width: _buttonSize,
        height: _buttonSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.6), // Daha şeffaf
              theme.colorScheme.primary.withOpacity(0.5), // Daha şeffaf
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(_isDragging ? 0.3 : 0.2),
              blurRadius: _isDragging ? 16 : 12,
              offset: Offset(0, _isDragging ? 4 : 2),
              spreadRadius: _isDragging ? 2 : 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AIAssistantScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(_buttonSize / 2),
            child: Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: theme.colorScheme.onPrimary.withOpacity(0.9),
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

