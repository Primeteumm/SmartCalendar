import 'package:flutter/foundation.dart' show debugPrint;
import '../models/event.dart';
import '../models/note.dart';

/// Service for analyzing calendar data and generating insights
class AnalyticsService {
  /// Get category breakdown for events and notes within a date range
  /// Returns a map of category -> total hours spent
  /// Assumes 1 hour duration per event/note if no time is specified
  static Map<String, double> getCategoryBreakdown({
    required List<Event> events,
    required List<Note> notes,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final categoryHours = <String, double>{};

    // Process events
    for (final event in events) {
      // Check if event is within date range
      if (event.date.isBefore(startDate) || event.date.isAfter(endDate)) {
        continue;
      }

      // Calculate duration (assume 1 hour if no time specified or all-day)
      double duration = 1.0; // Default 1 hour
      
      if (event.time != null && !event.time!.isEmpty) {
        // Try to parse time and estimate duration
        // For simplicity, assume 1 hour unless it's an all-day event
        duration = 1.0;
      }

      // Add to category total
      final category = event.category;
      categoryHours[category] = (categoryHours[category] ?? 0.0) + duration;
    }

    // Process notes
    for (final note in notes) {
      // Check if note is within date range
      if (note.date.isBefore(startDate) || note.date.isAfter(endDate)) {
        continue;
      }

      // Calculate duration (assume 1 hour for notes)
      double duration = 1.0;

      // Add to category total
      final category = note.category;
      categoryHours[category] = (categoryHours[category] ?? 0.0) + duration;
    }

    debugPrint('Category breakdown: $categoryHours');
    return categoryHours;
  }

  /// Get category breakdown for the last N days
  static Map<String, double> getCategoryBreakdownLastNDays({
    required List<Event> events,
    required List<Note> notes,
    required int days,
  }) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getCategoryBreakdown(
      events: events,
      notes: notes,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get most active day in the period
  static DateTime? getMostActiveDay({
    required List<Event> events,
    required List<Note> notes,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final dayCounts = <DateTime, int>{};

    // Count events per day
    for (final event in events) {
      if (event.date.isBefore(startDate) || event.date.isAfter(endDate)) {
        continue;
      }
      final day = DateTime(event.date.year, event.date.month, event.date.day);
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }

    // Count notes per day
    for (final note in notes) {
      if (note.date.isBefore(startDate) || note.date.isAfter(endDate)) {
        continue;
      }
      final day = DateTime(note.date.year, note.date.month, note.date.day);
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }

    if (dayCounts.isEmpty) return null;

    // Find day with maximum count
    DateTime? mostActiveDay;
    int maxCount = 0;
    dayCounts.forEach((day, count) {
      if (count > maxCount) {
        maxCount = count;
        mostActiveDay = day;
      }
    });

    return mostActiveDay;
  }

  /// Get total hours for a specific category
  static double getCategoryTotalHours(
    Map<String, double> breakdown,
    String category,
  ) {
    return breakdown[category] ?? 0.0;
  }

  /// Get total hours across all categories
  static double getTotalHours(Map<String, double> breakdown) {
    return breakdown.values.fold(0.0, (sum, hours) => sum + hours);
  }
}

