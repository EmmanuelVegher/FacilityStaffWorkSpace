//
// import 'package:geolocator/geolocator.dart';
// import '../model/track_location_model.dart';
// import 'isar_service.dart';
//
// class LocationTrackingService {
//   // static Future<void> initializeLocationTracking() async {
//   //   Workmanager().registerOneOffTask(
//   //     'locationTrackingTask',
//   //     'trackLocation',
//   //     initialDelay: _calculateDelayUntil12PM(),
//   //     constraints: Constraints(
//   //       networkType: NetworkType.not_required,
//   //     ),
//   //   );
//   // }
//
//   static Duration _calculateDelayUntil12PM() {
//     // ... (your implementation)
//     final now = DateTime.now();
//     final twelvePM = DateTime(now.year, now.month, now.day, 12);
//     return twelvePM.difference(now);
//   }
//
//   static Future<void> trackLocation() async {
//     // Request location permission if needed
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       return Future.error('Location services are disabled.');
//     }
//
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         return Future.error('Location permissions are denied');
//       }
//     }
//
//     if (permission == LocationPermission.deniedForever) {
//       return Future.error(
//           'Location permissions are permanently denied, we cannot request permissions.');
//     }
//
//     // Get current position
//     Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high);
//
//     print("New Position LocationTrackingService ==== $position");
//
//     // Store in Isar Database
//     // Assuming you have a model for location data and a method to save it in Isar
//     final locationData = TrackLocationModel(
//       latitude: position.latitude,
//       longitude: position.longitude,
//       timestamp: DateTime.now(),
//     );
//     await IsarService().saveLocationData(locationData);
//   }
// }