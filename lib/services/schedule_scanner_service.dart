import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/calendar_action.dart';
import '../utils/image_utils.dart';
import 'gemini_service.dart';

/// Service for scanning schedule images and extracting calendar events
class ScheduleScannerService {
  /// Scan an image file and extract calendar events
  /// 
  /// [imageFile] - The image file to scan
  /// Returns a list of CalendarAction objects
  static Future<List<CalendarAction>> scanImage(File imageFile) async {
    try {
      // Convert image to Base64
      final base64String = await ImageUtils.imageToBase64(imageFile);
      if (base64String == null) {
        debugPrint('Failed to convert image to Base64');
        return [];
      }

      // Get MIME type
      final mimeType = ImageUtils.getMimeType(imageFile.path);

      // Call Gemini API to scan the image
      final eventsJson = await GeminiService.scanScheduleImage(base64String, mimeType);
      
      if (eventsJson.isEmpty) {
        debugPrint('No events found in image');
        return [];
      }

      // Convert JSON to CalendarAction objects
      final events = <CalendarAction>[];
      for (final eventJson in eventsJson) {
        try {
          final action = CalendarAction.fromJson(eventJson);
          if (action.isValid()) {
            events.add(action);
          } else {
            debugPrint('Invalid calendar action: ${action.toString()}');
          }
        } catch (e) {
          debugPrint('Error parsing event JSON: $e');
          debugPrint('Event JSON: $eventJson');
        }
      }

      debugPrint('Successfully extracted ${events.length} events from image');
      return events;
    } catch (e, stackTrace) {
      debugPrint('Error scanning schedule image: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }
}

