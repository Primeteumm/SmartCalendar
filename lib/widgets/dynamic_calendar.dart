import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/note.dart';
import 'view_mode_selector.dart';

class DynamicCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final List<Event> events;
  final List<Note> notes;
  final Function(DateTime) onDateSelected;
  final CalendarViewMode viewMode;
  final Function(CalendarViewMode) onViewModeChanged;

  const DynamicCalendar({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.notes,
    required this.onDateSelected,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  @override
  State<DynamicCalendar> createState() => _DynamicCalendarState();
}

class _DynamicCalendarState extends State<DynamicCalendar> {
  late DateTime _currentStartDate;

  @override
  void initState() {
    super.initState();
    _updateCurrentStartDate();
  }

  @override
  void didUpdateWidget(DynamicCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewMode != widget.viewMode ||
        oldWidget.selectedDate != widget.selectedDate) {
      _updateCurrentStartDate();
    }
  }

  void _updateCurrentStartDate() {
    switch (widget.viewMode) {
      case CalendarViewMode.weekly:
        _currentStartDate = widget.selectedDate.subtract(
          Duration(days: widget.selectedDate.weekday - 1),
        );
        break;
      case CalendarViewMode.twoWeeks:
        _currentStartDate = widget.selectedDate.subtract(
          Duration(days: widget.selectedDate.weekday - 1),
        );
        break;
      case CalendarViewMode.monthly:
        _currentStartDate = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          1,
        );
        break;
    }
  }

  List<DateTime> _getDaysToDisplay() {
    int daysCount;
    switch (widget.viewMode) {
      case CalendarViewMode.weekly:
        daysCount = 7;
        break;
      case CalendarViewMode.twoWeeks:
        daysCount = 14;
        break;
      case CalendarViewMode.monthly:
        final lastDay = DateTime(
          _currentStartDate.year,
          _currentStartDate.month + 1,
          0,
        ).day;
        final firstWeekday = _currentStartDate.weekday;
        daysCount = lastDay + firstWeekday - 1;
        break;
    }

    return List.generate(daysCount, (index) {
      if (widget.viewMode == CalendarViewMode.monthly) {
        if (index < _currentStartDate.weekday - 1) {
          return DateTime(
            _currentStartDate.year,
            _currentStartDate.month - 1,
            DateTime(_currentStartDate.year, _currentStartDate.month, 0)
                .day -
                (_currentStartDate.weekday - 2 - index),
          );
        } else {
          return DateTime(
            _currentStartDate.year,
            _currentStartDate.month,
            index - (_currentStartDate.weekday - 1) + 1,
          );
        }
      } else {
        return _currentStartDate.add(Duration(days: index));
      }
    });
  }

  List<Event> _getEventsForDate(DateTime date) {
    return widget.events.where((event) {
      return event.date.year == date.year &&
          event.date.month == date.month &&
          event.date.day == date.day;
    }).toList();
  }

  List<Note> _getNotesForDate(DateTime date) {
    return widget.notes.where((note) {
      return note.date.year == date.year &&
          note.date.month == date.month &&
          note.date.day == date.day;
    }).toList();
  }

  Widget _buildNoteIndicators(int count) {
    if (count == 0) return const SizedBox.shrink();
    
    final displayCount = count > 6 ? 6 : count;
    final rows = (displayCount / 3).ceil();
    final List<Widget> dots = [];
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    for (int row = 0; row < rows && row < 2; row++) {
      final startIndex = row * 3;
      final endIndex = (startIndex + 3 < displayCount) ? startIndex + 3 : displayCount;
      final rowDots = <Widget>[];
      
      for (int i = startIndex; i < endIndex; i++) {
        rowDots.add(
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.4),
                  blurRadius: 2,
                  spreadRadius: 0.3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        );
      }
      
      dots.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowDots,
        ),
      );
      // Add spacing between rows
      if (row < rows - 1 && row < 1) {
        dots.add(const SizedBox(height: 3));
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: dots,
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isCurrentMonth(DateTime date) {
    return date.month == _currentStartDate.month &&
        date.year == _currentStartDate.year;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysToDisplay();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        // Month/Week header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    switch (widget.viewMode) {
                      case CalendarViewMode.weekly:
                        _currentStartDate = _currentStartDate.subtract(
                          const Duration(days: 7),
                        );
                        break;
                      case CalendarViewMode.twoWeeks:
                        _currentStartDate = _currentStartDate.subtract(
                          const Duration(days: 14),
                        );
                        break;
                      case CalendarViewMode.monthly:
                        _currentStartDate = DateTime(
                          _currentStartDate.year,
                          _currentStartDate.month - 1,
                          1,
                        );
                        break;
                    }
                  });
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMMM yyyy', 'en_US').format(_currentStartDate),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      CalendarViewMode newMode;
                      switch (widget.viewMode) {
                        case CalendarViewMode.monthly:
                          newMode = CalendarViewMode.twoWeeks;
                          break;
                        case CalendarViewMode.twoWeeks:
                          newMode = CalendarViewMode.weekly;
                          break;
                        case CalendarViewMode.weekly:
                          newMode = CalendarViewMode.monthly;
                          break;
                      }
                      widget.onViewModeChanged(newMode);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.viewMode == CalendarViewMode.monthly
                            ? 'Month'
                            : widget.viewMode == CalendarViewMode.twoWeeks
                                ? '2 Week'
                                : 'Week',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    switch (widget.viewMode) {
                      case CalendarViewMode.weekly:
                        _currentStartDate = _currentStartDate.add(
                          const Duration(days: 7),
                        );
                        break;
                      case CalendarViewMode.twoWeeks:
                        _currentStartDate = _currentStartDate.add(
                          const Duration(days: 14),
                        );
                        break;
                      case CalendarViewMode.monthly:
                        _currentStartDate = DateTime(
                          _currentStartDate.year,
                          _currentStartDate.month + 1,
                          1,
                        );
                        break;
                    }
                  });
                },
              ),
            ],
          ),
        ),
        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: weekdays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              final events = _getEventsForDate(date);
              final notes = _getNotesForDate(date);
              final isSelected = _isSameDay(date, widget.selectedDate);
              final isCurrentMonth = widget.viewMode == CalendarViewMode.monthly
                  ? _isCurrentMonth(date)
                  : true;

              return GestureDetector(
                onTap: () => widget.onDateSelected(date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isCurrentMonth
                                  ? (isSelected
                                      ? Theme.of(context)
                                          .colorScheme.onPrimaryContainer
                                      : Theme.of(context)
                                          .colorScheme.onSurface)
                                  : Theme.of(context)
                                      .colorScheme.onSurface
                                      .withOpacity(0.4),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                      ),
                      if (events.isNotEmpty || notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _buildNoteIndicators(events.length + notes.length),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

