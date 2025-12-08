import 'package:flutter/foundation.dart' show debugPrint;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Result class for location data
class LocationData {
  final double latitude;
  final double longitude;
  final String cityName;
  final String? countryName;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.cityName,
    this.countryName,
  });

  @override
  String toString() {
    return 'LocationData(lat: $latitude, long: $longitude, city: $cityName)';
  }
}

/// Service for managing device location and permissions
class LocationManager {
  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }

  /// Check current location permission status
  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Request location permission
  /// Returns true if permission is granted, false otherwise
  static Future<bool> requestPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return false;
      }

      // Check current permission status
      LocationPermission permission = await checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return false;
      }

      // Permission granted (whileInUse or always)
      debugPrint('Location permission granted: $permission');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error requesting location permission: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get current device position
  /// Returns Position if successful, null otherwise
  static Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    try {
      // Check and request permission first
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('Location permission not granted');
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeLimit,
      );

      debugPrint('Current position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e, stackTrace) {
      debugPrint('Error getting current position: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get city name from coordinates using reverse geocoding
  /// Returns city name if successful, null otherwise
  static Future<String?> getCityNameFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isEmpty) {
        debugPrint('No placemarks found for coordinates');
        return null;
      }

      final placemark = placemarks.first;
      
      // Try to get city name (locality)
      String? cityName = placemark.locality;
      
      // Fallback to subAdministrativeArea or administrativeArea if locality is null
      if (cityName == null || cityName.isEmpty) {
        cityName = placemark.subAdministrativeArea ?? placemark.administrativeArea;
      }
      
      // Final fallback to country if nothing else is available
      if (cityName == null || cityName.isEmpty) {
        cityName = placemark.country;
      }

      debugPrint('City name resolved: $cityName');
      return cityName;
    } catch (e, stackTrace) {
      debugPrint('Error getting city name from coordinates: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get complete location data (position + city name)
  /// This is the main method to use for getting location info
  /// Returns LocationData if successful, null otherwise
  static Future<LocationData?> getCurrentLocation() async {
    try {
      // Get current position
      final position = await getCurrentPosition();
      if (position == null) {
        debugPrint('Failed to get current position');
        return null;
      }

      // Get city name from coordinates
      final cityName = await getCityNameFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (cityName == null || cityName.isEmpty) {
        debugPrint('Failed to get city name, using coordinates as fallback');
        return LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          cityName: 'Unknown Location',
        );
      }

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: cityName,
      );
    } catch (e, stackTrace) {
      debugPrint('Error getting current location: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
}

