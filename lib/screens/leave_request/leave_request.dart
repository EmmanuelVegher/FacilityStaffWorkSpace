import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as locationPkg;
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:location/location.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';


import '../../services/location_services.dart';
import '../../widgets/drawer.dart';
import '../../widgets/geo_utils.dart';
import '../../widgets/header_widget.dart';


class GeofenceModel {
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final String category;
  final String stateName;

  GeofenceModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.category,
    required this.stateName,
  });

  factory GeofenceModel.fromFirestore(
      Map<String, dynamic> firestoreData, String stateName) {
    return GeofenceModel(
      name: firestoreData['LocationName'] ?? 'Unknown Location',
      latitude:
      GeofenceModel._parseNum(firestoreData['Latitude'])?.toDouble() ?? 0.0,
      longitude: GeofenceModel._parseNum(firestoreData['Longitude'])?.toDouble() ??
          0.0,
      radius:
      GeofenceModel._parseNum(firestoreData['Radius'])?.toDouble() ?? 100.0,
      category: firestoreData['category'] ?? 'General',
      stateName: stateName,
    );
  }

  static num? _parseNum(dynamic value) {
    if (value is num) {
      return value;
    } else if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }
}

class LeaveRequestModel {
  String? type;
  String? status = "Pending";
  DateTime? startDate;
  DateTime? endDate;
  String? reason;
  bool isSynced = false;
  String? staffId;
  String? leaveRequestId;
  String? selectedSupervisor;
  String? selectedSupervisorEmail;
  int? leaveDuration;
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
    this.type,
    this.status = "Pending",
    this.startDate,
    this.endDate,
    this.reason,
    this.isSynced = false,
    this.staffId,
    this.leaveRequestId,
    this.selectedSupervisor,
    this.selectedSupervisorEmail,
    this.leaveDuration,
    this.firstName,
    this.lastName,
    this.staffCategory,
    this.staffState,
    this.staffLocation,
    this.staffEmail,
    this.staffPhone,
    this.staffDepartment,
    this.staffDesignation,
    this.reasonsForRejectedLeave,
  });


  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      type: json['type'] as String?,
      status: json['status'] as String? ?? "Pending",
      startDate: json['startDate'] == null
          ? null
          : json['startDate'] is Timestamp
          ? (json['startDate'] as Timestamp).toDate()
          : DateTime.tryParse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : json['endDate'] is Timestamp
          ? (json['endDate'] as Timestamp).toDate()
          : DateTime.tryParse(json['endDate'] as String),
      reason: json['reason'] as String?,
      isSynced: json['isSynced'] as bool? ?? false,
      staffId: json['staffId'] as String?,
      leaveRequestId: json['leaveRequestId'] as String?,
      selectedSupervisor: json['selectedSupervisor'] as String?,
      selectedSupervisorEmail: json['selectedSupervisorEmail'] as String?,
      leaveDuration: json['leaveDuration'] as int?,
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
    return {
      'type': type,
      'status': status,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'reason': reason,
      'isSynced': isSynced,
      'staffId': staffId,
      'leaveRequestId': leaveRequestId,
      'selectedSupervisor': selectedSupervisor,
      'selectedSupervisorEmail': selectedSupervisorEmail,
      'leaveDuration':leaveDuration,
      'firstName':firstName,
      'lastName':lastName,
      'staffCategory':staffCategory,
      'staffState':staffState,
      'staffLocation':staffLocation,
      'staffEmail':staffEmail,
      'staffPhone':staffPhone,
      'staffDepartment':staffDepartment,
      'staffDesignation':staffDesignation,
      'reasonsForRejectedLeave':reasonsForRejectedLeave
    };
  }
}

class LeaveRequestsPage1 extends StatefulWidget {
  const LeaveRequestsPage1({super.key});

  @override
  _LeaveRequestsPage1State createState() => _LeaveRequestsPage1State();
}

class _LeaveRequestsPage1State extends State<LeaveRequestsPage1> with SingleTickerProviderStateMixin  {


  late TabController _tabController;

  final RxInt _totalAnnualLeaves = 10.obs;
  final RxInt _totalPaternityLeaves = 0.obs;
  final RxInt _totalMaternityLeaves = 30.obs;
  final RxInt _totalHolidayLeaves = 0.obs;
  final RxInt _usedAnnualLeaves = 0.obs;
  final RxInt _usedPaternityLeaves = 0.obs;
  final RxInt _usedMaternityLeaves = 0.obs;
  final RxInt _remainingPaternityLeaveBalance = 0.obs;
  final RxInt _remainingMaternityLeaveBalance = 0.obs;
  final RxInt _remainingAnnualLeaveBalance = 0.obs;
  RxInt expandedPanelIndex = (-1).obs;
  String googleApiKey2 = "AIzaSyBZMjfaZ7Cpd_wHjyxfx3tVKql4x4fS2KE";

  final _markedDates = <DateTime>[].obs;
  final _nigerianHolidays = <DateTime, String>{}.obs;

  final RxInt _pendingHolidayLeavesCount = 0.obs; // New RxInt for pending holiday leaves
  final RxInt _approvedHolidayLeavesCount = 0.obs; // New RxInt for approved holiday leaves


  RxDouble lati = 0.0.obs;
  RxDouble longi = 0.0.obs;
  RxString administrativeArea = "".obs;
  RxString location = "".obs;
  RxBool isGpsEnabled = false.obs;
  RxBool isInternetConnected = false.obs;
  locationPkg.Location locationService = locationPkg.Location();
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
  var isCircularProgressBarOn = true.obs;
  RxBool isLocationTurnedOn = false.obs;
  RxBool isAlertSet = false.obs;
  RxBool isAlertSet2 = false.obs;
  Rx<LocationPermission> isLocationPermissionGranted =
      LocationPermission.denied.obs;
  late StreamSubscription<LocationData> subscription; // Initialize subscription here
  RxString currentStateDisplay =
      "".obs;

  String _selectedLeaveType = 'Annual';
  RemainingLeaveModel? _remainingLeaves1;
  final TextEditingController _reasonController = TextEditingController();
  PickerDateRange? _selectedDateRange;
  final List<LeaveRequestModel> _leaveRequests1 = [];
  final bool _firebaseInitialized1 = false;
  // Use RxString for selectedSupervisor to observe changes
  final RxString _selectedSupervisor = RxString('');
  String? _selectedSupervisorEmail;
  BioModel? _bioInfo1;
  LeaveRequestModel? _leaveRequestInfo;
  String? selectedProjectName;
  String? selectedBioFirstName;
  String? selectedBioLastName;
  String? selectedBioDepartment;
  String? selectedBioState;
  String? selectedBioDesignation;
  String? selectedBioLocation;
  String? selectedBioStaffCategory;
  String? selectedBioEmail;
  String? selectedBioPhone;
  String? selectedGender;
  String? selectedMaritalStatus;
  String? selectedFirebaseId;
  String? facilitySupervisor;
  String? caritasSupervisor;
  DateTime? selectedDate;
  String? staffSignatureLink;
  BioModel? bioData; // Make bioData nullable// Currently selected project
  // Remove duplicated state variable, use RxString _selectedSupervisor
  String? selectedFacilitySupervisor; // State variable to store the selected supervisor

  final _leaveRequests = <LeaveRequestModel>[].obs;
  final _remainingLeaves = Rxn<RemainingLeaveModel>();
  final _bioInfo = Rxn<BioModel>();
  final _firebaseInitialized = false.obs;
  List<String> attachments = [];
  List<GeofenceModel> cachedGeofences = [];
  bool isHTML = false;
  String? _currentUserId;


  @override
  void initState() {
    super.initState();
    subscription = const Stream<LocationData>.empty().listen((_) {}); // Initialize with an empty stream

    _loadBioData();
    _loadAttendanceDates();
    _loadNigerianHolidays();
    _initFirebase().then((_) => _init()).then((_) {
      _startLocationService(); // Start location service after Firebase and BioData are initialized
      getCurrentLocation();
      _getUserLocation(); // Get initial location
      _updateLocation();
    });
    _tabController = TabController(length: 2, vsync: this);

  }


  @override
  void dispose() {
    _tabController.dispose();
    subscription.cancel();
    super.dispose();
  }

  Future<void> _loadAttendanceDates() async {
    print("_loadAttendanceDates here");
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      _currentUserId = user.uid;

      final attendanceCollection = FirebaseFirestore.instance
          .collection('Staff')
          .doc(_currentUserId)
          .collection('Record');

      final querySnapshot = await attendanceCollection.get();
      final markedDates = <DateTime>[];

      for (var doc in querySnapshot.docs) {
        final dateStr = doc.id; // Document ID is the date string
        try {
          final date = DateFormat('dd-MMMM-yyyy').parse(dateStr);
          markedDates.add(date);
        } catch (e) {
          print("Error parsing date: $dateStr, error: $e");
        }
      }
      _markedDates.assignAll(markedDates.toSet().toList()); // Ensure unique dates and update observable list
      print("_markedDates == $_markedDates");
    } catch (e) {
      print("Error loading attendance dates from Firebase: $e");
    }
  }


  Future<void> _loadNigerianHolidays() async {
    _nigerianHolidays.addAll({
      DateTime(2024, 1, 1): "New Year's",
      DateTime(2024, 4, 19): "Good Friday",
      DateTime(2024, 4, 22): "Easter Monday",
      DateTime(2024, 5, 1): "Worker's Day",
    });
  }


  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp();
      _firebaseInitialized.value = true;
    } catch (e) {
      print("Firebase initialization error: $e");
    }
  }

  Future<void> _updateHolidayLeaveCounts() async {
    int pendingCount = 0;
    int approvedCount = 0;

    for (var leaveRequest in _leaveRequests) {
      if (leaveRequest.type == 'Holiday') {
        if (leaveRequest.status == 'Pending') {
          pendingCount++;
        } else if (leaveRequest.status == 'Approved') {
          approvedCount++;
        }
      }
    }
    _pendingHolidayLeavesCount.value = pendingCount; // Update RxInt for pending count
    _approvedHolidayLeavesCount.value = approvedCount; // Update RxInt for approved count
  }



  Future<void> _init() async {
    if (_firebaseInitialized.value == false) return;
    print("Starting _init");

    try {


      _currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (_currentUserId == null) {
        throw Exception("User not logged in");
      }

      await _fetchBioInfo();

      ever(_bioInfo, (_) async {
        if (_bioInfo.value != null) {
          _remainingLeaves.value = await _initializeRemainingLeaveModel();
          await syncUnsyncedLeaveRequests();
          _checkAndUpdateLeaveStatus();
          _calculateAndStoreRemainingLeave();
          _updateHolidayLeaveCounts(); // Call the new function here
        }
      });

      _bioInfo.value = await _fetchBioInfo();
      _leaveRequests.bindStream(_streamLeaveRequests());

      _updateRemainingLeavesAndDate();


      print("Finished _init");
    } catch (e) {
      print("Error during _init: $e");
    }
  }

  Stream<List<LeaveRequestModel>> _streamLeaveRequests() async* {
    if (_currentUserId == null) yield [];

    final leaveRequestCollection = FirebaseFirestore.instance
        .collection('Staff')
        .doc(_currentUserId)
        .collection('Leave Request');

    yield* leaveRequestCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => LeaveRequestModel.fromJson(doc.data())).toList();
    });
  }


  Future<BioModel?> _fetchBioInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final bioDoc = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(user.uid)
          .get();

      if (bioDoc.exists && bioDoc.data() != null) {
        return BioModel.fromJson(bioDoc.data()!);
      } else {
        return null;
      }
    } catch (e) {
      print("Error fetching BioInfo from Firebase: $e");
      return null;
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
      isHTML: true,
    );

    try {
      await FlutterEmailSender.send(email);
      print('Email sent successfully (user interaction required)');
    } catch (error) {
      print('Error sending email: $error');
    }
  }


  String _formatLeaveRequestEmail2(LeaveRequestModel leaveRequest) {
    String tableStyle = """
    border-collapse: separate;
    border-spacing: 10px;
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

    PermissionStatus permission = await locationService.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await locationService.requestPermission();
      if (permission != PermissionStatus.granted) {
        return;
      }
    }

    subscription = locationService.onLocationChanged.listen((LocationData locationData) async { // Assign subscription here
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


      _updateLocation();
    }, onError: (e) {
      print("_getLocation2 Error:$e");
      _handleLocationError();
    });


  }

  Future<void> _handleLocationError() async {
    print("There is nooooooo internet to get location data or location error occurred");
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: geolocator.LocationAccuracy.best,
      forceAndroidLocationManager: true,
    );

    Position? position1 = await Geolocator.getLastKnownPosition();

    lati.value = position.latitude;
    longi.value = position.longitude;
    print("locationData.latitude == ${position.latitude}");
    _updateLocation();
  }


  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _getUserLocation1() async {
    print("Fetching user location...");

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );

      print('Latitude: ${position.latitude}, Longitude: ${position.longitude}');
      lati.value = position.latitude;
      longi.value = position.longitude;

      // Get location details using reverse geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      print("placemarks ==$placemarks");

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        location.value =
        "${placemark.street}, ${placemark.subLocality}, ${placemark.subAdministrativeArea}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.postalCode}, ${placemark.country}";
        administrativeArea.value = placemark.administrativeArea ?? '';

        print("Location details: ${location.value}");
        print("Administrative area: ${administrativeArea.value}");
      } else {
        location.value = "Location not found";
        administrativeArea.value = "";
        await _updateLocationUsingGeofencing2(position.latitude, position.longitude);
      }

      // Check if the user is inside any geofenced office location
      if (administrativeArea.value.isNotEmpty) {
        List<GeofenceModel> offices = [];
        final locationsSnapshot = await FirebaseFirestore.instance
            .collection('Locations')
            .where('state', isEqualTo: administrativeArea.value)
            .get();

        offices = locationsSnapshot.docs.map((doc) => LocationModel.fromJson(doc.data())).map((locationModel) => GeofenceModel(
          name: locationModel.locationName ?? '',
          latitude: locationModel.latitude ?? 0.0,
          longitude: locationModel.longitude ?? 0.0,
          radius: locationModel.radius?.toDouble() ?? 0.0,
          category: locationModel.category ?? '',
          stateName: locationModel.state ?? '',
        )).toList();

        print("Fetched geofence locations: $offices");

        isInsideAnyGeofence.value = false;
        for (GeofenceModel office in offices) {
          double distance = GeoUtils.haversine(
            position.latitude,
            position.longitude,
            office.latitude,
            office.longitude,
          );

          if (distance <= office.radius) {
            print('Entered office: ${office.name}');
            location.value = office.name;
            isInsideAnyGeofence.value = true;
            break;
          }
        }

        if (!isInsideAnyGeofence.value) {
          print("User is not inside any geofenced location. Using reverse geocoding.");
          List<Placemark> placemark = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          location.value =
          "${placemark.first.street}, ${placemark.first.subLocality}, ${placemark.first.subAdministrativeArea}, ${placemark.first.locality}, ${placemark.first.administrativeArea}, ${placemark.first.postalCode}, ${placemark.first.country}";
        }
      } else {
        if (location.value.isNotEmpty) {
          await _updateLocationUsingGeofencing();
        } else {
          List<Placemark> placemark = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          location.value =
          "${placemark.first.street}, ${placemark.first.subLocality}, ${placemark.first.subAdministrativeArea}, ${placemark.first.locality}, ${placemark.first.administrativeArea}, ${placemark.first.postalCode}, ${placemark.first.country}";
          print("Could not determine administrative area. Using fallback location.");
        }
      }
    } catch (e) {
      print("Error getting location: $e");

      if (lati.value != 0.0 && administrativeArea.value.isEmpty) {
        await _updateLocationUsingGeofencing();
      } else if (lati.value == 0.0 && administrativeArea.value.isEmpty) {
        Timer(const Duration(seconds: 10), () async {
          if (lati.value == 0.0 && longi.value == 0.0) {
            print("Location not obtained within 10 seconds. Using default location.");
            _getLocationDetailsFromLocationModel();
          }
        });
      } else {
        dev.log('Error getting location: $e');
        Fluttertoast.showToast(
          msg: "Error getting location: $e",
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

  Future<void> _getUserLocation() async {
    print("Fetching user location...");

    try {
      // Get user's current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );

      print('Latitude: \${position.latitude}, Longitude: \${position.longitude}');
      lati.value = position.latitude;
      longi.value = position.longitude;
      accuracy.value = position.accuracy;
      altitude.value = position.altitude;
      speed.value = position.speed;
      speedAccuracy.value = position.speedAccuracy;
      heading.value = position.heading;
      time.value = position.timestamp.millisecondsSinceEpoch.toDouble();
      isMock.value = position.isMocked;

      // Reverse geocoding using Google Maps API
      String apiKey = "AIzaSyDrEiP6HeIv5C2_Fo5szYDkpkYGdoOvcPg"; // Replace with your API key
      String url =
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        print("Geocoding API error: \${response.body}");
        location.value = "Geocoding failed";
        return;
      }

      var data = json.decode(response.body);
      String state = _extractState(data);
      String location1 = _extractLocation(data);
      print("location1===$location1");
      if (state.isEmpty) {
        location.value = location1;
        return;
      }

      print("Extracted State: \$state");
      administrativeArea.value = state;

      List<GeofenceModel> offices = await _fetchGeofenceLocations(state);
      if (offices.isEmpty) {
        location.value = location1;
        return;
      }

      _checkGeofence(offices, position.latitude, position.longitude,location1);
    } catch (e) {
      print("Error getting location: \$e");
      Fluttertoast.showToast(
        msg: "Error getting location: \$e",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  String _extractState(Map<String, dynamic> data) {
    List<dynamic> addressComponents = data["results"][0]["address_components"];
    print("addressComponents===${data["results"][0]}");
    for (var component in addressComponents) {
      if (component["types"].contains("administrative_area_level_1")) {
        return component["long_name"];
      }
    }
    return "";
  }


  String _extractLocation(Map<String, dynamic> data) {
    if (data['results'].isNotEmpty) {
      return data['results'][0]['formatted_address'] ?? "Address not found";
    }
    return "";
  }

  Future<List<GeofenceModel>> _fetchGeofenceLocations(String state) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('Location').doc(state).collection(state).get();
      return snapshot.docs.map((doc) => GeofenceModel.fromFirestore(doc.data(), state)).toList();
    } catch (e) {
      print("Error fetching geofence locations: \$e");
      return [];
    }
  }

  void _checkGeofence(List<GeofenceModel> offices, double latitude, double longitude,String location1) {
    isInsideAnyGeofence.value = false;

    for (GeofenceModel office in offices) {
      double distance = GeoUtils.haversine(latitude, longitude, office.latitude, office.longitude);
      if (distance <= office.radius) {
        print('Entered office: \${office.name}');
        location.value = office.name;
        isInsideAnyGeofence.value = true;
        isCircularProgressBarOn.value = false;
        return;
      }
    }

    location.value = location1;
    isCircularProgressBarOn.value = false;
  }




  Future<void> _updateLocation1() async {
    try{

      List<Placemark> placemarks = await placemarkFromCoordinates(
        lati.value,
        longi.value,
      );


      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        location.value =
        "${placemark.street},${placemark.subLocality},${placemark.subAdministrativeArea},${placemark.locality},${placemark.administrativeArea},${placemark.postalCode},${placemark.country}";
        administrativeArea.value = placemark.administrativeArea!;

        print("location.valuesssss==${location.value}");
        print("placemark.administrativeArea==${placemark.administrativeArea}");
        print("administrativeArea.value ==${administrativeArea.value}");

      } else {
        location.value = "Location not found";
        administrativeArea.value = "";
      }


      if (administrativeArea.value != '') {

        List<GeofenceModel> offices = [];
        final locationsSnapshot = await FirebaseFirestore.instance.collection('Locations').where('state', isEqualTo: administrativeArea.value).get();
        offices = locationsSnapshot.docs.map((doc) => LocationModel.fromJson(doc.data())).map((locationModel) => GeofenceModel(
          name: locationModel.locationName ?? '',
          latitude: locationModel.latitude ?? 0.0,
          longitude: locationModel.longitude ?? 0.0,
          radius: locationModel.radius?.toDouble() ?? 0.0, category: locationModel.category ?? '', stateName: locationModel.state ?? '',
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
            isCircularProgressBarOn.value = false;
            break;
          }
        }

        if (!isInsideAnyGeofence.value) {
          List<Placemark> placemark = await placemarkFromCoordinates(
              lati.value, longi.value);

          location.value =
          "${placemark[0].street},${placemark[0].subLocality},${placemark[0].subAdministrativeArea},${placemark[0].locality},${placemark[0].administrativeArea},${placemark[0].postalCode},${placemark[0].country}";

          print("Location from map === ${location.value}");
          isCircularProgressBarOn.value = false;
        }
      }
      else if(administrativeArea.value == '' && location.value != 0.0){
        await _updateLocationUsingGeofencing();
        print("_updateLocationUsingGeofencing2 here");
      } else {
        List<Placemark> placemark = await placemarkFromCoordinates(
            lati.value, longi.value);

        location.value =
        "${placemark[0].street},${placemark[0].subLocality},${placemark[0].subAdministrativeArea},${placemark[0].locality},${placemark[0].administrativeArea},${placemark[0].postalCode},${placemark[0].country}";

        print("Unable to get administrative area. Using default location.");
        isCircularProgressBarOn.value = false;
      }

    }catch(e){
      if(lati.value != 0.0 && administrativeArea.value == ''){
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
        dev.log("$e");
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

  Future<String?> _getUserState() async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        return userDoc["state"] as String?;
      }
    } catch (e) {
      dev.log("Error fetching user state: $e");
    }
    return null;
  }

  Future<String> _determineGeofenceLocation(double latitude, double longitude) async {
    String geofenceName = "";
    String? userState = await _getUserState();

    for (GeofenceModel geofence in cachedGeofences) {
      double distance = GeoUtils.haversine(latitude, longitude, geofence.latitude, geofence.longitude);
      if (distance <= geofence.radius) {
        currentStateDisplay.value = (geofence.stateName == userState) ? geofence.name : geofence.stateName;
        return geofence.name;
      }
    }

    currentStateDisplay.value = userState ?? (administrativeArea.value.isNotEmpty ? administrativeArea.value : "State Unknown");
    return geofenceName;
  }

  String? getUserId() {
    print("Current UUID === ${FirebaseAuth.instance.currentUser?.uid}");
    return FirebaseAuth.instance.currentUser?.uid;
  }


  Future<void> _updateLocation() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        lati.value,
        longi.value,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        location.value =
        "${placemark.street},${placemark.subLocality},${placemark.subAdministrativeArea},${placemark.locality},${placemark.administrativeArea},${placemark.postalCode},${placemark.country}";
        administrativeArea.value = placemark.administrativeArea!;
      } else {
        location.value = "Location not found";
        administrativeArea.value = "";
      }

      String geofenceLocationName =
      await _determineGeofenceLocation(lati.value, longi.value);
      if (geofenceLocationName.isNotEmpty) {
        location.value = geofenceLocationName;
        isInsideAnyGeofence.value = true;
      } else {
        // Use placemarker address if not in geofence
        location.value = location.value.isNotEmpty && location.value != "Location not found"
            ? location.value
            : "Location not found"; // Fallback if placemarker also failed
        isInsideAnyGeofence.value = false;
        // currentStateDisplay.value = administrativeArea.value.isNotEmpty
        //     ? administrativeArea.value
        //     : "State Unknown";
      }
      isCircularProgressBarOn.value = false;
    } catch (e) {
      // currentStateDisplay.value = administrativeArea.value.isNotEmpty
      //     ? administrativeArea.value
      //     : "State Unknown";
      if (lati.value != 0.0 && administrativeArea.value == '') {
        await _updateLocationUsingGeofencing();
      } else if (lati.value == 0.0 && administrativeArea.value == '') {
        print("Location not obtained within 10 seconds.");
        Timer(const Duration(seconds: 10), () {
          if (lati.value == 0.0 && longi.value == 0.0) {
            print("Location not obtained within 10 seconds. Using default.");
            _getLocationDetailsFromLocationModel();
          }
        });
      } else {
        dev.log("$e");
        Fluttertoast.showToast(
          msg: "Error: $e",
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


  Future<void> _updateLocationUsingGeofencing() async {

    if (lati.value != 0.0 && location.value == "") {

      List<GeofenceModel> geofences = [];
      final locationsSnapshot = await FirebaseFirestore.instance.collection('Locations').get();
      geofences = locationsSnapshot.docs.map((doc) => LocationModel.fromJson(doc.data())).map((locationModel) => GeofenceModel(
        name: locationModel.locationName ?? '',
        latitude: locationModel.latitude ?? 0.0,
        longitude: locationModel.longitude ?? 0.0,
        radius: locationModel.radius?.toDouble() ?? 0.0, category: locationModel.category ?? '', stateName: locationModel.state ?? '',
      )).toList();


      for (GeofenceModel geofence in geofences) {
        double distance = GeoUtils.haversine(
            lati.value, longi.value, geofence.latitude, geofence.longitude);

        if (distance <= geofence.radius) {

          print('Using geofence location: ${geofence.name}');
          location.value = geofence.name;
          isInsideAnyGeofence.value = true;
          isCircularProgressBarOn.value = false;
          break;
        }
      }


    }
  }

  Future<void> _updateLocationUsingGeofencing2(double latitde, double longitde) async {

    print("_updateLocationUsingGeofencing2 is here");


    List<GeofenceModel> geofences = [];
    final locationsSnapshot = await FirebaseFirestore.instance.collection('Locations').get();
    geofences = locationsSnapshot.docs.map((doc) => LocationModel.fromJson(doc.data())).map((locationModel) => GeofenceModel(
      name: locationModel.locationName ?? '',
      latitude: locationModel.latitude ?? 0.0,
      longitude: locationModel.longitude ?? 0.0,
      radius: locationModel.radius?.toDouble() ?? 0.0,
      category: locationModel.category ?? '', stateName: locationModel.state ?? '',

    )).toList();


    for (GeofenceModel geofence in geofences) {
      double distance = GeoUtils.haversine(
          latitde, longitde, geofence.latitude, geofence.longitude);

      if (distance <= geofence.radius) {

        print('Using geofence location: ${geofence.name}');
        location.value = geofence.name;
        isInsideAnyGeofence.value = true;
        isCircularProgressBarOn.value = false;
        break;
      }
    }

  }

  Future<void> _getLocationDetailsFromLocationModel() async {

    final bioModel = _bioInfo.value;
    final locationFromBioModel = bioModel?.location;
    print("locationFromBioModel === $locationFromBioModel");

    if (locationFromBioModel == null) {
      print("Location not found in BioModel");
      return;
    }


    final locationDoc = await FirebaseFirestore.instance
        .collection('Locations')
        .where('locationName', isEqualTo: locationFromBioModel)
        .get();

    if (locationDoc.docs.isEmpty) {
      print("No matching location found in LocationModel");
      return;
    }

    final locationModel = LocationModel.fromJson(locationDoc.docs.first.data());


    lati.value = locationModel.latitude ?? 0.0;
    longi.value = locationModel.longitude ?? 0.0;
    administrativeArea.value = locationModel.state ?? "";
    location.value = locationModel.locationName ?? "";
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
    LocationPermission permission = await Geolocator.checkPermission();
    isLocationPermissionGranted.value = permission;


    if (isLocationPermissionGranted.value == LocationPermission.denied ||
        isLocationPermissionGranted.value == LocationPermission.deniedForever) {
      showDialogBox2();
      isAlertSet2.value = true;
    }
  }

  Future<void> checkInternetConnection() async {
    // isInternetConnected.value = await InternetConnectionChecker.instance.hasConnection;
    if (!isInternetConnected.value) {
      Fluttertoast.showToast(
        msg:
        "No Internet Connectivity Detected.",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  showDialogBox() => showCupertinoDialog<String>(
    context: Get.context!,
    builder: (BuildContext context) => CupertinoAlertDialog(
      title: const Text("Location Turned Off"),
      content: const Text("Please turn on your location to ClockIn and Out"),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            Get.back();
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
    context: Get.context!,
    builder: (BuildContext builderContext) => CupertinoAlertDialog(
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            Get.back();
            isAlertSet2.value = false;
            isLocationPermissionGranted.value =
            await LocationService().getPermissionStatus();
            if (isLocationPermissionGranted.value ==
                LocationPermission.denied ||
                isLocationPermissionGranted.value ==
                    LocationPermission.deniedForever) {
              showDialogBox2();
            }
          },
          child: const Text("OK"),
        ),
      ],
    ),
  );



  Future<RemainingLeaveModel?> _initializeRemainingLeaveModel() async {
    try {
      // Get current user's UUID
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No logged-in user found.");
        return null;
      }

      String userId = user.uid;
      print("Current user ID: $userId");

      // Reference to the user's document in the "Staff" collection
      DocumentReference staffDocRef = FirebaseFirestore.instance.collection('Staff').doc(userId);

      // Fetch user data
      DocumentSnapshot staffDoc = await staffDocRef.get();

      // Check if document exists and fetch data
      if (!staffDoc.exists || staffDoc.data() == null) {
        print("User document does not exist in Staff collection.");
        return null;
      }

      Map<String, dynamic> staffData = staffDoc.data() as Map<String, dynamic>;

      // Ensure gender and maritalStatus exist
      String gender = staffData['gender'] ?? "Male";
      String maritalStatus = staffData['maritalStatus'] ?? "Single";

      // If missing, update Firestore
      if (!staffData.containsKey('gender') || !staffData.containsKey('maritalStatus')) {
        await staffDocRef.update({
          'gender': gender,
          'maritalStatus': maritalStatus,
        });
        print("Updated missing fields: gender = $gender, maritalStatus = $maritalStatus");
      }

      // Reference to RemainingLeave document
      DocumentReference remainingLeaveRef = staffDocRef.collection('RemainingLeave').doc('remainingLeaveDoc');
      DocumentSnapshot remainingLeaveDoc = await remainingLeaveRef.get();

      RemainingLeaveModel? remainingLeave;

      if (remainingLeaveDoc.exists && remainingLeaveDoc.data() != null) {
        remainingLeave = RemainingLeaveModel.fromJson(remainingLeaveDoc.data() as Map<String, dynamic>);
      } else {
        // Document does not exist, create and initialize it
        remainingLeave = RemainingLeaveModel(
          staffId: userId,
          annualLeaveBalance: _totalAnnualLeaves.value,
          holidayLeaveBalance: _totalHolidayLeaves.value,
          dateUpdated: DateTime.now(),
          paternityLeaveBalance: (gender == 'Male' && maritalStatus == 'Married') ? _totalPaternityLeaves.value : 0,
          maternityLeaveBalance: (gender == 'Female') ? _totalMaternityLeaves.value : 0,
        );



        await remainingLeaveRef.set(remainingLeave.toJson());
        print("Created new remaining leave document for user.");
      }

      // Update leave balances
      _usedPaternityLeaves.value = _totalPaternityLeaves.value - (remainingLeave.paternityLeaveBalance ?? 0);
      _usedMaternityLeaves.value = _totalMaternityLeaves.value - (remainingLeave.maternityLeaveBalance ?? 0);
      _usedAnnualLeaves.value = _totalAnnualLeaves.value - (remainingLeave.annualLeaveBalance ?? 0);
      _remainingPaternityLeaveBalance.value = remainingLeave.paternityLeaveBalance ?? 0;
      _remainingMaternityLeaveBalance.value = remainingLeave.maternityLeaveBalance ?? 0;
      _remainingAnnualLeaveBalance.value = remainingLeave.annualLeaveBalance ?? 0;

      return remainingLeave;
    } catch (e) {
      print("Error initializing remaining leave model: $e");
      return null;
    }
  }



  Future<void> _calculateAndStoreRemainingLeave() async {
    if (_currentUserId == null) return;

    final now = DateTime.now();
    final lastYearOctober = DateTime(now.year - 1, 10, 1);
    final currentYearSeptember = DateTime(now.year, 9, 30);

    DateTime startDate = lastYearOctober;
    DateTime endDate = currentYearSeptember;

    if (now.isBefore(currentYearSeptember)) {
      endDate = currentYearSeptember;
    } else {
      startDate = currentYearSeptember.add(const Duration(days: 1));
      endDate = DateTime(now.year + 1, 9, 30);
    }


    final attendanceCollection = FirebaseFirestore.instance
        .collection('Staff')
        .doc(_currentUserId)
        .collection('Record');

    final querySnapshot = await attendanceCollection
        .where('durationWorked', isEqualTo: 'Annual Leave')
        .where('date', isGreaterThanOrEqualTo: DateFormat('dd-MMMM-yyyy').format(startDate))
        .where('date', isLessThanOrEqualTo: DateFormat('dd-MMMM-yyyy').format(endDate))
        .get();

    int annualLeaveDays = 0;
    for (var doc in querySnapshot.docs) {
      final recordDate = DateFormat('dd-MMMM-yyyy').parse(doc['date'] as String);
      if (recordDate.weekday != DateTime.saturday && recordDate.weekday != DateTime.sunday) {
        annualLeaveDays++;
      }
    }

    final remainingLeaveDocRef = FirebaseFirestore.instance
        .collection('Staff')
        .doc(_currentUserId)
        .collection('RemainingLeave')
        .doc('remainingLeaveDoc');

    final docSnapshot = await remainingLeaveDocRef.get();
    if (docSnapshot.exists) {
      RemainingLeaveModel updatedRemainingLeave = RemainingLeaveModel.fromJson(docSnapshot.data()!);
      updatedRemainingLeave.annualLeaveBalance = (_totalAnnualLeaves.value - annualLeaveDays).clamp(0, _totalAnnualLeaves.value);
      await remainingLeaveDocRef.set(updatedRemainingLeave.toJson(), SetOptions(merge: true));
      _remainingLeaves.value = updatedRemainingLeave;
      _remainingAnnualLeaveBalance.value = updatedRemainingLeave.annualLeaveBalance ?? 0;
    }
  }



  Future<int> _calculateInitialAnnualLeave() async {
    return _totalAnnualLeaves.value; // Initial annual leave is just the total allocated.
  }

  Future<void> _insertInitialAnnualLeave() async {
    // No need to insert initial annual leave records in Firestore as it's calculated dynamically.
  }

  Future<void> _insertInitialHolidayLeave() async {
    // No need to insert initial holiday leave records in Firestore.
  }


  Future<int> _calculateInitialHoliday() async {
    return 0; // Initial holiday leave is 0
  }


  Future<void> syncUnsyncedLeaveRequests() async {

    print("syncUnsyncedLeaveRequests called - Firestore is online, syncing is mostly automatic.");
  }


  Future<void> _syncLeaveRequestToFirebase(LeaveRequestModel leaveRequest) async {
    try {



      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final staffCollection = FirebaseFirestore.instance.collection('Staff').doc(user.uid);
        final leaveRequestCollection = staffCollection.collection('Leave Request');

        final leaveRequestId = leaveRequest.leaveRequestId;
        if (leaveRequestId != null) {
          await leaveRequestCollection.doc(leaveRequestId).set({
            ...leaveRequest.toJson(),
            'leaveRequestId': leaveRequestId,
          });

          print('Leave request synced successfully: $leaveRequestId');
        }
      }
    } catch (e) {
      print('Error syncing leave request to Firebase: $e');
    }
  }




  Future<LeaveRequestModel> _getOrCreateLeaveRequestModel(String userId) async {

    return LeaveRequestModel()
      ..staffId = userId
      ..endDate = DateTime.now()
      ..startDate = DateTime.now()
      ..leaveRequestId = const Uuid().v4()
      ..reason = "Annual Leave"
      ..selectedSupervisor = "Super User"
      ..selectedSupervisorEmail = "superuser@ccfng.org"
      ..type = "Annual";
  }

  Future<void> _loadBioData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid; // Get the user UUID

    if (userId == null) {
      print("User is not authenticated.");
      return;
    }

    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        Map<String, dynamic> data = docSnapshot.data()!;
        setState(() {
          selectedBioFirstName = data['firstName'] ?? '';
          selectedBioLastName = data['lastName'] ?? '';
          selectedBioDepartment = data['department'] ?? '';
          selectedBioState = data['state'] ?? '';
          selectedBioDesignation = data['designation'] ?? '';
          selectedBioLocation = data['location'] ?? '';
          selectedBioStaffCategory = data['staffCategory'] ?? '';
          selectedGender = data['gender'] ?? '';
          selectedMaritalStatus = data['maritalStatus'] ?? '';
          selectedBioEmail = data['emailAddress'] ?? '';
          selectedBioPhone = data['mobile'] ?? '';
          staffSignatureLink = data['signatureLink'] ?? '';
          selectedFirebaseId = userId; // Store the Firebase UUID

        });


      } else {
        print("No bio data found for user ID: $userId");
      }
    } catch (e) {
      print("Error loading bio data: $e");
    }
  }

  // Rewritten buildSupervisorDropdown to use Obx and remove StatefulWidget
  Widget buildSupervisorDropdown() {
    return StreamBuilder<List<String?>>(
      stream: (selectedBioDepartment != null && selectedBioState != null)
          ? getSupervisorsFromFirestore(selectedBioDepartment!, selectedBioState!)
          : Stream.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          List<String?> supervisorNames = snapshot.data ?? [];
          print("Selected Supervisor before Dropdown: ${_selectedSupervisor.value}");

          return SizedBox(
              width: double.infinity,
              child: Obx(() => DropdownButton<String?>( // Wrapped DropdownButton with Obx
                isExpanded: true,
                value: _selectedSupervisor.value.isNotEmpty ? _selectedSupervisor.value : null,
                items: supervisorNames.map((supervisorName) {
                  return DropdownMenuItem<String?>(
                    value: supervisorName,
                    child: Text(
                      supervisorName ?? 'No Supervisor',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) async {
                  if (newValue != null) {
                    _selectedSupervisor.value = newValue;
                    print("Selected Caritas Supervisor: $_selectedSupervisor.value");

                    String? supervisorEmail = await getSupervisorEmailFromFirestore(selectedBioState!, newValue);
                    _selectedSupervisorEmail = supervisorEmail;
                    print("Caritas Supervisor Email: $_selectedSupervisorEmail");

                  } else {
                    _selectedSupervisor.value = '';
                    _selectedSupervisorEmail = null;
                  }
                },
                hint: const Text('Select Supervisor'),
              ),)
          );
        }
      },
    );
  }


  Stream<List<String?>> getSupervisorsFromFirestore(String department, String state) {
    return FirebaseFirestore.instance
        .collection('Supervisors')
        .doc(state)
        .collection(state)
        .where('department', isEqualTo: department)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => doc['supervisor'] as String?).toList());
  }

  Future<String?> getSupervisorEmailFromFirestore(String state, String supervisorName) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
          .collection('Supervisors')
          .doc(state)
          .collection(state)
          .doc(supervisorName)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final emailField = data['email'];

        // If emailField is a list and not empty, return the first email
        if (emailField is List && emailField.isNotEmpty) {
          return emailField[0] as String;
        }
        // If emailField is already a String, return it directly
        else if (emailField is String) {
          return emailField;
        }
      }
      return null;
    } catch (e) {
      print("Error fetching supervisor email: $e");
      return null;
    }
  }


  Future<void> _getLeaveData() async {
    print("Starting getLeaveData");

    print("Finished getLeaveData");
    await _checkAndUpdateLeaveStatus();
  }


  Future<void> _deleteLeaveRequestFromFirebase(LeaveRequestModel leaveRequest) async {
    print("leaveRequest.staffId == ${leaveRequest.staffId}");
    print("leaveRequest.leaveRequestId == ${leaveRequest.leaveRequestId}");
    try {
      await FirebaseFirestore.instance
          .collection('Staff')
          .doc(leaveRequest.staffId)
          .collection('Leave Request')
          .doc(leaveRequest.leaveRequestId)
          .delete();
      print("Leave request deleted from Firebase: ${leaveRequest.leaveRequestId}");
    } catch (e) {
      print("Error deleting leave request from Firebase: $e");
      throw e; // Re-throw the exception to be caught in the dialog
    }
  }



  Widget _buildLeaveSummaryItem(String leaveType, int used, int total, double fontSizeFactor, double paddingFactor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0 * paddingFactor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              Text("$leaveType Leave:", style: TextStyle(fontSize: 16 * fontSizeFactor, fontWeight: FontWeight.w500)),

              Text("$used Used, ${total - used} Remaining", style: TextStyle(fontSize: 14 * fontSizeFactor)),
            ],
          ),
          LinearPercentIndicator(
            lineHeight: 8 * fontSizeFactor,
            percent: total > 0 ? used.toDouble() / total : 0,
            progressColor: Colors.green,
            backgroundColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveSummaryItem1(String leaveType, int approvedCount, int pendingCount, double fontSizeFactor, double paddingFactor) { // Modified function
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0 * paddingFactor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("No of $leaveType(s) observed:", style: TextStyle(fontSize: 16 * fontSizeFactor, fontWeight: FontWeight.w500)),
              Text("$approvedCount Approved", style: TextStyle(fontSize: 14 * fontSizeFactor)) // Display approved count
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("No of $leaveType(s) pending approvals:", style: TextStyle(fontSize: 16 * fontSizeFactor, fontWeight: FontWeight.w500)),
              Text("$pendingCount Pending", style: TextStyle(fontSize: 14 * fontSizeFactor)) // Display pending count
            ],
          ),


        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final shortestSide = MediaQuery.of(context).size.shortestSide;

    double fontSizeFactor = max(0.8, min(1.2, shortestSide / 600));
    double paddingFactor = max(0.8, min(1.2, shortestSide / 600));
    double marginFactor = max(0.8, min(1.2, shortestSide / 600));
    double iconSizeFactor = max(0.8, min(1.2, shortestSide / 600));
    double headerHeightFactor = max(0.8, min(1.2, shortestSide / 600));
    double cardHeightFactor = max(0.8, min(1.2, screenHeight / 800));
    double buttonPaddingFactor = max(0.8, min(1.2, shortestSide / 600));
    double circularIndicatorRadiusFactor = max(0.8, min(1.2, shortestSide / 600));
    double circularIndicatorLineWidthFactor = max(0.8, min(1.2, shortestSide / 600));

    return Obx(() {
      if (_firebaseInitialized.value == false || _bioInfo.value == null || _remainingLeaves.value == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      } else {
        return _buildMainScaffold(fontSizeFactor, paddingFactor, marginFactor, iconSizeFactor, headerHeightFactor, cardHeightFactor, buttonPaddingFactor, circularIndicatorRadiusFactor, circularIndicatorLineWidthFactor);
      }
    });
  }



  Widget _buildMainScaffold(double fontSizeFactor, double paddingFactor, double marginFactor, double iconSizeFactor, double headerHeightFactor, double cardHeightFactor, double buttonPaddingFactor, double circularIndicatorRadiusFactor, double circularIndicatorLineWidthFactor) {
    List<Widget> leaveSummaryItems = [];


    leaveSummaryItems.add(
        _buildLeaveSummaryItem("Annual", _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0), _totalAnnualLeaves.value, fontSizeFactor, paddingFactor));


    if (selectedMaritalStatus == 'Married') {
      // if (_bioInfo.value?.gender == 'Male') {
      //   leaveSummaryItems.add(
      //     _buildLeaveSummaryItem("Paternity", _totalPaternityLeaves.value - (_remainingLeaves.value?.paternityLeaveBalance ?? 0), _totalPaternityLeaves.value, fontSizeFactor, paddingFactor),
      //   );
      // }
      if (selectedGender == 'Female') {
        leaveSummaryItems.add(
          _buildLeaveSummaryItem("Maternity", _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0) == _totalAnnualLeaves.value?
          _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0):_totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0), _totalMaternityLeaves.value, fontSizeFactor, paddingFactor),
        );
      }
    }
    leaveSummaryItems.add(_buildLeaveSummaryItem1("Holiday", _totalHolidayLeaves.value + (_remainingLeaves.value?.holidayLeaveBalance ?? 0), _totalHolidayLeaves.value, fontSizeFactor, paddingFactor));


    return Scaffold(

      appBar: AppBar(
        title: Text('Leave Request', style: TextStyle(color: Colors.white, fontSize: 20 * fontSizeFactor)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            colors: [Color(0xFF722F37), Color(0xFFB34A5A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),),
        ),

      ),
      drawer: drawer(context),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0 * paddingFactor),
        child: Column(
          children: [
            SizedBox(
              height: 60 * headerHeightFactor,
              width: double.infinity,
              child: HeaderWidget(100 * headerHeightFactor, false, Icons.house_rounded),
            ),

            Obx(() => Card (
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * marginFactor)),
              child: Container(
                width: double.infinity,
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
                  borderRadius: BorderRadius.circular(10 * marginFactor),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.0 * paddingFactor),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Geo-Coordinates Information:",
                        style: TextStyle(
                          fontFamily: "NexaBold",
                          fontSize: 18 * fontSizeFactor,
                          color: Colors.blueGrey,
                        ),
                      ),
                      SizedBox(height: 10 * paddingFactor),

                      IntrinsicWidth(child: Text(
                        "GPS is: ${isGpsEnabled.value ? 'On' : 'Off'}",
                        style: TextStyle(
                          fontFamily: "NexaBold",
                          fontSize: 16 * fontSizeFactor,
                        ),
                      ),),
                      SizedBox(height: 10 * paddingFactor),

                      IntrinsicWidth(child: Text(
                        "Current Latitude: ${lati.value.toStringAsFixed(
                            6)}, Current Longitude: ${longi.value.toStringAsFixed(6)}",
                        style: TextStyle(
                          fontFamily: "NexaBold",
                          fontSize: 16 * fontSizeFactor,
                        ),
                      ),),
                      SizedBox(height: 10 * paddingFactor),

                      IntrinsicWidth(child: Text(
                        "Coordinates Accuracy: ${accuracy.value}, Altitude: ${altitude.value} , Speed: ${speed.value}, Speed Accuracy: ${speedAccuracy.value}, Location Data Timestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(time.value.toInt()))} , Is Location Mocked?: ${isMock.value}",
                        style: TextStyle(
                          fontFamily: "NexaBold",
                          fontSize: 16 * fontSizeFactor,
                        ),
                      ),),
                      SizedBox(height: 10 * paddingFactor),
                      IntrinsicWidth(child:  Obx(() => Text(
                        "Current State: ${administrativeArea.value}",
                        style: TextStyle(
                          fontFamily: "NexaBold",
                          fontSize: 16 * fontSizeFactor,
                        ),
                      )),),
                      SizedBox(height: 10 * paddingFactor),


                      IntrinsicWidth(child: Obx(() => Text(
                        "Current Location: ${location.value}",
                        style: TextStyle(
                          fontFamily: "NexaBold",
                          fontSize: 16 * fontSizeFactor,
                        ),
                      ),),),

                    ],
                  ),
                ),
              ),
            ),
            ),

            SizedBox(height: 10 * paddingFactor),


            Obx(() => _buildCircularPercentIndicator(
                _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0),
                _totalAnnualLeaves.value,
                // _totalPaternityLeaves.value - (_remainingLeaves.value?.paternityLeaveBalance ?? 0),
                // _totalPaternityLeaves.value,
                _totalMaternityLeaves.value - (_remainingLeaves.value?.maternityLeaveBalance ?? 0),
                _totalMaternityLeaves.value,
                fontSizeFactor, circularIndicatorRadiusFactor, circularIndicatorLineWidthFactor
            )),
            Obx(() => Card(
              margin: EdgeInsets.only(top: 16.0 * marginFactor),
              child: Padding(
                padding: EdgeInsets.all(16.0 * paddingFactor),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Leave Summary", style: TextStyle(fontSize: 18 * fontSizeFactor, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12 * paddingFactor),


                    _buildLeaveSummaryItem(
                      "Annual", _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0), _totalAnnualLeaves.value, fontSizeFactor, paddingFactor,
                    ),


                    if (selectedGender == 'Female') ...[
                      // if (selectedGender == 'Female')
                      //   _buildLeaveSummaryItem("Maternity", _totalMaternityLeaves.value - (_remainingLeaves.value?.maternityLeaveBalance ?? 0), _totalMaternityLeaves.value, fontSizeFactor, paddingFactor)
                     // if (selectedGender == 'Female')
                     //    _buildLeaveSummaryItem("Maternity", _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0)
                     //        == _totalAnnualLeaves.value? _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0):
                     //    _totalAnnualLeaves.value - (_remainingLeaves.value?.annualLeaveBalance ?? 0), _totalMaternityLeaves.value, fontSizeFactor, paddingFactor),

                      _buildLeaveSummaryItem("Maternity",
                          _totalMaternityLeaves.value - (_remainingLeaves.value?.maternityLeaveBalance ?? 0), _totalMaternityLeaves.value, fontSizeFactor, paddingFactor),

                    ],
                    // _buildLeaveSummaryItem1("Holiday", _totalHolidayLeaves.value + (_remainingLeaves.value?.holidayLeaveBalance ?? 0), _totalHolidayLeaves.value, fontSizeFactor, paddingFactor),
                    //
                    _buildLeaveSummaryItem1("Holiday", _approvedHolidayLeavesCount.value, _pendingHolidayLeavesCount.value, fontSizeFactor, paddingFactor), // Updated here

                  ],
                ),
              ),
            )),

            Obx(() =>_buildLeaveRequestsCard(fontSizeFactor, paddingFactor, marginFactor, iconSizeFactor)),


          ],
        ),
      ),


      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showApplyLeaveBottomSheet(context, fontSizeFactor, paddingFactor, marginFactor, iconSizeFactor, buttonPaddingFactor);
        },
        label: const Text(
          "Click HERE to Request Leave",
          style: TextStyle(color: Colors.white, fontSize: 14.0),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.red,
      ),
    );


  }




  Widget _buildSummaryItem(String label, int count, Color color, double fontSizeFactor) {
    return Column(
      children: [
        Text("$count", style: TextStyle(fontSize: 18 * fontSizeFactor, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 14 * fontSizeFactor)),
      ],
    );
  }



  void _showApplyLeaveBottomSheet(BuildContext context, double fontSizeFactor, double paddingFactor, double marginFactor, double iconSizeFactor, double buttonPaddingFactor) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            List<Widget> leaveTypeButtons = [];

            //if (_bioInfo.value?.maritalStatus == 'Married') {
              // if (_bioInfo.value?.gender == 'Male') {
              //   leaveTypeButtons.addAll([
              //     _leaveTypeButton(setState, 'Paternity', 'Paternity Leave', fontSizeFactor, buttonPaddingFactor),
              //     _leaveTypeButton(setState, 'Annual', 'Annual Leave', fontSizeFactor, buttonPaddingFactor),
              //   ]);
              // } else
              if (selectedGender == 'Female') {
                leaveTypeButtons.addAll([
                  _leaveTypeButton(setState, 'Maternity', 'Maternity Leave', fontSizeFactor, buttonPaddingFactor),
                  _leaveTypeButton(setState, 'Annual', 'Annual Leave', fontSizeFactor, buttonPaddingFactor),
                ]);
              }
           // }
            else {
              leaveTypeButtons.add(_leaveTypeButton(setState, 'Annual', 'Annual Leave', fontSizeFactor, buttonPaddingFactor));
            }

            leaveTypeButtons.add(_leaveTypeButton(setState, 'Holiday', 'Holidays', fontSizeFactor, buttonPaddingFactor));


            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16 * paddingFactor,
                  right: 16 * paddingFactor,
                  top: 16 * paddingFactor,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[

                    Wrap(
                      spacing: 8.0 * paddingFactor,
                      runSpacing: 8.0 * paddingFactor,
                      children: leaveTypeButtons,
                    ),


                    SfDateRangePicker(

                      onSelectionChanged: (args) {
                        if (args.value is PickerDateRange) {

                          _selectedDateRange = args.value;
                          final selectedDates = _getSelectedDates(_selectedDateRange!);

                          final containsMarkedDate = selectedDates.any((date) => _markedDates.contains(date));

                          if (containsMarkedDate) {
                            Fluttertoast.showToast(msg: "Attendance exists for certain date(s) within your range.", fontSize: 14 * fontSizeFactor);


                            setState(() {});
                            return;
                          }
                        }
                        _onSelectionChanged(args, setState);
                      },
                      selectionMode: DateRangePickerSelectionMode.range,
                      initialSelectedRange: PickerDateRange(
                        DateTime.now(),
                        DateTime.now().add(const Duration(days: 1)),
                      ),
                      headerStyle: DateRangePickerHeaderStyle(
                        backgroundColor: Colors.blue,
                        textStyle: TextStyle(color: Colors.white, fontSize: 16 * fontSizeFactor),
                      ),
                      todayHighlightColor: Colors.red,
                      selectableDayPredicate: (DateTime date) {
                        return !_markedDates.contains(date);
                      },
                      cellBuilder: (BuildContext context, DateRangePickerCellDetails cellDetails) {

                        final holidayName = _nigerianHolidays[cellDetails.date];
                        bool isHoliday = holidayName != null;
                        bool isMarked = _markedDates.contains(cellDetails.date);
                        final markedDateLabel = _getMarkedDateLabel(cellDetails.date);

                        return Container(
                          decoration: BoxDecoration(
                            color: isHoliday ? Colors.green.withOpacity(0.2) : isMarked
                                ? Colors.grey
                                : null,
                            border: Border.all(color: const Color(0xFFF0F0F0), width: 0.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (markedDateLabel != null) ...[
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(markedDateLabel, style: TextStyle(fontSize: 6 * fontSizeFactor)),
                                ),
                                SizedBox(height: 2 * paddingFactor),
                              ],
                              if (isHoliday && markedDateLabel == null && !isMarked) ...[
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(holidayName, style: TextStyle(fontSize: 6 * fontSizeFactor)),
                                ),
                                SizedBox(height: 2 * paddingFactor),
                              ],


                              Text(cellDetails.date.day.toString(), style: TextStyle(fontSize: 14 * fontSizeFactor)),
                            ],
                          ),
                        );
                      },

                    ),


                    buildSupervisorDropdown(),



                    TextFormField(
                      controller: _reasonController,
                      decoration: InputDecoration(labelText: "Reason(s) For been Out-Of-Office", labelStyle: TextStyle(fontSize: 14 * fontSizeFactor)),
                      style: TextStyle(fontSize: 14 * fontSizeFactor),
                    ),




                    SizedBox(height: 16.0 * paddingFactor),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _handleSaveAndSubmit(context, setState, fontSizeFactor, paddingFactor);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 20 * buttonPaddingFactor, vertical: 12 * buttonPaddingFactor),
                            textStyle: TextStyle(fontSize: 16 * fontSizeFactor),
                          ),
                          child: const Text("Submit Request"),
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

  String? _getMarkedDateLabel(DateTime date) {

    final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
    final attendanceCollection = FirebaseFirestore.instance
        .collection('Staff')
        .doc(_currentUserId)
        .collection('Record');

    return null;
  }


  List<DateTime> _getSelectedDates(PickerDateRange range) {
    List<DateTime> dates = [];
    for (int i = 0; i <= range.endDate!.difference(range.startDate!).inDays; i++) {
      dates.add(range.startDate!.add(Duration(days: i)));
    }
    return dates;
  }


  Widget _leaveTypeButton(StateSetter setState, String type, String label, double fontSizeFactor, double buttonPaddingFactor) {
    return ElevatedButton(
      onPressed: () => setState(() => _selectedLeaveType = type),
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedLeaveType == type ? Colors.blue : Colors.grey,
        padding: EdgeInsets.symmetric(horizontal: 20 * buttonPaddingFactor, vertical: 12 * buttonPaddingFactor),
        textStyle: TextStyle(fontSize: 16 * fontSizeFactor),
      ),
      child: Text(label),
    );
  }


  void _onSelectionChanged(
      DateRangePickerSelectionChangedArgs args, StateSetter setState) {
    if (args.value is PickerDateRange) {
      _selectedDateRange = args.value;
      setState(() {});
    }
  }





  Future<List<DropdownMenuItem<String>>> _fetchSupervisorsFromFirebase() async {
    List<DropdownMenuItem<String>> supervisorItems = [];
    try {
      final supervisorsQuery = await FirebaseFirestore.instance
          .collection('Staff')
          .where('department', isEqualTo: _bioInfo.value?.department)
          .where('role', isEqualTo: 'Supervisor')
          .get();

      supervisorItems = supervisorsQuery.docs
          .map((doc) => DropdownMenuItem<String>(
        value: doc['fullName'] as String,
        child: Text(doc['fullName'] as String),
      ))
          .toList();
    } catch (e) {
      print("Error fetching supervisors from Firebase: $e");
    }
    return supervisorItems;
  }

  Widget _buildCircularPercentIndicator(int usedAnnual,int remainingAnnual,int usedMaternity,int remainingMaternity, double fontSizeFactor, double circularIndicatorRadiusFactor, double circularIndicatorLineWidthFactor) {
    RxInt totalLeaves = 0.obs;
    RxInt usedLeaves = 0.obs;
    final DateTime now = DateTime.now();
    final int fiscalYear = now.month >= 10 ? now.year + 1 : now.year;
    final String fiscalYearShort = fiscalYear.toString().substring(2);



    totalLeaves.bindStream(
      (() async* {
        if (selectedGender == 'Male') {
         //  if (selectedGender == 'Male') {
         //    yield remainingAnnual + 0;
         //  } else
         //
         // {
         //
         //    yield remainingMaternity;
         //  }
          yield remainingAnnual + 0;
        } else {

          yield remainingAnnual +  remainingMaternity;
        }
      })(),
    );

    usedLeaves.bindStream(
      (() async* {
        if (selectedGender == 'Female') {
          // if (_bioInfo.value?.gender == 'Male') {
          //   yield usedAnnual + usedPaternity;
          // } else
        //  if (selectedGender == 'Female') {

            yield (usedMaternity + usedAnnual);
          //}
        } else {

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
              radius: 100 * circularIndicatorRadiusFactor,
              lineWidth: 10 * circularIndicatorLineWidthFactor,
              percent: totalLeaves.value > 0
                  ? min(1.0, usedLeaves.value / totalLeaves.value) // Ensure it stays within 0.0 - 1.0
                  : 0.0,
              center: Text(
                "Total for FY$fiscalYearShort: ${totalLeaves.value}",
                style: TextStyle(fontSize: 18 * fontSizeFactor, fontWeight: FontWeight.w600),
              ),
              progressColor: Colors.green,
              backgroundColor: Colors.grey,
              circularStrokeCap: CircularStrokeCap.round,
            )),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Obx(() => _buildSummaryItem("Used", usedLeaves.value, Colors.blue, fontSizeFactor)),
                Obx(() => _buildSummaryItem(
                    "Balance", totalLeaves.value - usedLeaves.value, Colors.grey, fontSizeFactor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestsCard(double fontSizeFactor, double paddingFactor, double marginFactor, double iconSizeFactor) {

    final leaveRequestsByFiscalYear = <String, List<LeaveRequestModel>>{};
    for (final leaveRequest in _leaveRequests) {
      final fiscalYear = _getFiscalYear(leaveRequest.startDate!);
      leaveRequestsByFiscalYear.putIfAbsent(fiscalYear, () => []).add(leaveRequest);
    }

    return Card(
      margin: EdgeInsets.only(top: 16.0 * marginFactor),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0 * marginFactor)),
      child: Padding(
        padding: EdgeInsets.all(0.0 * paddingFactor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 16.0 * paddingFactor),
              child: Text(
                "Leave Requests",
                style: TextStyle(fontSize: 18 * fontSizeFactor, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 12 * paddingFactor),
            if (_leaveRequests.isEmpty)
              Center(child: Text("No leave requests found.", style: TextStyle(fontSize: 14 * fontSizeFactor)))
            else
              ExpansionPanelList(
                expansionCallback: (int index, bool isExpanded) {
                  setState(() {
                    if (isExpanded) {
                      expandedPanelIndex.value = index;
                    } else {
                      if (expandedPanelIndex.value == index) {
                        expandedPanelIndex.value = -1;
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
                          title: Text("FY $fiscalYear Leave Section", style: TextStyle(fontSize: 16 * fontSizeFactor)),
                          leading: isExpanded?Icon(Icons.remove,color: Colors.red, size: 24 * iconSizeFactor):Icon(Icons.add,color: Colors.green, size: 24 * iconSizeFactor)
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
                        return _buildLeaveRequestTile(leaveRequest, fontSizeFactor, paddingFactor, iconSizeFactor);
                      },
                    ),
                    canTapOnHeader: true,


                  );
                }).toList(),
              ),


          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestTile(LeaveRequestModel leaveRequest, double fontSizeFactor, double paddingFactor, double iconSizeFactor){
    return ListTile(
      title: Text(leaveRequest.type!, style: TextStyle(fontSize: 16 * fontSizeFactor)),
      subtitle: Text(
        'From ${DateFormat('dd MMMM, yyyy').format(leaveRequest.startDate!)} to ${DateFormat('dd MMMM, yyyy').format(leaveRequest.endDate!)}',
        style: TextStyle(fontSize: 12 * fontSizeFactor),
      ),
      trailing: SizedBox(
        width: 200 * paddingFactor,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getStatusIcon(leaveRequest.status),
              color: _getStatusColor(leaveRequest.status),
              size: 20 * iconSizeFactor,
            ),
            SizedBox(width: 8 * paddingFactor),
            Flexible(
              child: Text(
                leaveRequest.status!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14 * fontSizeFactor),
              ),
            ),


            leaveRequest.status == "Approved" ?const SizedBox.shrink():
            leaveRequest.status == "Rejected" ?const SizedBox.shrink():
            IconButton(
              icon: Icon(Icons.edit, size: 20 * iconSizeFactor),
              onPressed: () {
                _showEditLeaveBottomSheet(context, leaveRequest, fontSizeFactor, paddingFactor, max(0.8, min(1.2, MediaQuery.of(context).size.shortestSide / 600)), iconSizeFactor);
              },
            ),
            leaveRequest.status == "Approved" ?const SizedBox.shrink():
            leaveRequest.status == "Rejected" ?const SizedBox.shrink():
            IconButton(
              icon: Icon(Icons.delete, size: 20 * iconSizeFactor),
              onPressed: () {
                _showDeleteConfirmationDialog(context, leaveRequest, fontSizeFactor, paddingFactor);
              },
            ),
            leaveRequest.status == "Approved" ?const SizedBox.shrink():
            leaveRequest.status == "Rejected" ?const SizedBox.shrink():
            IconButton(
              icon: Icon(Icons.sync, size: 20 * iconSizeFactor),
              onPressed: () {
                _handleSync(leaveRequest);
              },
            ),
            SizedBox(width:8 * paddingFactor),

            leaveRequest.status == "Approved"?
            Text("Duration: ${leaveRequest.leaveDuration} day(s)", style: TextStyle(fontSize: 12 * fontSizeFactor)):const SizedBox.shrink(),
            leaveRequest.status == "Rejected"?
            IconButton(
              icon: Icon(Icons.info, size: 20 * iconSizeFactor),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("Rejection Reason", style: TextStyle(fontSize: 18 * fontSizeFactor)),
                      content: Text(leaveRequest.reasonsForRejectedLeave ?? "", style: TextStyle(fontSize: 14 * fontSizeFactor)),
                      actions: <Widget>[
                        TextButton(
                          child: Text("OK", style: TextStyle(fontSize: 14 * fontSizeFactor)),
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


  void _showEditLeaveBottomSheet(BuildContext context, LeaveRequestModel leaveRequest, double fontSizeFactor, double paddingFactor, double marginFactor, double iconSizeFactor) {


    _selectedLeaveType = leaveRequest.type!;
    _reasonController.text = leaveRequest.reason!;
    _selectedDateRange = PickerDateRange(leaveRequest.startDate, leaveRequest.endDate);
    _selectedSupervisor.value = leaveRequest.selectedSupervisor ?? ''; // Initialize RxString with existing value
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
                  _leaveTypeButton(setState, 'Paternity', 'Paternity Leave', fontSizeFactor, max(0.8, min(1.2, MediaQuery.of(context).size.shortestSide  / 600))),
                  _leaveTypeButton(setState, 'Annual', 'Annual Leave', fontSizeFactor, max(0.8, min(1.2, MediaQuery.of(context).size.shortestSide / 600))),
                ]);
              } else {
                leaveTypeButtons.addAll([
                  _leaveTypeButton(setState, 'Maternity', 'Maternity Leave', fontSizeFactor, max(0.8, min(1.2, MediaQuery.of(context).size.shortestSide / 600))),
                  _leaveTypeButton(setState, 'Annual', 'Annual Leave', fontSizeFactor, max(0.8, min(1.2, MediaQuery.of(context).size.shortestSide / 600))),
                ]);
              }
            } else {
              leaveTypeButtons.add(_leaveTypeButton(setState, 'Annual', 'Annual Leave', fontSizeFactor, max(0.8, min(1.2, MediaQuery.of(context).size.shortestSide / 600))));
            }

            leaveTypeButtons.add(_leaveTypeButton(setState, 'Holiday', 'Holidays', fontSizeFactor, max(0.8, min(1.2, MediaQuery.of(context).size.shortestSide / 600))));


            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16 * paddingFactor,
                  right: 16 * paddingFactor,
                  top: 16 * paddingFactor,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[


                    Wrap(
                      spacing: 8.0 * paddingFactor,
                      runSpacing: 8.0 * paddingFactor,
                      children: leaveTypeButtons,
                    ),



                    SfDateRangePicker(

                      onSelectionChanged: (args) {
                        if (args.value is PickerDateRange) {
                          final selectedDates = _getSelectedDates(args.value);
                          final containsMarkedDate = selectedDates.any((date) => _markedDates.contains(date));

                          if (containsMarkedDate) {
                            Fluttertoast.showToast(msg: "Attendance exists for the selected date(s).", fontSize: 14 * fontSizeFactor);


                            _selectedDateRange = null;
                            setState(() {});
                            return;
                          }
                        }
                        _onSelectionChanged(args, setState);
                      },
                      selectionMode: DateRangePickerSelectionMode.range,
                      initialSelectedRange: PickerDateRange(
                        DateTime.now(),
                        DateTime.now().add(const Duration(days: 1)),
                      ),
                      headerStyle: DateRangePickerHeaderStyle(
                        backgroundColor: Colors.blue,
                        textStyle: TextStyle(color: Colors.white, fontSize: 16 * fontSizeFactor),
                      ),
                      todayHighlightColor: Colors.red,
                      selectableDayPredicate: (DateTime date) {
                        return !_markedDates.contains(date);
                      },
                      cellBuilder: (BuildContext context, DateRangePickerCellDetails cellDetails) {

                        final holidayName = _nigerianHolidays[cellDetails.date];
                        bool isHoliday = holidayName != null;
                        bool isMarked = _markedDates.contains(cellDetails.date);
                        final markedDateLabel = _getMarkedDateLabel(cellDetails.date);

                        return Container(
                          decoration: BoxDecoration(
                            color: isHoliday ? Colors.green.withOpacity(0.2) : isMarked
                                ? Colors.grey
                                : null,
                            border: Border.all(color: const Color(0xFFF0F0F0), width: 0.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (markedDateLabel != null) ...[
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(markedDateLabel, style: TextStyle(fontSize: 6 * fontSizeFactor)),
                                ),
                                SizedBox(height: 2 * paddingFactor),
                              ],
                              if (isHoliday && markedDateLabel == null && !isMarked) ...[
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(holidayName, style: TextStyle(fontSize: 6 * fontSizeFactor)),
                                ),
                                SizedBox(height: 2 * paddingFactor),
                              ],


                              Text(cellDetails.date.day.toString(), style: TextStyle(fontSize: 14 * fontSizeFactor)),
                            ],
                          ),
                        );
                      },

                    ),

                    buildSupervisorDropdown(),

                    TextFormField(
                      controller: _reasonController,
                      decoration: InputDecoration(labelText: "Reason(s) For been Out-Of-Office", labelStyle: TextStyle(fontSize: 14 * fontSizeFactor)),
                      style: TextStyle(fontSize: 14 * fontSizeFactor),
                    ),




                    SizedBox(height: 16.0 * paddingFactor),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await _handleUpdateLeaveRequest(context, leaveRequest, setState, fontSizeFactor, paddingFactor);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 20 * max(0.8, min(1.2, MediaQuery.of(context).size.shortestSide / 600)), vertical: 12 * max(0.8, min(1.2, MediaQuery.of(context).size.shortestSide / 600))),
                            textStyle: TextStyle(fontSize: 16 * fontSizeFactor),
                          ),
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
    if (_currentUserId == null) return;

    final remainingLeaveDocRef = FirebaseFirestore.instance
        .collection('Staff')
        .doc(_currentUserId)
        .collection('RemainingLeave')
        .doc('remainingLeaveDoc');

    final docSnapshot = await remainingLeaveDocRef.get();
    if (docSnapshot.exists && docSnapshot.data() != null) {
      final remainingLeaveRequest = RemainingLeaveModel.fromJson(docSnapshot.data()!);

      final now = DateTime.now();
      final currentYear = now.year;
      final octoberThisYear = DateTime(currentYear, 10, 1);

      if (remainingLeaveRequest.dateUpdated!.isBefore(octoberThisYear) &&
          now.isAfter(octoberThisYear)) {
        remainingLeaveRequest.annualLeaveBalance = 10;
        remainingLeaveRequest.paternityLeaveBalance = 6;
        remainingLeaveRequest.maternityLeaveBalance = 60;
        remainingLeaveRequest.holidayLeaveBalance = 0;

        _remainingAnnualLeaveBalance.value = 10;
        _remainingPaternityLeaveBalance.value = 6;
        _remainingMaternityLeaveBalance.value = 60;
      }

      remainingLeaveRequest.dateUpdated = DateTime.now();
      await remainingLeaveDocRef.set(remainingLeaveRequest.toJson(), SetOptions(merge: true));

      _remainingLeaves.value = remainingLeaveRequest;
    }
  }


  Future<void> _handleUpdateLeaveRequest(BuildContext context, LeaveRequestModel leaveRequest, StateSetter setState, double fontSizeFactor, double paddingFactor) async{
    String? staffId = FirebaseAuth.instance.currentUser?.uid;
    if (staffId == null) {
      dev.log("Error: No logged-in user found");
      return;
    }


    try {
      leaveRequest.type = _selectedLeaveType;
      leaveRequest.startDate = _selectedDateRange!.startDate;
      leaveRequest.endDate = _selectedDateRange!.endDate ?? _selectedDateRange!.startDate;
      leaveRequest.reason = _reasonController.text;
      leaveRequest.selectedSupervisor = _selectedSupervisor.value; // Get value from RxString
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
      leaveRequest.staffId = staffId;


      final leaveRequestDocRef = FirebaseFirestore.instance
          .collection('Staff')
          .doc(_currentUserId)
          .collection('Leave Request')
          .doc(leaveRequest.leaveRequestId);

      await leaveRequestDocRef.update(leaveRequest.toJson());


      setState(() {
        leaveRequest.status = 'Pending';
      });


      if (mounted) {
        Navigator.of(context).pop();
        Fluttertoast.showToast(
            msg: "Leave Request updated successfully",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16 * fontSizeFactor);
      }


    } catch (e) {
      print("Error updating leave request: $e");
      if (mounted) {
        Fluttertoast.showToast(
            msg: "Failed to update leave request.",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16 * fontSizeFactor);

      }

    }

  }



  void _showDeleteConfirmationDialog(BuildContext context, LeaveRequestModel leaveRequest, double fontSizeFactor, double paddingFactor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete", style: TextStyle(fontSize: 18 * fontSizeFactor)),
          content: Text("Are you sure you want to delete this leave request?", style: TextStyle(fontSize: 14 * fontSizeFactor)),
          actions: <Widget>[
            TextButton(
              child: Text("No", style: TextStyle(fontSize: 14 * fontSizeFactor)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Yes", style: TextStyle(fontSize: 14 * fontSizeFactor)),
              onPressed: () async {
                try {
                  await _deleteLeaveRequestFromFirebase(leaveRequest); // Call Firebase delete function

                  _getLeaveData(); // Refresh leave data to update UI

                  if(mounted){
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Leave Request deleted successfully", style: TextStyle(fontSize: 14 * fontSizeFactor))));
                  }


                } catch (e) {
                  if(mounted){
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete Leave Request", style: TextStyle(fontSize: 14 * fontSizeFactor))));
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
      BuildContext context, StateSetter setState, double fontSizeFactor, double paddingFactor) async {

    String? staffId = FirebaseAuth.instance.currentUser?.uid;
    if (staffId == null) {
      dev.log("Error: No logged-in user found");
      return;
    }



    if (_selectedDateRange == null ||
        _reasonController.text.isEmpty ||
        _selectedSupervisor.value.isEmpty) { // Check if RxString value is empty
      Fluttertoast.showToast(
          msg: "Please fill all fields.",
          toastLength: Toast.LENGTH_LONG,

          fontSize: 14 * fontSizeFactor);
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
          fontSize: 14 * fontSizeFactor);
      return;
    }

    if (_remainingLeaves.value == null) {
      return;
    }

    final selectedDates = _getSelectedDates(_selectedDateRange!);
    if (selectedDates.any((date) => _markedDates.contains(date))) {
      Fluttertoast.showToast(msg: "There are days with attendance within your date range. Request not saved.", fontSize: 14 * fontSizeFactor);
      return;
    }


    switch (_selectedLeaveType) {
      case 'Annual':
        final annualBalance = _remainingLeaves.value!.annualLeaveBalance;
        if (annualBalance != null && leaveDuration > annualBalance) {
          _showLeaveExceedsBalanceError(context, 'Annual', annualBalance, fontSizeFactor, paddingFactor);
          return;
        }
        break;
      case 'Paternity':
        final paternityBalance = _remainingLeaves.value!.paternityLeaveBalance;
        if (paternityBalance != null && leaveDuration > paternityBalance) {
          _showLeaveExceedsBalanceError(context, 'Paternity', paternityBalance, fontSizeFactor, paddingFactor);
          return;
        }
        break;
      case 'Maternity':
        final maternityBalance = _remainingLeaves.value!.maternityLeaveBalance;
        if (maternityBalance != null && leaveDuration > maternityBalance) {
          _showLeaveExceedsBalanceError(context, 'Maternity', maternityBalance, fontSizeFactor, paddingFactor);
          return;
        }
        break;
    }


    final newLeaveRequest = LeaveRequestModel()
      ..type = _selectedLeaveType
      ..startDate = _selectedDateRange!.startDate
      ..endDate = _selectedDateRange!.endDate ?? _selectedDateRange!.startDate
      ..reason = _reasonController.text
      ..staffId = staffId
      ..selectedSupervisor = _selectedSupervisor.value // Get value from RxString
      ..selectedSupervisorEmail = _selectedSupervisorEmail
      ..leaveDuration = leaveDuration
      ..status = 'Pending'
      ..firstName = _bioInfo.value?.firstName!
      ..lastName = _bioInfo.value?.lastName!
      ..staffCategory = _bioInfo.value?.staffCategory!
      ..staffState= _bioInfo.value?.state!
      ..staffLocation= _bioInfo.value?.location!
      ..staffEmail= _bioInfo.value?.emailAddress!
      ..staffPhone= _bioInfo.value?.mobile!
      ..staffDepartment= _bioInfo.value?.department!
      ..staffDesignation= _bioInfo.value?.designation!
      ..leaveRequestId = const Uuid().v4();


    try {
      await _saveLeaveRequest(newLeaveRequest);
      await _updateRemainingLeavesAndDate();

      if (mounted) {
        Navigator.pop(context);
        Fluttertoast.showToast(
            msg: "Request submitted.",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16 * fontSizeFactor);
        setState(() {});


      }

    } catch (error) {

      print("Error in Save and Submit: $error");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred with saveLeaveRequest. Please try again.", style: TextStyle(fontSize: 14 * fontSizeFactor))),
        );
      }

    }

  }


  void _showLeaveExceedsBalanceError(BuildContext context, String leaveType, int remainingBalance, double fontSizeFactor, double paddingFactor) {
    Fluttertoast.showToast(
      msg: "$leaveType leave cannot exceed $remainingBalance working days. You have $remainingBalance days remaining.",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      fontSize: 14 * fontSizeFactor,
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




  Future<void> _saveLeaveRequest(LeaveRequestModel leaveRequest) async {

    final leaveRequestCollection = FirebaseFirestore.instance
        .collection('Staff')
        .doc(_currentUserId)
        .collection('Leave Request');
    await leaveRequestCollection.doc(leaveRequest.leaveRequestId).set(leaveRequest.toJson());
  }



  Future<void> _submitLeaveRequest(LeaveRequestModel leaveRequest, BuildContext context) async {


    if (!_firebaseInitialized.value) {
      print("Firebase not initialized. Cannot submit leave request.");
      Fluttertoast.showToast(msg: "Firebase not initialized. Cannot submit request.");
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final staffCollection =
        FirebaseFirestore.instance.collection('Staff').doc(user.uid);
        final leaveRequestCollection = staffCollection.collection('Leave Request');


        final leaveRequestId = leaveRequest.leaveRequestId;

        if (leaveRequestId != null) {
          await leaveRequestCollection.doc(leaveRequestId).set({
            ...leaveRequest.toJson(),
            'leaveRequestId': leaveRequestId,
            'status':"Pending"

          });

          await sendEmailFromDevice(
            leaveRequest.selectedSupervisorEmail!,
            'New Leave Request from ${leaveRequest.firstName} ${leaveRequest.lastName}',
            _formatLeaveRequestEmail2(leaveRequest),
          );


          _getLeaveData();
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

      for (final leaveRequest in _leaveRequests) {
        print("leaveRequest === ${leaveRequest.leaveRequestId}");

        try {

          final doc = await FirebaseFirestore.instance
              .collection('Staff')
              .doc(_bioInfo.value?.firebaseAuthId)
              .collection('Leave Request')
              .doc(leaveRequest.leaveRequestId)
              .get();

          if (doc.exists) {
            final firestoreStatus = doc.data()?['status'] as String?;
            final firestoreReason = doc.data()?['reason'] as String?;
            final firestoreReasonsForRejectedLeave = doc.data()?['reasonsForRejectedLeave'] as String?;


            if (firestoreStatus != null && firestoreStatus != leaveRequest.status) {

              setState(() {
                leaveRequest.status = firestoreStatus;
              });


              if (firestoreStatus == 'Approved') {

                await _addLeaveToAttendance1(
                  _bioInfo.value?.firebaseAuthId,
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
                leaveRequest.reasonsForRejectedLeave = firestoreReasonsForRejectedLeave;

                Fluttertoast.showToast(msg: "Out of Office Request Rejected");
              }
            }
          }
        } catch (innerError) {
          print('Error processing individual leave request: $innerError');
          Fluttertoast.showToast(
              msg: "Error processing individual Out of Office Request: $innerError");
        }
      }


      Get.off(() => const LeaveRequestsPage1());
    } catch (e) {
      print('Error checking Out of Office Request status: $e');
      Fluttertoast.showToast(msg: "Error syncing Out of Office Request status");
    }
  }



  Future<void> _addLeaveAttendanceRecord(DateTime date, String leaveType) async {

    final attendanceDocRef = FirebaseFirestore.instance
        .collection('Staff')
        .doc(_currentUserId)
        .collection('Record')
        .doc(DateFormat('dd-MMMM-yyyy').format(date));

    await attendanceDocRef.set({
      'Offline_DB_id': 1,
      'clockIn': '08:00 AM',
      'date': DateFormat('dd-MMMM-yyyy').format(date),
      'clockInLatitude': 0.0,
      'clockInLocation': "",
      'clockInLongitude': 0.0,
      'clockOut': '05:00 PM',
      'clockOutLatitude': 0.0,
      'clockOutLocation': "",
      'clockOutLongitude': 0.0,
      'isSynced': true,
      'voided': false,
      'isUpdated': true,
      'offDay': true,
      'durationWorked': leaveType,
      'noOfHours': 8.1,
      'month': DateFormat('MMMM yyyy').format(date),
    });
  }

  Future<void> _deductLeaveBalance(LeaveRequestModel leaveRequest, int daysToDeduct) async {

    final remainingLeaveDocRef = FirebaseFirestore.instance
        .collection('Staff')
        .doc(_currentUserId)
        .collection('RemainingLeave')
        .doc('remainingLeaveDoc');

    final docSnapshot = await remainingLeaveDocRef.get();
    if (docSnapshot.exists && docSnapshot.data() != null) {
      final updatedRemainingLeaveRequest = RemainingLeaveModel.fromJson(docSnapshot.data()!);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(remainingLeaveDocRef);
        if (!snapshot.exists) {
          throw Exception("Remaining leave document does not exist!");
        }

        int currentAnnualLeaveBalance = updatedRemainingLeaveRequest.annualLeaveBalance ?? 0;
        int currentPaternityLeaveBalance = updatedRemainingLeaveRequest.paternityLeaveBalance ?? 0;
        int currentMaternityLeaveBalance = updatedRemainingLeaveRequest.maternityLeaveBalance ?? 0;
        int currentHolidayLeaveBalance = updatedRemainingLeaveRequest.holidayLeaveBalance ?? 0;

        switch (leaveRequest.type) {
          case 'Annual':
            currentAnnualLeaveBalance = (currentAnnualLeaveBalance - daysToDeduct).clamp(0, _totalAnnualLeaves.value);
            break;
          case 'Paternity':
            currentPaternityLeaveBalance = (currentPaternityLeaveBalance - daysToDeduct).clamp(0, _totalPaternityLeaves.value);
            break;
          case 'Maternity':
            currentMaternityLeaveBalance = (currentMaternityLeaveBalance - daysToDeduct).clamp(0, _totalMaternityLeaves.value);
            break;
          case 'Holiday':
            currentHolidayLeaveBalance = (currentHolidayLeaveBalance - daysToDeduct).clamp(0, _totalHolidayLeaves.value);
            break;
        }

        transaction.update(remainingLeaveDocRef, {
          'annualLeaveBalance': currentAnnualLeaveBalance,
          'paternityLeaveBalance': currentPaternityLeaveBalance,
          'maternityLeaveBalance': currentMaternityLeaveBalance,
          'holidayLeaveBalance': currentHolidayLeaveBalance,
        });
      });
    }
  }


  Future<void> _addPreviousLeave(
      String? userId,
      DateTime? startDate,
      DateTime? endDate,
      String? leaveType,
      String? firestoreReason
      ) async {

    await FirebaseFirestore.instance
        .collection('Staff')
        .doc(userId)
        .collection('Leave Request')
        .add({
      'startDate': startDate,
      'endDate': endDate,
      'leaveType': leaveType,
      'reason': firestoreReason ?? '',

    });
  }


  Future<void> _addLeaveToAttendance1(
      String? userId,
      DateTime? startDate,
      DateTime? endDate,
      String? leaveType,
      String? firestoreReason
      ) async {

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

    const int maxRetries = 5;
    const Duration initialDelay = Duration(seconds: 2);

    for (var date = startDate; !date.isAfter(endDate); date = date.add(const Duration(days: 1))) {

      if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
        int retryCount = 0;

        final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
        final attendanceDocRef = FirebaseFirestore.instance
            .collection('Staff')
            .doc(userId)
            .collection('Record')
            .doc(formattedDate);

        final docSnapshot = await attendanceDocRef.get();
        if (docSnapshot.exists) {
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


            await attendanceDocRef.set({
              'Offline_DB_id': 1,
              'clockIn': '08:00 AM',
              'date': formattedDate,
              'clockInLatitude': lati.value,
              'clockInLocation': location.value,
              'clockInLongitude': longi.value,
              'clockOut': '05:00 PM',
              'clockOutLatitude': lati.value,
              'clockOutLocation': location.value,
              'clockOutLongitude': longi.value,
              'comments': firestoreReason,
              'isSynced': true,
              'voided': false,
              'isUpdated': true,
              'offDay': true,
              'durationWorked': leaveType == "Annual" ? "Annual Leave" : leaveType,
              'noOfHours': 9.0001,
              'month': DateFormat('MMMM yyyy').format(date),
            });


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
              final delay = initialDelay * retryCount;
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


    await _getLeaveData();


    Fluttertoast.showToast(
      msg: "Leave added to attendance records.",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );
  }




  Future<void> _updateLeaveBalanceAfterApproval(LeaveRequestModel leaveRequest) async {
    if (leaveRequest.status == 'Approved') {
      final leaveDuration = leaveRequest.leaveDuration;
      if (leaveDuration != null && leaveDuration > 0) {
        try {
          final currentRemainingLeaves = _remainingLeaves.value;
          if (currentRemainingLeaves == null) {
            print("Remaining leaves not initialized.");
            return;
          }

          final remainingLeaveDocRef = FirebaseFirestore.instance
              .collection('Staff')
              .doc(_currentUserId)
              .collection('RemainingLeave')
              .doc('remainingLeaveDoc');


          await FirebaseFirestore.instance.runTransaction((transaction) async {
            DocumentSnapshot snapshot = await transaction.get(remainingLeaveDocRef);
            if (!snapshot.exists) {
              throw Exception("Remaining leave document does not exist!");
            }
            RemainingLeaveModel updatedRemainingLeaveRequest = RemainingLeaveModel.fromJson(snapshot.data() as Map<String, dynamic>);


            int currentAnnualLeaveBalance = updatedRemainingLeaveRequest.annualLeaveBalance ?? 0;
            int currentPaternityLeaveBalance = updatedRemainingLeaveRequest.paternityLeaveBalance ?? 0;
            int currentMaternityLeaveBalance = updatedRemainingLeaveRequest.maternityLeaveBalance ?? 0;
            int currentHolidayLeaveBalance = updatedRemainingLeaveRequest.holidayLeaveBalance ?? 0;

            switch (leaveRequest.type) {
              case 'Annual':
                currentAnnualLeaveBalance = (currentAnnualLeaveBalance - leaveDuration).clamp(0, _totalAnnualLeaves.value);
                break;
              case 'Paternity':
                currentPaternityLeaveBalance = (currentPaternityLeaveBalance - leaveDuration).clamp(0, _totalPaternityLeaves.value);
                break;
              case 'Maternity':
                currentMaternityLeaveBalance = (currentMaternityLeaveBalance - leaveDuration).clamp(0, _totalMaternityLeaves.value);
                break;
              case 'Holiday':
                currentHolidayLeaveBalance = (currentHolidayLeaveBalance - leaveDuration).clamp(0, _totalHolidayLeaves.value);
                break;
            }

            transaction.update(remainingLeaveDocRef, {
              'annualLeaveBalance': currentAnnualLeaveBalance,
              'paternityLeaveBalance': currentPaternityLeaveBalance,
              'maternityLeaveBalance': currentMaternityLeaveBalance,
              'holidayLeaveBalance': currentHolidayLeaveBalance,
            });
          });


        } catch (e) {
          print('Error updating leave balance: $e');
          Fluttertoast.showToast(
              msg: "Error updating leave balance: $e",
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: Colors.black54,

              timeInSecForIosWeb: 1,
              textColor: Colors.white,
              fontSize: 16.0
          );
        }
      }
    }
  }


}

class BioModel {
  String? id; // Document ID from Firestore
  String? firstName;
  String? lastName;
  String? maritalStatus;
  String? gender;
  String? staffCategory;
  String? designation;
  String? password;
  String? state;
  String? emailAddress;
  String? role;
  String? location;
  String? firebaseAuthId;
  String? department;
  String? mobile;
  String? project;
  bool? isSynced;
  String? supervisor;
  String? supervisorEmail;
  String? version;
  bool? isRemoteDelete;
  bool? isRemoteUpdate;
  DateTime? lastUpdateDate;
  String? signatureLink;

  BioModel({
    this.id,
    this.firstName,
    this.lastName,
    this.staffCategory,
    this.designation,
    this.password,
    this.state,
    this.emailAddress,
    this.role,
    this.location,
    this.firebaseAuthId,
    this.department,
    this.mobile,
    this.project,
    this.isSynced,
    this.supervisor,
    this.supervisorEmail,
    this.version,
    this.isRemoteDelete,
    this.isRemoteUpdate,
    this.lastUpdateDate,
    this.signatureLink
  });

  factory BioModel.fromJson(Map<String, dynamic> json) {
    return BioModel(
        id: json['id'], // Get ID from json
        firstName: json['firstName'],
        lastName: json['lastName'],
        staffCategory: json['staffCategory'],
        designation: json['designation'],
        password: json['password'],
        state: json['state'],
        emailAddress: json['emailAddress'],
        role: json['role'],
        location: json['location'],
        firebaseAuthId: json['firebaseAuthId'],
        department: json['department'],
        mobile: json['mobile'],
        project: json['project'],
        isSynced:json['isSynced'],
        supervisor:json['supervisor'],
        supervisorEmail:json['supervisorEmail'],
        version:json['version'],
        isRemoteDelete:json['isRemoteDelete'],
        isRemoteUpdate:json['isRemoteUpdate'],
        lastUpdateDate: json['lastUpdateDate'] != null ? (json['lastUpdateDate'] as Timestamp).toDate() : null,
        signatureLink:json['signatureLink']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      'firstName': firstName,
      'lastName': lastName,
      'staffCategory': staffCategory,
      'designation': designation,
      'password': password,
      'state': state,
      'emailAddress': emailAddress,
      'role': role,
      'location': location,
      'firebaseAuthId': firebaseAuthId,
      'department': department,
      'mobile': mobile,
      'project': project,
      'isSynced':isSynced,
      'supervisor':supervisor,
      'supervisorEmail':supervisorEmail,
      'version':version,
      'isRemoteDelete':isRemoteDelete,
      'isRemoteUpdate':isRemoteUpdate,
      'lastUpdateDate':lastUpdateDate,
      'signatureLink':signatureLink
    };
  }
}

class LocationModel {
  String? id; // Document ID from Firestore
  String? state;
  String? locationName;
  String? category;
  double? latitude;
  double? longitude;
  double? radius;

  LocationModel(
      {this.id,
        this.state,
        this.locationName,
        this.category,
        this.latitude,
        this.longitude,
        this.radius});

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'], // Get ID from json
      state: json['state'],
      locationName: json['locationName'],
      category: json['category'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      radius: (json['radius'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      'state': state,
      'locationName': locationName,
      'category':category,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius
    };
  }
}

class AttendanceModel {
  String? id; // Document ID (date string) from Firestore
  String? clockIn;
  String? clockOut;
  String? clockInLocation;
  String? clockOutLocation;
  String? date;
  bool? isSynced;
  double? clockInLatitude;
  double? clockInLongitude;
  double? clockOutLatitude;
  double? clockOutLongitude;
  bool? voided;
  bool? isUpdated;
  bool? offDay;
  double? noOfHours;
  String? durationWorked;
  String? month;
  String? comments;
  int? offlineDbId;

  AttendanceModel(
      {this.id,
        this.clockIn,
        this.clockOut,
        this.clockInLocation,
        this.clockOutLocation,
        this.date,
        this.isSynced,
        this.clockInLatitude,
        this.clockInLongitude,
        this.clockOutLatitude,
        this.clockOutLongitude,
        this.voided,
        this.isUpdated,
        this.offDay,
        this.noOfHours,
        this.durationWorked,
        this.month,
        this.comments,
        this.offlineDbId
      });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
        id: json['id'], // Get ID from json
        offlineDbId: json['Offline_DB_id'],
        clockIn: json['clockIn'],
        clockOut: json['clockOut'],
        clockInLocation: json['clockInLocation'],
        clockOutLocation: json['clockOutLocation'],
        date: json['date'],
        isSynced: json['isSynced'],
        clockInLatitude: (json['clockInLatitude'] as num?)?.toDouble(),
        clockInLongitude: (json['clockInLongitude'] as num?)?.toDouble(),
        clockOutLatitude: (json['clockOutLatitude'] as num?)?.toDouble(),
        clockOutLongitude: (json['clockOutLongitude'] as num?)?.toDouble(),
        voided: json['voided'],
        isUpdated: json['isUpdated'],
        offDay: json['offDay'],
        noOfHours: (json['noOfHours'] as num?)?.toDouble(),
        durationWorked: json['durationWorked'],
        month: json['month'],
        comments:json['comments']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      'Offline_DB_id': offlineDbId,
      'clockIn': clockIn,
      'clockOut': clockOut,
      'clockInLocation': clockInLocation,
      'clockOutLocation': clockOutLocation,
      'date': date,
      'isSynced': isSynced,
      'clockInLatitude': clockInLatitude,
      'clockInLongitude': clockInLongitude,
      'clockOutLatitude': clockOutLatitude,
      'clockOutLongitude': clockOutLongitude,
      'voided': voided,
      'isUpdated': isUpdated,
      'offDay': offDay,
      'noOfHours': noOfHours,
      'durationWorked': durationWorked,
      'month': month,
      'comments':comments
    };
  }
}

class RemainingLeaveModel {
  String? id; // Document ID from Firestore (default to 'remainingLeaveDoc')
  String? staffId;
  int? paternityLeaveBalance;
  int? maternityLeaveBalance;
  int? annualLeaveBalance;
  int? holidayLeaveBalance;
  DateTime? dateUpdated;


  RemainingLeaveModel({
    this.id = 'remainingLeaveDoc', // Default Document ID
    this.staffId,
    this.paternityLeaveBalance,
    this.maternityLeaveBalance,
    this.annualLeaveBalance,
    this.holidayLeaveBalance,
    this.dateUpdated,
  });


  factory RemainingLeaveModel.fromJson(Map<String, dynamic> json) {
    return RemainingLeaveModel(
      id: json['id'] ?? 'remainingLeaveDoc', // Get ID from json or default
      staffId: json['staffId'],
      paternityLeaveBalance: json['paternityLeaveBalance'],
      maternityLeaveBalance: json['maternityLeaveBalance'],
      annualLeaveBalance: json['annualLeaveBalance'],
      holidayLeaveBalance: json['holidayLeaveBalance'],
      dateUpdated: json['dateUpdated'] != null ? (json['dateUpdated'] as Timestamp).toDate() : null,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId':staffId,
      'paternityLeaveBalance': paternityLeaveBalance,
      'maternityLeaveBalance': maternityLeaveBalance,
      'annualLeaveBalance': annualLeaveBalance,
      'holidayLeaveBalance': holidayLeaveBalance,
      'dateUpdated':dateUpdated

    };
  }
}