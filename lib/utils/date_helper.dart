import 'package:intl/intl.dart';

class DateHelper {
  // Method to get the start date of the week (Sunday)
  static DateTime getStartDateOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday));
  }

  static int calculateEarlyLateTime(String? clockInTime, {String targetTime = '08:00'}) {
    if (clockInTime == null || clockInTime.isEmpty) {
      return 0; // Or handle null/empty clockInTime differently
    }

    try {
      final clockInMinutes = timeOfDayToMinutes(clockInTime);
      final targetMinutes = timeOfDayToMinutes(targetTime);

      return clockInMinutes - targetMinutes;

    } catch (e) {
      print("Error calculating early/late time: $e");
      return 0; // Or handle the error differently
    }
  }

  static int timeOfDayToMinutes(String? timeString) { // Allow null values
    if (timeString == null || timeString.isEmpty) {
      return 0; // Return 0 for empty/null times
    }

    // Try parsing in 24-hour format first
    try {
      final parsedTime = DateFormat("HH:mm").parse(timeString);
      return parsedTime.hour * 60 + parsedTime.minute;
    } catch (e) {
      // If 24-hour format fails, try 12-hour format
      try {
        final parsedTime = DateFormat("h:mm a").parse(timeString);
        return parsedTime.hour * 60 + parsedTime.minute;
      } catch (e) {
        print("Error parsing time: $e - Time String: $timeString");
        return 0; // Return 0 for invalid formats
      }
    }
  }

  /// Function to convert time strings (clockIn, clockOut) to hours worked
  static double calculateHoursWorked(String clockIn, String clockOut) {
    try {
      // Parse clockIn and clockOut using 12-hour format
      final clockInTime = DateFormat("h:mm a").parse(clockIn);
      final clockOutTime = DateFormat("h:mm a").parse(clockOut);

      // Calculate the difference in minutes
      final differenceInMinutes = clockOutTime.difference(clockInTime).inMinutes;

      // Convert minutes to hours
      final hoursWorked = differenceInMinutes / 60.0;
      print("hoursWorked === $hoursWorked");

      return hoursWorked;
    } catch (e) {
      print("Error parsing time: $e - Clock In: $clockIn, Clock Out: $clockOut");
      return 0.0; // Return 0 in case of error
    }
  }


  static int calculateDurationWorkedInMinutes(String clockInTime, String clockOutTime) {
    if (clockInTime.isEmpty || clockOutTime.isEmpty) {
      return 0; // Or handle empty times differently
    }

    final clockInDateTime = _parseTime(clockInTime);
    final clockOutDateTime = _parseTime(clockOutTime);

    if (clockInDateTime == null || clockOutDateTime == null) {
      return 0; // Handle invalid time formats
    }

    final duration = clockOutDateTime.difference(clockInDateTime);
    return duration.inMinutes;
  }

  // Helper function to parse time strings
  static DateTime? _parseTime(String timeString) {
    try {
      return DateFormat("HH:mm").parse(timeString);
    } catch (e) {
      print("Error parsing time: $e");
      return null;
    }
  }
}