import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsProvider with ChangeNotifier {
  static const String _locationEnabledKey = 'location_enabled';
  static const String _notificationsEnabledKey = 'notifications_enabled';

  bool _locationEnabled = false;
  bool _notificationsEnabled = false;

  bool get locationEnabled => _locationEnabled;
  bool get notificationsEnabled => _notificationsEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _locationEnabled = prefs.getBool(_locationEnabledKey) ?? false;
      _notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Toggle location permission and save preference
  Future<bool> toggleLocation() async {
    try {
      if (_locationEnabled) {
        // Disable location
        _locationEnabled = false;
        await _saveLocationSetting(false);
        notifyListeners();
        return true;
      } else {
        // Request location permission
        final status = await Permission.location.request();
        if (status.isGranted) {
          _locationEnabled = true;
          await _saveLocationSetting(true);
          notifyListeners();
          return true;
        } else if (status.isPermanentlyDenied) {
          // Show dialog to open app settings
          await openAppSettings();
          return false;
        } else {
          debugPrint('Location permission denied');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error toggling location: $e');
      return false;
    }
  }

  /// Toggle notification permission and save preference
  Future<bool> toggleNotifications() async {
    try {
      if (_notificationsEnabled) {
        // Disable notifications
        _notificationsEnabled = false;
        await _saveNotificationSetting(false);
        notifyListeners();
        return true;
      } else {
        // Request notification permission
        final status = await Permission.notification.request();
        if (status.isGranted) {
          _notificationsEnabled = true;
          await _saveNotificationSetting(true);
          notifyListeners();
          return true;
        } else if (status.isPermanentlyDenied) {
          // Show dialog to open app settings
          await openAppSettings();
          return false;
        } else {
          debugPrint('Notification permission denied');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error toggling notifications: $e');
      return false;
    }
  }

  /// Check current permission status
  Future<void> checkPermissionStatus() async {
    try {
      final locationStatus = await Permission.location.status;
      _locationEnabled = locationStatus.isGranted;
      
      final notificationStatus = await Permission.notification.status;
      _notificationsEnabled = notificationStatus.isGranted;
      
      // Sync with saved preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_locationEnabledKey, _locationEnabled);
      await prefs.setBool(_notificationsEnabledKey, _notificationsEnabled);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking permission status: $e');
    }
  }

  Future<void> _saveLocationSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_locationEnabledKey, enabled);
    } catch (e) {
      debugPrint('Error saving location setting: $e');
    }
  }

  Future<void> _saveNotificationSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsEnabledKey, enabled);
    } catch (e) {
      debugPrint('Error saving notification setting: $e');
    }
  }
}

