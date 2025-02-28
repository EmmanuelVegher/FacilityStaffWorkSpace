// import 'dart:async';
// import 'package:flutter/material.dart'; // Required for background tasks
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:geolocator/geolocator.dart';
//
// import 'notification_services.dart';
//
// // Function to get the device's current location.
// Future<Position?> _determinePosition() async {
//   bool serviceEnabled;
//   LocationPermission permission;
//
//   // Check if location services are enabled on the device.
//   serviceEnabled = await Geolocator.isLocationServiceEnabled();
//   if (!serviceEnabled) {
//     return Future.error('Location services are disabled.');
//   }
//
//   // Request location permissions from the user.
//   permission = await Geolocator.checkPermission();
//   if (permission == LocationPermission.denied) {
//     permission = await Geolocator.requestPermission();
//     if (permission == LocationPermission.denied) {
//       return Future.error('Location permissions are denied');
//     }
//   }
//
//   // Handle the case where location permissions are permanently denied.
//   if (permission == LocationPermission.deniedForever) {
//     return Future.error(
//         'Location permissions are permanently denied, we cannot request permissions.');
//   }
//
//   // If all checks pass, get the current position.
//   return await Geolocator.getCurrentPosition();
// }
//
// // Function to simulate storing geolocation data.
// // Replace this with your actual data storage logic (e.g., database, file).
// Future<void> _storeGeolocation(Position position) async {
//   // TODO: Implement your logic to store latitude & longitude.
//   print('Latitude: ${position.latitude}, Longitude: ${position.longitude}');
// }
//
// // Modified backgroundTaskIsolate function to accept ServiceInstance
// void backgroundTaskIsolate(ServiceInstance service) async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // Get an instance of the FlutterBackgroundService.
//   final service = FlutterBackgroundService();
//   // Create an instance of your notification helper.
//   final notifyHelper = NotifyHelper();
//
//   // Initialize notifications when the background service starts.
//   notifyHelper.initializeNotification();
//
//
//   // // Schedule the 8:00 AM and 5:00 PM notifications.
//   // notifyHelper.scheduleDailyNotifications(
//   //     1, 'Good Morning!', 'Have a productive day!', 8, 0);
//   // notifyHelper.scheduleDailyNotifications(
//   //     2, 'Good Evening!', 'Time to unwind!', 17, 0);
//
//   // Accessing the service instance to communicate with the main isolate
//   Timer.periodic(const Duration(minutes: 1), (timer) async {
//     // Check if the background service is still running.
//     if (!(await service.isRunning())) return;
//
//
//     // Get the current time.
//     final now = DateTime.now();
//
//     // 12:00 PM Geolocation logic
//     if (now.hour == 12 && now.minute == 0) {
//       // Get the current position.
//       Position? position = await _determinePosition();
//       // If the position is successfully retrieved, store it.
//       if (position != null) {
//         _storeGeolocation(position);
//       }
//     }
//
//     // Optional: Send data back to the main isolate (foreground).
//     // This is useful for updating the UI or performing other tasks.
//     service.invoke('update', {'current time': DateTime.now().toString()});
//   });
// }