import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import 'view_mode_selector.dart';

class DynamicCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final List<Event> events;
  final Function(DateTime) onDateSelected;
  final CalendarViewMode viewMode;

  const DynamicCalendar({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
    required this.viewMode,
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
    final weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

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
              Text(
                widget.viewMode == CalendarViewMode.monthly
                    ? DateFormat('MMMM yyyy', 'tr_TR').format(_currentStartDate)
                    : '${DateFormat('d MMM', 'tr_TR').format(days.first)} - ${DateFormat('d MMM yyyy', 'tr_TR').format(days.last)}',
                style: Theme.of(context).textTheme.titleLarge,
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
                      if (events.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          height: 4,
                          width: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
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

