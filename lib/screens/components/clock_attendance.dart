import 'dart:async';
import 'dart:developer';

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


import '../../models/user_model.dart';
import '../../services/location_services.dart';
import '../../widgets/drawer.dart';
import '../../widgets/drawer2.dart';
import '../../widgets/geo_utils.dart';
import '../../widgets/header_widget.dart';

class GeofenceModel {
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

// Firestore Service to handle database interactions
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
}


class ClockAttendanceWeb extends StatelessWidget {
  final FirestoreService firestoreService;

  const ClockAttendanceWeb({Key? key, required this.firestoreService, required ClockAttendanceWebController controller})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ClockAttendanceWebController controller = Get.put(ClockAttendanceWebController(firestoreService));

    return Scaffold(
      drawer: drawer(context),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              double screenWidth = constraints.maxWidth;
              bool isMobile = screenWidth < 600;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenWidth * 0.02),
                child: Column(
                  children: [
                    SizedBox(height: screenWidth * 0.02),
                    HeaderWidget(screenWidth * 0.08, false, Icons.house_rounded),
                    SizedBox(height: screenWidth * 0.05),
                    _buildWelcomeHeader(context, controller, screenWidth, isMobile),
                    SizedBox(height: screenWidth * 0.05),
                    _buildStatusCard(context, controller, screenWidth, isMobile),
                    SizedBox(height: screenWidth * 0.05),
                    _buildAttendanceCard(context, controller, screenWidth, isMobile),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _buildWelcomeHeader(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
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
                  fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.03,
                ),
              ),
            ),
            Image(
              image: const AssetImage("./assets/image/ccfn_logo.png"),
              width: screenWidth / (isMobile ? 8 : 18),
              height: screenWidth / (isMobile ? 8 : 18),
            ),
          ],
        ),
        Obx(() => Text(
          "${controller.firstName.value.toString().toUpperCase()} ${controller.lastName.value.toString().toUpperCase()}",
          style: TextStyle(
            color: Colors.black54,
            fontFamily: "NexaBold",
            fontSize: isMobile ? screenWidth * 0.06 : screenWidth * 0.04,
          ),
        )),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
    return Container(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Status:",
            style: TextStyle(
              fontFamily: "NexaBold",
              fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.03,
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          Obx(() => Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade100, Colors.white, Colors.black12],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Geo-Coordinates Information:",
                    style: TextStyle(
                      fontFamily: "NexaBold",
                      fontSize: isMobile ? screenWidth * 0.045 : screenWidth * 0.025,
                      color: Colors.blueGrey,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  _buildStatusText("GPS is:", controller.isGpsEnabled.value ? 'On' : 'Off', screenWidth, isMobile),
                  _buildStatusText("Current Latitude:", controller.lati.value.toStringAsFixed(6), screenWidth, isMobile),
                  _buildStatusText("Current Longitude:", controller.longi.value.toStringAsFixed(6), screenWidth, isMobile),
                  _buildStatusText("Coordinates Accuracy:", controller.accuracy.value.toString(), screenWidth, isMobile),
                  _buildStatusText("Altitude:", controller.altitude.value.toString(), screenWidth, isMobile),
                  _buildStatusText("Speed:", controller.speed.value.toString(), screenWidth, isMobile),
                  _buildStatusText("Speed Accuracy:", controller.speedAccuracy.value.toString(), screenWidth, isMobile),
                  _buildStatusText("Location Data Timestamp:", DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(controller.time.value.toInt())), screenWidth, isMobile),
                  _buildStatusText("Is Location Mocked?:", controller.isMock.value.toString(), screenWidth, isMobile),
                  _buildStatusText("Current State:", controller.administrativeArea.value, screenWidth, isMobile),
                  _buildStatusText("Current Location:", controller.location.value, screenWidth, isMobile),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatusText(String label, String value, double screenWidth, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.005),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: "NexaBold",
            fontSize: isMobile ? screenWidth * 0.04 : screenWidth * 0.023,
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

  Widget _buildAttendanceCard(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
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
              return _buildClockOutSection(context, controller, lastAttendance, screenWidth, isMobile);
            } else if (lastAttendance.clockIn != "--/--" && lastAttendance.clockOut != "--/--") {
              return _buildDayCompletedSection(context, controller, lastAttendance, screenWidth, isMobile);
            } else {
              return _buildClockInSection(context, controller, screenWidth, isMobile, lastAttendance);
            }
          } else {
            return _buildClockInSection(context, controller, screenWidth, isMobile, null);
          }
        } else {
          return _buildClockInSection(context, controller, screenWidth, isMobile, null);
        }
      },
    );
  }


  Widget _buildClockInSection(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile, AttendanceModelFirestore? lastAttendance) {
    return Column(
      children: [
        _buildClockInOutDisplay(context, controller, screenWidth, isMobile), // Modified to use StreamBuilder inside
        SizedBox(height: screenWidth * 0.02),
        _buildDateAndStream(screenWidth, isMobile),
        SizedBox(height: screenWidth * 0.05),
        _buildClockInImageButton(context, controller, screenWidth, isMobile), // Replaced Slider with Image Button
        SizedBox(height: screenWidth * 0.02),
        _buildOutOfOfficeButton(context, controller, screenWidth, isMobile),
        SizedBox(height: screenWidth * 0.02),
        _buildLocationStatusCard(context, controller, screenWidth, isMobile),
      ],
    );
  }

  Widget _buildClockOutSection(BuildContext context, ClockAttendanceWebController controller, AttendanceModelFirestore? lastAttendance, double screenWidth, bool isMobile) {
    return Column(
      children: [
        _buildClockInOutDisplay(context, controller, screenWidth, isMobile), // Modified to use StreamBuilder inside
        SizedBox(height: screenWidth * 0.02),
        _buildDateAndStream(screenWidth, isMobile),
        SizedBox(height: screenWidth * 0.05),
        _buildClockOutImageButton(context, controller, screenWidth, isMobile), // Replaced Slider with Image Button
        SizedBox(height: screenWidth * 0.02),
        _buildLocationStatusCard(context, controller, screenWidth, isMobile),
      ],
    );
  }


  Widget _buildDayCompletedSection(BuildContext context, ClockAttendanceWebController controller, AttendanceModelFirestore? lastAttendance, double screenWidth, bool isMobile) {
    final TextEditingController commentsController = TextEditingController();
    return Column(
      children: [
        _buildClockInOutDisplay(context, controller, screenWidth, isMobile), // Modified to use StreamBuilder inside
        SizedBox(height: screenWidth * 0.02),
        _buildDateAndStream(screenWidth, isMobile),
        SizedBox(height: screenWidth * 0.03),
        Text(
          "You have completed this day!!!",
          style: TextStyle(
            fontFamily: "NexaLight",
            fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.03,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
        Obx(() => Text(
          "Duration Worked: ${controller.durationWorked.value}",
          style: TextStyle(
            fontFamily: "NexaLight",
            fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.03,
            color: Colors.black54,
          ),
        )),
        SizedBox(height: screenWidth * 0.02),
        Obx(() => Text(
          "Comment(s): ${controller.comments.value}",
          style: TextStyle(
            fontFamily: "NexaLight",
            fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.03,
            color: Colors.black54,
          ),
        )),
        SizedBox(height: screenWidth * 0.03),
        TextField(
          controller: commentsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Comments (If Any)",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0)),
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
        Obx(() => controller.comments.value == "No Comment" ? _buildAddCommentButton(context, commentsController, screenWidth, isMobile) : const SizedBox(height: 0)),
        SizedBox(height: screenWidth * 0.02),
        _buildLocationStatusCard(context, controller, screenWidth, isMobile),
        SizedBox(height: screenWidth * 0.02),
      ],
    );
  }


  Widget _buildClockInOutDisplay(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
    return Container(
      margin: EdgeInsets.only(top: screenWidth * 0.02, bottom: screenWidth * 0.05),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(2, 2)),
        ],
        borderRadius: BorderRadius.all(Radius.circular(screenWidth * 0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StreamBuilder<String>(
              stream: controller.clockInStream,
              initialData: controller.clockIn.value,
              builder: (context, snapshot) {
                return _buildClockTimeColumn("Clock In", snapshot.data ?? "--/--", screenWidth, isMobile);
              }
          ),
          StreamBuilder<String>(
              stream: controller.clockOutStream,
              initialData: controller.clockOut.value,
              builder: (context, snapshot) {
                return _buildClockTimeColumn("Clock Out", snapshot.data ?? "--/--", screenWidth, isMobile);
              }
          ),
        ],
      ),
    );
  }

  Widget _buildClockTimeColumn(String title, String time, double screenWidth, bool isMobile) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: "NexaLight",
                fontSize: isMobile ? screenWidth * 0.045 : screenWidth * 0.03,
                color: Colors.black54,
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontFamily: "NexaBold",
                fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.035,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateAndStream(double screenWidth, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: DateTime.now().day.toString(),
            style: TextStyle(
              color: Colors.red,
              fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.035,
              fontFamily: "NexaBold",
            ),
            children: [
              TextSpan(
                text: DateFormat(" MMMM yyyy").format(DateTime.now()),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.035,
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
                fontSize: isMobile ? screenWidth * 0.045 : screenWidth * 0.03,
                color: Colors.black54,
              ),
            );
          },
        ),
      ],
    );
  }


  Widget _buildClockInImageButton(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
    return GestureDetector(
      onTap: () async {
        await controller.clockInUpdated(controller.lati.value, controller.longi.value, controller.location.value);
      },
      child: Container(
        width: screenWidth * 0.8, // Adjust width as needed
        height: screenWidth * 0.25, // Adjust height as needed to maintain aspect ratio
        child: Image.asset(
          'assets/image/clockin9.jpg', // Path to your clock-in image
          fit: BoxFit.contain, // or BoxFit.fill, BoxFit.cover, etc.
        ),
      ),
    );
  }


  Widget _buildClockOutImageButton(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
    return GestureDetector(
      onTap: () async {
        await controller.clockOutUpdated(controller.lati.value, controller.longi.value, controller.location.value);
      },
      child: Container(
        width: screenWidth * 0.8, // Adjust width as needed
        height: screenWidth * 0.25, // Adjust height as needed to maintain aspect ratio
        child: Image.asset(
          'assets/image/clockout8.jpg', // Path to your clock-out image
          fit: BoxFit.contain, // or BoxFit.fill, BoxFit.cover, etc.
        ),
      ),
    );
  }


  Widget _buildOutOfOfficeButton(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
    return Padding(
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
        child: GestureDetector(
          onTap: (){
            controller.showBottomSheet3(context);
          },
          child: Container(
            width: screenWidth * 0.70,
            height: screenWidth * 0.08,
            padding: const EdgeInsets.only(left: 20.0, bottom: 0.0),
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
                        fontSize: isMobile ? screenWidth * 0.04 : screenWidth * 0.03),
                  ),
                  SizedBox(width:screenWidth * 0.02),
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


  Widget _buildLocationStatusCard(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
    return Container(
      width: screenWidth * 0.9,
      margin: EdgeInsets.all(screenWidth * 0.02),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red, Colors.black]),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03, horizontal: screenWidth * 0.02),
      child: Column(
        children: [
          Text(
            "Location Status",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.035,
              fontFamily: "NexaBold",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          SizedBox(
            width: screenWidth * 0.7,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildClockInLocationColumn("Clock-In Location", controller, screenWidth, isMobile),
                SizedBox(width: screenWidth * 0.01),
                _buildClockOutLocationColumn("Clock-Out Location", controller, screenWidth, isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockInLocationColumn(String title, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: "NexaLight",
              fontSize: isMobile ? screenWidth * 0.035 : screenWidth * 0.025,
              color: Colors.white,
            ),
          ),
          SizedBox(height: screenWidth * 0.01),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: controller.firestoreService.streamAttendanceRecord(controller.firestoreService.getUserId()!, DateFormat('dd-MMMM-yyyy').format(DateTime.now())), // Use stream from FirestoreService
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(); // Loading indicator
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)); // Error text
              } else if (snapshot.hasData && snapshot.data!.exists) {
                final attendanceData = snapshot.data!.data();
                final lastAttendance = AttendanceModelFirestore.fromMap(attendanceData!);
                return Text(
                  lastAttendance.clockInLocation ?? "",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "NexaBold",
                    fontSize: isMobile ? screenWidth * 0.03 : screenWidth * 0.02,
                    color: Colors.white,
                  ),
                );
              } else {
                return Text("",  // No data available
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "NexaBold",
                    fontSize: isMobile ? screenWidth * 0.03 : screenWidth * 0.02,
                    color: Colors.white,
                  ),);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClockOutLocationColumn(String title, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: "NexaLight",
              fontSize: isMobile ? screenWidth * 0.035 : screenWidth * 0.025,
              color: Colors.white,
            ),
          ),
          SizedBox(height: screenWidth * 0.01),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: controller.firestoreService.streamAttendanceRecord(controller.firestoreService.getUserId()!, DateFormat('dd-MMMM-yyyy').format(DateTime.now())), // Use stream from FirestoreService
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(); // Loading indicator
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)); // Error text
              } else if (snapshot.hasData && snapshot.data!.exists) {
                final attendanceData = snapshot.data!.data();
                final lastAttendance = AttendanceModelFirestore.fromMap(attendanceData!);
                return Text(
                  lastAttendance.clockOutLocation ?? "--/--",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "NexaBold",
                    fontSize: isMobile ? screenWidth * 0.03 : screenWidth * 0.02,
                    color: Colors.white,
                  ),
                );
              } else {
                return Text("--/--", // No data available
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "NexaBold",
                    fontSize: isMobile ? screenWidth * 0.03 : screenWidth * 0.02,
                    color: Colors.white,
                  ),);
              }
            },
          ),
        ],
      ),
    );
  }


  Widget _buildAddCommentButton(BuildContext context, TextEditingController commentsController, double screenWidth, bool isMobile) {
    return GestureDetector(
      onTap: () => Get.find<ClockAttendanceWebController>().handleAddComments(context, commentsController.text),
      child: Container(
        width: screenWidth * 0.40,
        height: screenWidth * 0.08,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.red, Colors.black]),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: const Center(
          child: Text(
            "Add Comment",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}


// AttendanceModelFirestore and ClockAttendanceWebController are updated as below.

// AttendanceModelFirestore for web
class AttendanceModelFirestore {
  int? id;
  String? clockIn;
  String? clockOut;
  String? clockInLocation;
  String? clockOutLocation;
  String? date;
  int? isSynced;
  String? clockInLatitude;
  String? clockInLongitude;
  String? clockOutLatitude;
  String? clockOutLongitude;
  String? durationWorked;
  double? noOfHours;
  bool? voided;
  bool? isUpdated;
  bool? offDay;
  String? month;
  String? comments;


  AttendanceModelFirestore({
    this.id,
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
      id: map['id'] as int?,
      clockIn: map['clockIn'] as String?,
      clockOut: map['clockOut'] as String?,
      clockInLocation: map['clockInLocation'] as String?,
      clockOutLocation: map['clockOutLocation'] as String?,
      date: map['date'] as String?,
      isSynced: map['isSynced'] as int?,
      clockInLatitude: map['clockInLatitude'] as String?,
      clockInLongitude: map['clockInLongitude'] as String?,
      clockOutLatitude: map['clockOutLatitude'] as String?,
      clockOutLongitude: map['clockOutLongitude'] as String?,
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
      'id': id,
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


// ClockAttendanceWebController (clock_attendance_controller.dart)
class ClockAttendanceWebController extends GetxController {
  final FirestoreService firestoreService;

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


  RxString administrativeArea = "".obs;
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
    _init();
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

  void _init() async {
    await _loadNTPTime();
    await _getAttendanceSummary();
    await _getUserDetail();
    _getUserLocation();


    await getLocationStatus().then((_) async {
      await getPermissionStatus().then((_) async {
        await _startLocationService();
      });
    });

    await checkInternetConnection();

  }


  Timer? _locationTimer;


  Future<void> _getLocationDetailsFromLocationModel() async {

    print("getLocationDetailsFromLocationModel is skipped for web in this example");
  }



  Future<void> _updateLocationUsingGeofencing() async {

    if (lati.value != 0.0 && location.value == "") {
      print("Geofencing is skipped for web in this example");
    }
  }

  Future<void> _updateLocationUsingGeofencing2(double latitde, double longitde) async {
    print("_updateLocationUsingGeofencing2 is skipped for web in this example");
  }


  Future<void> _loadNTPTime() async {
    try {
      ntpTime = await NTP.now(lookUpAddress: "pool.ntp.org");
    } catch (e) {
      log("Error getting NTP time: ${e.toString()}");

      ntpTime = DateTime.now();
    }
  }

  Future<void> _getUserDetail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      firebaseAuthId.value = user.uid;
      emailAddress.value = user.email ?? "";


      firstName.value = "Web User";
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

        _clockInStreamController.add(clockIn.value);
        _clockOutStreamController.add(clockOut.value);
        _clockInLocationStreamController.add(clockInLocation.value);
        _clockOutLocationStreamController.add(clockOutLocation.value);
      }
    } catch (e) {
      log("Error in _getAttendanceSummary: ${e.toString()}");
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


    return await geolocator.Geolocator.getCurrentPosition();
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
          desiredAccuracy: geolocator.LocationAccuracy.best,
          forceAndroidLocationManager: true,
        );

        if (position != null && position.latitude != null && position.longitude != null) {
          lati.value = position.latitude!;
          longi.value = position.longitude!;
          print("locationData.latitude == ${position.latitude}");
          _updateLocation();
        } else {
          print("_getLocation2: getCurrentPosition returned null position");
        }
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


      if (administrativeArea.value != '') {
        isInsideAnyGeofence.value = false;


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

    if (permission != null) {
      isLocationPermissionGranted.value = permission;

      if (isLocationPermissionGranted.value == LocationPermission.denied ||
          isLocationPermissionGranted.value == LocationPermission.deniedForever) {
        isAlertSet2.value = true;
      }
    } else {
      print("Error: Geolocator.checkPermission() returned null");
      isLocationPermissionGranted.value = LocationPermission.denied;
      isAlertSet2.value = true;
    }
  }

  Future<void> checkInternetConnection() async {

  }


  Future<void> handleAddComments(
      BuildContext context,String? commentsForAttendance) async {


    try {

      final attendanceResult = await getLastAttendanceForDateFirestore(DateFormat('dd-MMMM-yyyy').format(DateTime.now()));
      final attendanceData = await attendanceResult.get();

      if (attendanceData.exists) {
        AttendanceModelFirestore lastAttendance = AttendanceModelFirestore.fromMap(attendanceData.data()!);
        if (lastAttendance.date == DateFormat('dd-MMMM-yyyy').format(DateTime.now())) {
          await addComments(DateFormat('dd-MMMM-yyyy').format(DateTime.now()),commentsForAttendance!);
        }
      }


    } catch (e) {
      log("Attendance Comment Error ====== ${e.toString()}");

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
                clockIn: DateFormat('hh:mm a').format(DateTime.now()),
                date: currentDate,
                clockInLatitude: newlatitude.toString(),
                clockInLocation: newlocation,
                clockInLongitude: newlongitude.toString(),
                clockOut: "--/--",
                clockOutLatitude: "0.0",
                clockOutLocation: '',
                clockOutLongitude: "0.0",
                isSynced: 0,
                voided: false,
                isUpdated: false,
                durationWorked: "0 hours 0 minutes",
                noOfHours: 0.0,
                offDay: false,
                month: DateFormat('MMMM yyyy').format(DateTime.now()),
                comments: "No Comment",
              ).toMap();

              await firestoreService.createAttendanceRecord(userId, currentDate, attendance);

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
                      clockIn: DateFormat('hh:mm a').format(DateTime.now()),
                      date: currentDate,
                      clockInLatitude: newlatitude.toString(),
                      clockInLocation: newlocation,
                      clockInLongitude: newlongitude.toString(),
                      clockOut: "--/--",
                      clockOutLatitude: "0.0",
                      clockOutLocation: '',
                      clockOutLongitude: "0.0",
                      isSynced: 0,
                      voided: false,
                      isUpdated: false,
                      durationWorked: "0 hours 0 minutes",
                      noOfHours: 0.0,
                      offDay: false,
                      month: DateFormat('MMMM yyyy').format(DateTime.now()),
                      comments: "No Comment",
                    ).toMap();

                    await firestoreService.createAttendanceRecord(userId, currentDate, attendance);

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
                      'clockOutLatitude': newlatitude.toString(),
                      'clockOutLongitude': newlongitude.toString(),
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

      log('$hours hours $minutes minute');
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

      log('$hours hours $minutes minutes');
      return totalTime;
    }catch(e){
      return 0.0;
    }
  }


  // Helper function to get the last attendance record for the current date from Firestore
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
                    "Current State: ${controller.administrativeArea.value}",
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
                  child: Text(hint, style: TextStyle(color: Colors.grey)),
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
                    hint: Text(hint.isEmpty ? "Select Reason" : hint, style: TextStyle(color: Colors.grey)),
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
          desiredAccuracy: geolocator.LocationAccuracy.high);

      lati.value = position.latitude;
      longi.value = position.longitude;
      accuracy.value = position.accuracy;
      altitude.value = position.altitude;
      speed.value = position.speed;
      speedAccuracy.value = position.speedAccuracy;
      heading.value = position.heading;
      time.value = position.timestamp.millisecondsSinceEpoch.toDouble();
      isMock.value = position.isMocked;


      List<Placemark> placemark = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemark.isNotEmpty) {
        location.value =
        "${placemark[0].street}, ${placemark[0].subLocality}, ${placemark[0].subAdministrativeArea}, ${placemark[0].locality}, ${placemark[0].administrativeArea}, ${placemark[0].postalCode}, ${placemark[0].country}";
        administrativeArea.value = placemark[0].administrativeArea ?? "";
      }
    } catch (e) {
      log("Location Error: ${e.toString()}");
    }
  }
}