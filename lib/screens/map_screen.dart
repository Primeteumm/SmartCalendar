import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../providers/event_provider.dart';
import '../providers/note_provider.dart';
import '../models/event.dart';
import '../models/note.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Position? _userLocation;
  bool _showLocationBanner = false;
  bool _showLocationErrorBanner = false;

  @override
  void initState() {
    super.initState();
    _focusOnUserLocation();
  }

  Future<void> _focusOnUserLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _showLocationErrorBanner = true;
          });
          // Hide banner after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _showLocationErrorBanner = false;
              });
            }
          });
        }
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _showLocationErrorBanner = true;
            });
            // Hide banner after 5 seconds
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {
                  _showLocationErrorBanner = false;
                });
              }
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _showLocationErrorBanner = true;
          });
          // Hide banner after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _showLocationErrorBanner = false;
              });
            }
          });
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Focus map on user location and show banner
      if (mounted) {
        setState(() {
          _userLocation = position;
          _showLocationBanner = true;
        });

        _mapController.move(
          LatLng(position.latitude, position.longitude),
          13.0, // Zoom level
        );

        // Hide banner after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showLocationBanner = false;
            });
          }
        });
      }
    } catch (e) {
      // If location cannot be obtained, show error banner
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() {
          _showLocationErrorBanner = true;
        });
        // Hide banner after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showLocationErrorBanner = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<EventProvider, NoteProvider>(
        builder: (context, eventProvider, noteProvider, child) {
          final eventsWithLocation = eventProvider.getEventsWithLocation();
          final notesWithLocation = noteProvider.getNotesWithLocation();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(41.0082, 28.9784), // Istanbul default
                  initialZoom: 10.0,
                  minZoom: 3.0,
                  maxZoom: 18.0,
                ),
                children: [
                  // MapTiler tile layer with OpenStreetMap fallback
                  TileLayer(
                    urlTemplate: () {
                      final apiKey = dotenv.isInitialized 
                          ? (dotenv.env['MAPTILER_API_KEY'] ?? '') 
                          : '';
                      if (apiKey.isEmpty) {
                        // Fallback to OpenStreetMap if no API key
                        debugPrint('MAPTILER_API_KEY not found, using OpenStreetMap');
                        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
                      }
                      return 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$apiKey';
                    }(),
                    userAgentPackageName: 'com.smartcalendar.app',
                  ),
                  // Markers layer
                  MarkerLayer(
                    markers: [
                      // User location marker
                      if (_userLocation != null)
                        Marker(
                          point: LatLng(
                            _userLocation!.latitude,
                            _userLocation!.longitude,
                          ),
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                      // Event markers
                      ...eventsWithLocation
                          .where((event) =>
                              event.latitude != null && event.longitude != null)
                          .map((event) => Marker(
                                point: LatLng(
                                  event.latitude!,
                                  event.longitude!,
                                ),
                                width: 50,
                                height: 50,
                                alignment: Alignment(0, 1), // Bottom center - pin tip aligns with point
                                child: GestureDetector(
                                  onTap: () {
                                    _showEventInfo(context, event);
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 50,
                                          maxHeight: 18,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          event.title.length > 5 
                                              ? '${event.title.substring(0, 5)}...' 
                                              : event.title,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      Icon(
                                        Icons.location_on,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                      // Note markers (events created from notes)
                      ...notesWithLocation
                          .where((note) =>
                              note.latitude != null && note.longitude != null)
                          .map((note) => Marker(
                                point: LatLng(
                                  note.latitude!,
                                  note.longitude!,
                                ),
                                width: 50,
                                height: 50,
                                alignment: Alignment(0, 1), // Bottom center - pin tip aligns with point
                                child: GestureDetector(
                                  onTap: () {
                                    _showNoteInfo(context, note);
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 50,
                                          maxHeight: 18,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          () {
                                            final title = note.title ?? 'Event';
                                            return title.length > 5 
                                                ? '${title.substring(0, 5)}...' 
                                                : title;
                                          }(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      Icon(
                                        Icons.location_on,
                                        color: Theme.of(context).colorScheme.secondary,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                    ],
                  ),
                ],
              ),
              // Location success banner
              if (_showLocationBanner)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Location retrieved successfully',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _showLocationBanner = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Location error banner
              if (_showLocationErrorBanner)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Location could not be retrieved',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _showLocationErrorBanner = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showEventInfo(BuildContext context, Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.time != null) ...[
              Text('Time: ${event.time}'),
              const SizedBox(height: 8),
            ],
            if (event.description != null) ...[
              Text(event.description!),
              const SizedBox(height: 8),
            ],
            if (event.locationName != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text(event.locationName!)),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNoteInfo(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note.title ?? 'Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${DateFormat('EEEE, MMMM dd, yyyy', 'en_US').format(note.date)}',
            ),
            if (note.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(note.content),
            ],
            if (note.locationName != null && note.locationName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text(note.locationName!)),
                ],
              ),
            ],
            if (note.latitude != null && note.longitude != null) ...[
              const SizedBox(height: 8),
              Text(
                'Coordinates: ${note.latitude!.toStringAsFixed(6)}, ${note.longitude!.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

