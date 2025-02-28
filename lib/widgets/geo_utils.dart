import 'dart:math';
//calculate the distance between two geographic coordinate points using the Haversine formula, which is commonly used to find the shortest distance between two points on the Earth's surface given their latitude and longitude.
class GeoUtils {
  static const double earthRadius = 6371; // Radius of the Earth in kilometers

  static double degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double dLat = degreesToRadians(lat2 - lat1);
    double dLon = degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(degreesToRadians(lat1)) * cos(degreesToRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    double distance = earthRadius * c; // Distance in kilometers

    // Convert distance to meters
    distance *= 1000;
   // log('Distance between the two points: $distance meters');
    return distance;
  }

  // static double haversine(double lat1, double lon1, double lat2, double lon2) {
  //   // Convert latitude and longitude from degrees to radians
  //   double dLat = (lat2 - lat1) * (pi / 180);
  //   double dLon = (lon2 - lon1) * (pi / 180);
  //
  //   // Calculate the Haversine distance
  //   double a = pow(sin(dLat / 2), 2) +
  //       cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) * pow(sin(dLon / 2), 2);
  //   double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  //
  //   // Calculate the distance in kilometers
  //   double distance = 6371.0 * c;
  //   // Convert distance to meters
  //   distance *= 1000;
  //   print(distance);
  //   return distance;
  // }

  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    // Convert latitude and longitude to two decimals
    // double lat1Decimal = double.parse(lat1.toStringAsFixed(10));
    // double lon1Decimal = double.parse(lon1.toStringAsFixed(10));
    // double lat2Decimal = double.parse(lat2.toStringAsFixed(10));
    // double lon2Decimal = double.parse(lon2.toStringAsFixed(10));
    //
    // print(lat1Decimal);
    // print(lon1Decimal);
    // print(lat2Decimal);
    // print(lon2Decimal);

    // Convert latitude and longitude from degrees to radians
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);

    // Calculate the Haversine distance
    double a = pow(sin(dLat / 2), 2) +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) * pow(sin(dLon / 2), 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // Calculate the distance in kilometers
    //double distance = 40075.017 * c;
    double distance = 6371.0 * c;

    // Convert distance to meters
    distance *= 1000;

    //print(distance);
    return distance;
  }



}


