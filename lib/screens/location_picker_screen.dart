import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  LatLng _currentMapCenter = const LatLng(41.0082, 28.9784); // Default Istanbul
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
      _currentMapCenter = _selectedLocation!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_selectedLocation!, 15.0);
      });
    } else {
      _focusOnUserLocation();
    }
  }

  Future<void> _focusOnUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        final location = LatLng(position.latitude, position.longitude);
        setState(() {
          _selectedLocation = location;
          _currentMapCenter = location;
          _isLoadingLocation = false;
        });
        _mapController.move(location, 15.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _currentMapCenter = point;
    });
  }

  void _confirmSelection() {
    // Use selected location if available, otherwise use current map center
    final locationToReturn = _selectedLocation ?? _currentMapCenter;
    Navigator.of(context).pop({
      'latitude': locationToReturn.latitude,
      'longitude': locationToReturn.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Select Location',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isLoadingLocation)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.my_location,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: _focusOnUserLocation,
              tooltip: 'Use current location',
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation ?? _currentMapCenter,
              initialZoom: _selectedLocation != null ? 15.0 : 10.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: _onMapTap,
              onMapEvent: (MapEvent event) {
                if (event is MapEventMove) {
                  // Update current map center when map is moved
                  setState(() {
                    _currentMapCenter = event.camera.center;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: () {
                  final apiKey = dotenv.isInitialized
                      ? (dotenv.env['MAPTILER_API_KEY'] ?? '')
                      : '';
                  if (apiKey.isEmpty) {
                    return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
                  }
                  return 'https://api.maptiler.com/maps/019ba219-501c-796c-a5e2-83eb4d97e900/256/{z}/{x}/{y}.png?key=$apiKey';
                }(),
                userAgentPackageName: 'com.smartcalendar.app',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      alignment: Alignment(
                        0,
                        1,
                      ), // Bottom center - pin tip aligns with point
                      child: Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 50,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Center crosshair
          Center(
            child: IgnorePointer(
              child: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.primary,
                size: 40,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedLocation != null
                                ? 'Selected Location'
                                : 'Map Center',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedLocation != null
                                ? '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}'
                                : '${_currentMapCenter.latitude.toStringAsFixed(6)}, ${_currentMapCenter.longitude.toStringAsFixed(6)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _confirmSelection,
                icon: const Icon(Icons.check),
                label: const Text('Confirm Location'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
