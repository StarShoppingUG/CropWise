import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static Future<String> getCurrentLocationName() async {
    try {
      // Check for permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Location permission denied';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return 'Location permissions are permanently denied';
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Convert to LatLng and then to a readable name
      return 'Location (${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)})';
    } catch (e) {
      return 'Could not get location';
    }
  }

  static Future<Map<String, double>?> getCurrentCoordinates() async {
    try {
      // Check for permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return {'lat': position.latitude, 'lon': position.longitude};
    } catch (e) {
      return null;
    }
  }

  /// Reverse geocode coordinates to a human-readable address using Nominatim
  static Future<String> getAddressFromCoordinates(LatLng position) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'CropWise/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Use name (e.g. "Makerere University") if available
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          return data['name'];
        }

        final address = data['address'];
        if (address != null) {
          final parts =
              [
                address['road'],
                address['neighbourhood'],
                address['suburb'],
                address['village'],
                address['town'],
                address['city'],
                address['county'],
                address['state'],
                address['country'],
              ].where((part) => part != null).toList();

          return parts.join(', ');
        }
      }
    } catch (_) {}

    return 'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
  }
}
