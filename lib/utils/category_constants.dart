import 'package:flutter/material.dart';

/// Predefined categories with their associated colors
class CategoryConstants {
  // Category names
  static const String school = 'School';
  static const String work = 'Work';
  static const String social = 'Social';
  static const String health = 'Health';
  static const String general = 'General';

  // Category color mappings (hex codes)
  static const Map<String, String> categoryColors = {
    school: '#FF0000',  // Red
    work: '#0000FF',    // Blue
    social: '#FFA500',  // Orange
    health: '#00FF00',  // Green
    general: '#808080', // Grey
  };

  /// Get color hex for a category
  static String getColorHex(String category) {
    return categoryColors[category] ?? categoryColors[general]!;
  }

  /// Get Color object from hex string
  static Color getColorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Get all available categories
  static List<String> get allCategories => categoryColors.keys.toList();

  /// Check if a category is valid
  static bool isValidCategory(String category) {
    return categoryColors.containsKey(category);
  }
}

