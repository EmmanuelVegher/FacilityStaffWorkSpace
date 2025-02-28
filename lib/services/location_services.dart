import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, request user to enable it
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions in the background instead.
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return false;
    }

    return true; // Permissions granted
  }

  Future<Position?> getCurrentPosition() async {
    if (await _handleLocationPermission()) {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    }
    return null;
  }

  Future<double?> getLatitude() async {
    Position? position = await getCurrentPosition();
    return position?.latitude;
  }

  Future<double?> getLongitude() async {
    Position? position = await getCurrentPosition();
    return position?.longitude;
  }

  Future<bool> getLocationStatus() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }
}