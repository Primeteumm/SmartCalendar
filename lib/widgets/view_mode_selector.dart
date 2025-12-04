import 'package:flutter/material.dart';

enum CalendarViewMode {
  weekly,
  twoWeeks,
  monthly,
}

class ViewModeSelector extends StatelessWidget {
  final CalendarViewMode selectedMode;
  final Function(CalendarViewMode) onModeChanged;

  const ViewModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CalendarViewMode>(
      segments: const [
        ButtonSegment<CalendarViewMode>(
          value: CalendarViewMode.weekly,
          label: Text('Haftalık'),
        ),
        ButtonSegment<CalendarViewMode>(
          value: CalendarViewMode.twoWeeks,
          label: Text('2 Haftalık'),
        ),
        ButtonSegment<CalendarViewMode>(
          value: CalendarViewMode.monthly,
          label: Text('Aylık'),
        ),
      ],
      selected: {selectedMode},
      onSelectionChanged: (Set<CalendarViewMode> newSelection) {
        onModeChanged(newSelection.first);
      },
    );
  }
}

