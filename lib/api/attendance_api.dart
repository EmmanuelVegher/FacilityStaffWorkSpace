import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show ByteData, Uint8List, rootBundle;


import '../models/attendance_record.dart';
import '../utils/constants.dart'; // Your constants file


class AttendanceAPI {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;



  Future<List<AttendanceRecord>> getWeeklyRecords(String userId, DateTime startDate) async {
    final endDate = startDate.add(const Duration(days: 6));
    final records = <AttendanceRecord>[];

    try {
      for (int i = 0; i <= 6; i++) {
        final currentDate = startDate.add(Duration(days: i));
        final formattedDate = DateFormat('dd-MMMM-yyyy').format(currentDate);
        final documentSnapshot = await FirebaseFirestore.instance
            .collection('Staff')
            .doc(userId)
            .collection('Record')
            .doc(formattedDate)
            .get();

        if (documentSnapshot.exists) {
          records.add(AttendanceRecord.fromFirestore(documentSnapshot));
        }
      }

      print("Pulled Records: $records");
    } catch (e) {
      print('Error fetching data: $e');
      rethrow; // Re-throw the error for proper error handling in the UI
    }

    return records;
  }

  Future<List<AttendanceRecord>> getRecordsForDateRangeForChart(DateTime startDate, DateTime endDate) async {
    final records = <AttendanceRecord>[];
    final firestore = FirebaseFirestore.instance;

    try{
      final staffSnapshot = await firestore.collection('Staff').get();

      // final locationSnapshot = await firestore.collection('Location').get();
      //
      // // Assuming 'assets/caritas_logo.png' is the path to your image
      // String base64Image = await imageToBase64('assets/image/caritaslogo1.png');
      //
      // // Map to store locations categorized by type (Facility, Hotel, etc.)
      // final locationTypeMap = <String, Map<String, String>>{};

      // Iterate through each state document and its sub-collections
      // for (var stateDoc in locationSnapshot.docs) {
      //   final stateName = stateDoc.id;
      //   final subCollectionSnapshot = await firestore
      //       .collection('Location')
      //       .doc(stateName)
      //       .collection(stateName) // Sub-collection with the same name as the state
      //       .get();
      //   //
      //   // for (var locationDoc in subCollectionSnapshot.docs) {
      //   //   final locationName = locationDoc.id;
      //   //   final locationData = locationDoc.data();
      //   //   final category = locationData['category'] ?? ''; // Assuming category field exists
      //   //
      //   //   if (!locationTypeMap.containsKey(category)) {
      //   //     locationTypeMap[category] = {};
      //   //   }
      //   //   locationTypeMap[category]![locationName] = 'Within CARITAS ${category}s';
      //   // }
      // }

      // for (var date = startDate;
      //       .get();
      //
      //   if (recordSnapshot.exists) {
      //     records.add(AttendanceRecord.fromFirestore(recordSnapshot));
      //   }
      // }
      // for (var staffDoc in staffSnapshot.docs) {
      //   final userId = staffDoc.id;
      //   final staffData = staffDoc.data();
      //   final primaryFacility = staffData['location'] ?? '';
      //
      //
      //   for (var date = startDate;
      //   date.isBefore(endDate.add(const Duration(days: 1)));
      //   date = date.add(const Duration(days: 1))) {
      //     final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
      //     print("formattedDate == $formattedDate");
      //     final recordSnapshot = await firestore
      //         .collection('Staff')
      //         .doc(userId)
      //         .collection('Record')
      //         .doc(formattedDate)
      //         .get();
      //
      //     if (recordSnapshot.exists) {
      //       records.add(AttendanceRecord.fromFirestore(recordSnapshot));
      //     }
      //   }
      //
      //
      //
      // }
    }catch(e){
      print('Error fetching data: $e');
      rethrow;
    }

    return records;
  }



  Future<String> imageToBase64(String imagePath) async {
    final ByteData bytes = await rootBundle.load(imagePath);
    final buffer = bytes.buffer;
    return base64Encode(Uint8List.view(buffer));
  }

  Future<void> getRecordsForDateRange(DateTime startDate, DateTime endDate) async {
    final firestore = FirebaseFirestore.instance;

    try {
      final staffSnapshot = await firestore.collection('Staff').get();
      final locationSnapshot = await firestore.collection('Location').get();

      // Assuming 'assets/caritas_logo.png' is the path to your image
      String base64Image = await imageToBase64('assets/image/caritaslogo1.png');

      // Map to store locations categorized by type (Facility, Hotel, etc.)
      final locationTypeMap = <String, Map<String, String>>{};

      // Iterate through each state document and its sub-collections
      for (var stateDoc in locationSnapshot.docs) {
        final stateName = stateDoc.id;
        final subCollectionSnapshot = await firestore
            .collection('Location')
            .doc(stateName)
            .collection(stateName) // Sub-collection with the same name as the state
            .get();

        for (var locationDoc in subCollectionSnapshot.docs) {
          final locationName = locationDoc.id;
          final locationData = locationDoc.data();
          final category = locationData['category'] ?? ''; // Assuming category field exists

          if (!locationTypeMap.containsKey(category)) {
            locationTypeMap[category] = {};
          }
          locationTypeMap[category]![locationName] = 'Within CARITAS ${category}s';
        }
      }

      // Now process the attendance records for each staff member
      for (var staffDoc in staffSnapshot.docs) {
        final userId = staffDoc.id;
        final staffData = staffDoc.data();
        final primaryFacility = staffData['location'] ?? '';

        final userRecords = <AttendanceRecord>[];

        for (var date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
          final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
          final recordSnapshot = await firestore
              .collection('Staff')
              .doc(userId)
              .collection('Record')
              .doc(formattedDate)
              .get();

          if (recordSnapshot.exists) {
            userRecords.add(AttendanceRecord.fromFirestore(recordSnapshot));
          }
        }



        // Location Summary Counts
        int withinPrimaryFacilityCountClockIn = 0;
        int withinOtherCaritasLocationsCountClockIn = 0;
        int outsideCaritasLocationsCountClockIn = 0;

        int withinPrimaryFacilityCountClockOut = 0;
        int withinOtherCaritasLocationsCountClockOut = 0;
        int outsideCaritasLocationsCountClockOut = 0;

        for (var record in userRecords) {
          final clockInLocation = record.clockInLocation;
          final clockOutLocation = record.clockOutLocation;

          // Clock In Location Check
          if (clockInLocation == primaryFacility) {
            withinPrimaryFacilityCountClockIn++;
          } else if (isWithinCaritasLocations(clockInLocation, locationTypeMap)) {
            withinOtherCaritasLocationsCountClockIn++;
          } else {
            outsideCaritasLocationsCountClockIn++;
          }

          // Clock Out Location Check
          if (clockOutLocation == primaryFacility) {
            withinPrimaryFacilityCountClockOut++;
          } else if (isWithinCaritasLocations(clockOutLocation, locationTypeMap)) {
            withinOtherCaritasLocationsCountClockOut++;
          } else {
            outsideCaritasLocationsCountClockOut++;
          }
        }

        // Send email if there are any records to send
        if (userRecords.isNotEmpty) {
          await _sendEmailWithRecords(
            staffData,
            userRecords,
            DateFormat('dd-MMMM-yyyy').format(startDate),
            DateFormat('dd-MMMM-yyyy').format(endDate),
            withinPrimaryFacilityCountClockIn,
            withinOtherCaritasLocationsCountClockIn,
            outsideCaritasLocationsCountClockIn,
            withinPrimaryFacilityCountClockOut,
            withinOtherCaritasLocationsCountClockOut,
            outsideCaritasLocationsCountClockOut,
            base64Image, // Pass the base64 encoded image here

          );
        }
      }

      print('Successfully processed records and sent emails.');

    } catch (e) {
      print('Error fetching data or sending emails: $e');
      rethrow;
    }
  }

  bool isWithinCaritasLocations(String location, Map<String, Map<String, String>> locationTypeMap) {
    for (var category in locationTypeMap.keys) {
      if (locationTypeMap[category]!.containsKey(location)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _sendEmailWithRecords(
      Map<String, dynamic> staffData,
      List<AttendanceRecord> records,
      String startDate,
      String endDate,
      int withinPrimaryFacilityCountClockIn,
      int withinOtherCaritasLocationsCountClockIn,
      int outsideCaritasLocationsCountClockIn,
      int withinPrimaryFacilityCountClockOut,
      int withinOtherCaritasLocationsCountClockOut,
      int outsideCaritasLocationsCountClockOut,
      String base64Image, // Add this line
      ) async {
    final firstName = staffData['firstName'] ?? '';
    final lastName = staffData['lastName'] ?? '';
    final email = staffData['emailAddress'] ?? '';
    final primaryFacility = staffData['location'] ?? '';
    final supervisorEmail = staffData['supervisorEmail'] ?? '';

    final subject = 'Weekly Attendance Records for the week: $startDate to $endDate';
    int earlyClockInsCount = 0;
    int totalClockIns = records.length;
    final body = '''
  Dear $firstName $lastName,

  <br><br>

  Primary Facility/Office Location: $primaryFacility

  <br><br>

  Here is your weekly attendance summary:

  <br><br>

  1) Weekly Attendance Summary:

  <br><br>

  ${records.map((record) {
      final date = record.date;
      final clockInTime = record.clockInTime;
      final clockOutTime = record.clockOutTime;
      final clockInLocation = record.clockInLocation;
      final clockOutLocation = record.clockOutLocation;
      final comments = record.comments;
      final durationWorked = record.durationWorked;

      // Parse clock-in time from string to DateTime
      DateTime? clockInDateTime;
      if (clockInTime.isNotEmpty) {
        try {
          clockInDateTime = DateFormat("HH:mm").parse(clockInTime);
        } catch (e) {
          print("Error parsing clock-in time: $e");
        }
      }

      // Check if clock-in time is before 8:00 AM
      if (clockInDateTime != null && clockInDateTime.hour < 8) {
        earlyClockInsCount++;
      }

      return "&nbsp;&nbsp;&nbsp;&nbsp;☐ ${DateFormat('dd-MMMM-yyyy').format(date)} (${DateFormat('EEEE').format(record.date)}): Clocked in at $clockInTime, Clocked out at $clockOutTime, Duration: $durationWorked, Comments: $comments, Clock In Location: $clockInLocation, Clock Out Location: $clockOutLocation";
    }).join('<br><br>')}

  <br><br><br>

  2) Location Summary:
  
  
  <br><br>

  &nbsp;&nbsp;&nbsp;&nbsp;☐ Early Clock-ins (Number of Clock-Ins done before 8:00AM): $earlyClockInsCount/$totalClockIns day(s) (${(earlyClockInsCount / totalClockIns * 100).toStringAsFixed(2)}%)


       <br><br>
          ☐ Clock-Ins: Within Primary Facility: $withinPrimaryFacilityCountClockIn, Within Any other CARITAS Location: $withinOtherCaritasLocationsCountClockIn, Outside CARITAS Locations: $outsideCaritasLocationsCountClockIn
      
      <br><br>
          ☐ Clock-Outs: Within Primary Facility: $withinPrimaryFacilityCountClockOut, Within Any other CARITAS Location: $withinOtherCaritasLocationsCountClockOut, Outside CARITAS Locations: $outsideCaritasLocationsCountClockOut
  
  <br><br>

  For further details, kindly visit the dashboard at:
  https://lookerstudio.google.com/reporting/e021c456-efe7-43ae-86c9-ca25ebfbdd2f

  <br><br>
  
  Please note that if you have synced any attendance that is not reflected in this report or on the dashboard, kindly click on the sync icon on each of the Attendance to perform singular synchronization of the missing Attendance.Note that this is only available for Version 1.5 upward.
  <br><br>
  <span style="color:black;  font-size:15px; font-weight:bold;">Best Regards,</span>
  <br>
  <span style="color:black;  font-size:16px; font-weight:bold;">VEGHER, Emmanuel.</span>
  <br>
  <span style="color:black;  font-size:16px; font-weight:bold;">SENIOR Technical Specialist  - Health Informatics.</span>
  <br>
  <span style="color:red;  font-size:16px; font-weight:bold;">Caritas Nigeria (CCFN)</span>
  <br>
  <span style="color:black;">Catholic Secretariat of Nigeria Building,</span>
  <br>
  <span style="color:black;">Plot 459 Cadastral Zone B2, Durumi 1, Garki, Abuja</span>
  <br>
  <span style="color:black;">Mobile: (Office) +234-8103465662, +234-9088988551</span>
  <br>
  <span style="color:black;">Email: Evegher@ccfng.org | Facebook: www.facebook.com/CaritasNigeria</span>
  <br>
  <span style="color:black;">Website: www.caritasnigeria.org | Linkedin: www.linkedin.com/in/emmanuel-vegher-221718190/</span>
  <br><br>
 <!-- Add the Base64 image here -->
  <img src="data:image/png;base64,$base64Image" alt="Caritas Nigeria Logo" style="width:200px; height:auto;">

 
  
  ''';

    try {
      await sendEmail(email, subject, body, cc: supervisorEmail);
      print('Email sent successfully to $email (CC: $supervisorEmail)');
    } catch (e) {
      print('Error sending email: $e');
    }
  }


// Modified sendEmail function to fit into the code structure
  Future<void> sendEmail(String recipient, String subject, String body, {String? cc}) async {
    final url = Uri.parse('$URL/send-email');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'recipient': "vegher.emmanuel@gmail.com",
        'subject': subject,
        'body': body,
        //'cc': cc,
      }),
    );

    if (response.statusCode == 200) {
      print('Email request successful');
    } else {
      throw Exception('Failed to send email: ${response.body}');
    }
  }
}

  // ... (Other Firestore data fetching methods)


