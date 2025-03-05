import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as locationPkg;
import 'package:percent_indicator/percent_indicator.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';

import '../../services/location_services.dart';
import '../../widgets/drawer.dart';
import '../../widgets/header_widget.dart';
import '../../widgets/geo_utils.dart';

// Model Classes
class LeaveRequestModel {
  String? leaveRequestId;
  String? staffId;
  String? type;
  DateTime? startDate;
  DateTime? endDate;
  String? reason;
  String? status;
  String? selectedSupervisor;
  String? selectedSupervisorEmail;
  int? leaveDuration;
  bool isSynced;
  String? firstName;
  String? lastName;
  String? staffCategory;
  String? staffState;
  String? staffLocation;
  String? staffEmail;
  String? staffPhone;
  String? staffDepartment;
  String? staffDesignation;
  String? reasonsForRejectedLeave;


  LeaveRequestModel({
    this.leaveRequestId,
    this.staffId,
    this.type,
    this.startDate,
    this.endDate,
    this.reason,
    this.status = 'Pending',
    this.selectedSupervisor,
    this.selectedSupervisorEmail,
    this.leaveDuration,
    this.isSynced = false,
    this.firstName,
    this.lastName,
    this.staffCategory,
    this.staffState,
    this.staffLocation,
    this.staffEmail,
    this.staffPhone,
    this.staffDepartment,
    this.staffDesignation,
    this.reasonsForRejectedLeave
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      leaveRequestId: json['leaveRequestId'] as String?,
      staffId: json['staffId'] as String?,
      type: json['type'] as String?,
      startDate: json['startDate'] != null ? (json['startDate'] as Timestamp).toDate() : null,
      endDate: json['endDate'] != null ? (json['endDate'] as Timestamp).toDate() : null,
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'Pending',
      selectedSupervisor: json['selectedSupervisor'] as String?,
      selectedSupervisorEmail: json['selectedSupervisorEmail'] as String?,
      leaveDuration: json['leaveDuration'] as int?,
      isSynced: json['isSynced'] as bool? ?? false,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      staffCategory: json['staffCategory'] as String?,
      staffState: json['staffState'] as String?,
      staffLocation: json['staffLocation'] as String?,
      staffEmail: json['staffEmail'] as String?,
      staffPhone: json['staffPhone'] as String?,
      staffDepartment: json['staffDepartment'] as String?,
      staffDesignation: json['staffDesignation'] as String?,
      reasonsForRejectedLeave: json['reasonsForRejectedLeave'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'leaveRequestId': leaveRequestId,
      'staffId': staffId,
      'type': type,
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
      'status': status,
      'selectedSupervisor': selectedSupervisor,
      'selectedSupervisorEmail': selectedSupervisorEmail,
      'leaveDuration': leaveDuration,
      'isSynced': isSynced,
      'firstName': firstName,
      'lastName': lastName,
      'staffCategory': staffCategory,
      'staffState': staffState,
      'staffLocation': staffLocation,
      'staffEmail': staffEmail,
      'staffPhone': staffPhone,
      'staffDepartment': staffDepartment,
      'staffDesignation': staffDesignation,
      'reasonsForRejectedLeave': reasonsForRejectedLeave,
    };
  }
}

class AttendanceModel {
  int? Offline_DB_id;
  String? date;
  String? clockIn;
  String? clockOut;
  double? clockInLatitude;
  double? clockInLongitude;
  String? clockInLocation;
  double? clockOutLatitude;
  double? clockOutLongitude;
  String? clockOutLocation;
  bool? isSynced;
  bool? voided;
  bool? offDay;
  String? durationWorked;
  double? noOfHours;
  bool? isUpdated;
  String? month;
  String? comments;

  AttendanceModel({
    this.Offline_DB_id,
    this.date,
    this.clockIn,
    this.clockOut,
    this.clockInLatitude,
    this.clockInLongitude,
    this.clockInLocation,
    this.clockOutLatitude,
    this.clockOutLongitude,
    this.clockOutLocation,
    this.isSynced,
    this.voided,
    this.offDay,
    this.durationWorked,
    this.noOfHours,
    this.isUpdated,
    this.month,
    this.comments,
  });


  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      Offline_DB_id: json['Offline_DB_id'] as int?,
      date: json['date'] as String?,
      clockIn: json['clockIn'] as String?,
      clockOut: json['clockOut'] as String?,
      clockInLatitude: _parseStringToDouble(json['clockInLatitude']),
      clockInLongitude: _parseStringToDouble(json['clockInLongitude']),
      clockInLocation: json['clockInLocation'] as String?,
      clockOutLatitude: _parseStringToDouble(json['clockOutLatitude']),
      clockOutLongitude: _parseStringToDouble(json['clockOutLongitude']),
      clockOutLocation: json['clockOutLocation'] as String?,
      isSynced: _parseToBool(json['isSynced']),
      voided: _parseToBool(json['voided']),
      offDay: _parseToBool(json['offDay']),
      durationWorked: json['durationWorked'] as String?,
      noOfHours: _parseStringToDouble(json['noOfHours']),
      isUpdated: _parseToBool(json['isUpdated']),
      month: json['month'] as String?,
      comments: json['comments'] as String?,
    );
  }

  static double? _parseStringToDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }


  static bool? _parseToBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value != 0; // Assuming 0 is false, and anything else (like 1) is true
    }
    if (value is String) {
      if (value.toLowerCase() == 'true') {
        return true;
      } else if (value.toLowerCase() == 'false') {
        return false;
      }
    }
    return null; // Return null if parsing fails or type is unexpected
  }


  Map<String, dynamic> toJson() {
    return {
      'Offline_DB_id': Offline_DB_id,
      'date': date,
      'clockIn': clockIn,
      'clockOut': clockOut,
      'clockInLatitude': clockInLatitude,
      'clockInLongitude': clockInLongitude,
      'clockInLocation': clockInLocation,
      'clockOutLatitude': clockOutLatitude,
      'clockOutLongitude': clockOutLongitude,
      'clockOutLocation': clockOutLocation,
      'isSynced': isSynced,
      'voided': voided,
      'offDay': offDay,
      'durationWorked': durationWorked,
      'noOfHours': noOfHours,
      'isUpdated': isUpdated,
      'month': month,
      'comments': comments,
    };
  }
}

class BioModel {
  String? firebaseAuthId;
  String? firstName;
  String? lastName;
  String? emailAddress;
  String? mobile;
  String? gender;
  String? maritalStatus;
  String? designation;
  String? department;
  String? location;
  String? state;
  String? role;
  String? staffCategory;


  BioModel({
    this.firebaseAuthId,
    this.firstName,
    this.lastName,
    this.emailAddress,
    this.mobile,
    this.gender,
    this.maritalStatus,
    this.designation,
    this.department,
    this.location,
    this.state,
    this.role,
    this.staffCategory,

  });

  factory BioModel.fromJson(Map<String, dynamic> json) {
    return BioModel(
      firebaseAuthId: json['firebaseAuthId'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      emailAddress: json['emailAddress'] as String?,
      mobile: json['mobile'] as String?,
      gender: json['gender'] as String?,
      maritalStatus: json['maritalStatus'] as String?,
      designation: json['designation'] as String?,
      department: json['department'] as String?,
      location: json['location'] as String?,
      state: json['state'] as String?,
      role: json['role'] as String?,
      staffCategory: json['staffCategory'] as String?,

    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firebaseAuthId': firebaseAuthId,
      'firstName': firstName,
      'lastName': lastName,
      'emailAddress': emailAddress,
      'mobile': mobile,
      'gender': gender,
      'maritalStatus': maritalStatus,
      'designation': designation,
      'department': department,
      'location': location,
      'state': state,
      'role': role,
      'staffCategory': staffCategory,

    };
  }
}

class LocationModel {
  String? locationId;
  String? locationName;
  double? latitude;
  double? longitude;
  double? radius;
  String? state;
  String? lga;

  LocationModel({
    this.locationId,
    this.locationName,
    this.latitude,
    this.longitude,
    this.radius,
    this.state,
    this.lga,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      locationId: json['locationId'] as String?,
      locationName: json['locationName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radius: (json['radius'] as num?)?.toDouble(),
      state: json['state'] as String?,
      lga: json['lga'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locationId': locationId,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'state': state,
      'lga': lga,
    };
  }
}

class RemainingLeaveModel {
  String? id;
  String? staffId;
  int? annualLeaveBalance;
  int? paternityLeaveBalance;
  int? maternityLeaveBalance;
  int? holidayLeaveBalance;
  DateTime? dateUpdated;


  RemainingLeaveModel({
    this.id,
    this.staffId,
    this.annualLeaveBalance,
    this.paternityLeaveBalance,
    this.maternityLeaveBalance,
    this.holidayLeaveBalance,
    this.dateUpdated,

  });

  factory RemainingLeaveModel.fromJson(Map<String, dynamic> json) {
    return RemainingLeaveModel(
      id: json['id'] as String?,
      staffId: json['staffId'] as String?,
      annualLeaveBalance: json['annualLeaveBalance'] as int?,
      paternityLeaveBalance: json['paternityLeaveBalance'] as int?,
      maternityLeaveBalance: json['maternityLeaveBalance'] as int?,
      holidayLeaveBalance: json['holidayLeaveBalance'] as int?,
      dateUpdated: json['dateUpdated'] != null ? (json['dateUpdated'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'annualLeaveBalance': annualLeaveBalance,
      'paternityLeaveBalance': paternityLeaveBalance,
      'maternityLeaveBalance': maternityLeaveBalance,
      'holidayLeaveBalance': holidayLeaveBalance,
      'dateUpdated': dateUpdated,

    };
  }
}


class GeofenceModel {  // Keep the GeofenceModel
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


class LeaveRequestsPageWeb extends StatefulWidget {
  const LeaveRequestsPageWeb({super.key});

  @override
  _LeaveRequestsPageWebState createState() => _LeaveRequestsPageWebState();
}

class _LeaveRequestsPageWebState extends State<LeaveRequestsPageWeb> with SingleTickerProviderStateMixin  {


  late TabController _tabController; // Declare a TabController

  final RxInt _totalAnnualLeaves = 10.obs;
  final RxInt _totalPaternityLeaves = 6.obs;
  final RxInt _totalMaternityLeaves = 60.obs;
  final RxInt _totalHolidayLeaves = 0.obs;
  final RxInt _usedAnnualLeaves = 0.obs;
  final RxInt _usedPaternityLeaves = 0.obs;
  final RxInt _usedMaternityLeaves = 0.obs;
  final RxInt _remainingPaternityLeaveBalance = 0.obs;
  final RxInt _remainingMaternityLeaveBalance = 0.obs;
  final RxInt _remainingAnnualLeaveBalance = 0.obs;
// Store the index of the currently expanded panel
  RxInt expandedPanelIndex = (-1).obs;

  final _markedDates = <DateTime>[].obs; // Store marked dates
  final _nigerianHolidays = <DateTime, String>{}.obs;  // Nigerian holidays


  RxDouble lati = 0.0.obs;
  RxDouble longi = 0.0.obs;
  RxString administrativeArea = "".obs;
  RxString location = "".obs;
  RxBool isGpsEnabled = false.obs;
  RxBool isInternetConnected = false.obs; // Observable for internet connection status
  locationPkg.Location locationService = locationPkg.Location(); // Location service instance
  RxBool isInsideAnyGeofence = false.obs;
  RxDouble accuracy = 0.0.obs;
  RxDouble altitude = 0.0.obs;
  RxDouble speed = 0.0.obs;
  RxDouble speedAccuracy = 0.0.obs;
  RxDouble heading = 0.0.obs;
  RxDouble time = 0.0.obs;
  RxBool isMock = false.obs;
  RxDouble verticalAccuracy = 0.0.obs;
  RxDouble headingAccuracy = 0.0.obs;
  RxDouble elapsedRealtimeNanos = 0.0.obs;
  RxDouble elapsedRealtimeUncertaintyNanos = 0.0.obs;
  var isCircularProgressBarOn = true.obs; // Observable boolean
  RxBool isLocationTurnedOn = false.obs;
  RxBool isAlertSet = false.obs;
  RxBool isAlertSet2 = false.obs;
  Rx<LocationPermission> isLocationPermissionGranted =
      LocationPermission.denied.obs;
  late StreamSubscription subscription;

  String _selectedLeaveType = 'Annual';
  RemainingLeaveModel? _remainingLeaves1; // Store remaining leaves - nullable
  final TextEditingController _reasonController = TextEditingController();
  PickerDateRange? _selectedDateRange;
  final List<LeaveRequestModel> _leaveRequests1 = [];
  final bool _isarInitialized1 = false; // No Isar anymore
  String? _selectedSupervisor;
  String? _selectedSupervisorEmail;
  BioModel? _bioInfo1;
  LeaveRequestModel? _leaveRequestInfo; // Nullable

  final _leaveRequests = <LeaveRequestModel>[].obs; // Use RxList for reactivity
  final _remainingLeaves = Rxn<RemainingLeaveModel>(); // Use Rxn for nullable observable
  final _bioInfo = Rxn<BioModel>();  // Use Rxn for nullable observable
  final _firebaseInitialized = false.obs; // Track Firebase initialization
  List<String> attachments = [];
  bool isHTML = false;



  @override
  void initState() {
    super.initState();
    // ... existing initState code

    _loadAttendanceDates();  // Load attendance dates when initializing
    _loadNigerianHolidays(); // Load Nigerian holidays
    //_init();
    _initFirebase().then((_) => _init()); // Initialize Firebase first
    _tabController = TabController(length: 2, vsync: this); // Initialize the TabController
    //     .then((_){
    //   // Start a 2-second timer
    //   Timer(const Duration(seconds: 2), () {
    //     setState(() async {
    //      await _init();
    //       _isIndicatorVisible = true;
    //     });
    //   });
    // });

  }


  @override
  void dispose() {
    _tabController.dispose(); // Dispose of the TabController
    subscription.cancel(); // Cancel GPS subscription
    super.dispose();
  }

  Future<void> _loadAttendanceDates() async {
    print("_loadAttendanceDates here");
    try {
      final attendanceRecords = await _getAllAttendanceFromFirebase();
      //isar.attendanceModels.where().findAll();
      final markedDatesMap = <DateTime, String?>{};
      // final dates = attendanceRecords
      //     .map((record) => DateFormat('dd-MMMM-yyyy').parse(record.date!))
      //     .toSet();
      // _markedDates.assignAll(dates);

      for (var record in attendanceRecords) {
        final date = DateFormat('dd-MMMM-yyyy').parse(record.date!);
        markedDatesMap[date] = record.durationWorked; // Store durationWorked for all attendance
      }

      _markedDates.assignAll(markedDatesMap.keys);
      print("attendanceRecords == $attendanceRecords");
      print("_markedDates == $_markedDates");
    } catch (e) {
      print("Error loading attendance dates: $e");
    }
  }

  Future<List<AttendanceModel>> _getAllAttendanceFromFirebase() async {
    List<AttendanceModel> attendanceRecords = [];
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
            .collection('Staff')
            .doc(user.uid)
            .collection('Record')
            .get();

        attendanceRecords = querySnapshot.docs.map((doc) => AttendanceModel.fromJson(doc.data())).toList();
        log("attendanceRecords===$attendanceRecords");
      }
    } catch (e) {
      print("Error fetching attendance from Firebase: $e");
    }
    return attendanceRecords;
  }


  Future<void> _loadNigerianHolidays() async {
    _nigerianHolidays.addAll({  // Add holidays with names
      DateTime(2024, 1, 1): "New Year's",
      DateTime(2024, 4, 19): "Good Friday",
      DateTime(2024, 4, 22): "Easter Monday",
      DateTime(2024, 5, 1): "Worker's Day",
      // ... more holidays
    });
  }


  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(); // Initialize Firebase
      _firebaseInitialized.value = true;
    } catch (e) {
      print("Firebase initialization error: $e");
      // Handle error (e.g., show a dialog to the user)
    }
  }


  Future<void> _init() async {
    if (!_firebaseInitialized.value) return; // Avoid re-initialization if Firebase not ready
    print("Starting _init");

    try {
      await _getUserLocation(); // Call the location fetching function
      await getLocationStatus().then((_) async {
        await getPermissionStatus().then((_) async {
          await _startLocationService();
        });
      });

     // await checkInternetConnection();


      // Fetch `_bioInfo` from Firebase
      final bioInfo = await _fetchBioInfoFromFirebase();

      // Ensure `bioInfo` is not null
      if (bioInfo == null) {
        throw Exception("Failed to fetch bioInfo from Firebase");
      }

      // Use GetX's ever method to listen to changes
      ever(_bioInfo, (_) async {
        if (_bioInfo.value != null) {
          _remainingLeaves.value = await _initializeRemainingLeaveModel(_bioInfo.value!);
          //_isarInitialized.value = true; // No Isar anymore
          //Add these 2 functions here
          await syncUnsyncedLeaveRequests();
          _checkAndUpdateLeaveStatus();
        }
      });


      // Initialize _bioInfo, which triggers the chain of reactions
      _bioInfo.value = bioInfo;

      _leaveRequests.bindStream(_fetchLeaveRequestsStream(_bioInfo.value?.firebaseAuthId ?? ''));


      _updateRemainingLeavesAndDate();


      print("Finished _init");
    } catch (e) {
      print("Error during _init: $e");
    }
  }


  Future<BioModel?> _fetchBioInfoFromFirebase() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot<Map<String, dynamic>> docSnapshot =
        await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
        if (docSnapshot.exists) {
          return BioModel.fromJson(docSnapshot.data()!);
        }
      }
      return null;
    } catch (e) {
      print("Error fetching BioInfo from Firebase: $e");
      return null;
    }
  }

  Stream<List<LeaveRequestModel>> _fetchLeaveRequestsStream(String staffId) {
    try {
      if (staffId.isEmpty) {
        return Stream.value([]); // Return an empty stream if staffId is empty
      }
      return FirebaseFirestore.instance
          .collection('Staff')
          .doc(staffId)
          .collection('Leave Request')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => LeaveRequestModel.fromJson(doc.data())).toList();
      });
    } catch (e) {
      print("Error fetching leave requests stream from Firebase: $e");
      return Stream.value([]); // Return an empty stream in case of error
    }
  }


  Future<void> sendEmailToSupervisor(LeaveRequestModel leaveRequest) async {
    final Email email = Email(
      body: '''
Greetings!!!,

You have received a new leave request from ${leaveRequest.firstName} ${leaveRequest.lastName}.

Details:
- Leave Type: ${leaveRequest.type}
- Start Date: ${DateFormat('dd MMMM,yyyy').format(leaveRequest.startDate!)}
- End Date: ${DateFormat('dd MMMM,yyyy').format(leaveRequest.endDate!)}
- Reason: ${leaveRequest.reason}

Please, kindly review the request at your earliest convenience.

Best regards,
${leaveRequest.firstName} ${leaveRequest.lastName}.
''',
      subject: 'New Leave Request from ${leaveRequest.firstName} ${leaveRequest.lastName}',
      recipients: [leaveRequest.selectedSupervisorEmail!],
      attachmentPaths: attachments,
      isHTML: isHTML,
    );
    String platformResponse;

    try {
      await FlutterEmailSender.send(email);
      platformResponse = 'success';
    } catch (error) {
      print(error);
      platformResponse = error.toString();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(platformResponse),
      ),
    );
  }

  Future<void> sendEmailFromDevice(String to, String subject, String body) async {
    final Email email = Email(
      recipients: [to],
      subject: subject,
      body: body,
      isHTML: true, // Set to true if your body is HTML
    );

    try {
      await FlutterEmailSender.send(email);
      print('Email sent successfully (user interaction required)');
    } catch (error) {
      print('Error sending email: $error');
      // ... error handling (show a dialog to the user)
    }
  }


  String _formatLeaveRequestEmail2(LeaveRequestModel leaveRequest) {
    // Inline CSS styles
    String tableStyle = """
    border-collapse: separate;
    border-spacing: 10px; /* Spacing between columns */
    width: 100%;
    font-family: Arial, sans-serif;
    margin: 20px 0;
    font-size: 14px;
    color: #333;
  """;
    String thStyle = """
    border: 1px solid #dddddd;
    text-align: center;
    padding: 10px;
    background-color: #4CAF50;
    color: white;
  """;
    String tdStyle = """
    border: 1px solid #dddddd;
    text-align: center;
    padding: 10px;
    background-color: #f9f9f9;
  """;
    String headerStyle = "color: #4CAF50; font-weight: bold; font-size: 16px;";
    String bodyStyle = "font-family: Arial, sans-serif; font-size: 14px; color: #333;";

    // HTML email body
    return """
<!DOCTYPE html>
<html>
<head>
  <title>Leave Request</title>
</head>
<body style="$bodyStyle">

<p>Greetings!!!,</p>

<p>You have a new leave request from <b>${leaveRequest.firstName} ${leaveRequest.lastName}</b>.</p>

<h3 style="$headerStyle">Leave Request Details:</h3>
<table style="$tableStyle">
  <tr>
    <th style="$thStyle">Leave Type</th>
    <th style="$thStyle">Start Date</th>
    <th style="$thStyle">End Date</th>
    <th style="$thStyle">Duration</th>
    <th style="$thStyle">Reason</th>
  </tr>
  <tr>
    <td style="$tdStyle">${leaveRequest.type}</td>
    <td style="$tdStyle">${DateFormat('yyyy-MM-dd').format(leaveRequest.startDate!)}</td>
    <td style="$tdStyle">${DateFormat('yyyy-MM-dd').format(leaveRequest.endDate!)}</td>
    <td style="$tdStyle">${leaveRequest.leaveDuration} days</td>
    <td style="$tdStyle">${leaveRequest.reason}</td>
  </tr>
</table>

<h3 style="$headerStyle">Current Leave Summary for ${leaveRequest.firstName} ${leaveRequest.lastName}:</h3>
<table style="$tableStyle">
  <tr>
    <th style="$thStyle">Leave Type</th>
    <th style="$thStyle">Total</th>
    <th style="$thStyle">Used</th>
    <th style="$thStyle">Remaining</th>
  </tr>
  <tr>
    <td style="$tdStyle">Annual Leave</td>
    <td style="$tdStyle">$_totalAnnualLeaves</td>
    <td style="$tdStyle">${_totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0)}</td>
    <td style="$tdStyle">${_remainingLeaves.value?.annualLeaveBalance ?? 0}</td>
  </tr>
  ${_bioInfo.value?.maritalStatus == 'Married' && _bioInfo.value?.gender == 'Male' ? """
    <tr>
      <td style="$tdStyle">Paternity Leave</td>
      <td style="$tdStyle">$_totalPaternityLeaves</td>
      <td style="$tdStyle">${_totalPaternityLeaves.value - (_remainingLeaves.value?.paternityLeaveBalance ?? 0)}</td>
      <td style="$tdStyle">${_remainingLeaves.value?.paternityLeaveBalance ?? 0}</td>
    </tr>
  """ : ''}
  ${_bioInfo.value?.maritalStatus == 'Married' && _bioInfo.value?.gender == 'Female' ? """
    <tr>
      <td style="$tdStyle">Maternity Leave</td>
      <td style="$tdStyle">$_totalMaternityLeaves</td>
      <td style="$tdStyle">${_totalMaternityLeaves.value - (_remainingLeaves.value?.maternityLeaveBalance ?? 0)}</td>
      <td style="$tdStyle">${_remainingLeaves.value?.maternityLeaveBalance ?? 0}</td>
    </tr>
  """ : ''}
  <tr>
    <td style="$tdStyle">Holiday Leave</td>
    <td style="$tdStyle">${_totalHolidayLeaves.value + (_remainingLeaves.value?.holidayLeaveBalance ?? 0)}</td>
    <td style="$tdStyle">${_remainingLeaves.value?.holidayLeaveBalance ?? 0}</td>
    <td style="$tdStyle">0</td>
  </tr>
</table>

<p>Please kindly review the request at your earliest convenience.</p>

<p>Best regards,<br>
<b>${leaveRequest.firstName} ${leaveRequest.lastName}</b></p>

</body>
</html>
""";
  }





  Future<void> _startLocationService() async {
    bool serviceEnabled = await locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationService.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    locationPkg.PermissionStatus permission = await locationService.hasPermission();
    if (permission == locationPkg.PermissionStatus.denied) {
      permission = await locationService.requestPermission();
      if (permission != locationPkg.PermissionStatus.granted) {
        return;
      }
    }

    // Use a FutureBuilder to manage the asynchronous location fetching
    _getLocation2().then((_) { // Call _getLocation and wait for it to complete
      // Now that the location is obtained, update the UI using Obx
      lati.refresh(); // Force a refresh of the Obx variable
      longi.refresh();
      administrativeArea.refresh();
      location.refresh();
    });

  }

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, handle this case.
      // You could show a dialog asking the user to enable location services.
      return Future.error('Location services are disabled.');
    }

    // Check for location permission.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, handle this case.
        return Future.error('Location permissions are denied');
      }
    }

    // If the permission is denied forever, show a dialog to the user.
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _getUserLocation() async {
    print("Geolocator Dependency here");
    try {
      Position? position = await getCurrentLocation();
      if (position != null) {
        print('Latitude: ${position.latitude}, Longitude: ${position.longitude}');
        // Use the position data (latitude, longitude) as needed
        lati.value = position.latitude;
        longi.value = position.longitude;

        // Update location based on new latitude and longitude
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
          // timeout: const Duration(seconds: 15),
        );

        // print("placemarksssssss==$placemarks");

        if (placemarks.isNotEmpty) {
          Placemark placemark = placemarks[0];
          location.value =
          "${placemark.street},${placemark.subLocality},${placemark.subAdministrativeArea},${placemark.locality},${placemark.administrativeArea},${placemark.postalCode},${placemark.country}";
          administrativeArea.value = placemark.administrativeArea!; // Update state name

          print("location.valuesssss==${location.value}");
          print("placemark.administrativeArea==${placemark.administrativeArea}");
          print("administrativeArea.value ==${administrativeArea.value}");

        } else {
          location.value = "Location not found";
          administrativeArea.value = "";
          await _updateLocationUsingGeofencing2(position.latitude,position.longitude);
        }

        // Geofencing logic
        if (administrativeArea.value != '') {
          // Query Firebase for locations with the same administrative area
          List<LocationModel> firebaseLocations =
          await _getLocationsByStateFromFirebase(administrativeArea.value);


          // Convert Firebase locations to GeofenceModel
          List<GeofenceModel> offices = firebaseLocations.map((location) => GeofenceModel(
            name: location.locationName!, // Use 'locationName'
            latitude: location.latitude ?? 0.0,
            longitude: location.longitude ?? 0.0,
            radius: location.radius?.toDouble() ?? 0.0,
          )).toList();

          print("Officessss == $offices");

          isInsideAnyGeofence.value = false;
          for (GeofenceModel office in offices) {
            double distance = GeoUtils.haversine(
                position.latitude, position.longitude,office.latitude, office.longitude);

            if (distance <= office.radius) {
              print('Entered office: ${office.name}');

              location.value = office.name;
              isInsideAnyGeofence.value = true;
              // isCircularProgressBarOn.value = false; // Update observable value
              break;
            }
          }

          if (!isInsideAnyGeofence.value) {
            List<Placemark> placemark = await placemarkFromCoordinates(
                position.latitude, position.longitude);

            location.value =
            "${placemark[0].street},${placemark[0].subLocality},${placemark[0].subAdministrativeArea},${placemark[0].locality},${placemark[0].administrativeArea},${placemark[0].postalCode},${placemark[0].country}";

            print("Location from map === ${location.value}");
            // isCircularProgressBarOn.value = false; // Update observable value
          }
        }
        else if(administrativeArea.value == '' && location.value != 0.0){
          // If we cant get the state, check the entire location name for geo fencing
          print("administrativeArea.value1 == '' && location.value1 != 0.0");
          await _updateLocationUsingGeofencing();
        }
        else {
          List<Placemark> placemark = await placemarkFromCoordinates(
              position.latitude, position.longitude);

          location.value =
          "${placemark[0].street},${placemark[0].subLocality},${placemark[0].subAdministrativeArea},${placemark[0].locality},${placemark[0].administrativeArea},${placemark[0].postalCode},${placemark[0].country}";

          print("Unable to get administrative area. Using default location.");

        }

      }

    } catch (e) {

      // Handle location errors (e.g., show an error message)
      if(lati.value != 0.0 && administrativeArea.value == ''){
        // If we cant get the state, check the entire location name for geo fencing
        print("administrativeArea.value2 == '' && location.value2 != 0.0");
        await _updateLocationUsingGeofencing();
      }else if(lati.value == 0.0 && administrativeArea.value == '') {
        Timer(const Duration(seconds: 10), () async {
          if (lati.value == 0.0 && longi.value == 0.0) {
            print("Location not obtained within 10 seconds. Using default1.");
            _getLocationDetailsFromLocationModel();
          }
        });
      }
      else{

        log('Error getting location: $e');
        Fluttertoast.showToast(
          msg: "Error getting location: $e",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.black54,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0,
        );}
    }
  }

  Future<List<LocationModel>> _getLocationsByStateFromFirebase(String state) async {
    List<LocationModel> locations = [];
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Locations')
          .where('state', isEqualTo: state)
          .get();

      locations = querySnapshot.docs.map((doc) => LocationModel.fromJson(doc.data())).toList();
    } catch (e) {
      print("Error fetching locations by state from Firebase: $e");
    }
    return locations;
  }


  Future<void> _getLocation2() async {

    // Check for internet connection
 //   isInternetConnected.value = await InternetConnectionChecker.instance.hasConnection;
    try{
      print("_getLocation2 hereeeee");
      locationService.onLocationChanged.listen((locationPkg.LocationData locationData) async {
        lati.value = locationData.latitude!;
        longi.value = locationData.longitude!;
        accuracy.value = locationData.accuracy!;
        altitude.value = locationData.altitude!;
        speed.value = locationData.speed!;
        speedAccuracy.value = locationData.speedAccuracy!;
        heading.value = locationData.heading!;
        time.value = locationData.time!;
        isMock.value = locationData.isMock!;
        verticalAccuracy.value = locationData.verticalAccuracy!;
        headingAccuracy.value = locationData.headingAccuracy!;
        elapsedRealtimeNanos.value = locationData.elapsedRealtimeNanos!;
        elapsedRealtimeUncertaintyNanos.value = locationData.elapsedRealtimeUncertaintyNanos!;
        // satelliteNumber.value = locationData.satelliteNumber!;
        // provider.value = locationData.provider!;


        // print("locationData.latitude! == ${locationData.latitude!}");
        //print("locationData.longitude! == ${locationData.longitude!}");
        _updateLocation();
      });
    }catch(e){
      print("_getLocation2 Error:$e");
      print("There is nooooooo internet to get location data");
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: true, // Important for Android
      );

      Position? position1 = await Geolocator.getLastKnownPosition();

      lati.value = position.latitude;
      longi.value = position.longitude;
      print("locationData.latitude == ${position.latitude}");
      _updateLocation();



    }

  }

  Future<void> _updateLocation() async {
    try{
      // Update location based on new latitude and longitude
      List<Placemark> placemarks = await placemarkFromCoordinates(
        lati.value,
        longi.value,
        // timeout: const Duration(seconds: 15),
      );

      // print("placemarksssssss==$placemarks");

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        location.value =
        "${placemark.street},${placemark.subLocality},${placemark.subAdministrativeArea},${placemark.locality},${placemark.administrativeArea},${placemark.postalCode},${placemark.country}";
        administrativeArea.value = placemark.administrativeArea!; // Update state name

        print("location.valuesssss==${location.value}");
        print("placemark.administrativeArea==${placemark.administrativeArea}");
        print("administrativeArea.value ==${administrativeArea.value}");

      } else {
        location.value = "Location not found";
        administrativeArea.value = "";
      }

      // Geofencing logic
      if (administrativeArea.value != '') {
        // Query Firebase database for locations with the same administrative area
        List<LocationModel> firebaseLocations =
        await _getLocationsByStateFromFirebase(administrativeArea.value);


        // Convert Firebase locations to GeofenceModel
        List<GeofenceModel> offices = firebaseLocations.map((location) => GeofenceModel(
          name: location.locationName!, // Use 'locationName'
          latitude: location.latitude ?? 0.0,
          longitude: location.longitude ?? 0.0,
          radius: location.radius?.toDouble() ?? 0.0,
        )).toList();

        print("Officessss == $offices");

        isInsideAnyGeofence.value = false;
        for (GeofenceModel office in offices) {
          double distance = GeoUtils.haversine(
              lati.value, longi.value,office.latitude, office.longitude);

          if (distance <= office.radius) {
            print('Entered office: ${office.name}');

            location.value = office.name;
            isInsideAnyGeofence.value = true;
            isCircularProgressBarOn.value = false; // Update observable value
            break;
          }
        }

        if (!isInsideAnyGeofence.value) {
          List<Placemark> placemark = await placemarkFromCoordinates(
              lati.value, longi.value);

          location.value =
          "${placemark[0].street},${placemark[0].subLocality},${placemark[0].subAdministrativeArea},${placemark[0].locality},${placemark[0].administrativeArea},${placemark[0].postalCode},${placemark[0].country}";

          print("Location from map === ${location.value}");
          isCircularProgressBarOn.value = false; // Update observable value
        }
      }
      else if(administrativeArea.value == '' && location.value != 0.0){
        // If we cant get the state, check the entire location name for geo fencing
        print("_updateLocationUsingGeofencing2 here");
        await _updateLocationUsingGeofencing();
      } else {
        List<Placemark> placemark = await placemarkFromCoordinates(
            lati.value, longi.value);

        location.value =
        "${placemark[0].street},${placemark[0].subLocality},${placemark[0].subAdministrativeArea},${placemark[0].locality},${placemark[0].administrativeArea},${placemark[0].postalCode},${placemark[0].country}";

        print("Unable to get administrative area. Using default location.");
        isCircularProgressBarOn.value = false; // Update observable value
      }

    }catch(e){
      if(lati.value != 0.0 && administrativeArea.value == ''){
        // If we cant get the state, check the entire location name for geo fencing
        await _updateLocationUsingGeofencing();
        print("_updateLocationUsingGeofencing3 here");
      }else if(lati.value == 0.0 && administrativeArea.value == '') {
        print("Location not obtained within 10 seconds.");
        Timer(const Duration(seconds: 10), () {
          if (lati.value == 0.0 && longi.value == 0.0) {
            print("Location not obtained within 10 seconds. Using default.");
            _getLocationDetailsFromLocationModel();
          }
        });
      }
      else{
        log("$e");
        Fluttertoast.showToast(
          msg: "Error: $e",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.black54,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0,
        );}


    }

  }

  // Function to update location details using geofencing
  Future<void> _updateLocationUsingGeofencing() async {
    // 1. Check if latitude is valid and location name is empty
    if (lati.value != 0.0 && location.value == "") {
      // 2. Get all locations from LocationModel
      List<LocationModel> allLocations = await _getAllLocationsFromFirebase();
      print("updateLocationUsingGeofencing for all location here");

      // 3. Convert LocationModel objects to GeofenceModel for easier calculations
      List<GeofenceModel> geofences = allLocations.map((location) => GeofenceModel(
        name: location.locationName!,
        latitude: location.latitude ?? 0.0,
        longitude: location.longitude ?? 0.0,
        radius: location.radius?.toDouble() ?? 0.0,
      )).toList();

      // 4. Iterate through each geofence to check if current location falls within
      for (GeofenceModel geofence in geofences) {
        double distance = GeoUtils.haversine(
            lati.value, longi.value, geofence.latitude, geofence.longitude);

        if (distance <= geofence.radius) {
          // Found a matching geofence!
          print('Using geofence location: ${geofence.name}');
          location.value = geofence.name;
          isInsideAnyGeofence.value = true;
          isCircularProgressBarOn.value = false; // Update observable value
          break; // Exit loop after finding a match
        }
      }

      // If no geofence match is found, you can keep the location.value as ""
      // or set a default value.
    }
  }

  Future<List<LocationModel>> _getAllLocationsFromFirebase() async {
    List<LocationModel> locations = [];
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Locations')
          .get();

      locations = querySnapshot.docs.map((doc) => LocationModel.fromJson(doc.data())).toList();
    } catch (e) {
      print("Error fetching all locations from Firebase: $e");
    }
    return locations;
  }


  Future<void> _updateLocationUsingGeofencing2(double latitde, double longitde) async {
    // 1. Check if latitude is valid and location name is empty
    print("_updateLocationUsingGeofencing2 is here");

    // 2. Get all locations from LocationModel
    List<LocationModel> allLocations = await _getAllLocationsFromFirebase();
    print("updateLocationUsingGeofencing for all location here");

    // 3. Convert LocationModel objects to GeofenceModel for easier calculations
    List<GeofenceModel> geofences = allLocations.map((location) => GeofenceModel(
      name: location.locationName!,
      latitude: location.latitude ?? 0.0,
      longitude: location.longitude ?? 0.0,
      radius: location.radius?.toDouble() ?? 0.0,
    )).toList();

    // 4. Iterate through each geofence to check if current location falls within
    for (GeofenceModel geofence in geofences) {
      double distance = GeoUtils.haversine(
          latitde, longitde, geofence.latitude, geofence.longitude);

      if (distance <= geofence.radius) {
        // Found a matching geofence!
        print('Using geofence location: ${geofence.name}');
        location.value = geofence.name;
        isInsideAnyGeofence.value = true;
        isCircularProgressBarOn.value = false; // Update observable value
        break; // Exit loop after finding a match
      }
    }

  }

  Future<void> _getLocationDetailsFromLocationModel() async {
    // 1. Get the location field from BioModel
    final bioModel = _bioInfo.value; // Use the observable value
    final locationFromBioModel = bioModel?.location;
    print("locationFromBioModel === $locationFromBioModel");

    if (locationFromBioModel == null) {
      print("Location not found in BioModel");
      return;
    }

    // 2. Query LocationModel using the location from BioModel
    final locationModel = await _getLocationByNameFromFirebase(locationFromBioModel);


    if (locationModel == null) {
      print("No matching location found in LocationModel");
      return;
    }

    // 3. Update the controller's variables with data from LocationModel
    lati.value = locationModel.latitude ?? 0.0;
    longi.value = locationModel.longitude ?? 0.0;
    administrativeArea.value = locationModel.state ?? "";
    location.value = locationModel.locationName ?? "";
  }

  Future<LocationModel?> _getLocationByNameFromFirebase(String? locationName) async {
    if (locationName == null || locationName.isEmpty) {
      return null;
    }
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Locations')
          .where('locationName', isEqualTo: locationName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return LocationModel.fromJson(querySnapshot.docs.first.data());
      } else {
        return null;
      }
    } catch (e) {
      print("Error fetching location by name from Firebase: $e");
      return null;
    }
  }


  Future<void> getLocationStatus() async {
    bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    isLocationTurnedOn.value = isLocationEnabled;

    if (!isLocationTurnedOn.value && !isAlertSet.value) {
      showDialogBox();
      isAlertSet.value = true;
    }
  }

  Future<void> getPermissionStatus() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      isLocationPermissionGranted.value = permission;

      // Check if permission is denied
      if (isLocationPermissionGranted.value == LocationPermission.denied ||
          isLocationPermissionGranted.value == LocationPermission.deniedForever) {
        showDialogBox2();
        isAlertSet2.value = true;
      }
    } catch (e) {
      print("Error in getPermissionStatus: $e");
      // Handle the error gracefully, maybe set a default permission status or show a message
      isLocationPermissionGranted.value = LocationPermission.denied; // Default to denied in case of error
      Fluttertoast.showToast(
        msg: "Error checking location permission: $e",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.redAccent,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }
  // Future<void> checkInternetConnection() async {
  //   isInternetConnected.value = await InternetConnectionChecker.instance.hasConnection;
  //   if (!isInternetConnected.value) {
  //     Fluttertoast.showToast(
  //       msg:
  //       "No Internet Connectivity Detected.",
  //       toastLength: Toast.LENGTH_LONG,
  //       backgroundColor: Colors.black54,
  //       gravity: ToastGravity.BOTTOM,
  //       timeInSecForIosWeb: 1,
  //       textColor: Colors.white,
  //       fontSize: 16.0,
  //     );
  //   }
  // }

  showDialogBox() => showCupertinoDialog<String>(
    context: Get.context!, // Retrieve BuildContext from Get
    builder: (BuildContext context) => CupertinoAlertDialog(
      title: const Text("Location Turned Off"),
      content: const Text("Please turn on your location to ClockIn and Out"),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            Get.back(); // You can use Get.back() here
            isAlertSet.value = false;
            isLocationTurnedOn.value =
            await LocationService().getLocationStatus();
            if (!isLocationTurnedOn.value) {
              showDialogBox();
            }
          },
          child: const Text("OK"),
        ),
      ],
    ),
  );



  showDialogBox2() => showCupertinoDialog<String>(
    context: Get.context!, // Retrieve BuildContext from Get
    builder: (BuildContext builderContext) => CupertinoAlertDialog(
      // ... your AlertDialog content
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            Get.back(); // You can use Get.back() here
            isAlertSet2.value = false;
            isLocationPermissionGranted.value =
            await LocationService().getPermissionStatus();
            if (isLocationPermissionGranted.value ==
                LocationPermission.denied ||
                isLocationPermissionGranted.value ==
                    LocationPermission.deniedForever) {
              showDialogBox2(); // Use builderContext for the recursive call
            }
          },
          child: const Text("OK"),
        ),
      ],
    ),
  );


  Future<RemainingLeaveModel?> _initializeRemainingLeaveModel(BioModel bioInfo) async {
    RemainingLeaveModel? remainingLeave;
    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(bioInfo.firebaseAuthId!)
          .collection('RemainingLeaves')
          .doc(bioInfo.firebaseAuthId!)
          .get();

      if (docSnapshot.exists) {
        remainingLeave = RemainingLeaveModel.fromJson(docSnapshot.data()!);
      }
    } catch (e) {
      print("Error fetching remaining leave from Firebase: $e");
      return null;
    }


    if (remainingLeave == null) {
      remainingLeave = RemainingLeaveModel(
        staffId: bioInfo.firebaseAuthId!,
        annualLeaveBalance: await _calculateInitialAnnualLeave(),
        holidayLeaveBalance: await _calculateInitialHoliday(),
        dateUpdated: DateTime.now(),
        paternityLeaveBalance: (bioInfo.gender == 'Male' && bioInfo.maritalStatus == 'Married')
            ? _totalPaternityLeaves.value
            : 6,
        maternityLeaveBalance: (bioInfo.gender == 'Female' && bioInfo.maritalStatus == 'Married')
            ? _totalMaternityLeaves.value
            : 60,
      );

      await _saveRemainingLeaveToFirebase(remainingLeave).then((_) async {
        await _insertInitialAnnualLeave().then((_) async {
          await _insertInitialHolidayLeave();
        });
      });

    } else{

      _usedPaternityLeaves.value = _totalPaternityLeaves.value -remainingLeave.paternityLeaveBalance!;
      _usedMaternityLeaves.value =_totalMaternityLeaves.value -remainingLeave.maternityLeaveBalance!;
      _usedAnnualLeaves.value = _totalAnnualLeaves.value - remainingLeave.annualLeaveBalance! ;
      _remainingPaternityLeaveBalance.value = remainingLeave.paternityLeaveBalance!;
      _remainingMaternityLeaveBalance.value = remainingLeave.maternityLeaveBalance!;
      _remainingAnnualLeaveBalance.value = remainingLeave.annualLeaveBalance!;
    }

    return remainingLeave;
  }

  Future<void> _saveRemainingLeaveToFirebase(RemainingLeaveModel remainingLeave) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('Staff')
            .doc(user.uid)
            .collection('RemainingLeaves')
            .doc(user.uid)
            .set(remainingLeave.toJson());
      }
    } catch (e) {
      print("Error saving remaining leave to Firebase: $e");
    }
  }


  Future<int> _calculateInitialAnnualLeave() async {
    final now = DateTime.now();
    final currentYear = now.year;

    // Define October 1st for the current and previous years
    final octoberFirstCurrentYear = DateTime(currentYear, 10, 1);
    final octoberFirstPreviousYear = DateTime(currentYear - 1, 10, 1);

    // Determine the start date
    final start = now.isAfter(octoberFirstCurrentYear)
        ? octoberFirstCurrentYear
        : octoberFirstPreviousYear;

    final annualLeaveRecords = await _getAttendanceRecordsForDurationWorkedFromFirebase(
        'Annual Leave',
        DateFormat('dd-MMMM-yyyy').format(start),
        DateFormat('dd-MMMM-yyyy').format(now)
    );


    // Count records excluding weekends
    final leaveDaysExcludingWeekends = annualLeaveRecords.where((date) {
      final recordDate = DateFormat('dd-MMMM-yyyy').parse(date.date!);
      return recordDate.weekday != DateTime.saturday &&
          recordDate.weekday != DateTime.sunday;
    }).length;


    return (_totalAnnualLeaves.value - leaveDaysExcludingWeekends).clamp(0, _totalAnnualLeaves.value);
  }

  Future<List<AttendanceModel>> _getAttendanceRecordsForDurationWorkedFromFirebase(String durationWorked, String startDate, String endDate) async {
    List<AttendanceModel> attendanceRecords = [];
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
            .collection('Staff')
            .doc(user.uid)
            .collection('Attendance')
            .where('durationWorked', isEqualTo: durationWorked)
            .where('offDay', isEqualTo: true)
            .where('date', isGreaterThanOrEqualTo: startDate)
            .where('date', isLessThanOrEqualTo: endDate)
            .get();

        attendanceRecords = querySnapshot.docs.map((doc) => AttendanceModel.fromJson(doc.data())).toList();
      }
    } catch (e) {
      print("Error fetching attendance records by duration from Firebase: $e");
    }
    return attendanceRecords;
  }


  Future<void> _insertInitialAnnualLeave() async {
    final now = DateTime.now();
    final currentYear = now.year;

    final octoberFirstCurrentYear = DateTime(currentYear, 10, 1);
    final octoberFirstPreviousYear = DateTime(currentYear - 1, 10, 1);

    final start = now.isAfter(octoberFirstCurrentYear)
        ? octoberFirstCurrentYear
        : octoberFirstPreviousYear;

    final annualLeaveRecords = await _getAttendanceRecordsForDurationWorkedFromFirebase(
        'Annual Leave',
        DateFormat('dd-MMMM-yyyy').format(start),
        DateFormat('dd-MMMM-yyyy').format(now)
    );

    for (final leaveRecord in annualLeaveRecords) {
      final recordDate = DateFormat('dd-MMMM-yyyy').parse(leaveRecord.date!);

      // Check if the date is not a weekend before inserting
      if (recordDate.weekday != DateTime.saturday &&
          recordDate.weekday != DateTime.sunday) {
        await _addLeaveRecordToLeaveRequest(leaveRecord); // Call the insert function
      }
    }


  }

  Future<void> _insertInitialHolidayLeave() async {
    final now = DateTime.now();
    final currentYear = now.year;

    final octoberFirstCurrentYear = DateTime(currentYear, 10, 1);
    final octoberFirstPreviousYear = DateTime(currentYear - 1, 10, 1);

    final start = now.isAfter(octoberFirstCurrentYear)
        ? octoberFirstCurrentYear
        : octoberFirstPreviousYear;

    final holidayLeaveRecords = await _getAttendanceRecordsForDurationWorkedFromFirebase(
        'Holiday',
        DateFormat('dd-MMMM-yyyy').format(start),
        DateFormat('dd-MMMM-yyyy').format(now)
    );


    for (final leaveRecord in holidayLeaveRecords) {
      final recordDate = DateFormat('dd-MMMM-yyyy').parse(leaveRecord.date!);

      // Check if the date is not a weekend before inserting
      if (recordDate.weekday != DateTime.saturday &&
          recordDate.weekday != DateTime.sunday) {
        await _addHolidayLeaveRecordToLeaveRequest(leaveRecord); // Call the insert function
      }
    }


  }

  Future<void> _addLeaveRecordToLeaveRequest(AttendanceModel leaveRecord) async {
    try {
      final recordDate = DateFormat('dd-MMMM-yyyy').parse(leaveRecord.date!);

      final newLeaveRequest = LeaveRequestModel(
        type: leaveRecord.durationWorked,
        status: "Approved", // Set the status
        startDate: recordDate,
        endDate: recordDate,
        reason: "Annual Leave", // Or any default reason if needed
        isSynced: false, // Important to mark not synced initially
        staffId: _bioInfo.value?.firebaseAuthId, // Get the staffId from _bioInfo
        leaveRequestId: const Uuid().v4(),
        selectedSupervisor: "App Support", // or determine how to set this
        selectedSupervisorEmail: "appsupport@ccfng.org",
        leaveDuration: 1, // since it represents a single day of leave
        firstName: "App Support",
        lastName: "CaritasNigeria",
        staffCategory: _bioInfo.value?.staffCategory,
        staffState: _bioInfo.value?.state,
        staffLocation: _bioInfo.value?.location,
        staffEmail: _bioInfo.value?.emailAddress,
        staffPhone: _bioInfo.value?.mobile,
        staffDepartment: _bioInfo.value?.department,
        staffDesignation: _bioInfo.value?.designation,
      );


      await _saveLeaveRequestToFirebase(newLeaveRequest);
    } catch (e) {
      print("Error adding leave record to Leave_request: $e");
    }
  }

  Future<void> _saveLeaveRequestToFirebase(LeaveRequestModel leaveRequest) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final staffCollection = FirebaseFirestore.instance.collection('Staff').doc(user.uid);
        final leaveRequestCollection = staffCollection.collection('Leave Request');
        await leaveRequestCollection.doc(leaveRequest.leaveRequestId).set(leaveRequest.toJson());
      }
    } catch (e) {
      print("Error saving leave request to Firebase: $e");
    }
  }


  Future<void> _addHolidayLeaveRecordToLeaveRequest(AttendanceModel leaveRecord) async {
    try {
      final recordDate = DateFormat('dd-MMMM-yyyy').parse(leaveRecord.date!);

      final newLeaveRequest = LeaveRequestModel(
        type: leaveRecord.durationWorked,
        status: "Approved", // Set the status
        startDate: recordDate,
        endDate: recordDate,
        reason: "Holiday", // Or any default reason if needed
        isSynced: false, // Important to mark not synced initially
        staffId: _bioInfo.value?.firebaseAuthId, // Get the staffId from _bioInfo
        leaveRequestId: const Uuid().v4(),
        selectedSupervisor: "App Support", // or determine how to set this
        selectedSupervisorEmail: "appsupport@ccfng.org",
        leaveDuration: 1, // since it represents a single day of leave
        firstName: "App Support",
        lastName: "CaritasNigeria",
        staffCategory: _bioInfo.value?.staffCategory,
        staffState: _bioInfo.value?.state,
        staffLocation: _bioInfo.value?.location,
        staffEmail: _bioInfo.value?.emailAddress,
        staffPhone: _bioInfo.value?.mobile,
        staffDepartment: _bioInfo.value?.department,
        staffDesignation: _bioInfo.value?.designation,
      );


      await _saveLeaveRequestToFirebase(newLeaveRequest);
    } catch (e) {
      print("Error adding holiday leave record to Leave_request: $e");
    }
  }

  Future<int> _calculateInitialHoliday() async {
    print("holidayLeaveRecords Here");
    final now = DateTime.now();
    final currentYear = now.year;

    // Define October 1st for the current and previous years
    final octoberFirstCurrentYear = DateTime(currentYear, 10, 1);
    final octoberFirstPreviousYear = DateTime(currentYear - 1, 10, 1);

    // Determine the start date
    final start = now.isAfter(octoberFirstCurrentYear)
        ? octoberFirstCurrentYear
        : octoberFirstPreviousYear;

    final holidayRecords = await _getAttendanceRecordsForDurationWorkedFromFirebase(
        'Holiday',
        DateFormat('dd-MMMM-yyyy').format(start),
        DateFormat('dd-MMMM-yyyy').format(now)
    );


    // Count records excluding weekends
    final holidayDaysExcludingWeekends = holidayRecords.where((date) {
      final recordDate = DateFormat('dd-MMMM-yyyy').parse(date.date!);
      return recordDate.weekday != DateTime.saturday &&
          recordDate.weekday != DateTime.sunday;
    }).length;


    return holidayDaysExcludingWeekends;

  }

  Future<void> syncUnsyncedLeaveRequests() async {

    try {
      final unsyncedLeaveRequests = await _getUnsyncedLeaveRequestsFromFirebase();

      for (final leaveRequest in unsyncedLeaveRequests) {
        await _syncLeaveRequestToFirebase(leaveRequest);
      }
    } catch (e) {
      print("Error syncing unsynced leave requests: $e");
    }
  }

  // This function needs to be adjusted to fetch unsynced requests from Firebase if you were tracking 'isSynced' status in Firebase.
  // If 'isSynced' was only tracked locally (in Isar, which is now removed), you might not need this function at all,
  // or you might need to rethink how to handle offline/sync scenarios with Firebase directly.
  Future<List<LeaveRequestModel>> _getUnsyncedLeaveRequestsFromFirebase() async {
    return []; // Since we are not tracking 'isSynced' in Firebase in this example, return empty list.
  }


  Future<void> _syncLeaveRequestToFirebase(LeaveRequestModel leaveRequest) async {
    try {

      //Check network connectivity first
      // final isInternetConnected = await InternetConnectionChecker.instance.hasConnection;
      // if(!isInternetConnected){
      //   print("No Internet Connection. Syncing aborted.");
      //   return;
      // }

      final user = FirebaseAuth.instance.currentUser; //Ensure Firebase is initialized before use
      if (user != null) {
        final staffCollection = FirebaseFirestore.instance.collection('Staff').doc(user.uid);
        final leaveRequestCollection = staffCollection.collection('Leave Request');

        final leaveRequestId = leaveRequest.leaveRequestId;
        if (leaveRequestId != null) { //Ensure leaveRequestId exists
          await leaveRequestCollection.doc(leaveRequestId).set({
            ...leaveRequest.toJson(),
            'leaveRequestId': leaveRequestId,
          });

          print('Leave request synced successfully: $leaveRequestId');

        }
      }


    } catch (e) {

      print('Error syncing leave request to Firebase: $e');
      // Handle error, e.g., retry later or show a message to the user.


    }
  }




  Future<LeaveRequestModel> _getOrCreateLeaveRequestModel(String userId) async {
    // This function might not be needed anymore as we are directly saving to Firebase and not using local IDs like Isar.
    // If you need to ensure a leave request exists, you'll need to adjust this logic for Firebase.
    // For now, let's assume we create a new LeaveRequestModel every time.

    final newRequest = LeaveRequestModel(
      staffId: userId,
      endDate: DateTime.now(),
      startDate: DateTime.now(),
      leaveRequestId: const Uuid().v4(),
      reason: "Annual Leave",
      selectedSupervisor: "Super User",
      selectedSupervisorEmail: "superuser@ccfng.org",
      type: "Annual",
    );

    return newRequest;
  }


  Future<void> _getLeaveData() async {
    print("Starting getLeaveData");
    // Data is already loaded via stream in _init, no need to explicitly fetch again unless refreshing is needed.
    // If you need to refresh the leave data, consider re-triggering the stream or refetching data.
    print("Finished getLeaveData");
    await _checkAndUpdateLeaveStatus();
  }




  Widget _buildLeaveSummaryItem(String leaveType, int used, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Increased spacing
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align items to edges
            children: [

              Text("$leaveType Leave:", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)), // Style adjustments

              Text("$used Used, ${total - used} Remaining", style: const TextStyle(fontSize: 14)), // Usage/Remaining info
            ],
          ),
          LinearPercentIndicator(
            lineHeight: 10,
            percent: total > 0 ? used.toDouble() / total : 0,
            progressColor: Colors.green,
            backgroundColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveSummaryItem1(String leaveType, int used, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Increased spacing
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align items to edges
            children: [
              Text("No of $leaveType(s) observed:", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),// Style adjustments
              Text("$used Observed", style: const TextStyle(fontSize: 14))
            ],
          ),
          // LinearPercentIndicator(
          //   lineHeight: 10,
          //   percent: total > 0 ? used.toDouble() / total : 0,
          //   progressColor: Colors.blue,
          //   backgroundColor: Colors.grey[300],
          // ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Obx(() { // Wrap with Obx to rebuild when observables change
      if (!_firebaseInitialized.value || _bioInfo.value == null || _remainingLeaves.value == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      } else {
        return _buildMainScaffold(); // Call _buildMainScaffold when data is available
      }
    });
  }



  Widget _buildMainScaffold() { //Widget builds the main scaffold
    List<Widget> leaveSummaryItems = []; //Create a list of widget for leave summary items



    //Create Leave Summary Items
    leaveSummaryItems.add(
        _buildLeaveSummaryItem("Annual", _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0), _totalAnnualLeaves.value)); //Safe null checks


    if (_bioInfo.value?.maritalStatus == 'Married') {
      if (_bioInfo.value?.gender == 'Male') {
        leaveSummaryItems.add(
          _buildLeaveSummaryItem("Paternity", _totalPaternityLeaves.value - (_remainingLeaves.value?.paternityLeaveBalance ?? 0), _totalPaternityLeaves.value),
        );
      } else {
        leaveSummaryItems.add(
          _buildLeaveSummaryItem("Maternity", _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0) == _totalAnnualLeaves.value?
          _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0):_totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0), _totalMaternityLeaves.value),
        );
      }
    }
    leaveSummaryItems.add(_buildLeaveSummaryItem1("Holiday", _totalHolidayLeaves.value + (_remainingLeaves.value?.holidayLeaveBalance ?? 0), _totalHolidayLeaves.value));

    //   _totalMaternityLeaves.value - (_remainingLeaves.value?.maternityLeaveBalance ?? 0)

    return Scaffold( //Build Scaffold. Now you can safely access _remainingLeaves and _bioInfo here
      appBar: AppBar(
        title: const Text("Out of Office Leave Requests"),
      ),
      drawer: drawer(context), // Use web drawer
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(
              height: 100, // Fixed height for web header
              width: double.infinity, // Full width for web
              child: HeaderWidget(100, false, Icons.house_rounded),
            ),
            const SizedBox(height: 10),
            Obx(() => Card (
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Container(
                width: double.infinity, // Full width for web card
                //height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 1.15 : 0.50), // Adjusted height for web - consider fixed or more flexible
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.shade100,
                      Colors.white,
                      Colors.black12,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Geo-Cordinates Information:",
                      style: TextStyle(
                        fontFamily: "NexaBold",
                        fontSize: 20, // Fixed font size for web
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      "GPS is: ${isGpsEnabled.value ? 'On' : 'Off'}",
                      style: const TextStyle(
                        fontFamily: "NexaBold",
                        fontSize: 18, // Fixed font size for web
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      "Current Latitude: ${lati.value.toStringAsFixed(
                          6)}, Current Longitude: ${longi.value.toStringAsFixed(6)}",
                      style: const TextStyle(
                        fontFamily: "NexaBold",
                        fontSize: 18, // Fixed font size for web
                      ),
                    ),
                    const SizedBox(height: 10), // Spacing between status and coordinates

                    Text(
                      "Coordinates Accuracy: ${accuracy.value}, Altitude: ${altitude.value} , Speed: ${speed.value}, Speed Accuracy: ${speedAccuracy.value}, Location Data Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(time.value.toInt()))} , Is Location Mocked?: ${isMock.value}",
                      style: const TextStyle(
                        fontFamily: "NexaBold",
                        fontSize: 18, // Fixed font size for web
                      ),
                    ),
                    const SizedBox(height: 10),
                    Obx(() => Text(
                      "Current State: ${administrativeArea.value}",
                      style: const TextStyle(
                        fontFamily: "NexaBold",
                        fontSize: 18, // Fixed font size for web
                      ),
                    )),
                    const SizedBox(height: 10),


                    Obx(() => Text(
                      "Current Location: ${location.value}",
                      style: const TextStyle(
                        fontFamily: "NexaBold",
                        fontSize: 18, // Fixed font size for web
                      ),
                    )),
                    const SizedBox(height: 10),

                    Obx(() => Text(
                      "Current State: ${administrativeArea.value}",
                      style: const TextStyle(
                        fontFamily: "NexaBold",
                        fontSize: 18, // Fixed font size for web
                      ),
                    )),
                  ],
                ),
              ),
            ),
            ),
            const SizedBox(height: 10),
            //
            // _buildCircularPercentIndicator(_totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0), _totalAnnualLeaves.value,
            //     _totalPaternityLeaves.value - (_remainingLeaves.value?.paternityLeaveBalance ?? 0), _totalPaternityLeaves.value,
            //     _totalMaternityLeaves.value - (_remainingLeaves.value?.maternityLeaveBalance ?? 0), _totalMaternityLeaves.value) ,// Show the indicator after the delay
            Obx(() => _buildCircularPercentIndicator(
              _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0),
              _totalAnnualLeaves.value,
              _totalPaternityLeaves.value - (_remainingLeaves.value?.paternityLeaveBalance ?? 0),
              _totalPaternityLeaves.value,
              _totalMaternityLeaves.value - (_remainingLeaves.value?.maternityLeaveBalance ?? 0),
              _totalMaternityLeaves.value,
            )),
            Obx(() => Card(
              margin: const EdgeInsets.only(top: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Leave Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // ... leaveSummaryItems (calculate these reactively within the Obx)
                    // Example:
                    _buildLeaveSummaryItem(
                      "Annual", _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0), _totalAnnualLeaves.value,
                    ),


                    if (_bioInfo.value!.maritalStatus == 'Married') ...[ // Conditional rendering inside Obx
                      if (_bioInfo.value!.gender == 'Male')
                        _buildLeaveSummaryItem("Paternity", _totalPaternityLeaves.value - (_remainingLeaves.value?.paternityLeaveBalance ?? 0), _totalPaternityLeaves.value)
                      else // Assuming if not Male, it's Female
                        _buildLeaveSummaryItem("Maternity", _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0) == _totalAnnualLeaves.value?
                        _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0):_totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0), _totalMaternityLeaves.value),
                    ],
                    _buildLeaveSummaryItem1("Holiday", _totalHolidayLeaves.value + (_remainingLeaves.value?.holidayLeaveBalance ?? 0), _totalHolidayLeaves.value),


                  ],
                ),
              ),
            )),

            Obx(() =>_buildLeaveRequestsCard()),


          ],
        ),
      ),


      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showApplyLeaveBottomSheet(context);
        },
        child: const Icon(Icons.add),
      ),
    );


  }


  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text("$count", style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }



  void _showApplyLeaveBottomSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            List<Widget> leaveTypeButtons = [];

            if (_bioInfo.value?.maritalStatus == 'Married') {
              if (_bioInfo.value?.gender == 'Male') {
                leaveTypeButtons.addAll([
                  _leaveTypeButton(setState, 'Paternity', 'Paternity Leave'),
                  _leaveTypeButton(setState, 'Annual', 'Annual Leave'),
                ]);
              } else {
                leaveTypeButtons.addAll([
                  _leaveTypeButton(setState, 'Maternity', 'Maternity Leave'),
                  _leaveTypeButton(setState, 'Annual', 'Annual Leave'),
                ]);
              }
            } else {
              leaveTypeButtons.add(_leaveTypeButton(setState, 'Annual', 'Annual Leave'));
            }

            leaveTypeButtons.add(_leaveTypeButton(setState, 'Holiday', 'Holidays'));


            return SingleChildScrollView( // Wrap with SingleChildScrollView
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                width: MediaQuery.of(context).size.width * 0.5, // Limit width for web
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch across width
                  children: <Widget>[
                    // ... (rest of the bottom sheet content)
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: leaveTypeButtons,
                    ),
                    // ... (date picker, reason field, supervisor dropdown)
                    // Date Range Picker
                    SizedBox( // Added SizedBox to control width of SfDateRangePicker on web
                      width: 400, // Set a fixed width for the date picker on web
                      height: 400, // Set a fixed height for the date picker on web
                      child: SfDateRangePicker(

                        onSelectionChanged: (args) {
                          if (args.value is PickerDateRange) {
                            // final selectedDates = _getSelectedDates(args.value);
                            // final containsMarkedDate = selectedDates.any((date) => _markedDates.contains(date));
                            _selectedDateRange = args.value; // Store the selected date range
                            final selectedDates = _getSelectedDates(_selectedDateRange!); //Use the stored range

                            final containsMarkedDate = selectedDates.any((date) => _markedDates.contains(date));

                            if (containsMarkedDate) {
                              Fluttertoast.showToast(msg: "Attendance exists for certain date(s) within your range.");


                              // Clear the selection or reset to a valid range
                              //_selectedDateRange = null; //Clear selection, or
                              //_selectedDateRange = PickerDateRange(DateTime.now(), DateTime.now()); //Reset to today
                              setState(() {}); //Force bottom sheet to rebuild
                              return;
                            }
                          }
                          _onSelectionChanged(args, setState); //Call original function
                        },
                        selectionMode: DateRangePickerSelectionMode.range,
                        initialSelectedRange: PickerDateRange(
                          DateTime.now(),
                          DateTime.now().add(const Duration(days: 1)),
                        ),
                        headerStyle: const DateRangePickerHeaderStyle(
                          backgroundColor: Colors.blue,
                          textStyle: TextStyle(color: Colors.white),
                        ),
                        todayHighlightColor: Colors.red,
                        selectableDayPredicate: (DateTime date) {
                          return !_markedDates.contains(date);  // Disable marked dates directly
                        },
                        cellBuilder: (BuildContext context, DateRangePickerCellDetails cellDetails) {

                          final holidayName = _nigerianHolidays[cellDetails.date];
                          bool isHoliday = holidayName != null;
                          bool isMarked = _markedDates.contains(cellDetails.date);
                          final markedDateLabel = _getMarkedDateLabel(cellDetails.date); // Always get the label

                          return Container(
                            decoration: BoxDecoration(
                              color: isHoliday ? Colors.green.withOpacity(0.2) : isMarked
                                  ? Colors.grey
                                  : null,
                              border: Border.all(color: const Color(0xFFF0F0F0), width: 0.5),
                            ),
                            child: Column(  // Use a Column for vertical layout
                              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                              children: [
                                if (markedDateLabel != null) ...[
                                  FittedBox( // Use FittedBox for better scaling
                                    fit: BoxFit.scaleDown, // Scale down text to fit
                                    child: Text(markedDateLabel, style: const TextStyle(fontSize: 6)), // Smaller font size
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                if (isHoliday && markedDateLabel == null && !isMarked) ...[
                                  FittedBox( // FittedBox for holidays too
                                    fit: BoxFit.scaleDown,
                                    child: Text(holidayName, style: const TextStyle(fontSize: 6)), // Smaller font size
                                  ),
                                  const SizedBox(height: 2),
                                ],


                                Text(cellDetails.date.day.toString()),
                              ],
                            ),
                          );
                        },

                      ),
                    ),


                    FutureBuilder<List<DropdownMenuItem<String>>>(
                      future: _fetchSupervisorsFromFirebase(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('No supervisors found.');
                        } else {
                          // Extract items from snapshot
                          final items = snapshot.data!;

                          // Ensure the selected value exists in the dropdown items
                          final isValuePresent = items.any((item) => item.value == _selectedSupervisor);

                          return DropdownButtonFormField<String>(
                            value: isValuePresent ? _selectedSupervisor : null, // Use null if the value is not present
                            hint: const Text('Select Supervisor'),
                            onChanged: (newValue) async {
                              setState(() {
                                _selectedSupervisor = newValue;
                              });

                              List<String?> supervisorsemail = await _getSupervisorEmailFromFirebase(
                                _bioInfo.value?.department,
                                newValue,
                              );

                              setState(() {
                                _selectedSupervisorEmail = supervisorsemail[0];
                              });
                              print(_selectedSupervisorEmail);
                            },
                            items: items,
                            decoration: const InputDecoration(labelText: 'Supervisor'),
                          );
                        }
                      },
                    ),

                    // Other Leave Details
                    TextFormField(
                      controller: _reasonController, // Use a controller
                      decoration: const InputDecoration(labelText: "Reason(s) For been Out-Of-Office"),
                    ),




                    const SizedBox(height: 16.0), // Add spacing between dropdown and buttons

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Evenly space buttons
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _handleSaveAndSubmit(context, setState);
                          },
                          child: const Text("Save Request"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          });
        });
  }

  Future<List<String?>> _getSupervisorEmailFromFirebase(String? department, String? newValue) async {
    List<String?> emails = [];
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .where('department', isEqualTo: department)
          .where('role', isEqualTo: 'Supervisor')
          .where('firstName', isEqualTo: newValue) // Assuming supervisor name is stored in 'firstName'
          .get();

      emails = querySnapshot.docs.map((doc) => BioModel.fromJson(doc.data()).emailAddress).toList();
    } catch (e) {
      print("Error fetching supervisor emails from Firebase: $e");
    }
    return emails;
  }


  Future<List<DropdownMenuItem<String>>> _fetchSupervisorsFromFirebase() async {
    List<DropdownMenuItem<String>> supervisorItems = [];
    try {
      BioModel? userBio = _bioInfo.value;
      if (userBio != null) {
        QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
            .collection('Staff')
            .where('department', isEqualTo: userBio.department)
            .where('state', isEqualTo: userBio.state)
            .where('role', isEqualTo: 'Supervisor')
            .get();

        supervisorItems = querySnapshot.docs.map((doc) {
          BioModel supervisorBio = BioModel.fromJson(doc.data());
          return DropdownMenuItem<String>(
            value: supervisorBio.firstName, // Use supervisor's first name as value
            child: Text(supervisorBio.firstName!),
          );
        }).toList();
      }
    } catch (e) {
      print("Error fetching supervisors from Firebase: $e");
    }
    return supervisorItems;
  }


  String? _getMarkedDateLabel(DateTime date) {
    final attendanceRecords = _getAttendanceForDateFromFirebaseSync(DateFormat('dd-MMMM-yyyy').format(date));

    if (attendanceRecords.isNotEmpty){
      return attendanceRecords[0].durationWorked;
    }
    return null;
  }

  List<AttendanceModel> _getAttendanceForDateFromFirebaseSync(String formattedDate) {
    // This is a synchronous placeholder. In real web app, avoid synchronous operations if possible.
    // Consider fetching this data asynchronously beforehand or use a different approach for web.
    List<AttendanceModel> records = [];
    // Placeholder for synchronous data fetching - consider making this asynchronous for web
    return records;
  }


  List<DateTime> _getSelectedDates(PickerDateRange range) {
    List<DateTime> dates = [];
    for (int i = 0; i <= range.endDate!.difference(range.startDate!).inDays; i++) {
      dates.add(range.startDate!.add(Duration(days: i)));
    }
    return dates;
  }


  Widget _leaveTypeButton(StateSetter setState, String type, String label) {
    return ElevatedButton(
      onPressed: () => setState(() => _selectedLeaveType = type),
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedLeaveType == type ? Colors.blue : Colors.grey,
      ),
      child: Text(label),
    );
  }


  void _onSelectionChanged(
      DateRangePickerSelectionChangedArgs args, StateSetter setState) {
    if (args.value is PickerDateRange) {
      _selectedDateRange = args.value;
      setState(() {}); // This line is important to rebuild the bottom sheet
    }
  }


  Widget _buildCircularPercentIndicator(int usedAnnual,int remainingAnnual,int usedPaternity,int remainingPaternity,int usedMaternity,int remainingMaternity) {
    RxInt totalLeaves = 0.obs;
    RxInt usedLeaves = 0.obs;
    final DateTime now = DateTime.now();
    final int fiscalYear = now.month >= 10 ? now.year + 1 : now.year;
    final String fiscalYearShort = fiscalYear.toString().substring(2); // Extract last two digits


    // Calculate leave values reactively
    totalLeaves.bindStream(
      (() async* {
        if (_bioInfo.value?.maritalStatus == 'Married') {
          if (_bioInfo.value?.gender == 'Male') {
            yield remainingAnnual + remainingPaternity;
          } else {
            // Female: Maternity leave includes annual leave
            yield remainingMaternity;
          }
        } else {
          // Other marital statuses
          yield remainingAnnual;
        }
      })(),
    );

    usedLeaves.bindStream(
      (() async* {
        if (_bioInfo.value?.maritalStatus == 'Married') {
          if (_bioInfo.value?.gender == 'Male') {
            yield usedAnnual + usedPaternity;
          } else {
            // Female: Adjust if part of the annual leave
            yield (usedMaternity + usedAnnual);
          }
        } else {
          // Other marital statuses
          yield usedAnnual;
        }
      })(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Obx(() => CircularPercentIndicator(

              radius: 100, // Fixed radius for web
              lineWidth: 14, // Fixed lineWidth for web
              percent: totalLeaves.value > 0
                  ? usedLeaves.value / totalLeaves.value
                  : 0,
              center: Text(
                "Total for FY$fiscalYearShort: ${totalLeaves.value}", // Total available across leave types
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600), // Fixed font size
              ),
              progressColor: Colors.green,
              backgroundColor: Colors.grey,
              circularStrokeCap: CircularStrokeCap.round,
            )),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Obx(() => _buildSummaryItem("Used", usedLeaves.value, Colors.blue)),
                Obx(() => _buildSummaryItem(
                    "Balance", totalLeaves.value - usedLeaves.value, Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildLeaveRequestsCard() {
    // Group leave requests by fiscal year
    final leaveRequestsByFiscalYear = <String, List<LeaveRequestModel>>{};
    for (final leaveRequest in _leaveRequests) {
      final fiscalYear = _getFiscalYear(leaveRequest.startDate!);
      leaveRequestsByFiscalYear.putIfAbsent(fiscalYear, () => []).add(leaveRequest);
    }

    return Card(
      margin: const EdgeInsets.only(top: 16.0),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Text(
                "Leave Requests",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            if (_leaveRequests.isEmpty)
              const Center(child: Text("No leave requests found."))
            else
              ExpansionPanelList(
                expansionCallback: (int index, bool isExpanded) {
                  setState(() {
                    if (isExpanded) {
                      expandedPanelIndex.value = index;
                    } else {
                      if (expandedPanelIndex.value == index) {
                        expandedPanelIndex.value = -1; // Collapse
                      }
                    }
                  });
                },
                children: leaveRequestsByFiscalYear.entries.map<ExpansionPanel>((entry) {
                  final fiscalYear = entry.key;
                  final leaveRequests = entry.value;

                  return ExpansionPanel(
                    headerBuilder: (BuildContext context, bool isExpanded) {
                      return ListTile(
                          title: Text("FY $fiscalYear Out-of-Office Leave Section"),
                          leading: isExpanded?const Icon(Icons.remove,color: Colors.red,):const Icon(Icons.add,color: Colors.green,)
                      );
                    },
                    isExpanded: expandedPanelIndex.value == leaveRequestsByFiscalYear.entries
                        .toList()
                        .indexWhere((e) => e.key == fiscalYear),
                    body: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: leaveRequests.length,
                      itemBuilder: (context, index) {
                        final leaveRequest = leaveRequests[index];
                        return _buildLeaveRequestTile(leaveRequest); //Helper function
                      },
                    ),
                    canTapOnHeader: true, // IMPORTANT: Allow tapping on the header
                    // isExpanded: leaveRequestsByFiscalYear.entries // Correct expansion logic
                    //     .toList()
                    //     .indexWhere((e) => e.key == fiscalYear) == 0

                  );
                }).toList(),
              ),


          ],
        ),
      ),
    );
  }




  Widget _buildLeaveRequestTile(LeaveRequestModel leaveRequest){  //Helper function to build individual leave request tiles
    return ListTile(
      title: Text(leaveRequest.type!),
      subtitle: Text(
        'From ${DateFormat('dd MMMM, yyyy').format(leaveRequest.startDate!)} to ${DateFormat('dd MMMM, yyyy').format(leaveRequest.endDate!)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: SizedBox(
        width: 400, // Fixed width for web trailing section
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getStatusIcon(leaveRequest.status),
              color: _getStatusColor(leaveRequest.status),
            ),
            const SizedBox(width: 8),
            Flexible( // Wraps the text to the next line if it's too long
              child: Text(
                leaveRequest.status!,
                overflow: TextOverflow.ellipsis, // Truncates the text with "..." if it overflows
              ),
            ),
            // ... (Rest of your trailing widgets - edit, delete, sync, duration)
            leaveRequest.status == "Approved" ?const SizedBox.shrink():
            leaveRequest.status == "Rejected" ?const SizedBox.shrink():
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showEditLeaveBottomSheet(context, leaveRequest);
              },
            ),
            leaveRequest.status == "Approved" ?const SizedBox.shrink():
            leaveRequest.status == "Rejected" ?const SizedBox.shrink():
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                _showDeleteConfirmationDialog(context, leaveRequest);
              },
            ),
            leaveRequest.status == "Approved" ?const SizedBox.shrink():
            leaveRequest.status == "Rejected" ?const SizedBox.shrink():
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () {
                _handleSync(leaveRequest);
              },
            ),
            const SizedBox(width:20),

            leaveRequest.status == "Approved"?
            Text("Duration: ${leaveRequest.leaveDuration} day(s)"):const SizedBox.shrink(),
            leaveRequest.status == "Rejected"?
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Rejection Reason"),
                      content: Text(leaveRequest.reasonsForRejectedLeave ?? ""), // Handle null
                      actions: <Widget>[
                        TextButton(
                          child: const Text("OK"),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ):
            const SizedBox.shrink(),
          ],
        ),
      ),


    );
  }


  String _getFiscalYear(DateTime date) {
    final year = date.month >= 10 ? date.year + 1 : date.year;
    return year.toString().substring(2);
  }



  Future<void> _handleSync(LeaveRequestModel newLeaveRequest) async{
    await _submitLeaveRequest(newLeaveRequest, context);
  }


  void _showEditLeaveBottomSheet(BuildContext context, LeaveRequestModel leaveRequest) {
    // Set initial values for the bottom sheet fields
    _selectedLeaveType = leaveRequest.type!;
    _reasonController.text = leaveRequest.reason!;
    _selectedDateRange = PickerDateRange(leaveRequest.startDate, leaveRequest.endDate);
    _selectedSupervisor = leaveRequest.selectedSupervisor;
    _selectedSupervisorEmail = leaveRequest.selectedSupervisorEmail;



    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            List<Widget> leaveTypeButtons = [];

            if (_bioInfo.value?.maritalStatus == 'Married') {
              if (_bioInfo.value?.gender == 'Male') {
                leaveTypeButtons.addAll([
                  _leaveTypeButton(setState, 'Paternity', 'Paternity Leave'),
                  _leaveTypeButton(setState, 'Annual', 'Annual Leave'),
                ]);
              } else {
                leaveTypeButtons.addAll([
                  _leaveTypeButton(setState, 'Maternity', 'Maternity Leave'),
                  _leaveTypeButton(setState, 'Annual', 'Annual Leave'),
                ]);
              }
            } else {
              leaveTypeButtons.add(_leaveTypeButton(setState, 'Annual', 'Annual Leave'));
            }

            leaveTypeButtons.add(_leaveTypeButton(setState, 'Holiday', 'Holidays'));


            return SingleChildScrollView( // Wrap with SingleChildScrollView
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                width: MediaQuery.of(context).size.width * 0.5, // Limit width for web
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch across width
                  children: <Widget>[
                    // ... (rest of the bottom sheet content)
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: leaveTypeButtons,
                    ),
                    // ... (date picker, reason field, supervisor dropdown)

                    SizedBox( // Added SizedBox to control width of SfDateRangePicker on web
                      width: 400, // Set a fixed width for the date picker on web
                      height: 400, // Set a fixed height for the date picker on web
                      child: SfDateRangePicker(

                        onSelectionChanged: (args) {
                          if (args.value is PickerDateRange) {
                            final selectedDates = _getSelectedDates(args.value);
                            final containsMarkedDate = selectedDates.any((date) => _markedDates.contains(date));

                            if (containsMarkedDate) {
                              Fluttertoast.showToast(msg: "Attendance exists for the selected date(s).");


                              // Clear the selection or reset to a valid range
                              _selectedDateRange = null; //Clear selection, or
                              //_selectedDateRange = PickerDateRange(DateTime.now(), DateTime.now()); //Reset to today
                              setState(() {}); //Force bottom sheet to rebuild
                              return;
                            }
                          }
                          _onSelectionChanged(args, setState); //Call original function
                        },
                        selectionMode: DateRangePickerSelectionMode.range,
                        initialSelectedRange: PickerDateRange(
                          DateTime.now(),
                          DateTime.now().add(const Duration(days: 1)),
                        ),
                        headerStyle: const DateRangePickerHeaderStyle(
                          backgroundColor: Colors.blue,
                          textStyle: TextStyle(color: Colors.white),
                        ),
                        todayHighlightColor: Colors.red,
                        selectableDayPredicate: (DateTime date) {
                          return !_markedDates.contains(date);  // Disable marked dates directly
                        },
                        cellBuilder: (BuildContext context, DateRangePickerCellDetails cellDetails) {

                          final holidayName = _nigerianHolidays[cellDetails.date];
                          bool isHoliday = holidayName != null;
                          bool isMarked = _markedDates.contains(cellDetails.date);
                          final markedDateLabel = _getMarkedDateLabel(cellDetails.date); // Always get the label

                          return Container(
                            decoration: BoxDecoration(
                              color: isHoliday ? Colors.green.withOpacity(0.2) : isMarked
                                  ? Colors.grey
                                  : null,
                              border: Border.all(color: const Color(0xFFF0F0F0), width: 0.5),
                            ),
                            child: Column(  // Use a Column for vertical layout
                              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                              children: [
                                if (markedDateLabel != null) ...[
                                  FittedBox( // Use FittedBox for better scaling
                                    fit: BoxFit.scaleDown, // Scale down text to fit
                                    child: Text(markedDateLabel, style: const TextStyle(fontSize: 6)), // Smaller font size
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                if (isHoliday && markedDateLabel == null && !isMarked) ...[
                                  FittedBox( // FittedBox for holidays too
                                    fit: BoxFit.scaleDown,
                                    child: Text(holidayName, style: const TextStyle(fontSize: 6)), // Smaller font size
                                  ),
                                  const SizedBox(height: 2),
                                ],


                                Text(cellDetails.date.day.toString()),
                              ],
                            ),
                          );
                        },

                      ),
                    ),

                    FutureBuilder<List<DropdownMenuItem<String>>>(
                      future: _fetchSupervisorsFromFirebase(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('No supervisors found.');
                        } else {
                          return DropdownButtonFormField<String>(
                            value: _selectedSupervisor,
                            hint: const Text('Select Supervisor'),
                            onChanged: (newValue) async {


                              setState(() {
                                _selectedSupervisor = newValue;

                              });

                              List<String?> supervisorsemail = await _getSupervisorEmailFromFirebase(_bioInfo.value?.department,newValue);


                              setState(() {
                                _selectedSupervisorEmail = supervisorsemail[0];

                              });
                              print(_selectedSupervisorEmail);

                            },
                            items: snapshot.data,
                            decoration: const InputDecoration(labelText: 'Supervisor'),
                          );
                        }
                      },
                    ),
                    //Other Leave Details
                    TextFormField(
                      controller: _reasonController, // Use a controller
                      decoration: const InputDecoration(labelText: "Reason(s) For been Out-Of-Office"),
                    ),




                    const SizedBox(height: 16.0), // Add spacing between dropdown and buttons

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Evenly space buttons
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await _handleUpdateLeaveRequest(context, leaveRequest, setState); // Add setState here
                          },
                          child: const Text("Update"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          });
        });
  }

  Future<void> _updateRemainingLeavesAndDate() async {
    final userId = _bioInfo.value?.firebaseAuthId;
    if (userId == null) return;

    DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
        .collection('Staff')
        .doc(userId)
        .collection('RemainingLeaves')
        .doc(userId)
        .get();

    RemainingLeaveModel? remainingLeaveRequest;
    if (docSnapshot.exists) {
      remainingLeaveRequest = RemainingLeaveModel.fromJson(docSnapshot.data()!);
    }

    if (remainingLeaveRequest != null) {
      final now = DateTime.now();
      final currentYear = now.year;
      final octoberThisYear = DateTime(currentYear, 10, 1);

      if (remainingLeaveRequest.dateUpdated!.isBefore(octoberThisYear) &&
          now.isAfter(octoberThisYear)) { // Check current date against October

        remainingLeaveRequest.annualLeaveBalance = 10;
        remainingLeaveRequest.paternityLeaveBalance = 6;
        remainingLeaveRequest.maternityLeaveBalance = 60;
        remainingLeaveRequest.holidayLeaveBalance = 0;

        // Update observables for immediate UI update:
        _remainingAnnualLeaveBalance.value = 10;
        _remainingPaternityLeaveBalance.value = 6;
        _remainingMaternityLeaveBalance.value = 60;
        //_totalHolidayLeaves.value = 0; // You might not need to update this if it's always 0
      }

      remainingLeaveRequest.dateUpdated = DateTime.now();
      await _updateRemainingLeaveInFirebase(remainingLeaveRequest);

      // Update observables to trigger UI updates *after* the transaction
      _remainingLeaves.value = remainingLeaveRequest;
    }
  }

  Future<void> _updateRemainingLeaveInFirebase(RemainingLeaveModel remainingLeaveRequest) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('Staff')
            .doc(user.uid)
            .collection('RemainingLeaves')
            .doc(user.uid)
            .set(remainingLeaveRequest.toJson());
      }
    } catch (e) {
      print("Error updating remaining leave in Firebase: $e");
    }
  }


  Future<void> _handleUpdateLeaveRequest(BuildContext context, LeaveRequestModel leaveRequest, StateSetter setState) async{
    try {
      leaveRequest.type = _selectedLeaveType;
      leaveRequest.startDate = _selectedDateRange!.startDate;
      leaveRequest.endDate = _selectedDateRange!.endDate ?? _selectedDateRange!.startDate;
      leaveRequest.reason = _reasonController.text;
      leaveRequest.selectedSupervisor = _selectedSupervisor;
      leaveRequest.selectedSupervisorEmail = _selectedSupervisorEmail;
      leaveRequest.staffCategory = _bioInfo.value?.staffCategory;
      leaveRequest.staffState = _bioInfo.value?.state;
      leaveRequest.staffLocation = _bioInfo.value?.location;
      leaveRequest.staffEmail = _bioInfo.value?.emailAddress;
      leaveRequest.staffPhone = _bioInfo.value?.mobile;
      leaveRequest.staffDepartment = _bioInfo.value?.department;
      leaveRequest.staffDesignation = _bioInfo.value?.designation;
      leaveRequest.firstName = _bioInfo.value?.firstName;
      leaveRequest.lastName = _bioInfo.value?.lastName;


      await _updateLeaveRequestInFirebase(leaveRequest);
      await _updateLeaveBalanceAfterApproval(leaveRequest);
      await _updateRemainingLeavesAndDate(); // Pass the endDate

      // Update status to Pending after updating Firestore

      leaveRequest.status = 'Pending';
      await _updateLeaveRequestInFirebase(leaveRequest);


      if (mounted) { // Add mounted check
        Navigator.of(context).pop(); // Close the bottom sheet
        Fluttertoast.showToast(
            msg: "Leave Request updated successfully",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0);
      }




    } catch (e) {
      // Handle any errors
      print("Error updating leave request: $e");
      if (mounted) {
        Fluttertoast.showToast(
            msg: "Failed to update leave request.",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0);

      }

    }

  }

  Future<void> _updateLeaveBalanceAfterApproval(LeaveRequestModel leaveRequest) async {
    if (leaveRequest.status == 'Approved') {
      final leaveDuration = leaveRequest.leaveDuration;
      if (leaveDuration != null && leaveDuration > 0) {
        try {
          final currentRemainingLeaves = _remainingLeaves.value; // Get a local copy
          if (currentRemainingLeaves == null) {
            print("Remaining leaves not initialized."); // Handle this case as needed
            return;
          }

          // Update Firebase Firestore
          final userId = _bioInfo.value?.firebaseAuthId;
          if (userId != null) {
            DocumentReference remainingLeaveDocRef = FirebaseFirestore.instance
                .collection('Staff')
                .doc(userId)
                .collection('RemainingLeaves')
                .doc(userId);

            int updatedAnnualBalance = currentRemainingLeaves.annualLeaveBalance!;
            int updatedPaternityBalance = currentRemainingLeaves.paternityLeaveBalance!;
            int updatedMaternityBalance = currentRemainingLeaves.maternityLeaveBalance!;
            int updatedHolidayBalance = currentRemainingLeaves.holidayLeaveBalance!;


            switch (leaveRequest.type) {
              case 'Annual':
                updatedAnnualBalance = (currentRemainingLeaves.annualLeaveBalance! - leaveDuration).clamp(0, _totalAnnualLeaves.value);
                break;
              case 'Paternity':
                updatedPaternityBalance = (currentRemainingLeaves.paternityLeaveBalance! - leaveDuration).clamp(0, _totalPaternityLeaves.value);
                break;
              case 'Maternity':
                updatedMaternityBalance = (currentRemainingLeaves.maternityLeaveBalance! - leaveDuration).clamp(0, _totalMaternityLeaves.value);
                break;
              case 'Holiday':
                updatedHolidayBalance = (currentRemainingLeaves.holidayLeaveBalance! + leaveDuration).clamp(0, _totalHolidayLeaves.value);
                break;
            }

            await remainingLeaveDocRef.update({
              'annualLeaveBalance': updatedAnnualBalance,
              'paternityLeaveBalance': updatedPaternityBalance,
              'maternityLeaveBalance': updatedMaternityBalance,
              'holidayLeaveBalance': updatedHolidayBalance,
            });

            // Update local observable after successful Firestore update
            currentRemainingLeaves.annualLeaveBalance = updatedAnnualBalance;
            currentRemainingLeaves.paternityLeaveBalance = updatedPaternityBalance;
            currentRemainingLeaves.maternityLeaveBalance = updatedMaternityBalance;
            currentRemainingLeaves.holidayLeaveBalance = updatedHolidayBalance;
            _remainingLeaves.value = currentRemainingLeaves; // Update observable

          }


        } catch (e) {
          print('Error updating leave balance in Firebase: $e');
          // Display an error message to the user.
          Fluttertoast.showToast(
              msg: "Error updating leave balance: $e",
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: Colors.black54,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              textColor: Colors.white,
              fontSize: 16.0
          );
        }
      }
    }
  }

  Future<void> _updateLeaveRequestInFirebase(LeaveRequestModel leaveRequest) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final staffCollection = FirebaseFirestore.instance.collection('Staff').doc(user.uid);
        final leaveRequestCollection = staffCollection.collection('Leave Request');
        await leaveRequestCollection.doc(leaveRequest.leaveRequestId).update(leaveRequest.toJson());
      }
    } catch (e) {
      print("Error updating leave request in Firebase: $e");
    }
  }



  void _showDeleteConfirmationDialog(BuildContext context, LeaveRequestModel leaveRequest) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this leave request?"),
          actions: <Widget>[
            TextButton(
              child: const Text("No"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text("Yes"),
              onPressed: () async {
                try {
                  // Delete from Firestore
                  await _deleteLeaveRequestFromFirebase(leaveRequest);

                  // Refresh the UI
                  _getLeaveData();

                  if(mounted){
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leave Request deleted successfully")));
                  }


                } catch (e) {
                  if(mounted){
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete Leave Request")));
                  }
                  print("Error deleting leave request: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteLeaveRequestFromFirebase(LeaveRequestModel leaveRequest) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('Staff')
            .doc(user.uid)
            .collection('Leave Request')
            .doc(leaveRequest.leaveRequestId)
            .delete();
      }
    } catch (e) {
      print("Error deleting leave request from Firebase: $e");
    }
  }


  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'Approved': return Icons.check_circle;
      case 'Rejected': return Icons.cancel;
      case 'Pending': return Icons.access_time;
      default: return Icons.help;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Approved': return Colors.green;
      case 'Rejected': return Colors.red;
      case 'Pending': return Colors.orange;
      default: return Colors.grey;
    }
  }



  Future<void> _handleSaveAndSubmit(
      BuildContext context, StateSetter setState) async {



    if (_selectedDateRange == null ||
        _reasonController.text.isEmpty ||
        _selectedSupervisor == null) {
      Fluttertoast.showToast(
          msg: "Please fill all fields.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM);
      return;
    }

    final leaveDuration = _calculateLeaveDuration(
      _selectedLeaveType,
      _selectedDateRange!.startDate!,
      _selectedDateRange!.endDate ?? _selectedDateRange!.startDate!,
    );


    if (leaveDuration <= 0) {
      Fluttertoast.showToast(
          msg: "Selected dates are invalid.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM);
      return;
    }

    if (_remainingLeaves.value == null) { //Check if _remainingLeaves.value is null
      return; //or show some error message
    }

    final selectedDates = _getSelectedDates(_selectedDateRange!);
    if (selectedDates.any((date) => _markedDates.contains(date))) {
      Fluttertoast.showToast(msg: "There are days with attendance within your date range. Request not saved.");
      return; // Don't proceed with saving
    }


    switch (_selectedLeaveType) {
      case 'Annual':
        final annualBalance = _remainingLeaves.value!.annualLeaveBalance;
        if (annualBalance != null && leaveDuration > annualBalance) { // Check for null and then compare
          _showLeaveExceedsBalanceError(context, 'Annual', annualBalance); //No need for !
          return;
        }
        break;
      case 'Paternity':
        final paternityBalance = _remainingLeaves.value!.paternityLeaveBalance;
        if (paternityBalance != null && leaveDuration > paternityBalance) {
          _showLeaveExceedsBalanceError(context, 'Paternity', paternityBalance);
          return;
        }
        break;
      case 'Maternity':
        final maternityBalance = _remainingLeaves.value!.maternityLeaveBalance;
        if (maternityBalance != null && leaveDuration > maternityBalance) {
          _showLeaveExceedsBalanceError(context, 'Maternity', maternityBalance);
          return;
        }
        break;
    }


    final newLeaveRequest = LeaveRequestModel(
      type: _selectedLeaveType,
      startDate: _selectedDateRange!.startDate,
      endDate: _selectedDateRange!.endDate ?? _selectedDateRange!.startDate,
      reason: _reasonController.text,
      staffId: _bioInfo.value?.firebaseAuthId,
      selectedSupervisor: _selectedSupervisor,
      selectedSupervisorEmail: _selectedSupervisorEmail,
      leaveDuration: leaveDuration,
      status: 'Pending',
      firstName: _bioInfo.value?.firstName!,
      lastName: _bioInfo.value?.lastName!,
      staffCategory: _bioInfo.value?.staffCategory!,
      staffState: _bioInfo.value?.state!,
      staffLocation: _bioInfo.value?.location!,
      staffEmail: _bioInfo.value?.emailAddress!,
      staffPhone: _bioInfo.value?.mobile!,
      staffDepartment: _bioInfo.value?.department!,
      staffDesignation: _bioInfo.value?.designation!,
      leaveRequestId: const Uuid().v4(), // Generate UUID for leaveRequestId
    );




    // The await calls don't return a value, so just await them directly
    try {
      await _saveLeaveRequestToFirebase(newLeaveRequest);  // Save to Firebase

      if (mounted) {
        Navigator.pop(context);
        Fluttertoast.showToast(
            msg: "Request saved locally.",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0);
        setState(() {}); // Rebuild to show saved request.


      }

    } catch (error) {
      // Handle any errors during submission
      print("Error in Save and Submit: $error");
      // Show an error message to the user if needed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An error occurred with saveLeaveRequest. Please try again.")),
        );
      }

    }

  }


  void _showLeaveExceedsBalanceError(BuildContext context, String leaveType, int remainingBalance) {
    Fluttertoast.showToast(
      msg: "$leaveType leave cannot exceed $remainingBalance working days. You have $remainingBalance days remaining.",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );
  }


  int _calculateLeaveDuration(String leaveType, DateTime startDate, DateTime endDate) {
    int duration = endDate.difference(startDate).inDays + 1;
    if (leaveType == 'Annual') {
      for (var date = startDate; !date.isAfter(endDate); date = date.add(const Duration(days: 1))) {
        if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
          duration--;
        }
      }
    }
    return duration;
  }


  Future<void> _submitLeaveRequest(LeaveRequestModel leaveRequest, BuildContext context) async {

    // Check if Firebase is initialized before using it
    if (!_firebaseInitialized.value) {
      print("Firebase not initialized. Cannot submit leave request.");
      Fluttertoast.showToast(msg: "Firebase not initialized. Cannot submit request.");
      return; // Or handle the error as needed
    }
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final staffCollection =
        FirebaseFirestore.instance.collection('Staff').doc(user.uid);
        final leaveRequestCollection = staffCollection.collection('Leave Request');

        // Use the leaveRequestId from the LeaveRequestModel as the document ID in Firestore
        final leaveRequestId = leaveRequest.leaveRequestId; // Get leaveRequestId

        if (leaveRequestId != null) {  //Check if leaveRequestId exists for local requests
          await leaveRequestCollection.doc(leaveRequestId).set({ // Use set() with doc ID
            ...leaveRequest.toJson(),
            'leaveRequestId': leaveRequestId, // Include leaveRequestId in document
            'status':"Pending"

          });

          //await sendEmailToSupervisor(leaveRequest); // Send email after saving
          await sendEmailFromDevice(
            leaveRequest.selectedSupervisorEmail!,
            'New Leave Request from ${leaveRequest.firstName} ${leaveRequest.lastName}',
            _formatLeaveRequestEmail2(leaveRequest),
          );


          // Update isSynced flag - if you are tracking it in Firebase, update here.
          // Since we are not tracking 'isSynced' in Firebase in this example, no need to update it.


          // Refresh leave data and UI
          _getLeaveData(); // Or setState(() {});
          if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Out of Office request submitted successfully.")));
          }


        }



      }
    } catch (e) {
      print("Error submitting leave request: $e");
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error syncing out of Office request. Please try again."),
        ));
      }
    }
  }

  Future<void> _checkAndUpdateLeaveStatus() async {
    try {
      final userId = _bioInfo.value?.firebaseAuthId;
      if (userId == null) return;

      // Fetch all leave requests for the staff member from Firebase Stream (already bound to _leaveRequests)
      // No need to fetch again unless you need to refresh it explicitly.

      for (final leaveRequest in _leaveRequests) {
        print("leaveRequest === ${leaveRequest.leaveRequestId}");

        try {
          // Fetch the corresponding leave request document from Firestore
          final doc = await FirebaseFirestore.instance
              .collection('Staff')
              .doc(userId)
              .collection('Leave Request')
              .doc(leaveRequest.leaveRequestId)
              .get();

          if (doc.exists) {
            final firestoreStatus = doc.data()?['status'] as String?;
            final firestoreReason = doc.data()?['reason'] as String?;

            final firestoreReasonsForRejectedLeave = doc.data()?['reasonsForRejectedLeave'] as String?;

            // Update local state if Firestore status differs
            if (firestoreStatus != null && firestoreStatus != leaveRequest.status) {
              leaveRequest.status = firestoreStatus; // Update the local LeaveRequestModel status
              // No need to save back to Firebase here as status is updated from Firebase itself

              if (firestoreStatus == 'Approved') {
                // Add attendance records and deduct leave balance
                await _addLeaveToAttendance1(
                  userId,
                  leaveRequest.startDate,
                  leaveRequest.endDate,
                  leaveRequest.type,
                  firestoreReason,
                ).then((_) async {
                  final leaveDuration = leaveRequest.leaveDuration ?? 0;
                  await _deductLeaveBalance(leaveRequest, leaveDuration);
                });
                Fluttertoast.showToast(msg: "Out of Office Request Approved");
              } else if (firestoreStatus == 'Rejected') {
                leaveRequest.reasonsForRejectedLeave = firestoreReasonsForRejectedLeave; //Update rejection reason
                Fluttertoast.showToast(msg: "Out of Office Request Rejected");
              }
              // Since _leaveRequests is an RxList, updating leaveRequest object inside it should trigger UI update.
            }
          }
        } catch (innerError) {
          print('Error processing individual leave request: $innerError');
          Fluttertoast.showToast(
              msg: "Error processing individual Out of Office Request: $innerError");
        }
      }

      // No need to navigate again as data is streamed and UI updates automatically.
      // If you need to refresh the whole page, consider using Navigator.pushReplacementNamed for web.
      // Get.off(() => LeaveRequestsPageWeb()); // Navigation might not be necessary for web refresh, consider other methods if needed.
    } catch (e) {
      print('Error checking Out of Office Request status: $e');
      Fluttertoast.showToast(msg: "Error syncing Out of Office Request status");
    }
  }



  Future<void> _addLeaveAttendanceRecord(DateTime date, String leaveType) async {
    // This function seems to be related to Isar. For Firebase, you might want to directly save attendance to Firestore.
    // However, based on the original code, this might not be directly needed in this web version if attendance is managed differently.
    // If you need to save attendance records to Firebase, implement the Firebase save operation here.
    print("Placeholder for _addLeaveAttendanceRecord for web using Firebase.");
  }

  Future<void> _deductLeaveBalance(LeaveRequestModel leaveRequest, int daysToDeduct) async {
    final userId = _bioInfo.value?.firebaseAuthId;
    if (userId == null) return;

    DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
        .collection('Staff')
        .doc(userId)
        .collection('RemainingLeaves')
        .doc(userId)
        .get();

    RemainingLeaveModel? updatedLeaveRequest;
    if (docSnapshot.exists) {
      updatedLeaveRequest = RemainingLeaveModel.fromJson(docSnapshot.data()!);
    }

    if (updatedLeaveRequest != null) {


      switch (leaveRequest.type) {
        case 'Annual':
          updatedLeaveRequest.annualLeaveBalance = (updatedLeaveRequest.annualLeaveBalance! - daysToDeduct).clamp(0, _totalAnnualLeaves.value);
          break;
        case 'Paternity':
          updatedLeaveRequest.paternityLeaveBalance = (updatedLeaveRequest.paternityLeaveBalance! - daysToDeduct).clamp(0, _totalPaternityLeaves.value);
          break;
        case 'Maternity':
          updatedLeaveRequest.maternityLeaveBalance = (updatedLeaveRequest.maternityLeaveBalance! - daysToDeduct).clamp(0, _totalMaternityLeaves.value);
          break;
        case 'Holiday':
          updatedLeaveRequest.holidayLeaveBalance = (updatedLeaveRequest.holidayLeaveBalance! + daysToDeduct);
          break;
      }
      await _updateRemainingLeaveInFirebase(updatedLeaveRequest);
      _remainingLeaves.value = updatedLeaveRequest; //Update observable
    }
  }


  Future<void> _addPreviousLeave(
      String? userId,
      DateTime? startDate,
      DateTime? endDate,
      String? leaveType,
      String? firestoreReason
      ) async {
    // Insert into Leave Request collection in Firestore
    await FirebaseFirestore.instance
        .collection('Staff')
        .doc(userId)
        .collection('Leave Request') // Use consistent collection name
        .add({ // Use add() to create a new document with auto-generated ID
      'startDate': startDate,
      'endDate': endDate,
      'leaveType': leaveType, // Include the leave type
      'reason': firestoreReason ?? '', // Or handle null as needed
      // ... any other relevant leave details

    });
  }


  Future<void> _addLeaveToAttendance1(
      String? userId,
      DateTime? startDate,
      DateTime? endDate,
      String? leaveType,
      String? firestoreReason
      ) async {
    // Validate input parameters
    if (userId == null || startDate == null || endDate == null || leaveType == null) {
      print('Invalid input for _addLeaveToAttendance1');
      Fluttertoast.showToast(
        msg: "Invalid input for _addLeaveToAttendance...",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    const int maxRetries = 5; // Maximum number of retry attempts
    const Duration initialDelay = Duration(seconds: 2); // Initial delay for retry

    for (var date = startDate; !date.isAfter(endDate); date = date.add(const Duration(days: 1))) {
      // Skip weekends
      if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
        int retryCount = 0; // Reset retry count for each date

        // Check if the record for this date already exists - Implement Firebase check here if needed.
        final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
        final existingRecord = await _getAttendanceForDateFromFirebase(formattedDate, userId);
        if (existingRecord.isNotEmpty) {
          print("Attendance for $formattedDate already exists. Skipping...");
          Fluttertoast.showToast(
            msg: "Attendance for $formattedDate already exists. Skipping...",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          continue;
        }

        while (retryCount < maxRetries) {
          try {
            print("Processing leave attendance for date: $date");
            Fluttertoast.showToast(
              msg: "Processing leave attendance for date: $date",
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: Colors.black54,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              textColor: Colors.white,
              fontSize: 16.0,
            );

            // Save attendance for the given date to Firebase
            await _saveAttendanceToFirebase(AttendanceModel(
              clockIn: '08:00 AM',
              date: formattedDate,
              clockInLatitude: lati.value,
              clockInLocation: location.value,
              clockInLongitude: longi.value,
              clockOut: '05:00 PM',
              clockOutLatitude: lati.value,
              clockOutLocation: location.value,
              clockOutLongitude: longi.value,
              comments: firestoreReason,
              isSynced: false,
              voided: false,
              isUpdated: true,
              offDay: true, // Set offDay to true for leave days
              durationWorked: leaveType == "Annual" ? "Annual Leave" : leaveType,
              noOfHours: 9.0001,
              month: DateFormat('MMMM yyyy').format(date),
            ), userId);


            // Break out of retry loop if successful
            print("Successfully added leave attendance for: $date");
            Fluttertoast.showToast(
              msg: "Successfully added leave attendance for: $date",
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: Colors.black54,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            break;
          } catch (e) {
            retryCount++;
            print("Error saving attendance for $date: $e (Retry: $retryCount)");
            Fluttertoast.showToast(
              msg: "Error saving attendance for $date: $e (Retry: $retryCount)",
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: Colors.black54,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              textColor: Colors.white,
              fontSize: 16.0,
            );

            if (retryCount < maxRetries) {
              final delay = initialDelay * retryCount; // Exponential backoff
              print("Retrying after ${delay.inSeconds} seconds...");
              Fluttertoast.showToast(
                msg: "Retrying after ${delay.inSeconds} seconds...",
                toastLength: Toast.LENGTH_LONG,
                backgroundColor: Colors.black54,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                textColor: Colors.white,
                fontSize: 16.0,
              );
              await Future.delayed(delay);
            } else {
              print("Max retries reached for $date. Skipping...");
              Fluttertoast.showToast(
                msg: "Max retries reached for $date. Skipping...",
                toastLength: Toast.LENGTH_LONG,
                backgroundColor: Colors.black54,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                textColor: Colors.white,
                fontSize: 16.0,
              );
            }
          }
        }
      }
    }

    // Fetch leave data after processing - Consider if refresh is needed for web UI.
    // await _getLeaveData(); // Refreshing data might not be necessary for web if using streams effectively.

    // Show confirmation message
    Fluttertoast.showToast(
      msg: "Leave added to attendance records.",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );
  }

  Future<List<AttendanceModel>> _getAttendanceForDateFromFirebase(String formattedDate, String userId) async {
    List<AttendanceModel> attendanceRecords = [];

    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .collection('Attendance')
          .where('date', isEqualTo: formattedDate)
          .get();

      attendanceRecords = querySnapshot.docs.map((doc) {
        // Decode the log content if it's stored as a JSON string
        Map<String, dynamic> data = doc.data();
        if (data.containsKey('log') && data['log'] is String) {
          try {
            data['log'] = jsonDecode(data['log']);
          } catch (e) {
            print("Error decoding log data: $e");
          }
        }
        return AttendanceModel.fromJson(data);
      }).toList();
    } catch (e) {
      print("Error fetching attendance for date from Firebase: $e");
    }

    return attendanceRecords;
  }

  Future<void> _saveAttendanceToFirebase(AttendanceModel attendance, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .collection('Attendance')
          .doc(DateFormat('dd-MM-yyyy').format(DateTime.now())) // Use date as document ID for simplicity, consider UUID if needed
          .set(attendance.toJson());
    } catch (e) {
      print("Error saving attendance to Firebase: $e");
      rethrow; // Re-throw to be caught by the retry logic
    }
  }


}