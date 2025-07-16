import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../services/location_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/app_gradients.dart';

class MapPicker extends StatefulWidget {
  final String? initialLocation;
  final Function(String location, double lat, double lng) onLocationSelected;

  const MapPicker({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  LatLng _selectedLocation = LatLng(0.3476, 32.5825); // Default to Kampala
  String _selectedAddress = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  void _setInitialLocation() {
    if (widget.initialLocation != null &&
        widget.initialLocation!.contains(',')) {
      final parts = widget.initialLocation!.split(',');
      if (parts.length == 2) {
        try {
          final lat = double.parse(parts[0].trim());
          final lng = double.parse(parts[1].trim());
          setState(() {
            _selectedLocation = LatLng(lat, lng);
            _isLoading = false;
          });
          _getAddressFromCoordinates(_selectedLocation);
          return;
        } catch (e) {
          // Fall through to geolocator
        }
      }
    }
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      // Get address for current location
      _getAddressFromCoordinates(_selectedLocation);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromCoordinates(LatLng position) async {
    try {
      // Use the new async reverse geocoding method
      String locationName = await LocationService.getAddressFromCoordinates(
        position,
      );
      setState(() {
        _selectedAddress = locationName;
      });
    } catch (e) {
      setState(() {
        _selectedAddress =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
    _getAddressFromCoordinates(position);
  }

  void _onCameraMove(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundGradient = appBackgroundGradient(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'Select Location',
        backgroundColor: colorScheme.primary.withAlpha((0.85 * 255).toInt()),
        foregroundColor: colorScheme.onPrimary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: colorScheme.onPrimary,
            ),
            onPressed: () {
              // Only call the callback, do NOT update LocationProvider here
              widget.onLocationSelected(
                _selectedAddress,
                _selectedLocation.latitude,
                _selectedLocation.longitude,
              );
              Navigator.pop(context);
            },
            child: Text(
              'Confirm',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 15.0,
                onTap: (tapPosition, point) {
                  _onMapTap(point);
                },
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    _onCameraMove(position.center!);
                  }
                },
                onMapReady: () {
                  _getAddressFromCoordinates(_selectedLocation);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.StarShoppingUG.CropWise',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Selected Location:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedAddress.isNotEmpty
                          ? _selectedAddress
                          : 'Tap on map to select location',
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(170),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coordinates: ${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withAlpha(85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Floating button for current location
            Positioned(
              bottom: 110,
              right: 10,
              child: FloatingActionButton.extended(
                heroTag: 'use_current_location',
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                icon: const Icon(Icons.my_location),
                label: const Text('Use Current'),
                onPressed: () async {
                  setState(() => _isLoading = true);
                  await _initializeLocation();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
