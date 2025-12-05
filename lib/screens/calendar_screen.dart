import 'package:flutter/material.dart';
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
import 'settings_screen.dart';
import 'ai_assistant_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAiButtonPosition();
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
                initialChildSize: 0.3,
                minChildSize: 0.1,
                maxChildSize: 0.9,
                snap: true,
                snapSizes: const [0.1, 0.3, 0.9],
                builder: (context, scrollController) {
                  return NotesSection(
                selectedDate: _selectedDate,
                eventsOnDate: eventsOnDate,
                notesOnDate: notesOnDate,
                    scrollController: scrollController,
                onEventTap: (event) {
                  // Show event details or edit
                },
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

