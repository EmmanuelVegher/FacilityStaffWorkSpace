import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceRecord {
  final String userId;
  final DateTime date;
  final String clockInTime;
  final String clockOutTime;
  final String clockInLocation;
  final String clockOutLocation;
  final String comments;
  final String durationWorked;
  // ... other fields

  AttendanceRecord({
    required this.userId,
    required this.date,
    required this.clockInTime,
    required this.clockOutTime,
    required this.clockInLocation,
    required this.clockOutLocation,
    required this.comments,
    required this.durationWorked
    // ... other fields
  });

  bool get clockedIn {
    return clockInTime.isNotEmpty; // Check if clockInTime is not empty
  }

  // ... (Factory constructor from Firestore DocumentSnapshot)
  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle the 'date' field, which could be a Timestamp or a String
    DateTime date;
    if (data['date'] is Timestamp) {
      date = (data['date'] as Timestamp).toDate();
    } else if (data['date'] is String) {
      date = DateFormat('dd-MMMM-yyyy').parse(data['date'] as String);
    } else {
      // Handle other data types or throw an error
      throw const FormatException('Invalid date format in Firestore document');
    }

    return AttendanceRecord(
      userId: doc.id,
      date: date,
      clockInTime: data['clockIn'] ?? '',
      clockOutTime: data['clockOut'] ?? '',
      clockInLocation: data['clockInLocation'] ?? '',
      clockOutLocation: data['clockOutLocation'] ?? '',
      comments: data['comments'] ?? '',
        durationWorked:data['durationWorked'] ?? '',

      // ... other fields
    );
  }

  set staffData(Map<String, dynamic>? data) {
    staffData = data;
  }

  @override
  String toString() {
    return 'AttendanceRecord{userId: $userId, date: $date, clockInTime: $clockInTime, clockOutTime: $clockOutTime}'; // Customize as needed
  }
}