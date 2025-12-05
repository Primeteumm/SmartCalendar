import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;

/// Utility class for image processing operations
class ImageUtils {
  /// Convert an image file to Base64 encoded string
  /// 
  /// [imageFile] - The File object representing the image
  /// Returns Base64 encoded string, or null if conversion fails
  static Future<String?> imageToBase64(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        debugPrint('Image file does not exist: ${imageFile.path}');
        return null;
      }

      // Read the file as bytes
      final bytes = await imageFile.readAsBytes();
      
      // Convert to Base64
      final base64String = base64Encode(bytes);
      
      debugPrint('Image converted to Base64 successfully. Size: ${bytes.length} bytes');
      return base64String;
    } catch (e, stackTrace) {
      debugPrint('Error converting image to Base64: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get MIME type from file extension
  /// 
  /// [filePath] - The path of the file
  /// Returns MIME type string (e.g., 'image/jpeg', 'image/png')
  static String getMimeType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        // Default to jpeg if unknown
        return 'image/jpeg';
    }
  }
}

