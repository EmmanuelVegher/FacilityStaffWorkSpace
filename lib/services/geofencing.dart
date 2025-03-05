import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';


class GeofenceModel {
  final String name;
  final double latitude;
  final double longitude;
  final double radius;

  GeofenceModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}

class GeoFencing extends StatefulWidget {
  const GeoFencing({super.key});

  @override
  State<GeoFencing> createState() => _GeoFencingState();
}

class _GeoFencingState extends State<GeoFencing> {
  // // Create a Geolocator object.
  // final geolocator = Geolocator();
  //
  // // Create a geofence.
  // final geofence = Circle(
  //   center: LatLng(37.7833, -122.4167),
  //   radius: 100,
  // );


  @override
  void initState() {
    super.initState();
    _startGeofencing();
  }

  void _startGeofencing() async {
    // Implement your geofencing logic here
    // Get the current location periodically and check if it is inside the geofence

    // Example: Get the current location every 10 seconds
    const Duration interval = Duration(seconds: 10);
    Timer.periodic(interval, (Timer timer) async {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // Check if the current position is inside the geofence
      List<GeofenceModel> offices = getGeofenceOffices();
      for (GeofenceModel office in offices) {
        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          office.latitude,
          office.longitude,
        );

        if (distance <= office.radius) {
          // Device is inside the geofence, perform geofencing actions for this office
          print('Entered office: ${office.name}');
        }
      }
    });
  }

  List<GeofenceModel> getGeofenceOffices() {
    // Implement this function to return a list of GeofenceModel objects for your offices
    // Example:
    List<GeofenceModel> offices = [
      GeofenceModel(name: 'Office 1', latitude: 37.7749, longitude: -122.4194, radius: 100),
      GeofenceModel(name: 'Office 2', latitude: 37.7395, longitude: -122.3897, radius: 150),
      // Add more office coordinates
    ];
    return offices;
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
