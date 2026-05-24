import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ntp/ntp.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'package:location/location.dart' as locationPkg;
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http; // Import http package
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/location_services.dart';
import '../../services/qr_verification_service.dart';
import '../../widgets/drawer.dart';
import '../../widgets/geo_utils.dart';
import '../../widgets/header_widget.dart';
import '../leave_request/leave_request.dart';
import '../login_screen.dart';
import '../staff_dashboard.dart';
import 'history_page.dart'; // Import your login screen
import 'package:service_delivery_workspace/screens/components/qr_scanner_page.dart';

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
      longitude:
          GeofenceModel._parseNum(firestoreData['Longitude'])?.toDouble() ??
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

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? getUserId() {
    print("Current UUID === ${_auth.currentUser?.uid}");
    return _auth.currentUser?.uid;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAttendanceRecord(
      String userId, String date) {
    return _firestore
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getAttendanceRecord(
      String userId, String date) async {
    return await _firestore
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .get();
  }

  Future<void> createAttendanceRecord(
      String userId, String date, Map<String, dynamic> data) async {
    // Ensure timestamp is added for analysis pages
    final finalData = Map<String, dynamic>.from(data);
    if (!finalData.containsKey('timestamp') || finalData['timestamp'] == null) {
      finalData['timestamp'] = FieldValue.serverTimestamp();
    }
    
    // Inject staff denormalized data
    try {
      final staffDoc = await _firestore.collection('Staff').doc(userId).get();
      if (staffDoc.exists && staffDoc.data() != null) {
        final staffData = staffDoc.data()!;
        finalData['state'] = staffData['state'];
        finalData['location'] = staffData['location']; // Facility Name
        finalData['designation'] = staffData['designation'];
        finalData['staffName'] = '${staffData['firstName'] ?? ''} ${staffData['lastName'] ?? ''}'.trim();
      }
    } catch (e) {
      dev.log("Error fetching staff data for denormalization: $e");
    }

    await _firestore
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .set(finalData);
  }

  Future<void> updateAttendanceRecord(
      String userId, String date, Map<String, dynamic> data) async {
    // Ensure timestamp is updated or present
    final finalData = Map<String, dynamic>.from(data);
    if (!finalData.containsKey('timestamp') || finalData['timestamp'] == null) {
      finalData['timestamp'] = FieldValue.serverTimestamp();
    }
    
    // Inject staff denormalized data to keep records consistent
    try {
      final staffDoc = await _firestore.collection('Staff').doc(userId).get();
      if (staffDoc.exists && staffDoc.data() != null) {
        final staffData = staffDoc.data()!;
        finalData['state'] = staffData['state'];
        finalData['location'] = staffData['location']; // Facility Name
        finalData['designation'] = staffData['designation'];
        finalData['staffName'] = '${staffData['firstName'] ?? ''} ${staffData['lastName'] ?? ''}'.trim();
      }
    } catch (e) {
      dev.log("Error fetching staff data for denormalization: $e");
    }

    await _firestore
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .update(finalData);
  }

  Future<String?> getUserState() async {
    DocumentSnapshot userSnapshot =
        await _firestore.collection('Staff').doc(getUserId()).get();
    if (userSnapshot.exists) {
      Map<String, dynamic>? userData =
          userSnapshot.data() as Map<String, dynamic>?;
      return userData?['state'] as String?;
    }
    return null;
  }

  Future<List<String>> getAllStates() async {
    List<String> states = [];
    try {
      QuerySnapshot locationSnapshot =
          await _firestore.collection('Location').get();
      for (var doc in locationSnapshot.docs) {
        states.add(doc.id);
      }
    } catch (e) {
      dev.log("Error fetching states: $e");
    }
    return states;
  }

  Future<List<GeofenceModel>> getGeofencesForState(String state) async {
    List<GeofenceModel> geofenceLocations = [];
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('Location')
          .doc(state)
          .collection(state)
          .get();

      for (var doc in snapshot.docs) {
        geofenceLocations.add(GeofenceModel.fromFirestore(doc.data(), state));
      }
      dev.log("geofenceLocations =$geofenceLocations");
    } catch (e) {
      dev.log("Error fetching geofences for state $state: $e");
    }
    return geofenceLocations;
  }

  Future<List<GeofenceModel>> getGeofencesForAllStatesExceptCurrent(
      String currentState) async {
    List<GeofenceModel> allGeofences = [];
    List<String> allStates = await getAllStates();

    for (String state in allStates) {
      if (state != currentState) {
        allGeofences.addAll(await getGeofencesForState(state));
      }
    }
    return allGeofences;
  }

  Future<bool> hasSurveyResponseForToday(String userId) async {
    final currentDateFormatted =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await _firestore
        .collection('Staff')
        .doc(userId)
        .collection('SurveyResponses')
        .doc(currentDateFormatted)
        .get();
    return doc.exists;
  }
}

class ClockAttendanceWeb extends StatefulWidget {
  const ClockAttendanceWeb({super.key});

  static const Color maroonPrimary = Color(0xFF5C1A2E); // Corporate Maroon
  static const Color goldAccent = Color(0xFFD4A03C); // Corporate Gold
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [maroonPrimary, Color(0xFF2E0215)], // Maroon to darker shade
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  State<ClockAttendanceWeb> createState() => _ClockAttendanceWebState();
}

class _ClockAttendanceWebState extends State<ClockAttendanceWeb> {
  int _selectedIndex = 0;
  static final TextStyle optionStyle =
      GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.bold);
  static final List<Widget> _widgetOptions = <Widget>[
    const AttendancePage(),
    const HistoryPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: ClockAttendanceWeb.goldAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}

class AttendancePage extends StatefulWidget {
  // Changed to StatefulWidget
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() =>
      _AttendancePageState(); // Create corresponding State
}

class _AttendancePageState extends State<AttendancePage> {
  // Created State class
  Timer? _inactivityTimer;
  final ClockAttendanceWebController controller =
      Get.put(ClockAttendanceWebController(FirestoreService()));

  static const Color maroonPrimary = Color(0xFF5C1A2E); // Corporate Maroon
  static const Color goldAccent = Color(0xFFD4A03C); // Corporate Gold
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [maroonPrimary, Color(0xFF2E0215)], // Maroon to darker shade
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    controller
        .initializeLocationAndGeofence(); // Initialize location and geofence in initState
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel(); // Cancel any existing timer
    _inactivityTimer = Timer(const Duration(minutes: 5), _logoutUser);
  }

  void _resetInactivityTimer() {
    _startInactivityTimer(); // Restart the timer on user activity
  }

  void _logoutUser() {
    Get.delete<ClockAttendanceWebController>(); // Clear the controller
    FirebaseAuth.instance.signOut();
    // Navigate to the login screen after logout
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (context) =>
              const LoginPage()), // Replace LoginScreen with your actual login page widget
    );
    Fluttertoast.showToast(
      msg: "Logged out due to inactivity.",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ResponsiveSizes sizes = ResponsiveSizes(context);

    return Listener(
      // Wrap with Listener to detect user interactions
      onPointerDown: (_) => _resetInactivityTimer(), // Reset timer on tap/click
      onPointerMove: (_) => _resetInactivityTimer(), // Reset timer on drag/move
      onPointerSignal: (_) =>
          _resetInactivityTimer(), // Reset timer on scroll/signal
      child: Scaffold(
        drawer: drawer(context),
        appBar: AppBar(
          title:
              Text('Attendance', style: GoogleFonts.poppins(color: Colors.white)),
          iconTheme: const IconThemeData(
              color: Colors.white), // Makes the drawer icon white
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: appBarGradient),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(top: 15, right: 15, bottom: 15),
              child: Image.asset("assets/image/ccfn_logo.png"),
            )
          ],
        ),
        body: SelectionArea(
          child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                ScreenSize screenSize =
                    sizes.getScreenSize(constraints.maxWidth);
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: sizes.horizontalPadding,
                      vertical: sizes.verticalPadding),
                  child: Column(
                    children: [
                      SizedBox(height: sizes.verticalSpacing),
                      HeaderWidget(
                          sizes.headerIconSize, false, Icons.house_rounded),
                      SizedBox(height: sizes.sectionSpacing),
                      _buildWelcomeHeader(
                          context, controller, screenSize, sizes),
                      SizedBox(height: sizes.sectionSpacing),
                      _buildStatusCard(context, controller, screenSize, sizes),
                      SizedBox(height: sizes.sectionSpacing),
                      _buildAttendanceCard(
                          context, controller, screenSize, sizes),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildWelcomeHeader(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                "Welcome",
                textAlign: TextAlign.start,
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontWeight: FontWeight.w300,
                  fontSize: sizes.welcomeHeaderTextSize,
                ),
              ),
            ),
            Image(
              image: const AssetImage("./assets/image/ccfn_logo.png"),
              width: sizes.logoSize,
              height: sizes.logoSize,
            ),
          ],
        ),
        Obx(() => Text(
              "${controller.firstName.value.toString().toUpperCase()} ${controller.lastName.value.toString().toUpperCase()}",
              style: GoogleFonts.poppins(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: sizes.usernameHeaderTextSize,
              ),
            )),
      ],
    );
  }

  Widget _buildStatusCard(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return Container(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Status:",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: sizes.cardHeaderTextSize,
            ),
          ),
          SizedBox(height: sizes.cardInnerSpacing),
          Obx(() => Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(sizes.cardBorderRadius)),
                child: Container(
                  width: MediaQuery.of(context).size.width * 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.red.shade100,
                        Colors.white,
                        Colors.black12
                      ],
                    ),
                    borderRadius: BorderRadius.circular(sizes.cardBorderRadius),
                  ),
                  padding: EdgeInsets.all(sizes.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Geo-Coordinates Information:",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: sizes.subCardHeaderTextSize,
                          color: Colors.blueGrey,
                        ),
                      ),
                      SizedBox(height: sizes.cardInnerSpacing),
                      _buildStatusText(
                          "GPS is:",
                          controller.isGpsEnabled.value ? 'On' : 'Off',
                          screenSize,
                          sizes),
                      _buildStatusText(
                          "Current Latitude:",
                          controller.lati.value.toStringAsFixed(6),
                          screenSize,
                          sizes),
                      _buildStatusText(
                          "Current Longitude:",
                          controller.longi.value.toStringAsFixed(6),
                          screenSize,
                          sizes),
                      _buildStatusText(
                          "Coordinates Accuracy:",
                          controller.accuracy.value.toString(),
                          screenSize,
                          sizes),
                      _buildStatusText(
                          "Altitude:",
                          controller.altitude.value.toString(),
                          screenSize,
                          sizes),
                      _buildStatusText("Speed:",
                          controller.speed.value.toString(), screenSize, sizes),
                      _buildStatusText(
                          "Speed Accuracy:",
                          controller.speedAccuracy.value.toString(),
                          screenSize,
                          sizes),
                      _buildStatusText(
                          "Location Data Timestamp:",
                          DateFormat('yyyy-MM-dd HH:mm:ss').format(
                              DateTime.fromMillisecondsSinceEpoch(
                                  controller.time.value.toInt())),
                          screenSize,
                          sizes),
                      _buildStatusText(
                          "Is Location Mocked?:",
                          controller.isMock.value.toString(),
                          screenSize,
                          sizes),
                      _buildStatusText(
                          "Current State:",
                          controller.administrativeArea.value,
                          screenSize,
                          sizes),
                      _buildStatusText("Current Location:",
                          controller.location.value, screenSize, sizes),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStatusText(String label, String value, ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: sizes.statusTextVerticalPadding),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: sizes.statusTextSize,
            color: Colors.black87,
          ),
          children: <TextSpan>[
            TextSpan(
                text: '$label ',
                style: GoogleFonts.poppins(color: Colors.blueGrey)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: controller.firestoreService.streamAttendanceRecord(
          controller.firestoreService.getUserId()!,
          DateFormat('dd-MMMM-yyyy').format(DateTime.now())),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData && snapshot.data!.exists) {
          final attendanceData = snapshot.data!.data();
          if (attendanceData != null) {
            final lastAttendance =
                AttendanceModelFirestore.fromMap(attendanceData);
            if (lastAttendance.clockIn != "--/--" &&
                lastAttendance.clockOut == "--/--") {
              return _buildClockOutSection(
                  context, controller, lastAttendance, screenSize, sizes);
            } else if (lastAttendance.clockIn != "--/--" &&
                lastAttendance.clockOut != "--/--") {
              return _buildDayCompletedSection(
                  context, controller, lastAttendance, screenSize, sizes);
            } else {
              return _buildClockInSection(
                  context, controller, screenSize, lastAttendance, sizes);
            }
          } else {
            return _buildClockInSection(
                context, controller, screenSize, null, sizes);
          }
        } else {
          return _buildClockInSection(
              context, controller, screenSize, null, sizes);
        }
      },
    );
  }

  Widget _buildClockInSection(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      AttendanceModelFirestore? lastAttendance,
      ResponsiveSizes sizes) {
    return Column(
      children: [
        _buildClockInOutDisplay(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildDateAndTime(screenSize, sizes),
        SizedBox(height: sizes.sectionSpacing),
        _buildClockInImageButton(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildOutOfOfficeButton(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildLocationStatusCard(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildVerifiedByCard(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        Text(
          "Location data powered by OpenStreetMap contributors, under the Open Database License.",
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: sizes.cardInnerSpacing),
      ],
    );
  }

  Widget _buildClockOutSection(
      BuildContext context,
      ClockAttendanceWebController controller,
      AttendanceModelFirestore? lastAttendance,
      ScreenSize screenSize,
      sizes) {
    return Column(
      children: [
        _buildClockInOutDisplay(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildDateAndTime(screenSize, sizes),
        SizedBox(height: sizes.sectionSpacing),
        _buildClockOutImageButton(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildVerificationButtons(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildLocationStatusCard(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildVerifiedByCard(context, controller, screenSize, sizes),
      ],
    );
  }

  Widget _buildVerificationButtons(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: controller.firestoreService.streamAttendanceRecord(
          controller.firestoreService.getUserId()!,
          DateFormat('dd-MMMM-yyyy').format(DateTime.now())),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final attendanceData = snapshot.data!.data();
        if (attendanceData == null) {
          return const SizedBox.shrink();
        }

        final lastAttendance = AttendanceModelFirestore.fromMap(attendanceData);

        // Only show verification buttons if clocked in but not clocked out
        if (lastAttendance.clockIn == "--/--" ||
            lastAttendance.clockOut != "--/--") {
          return const SizedBox.shrink();
        }

        // Hide QR verification buttons after 11:59 AM (i.e., from 12:00 PM onwards)
        // Checks if current hour is 12 or greater.
        if (DateTime.now().hour >= 12) {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                // Navigate directly to QR verification page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QRScannerPage(),
                    ),
                  );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(
                    horizontal: sizes.cardPadding,
                    vertical: sizes.cardInnerSpacing),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(sizes.textFieldBorderRadius),
                ),
              ),
              child: Text(
                "Scan QR to verify",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: sizes.outOfOfficeButtonTextSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Show QR code dialog with real-time listening
                controller.showQRDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(
                    horizontal: sizes.cardPadding,
                    vertical: sizes.cardInnerSpacing),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(sizes.textFieldBorderRadius),
                ),
              ),
              child: Text(
                "Generate QR for verification",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: sizes.outOfOfficeButtonTextSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDayCompletedSection(
      BuildContext context,
      ClockAttendanceWebController controller,
      AttendanceModelFirestore? lastAttendance,
      ScreenSize screenSize,
      sizes) {
    final TextEditingController commentsController = TextEditingController(
        text: lastAttendance?.comments != "No Comment"
            ? lastAttendance?.comments
            : "");
    return Column(
      children: [
        _buildClockInOutDisplay(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildDateAndTime(screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        Text(
          "You have completed this day!!!",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w300,
            fontSize: sizes.dayCompletedTextSize,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: sizes.cardInnerSpacing),
        Obx(() => Text(
              "Duration Worked: ${controller.durationWorked.value}",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w300,
                fontSize: sizes.dayCompletedTextSize,
                color: Colors.black54,
              ),
            )),
        SizedBox(height: sizes.cardInnerSpacing),
        Obx(() => Text(
              "Comment(s): ${controller.comments.value}",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w300,
                fontSize: sizes.dayCompletedTextSize,
                color: Colors.black54,
              ),
            )),
        SizedBox(height: sizes.cardInnerSpacing),
        TextField(
          controller: commentsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Add Comment (Optional)",
            border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(sizes.textFieldBorderRadius)),
            contentPadding: EdgeInsets.all(sizes.textFieldPadding),
          ),
          style: GoogleFonts.poppins(fontSize: sizes.textFieldInputTextSize),
        ),
        SizedBox(height: sizes.cardInnerSpacing),
        Obx(() => controller.comments.value == "No Comment" ||
                controller.comments.value.isEmpty
            ? _buildAddCommentButton(
                context, commentsController, screenSize, sizes)
            : const SizedBox(height: 0)),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildLocationStatusCard(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildVerifiedByCard(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
      ],
    );
  }

  Widget _buildClockInOutDisplay(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return Container(
      margin: EdgeInsets.only(
          top: sizes.clockDisplayTopMargin,
          bottom: sizes.clockDisplayBottomMargin),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black26,
              blurRadius: sizes.clockDisplayShadowBlurRadius,
              offset: const Offset(2, 2)),
        ],
        borderRadius:
            BorderRadius.all(Radius.circular(sizes.clockDisplayBorderRadius)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StreamBuilder<String>(
              stream: controller.clockInStream,
              initialData: controller.clockIn.value,
              builder: (context, snapshot) {
                return _buildClockTimeColumn(
                    "Clock In", snapshot.data ?? "--/--", screenSize, sizes);
              }),
          StreamBuilder<String>(
              stream: controller.clockOutStream,
              initialData: controller.clockOut.value,
              builder: (context, snapshot) {
                return _buildClockTimeColumn(
                    "Clock Out", snapshot.data ?? "--/--", screenSize, sizes);
              }),
        ],
      ),
    );
  }

  Widget _buildClockTimeColumn(
      String title, String time, ScreenSize screenSize, ResponsiveSizes sizes) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: sizes.clockTimeColumnVerticalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w300,
                fontSize: sizes.clockTimeColumnTitleFontSize,
                color: Colors.black54,
              ),
            ),
            Text(
              time,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: sizes.clockTimeColumnTimeFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateAndTime(ScreenSize screenSize, ResponsiveSizes sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: DateTime.now().day.toString(),
            style: GoogleFonts.poppins(
              color: Colors.red,
              fontSize: sizes.dateTextSize,
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(
                text: DateFormat(" MMMM yyyy").format(DateTime.now()),
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: sizes.dateTextSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, snapshot) {
            return Text(
              DateFormat("hh:mm:ss a").format(DateTime.now()),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w300,
                fontSize: sizes.timeTextSize,
                color: Colors.black54,
              ),
            );
          },
        ),
      ],
    );
  }

  // Helper function to check if a given date is the last Thursday of the month
  bool isLastThursdayOfMonth(DateTime date) {
    int year = date.year;
    int month = date.month;
    DateTime lastThursday =
        DateTime(year, month + 1, 0); // Start from the last day of the month

    while (lastThursday.weekday != DateTime.thursday) {
      lastThursday = lastThursday.subtract(const Duration(days: 1));
    }

    // Ensure the last Thursday falls between the 20th and 30th
    return lastThursday.day >= 20 &&
        lastThursday.day <= 31 &&
        date.day == lastThursday.day;
  }

  bool _isLastFridayBetween2ndAnd11th(DateTime date) {
    int year = date.year;
    int month = date.month;
    DateTime lastFriday = DateTime(year, month, 11); // Start from the 11th

    while (lastFriday.weekday != DateTime.friday) {
      lastFriday = lastFriday.subtract(const Duration(days: 1));
    }

    // Ensure the last Friday falls between the 2nd and 11th
    return lastFriday.day >= 2 &&
        lastFriday.day <= 11 &&
        date.day == lastFriday.day;
  }

  Widget _buildClockInImageButton(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return GestureDetector(
      onTap: () async {
        // Check if today is the last Thursday between the 20th and 30th
        DateTime now = DateTime.now();
        // if (isLastThursdayOfMonth(DateTime.now())) {
        //   final hasSurvey = await controller.firestoreService.hasSurveyResponseForToday(controller.firestoreService.getUserId()!);
        //   if (!hasSurvey) {
        //     Fluttertoast.showToast(
        //       msg: "Kindly Fill the Survey Before Clocking In",
        //       toastLength: Toast.LENGTH_LONG,
        //       backgroundColor: Colors.black54,
        //       gravity: ToastGravity.BOTTOM,
        //       timeInSecForIosWeb: 1,
        //       textColor: Colors.white,
        //       fontSize: 16.0,
        //     );
        //     // Navigate to PsychologicalMetricsPage if it's last thursday and no survey
        //     Navigator.pushReplacement(
        //       context,
        //       MaterialPageRoute(

        //     builder: (context) => const PsychologicalMetricsPage(),
        //       ),
        //     );
        //     return;
        //   }
        // }
        await controller.clockInUpdated(
            context,
            controller.lati.value,
            controller.longi.value,
            controller.location.value); // Pass context here
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 1,
        height: sizes.clockButtonHeight,
        child: Image.asset(
          'assets/image/clockin9.jpg',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildClockOutImageButton(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return GestureDetector(
      onTap: () async {
        // Check verification requirements before allowing clock out
        final qrService = QRVerificationService();
        final userId = controller.firestoreService.getUserId();
        final today = DateFormat('dd-MMMM-yyyy').format(DateTime.now());




        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Confirm Clock Out"),
              content: Text("Are you sure you want to clock out?"),
              actions: <Widget>[
                TextButton(
                  child: Text("No"),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                ),
                TextButton(
                  child: Text("Yes"),
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close the dialog
                    await controller.clockOutUpdated(controller.lati.value,
                        controller.longi.value, controller.location.value);
                  },
                ),
              ],
            );
          },
        );
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 1,
        height: sizes.clockButtonHeight,
        child: Image.asset(
          'assets/image/clockout8.jpg',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildOutOfOfficeButton(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return Padding(
        padding: EdgeInsets.symmetric(
            vertical: sizes.outOfOfficeButtonVerticalPadding),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const LeaveRequestsPage1()),
            );
          },
          child: Container(
            width: sizes.outOfOfficeButtonWidth,
            height: sizes.outOfOfficeButtonHeight,
            padding: EdgeInsets.only(
                left: sizes.outOfOfficeButtonLeftPadding, bottom: 0.0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red,
                  Colors.black,
                ],
              ),
              borderRadius: BorderRadius.all(
                Radius.circular(20),
              ),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                "Out Of Office? CLICK HERE",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: sizes.outOfOfficeButtonTextSize),
              ),
              SizedBox(width: sizes.outOfOfficeButtonIconSpacing),
              const Icon(
                Icons.arrow_forward,
                size: 16,
                color: Colors.white,
              ),
            ]),
          ),
        ));
  }

  Widget _buildLocationStatusCard(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return Container(
      width: MediaQuery.of(context).size.width * 1,
      margin: EdgeInsets.all(sizes.locationCardMargin),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red, Colors.black]),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      padding: EdgeInsets.symmetric(
          vertical: sizes.locationCardVerticalPadding,
          horizontal: sizes.locationCardHorizontalPadding),
      child: Column(
        children: [
          Text(
            "Location Status",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: sizes.locationCardHeaderTextSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: sizes.cardInnerSpacing),
          SizedBox(
            width: sizes.locationInnerContentWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildClockInLocationColumn(
                    "Clock-In Location", controller, screenSize, sizes),
                SizedBox(width: sizes.locationColumnSpacing),
                _buildClockOutLocationColumn(
                    "Clock-Out Location", controller, screenSize, sizes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockInLocationColumn(
      String title,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w300,
              fontSize: sizes.locationColumnTitleTextSize,
              color: Colors.white,
            ),
          ),
          SizedBox(height: sizes.cardInnerSpacing),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: controller.firestoreService.streamAttendanceRecord(
                controller.firestoreService.getUserId()!,
                DateFormat('dd-MMMM-yyyy').format(DateTime.now())),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.white));
              } else if (snapshot.hasData && snapshot.data!.exists) {
                final attendanceData = snapshot.data!.data();
                final lastAttendance =
                    AttendanceModelFirestore.fromMap(attendanceData!);
                return Text(
                  lastAttendance.clockInLocation ?? "",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: sizes.locationColumnLocationTextSize,
                    color: Colors.white,
                  ),
                );
              } else {
                return Text(
                  "",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: sizes.locationColumnLocationTextSize,
                    color: Colors.white,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClockOutLocationColumn(
      String title,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w300,
              fontSize: sizes.locationColumnTitleTextSize,
              color: Colors.white,
            ),
          ),
          SizedBox(height: sizes.cardInnerSpacing),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: controller.firestoreService.streamAttendanceRecord(
                controller.firestoreService.getUserId()!,
                DateFormat('dd-MMMM-yyyy').format(DateTime.now())),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.white));
              } else if (snapshot.hasData && snapshot.data!.exists) {
                final attendanceData = snapshot.data!.data();
                final lastAttendance =
                    AttendanceModelFirestore.fromMap(attendanceData!);
                return Text(
                  lastAttendance.clockOutLocation ?? "",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: sizes.locationColumnLocationTextSize,
                    color: Colors.white,
                  ),
                );
              } else {
                return Text(
                  "",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: sizes.locationColumnLocationTextSize,
                    color: Colors.white,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedByCard(
      BuildContext context,
      ClockAttendanceWebController controller,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return Container(
      margin: EdgeInsets.all(sizes.locationCardMargin),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C1A2E), Color(0xFF7D243E)], // Maroon gradient
        ),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
      ),
      padding: EdgeInsets.symmetric(
          vertical: sizes.locationCardVerticalPadding,
          horizontal: sizes.locationCardHorizontalPadding),
      child: Column(
        children: [
          Text(
            "Verified By",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: sizes.locationCardHeaderTextSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: sizes.cardInnerSpacing),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: controller.firestoreService.streamAttendanceRecord(
                controller.firestoreService.getUserId()!,
                DateFormat('dd-MMMM-yyyy').format(DateTime.now())),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(color: Colors.white);
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: sizes.locationColumnLocationTextSize));
              } else if (snapshot.hasData && snapshot.data!.exists) {
                final attendanceData = snapshot.data!.data();
                final lastAttendance =
                    AttendanceModelFirestore.fromMap(attendanceData!);
                final verifiedByNames = lastAttendance.verifiedByUserNames ?? [];
                
                if (verifiedByNames.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(sizes.cardInnerSpacing),
                    child: Text(
                      "No verifications yet",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: sizes.locationColumnLocationTextSize,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                }
                
                return Container(
                  constraints: BoxConstraints(
                    maxWidth: sizes.locationInnerContentWidth,
                  ),
                  child: Column(
                    children: verifiedByNames.map((verifierInfo) {
                      return Container(
                        margin: EdgeInsets.only(bottom: sizes.cardInnerSpacing / 2),
                        padding: EdgeInsets.all(sizes.cardInnerSpacing),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.greenAccent,
                              size: sizes.locationColumnTitleTextSize * 1.2,
                            ),
                            SizedBox(width: sizes.cardInnerSpacing),
                            Expanded(
                              child: Text(
                                verifierInfo,
                                style: GoogleFonts.poppins(
                                  fontSize: sizes.locationColumnLocationTextSize * 0.9,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              } else {
                return Text(
                  "No attendance record for today",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: sizes.locationColumnLocationTextSize,
                    color: Colors.white70,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddCommentButton(
      BuildContext context,
      TextEditingController commentsController,
      ScreenSize screenSize,
      ResponsiveSizes sizes) {
    return GestureDetector(
      onTap: () => Get.find<ClockAttendanceWebController>()
          .handleAddComments(context, commentsController.text),
      child: Container(
        width: sizes.commentButtonWidth,
        height: sizes.commentButtonHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.red, Colors.black]),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Center(
          child: Text(
            "Add Comment",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: sizes.commentButtonTextSize,
            ),
          ),
        ),
      ),
    );
  }
}

class AttendanceModelFirestore {
  int? Offline_DB_id;
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
  String? durationWorked;
  double? noOfHours;
  bool? voided;
  bool? isUpdated;
  bool? offDay;
  String? month;
  String? comments;
  // Verification fields
  String? verificationMethod;
  int? verificationCount;
  bool? verificationRequired;
  List<String>? verifiedByUserIds;
  List<String>? verifiedByUserNames;
  dynamic timestamp;

  AttendanceModelFirestore({
    this.Offline_DB_id,
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
    this.durationWorked,
    this.noOfHours,
    this.voided,
    this.isUpdated,
    this.offDay,
    this.month,
    this.comments,
    // Verification fields
    this.verificationMethod,
    this.verificationCount,
    this.verificationRequired,
    this.verifiedByUserIds,
    this.verifiedByUserNames,
    this.timestamp,
  });

  factory AttendanceModelFirestore.fromMap(Map<String, dynamic> map) {
    return AttendanceModelFirestore(
      Offline_DB_id: map['Offline_DB_id'] as int?,
      clockIn: map['clockIn'] as String?,
      clockOut: map['clockOut'] as String?,
      clockInLocation: map['clockInLocation'] as String?,
      clockOutLocation: map['clockOutLocation'] as String?,
      date: map['date'] as String?,
      isSynced: map['isSynced'] as bool?,
      clockInLatitude: map['clockInLatitude'] as double?,
      clockInLongitude: map['clockInLongitude'] as double?,
      clockOutLatitude: map['clockOutLatitude'] as double?,
      clockOutLongitude: map['clockOutLongitude'] as double?,
      durationWorked: map['durationWorked'] as String?,
      noOfHours: map['noOfHours'] as double?,
      voided: map['voided'] as bool?,
      isUpdated: map['isUpdated'] as bool?,
      offDay: map['offDay'] as bool?,
      month: map['month'] as String?,
      comments: map['comments'] as String?,
      // Verification fields
      verificationMethod: map['verificationMethod'] as String?,
      verificationCount: (map['verificationCount'] as num?)?.toInt(),
      verificationRequired: map['verificationRequired'] as bool?,
      verifiedByUserIds:
          (map['verifiedByUserIds'] as List<dynamic>?)?.cast<String>(),
      verifiedByUserNames:
          (map['verifiedByUserNames'] as List<dynamic>?)?.cast<String>(),
      timestamp: map['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Offline_DB_id': Offline_DB_id,
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
      'durationWorked': durationWorked,
      'noOfHours': noOfHours,
      'voided': voided,
      'isUpdated': isUpdated,
      'offDay': offDay,
      'month': month,
      'comments': comments,
      // Verification fields
      'verificationMethod': verificationMethod,
      'verificationCount': verificationCount,
      'verificationRequired': verificationRequired,
      'verifiedByUserIds': verifiedByUserIds,
      'verifiedByUserNames': verifiedByUserNames,
      'timestamp': timestamp,
    };
  }
}

class ClockAttendanceWebController extends GetxController {
  final FirestoreService firestoreService;
  late List<GeofenceModel> geofenceList = <GeofenceModel>[].obs;
  List<GeofenceModel> cachedGeofences = [];
  StreamSubscription? locationSubscription; // To manage location stream

  ClockAttendanceWebController(this.firestoreService) {
    _init();
  }

  final _clockInOutLock = Lock();

  var isCircularProgressBarOn = true.obs;

  final _clockInStreamController = StreamController<String>.broadcast();
  Stream<String> get clockInStream => _clockInStreamController.stream;

  final _clockOutStreamController = StreamController<String>.broadcast();
  Stream<String> get clockOutStream => _clockOutStreamController.stream;

  final _clockInLocationStreamController = StreamController<String>.broadcast();
  Stream<String> get clockInLocationStream =>
      _clockInLocationStreamController.stream;

  final _clockOutLocationStreamController =
      StreamController<String>.broadcast();
  Stream<String> get clockOutLocationStream =>
      _clockOutLocationStreamController.stream;

  RxString clockIn = "--/--".obs;
  RxString clockOut = "--/--".obs;
  RxString durationWorked = "".obs;
  RxString location = "".obs;
  RxString comments = "No Comment".obs;
  RxString clockInLocation = "".obs;
  RxString clockOutLocation = "".obs;
  RxString role = "".obs;
  RxString firstName = "".obs;
  RxString lastName = "".obs;
  RxString emailAddress = "".obs;
  RxString firebaseAuthId = "".obs;
  RxDouble lati = 0.0.obs;
  RxDouble longi = 0.0.obs;
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
  RxBool isLoading = false.obs;
  RxBool isSliderEnabled = true.obs;
  RxBool isClockedIn = false.obs;

  RxString administrativeArea = "".obs;
  RxString currentStateDisplay = "".obs;
  RxBool isLocationTurnedOn = false.obs;
  Rx<LocationPermission> isLocationPermissionGranted =
      LocationPermission.denied.obs;
  RxBool isAlertSet = false.obs;
  RxBool isAlertSet2 = false.obs;
  RxBool isInsideAnyGeofence = false.obs;
  RxBool isInternetConnected = false.obs;
  RxBool isGpsEnabled = false.obs;

  String currentDate = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
  DateTime ntpTime = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  String _endTime = "11:59 PM";
  String _startTime = DateFormat("hh:mm a").format(DateTime.now()).toString();
  String _reasons = "";
  int _selectedColor = 0;
  var isDeviceConnected = false;
  List<String> reasonsForDayOff = [
    "Holiday",
    "Annual Leave",
    "Sick Leave",
    "Other Leaves",
    "Absent",
    "Travel",
    "Remote Working",
    "Security Crisis"
  ];

  locationPkg.Location locationService = locationPkg.Location();

  @override
  void onInit() {
    super.onInit();
    _loadInitialData();
    initializeLocationAndGeofence(); // Call initialization here in onInit
  }

  @override
  void onClose() {
    _locationTimer?.cancel();
    _clockInStreamController.close();
    _clockOutStreamController.close();
    _clockInLocationStreamController.close();
    _clockOutLocationStreamController.close();
    locationSubscription?.cancel(); // Cancel location stream on close
    super.onClose();
  }

  Future<void> initializeLocationAndGeofence() async {
    await _initLocationServiceAndData();
  }

  Future<void> _initLocationServiceAndData() async {
    await getLocationStatus().then((_) async {
      await _getUserLocation();
      await _getLocation2();
      await _updateLocationUsingGeofencing();
      await getPermissionStatus().then((_) async {
        await _startLocationService().then((_) async {
          await _getLocation2();
          // await _getUserLocation1();
          await _getUserLocation();
          await _updateLocationUsingGeofencing();
          await _loadInitialData(); // Load other data after location is ready
        });
      });
    });
  }

  void _clearLocationData() {
    lati.value = 0.0;
    longi.value = 0.0;
    accuracy.value = 0.0;
    altitude.value = 0.0;
    speed.value = 0.0;
    speedAccuracy.value = 0.0;
    heading.value = 0.0;
    time.value = 0.0;
    isMock.value = false;
    verticalAccuracy.value = 0.0;
    headingAccuracy.value = 0.0;
    elapsedRealtimeNanos.value = 0.0;
    elapsedRealtimeUncertaintyNanos.value = 0.0;
    location.value = "";
    administrativeArea.value = "";
    currentStateDisplay.value = "";
    isInsideAnyGeofence.value = false;
  }

  Future<void> _loadInitialData() async {
    await _loadNTPTime();
    await _getAttendanceSummary();
    await _getUserDetail();
    await _fetchGeofenceLocations();
    await checkInternetConnection();
  }

  Future<void> _init() async {
    // No need to call _initLocationServiceAndData here anymore, called from initializeLocationAndGeofence
  }

  Timer? _locationTimer;

  Future<void> _getLocationDetailsFromLocationModel() async {
    print(
        "getLocationDetailsFromLocationModel is skipped for web in this example");
  }

  Future<void> _updateLocationUsingGeofencing() async {
    if (lati.value != 0.0) {
      String geofencedLocationName =
          await _determineGeofenceLocation(lati.value, longi.value);
      if (geofencedLocationName.isNotEmpty) {
        location.value = geofencedLocationName;
        isInsideAnyGeofence.value = true;
      } else {
        isInsideAnyGeofence.value = false;
        currentStateDisplay.value = administrativeArea.value;
      }
    }
  }

  Future<void> _updateLocationUsingGeofencing2(
      double latitde, double longitde) async {
    print("_updateLocationUsingGeofencing2 is skipped for web in this example");
  }

  Future<String?> _getUserState() async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;

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

  Future<String> _determineGeofenceLocation(
      double latitude, double longitude) async {
    String geofenceName = "";
    String? userState = await _getUserState();

    for (GeofenceModel geofence in cachedGeofences) {
      double distance = GeoUtils.haversine(
          latitude, longitude, geofence.latitude, geofence.longitude);
      if (distance <= geofence.radius) {
        currentStateDisplay.value = (geofence.stateName == userState)
            ? geofence.name
            : geofence.stateName;
        return geofence.name;
      }
    }

    currentStateDisplay.value = userState ??
        (administrativeArea.value.isNotEmpty
            ? administrativeArea.value
            : "State Unknown");
    return geofenceName;
  }

  String? getUserId() {
    print("Current UUID === ${FirebaseAuth.instance.currentUser?.uid}");
    return FirebaseAuth.instance.currentUser?.uid;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAttendanceRecord(
      String userId, String date) {
    return FirebaseFirestore.instance
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getAttendanceRecord(
      String userId, String date) async {
    return await FirebaseFirestore.instance
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .get();
  }

  Future<void> createAttendanceRecord(
      String userId, String date, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .set(data);
  }

  Future<void> updateAttendanceRecord(
      String userId, String date, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .update(data);
  }

  Future<String?> getUserState() async {
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('Staff')
        .doc(getUserId())
        .get();
    if (userSnapshot.exists) {
      Map<String, dynamic>? userData =
          userSnapshot.data() as Map<String, dynamic>?;
      return userData?['state'] as String?;
    }
    return null;
  }

  Future<List<String>> getAllStates() async {
    List<String> states = [];
    try {
      QuerySnapshot locationSnapshot =
          await FirebaseFirestore.instance.collection('Location').get();
      for (var doc in locationSnapshot.docs) {
        states.add(doc.id);
      }
    } catch (e) {
      dev.log("Error fetching states: $e");
    }
    return states;
  }

  Future<List<GeofenceModel>> getGeofencesForState(String state) async {
    List<GeofenceModel> geofenceLocations = [];
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('Location')
          .doc(state)
          .collection(state)
          .get();

      for (var doc in snapshot.docs) {
        geofenceLocations.add(GeofenceModel.fromFirestore(doc.data(), state));
      }
      dev.log("geofenceLocations =$geofenceLocations");
    } catch (e) {
      dev.log("Error fetching geofences for state $state: $e");
    }
    return geofenceLocations;
  }

  Future<List<GeofenceModel>> getGeofencesForAllStatesExceptCurrent(
      String currentState) async {
    List<GeofenceModel> allGeofences = [];
    List<String> allStates = await getAllStates();

    for (String state in allStates) {
      if (state != currentState) {
        allGeofences.addAll(await getGeofencesForState(state));
      }
    }
    return allGeofences;
  }

  Future<void> _fetchGeofenceLocations() async {
    String? userState = await _getUserState();
    if (userState != null) {
      dev.log("User state found==$userState");
      List<GeofenceModel> currentStateGeofences =
          await firestoreService.getGeofencesForState(userState);
      cachedGeofences.addAll(currentStateGeofences);

      List<GeofenceModel> otherStatesGeofences = await firestoreService
          .getGeofencesForAllStatesExceptCurrent(userState);
      cachedGeofences.addAll(otherStatesGeofences);

      dev.log("cachedGeofences count==${cachedGeofences.length}");
    } else {
      dev.log("User state not found, geofencing might not work correctly.");
      List<String> allStates = await firestoreService.getAllStates();
      for (String state in allStates) {
        List<GeofenceModel> stateGeofences =
            await firestoreService.getGeofencesForState(state);
        cachedGeofences.addAll(stateGeofences);
      }
    }
  }

  Future<void> _loadNTPTime1() async {
    try {
      ntpTime = await NTP.now(lookUpAddress: "pool.ntp.org");
    } catch (e) {
      dev.log("Error getting NTP time: ${e.toString()}");
      ntpTime = DateTime.now();
    }
  }

  Future<void> _getUserDetail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      firebaseAuthId.value = user.uid;
      emailAddress.value = user.email ?? "";
      dev.log("_getUserDetail ==$user");

      // Try to split displayName into first and last name
      final nameParts = (user.displayName ?? "").split(' ');
      if (nameParts.length > 1) {
        firstName.value = nameParts.first;
        lastName.value = nameParts.sublist(1).join(' ');
      } else {
        firstName.value = user.displayName ?? "";
        lastName.value = "";
      }

      // Fetch real designation from Firestore
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('Staff')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          role.value = userDoc.data()?['designation'] ?? 'Staff';
          // Also update first/last name if available in Firestore
          firstName.value = userDoc.data()?['firstName'] ?? firstName.value;
          lastName.value = userDoc.data()?['lastName'] ?? lastName.value;
        } else {
          role.value = "User";
        }
      } catch (e) {
        dev.log("Error fetching user designation: $e");
        role.value = "User";
      }
    }
  }

  Future<void> _getAttendanceSummary() async {
    try {
      final attendanceData = await getLastAttendanceForDateFirestore(
              DateFormat('dd-MMMM-yyyy').format(DateTime.now()))
          .get();

      if (attendanceData.exists) {
        AttendanceModelFirestore lastAttendance =
            AttendanceModelFirestore.fromMap(attendanceData.data()!);

        clockIn.value = lastAttendance.clockIn ?? "--/--";
        clockOut.value = lastAttendance.clockOut ?? "--/--";
        clockInLocation.value = lastAttendance.clockInLocation ?? "";
        clockOutLocation.value = lastAttendance.clockOutLocation ?? "";
        durationWorked.value = lastAttendance.durationWorked ?? "";
        comments.value = lastAttendance.comments ?? "No Comment";
        isClockedIn.value = lastAttendance.clockIn != "--/--" &&
            lastAttendance.clockOut == "--/--";

        _clockInStreamController.add(clockIn.value);
        _clockOutStreamController.add(clockOut.value);
        _clockInLocationStreamController.add(clockInLocation.value);
        _clockOutLocationStreamController.add(clockOutLocation.value);
      } else {
        clockIn.value = "--/--";
        clockOut.value = "--/--";
        clockInLocation.value = "";
        clockOutLocation.value = "";
        durationWorked.value = "";
        comments.value = "No Comment";
        isClockedIn.value = false;

        _clockInStreamController.add(clockIn.value);
        _clockOutStreamController.add(clockOut.value);
        _clockInLocationStreamController.add(clockInLocation.value);
        _clockOutLocationStreamController.add(clockOutLocation.value);
      }
    } catch (e) {
      dev.log("Error in _getAttendanceSummary: ${e.toString()}");
    }
  }

  Future<void> _startLocationService() async {
    bool serviceEnabled = await locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationService.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    locationPkg.PermissionStatus permission =
        await locationService.requestPermission();
    if (permission != locationPkg.PermissionStatus.granted) {
      return;
    }

    // Cancel any existing subscription before starting a new one
    locationSubscription?.cancel();
    _getLocation2();
  }

  Future<geolocator.Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await geolocator.Geolocator.checkPermission();
    permission = await geolocator.Geolocator
        .requestPermission(); // Request permission every time
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    try {
      // Attempt 1: Medium accuracy (balanced for mobile/desktop) with 30s timeout
      return await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 30));
    } catch (e) {
      dev.log("Medium accuracy location failed: $e");
      try {
        // Attempt 2: Low accuracy (IP/Cell based) with 45s timeout - better for laptops
        return await geolocator.Geolocator.getCurrentPosition(
            desiredAccuracy: geolocator.LocationAccuracy.low,
            timeLimit: const Duration(seconds: 45));
      } catch (e) {
         dev.log("Low accuracy location failed: $e");
         return null;
      }
    }
  }

  void _getUserLocation1() async {
    print("Geolocator Dependency here");
    try {
      geolocator.Position? position = await getCurrentLocation();
      if (position != null) {
        print(
            'Latitude: ${position.latitude}, Longitude: ${position.longitude}');

        lati.value = position.latitude;
        longi.value = position.longitude;

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark placemark = placemarks[0];
          location.value =
              "${placemark.street},${placemark.subLocality},${placemark.subAdministrativeArea},${placemark.locality},${placemark.administrativeArea},${placemark.postalCode},${placemark.country}";
          administrativeArea.value = placemark.administrativeArea!;
        } else {
          location.value = "Location not found";
          administrativeArea.value = "";
          await _updateLocationUsingGeofencing2(
              position.latitude, position.longitude);
        }

        if (administrativeArea.value != '') {
          isInsideAnyGeofence.value = false;

          if (!isInsideAnyGeofence.value) {
            List<Placemark> placemark = await placemarkFromCoordinates(
                position.latitude, position.longitude);

            location.value =
                "${placemark[0].street},${placemark[0].subLocality},${placemark[0].subAdministrativeArea},${placemark[0].locality},${placemark[0].administrativeArea},${placemark[0].postalCode},${placemark[0].country}";
          }
        } else if (administrativeArea.value == '' && location.value != 0.0) {
          await _updateLocationUsingGeofencing();
        } else {
          List<Placemark> placemark = await placemarkFromCoordinates(
              position.latitude, position.longitude);

          location.value =
              "${placemark[0].street},${placemark[0].subLocality},${placemark[0].subAdministrativeArea},${placemark[0].locality},${placemark[0].administrativeArea},${placemark[0].postalCode},${placemark[0].country}";
        }
      }
    } catch (e) {
      if (lati.value != 0.0 && administrativeArea.value == '') {
        await _updateLocationUsingGeofencing();
      } else if (lati.value == 0.0 && administrativeArea.value == '') {
        Timer(const Duration(seconds: 10), () async {
          if (lati.value == 0.0 && longi.value == 0.0) {
            print("Location not obtained within 10 seconds. Using default1.");
            _getLocationDetailsFromLocationModel();
          }
        });
      } else {
        dev.log('Error getting location: $e');
        // Fluttertoast.showToast(
        //   msg: "Error getting location: $e",a
        //   toastLength: Toast.LENGTH_LONG,
        //   backgroundColor: Colors.black54,
        //   gravity: ToastGravity.BOTTOM,
        //   timeInSecForIosWeb: 1,
        //   textColor: Colors.white,
        //   fontSize: 16.0,
        // );
      }
    }
  }

  Future<void> _getLocation2() async {
    try {
      print("_getLocation2 hereeeee");
      locationSubscription =
          locationService.onLocationChanged // Assign subscription here
              .listen((locationPkg.LocationData? locationData) async {
        if (locationData != null &&
            locationData.latitude != null &&
            locationData.longitude != null) {
          
          // Ignore 0.0, 0.0 which can happen on initialization or error
          if (locationData.latitude == 0.0 && locationData.longitude == 0.0) {
             return;
          }

          lati.value = locationData.latitude!;
          longi.value = locationData.longitude!;
          accuracy.value = locationData.accuracy ?? 0.0;
          altitude.value = locationData.altitude ?? 0.0;
          speed.value = locationData.speed ?? 0.0;
          speedAccuracy.value = locationData.speedAccuracy ?? 0.0;
          heading.value = locationData.heading ?? 0.0;
          time.value = locationData.time ?? 0.0;
          isMock.value = locationData.isMock ?? false;
          verticalAccuracy.value = locationData.verticalAccuracy ?? 0.0;
          headingAccuracy.value = locationData.headingAccuracy ?? 0.0;
          elapsedRealtimeNanos.value = locationData.elapsedRealtimeNanos ?? 0.0;
          elapsedRealtimeUncertaintyNanos.value =
              locationData.elapsedRealtimeUncertaintyNanos ?? 0.0;

          _getUserLocation();
          _getAttendanceSummary();
        } else {
          print("_getLocation2: Received null location data");
        }
      }, onError: (e) {
        dev.log("_getLocation2 stream error: $e");
        if (e is Exception &&
            e.toString().contains('kCLErrorLocationUnknown')) {
          print("Location Unknown Error detected, retrying...");
          _getUserLocation();
        } else {
          print("_getLocation2: General error: $e");
        }
      });
    } catch (e) {
      print("_getLocation2 Error:$e");
      print("No internet to get location data, trying Geolocator...");
      try {
        geolocator.Position? position =
            await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.high,
          forceAndroidLocationManager: true,
        );

        lati.value = position.latitude;
        longi.value = position.longitude;
        print("locationData.latitude == ${position.latitude}");
        _getUserLocation();
      } catch (geolocatorError) {
        print(
            "_getLocation2: Error getting location from geolocator: $geolocatorError");
      }
    }
  }

  // Future<void> _updateLocation() async {
  //   try {
  //     List<Placemark> placemarks = await placemarkFromCoordinates(
  //       lati.value,
  //       longi.value,
  //     );
  //
  //     if (placemarks.isNotEmpty) {
  //       Placemark placemark = placemarks[0];
  //       location.value =
  //       "${placemark.street},${placemark.subLocality},${placemark.subAdministrativeArea},${placemark.locality},${placemark.administrativeArea},${placemark.postalCode},${placemark.country}";
  //       administrativeArea.value = placemark.administrativeArea!;
  //     } else {
  //       location.value = "Location not found";
  //       administrativeArea.value = "";
  //     }
  //
  //     String geofenceLocationName =
  //     await _determineGeofenceLocation(lati.value, longi.value);
  //     if (geofenceLocationName.isNotEmpty) {
  //       location.value = geofenceLocationName;
  //       isInsideAnyGeofence.value = true;
  //     } else {
  //       // Use placemarker address if not in geofence
  //       location.value = location.value.isNotEmpty && location.value != "Location not found"
  //           ? location.value
  //           : "Location not found"; // Fallback if placemarker also failed
  //       isInsideAnyGeofence.value = false;
  //       currentStateDisplay.value = administrativeArea.value.isNotEmpty
  //           ? administrativeArea.value
  //           : "State Unknown";
  //     }
  //     isCircularProgressBarOn.value = false;
  //   } catch (e) {
  //     currentStateDisplay.value = administrativeArea.value.isNotEmpty
  //         ? administrativeArea.value
  //         : "State Unknown";
  //     if (lati.value != 0.0 && administrativeArea.value == '') {
  //       await _updateLocationUsingGeofencing();
  //     } else if (lati.value == 0.0 && administrativeArea.value == '') {
  //       print("Location not obtained within 10 seconds.");
  //       Timer(const Duration(seconds: 10), () {
  //         if (lati.value == 0.0 && longi.value == 0.0) {
  //           print("Location not obtained within 10 seconds. Using default.");
  //           _getLocationDetailsFromLocationModel();
  //         }
  //       });
  //     } else {
  //       dev.log("$e");
  //       Fluttertoast.showToast(
  //         msg: "UpdateLocation Error: $e",
  //         toastLength: Toast.LENGTH_LONG,
  //         backgroundColor: Colors.black54,
  //         gravity: ToastGravity.BOTTOM,
  //         timeInSecForIosWeb: 1,
  //         textColor: Colors.white,
  //         fontSize: 16.0,
  //       );
  //     }
  //   }
  // }

  Future<void> getLocationStatus() async {
    bool isLocationEnabled =
        await geolocator.Geolocator.isLocationServiceEnabled();
    isLocationTurnedOn.value = isLocationEnabled;

    if (!isLocationTurnedOn.value && !isAlertSet.value) {
      showDialogBox();
      isAlertSet.value = true;
    }
    isGpsEnabled.value = isLocationEnabled;
  }

  Future<void> getPermissionStatus() async {
    LocationPermission permission =
        await geolocator.Geolocator.checkPermission();
    permission = await geolocator.Geolocator
        .requestPermission(); // Request permission every time

    isLocationPermissionGranted.value = permission;

    if (isLocationPermissionGranted.value == LocationPermission.denied ||
        isLocationPermissionGranted.value == LocationPermission.deniedForever) {
      isAlertSet2.value = true;
    }
  }

  Future<void> checkInternetConnection() async {}

  Future<void> handleAddComments(
      BuildContext context, String? commentsForAttendance) async {
    try {
      final attendanceResult = getLastAttendanceForDateFirestore(
          DateFormat('dd-MMMM-yyyy').format(DateTime.now()));
      final attendanceData = await attendanceResult.get();

      if (attendanceData.exists) {
        AttendanceModelFirestore lastAttendance =
            AttendanceModelFirestore.fromMap(attendanceData.data()!);
        if (lastAttendance.date ==
            DateFormat('dd-MMMM-yyyy').format(DateTime.now())) {
          await addComments(DateFormat('dd-MMMM-yyyy').format(DateTime.now()),
              commentsForAttendance!);
        }
      }
    } catch (e) {
      dev.log("Attendance Comment Error ====== ${e.toString()}");
    }
  }

  Future<void> addComments(
      String attendanceDate, String commentsForAttendance) async {
    String? userId = firestoreService.getUserId();
    if (userId == null) {
      return;
    }

    await firestoreService.updateAttendanceRecord(
        userId, attendanceDate, {'comments': commentsForAttendance});

    comments.value = commentsForAttendance;

    Fluttertoast.showToast(
      msg: "Adding Comments..",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.black54,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<DateTime> getGoogleServerTime() async {
    try {
      final response = await http.head(Uri.parse(
          'https://time.google.com')); // Use http package for web compatibility

      if (response.headers.containsKey('date')) {
        final serverDate = response.headers['date'];
        if (serverDate != null) {
          return DateTime.parse(serverDate);
        }
      }
      // If 'date' header is missing or invalid, fallback to device time, or handle as needed
      print(
          "Warning: 'date' header missing or invalid. Falling back to device time.");
      return DateTime.now(); // Fallback to device time if header is not found
    } catch (e) {
      print("Error fetching server time: $e. Falling back to device time.");
      return DateTime.now(); // Fallback to device time on error
    }
  }

  Future<void> _loadNTPTime() async {
    try {
      ntpTime = await getGoogleServerTime(); // Use the new function
    } catch (e) {
      dev.log("Error getting server time: ${e.toString()}");
      ntpTime = DateTime.now();
    }
  }

  Future<void> clockInUpdated(BuildContext context, double newlatitude,
      double newlongitude, String newlocation) async {
    print("clockInUpdated");

    if (!isLoading.value) {
      await _clockInOutLock.synchronized(() async {
        try {
          // Location Validation: Check if location is available
          if (location.value.isEmpty ||
              location.value == "Location not found") {
            Fluttertoast.showToast(
              msg:
                  "Current Location is not available. Please wait and try again.",
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: Colors.redAccent,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            return; // Prevent saving if location is not available
          }

          currentDate = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
          String? userId = firestoreService.getUserId();

          if (userId == null) {
            return;
          }

          final attendanceData =
              await getLastAttendanceForDateFirestore(currentDate).get();

          if (!attendanceData.exists) {
            if (newlatitude != 0.0) {
              DateTime ntpClockInTime;
              try {
                ntpClockInTime =
                    await getGoogleServerTime(); // Get server time for clock-in
              } catch (e) {
                dev.log(
                    "Error getting server time for clock-in: $e, using device time.");
                ntpClockInTime = DateTime.now(); // Fallback to device time
              }
              final clockInTimeFormatted =
                  DateFormat('hh:mm a').format(ntpClockInTime);

              final attendance = AttendanceModelFirestore(
                Offline_DB_id: Random().nextInt(300) + 1,
                clockIn:
                    clockInTimeFormatted, // Use server time or device time if server fails
                date: currentDate,
                clockInLatitude: newlatitude,
                clockInLocation: location.value, // Use validated location.value
                clockInLongitude: newlongitude,
                clockOut: "--/--",
                clockOutLatitude: 0.0,
                clockOutLocation: '',
                clockOutLongitude: 0.0,
                isSynced: true,
                voided: false,
                isUpdated: false,
                durationWorked: "0 hours 0 minutes",
                noOfHours: 0.0,
                offDay: false,
                month: DateFormat('MMMM yyyy').format(DateTime.now()),
                comments: "No Comment",
                // Verification fields
                verificationMethod: "qr",
                verificationCount: 0,
                verificationRequired: true,
                verifiedByUserIds: [],
                verifiedByUserNames: [],
              ).toMap();

              await firestoreService.createAttendanceRecord(
                  userId, currentDate, attendance);

              clockIn.value =
                  clockInTimeFormatted; // Update UI with server time or device time
              clockInLocation.value = location.value;
              isClockedIn.value = true;
              _clockInStreamController.add(clockIn.value);
              _clockInLocationStreamController.add(location.value);

              Fluttertoast.showToast(
                msg: "Clocking-In..",
                toastLength: Toast.LENGTH_LONG,
                backgroundColor: Colors.black54,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                textColor: Colors.white,
                fontSize: 16.0,
              );
            } else {
              Fluttertoast.showToast(
                msg: "Latitude and Longitude cannot be 0.0..",
                toastLength: Toast.LENGTH_LONG,
                backgroundColor: Colors.black54,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                textColor: Colors.white,
                fontSize: 16.0,
              );
            }
          } else {
            AttendanceModelFirestore lastAttendance =
                AttendanceModelFirestore.fromMap(attendanceData.data()!);

            if (lastAttendance.date != currentDate) {
              final clockInDateTime = DateFormat('dd-MMMM-yyyy hh:mm a')
                  .parse('${lastAttendance.date} ${lastAttendance.clockIn}');

              final now = DateTime.now();
              final difference = now.difference(clockInDateTime);

              if (difference < const Duration(hours: 1)) {
                Fluttertoast.showToast(
                  msg: "You can clock out after 1 hour",
                  toastLength: Toast.LENGTH_LONG,
                  backgroundColor: Colors.black54,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
                isLoading.value = false;
              } else {
                if (lastAttendance.clockIn ==
                    DateFormat('hh:mm a').format(DateTime.now())) {
                  Fluttertoast.showToast(
                      msg: "You cannot clock in and clock out the same time",
                      toastLength: Toast.LENGTH_LONG,
                      backgroundColor: Colors.black54,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      textColor: Colors.white,
                      fontSize: 16.0);
                  isLoading.value = false;
                } else {
                  if (newlatitude != 0.0) {
                    DateTime ntpClockInTime;
                    try {
                      ntpClockInTime =
                          await getGoogleServerTime(); // Get server time for clock-in
                    } catch (e) {
                      dev.log(
                          "Error getting server time for clock-in: $e, using device time.");
                      ntpClockInTime =
                          DateTime.now(); // Fallback to device time
                    }
                    final clockInTimeFormatted =
                        DateFormat('hh:mm a').format(ntpClockInTime);

                    final attendance = AttendanceModelFirestore(
                      Offline_DB_id: Random().nextInt(300) + 1,
                      clockIn:
                          clockInTimeFormatted, // Use NTP time or device time if server fails
                      date: currentDate,
                      clockInLatitude: newlatitude,
                      clockInLocation:
                          location.value, // Use validated location.value
                      clockInLongitude: newlongitude,
                      clockOut: "--/--",
                      clockOutLatitude: 0.0,
                      clockOutLocation: '',
                      clockOutLongitude: 0.0,
                      isSynced: true,
                      voided: false,
                      isUpdated: false,
                      durationWorked: "0 hours 0 minutes",
                      noOfHours: 0.0,
                      offDay: false,
                      month: DateFormat('MMMM yyyy').format(DateTime.now()),
                      comments: "No Comment",
                      // Verification fields
                      verificationMethod: "qr",
                      verificationCount: 0,
                      verificationRequired: true,
                      verifiedByUserIds: [],
                      verifiedByUserNames: [],
                    ).toMap();

                    await firestoreService.createAttendanceRecord(
                        userId, currentDate, attendance);
                    clockIn.value =
                        clockInTimeFormatted; // Update UI with NTP time or device time
                    clockInLocation.value = location.value;
                    isClockedIn.value = true;

                    _clockInStreamController.add(
                        clockInTimeFormatted); // Use NTP time or device time if server fails
                    _clockInLocationStreamController.add(location.value);
                    Fluttertoast.showToast(
                      msg: "Clocking-In..",
                      toastLength: Toast.LENGTH_LONG,
                      backgroundColor: Colors.black54,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  } else {
                    Fluttertoast.showToast(
                      msg: "Latitude and Longitude cannot be 0.0..",
                      toastLength: Toast.LENGTH_LONG,
                      backgroundColor: Colors.black54,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  }

                  await _getAttendanceSummary();
                }
              }
            }
          }
        } catch (e) {
          Fluttertoast.showToast(
            msg: "Error from clock in: $e",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      });
    }
  }

  Future<void> clockOutUpdated(
      double newlatitude, double newlongitude, String newlocation) async {
    print("clockOutUpdated");

    if (!isLoading.value) {
      await _clockInOutLock.synchronized(() async {
        try {
          // Location Validation: Check if location is available
          if (location.value.isEmpty ||
              location.value == "Location not found") {
            Fluttertoast.showToast(
              msg:
                  "Current Location is not available. Please wait and try again.",
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: Colors.redAccent,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            return; // Prevent saving if location is not available
          }

          currentDate = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
          String? userId = firestoreService.getUserId();
          if (userId == null) {
            return;
          }

          final attendanceData =
              await getLastAttendanceForDateFirestore(currentDate).get();

          if (attendanceData.exists) {
            AttendanceModelFirestore lastAttendance =
                AttendanceModelFirestore.fromMap(attendanceData.data()!);

            if (lastAttendance.date == currentDate &&
                lastAttendance.clockOut == "--/--") {
              final clockInDateTime = DateFormat('dd-MMMM-yyyy hh:mm a')
                  .parse('${lastAttendance.date} ${lastAttendance.clockIn}');

              final now = DateTime.now();
              final difference = now.difference(clockInDateTime);

              if (difference < const Duration(hours: 1)) {
                Fluttertoast.showToast(
                  msg: "You can clock out after 1 hour",
                  toastLength: Toast.LENGTH_LONG,
                  backgroundColor: Colors.black54,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
                isLoading.value = false;
              } else {
                if (lastAttendance.clockIn ==
                    DateFormat('hh:mm a').format(DateTime.now())) {
                  Fluttertoast.showToast(
                      msg: "You cannot clock in and clock out the same time",
                      toastLength: Toast.LENGTH_LONG,
                      backgroundColor: Colors.black54,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      textColor: Colors.white,
                      fontSize: 16.0);
                  isLoading.value = false;
                } else {
                  if (newlatitude != 0.0) {
                    DateTime ntpClockOutTime;
                    try {
                      ntpClockOutTime =
                          await getGoogleServerTime(); // Get server time for clock-out
                    } catch (e) {
                      dev.log(
                          "Error getting server time for clock-out: $e, using device time.");
                      ntpClockOutTime =
                          DateTime.now(); // Fallback to device time
                    }
                    final clockOutTimeFormatted =
                        DateFormat('hh:mm a').format(ntpClockOutTime);

                    Map<String, dynamic> updateData = {
                      'clockOut':
                          clockOutTimeFormatted, // Use NTP time or device time if server fails
                      'clockOutLatitude': newlatitude,
                      'clockOutLongitude': newlongitude,
                      'clockOutLocation':
                          location.value, // Use validated location.value
                      'isUpdated': true,
                      'durationWorked': _diffClockInOut(
                          lastAttendance.clockIn.toString(),
                          clockOutTimeFormatted), // Use NTP formatted time or device time if server fails
                      'noOfHours': _diffHoursWorked(
                          lastAttendance.clockIn.toString(),
                          clockOutTimeFormatted), // Use NTP formatted time or device time if server fails
                    };

                    await firestoreService.updateAttendanceRecord(
                      userId,
                      currentDate,
                      updateData,
                    );

                    clockOut.value =
                        clockOutTimeFormatted; // Update UI with NTP time or device time
                    clockOutLocation.value = location.value;
                    isClockedIn.value = false;

                    _clockOutStreamController.add(
                        clockOutTimeFormatted); // Use NTP time or device time if server fails
                    _clockOutLocationStreamController.add(location.value);
                    Fluttertoast.showToast(
                      msg: "Clocking-Out..",
                      toastLength: Toast.LENGTH_LONG,
                      backgroundColor: Colors.black54,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                    Get.off(() => const UserDashboardPage());
                  } else {
                    Fluttertoast.showToast(
                      msg: "Latitude and Longitude cannot be 0.0..",
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

          await _getAttendanceSummary();
        } catch (e) {
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
      });
    }
  }

  Future<String?> showDialogBox() => showCupertinoDialog<String>(
        context: Get.context!,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text("Location Turned Off"),
          content:
              Text("Please turn on your location to ClockIn and Out"),
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
              child: Text("OK"),
            ),
          ],
        ),
      );

  String _diffClockInOut(String clockInTime, String clockOutTime) {
    try {
      var format = DateFormat("h:mm a");
      var clockTimeIn = format.parse(clockInTime);
      var clockTimeOut = format.parse(clockOutTime);

      if (clockTimeIn.isAfter(clockTimeOut)) {
        clockTimeOut = clockTimeOut.add(const Duration(days: 1));
      } else if (clockInTime == "--/--" || clockOutTime == "--/--") {
        return "0 hour(s) 0 minute(s)";
      }

      Duration diff = clockTimeOut.difference(clockTimeIn);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;

      dev.log('$hours hours $minutes minute');
      return ('$hours hour(s) $minutes minute(s)');
    } catch (e) {
      return "0 hour(s) 0 minute(s)";
    }
  }

  double _diffHoursWorked(String clockInTime, String clockOutTime) {
    try {
      var format = DateFormat("h:mm a");
      var clockTimeIn = format.parse(clockInTime);
      var clockTimeOut = format.parse(clockOutTime);
      if (clockTimeIn.isAfter(clockTimeOut)) {
        clockTimeOut = clockTimeOut.add(const Duration(days: 1));
      }

      Duration diff = clockOutTime.isEmpty || clockInTime.isEmpty
          ? const Duration(minutes: 0)
          : clockTimeOut.difference(clockTimeIn);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      final minCal = minutes / 60;
      String inStringMin = minCal.toStringAsFixed(3);
      double roundedMinDouble = double.parse(inStringMin);
      final totalTime = hours + roundedMinDouble;

      dev.log('$hours hours $minutes minutes');
      return totalTime;
    } catch (e) {
      return 0.0;
    }
  }

  DocumentReference<Map<String, dynamic>> getLastAttendanceForDateFirestore(
      String date) {
    String? userId = firestoreService.getUserId();
    if (userId == null) {
      throw Exception("User not logged in");
    }
    return FirebaseFirestore.instance
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date);
  }

  void showBottomSheet3(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    final ClockAttendanceWebController controller =
        Get.find<ClockAttendanceWebController>();
    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.only(left: 20, right: 20),
            width: screenWidth,
            height: screenHeight * 0.65,
            color: Colors.white,
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Out Of Office?",
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth / 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Obx(() => Text(
                        "Current Latitude: ${controller.lati.value.toStringAsFixed(6)}, Current Longitude: ${controller.longi.value.toStringAsFixed(6)}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth / 23,
                        ),
                      )),
                  const SizedBox(height: 10),
                  IntrinsicWidth(
                    child: Obx(() => Text(
                          "Current State: ${controller.administrativeArea.value}",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: screenWidth / 23,
                          ),
                        )),
                  ),
                  const SizedBox(height: 10),
                  Obx(() => Text(
                        "Current Location: ${controller.location.value}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth / 23,
                        ),
                      )),
                  const SizedBox(height: 10),
                  _buildInputFieldBottomSheet(
                      "Date",
                      DateFormat("dd/MM/yyyy").format(_selectedDate),
                      IconButton(
                        onPressed: () {
                          _getDateFromUser(setState);
                        },
                        icon: const Icon(Icons.calendar_today_outlined,
                            color: Colors.grey),
                      )),
                  _buildDropdownInputFieldBottomSheet(
                      "Reasons For Day off", _reasons, reasonsForDayOff,
                      (String? newValue) {
                    setState(() {
                      _reasons = newValue!;
                    });
                  }),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputFieldBottomSheet(
                            "Start Time",
                            _startTime,
                            IconButton(
                              onPressed: () {
                                _getTimeFromUser(
                                    isStartTime: true, setState: setState);
                              },
                              icon: const Icon(Icons.access_time_rounded,
                                  color: Colors.grey),
                            )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputFieldBottomSheet(
                            "End Time",
                            _endTime,
                            IconButton(
                              onPressed: () {
                                _getTimeFromUser(
                                    isStartTime: false, setState: setState);
                              },
                              icon: const Icon(Icons.access_time_rounded,
                                  color: Colors.grey),
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Color",
                            style: GoogleFonts.poppins(
                              color:
                                  Get.isDarkMode ? Colors.white : Colors.black,
                              fontSize: screenWidth / 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.start,
                            children: List<Widget>.generate(3, (int index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedColor = index;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: index == 0
                                        ? Colors.red
                                        : index == 1
                                            ? Colors.blueAccent
                                            : Colors.yellow,
                                    child: _selectedColor == index
                                        ? const Icon(Icons.done,
                                            color: Colors.white, size: 16)
                                        : Container(),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _validateData(context),
                        child: Container(
                          width: 120,
                          height: 60,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Colors.red, Colors.black]),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Center(
                            child: Text(
                              "Submit",
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildInputFieldBottomSheet(String title, String hint, Widget widget) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Get.textTheme.titleSmall),
          Container(
            height: 52,
            margin: const EdgeInsets.only(top: 8.0),
            padding: const EdgeInsets.only(left: 14, right: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 1.0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(hint, style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                widget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownInputFieldBottomSheet(String title, String hint,
      List<String> items, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Get.textTheme.titleSmall),
          Container(
            height: 52,
            margin: const EdgeInsets.only(top: 8.0),
            padding: const EdgeInsets.only(left: 14, right: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 1.0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: hint.isNotEmpty ? hint : null,
                    hint: Text(hint.isEmpty ? "Select Reason" : hint,
                        style: GoogleFonts.poppins(color: Colors.grey)),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey),
                    iconSize: 32,
                    elevation: 4,
                    style: GoogleFonts.poppins(
                        color: Get.isDarkMode ? Colors.white : Colors.black),
                    underline: Container(height: 0),
                    onChanged: onChanged,
                    items: items.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value,
                            style: GoogleFonts.poppins(
                                color: Get.isDarkMode
                                    ? Colors.white
                                    : Colors.black)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _validateData(BuildContext context) {
    if (_reasons.isNotEmpty) {
      //_addDaysOffToDb();
      Get.back();
    } else if (_reasons.isEmpty) {
      Get.snackbar(
        "Required",
        "Reasons For Day Off is required!",
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black87,
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      );
    }
  }

  void _getDateFromUser(StateSetter setState) async {
    DateTime? pickerDate = await showDatePicker(
      context: Get.context!,
      initialDate: DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2090),
    );
    if (pickerDate != null) {
      setState(() {
        _selectedDate = pickerDate;
      });
    } else {
      print("It's null or something is wrong");
    }
  }

  void _getTimeFromUser(
      {required bool isStartTime, required StateSetter setState}) async {
    var pickedTime = await _showTimePicker();
    String formattedTime = pickedTime.format(Get.context!);
    print(pickedTime);
    if (isStartTime) {
      setState(() {
        _startTime = formattedTime;
      });
    } else {
      setState(() {
        _endTime = formattedTime;
      });
    }
  }

  Future<TimeOfDay> _showTimePicker() async {
    TimeOfDay? pickedTime = await showTimePicker(
      initialEntryMode: TimePickerEntryMode.input,
      context: Get.context!,
      initialTime: TimeOfDay(
        hour: int.parse(_startTime.split(":")[0]),
        minute: int.parse(_startTime.split(":")[1].split(" ")[0]),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    return pickedTime ?? TimeOfDay.now();
  }

  Future<void> _getUserLocation22() async {
    print("Fetching user location...");

    try {
      // Get user's current position
      Position position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );

      print(
          'Latitude: \${position.latitude}, Longitude: \${position.longitude}');
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
      String apiKey = ""; // Replace with your API key
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
      if (state.isEmpty) {
        location.value = location1;
        return;
      }

      print("Extracted State: \$state");
      administrativeArea.value = state;

      List<GeofenceModel> offices = await _fetchGeofenceLocations1(state);
      if (offices.isEmpty) {
        location.value = location1;
        return;
      }

      _checkGeofence(offices, position.latitude, position.longitude, location1);
    } catch (e) {
      print("Error getting location: $e");
      // Fluttertoast.showToast(
      //   msg: "Error getting location: $e",
      //   toastLength: Toast.LENGTH_LONG,
      //   backgroundColor: Colors.black54,
      //   gravity: ToastGravity.BOTTOM,
      //   textColor: Colors.white,
      //   fontSize: 16.0,
      // );
    }
  }

  Future<void> _getUserLocation() async {
    print("Fetching user location using Nominatim...");

    try {
      // Get user's current position with timeout and fallback strategy
      Position? position;
      
      // Attempt 1: Medium accuracy (30s timeout)
      try {
        print("Attempting to get location (Medium Accuracy)...");
        position = await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 30),
        );
      } catch (e) {
        print("Medium accuracy failed: $e");
        
        // Attempt 2: Low accuracy (45s timeout)
        try {
          print("Attempting to get location (Low Accuracy)...");
          position = await geolocator.Geolocator.getCurrentPosition(
            desiredAccuracy: geolocator.LocationAccuracy.low,
            timeLimit: const Duration(seconds: 45),
          );
        } catch (e) {
          print("Low accuracy failed: $e");
          
          // Attempt 3: Last known position
          print("Attempting to get last known position...");
          position = await geolocator.Geolocator.getLastKnownPosition();
        }
      }

      if (position == null) {
        print("Unable to get any location data.");
        location.value = "Location not found";
        return;
      }
      
      
      // Validate coordinates - don't use 0.0, 0.0
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        print("Invalid coordinates (0.0, 0.0) detected.");
        location.value = "Invalid location data";
        return;
      }
      
      print("Got location: ${position.latitude}, ${position.longitude}");


      print('Latitude: ${position.latitude}, Longitude: ${position.longitude}');
      lati.value = position.latitude;
      longi.value = position.longitude;
      accuracy.value = position.accuracy;
      altitude.value = position.altitude;
      speed.value = position.speed;
      speedAccuracy.value = position.speedAccuracy;
      heading.value = position.heading;
      time.value = position.timestamp.millisecondsSinceEpoch.toDouble();
      isMock.value = position.isMocked;

      // --- Nominatim API Call for Reverse Geocoding ---
      final nominatimUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}');
      final response = await http.get(nominatimUrl);

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        if (decodedResponse != null &&
            decodedResponse['display_name'] != null) {
          location.value = decodedResponse['display_name'];
          administrativeArea.value = _extractStateFromNominatim(
              decodedResponse); // Extract state if needed
        } else {
          location.value =
              "Location not found"; // Or handle no location found from Nominatim
          administrativeArea.value = "";
        }
      } else {
        print('Nominatim API error: ${response.statusCode}, ${response.body}');
        location.value = "Geocoding failed"; // Handle API error
        administrativeArea.value = "";
      }

      String geofenceLocationName =
          await _determineGeofenceLocation(lati.value, longi.value);
      if (geofenceLocationName.isNotEmpty) {
        location.value = geofenceLocationName;
        isInsideAnyGeofence.value = true;
      } else {
        isInsideAnyGeofence.value = false;
        currentStateDisplay.value = administrativeArea.value.isNotEmpty
            ? administrativeArea.value
            : "State Unknown";
      }
      isCircularProgressBarOn.value = false;
    } catch (e) {
      print("Error getting location: $e");
      location.value = "Location Error"; // Generic error message for UI
      administrativeArea.value = "";
      isCircularProgressBarOn.value = false;
    }
  }

  // Helper function to extract state from Nominatim response (adjust as needed)
  String _extractStateFromNominatim(Map<String, dynamic> nominatimResponse) {
    if (nominatimResponse['address'] != null) {
      final address = nominatimResponse['address'];
      return address['state'] ??
          address['region'] ??
          ''; // Try 'state' first, then 'region'
    }
    return '';
  }

  String _extractState(Map<String, dynamic> data) {
    List<dynamic> addressComponents = data["results"][0]["address_components"];
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

  Future<List<GeofenceModel>> _fetchGeofenceLocations1(String state) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Location')
          .doc(state)
          .collection(state)
          .get();
      return snapshot.docs
          .map((doc) => GeofenceModel.fromFirestore(doc.data(), state))
          .toList();
    } catch (e) {
      print("Error fetching geofence locations: \$e");
      return [];
    }
  }

  void _checkGeofence(List<GeofenceModel> offices, double latitude,
      double longitude, String location1) {
    isInsideAnyGeofence.value = false;

    for (GeofenceModel office in offices) {
      double distance = GeoUtils.haversine(
          latitude, longitude, office.latitude, office.longitude);
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

  void showQRDialog(BuildContext context) {
    // Generate fresh QR data with current timestamp
    final uuid = const Uuid();
    final freshUserId = FirebaseAuth.instance.currentUser?.uid ?? firebaseAuthId.value;
    final freshQrData = jsonEncode({
      'firstName': firstName.value,
      'lastName': lastName.value,
      'fullName': '${firstName.value} ${lastName.value}'.trim(),
      'designation': role.value,
      'userId': freshUserId, // Use the directly fetched ID
      'attendanceData': {
        'date': currentDate,
        'clockInTime': clockIn.value,
        'clockOutTime': clockOut.value,
        'clockInLocation': clockInLocation.value,
        'clockOutLocation': clockOutLocation.value,
      },
      'uuid': uuid.v4(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    print('QR Code Data: $freshQrData');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('verificationRequests')
              .doc(firebaseAuthId.value)
              .snapshots(),
          builder: (context, snapshot) {
            // Check if verification is received
            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              if (data['status'] == 'pending') {
                // Verification received!
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  
                  // 1. Show Success Message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Verified by ${data['scannerUserName'] ?? 'Scanner'}"),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }

                  // 2. Update target user's attendance record
                  final today = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
                  final targetRecordRef = FirebaseFirestore.instance
                      .collection('Staff')
                      .doc(firebaseAuthId.value)
                      .collection('Record')
                      .doc(today);

                  final targetRecord = await targetRecordRef.get();
                  if (targetRecord.exists) {
                    final currentData = targetRecord.data()!;
                    final verifiedIds = List<String>.from(currentData['verifiedByUserIds'] ?? []);
                    final verifiedNames = List<String>.from(currentData['verifiedByUserNames'] ?? []);
                    
                    final scannerId = data['scannerUserId'];
                    final scannerName = data['scannerUserName'];
                    final timestamp = DateFormat('d-MMM-yyyy \'at\' hh:mm a').format(DateTime.now());
                    
                    // Read scanner role
                    final scannerDoc = await FirebaseFirestore.instance.collection('Staff').doc(scannerId).get();
                    final scannerRole = scannerDoc.data()?['designation'] ?? 'Staff';
                    
                    verifiedIds.add(scannerId);
                    verifiedNames.add("$scannerName-$scannerRole $timestamp");
                    
                    await targetRecordRef.update({
                      'verificationMethod': 'qr',
                      'verificationRequired': true,
                      'verificationCount': verifiedIds.length,
                      'verifiedByUserIds': verifiedIds,
                      'verifiedByUserNames': verifiedNames,
                    });
                  }

                  // 3. Clear the request status to prevent loop
                  try {
                    await FirebaseFirestore.instance
                        .collection('verificationRequests')
                        .doc(firebaseAuthId.value)
                        .update({'status': 'completed'});
                  } catch (e) {
                    print("Error updating verification status: $e");
                  }

                  // 3. Close the dialog
                  if (Navigator.canPop(dialogContext)) {
                    Navigator.pop(dialogContext);
                  }
                });
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    QrImageView(
                      data: freshQrData,
                      version: QrVersions.auto,
                      size: 250.0,
                      gapless: false,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Scan to verify attendance",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Listening for scanner...",
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<int>(
                      stream: Stream.periodic(
                              const Duration(seconds: 1), (count) => 30 - count)
                          .take(31),
                      builder: (context, snapshot) {
                        final remaining = snapshot.data ?? 30;
                        if (remaining <= 0) {
                          Future.microtask(() {
                            if (Navigator.canPop(dialogContext)) {
                              Navigator.of(dialogContext).pop();
                              _showQRExpiryDialog(context);
                            }
                          });
                          return const SizedBox.shrink();
                        }
                        return Text(
                          'Expires in: $remaining seconds',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQRExpiryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('QR Code Expired'),
          content:
              const Text('The QR code has expired. Please generate a new one.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

enum ScreenSize { mobile, tablet, desktop }

class ResponsiveSizes {
  final BuildContext context;
  late ScreenSize screenSize;
  late double screenWidth;

  ResponsiveSizes(this.context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenSize = getScreenSize(screenWidth);
  }

  ScreenSize getScreenSize(double width) {
    if (width < 600) return ScreenSize.mobile;
    if (width < 992) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }

  double get horizontalPadding =>
      _scaleFactor(mobile: 0.025, tablet: 0.05, desktop: 0.10) * screenWidth;
  double get verticalPadding =>
      _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get verticalSpacing =>
      _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get sectionSpacing =>
      _scaleFactor(mobile: 0.025, tablet: 0.015, desktop: 0.01) * screenWidth;
  double get headerIconSize =>
      _scaleFactor(mobile: 0.04, tablet: 0.03, desktop: 0.02) * screenWidth;
  double get welcomeHeaderTextSize =>
      _scaleFactor(mobile: 0.025, tablet: 0.017, desktop: 0.0125) * screenWidth;
  double get usernameHeaderTextSize =>
      _scaleFactor(mobile: 0.03, tablet: 0.022, desktop: 0.017) * screenWidth;
  double get logoSize =>
      _scaleFactor(mobile: 1 / 16, tablet: 1 / 24, desktop: 1 / 40) *
      screenWidth;
  double get cardHeaderTextSize =>
      _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get subCardHeaderTextSize =>
      _scaleFactor(mobile: 0.022, tablet: 0.015, desktop: 0.010) * screenWidth;
  double get cardBorderRadius =>
      _scaleFactor(mobile: 6.0, tablet: 7.5, desktop: 9.0);
  double get cardPadding =>
      _scaleFactor(mobile: 0.02, tablet: 0.015, desktop: 0.01) * screenWidth;
  double get cardInnerSpacing =>
      _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get statusTextSize =>
      _scaleFactor(mobile: 0.02, tablet: 0.015, desktop: 0.012) * screenWidth;
  double get statusTextVerticalPadding =>
      _scaleFactor(mobile: 0.0025, tablet: 0.002, desktop: 0.0015) *
      screenWidth;
  double get dayCompletedTextSize =>
      _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get textFieldBorderRadius =>
      _scaleFactor(mobile: 7.5, tablet: 9.0, desktop: 10.0);
  double get textFieldPadding =>
      _scaleFactor(mobile: 0.04, tablet: 0.03, desktop: 0.02) * screenWidth;
  double get textFieldHintTextSize =>
      _scaleFactor(mobile: 0.02, tablet: 0.015, desktop: 0.012) * screenWidth;
  double get textFieldInputTextSize =>
      _scaleFactor(mobile: 0.022, tablet: 0.017, desktop: 0.014) * screenWidth;
  double get clockDisplayTopMargin =>
      _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get clockDisplayBottomMargin =>
      _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get clockDisplayShadowBlurRadius =>
      _scaleFactor(mobile: 5.0, tablet: 4.0, desktop: 3.0);
  double get clockDisplayBorderRadius =>
      _scaleFactor(mobile: 0.02, tablet: 0.015, desktop: 0.01) * screenWidth;
  double get clockTimeColumnVerticalPadding =>
      _scaleFactor(mobile: 0.015, tablet: 0.0175, desktop: 0.01) * screenWidth;
  double get clockTimeColumnTitleFontSize =>
      _scaleFactor(mobile: 0.022, tablet: 0.017, desktop: 0.012) * screenWidth;
  double get clockTimeColumnTimeFontSize =>
      _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get dateTextSize =>
      _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get timeTextSize =>
      _scaleFactor(mobile: 0.022, tablet: 0.017, desktop: 0.012) * screenWidth;
  double get clockButtonWidth =>
      _scaleFactor(mobile: 0.4, tablet: 0.3, desktop: 0.2) * screenWidth;
  double get clockButtonHeight =>
      _scaleFactor(mobile: 0.25, tablet: 0.25, desktop: 0.25) * screenWidth;
  double get outOfOfficeButtonVerticalPadding =>
      _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get outOfOfficeButtonWidth =>
      _scaleFactor(mobile: 0.35, tablet: 0.25, desktop: 0.17) * screenWidth;
  double get outOfOfficeButtonHeight =>
      _scaleFactor(mobile: 0.04, tablet: 0.03, desktop: 0.02) * screenWidth;
  double get outOfOfficeButtonLeftPadding =>
      _scaleFactor(mobile: 10.0, tablet: 7.5, desktop: 5.0);
  double get outOfOfficeButtonTextSize =>
      _scaleFactor(mobile: 0.02, tablet: 0.015, desktop: 0.01) * screenWidth;
  double get outOfOfficeButtonIconSpacing =>
      _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get locationCardWidth =>
      _scaleFactor(mobile: 0.45, tablet: 0.35, desktop: 0.25) * screenWidth;
  double get locationCardMargin =>
      _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get locationCardVerticalPadding =>
      _scaleFactor(mobile: 0.015, tablet: 0.012, desktop: 0.01) * screenWidth;
  double get locationCardHorizontalPadding =>
      _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get locationCardHeaderTextSize =>
      _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get locationInnerContentWidth =>
      _scaleFactor(mobile: 0.35, tablet: 0.3, desktop: 0.2) * screenWidth;
  double get locationColumnSpacing =>
      _scaleFactor(mobile: 0.005, tablet: 0.004, desktop: 0.003) * screenWidth;
  double get locationColumnTitleTextSize =>
      _scaleFactor(mobile: 0.017, tablet: 0.014, desktop: 0.010) * screenWidth;
  double get locationColumnLocationTextSize =>
      _scaleFactor(mobile: 0.015, tablet: 0.012, desktop: 0.009) * screenWidth;
  double get commentButtonWidth =>
      _scaleFactor(mobile: 0.20, tablet: 0.15, desktop: 0.10) * screenWidth;
  double get commentButtonHeight =>
      _scaleFactor(mobile: 0.04, tablet: 0.03, desktop: 0.02) * screenWidth;
  double get commentButtonTextSize =>
      _scaleFactor(mobile: 8.0, tablet: 7.0, desktop: 6.0);

  double _scaleFactor(
      {required double mobile,
      required double tablet,
      required double desktop}) {
    switch (screenSize) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet;
      case ScreenSize.desktop:
        return desktop;
      default:
        return mobile;
    }
  }
}
