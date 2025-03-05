import 'dart:async';
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
import 'package:synchronized/synchronized.dart';
import 'package:location/location.dart' as locationPkg;
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';


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
  final String stateName; // Added stateName

  GeofenceModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.category,
    required this.stateName, // Added stateName
  });

  factory GeofenceModel.fromFirestore(Map<String, dynamic> firestoreData, String stateName) { // Modified factory
    return GeofenceModel(
      name: firestoreData['LocationName'] ?? 'Unknown Location',
      latitude: GeofenceModel._parseNum(firestoreData['Latitude'])?.toDouble() ?? 0.0,
      longitude: GeofenceModel._parseNum(firestoreData['Longitude'])?.toDouble() ?? 0.0,
      radius: GeofenceModel._parseNum(firestoreData['Radius'])?.toDouble() ?? 100.0,
      category: firestoreData['category'] ?? 'General',
      stateName: stateName, // Passing stateName here
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

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamAttendanceRecord(String userId, String date) {
    return _firestore
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .snapshots();
  }


  Future<DocumentSnapshot<Map<String, dynamic>>> getAttendanceRecord(String userId, String date) async {
    return await _firestore
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .get();
  }

  Future<void> createAttendanceRecord(String userId, String date, Map<String, dynamic> data) async {
    await _firestore
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .set(data);
  }

  Future<void> updateAttendanceRecord(String userId, String date, Map<String, dynamic> data) async {
    await _firestore
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .update(data);
  }


  Future<String?> getUserState() async {
    DocumentSnapshot userSnapshot = await _firestore.collection('Staff').doc(getUserId()).get();
    if (userSnapshot.exists) {
      Map<String, dynamic>? userData = userSnapshot.data() as Map<String, dynamic>?;
      return userData?['state'] as String?;
    }
    return null;
  }

  Future<List<String>> getAllStates() async {
    List<String> states = [];
    try {
      QuerySnapshot locationSnapshot = await _firestore.collection('Location').get();
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
        geofenceLocations.add(GeofenceModel.fromFirestore(doc.data(), state)); // Passing state name here
      }
      dev.log("geofenceLocations =$geofenceLocations");
    } catch (e) {
      dev.log("Error fetching geofences for state $state: $e");
    }
    return geofenceLocations;
  }


  Future<List<GeofenceModel>> getGeofencesForAllStatesExceptCurrent(String currentState) async {
    List<GeofenceModel> allGeofences = [];
    List<String> allStates = await getAllStates();

    for (String state in allStates) {
      if (state != currentState) {
        allGeofences.addAll(await getGeofencesForState(state));
      }
    }
    return allGeofences;
  }
}


class ClockAttendanceWeb extends StatelessWidget {


  const ClockAttendanceWeb({super.key});

  @override
  Widget build(BuildContext context) {
    final ClockAttendanceWebController controller = Get.put(ClockAttendanceWebController(FirestoreService()));
    controller.onRefreshPage(); // Call onRefreshPage here to refresh location on every build
    final ResponsiveSizes sizes = ResponsiveSizes(context);

    return Scaffold(
      drawer: drawer(context), // Added drawer here
      appBar: AppBar(
        title: const Text('Attendance'),
      ),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              ScreenSize screenSize = sizes.getScreenSize(constraints.maxWidth);
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: sizes.horizontalPadding, vertical: sizes.verticalPadding),
                child: Column(
                  children: [
                    SizedBox(height: sizes.verticalSpacing),
                    HeaderWidget(sizes.headerIconSize, false, Icons.house_rounded), // Added HeaderWidget
                    SizedBox(height: sizes.sectionSpacing),
                    _buildWelcomeHeader(context, controller, screenSize, sizes),
                    SizedBox(height: sizes.sectionSpacing),
                    _buildStatusCard(context, controller, screenSize, sizes),
                    SizedBox(height: sizes.sectionSpacing),
                    _buildAttendanceCard(context, controller, screenSize, sizes),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _buildWelcomeHeader(BuildContext context, ClockAttendanceWebController controller, ScreenSize screenSize, ResponsiveSizes sizes) {
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
                style: TextStyle(
                  color: Colors.black54,
                  fontFamily: "NexaLight",
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
          style: TextStyle(
            color: Colors.black54,
            fontFamily: "NexaBold",
            fontSize: sizes.usernameHeaderTextSize,
          ),
        )),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, ClockAttendanceWebController controller, ScreenSize screenSize, ResponsiveSizes sizes) {
    return Container(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Status:",
            style: TextStyle(
              fontFamily: "NexaBold",
              fontSize: sizes.cardHeaderTextSize,
            ),
          ),
          SizedBox(height: sizes.cardInnerSpacing),
          Obx(() => Card(
            elevation: 4,

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(sizes.cardBorderRadius)),
            child: Container(
              width:MediaQuery.of(context).size.width*1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade100, Colors.white, Colors.black12],
                ),
                borderRadius: BorderRadius.circular(sizes.cardBorderRadius),
              ),
              padding: EdgeInsets.all(sizes.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Geo-Coordinates Information:",
                    style: TextStyle(
                      fontFamily: "NexaBold",
                      fontSize: sizes.subCardHeaderTextSize,
                      color: Colors.blueGrey,
                    ),
                  ),
                  SizedBox(height: sizes.cardInnerSpacing),
                  _buildStatusText("GPS is:", controller.isGpsEnabled.value ? 'On' : 'Off', screenSize, sizes),
                  _buildStatusText("Current Latitude:", controller.lati.value.toStringAsFixed(6), screenSize, sizes),
                  _buildStatusText("Current Longitude:", controller.longi.value.toStringAsFixed(6), screenSize, sizes),
                  _buildStatusText("Coordinates Accuracy:", controller.accuracy.value.toString(), screenSize, sizes),
                  _buildStatusText("Altitude:", controller.altitude.value.toString(), screenSize, sizes),
                  _buildStatusText("Speed:", controller.speed.value.toString(), screenSize, sizes),
                  _buildStatusText("Speed Accuracy:", controller.speedAccuracy.value.toString(), screenSize, sizes),
                  _buildStatusText("Location Data Timestamp:", DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(controller.time.value.toInt())), screenSize, sizes),
                  _buildStatusText("Is Location Mocked?:", controller.isMock.value.toString(), screenSize, sizes),
                  _buildStatusText("Current State:", controller.currentStateDisplay.value, screenSize, sizes), // Updated to use currentStateDisplay
                  _buildStatusText("Current Location:", controller.location.value, screenSize, sizes),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatusText(String label, String value, ScreenSize screenSize, ResponsiveSizes sizes) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: sizes.statusTextVerticalPadding),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: "NexaBold",
            fontSize: sizes.statusTextSize,
            color: Colors.black87,
          ),
          children: <TextSpan>[
            TextSpan(text: '$label ', style: const TextStyle(color: Colors.blueGrey)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(BuildContext context, ClockAttendanceWebController controller, ScreenSize screenSize, ResponsiveSizes sizes) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: controller.getLastAttendanceForDateFirestore(DateFormat('dd-MMMM-yyyy').format(DateTime.now())).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData && snapshot.data!.exists) {
          final attendanceData = snapshot.data!.data();
          if (attendanceData != null) {
            final lastAttendance = AttendanceModelFirestore.fromMap(attendanceData);
            if (lastAttendance.clockIn != "--/--" && lastAttendance.clockOut == "--/--") {
              return _buildClockOutSection(context, controller, lastAttendance, screenSize, sizes);
            } else if (lastAttendance.clockIn != "--/--" && lastAttendance.clockOut != "--/--") {
              return _buildDayCompletedSection(context, controller, lastAttendance, screenSize, sizes);
            } else {
              return _buildClockInSection(context, controller, screenSize, lastAttendance, sizes);
            }
          } else {
            return _buildClockInSection(context, controller, screenSize, null, sizes);
          }
        } else {
          return _buildClockInSection(context, controller, screenSize, null, sizes);
        }
      },
    );
  }


  Widget _buildClockInSection(BuildContext context, ClockAttendanceWebController controller, ScreenSize screenSize, AttendanceModelFirestore? lastAttendance, ResponsiveSizes sizes) {
    return Column(
      children: [
        _buildClockInOutDisplay(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildDateAndTime(screenSize, sizes),
        SizedBox(height: sizes.sectionSpacing),
        _buildClockInImageButton(context, controller, screenSize, sizes), // Show clock-in button initially
        SizedBox(height: sizes.cardInnerSpacing),
        _buildOutOfOfficeButton(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildLocationStatusCard(context, controller, screenSize, sizes),
      ],
    );
  }

  Widget _buildClockOutSection(BuildContext context, ClockAttendanceWebController controller, AttendanceModelFirestore? lastAttendance, ScreenSize screenSize, sizes) {
    return Column(
      children: [
        _buildClockInOutDisplay(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildDateAndTime(screenSize, sizes),
        SizedBox(height: sizes.sectionSpacing),
        _buildClockOutImageButton(context, controller, screenSize, sizes), // Show clock-out button if clocked in
        SizedBox(height: sizes.cardInnerSpacing),
        _buildLocationStatusCard(context, controller, screenSize, sizes),
      ],
    );
  }


  Widget _buildDayCompletedSection(BuildContext context, ClockAttendanceWebController controller, AttendanceModelFirestore? lastAttendance, ScreenSize screenSize, sizes) {
    final TextEditingController commentsController = TextEditingController(text: lastAttendance?.comments != "No Comment" ? lastAttendance?.comments : ""); // Initialize with existing comments
    return Column(
      children: [
        _buildClockInOutDisplay(context, controller, screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        _buildDateAndTime(screenSize, sizes),
        SizedBox(height: sizes.cardInnerSpacing),
        Text(
          "You have completed this day!!!",
          style: TextStyle(
            fontFamily: "NexaLight",
            fontSize: sizes.dayCompletedTextSize,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: sizes.cardInnerSpacing),
        Obx(() => Text(
          "Duration Worked: ${controller.durationWorked.value}",
          style: TextStyle(
            fontFamily: "NexaLight",
            fontSize: sizes.dayCompletedTextSize,
            color: Colors.black54,
          ),
        )),
        SizedBox(height: sizes.cardInnerSpacing),
        Obx(() => Text(
          "Comment(s): ${controller.comments.value}",
          style: TextStyle(
            fontFamily: "NexaLight",
            fontSize: sizes.dayCompletedTextSize,
            color: Colors.black54,
          ),
        )),

        // Comment Input Section Start
        SizedBox(height: sizes.cardInnerSpacing),
        TextField(
          controller: commentsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Add Comment (Optional)",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(sizes.textFieldBorderRadius)),
            contentPadding: EdgeInsets.all(sizes.textFieldPadding),
          ),
          style: TextStyle(fontSize: sizes.textFieldInputTextSize),
        ),
        SizedBox(height: sizes.cardInnerSpacing),
        Obx(() => controller.comments.value == "No Comment" || controller.comments.value.isEmpty ? _buildAddCommentButton(context, commentsController, screenSize, sizes) : const SizedBox(height: 0)),
        SizedBox(height: sizes.cardInnerSpacing),
        // Comment Input Section End

        _buildLocationStatusCard(context, controller, screenSize, sizes), // Location Card is placed after comment section
        SizedBox(height: sizes.cardInnerSpacing),
      ],
    );
  }


  Widget _buildClockInOutDisplay(BuildContext context, ClockAttendanceWebController controller, ScreenSize screenSize, ResponsiveSizes sizes) {
    return Container(
      margin: EdgeInsets.only(top: sizes.clockDisplayTopMargin, bottom: sizes.clockDisplayBottomMargin),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: sizes.clockDisplayShadowBlurRadius, offset: const Offset(2, 2)),
        ],
        borderRadius: BorderRadius.all(Radius.circular(sizes.clockDisplayBorderRadius)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StreamBuilder<String>(
              stream: controller.clockInStream,
              initialData: controller.clockIn.value,
              builder: (context, snapshot) {
                return _buildClockTimeColumn("Clock In", snapshot.data ?? "--/--", screenSize, sizes);
              }
          ),
          StreamBuilder<String>(
              stream: controller.clockOutStream,
              initialData: controller.clockOut.value,
              builder: (context, snapshot) {
                return _buildClockTimeColumn("Clock Out", snapshot.data ?? "--/--", screenSize, sizes);
              }
          ),
        ],
      ),
    );
  }

  Widget _buildClockTimeColumn(String title, String time, ScreenSize screenSize, ResponsiveSizes sizes) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: sizes.clockTimeColumnVerticalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: "NexaLight",
                fontSize: sizes.clockTimeColumnTitleFontSize,
                color: Colors.black54,
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontFamily: "NexaBold",
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
            style: TextStyle(
              color: Colors.red,
              fontSize: sizes.dateTextSize,
              fontFamily: "NexaBold",
            ),
            children: [
              TextSpan(
                text: DateFormat(" MMMM yyyy").format(DateTime.now()),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: sizes.dateTextSize,
                  fontFamily: "NexaBold",
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
              style: TextStyle(
                fontFamily: "NexaLight",
                fontSize: sizes.timeTextSize,
                color: Colors.black54,
              ),
            );
          },
        ),
      ],
    );
  }


  Widget _buildClockInImageButton(BuildContext context, ClockAttendanceWebController controller, ScreenSize screenSize, ResponsiveSizes sizes) {
    return GestureDetector(
      onTap: () async {
        await controller.clockInUpdated(controller.lati.value, controller.longi.value, controller.location.value);
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width*1,
        height: sizes.clockButtonHeight,
        child: Image.asset(
          'assets/image/clockin9.jpg',
          fit: BoxFit.contain,
        ),
      ),
    );
  }


  Widget _buildClockOutImageButton(BuildContext context, ClockAttendanceWebController controller, ScreenSize screenSize, ResponsiveSizes sizes) {
    return GestureDetector(
      onTap: () async {
        await controller.clockOutUpdated(controller.lati.value, controller.longi.value, controller.location.value);
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width*1,
        height: sizes.clockButtonHeight,
        child: Image.asset(
          'assets/image/clockout8.jpg',
          fit: BoxFit.contain,
        ),
      ),
    );
  }


  Widget _buildOutOfOfficeButton(BuildContext context, ClockAttendanceWebController controller, ScreenSize screenSize, ResponsiveSizes sizes) {
    return Padding(
        padding: EdgeInsets.symmetric(vertical: sizes.outOfOfficeButtonVerticalPadding),
        child: GestureDetector(
          onTap: (){
            controller.showBottomSheet3(context);
          },
          child: Container(
            width: sizes.outOfOfficeButtonWidth,
            height: sizes.outOfOfficeButtonHeight,
            padding: EdgeInsets.only(left: sizes.outOfOfficeButtonLeftPadding, bottom: 0.0),
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
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
                  Text(
                    "Out Of Office? CLICK HERE",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: sizes.outOfOfficeButtonTextSize),
                  ),
                  SizedBox(width:sizes.outOfOfficeButtonIconSpacing),
                  const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.white,
                  ),
                ]),
          ),
        )
    );
  }


  Widget _buildLocationStatusCard(BuildContext context, ClockAttendanceWebController controller, ScreenSize screenSize, ResponsiveSizes sizes) {
    return Container(
      width: MediaQuery.of(context).size.width*1,
      margin: EdgeInsets.all(sizes.locationCardMargin),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red, Colors.black]),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      padding: EdgeInsets.symmetric(vertical: sizes.locationCardVerticalPadding, horizontal: sizes.locationCardHorizontalPadding),
      child: Column(
        children: [
          Text(
            "Location Status",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sizes.locationCardHeaderTextSize,
              fontFamily: "NexaBold",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: sizes.cardInnerSpacing),
          SizedBox(
            width: sizes.locationInnerContentWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildClockInLocationColumn("Clock-In Location", controller, screenSize, sizes),
                SizedBox(width: sizes.locationColumnSpacing),
                _buildClockOutLocationColumn("Clock-Out Location", controller, screenSize, sizes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockInLocationColumn(String title, ClockAttendanceWebController controller, ScreenSize screenSize, ResponsiveSizes sizes) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: "NexaLight",
              fontSize: sizes.locationColumnTitleTextSize,
              color: Colors.white,
            ),
          ),
          SizedBox(height: sizes.cardInnerSpacing),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: controller.firestoreService.streamAttendanceRecord(controller.firestoreService.getUserId()!, DateFormat('dd-MMMM-yyyy').format(DateTime.now())),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white));
              } else if (snapshot.hasData && snapshot.data!.exists) {
                final attendanceData = snapshot.data!.data();
                final lastAttendance = AttendanceModelFirestore.fromMap(attendanceData!);
                return Text(
                  lastAttendance.clockInLocation ?? "",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "NexaBold",
                    fontSize: sizes.locationColumnLocationTextSize,
                    color: Colors.white,
                  ),
                );
              } else {
                return Text("",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "NexaBold",
                    fontSize: sizes.locationColumnLocationTextSize,
                    color: Colors.white,
                  ),);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClockOutLocationColumn(String title, ClockAttendanceWebController controller, ScreenSize screenSize, ResponsiveSizes sizes) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: "NexaLight",
              fontSize: sizes.locationColumnTitleTextSize,
              color: Colors.white,
            ),
          ),
          SizedBox(height: sizes.cardInnerSpacing),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: controller.firestoreService.streamAttendanceRecord(controller.firestoreService.getUserId()!, DateFormat('dd-MMMM-yyyy').format(DateTime.now())),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white));
              } else if (snapshot.hasData && snapshot.data!.exists) {
                final attendanceData = snapshot.data!.data();
                final lastAttendance = AttendanceModelFirestore.fromMap(attendanceData!);
                return Text(
                  lastAttendance.clockOutLocation ?? "",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "NexaBold",
                    fontSize: sizes.locationColumnLocationTextSize,
                    color: Colors.white,
                  ),
                );
              } else {
                return Text("",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "NexaBold",
                    fontSize: sizes.locationColumnLocationTextSize,
                    color: Colors.white,
                  ),);
              }
            },
          ),
        ],
      ),
    );
  }


  Widget _buildAddCommentButton(BuildContext context, TextEditingController commentsController, ScreenSize screenSize, ResponsiveSizes sizes) {
    return GestureDetector(
      onTap: () => Get.find<ClockAttendanceWebController>().handleAddComments(context, commentsController.text),
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
            style: TextStyle(
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
    this.comments
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
    };
  }
}



class ClockAttendanceWebController extends GetxController {
  final FirestoreService firestoreService;
  late List<GeofenceModel> geofenceList = <GeofenceModel>[].obs;
  List<GeofenceModel> cachedGeofences = []; // Cache for geofences

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
  Stream<String> get clockInLocationStream => _clockInLocationStreamController.stream;

  final _clockOutLocationStreamController = StreamController<String>.broadcast();
  Stream<String> get clockOutLocationStream => _clockOutLocationStreamController.stream;



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
  RxBool isClockedIn = false.obs; // Track clock-in state


  RxString administrativeArea = "".obs;
  RxString currentStateDisplay = "".obs; // New RxString for displaying current state (geofence or administrativeArea)
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
  String _startTime =
  DateFormat("hh:mm a").format(DateTime.now()).toString();
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
  late StreamSubscription subscription;


  @override
  void onInit() {
    super.onInit();
    _loadInitialData();
    //_init();
  }

  @override
  void onReady() {
    super.onReady();
    _init(); // Call _init again in onReady to refresh location on page refresh
  }

  @override
  void onClose() {
    _locationTimer?.cancel();
    _clockInStreamController.close();
    _clockOutStreamController.close();
    _clockInLocationStreamController.close();
    _clockOutLocationStreamController.close();
    super.onClose();
  }

  Future<void> onRefreshPage() async {
    await _init(); // Call _init again to refresh location
  }

  Future<void> _loadInitialData() async {
    await _loadNTPTime();
    await _getAttendanceSummary();
    await _getUserDetail();
    await _fetchGeofenceLocations(); // Fetch and cache geofences
    await checkInternetConnection();
  }

  Future<void> _init() async {

    await getLocationStatus().then((_) async {
      await getPermissionStatus().then((_) async {
        await _startLocationService();
      });
    });
  }


  Timer? _locationTimer;


  Future<void> _getLocationDetailsFromLocationModel() async {

    print("getLocationDetailsFromLocationModel is skipped for web in this example");
  }



  Future<void> _updateLocationUsingGeofencing() async {
    if (lati.value != 0.0) {
      String geofencedLocationName = await _determineGeofenceLocation(lati.value, longi.value);
      if (geofencedLocationName.isNotEmpty) {
        location.value = geofencedLocationName;
        //currentStateDisplay.value = geofencedLocationName; // Set currentStateDisplay to geofence name - now handled in _determineGeofenceLocation
        isInsideAnyGeofence.value = true;
      } else {
        isInsideAnyGeofence.value = false;
        currentStateDisplay.value = administrativeArea.value; // Fallback to administrativeArea if no geofence
      }
    }
  }


  Future<void> _updateLocationUsingGeofencing2(double latitde, double longitde) async {
    print("_updateLocationUsingGeofencing2 is skipped for web in this example");
  }

  Future<String> _determineGeofenceLocation(double latitude, double longitude) async {
    String geofenceName = "";
    String? userState = await firestoreService.getUserState();

    for (GeofenceModel geofence in cachedGeofences) {
      double distance = GeoUtils.haversine(latitude, longitude, geofence.latitude, geofence.longitude);
      if (distance <= geofence.radius) {
        if (geofence.stateName == userState) {
          currentStateDisplay.value = geofence.name; // Update with geofence name if in current state
        } else {
          currentStateDisplay.value = geofence.stateName; // Update with other state name if from another state
        }
        return geofence.name; // Return geofence name if inside
      }
    }
    if(userState != null) {
      currentStateDisplay.value = userState; // Default to user state if not in any geofence of cached states and user state is known
    } else {
      currentStateDisplay.value = administrativeArea.value.isNotEmpty ? administrativeArea.value : "State Unknown"; // Fallback to administrativeArea or "State Unknown"
    }

    return geofenceName; // Return empty string if not in any geofence
  }


  Future<void> _fetchGeofenceLocations() async {
    String? userState = await firestoreService.getUserState();
    if (userState != null) {
      dev.log("User state found==$userState");
      List<GeofenceModel> currentStateGeofences = await firestoreService.getGeofencesForState(userState);
      cachedGeofences.addAll(currentStateGeofences); // Add current state geofences to cache

      List<GeofenceModel> otherStatesGeofences = await firestoreService.getGeofencesForAllStatesExceptCurrent(userState);
      cachedGeofences.addAll(otherStatesGeofences); // Add geofences from other states to cache

      dev.log("cachedGeofences count==${cachedGeofences.length}");
    } else {
      dev.log("User state not found, geofencing might not work correctly.");
      // Optionally fetch all geofences if state is unknown for a broader check
      List<String> allStates = await firestoreService.getAllStates();
      for (String state in allStates) {
        List<GeofenceModel> stateGeofences = await firestoreService.getGeofencesForState(state);
        cachedGeofences.addAll(stateGeofences);
      }
    }
  }


  Future<void> _loadNTPTime() async {
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


      firstName.value = user.displayName ?? "";
      lastName.value = "";
      role.value = "User";

    }
  }

  Future<void> _getAttendanceSummary() async {
    try {
      final attendanceData = await getLastAttendanceForDateFirestore(DateFormat('dd-MMMM-yyyy').format(DateTime.now())).get();

      if (attendanceData.exists) {
        AttendanceModelFirestore lastAttendance = AttendanceModelFirestore.fromMap(attendanceData.data()!);

        clockIn.value = lastAttendance.clockIn ?? "--/--";
        clockOut.value = lastAttendance.clockOut ?? "--/--";
        clockInLocation.value = lastAttendance.clockInLocation ?? "";
        clockOutLocation.value = lastAttendance.clockOutLocation ?? "";
        durationWorked.value = lastAttendance.durationWorked ?? "";
        comments.value = lastAttendance.comments ?? "No Comment";
        isClockedIn.value = lastAttendance.clockIn != "--/--" && lastAttendance.clockOut == "--/--"; // Update clock-in status

        _clockInStreamController.add(clockIn.value);
        _clockOutStreamController.add(clockOut.value);
        _clockInLocationStreamController.add(clockInLocation.value);
        _clockOutLocationStreamController.add(clockOutLocation.value);

      } else {
        clockIn.value =  "--/--";
        clockOut.value =  "--/--";
        clockInLocation.value = "";
        clockOutLocation.value = "";
        durationWorked.value = "";
        comments.value = "No Comment";
        isClockedIn.value = false; // Not clocked in

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

    locationPkg.PermissionStatus permission = await locationService.requestPermission();
    if (permission != locationPkg.PermissionStatus.granted) {
      return;
    }

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
    if (permission == LocationPermission.denied) {
      permission = await geolocator.Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {

        return Future.error('Location permissions are denied');
      }
    }


    if (permission == LocationPermission.deniedForever) {

      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }


    return await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.low // Reduced accuracy for faster updates
    );
  }

  void _getUserLocation1() async {
    print("Geolocator Dependency here");
    try {
      geolocator.Position? position = await getCurrentLocation();
      if (position != null) {
        print('Latitude: ${position.latitude}, Longitude: ${position.longitude}');

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
          await _updateLocationUsingGeofencing2(position.latitude,position.longitude);
        }


        if (administrativeArea.value != '') {
          isInsideAnyGeofence.value = false;


          if (!isInsideAnyGeofence.value) {
            List<Placemark> placemark = await placemarkFromCoordinates(
                position.latitude, position.longitude);

            location.value =
            "${placemark[0].street},${placemark[0].subLocality},${placemark[0].subAdministrativeArea},${placemark[0].locality},${placemark[0].administrativeArea},${placemark[0].postalCode},${placemark[0].country}";


          }
        }
        else if(administrativeArea.value == '' && location.value != 0.0){

          await _updateLocationUsingGeofencing();
        }
        else {
          List<Placemark> placemark = await placemarkFromCoordinates(
              position.latitude, position.longitude);

          location.value =
          "${placemark[0].street},${placemark[0].subLocality},${placemark[0].subAdministrativeArea},${placemark[0].locality},${placemark[0].administrativeArea},${placemark[0].postalCode},${placemark[0].country}";


        }

      }

    } catch (e) {


      if(lati.value != 0.0 && administrativeArea.value == ''){

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

        dev.log('Error getting location: $e');
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

  Future<void> _getLocation2() async {

    try{
      print("_getLocation2 hereeeee");
      locationService.onLocationChanged.listen((locationPkg.LocationData? locationData) async {
        if (locationData != null && locationData.latitude != null && locationData.longitude != null) {
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
          elapsedRealtimeUncertaintyNanos.value = locationData.elapsedRealtimeUncertaintyNanos ?? 0.0;


          _updateLocation();
          _getAttendanceSummary();
        } else {
          print("_getLocation2: Received null location data");
        }
      });
    }catch(e){
      print("_getLocation2 Error:$e");
      print("There is nooooooo internet to get location data");
      try {
        geolocator.Position? position = await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.low, // Reduced accuracy for faster updates
          forceAndroidLocationManager: true,
        );

        lati.value = position.latitude;
        longi.value = position.longitude;
        print("locationData.latitude == ${position.latitude}");
        _updateLocation();
            } catch (geolocatorError) {
        print("_getLocation2: Error getting location from geolocator: $geolocatorError");
      }
    }

  }

  Future<void> _updateLocation() async {
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


      } else {
        location.value = "Location not found";
        administrativeArea.value = "";
      }


      String geofenceLocationName = await _determineGeofenceLocation(lati.value, longi.value);
      if (geofenceLocationName.isNotEmpty) {
        location.value = geofenceLocationName;
        // currentStateDisplay.value = geofenceLocationName; // Display geofence name - now handled in _determineGeofenceLocation
        isInsideAnyGeofence.value = true;
      } else {
        isInsideAnyGeofence.value = false;
        currentStateDisplay.value = administrativeArea.value.isNotEmpty ? administrativeArea.value : "State Unknown"; // Display administrativeArea or "State Unknown"
      }
      isCircularProgressBarOn.value = false;


    }catch(e){
      currentStateDisplay.value = administrativeArea.value.isNotEmpty ? administrativeArea.value : "State Unknown"; // Fallback even on error
      if(lati.value != 0.0 && administrativeArea.value == ''){

        await _updateLocationUsingGeofencing();
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


  Future<void> getLocationStatus() async {
    bool isLocationEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    isLocationTurnedOn.value = isLocationEnabled;

    if (!isLocationTurnedOn.value && !isAlertSet.value) {
      showDialogBox();
      isAlertSet.value = true;
    }
  }

  Future<void> getPermissionStatus() async {
    LocationPermission? permission = await geolocator.Geolocator.checkPermission();

    isLocationPermissionGranted.value = permission;

    if (isLocationPermissionGranted.value == LocationPermission.denied ||
        isLocationPermissionGranted.value == LocationPermission.deniedForever) {
      isAlertSet2.value = true;
    }
    }

  Future<void> checkInternetConnection() async {

  }


  Future<void> handleAddComments(
      BuildContext context,String? commentsForAttendance) async {


    try {

      final attendanceResult = getLastAttendanceForDateFirestore(DateFormat('dd-MMMM-yyyy').format(DateTime.now()));
      final attendanceData = await attendanceResult.get();

      if (attendanceData.exists) {
        AttendanceModelFirestore lastAttendance = AttendanceModelFirestore.fromMap(attendanceData.data()!);
        if (lastAttendance.date == DateFormat('dd-MMMM-yyyy').format(DateTime.now())) {
          await addComments(DateFormat('dd-MMMM-yyyy').format(DateTime.now()),commentsForAttendance!);
        }
      }


    } catch (e) {
      dev.log("Attendance Comment Error ====== ${e.toString()}");

    }

  }


  Future<void> addComments(
      String attendanceDate,
      String commentsForAttendance
      ) async {

    String? userId = firestoreService.getUserId();
    if (userId == null) {
      return;
    }


    await firestoreService.updateAttendanceRecord(
        userId,
        attendanceDate,
        {'comments': commentsForAttendance}
    );

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


  Future<void> clockInUpdated(double newlatitude,double newlongitude,String newlocation) async {
    print("clockInUpdated");

    if (!isLoading.value) {
      await _clockInOutLock.synchronized(() async {
        try {

          currentDate = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
          String? userId = firestoreService.getUserId();

          if (userId == null) {
            return;
          }

          final attendanceData = await getLastAttendanceForDateFirestore(currentDate).get();


          if (!attendanceData.exists) {
            if (newlatitude != 0.0) {
              final attendance = AttendanceModelFirestore(
                Offline_DB_id: Random().nextInt(300) + 1, // Insert random number here
                clockIn: DateFormat('hh:mm a').format(DateTime.now()),
                date: currentDate,
                clockInLatitude: newlatitude,
                clockInLocation: newlocation,
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
              ).toMap();

              await firestoreService.createAttendanceRecord(userId, currentDate, attendance);

              clockIn.value = DateFormat('hh:mm a').format(DateTime.now()); // Update clockIn value
              clockInLocation.value = location.value; // Update clockInLocation value
              isClockedIn.value = true; // Set clocked in status to true
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
          }else
          {
            AttendanceModelFirestore lastAttendance = AttendanceModelFirestore.fromMap(attendanceData.data()!);

            if (lastAttendance.date != currentDate) {

              final clockInDateTime = DateFormat('dd-MMMM-yyyy hh:mm a').parse(
                  '${lastAttendance.date} ${lastAttendance.clockIn}');

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
                isLoading.value =
                false;

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
                      fontSize: 16.0
                  );
                  isLoading.value =
                  false;

                }
                else {
                  if (newlatitude != 0.0) {
                    final attendance = AttendanceModelFirestore(
                      Offline_DB_id: Random().nextInt(300) + 1, // Insert random number here
                      clockIn: DateFormat('hh:mm a').format(DateTime.now()),
                      date: currentDate,
                      clockInLatitude: newlatitude,
                      clockInLocation: newlocation,
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
                    ).toMap();

                    await firestoreService.createAttendanceRecord(userId, currentDate, attendance);
                    clockIn.value = DateFormat('hh:mm a').format(DateTime.now()); // Update clockIn value
                    clockInLocation.value = location.value; // Update clockInLocation value
                    isClockedIn.value = true; // Set clocked in status to true

                    _clockInStreamController.add(
                        DateFormat('hh:mm a').format(DateTime.now()));
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


        }catch(e){
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

      double newlatitude,double newlongitude,String newlocation
      ) async {

    print("clockOutUpdated");

    if (!isLoading.value) {
      await _clockInOutLock.synchronized(() async {
        try {

          currentDate = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
          String? userId = firestoreService.getUserId();
          if (userId == null) {
            return;
          }

          final attendanceData = await getLastAttendanceForDateFirestore(currentDate).get();


          if (attendanceData.exists) {
            AttendanceModelFirestore lastAttendance = AttendanceModelFirestore.fromMap(attendanceData.data()!);

            if (lastAttendance.date == currentDate &&
                lastAttendance.clockOut == "--/--") {


              final clockInDateTime = DateFormat('dd-MMMM-yyyy hh:mm a').parse(
                  '${lastAttendance.date} ${lastAttendance.clockIn}');

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
                isLoading.value =
                false;

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
                      fontSize: 16.0
                  );
                  isLoading.value =
                  false;

                }
                else {


                  if(newlatitude != 0.0) {

                    Map<String, dynamic> updateData = {
                      'clockOut': DateFormat('hh:mm a').format(DateTime.now()),
                      'clockOutLatitude': newlatitude,
                      'clockOutLongitude': newlongitude,
                      'clockOutLocation': newlocation,
                      'isUpdated': true,
                      'durationWorked': _diffClockInOut(
                          lastAttendance.clockIn.toString(),
                          DateFormat('h:mm a').format(DateTime.now())),
                      'noOfHours': _diffHoursWorked(
                          lastAttendance.clockIn.toString(),
                          DateFormat('h:mm a').format(DateTime.now())),
                    };

                    await firestoreService.updateAttendanceRecord(
                      userId,
                      currentDate,
                      updateData,
                    );

                    clockOut.value = DateFormat('hh:mm a').format(DateTime.now()); // Update clockOut value
                    clockOutLocation.value = location.value; // Update clockOutLocation value
                    isClockedIn.value = false; // Set clocked in status to false

                    _clockOutStreamController.add(DateFormat('hh:mm a').format(DateTime.now()));
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

                  } else{
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

        }catch(e){
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


  String _diffClockInOut(String clockInTime, String clockOutTime) {
    try{
      var format = DateFormat("h:mm a");
      var clockTimeIn = format.parse(clockInTime);
      var clockTimeOut = format.parse(clockOutTime);

      if (clockTimeIn.isAfter(clockTimeOut)) {
        clockTimeOut = clockTimeOut.add(const Duration(days: 1));
      } else if (clockInTime == "--/--" || clockOutTime == "--/--" ) {
        return "0 hour(s) 0 minute(s)";

      }

      Duration diff = clockTimeOut.difference(clockTimeIn);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;

      dev.log('$hours hours $minutes minute');
      return ('$hours hour(s) $minutes minute(s)');
    }catch(e){
      return "0 hour(s) 0 minute(s)";
    }

  }

  double _diffHoursWorked(String clockInTime, String clockOutTime) {
    try{
      var format = DateFormat("h:mm a");
      var clockTimeIn = format.parse(clockInTime);
      var clockTimeOut = format.parse(clockOutTime);
      if (clockTimeIn.isAfter(clockTimeOut)) {
        clockTimeOut = clockTimeOut.add(const Duration(days: 1));
      }

      Duration diff = clockOutTime.isEmpty || clockInTime.isEmpty ? const Duration(minutes: 0): clockTimeOut.difference(clockTimeIn);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      final minCal = minutes / 60;
      String inStringMin = minCal.toStringAsFixed(3);
      double roundedMinDouble = double.parse(inStringMin);
      final totalTime = hours + roundedMinDouble;

      dev.log('$hours hours $minutes minutes');
      return totalTime;
    }catch(e){
      return 0.0;
    }
  }


  DocumentReference<Map<String, dynamic>> getLastAttendanceForDateFirestore(String date) {
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
    final ClockAttendanceWebController controller = Get.find<ClockAttendanceWebController>();
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
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth / 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Obx(() => Text(
                    "Current Latitude: ${controller.lati.value.toStringAsFixed(6)}, Current Longitude: ${controller.longi.value.toStringAsFixed(6)}",
                    style: TextStyle(
                      fontFamily: "NexaBold",
                      fontSize: screenWidth / 23,
                    ),
                  )),
                  const SizedBox(height: 10),
                  Obx(() => Text(
                    "Current State: ${controller.currentStateDisplay.value}", // Updated to use currentStateDisplay
                    style: TextStyle(
                      fontFamily: "NexaBold",
                      fontSize: screenWidth / 23,
                    ),
                  )),
                  const SizedBox(height: 10),
                  Obx(() => Text(
                    "Current Location: ${controller.location.value}",
                    style: TextStyle(
                      fontFamily: "NexaBold",
                      fontSize: screenWidth / 23,
                    ),
                  )),
                  const SizedBox(height: 10),
                  _buildInputFieldBottomSheet("Date", DateFormat("dd/MM/yyyy").format(_selectedDate), IconButton(
                    onPressed: () {
                      _getDateFromUser(setState);
                    },
                    icon: const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                  )),
                  _buildDropdownInputFieldBottomSheet("Reasons For Day off", _reasons, reasonsForDayOff, (String? newValue) {
                    setState(() {
                      _reasons = newValue!;
                    });
                  }),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputFieldBottomSheet("Start Time", _startTime, IconButton(
                          onPressed: () {
                            _getTimeFromUser(isStartTime: true, setState: setState);
                          },
                          icon: const Icon(Icons.access_time_rounded, color: Colors.grey),
                        )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputFieldBottomSheet("End Time", _endTime, IconButton(
                          onPressed: () {
                            _getTimeFromUser(isStartTime: false, setState: setState);
                          },
                          icon: const Icon(Icons.access_time_rounded, color: Colors.grey),
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
                            style: TextStyle(
                              color: Get.isDarkMode ? Colors.white : Colors.black,
                              fontSize: screenWidth / 21,
                              fontFamily: "NexaBold",
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
                                    backgroundColor: index == 0 ? Colors.red : index == 1 ? Colors.blueAccent : Colors.yellow,
                                    child: _selectedColor == index ? const Icon(Icons.done, color: Colors.white, size: 16) : Container(),
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
                            gradient: LinearGradient(colors: [Colors.red, Colors.black]),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: const Center(
                            child: Text(
                              "Submit",
                              style: TextStyle(color: Colors.white),
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
                  child: Text(hint, style: const TextStyle(color: Colors.grey)),
                ),
                widget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownInputFieldBottomSheet(String title, String hint, List<String> items, Function(String?) onChanged) {
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
                    hint: Text(hint.isEmpty ? "Select Reason" : hint, style: const TextStyle(color: Colors.grey)),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    iconSize: 32,
                    elevation: 4,
                    style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black),
                    underline: Container(height: 0),
                    onChanged: onChanged,
                    items: items.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black)),
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
      //_addDaysOffToDb(); // Functionality for adding days off needs implementation
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


  Future<void> _getUserLocation() async {
    try {
      geolocator.Position position = await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.low); // Reduced accuracy here as well

      lati.value = position.latitude;
      longi.value = position.longitude;
      accuracy.value = position.accuracy;
      altitude.value = position.altitude;
      speed.value = position.speed;
      speedAccuracy.value = position.speedAccuracy;
      heading.value = position.heading;
      time.value = position.timestamp.millisecondsSinceEpoch.toDouble();
      isMock.value = position.isMocked;


      List<Placemark> placemark = await placemarkFromCoordinates(position.latitude, position.longitude,); // Specify locale for potentially faster geocoding
      if (placemark.isNotEmpty) {
        location.value =
        "${placemark[0].street}, ${placemark[0].subLocality}, ${placemark[0].subAdministrativeArea}, ${placemark[0].locality}, ${placemark[0].administrativeArea}, ${placemark[0].postalCode}, ${placemark[0].country}";
        administrativeArea.value = placemark[0].administrativeArea ?? "";
      }
      await _updateLocationUsingGeofencing();
    } catch (e) {
      dev.log("Location Error: ${e.toString()}");
    }
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

  double get horizontalPadding => _scaleFactor(mobile: 0.025, tablet: 0.05, desktop: 0.10) * screenWidth;
  double get verticalPadding => _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get verticalSpacing => _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get sectionSpacing => _scaleFactor(mobile: 0.025, tablet: 0.015, desktop: 0.01) * screenWidth;
  double get headerIconSize => _scaleFactor(mobile: 0.04, tablet: 0.03, desktop: 0.02) * screenWidth;
  double get welcomeHeaderTextSize => _scaleFactor(mobile: 0.025, tablet: 0.017, desktop: 0.0125) * screenWidth;
  double get usernameHeaderTextSize => _scaleFactor(mobile: 0.03, tablet: 0.022, desktop: 0.017) * screenWidth;
  double get logoSize => _scaleFactor(mobile: 1/16, tablet: 1/24, desktop: 1/40) * screenWidth;
  double get cardHeaderTextSize => _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get subCardHeaderTextSize => _scaleFactor(mobile: 0.022, tablet: 0.015, desktop: 0.010) * screenWidth;
  double get cardBorderRadius => _scaleFactor(mobile: 6.0, tablet: 7.5, desktop: 9.0);
  double get cardPadding => _scaleFactor(mobile: 0.02, tablet: 0.015, desktop: 0.01) * screenWidth;
  double get cardInnerSpacing => _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get statusTextSize => _scaleFactor(mobile: 0.02, tablet: 0.015, desktop: 0.012) * screenWidth;
  double get statusTextVerticalPadding => _scaleFactor(mobile: 0.0025, tablet: 0.002, desktop: 0.0015) * screenWidth;
  double get dayCompletedTextSize => _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get textFieldBorderRadius => _scaleFactor(mobile: 7.5, tablet: 9.0, desktop: 10.0);
  double get textFieldPadding => _scaleFactor(mobile: 0.04, tablet: 0.03, desktop: 0.02) * screenWidth;
  double get textFieldHintTextSize => _scaleFactor(mobile: 0.02, tablet: 0.015, desktop: 0.012) * screenWidth;
  double get textFieldInputTextSize => _scaleFactor(mobile: 0.022, tablet: 0.017, desktop: 0.014) * screenWidth;
  double get clockDisplayTopMargin => _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get clockDisplayBottomMargin => _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get clockDisplayShadowBlurRadius => _scaleFactor(mobile: 5.0, tablet: 4.0, desktop: 3.0);
  double get clockDisplayBorderRadius => _scaleFactor(mobile: 0.02, tablet: 0.015, desktop: 0.01) * screenWidth;
  double get clockTimeColumnVerticalPadding => _scaleFactor(mobile: 0.015, tablet: 0.0175, desktop: 0.01) * screenWidth;
  double get clockTimeColumnTitleFontSize => _scaleFactor(mobile: 0.022, tablet: 0.017, desktop: 0.012) * screenWidth;
  double get clockTimeColumnTimeFontSize => _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get dateTextSize => _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get timeTextSize => _scaleFactor(mobile: 0.022, tablet: 0.017, desktop: 0.012) * screenWidth;
  double get clockButtonWidth => _scaleFactor(mobile: 0.4, tablet: 0.3, desktop: 0.2) * screenWidth;
  double get clockButtonHeight => _scaleFactor(mobile: 0.25, tablet: 0.25, desktop: 0.25) * screenWidth;
  double get outOfOfficeButtonVerticalPadding => _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get outOfOfficeButtonWidth => _scaleFactor(mobile: 0.35, tablet: 0.25, desktop: 0.17) * screenWidth;
  double get outOfOfficeButtonHeight => _scaleFactor(mobile: 0.04, tablet: 0.03, desktop: 0.02) * screenWidth;
  double get outOfOfficeButtonLeftPadding => _scaleFactor(mobile: 10.0, tablet: 7.5, desktop: 5.0);
  double get outOfOfficeButtonTextSize => _scaleFactor(mobile: 0.02, tablet: 0.015, desktop: 0.01) * screenWidth;
  double get outOfOfficeButtonIconSpacing => _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get locationCardWidth => _scaleFactor(mobile: 0.45, tablet: 0.35, desktop: 0.25) * screenWidth;
  double get locationCardMargin => _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get locationCardVerticalPadding => _scaleFactor(mobile: 0.015, tablet: 0.012, desktop: 0.01) * screenWidth;
  double get locationCardHorizontalPadding => _scaleFactor(mobile: 0.01, tablet: 0.007, desktop: 0.005) * screenWidth;
  double get locationCardHeaderTextSize => _scaleFactor(mobile: 0.025, tablet: 0.02, desktop: 0.015) * screenWidth;
  double get locationInnerContentWidth => _scaleFactor(mobile: 0.35, tablet: 0.3, desktop: 0.2) * screenWidth;
  double get locationColumnSpacing => _scaleFactor(mobile: 0.005, tablet: 0.004, desktop: 0.003) * screenWidth;
  double get locationColumnTitleTextSize => _scaleFactor(mobile: 0.017, tablet: 0.014, desktop: 0.010) * screenWidth;
  double get locationColumnLocationTextSize => _scaleFactor(mobile: 0.015, tablet: 0.012, desktop: 0.009) * screenWidth;
  double get commentButtonWidth => _scaleFactor(mobile: 0.20, tablet: 0.15, desktop: 0.10) * screenWidth;
  double get commentButtonHeight => _scaleFactor(mobile: 0.04, tablet: 0.03, desktop: 0.02) * screenWidth;
  double get commentButtonTextSize => _scaleFactor(mobile: 8.0, tablet: 7.0, desktop: 6.0);


  double _scaleFactor({required double mobile, required double tablet, required double desktop}) {
    switch (screenSize) {
      case ScreenSize.mobile: return mobile;
      case ScreenSize.tablet: return tablet;
      case ScreenSize.desktop: return desktop;
      default: return mobile;
    }
  }
}