// import 'dart:async';
// import 'dart:developer';
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart' as geolocator;
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import 'package:ntp/ntp.dart';
// import 'package:slide_to_act/slide_to_act.dart';
// import 'package:synchronized/synchronized.dart';
// import 'package:location/location.dart' as locationPkg;
//
// import '../../widgets/header_widget.dart';
//
// class GeofenceModel {
//   final String name;
//   final double latitude;
//   final double longitude;
//   final double radius;
//
//   GeofenceModel({
//     required this.name,
//     required this.latitude,
//     required this.longitude,
//     required this.radius,
//   });
// }
//
// class ClockAttendanceWeb1 extends StatelessWidget {
//   ClockAttendanceWeb1({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final ClockAttendanceWebController controller = Get.put(ClockAttendanceWebController());
//     return Scaffold(
//       body: SafeArea( // Use SafeArea to avoid overlapping with system UI
//         child: Center(
//           child: LayoutBuilder( // Use LayoutBuilder for responsiveness
//             builder: (context, constraints) {
//               double screenWidth = constraints.maxWidth;
//               bool isMobile = screenWidth < 600; // Define mobile breakpoint
//               return SingleChildScrollView(
//                 padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenWidth * 0.02), // Responsive padding
//                 child: Column(
//                   children: [
//                     SizedBox(height: screenWidth * 0.02), // Responsive spacing
//                     HeaderWidget(screenWidth * 0.08, false, Icons.house_rounded), // Responsive header size
//                     SizedBox(height: screenWidth * 0.05), // Responsive spacing
//                     _buildWelcomeHeader(context, controller, screenWidth, isMobile),
//                     SizedBox(height: screenWidth * 0.05), // Responsive spacing
//                     _buildStatusCard(context, controller, screenWidth, isMobile),
//                     SizedBox(height: screenWidth * 0.05), // Responsive spacing
//                     _buildAttendanceCard(context, controller, screenWidth, isMobile),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildWelcomeHeader(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.center, // Center content
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center, // Center items horizontally
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             Expanded( // Use Expanded for text to take available space
//               child: Text(
//                 "Welcome",
//                 textAlign: TextAlign.start, // Align text to start within the expanded space
//                 style: TextStyle(
//                   color: Colors.black54,
//                   fontFamily: "NexaLight",
//                   fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.03, // Responsive font size
//                 ),
//               ),
//             ),
//             Image(
//               image: const AssetImage("./assets/image/ccfn_logo.png"),
//               width: screenWidth / (isMobile ? 8 : 18), // Responsive logo size
//               height: screenWidth / (isMobile ? 8 : 18),
//             ),
//           ],
//         ),
//         Obx(() => Text(
//           "${controller.firstName.value.toString().toUpperCase()} ${controller.lastName.value.toString().toUpperCase()}",
//           style: TextStyle(
//             color: Colors.black54,
//             fontFamily: "NexaBold",
//             fontSize: isMobile ? screenWidth * 0.06 : screenWidth * 0.04, // Responsive font size
//           ),
//         )),
//       ],
//     );
//   }
//
//
//   Widget _buildStatusCard(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
//     return Container(
//       alignment: Alignment.centerLeft,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             "Today's Status:",
//             style: TextStyle(
//               fontFamily: "NexaBold",
//               fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.03, // Responsive font size
//             ),
//           ),
//           SizedBox(height: screenWidth * 0.02), // Responsive spacing
//           Obx(() => Card(
//             elevation: 4,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                   colors: [Colors.red.shade100, Colors.white, Colors.black12],
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               padding: EdgeInsets.all(screenWidth * 0.04), // Responsive padding
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     "Geo-Coordinates Information:",
//                     style: TextStyle(
//                       fontFamily: "NexaBold",
//                       fontSize: isMobile ? screenWidth * 0.045 : screenWidth * 0.025, // Responsive font size
//                       color: Colors.blueGrey,
//                     ),
//                   ),
//                   SizedBox(height: screenWidth * 0.02), // Responsive spacing
//                   _buildStatusText("GPS is:", controller.isGpsEnabled.value ? 'On' : 'Off', screenWidth, isMobile),
//                   _buildStatusText("Current Latitude:", controller.lati.value.toStringAsFixed(6), screenWidth, isMobile),
//                   _buildStatusText("Current Longitude:", controller.longi.value.toStringAsFixed(6), screenWidth, isMobile),
//                   _buildStatusText("Coordinates Accuracy:", controller.accuracy.value.toString(), screenWidth, isMobile),
//                   _buildStatusText("Altitude:", controller.altitude.value.toString(), screenWidth, isMobile),
//                   _buildStatusText("Speed:", controller.speed.value.toString(), screenWidth, isMobile),
//                   _buildStatusText("Speed Accuracy:", controller.speedAccuracy.value.toString(), screenWidth, isMobile),
//                   _buildStatusText("Location Data Timestamp:", DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(controller.time.value.toInt())), screenWidth, isMobile),
//                   _buildStatusText("Is Location Mocked?:", controller.isMock.value.toString(), screenWidth, isMobile),
//                   _buildStatusText("Current State:", controller.administrativeArea.value, screenWidth, isMobile),
//                   _buildStatusText("Current Location:", controller.location.value, screenWidth, isMobile),
//                 ],
//               ),
//             ),
//           )),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatusText(String label, String value, double screenWidth, bool isMobile) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: screenWidth * 0.005), // Responsive vertical padding
//       child: RichText(
//         text: TextSpan(
//           style: TextStyle(
//             fontFamily: "NexaBold",
//             fontSize: isMobile ? screenWidth * 0.04 : screenWidth * 0.023, // Responsive font size
//             color: Colors.black87,
//           ),
//           children: <TextSpan>[
//             TextSpan(text: '$label ', style: const TextStyle(color: Colors.blueGrey)),
//             TextSpan(text: value),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildAttendanceCard(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
//     return FutureBuilder<AttendanceModel?>(
//       future: controller.getLastAttendanceFordate(DateFormat('dd-MMMM-yyyy').format(DateTime.now())),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const CircularProgressIndicator();
//         } else if (snapshot.hasError) {
//           return Text('Error: ${snapshot.error}');
//         } else if (snapshot.hasData) {
//           final lastAttendance = snapshot.data;
//           if (lastAttendance?.clockIn != "--/--" && lastAttendance?.clockOut == "--/--") {
//             return _buildClockOutSection(context, controller, lastAttendance, screenWidth, isMobile);
//           } else if (lastAttendance?.clockIn != "--/--" && lastAttendance?.clockOut != "--/--") {
//             return _buildDayCompletedSection(context, controller, lastAttendance, screenWidth, isMobile);
//           } else {
//             return _buildClockInSection(context, controller, screenWidth, isMobile);
//           }
//         } else {
//           return _buildClockInSection(context, controller, screenWidth, isMobile); // Default to clock-in section if no data
//         }
//       },
//     );
//   }
//
//   Widget _buildClockInSection(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
//     return Column(
//       children: [
//         _buildClockInOutDisplay(context, "--/--", "--/--", screenWidth, isMobile),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//         _buildDateAndStream(screenWidth, isMobile),
//         SizedBox(height: screenWidth * 0.05), // Responsive spacing
//         _buildClockInSlider(context, controller, screenWidth, isMobile),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//         _buildOutOfOfficeButton(context, controller, screenWidth, isMobile),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//         _buildLocationStatusCard(context, controller, "--/--", "--/--", screenWidth, isMobile), // Initial location status
//       ],
//     );
//   }
//
//   Widget _buildClockOutSection(BuildContext context, ClockAttendanceWebController controller, AttendanceModel? lastAttendance, double screenWidth, bool isMobile) {
//     return Column(
//       children: [
//         _buildClockInOutDisplay(context, lastAttendance?.clockIn ?? "--/--", lastAttendance?.clockOut ?? "--/--", screenWidth, isMobile),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//         _buildDateAndStream(screenWidth, isMobile),
//         SizedBox(height: screenWidth * 0.05), // Responsive spacing
//         _buildClockOutSlider(context, controller, screenWidth, isMobile),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//         _buildLocationStatusCard(context, controller, lastAttendance?.clockInLocation ?? "--/--", lastAttendance?.clockOutLocation ?? "--/--", screenWidth, isMobile),
//       ],
//     );
//   }
//
//   Widget _buildDayCompletedSection(BuildContext context, ClockAttendanceWebController controller, AttendanceModel? lastAttendance, double screenWidth, bool isMobile) {
//     final TextEditingController commentsController = TextEditingController();
//     return Column(
//       children: [
//         _buildClockInOutDisplay(context, lastAttendance?.clockIn ?? "--/--", lastAttendance?.clockOut ?? "--/--", screenWidth, isMobile),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//         _buildDateAndStream(screenWidth, isMobile),
//         SizedBox(height: screenWidth * 0.03), // Responsive spacing
//         Text(
//           "You have completed this day!!!",
//           style: TextStyle(
//             fontFamily: "NexaLight",
//             fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.03, // Responsive font size
//             color: Colors.black54,
//           ),
//         ),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//         Obx(() => Text(
//           "Duration Worked: ${controller.durationWorked.value}",
//           style: TextStyle(
//             fontFamily: "NexaLight",
//             fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.03, // Responsive font size
//             color: Colors.black54,
//           ),
//         )),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//         Obx(() => Text(
//           "Comment(s): ${controller.comments.value}",
//           style: TextStyle(
//             fontFamily: "NexaLight",
//             fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.03, // Responsive font size
//             color: Colors.black54,
//           ),
//         )),
//         SizedBox(height: screenWidth * 0.03), // Responsive spacing
//         TextField(
//           controller: commentsController,
//           maxLines: 3,
//           decoration: InputDecoration(
//             hintText: "Comments (If Any)",
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0)),
//           ),
//         ),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//         controller.comments.value == "No Comment" ? _buildAddCommentButton(context, commentsController, screenWidth, isMobile) : const SizedBox(height: 0),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//         _buildLocationStatusCard(context, controller, lastAttendance?.clockInLocation ?? "--/--", lastAttendance?.clockOutLocation ?? "--/--", screenWidth, isMobile),
//         SizedBox(height: screenWidth * 0.02), // Responsive spacing
//       ],
//     );
//   }
//
//   Widget _buildClockInOutDisplay(BuildContext context, String clockInTime, String clockOutTime, double screenWidth, bool isMobile) {
//     return Container(
//       margin: EdgeInsets.only(top: screenWidth * 0.02, bottom: screenWidth * 0.05), // Responsive margins
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(2, 2)),
//         ],
//         borderRadius: BorderRadius.all(Radius.circular(screenWidth * 0.04)), // Responsive border radius
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           _buildClockTimeColumn("Clock In", clockInTime, screenWidth, isMobile),
//           _buildClockTimeColumn("Clock Out", clockOutTime, screenWidth, isMobile),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildClockTimeColumn(String title, String time, double screenWidth, bool isMobile) {
//     return Expanded(
//       child: Padding(
//         padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03), // Responsive padding
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             Text(
//               title,
//               style: TextStyle(
//                 fontFamily: "NexaLight",
//                 fontSize: isMobile ? screenWidth * 0.045 : screenWidth * 0.03, // Responsive font size
//                 color: Colors.black54,
//               ),
//             ),
//             Text(
//               time,
//               style: TextStyle(
//                 fontFamily: "NexaBold",
//                 fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.035, // Responsive font size
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildDateAndStream(double screenWidth, bool isMobile) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         RichText(
//           text: TextSpan(
//             text: DateTime.now().day.toString(),
//             style: TextStyle(
//               color: Colors.red,
//               fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.035, // Responsive font size
//               fontFamily: "NexaBold",
//             ),
//             children: [
//               TextSpan(
//                 text: DateFormat(" MMMM yyyy").format(DateTime.now()),
//                 style: TextStyle(
//                   color: Colors.black,
//                   fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.035, // Responsive font size
//                   fontFamily: "NexaBold",
//                 ),
//               ),
//             ],
//           ),
//         ),
//         StreamBuilder(
//           stream: Stream.periodic(const Duration(seconds: 1)),
//           builder: (context, snapshot) {
//             return Text(
//               DateFormat("hh:mm:ss a").format(DateTime.now()),
//               style: TextStyle(
//                 fontFamily: "NexaLight",
//                 fontSize: isMobile ? screenWidth * 0.045 : screenWidth * 0.03, // Responsive font size
//                 color: Colors.black54,
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
//
//
//   Widget _buildClockInSlider(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
//     return Container(
//       margin: EdgeInsets.only(top: screenWidth * 0.03, bottom: screenWidth * 0.03), // Responsive margins
//       child: Builder(
//         builder: (context) {
//           final GlobalKey<SlideActionState> key = GlobalKey();
//           return Obx(() => SlideAction(
//             text: "Slide to Clock In",
//             animationDuration: const Duration(milliseconds: 300),
//             submittedIcon: controller.isLoading.value ? const CircularProgressIndicator() : const Icon(Icons.done),
//             textStyle: TextStyle(
//               color: Colors.black54,
//               fontSize: isMobile ? screenWidth * 0.045 : screenWidth * 0.03, // Responsive font size
//               fontFamily: "NexaLight",
//             ),
//             outerColor: Colors.white,
//             innerColor: Colors.red,
//             key: key,
//             onSubmit: controller.isLoading.value ? null : () async {
//               await controller.clockInUpdated(controller.lati.value, controller.longi.value, controller.location.value);
//             },
//             sliderButtonIcon: controller.isLoading.value ? const CircularProgressIndicator(strokeWidth: 2) : const Icon(Icons.arrow_forward_ios_rounded),
//           ));
//         },
//       ),
//     );
//   }
//
//   Widget _buildClockOutSlider(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
//     return Container(
//       margin: EdgeInsets.only(top: screenWidth * 0.03, bottom: screenWidth * 0.03), // Responsive margins
//       child: Builder(
//         builder: (context) {
//           final GlobalKey<SlideActionState> key = GlobalKey();
//           return Obx(() => SlideAction(
//             text: "Slide to Clock Out",
//             animationDuration: const Duration(milliseconds: 300),
//             submittedIcon: controller.isLoading.value ? const CircularProgressIndicator() : const Icon(Icons.done),
//             textStyle: TextStyle(
//               color: Colors.black54,
//               fontSize: isMobile ? screenWidth * 0.045 : screenWidth * 0.03, // Responsive font size
//               fontFamily: "NexaLight",
//             ),
//             outerColor: Colors.white,
//             innerColor: Colors.red,
//             key: key,
//             onSubmit: controller.isLoading.value ? null : () async {
//               await controller.clockOutUpdated(controller.lati.value, controller.longi.value, controller.location.value);
//             },
//             sliderButtonIcon: controller.isLoading.value ? const CircularProgressIndicator(strokeWidth: 2) : const Icon(Icons.arrow_forward_ios_rounded),
//           ));
//         },
//       ),
//     );
//   }
//
//   Widget _buildOutOfOfficeButton(BuildContext context, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
//     return StreamBuilder<String>(
//       stream: controller.clockInStream,
//       builder: (context, snapshot) {
//         if (snapshot.hasData) {
//           return const SizedBox.shrink();
//         } else {
//           return GestureDetector(
//             onTap: () {
//               controller.showBottomSheet3(context);
//             },
//             child: Container(
//               width: screenWidth * 0.70,
//               height: screenWidth * 0.08, // Responsive button height
//               padding: const EdgeInsets.only(left: 20.0, bottom: 0.0),
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(colors: [Colors.red, Colors.black]),
//                 borderRadius: BorderRadius.all(Radius.circular(20)),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center, // Center content
//                 children: [
//                   Text(
//                     "Out Of Office? CLICK HERE",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: isMobile ? screenWidth * 0.04 : screenWidth * 0.03, // Responsive font size
//                     ),
//                   ),
//                   SizedBox(width: screenWidth * 0.02), // Responsive spacing
//                   const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
//                 ],
//               ),
//             ),
//           );
//         }
//       },
//     );
//   }
//
//   Widget _buildLocationStatusCard(BuildContext context, ClockAttendanceWebController controller, String clockInLocation, String clockOutLocation, double screenWidth, bool isMobile) {
//     return Container(
//       width: screenWidth * 0.9,
//       margin: EdgeInsets.all(screenWidth * 0.02), // Responsive margins
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(colors: [Colors.red, Colors.black]),
//         borderRadius: BorderRadius.all(Radius.circular(24)),
//       ),
//       padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03, horizontal: screenWidth * 0.02), // Responsive padding
//       child: Column(
//         children: [
//           Text(
//             "Location Status",
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: isMobile ? screenWidth * 0.05 : screenWidth * 0.035, // Responsive font size
//               fontFamily: "NexaBold",
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: screenWidth * 0.02), // Responsive spacing
//           SizedBox(
//             width: screenWidth * 0.7,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 _buildLocationColumn("Clock-In Location", clockInLocation, controller, screenWidth, isMobile),
//                 SizedBox(width: screenWidth * 0.01), // Responsive spacing
//                 _buildLocationColumn("Clock-Out Location", clockOutLocation, controller, screenWidth, isMobile),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLocationColumn(String title, String initialLocation, ClockAttendanceWebController controller, double screenWidth, bool isMobile) {
//     return Expanded(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontFamily: "NexaLight",
//               fontSize: isMobile ? screenWidth * 0.035 : screenWidth * 0.025, // Responsive font size
//               color: Colors.white,
//             ),
//           ),
//           SizedBox(height: screenWidth * 0.01), // Responsive spacing
//           StreamBuilder<AttendanceModel?>(
//             stream: controller.watchLastAttendance(DateFormat('MMMM').format(DateTime.now())),
//             builder: (context, snapshot) {
//               String location = initialLocation; // Default location
//               if (snapshot.hasData && snapshot.data != null) {
//                 if (title == "Clock-In Location") {
//                   location = snapshot.data!.clockInLocation ?? "--/--";
//                 } else if (title == "Clock-Out Location") {
//                   location = snapshot.data!.clockOutLocation ?? "--/--";
//                 }
//               }
//               return Text(
//                 location,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontFamily: "NexaBold",
//                   fontSize: isMobile ? screenWidth * 0.03 : screenWidth * 0.02, // Responsive font size
//                   color: Colors.white,
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAddCommentButton(BuildContext context, TextEditingController commentsController, double screenWidth, bool isMobile) {
//     return GestureDetector(
//       onTap: () => _handleAddComments(context, commentsController.text),
//       child: Container(
//         width: screenWidth * 0.40,
//         height: screenWidth * 0.08, // Responsive button height
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(colors: [Colors.red, Colors.black]),
//           borderRadius: BorderRadius.all(Radius.circular(20)),
//         ),
//         child: const Center(
//           child: Text(
//             "Add Comment",
//             style: TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//
//   Future<void> _handleAddComments(BuildContext context, String? commentsForAttendance) async {
//     try {
//       final lastAttend = await Get.find<ClockAttendanceWebController>().getLastAttendanceFordate(
//           DateFormat("dd-MMMM-yyyy").format(DateTime.now()).toString());
//
//       if (lastAttend?.date == DateFormat('dd-MMMM-yyyy').format(DateTime.now())) {
//         List<AttendanceModel> attendanceResult = await Get.find<ClockAttendanceWebController>()
//             .getAttendanceForDate(DateFormat('dd-MMMM-yyyy').format(DateTime.now()));
//         final bioInfoForUser = await Get.find<ClockAttendanceWebController>().getUserDetail();
//
//         await _addComments(attendanceResult[0].id!, bioInfoForUser, attendanceResult, commentsForAttendance!);
//       }
//     } catch (e) {
//       log("Attendance Comment Error ====== ${e.toString()}");
//     }
//   }
//
//   Future<void> _addComments(
//       int attendanceId,
//       UserModel? bioInfoForUser,
//       List<AttendanceModel> attendanceResult,
//       String commentsForAttendance
//       ) async {
//
//     await Get.find<ClockAttendanceWebController>().updateAttendanceWithComment(
//         attendanceId,
//         AttendanceModel(),
//         commentsForAttendance
//     );
//     Fluttertoast.showToast(
//       msg: "Adding Comments..",
//       toastLength: Toast.LENGTH_LONG,
//       backgroundColor: Colors.black54,
//       gravity: ToastGravity.BOTTOM,
//       timeInSecForIosWeb: 1,
//       textColor: Colors.white,
//       fontSize: 16.0,
//     );
//   }
// }
//
//
// class ClockAttendanceWebController extends GetxController {
//   final CollectionReference staffCollection = FirebaseFirestore.instance.collection('staff');
//  // final String? _currentUserId = 'testUserID';
//   // Replace with actual user ID retrieval logic for web
//   final String? _currentUserId = 'F2tJh8tU2cTDCzwp0hL3HaamBS52';
//
//   ClockAttendanceWebController() {
//     _init();
//   }
//
//   final _clockInOutLock = Lock();
//   var isCircularProgressBarOn = true.obs;
//
//   final _clockInStreamController = StreamController<String>.broadcast();
//   Stream<String> get clockInStream => _clockInStreamController.stream;
//
//   final _clockOutStreamController = StreamController<String>.broadcast();
//   Stream<String> get clockOutStream => _clockOutStreamController.stream;
//
//   final _clockInLocationStreamController = StreamController<String>.broadcast();
//   Stream<String> get clockInLocationStream => _clockInLocationStreamController.stream;
//
//   final _clockOutLocationStreamController = StreamController<String>.broadcast();
//   Stream<String> get clockOutLocationStream => _clockOutLocationStreamController.stream;
//
//   final _fullNameStreamController = StreamController<String>.broadcast();
//   Stream<String> get fullNameStream => _fullNameStreamController.stream;
//
//   RxString clockIn = "--/--".obs;
//   RxString clockOut = "--/--".obs;
//   RxString durationWorked = "".obs;
//   RxString location = "".obs;
//   RxString comments = "No Comment".obs;
//   RxString clockInLocation = "".obs;
//   RxString clockOutLocation = "".obs;
//   RxString role = "".obs;
//   RxString firstName = "".obs;
//   RxString lastName = "".obs;
//   RxString emailAddress = "".obs;
//   RxString firebaseAuthId = "".obs;
//   RxDouble lati = 0.0.obs;
//   RxDouble longi = 0.0.obs;
//   RxDouble accuracy = 0.0.obs;
//   RxDouble altitude = 0.0.obs;
//   RxDouble speed = 0.0.obs;
//   RxDouble speedAccuracy = 0.0.obs;
//   RxDouble heading = 0.0.obs;
//   RxDouble time = 0.0.obs;
//   RxBool isMock = false.obs;
//   RxDouble verticalAccuracy = 0.0.obs;
//   RxDouble headingAccuracy = 0.0.obs;
//   RxDouble elapsedRealtimeNanos = 0.0.obs;
//   RxDouble elapsedRealtimeUncertaintyNanos = 0.0.obs;
//   RxBool isLoading = false.obs;
//   RxBool isSliderEnabled = true.obs;
//   RxString administrativeArea = "".obs;
//   RxBool isLocationTurnedOn = false.obs;
//   Rx<geolocator.LocationPermission> isLocationPermissionGranted = geolocator.LocationPermission.denied.obs;
//   RxBool isAlertSet = false.obs;
//   RxBool isAlertSet2 = false.obs;
//   RxBool isInsideAnyGeofence = false.obs;
//   RxBool isInternetConnected = false.obs;
//   RxBool isGpsEnabled = false.obs;
//
//   String currentDate = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
//   DateTime ntpTime = DateTime.now();
//   DateTime _selectedDate = DateTime.now();
//   String _endTime = "11:59 PM";
//   String _startTime = DateFormat("hh:mm a").format(DateTime.now()).toString();
//   String _reasons = "";
//   int _selectedColor = 0;
//   var isDeviceConnected = false;
//   List<String> reasonsForDayOff = [
//     "Holiday",
//     "Annual Leave",
//     "Sick Leave",
//     "Other Leaves",
//     "Absent",
//     "Travel",
//     "Remote Working",
//     "Security Crisis"
//   ];
//
//   locationPkg.Location locationService = locationPkg.Location();
//   Timer? _locationTimer;
//
//
//   @override
//   void onInit() {
//     super.onInit();
//     _init();
//   }
//
//   @override
//   void onClose() {
//     _locationTimer?.cancel();
//     _clockInStreamController.close();
//     _clockOutStreamController.close();
//     _clockInLocationStreamController.close();
//     _clockOutLocationStreamController.close();
//     _fullNameStreamController.close();
//     super.onClose();
//   }
//
//   void _init() async {
//     await _loadNTPTime();
//     await _getAttendanceSummary();
//     await _getUserDetail();
//     _getUserLocation();
//   }
//
//   Future<void> _loadNTPTime() async {
//     try {
//       ntpTime = await NTP.now(lookUpAddress: "pool.ntp.org");
//     } catch (e) {
//       log("Error getting NTP time: ${e.toString()}");
//       ntpTime = DateTime.now();
//     }
//   }
//
//   Future<UserModel?> getUserDetail() async {
//     if (_currentUserId != null) {
//       try {
//         CollectionReference<Map<String, dynamic>> correctlyTypedStaffCollection = FirebaseFirestore.instance.collection('staff');
//         DocumentSnapshot<Map<String, dynamic>> snapshot = await correctlyTypedStaffCollection.doc(_currentUserId!).get();
//         if (snapshot.exists && snapshot.data() != null) {
//           Map<String, dynamic>? userData = snapshot.data();
//           return UserModel.fromMap(userData!);
//         } else {
//           print('User data not found for ID: $_currentUserId');
//           return null;
//         }
//       } catch (error) {
//         print('Error fetching user details from Firestore: $error');
//         return null;
//       }
//     } else {
//       print('No user ID available.');
//       return null;
//     }
//   }
//
//   Future<void> _getUserDetail() async {
//     UserModel? userDetail = await getUserDetail();
//     if (userDetail != null && !isClosed) {
//       firebaseAuthId.value = userDetail.firebaseAuthId ?? "";
//       firstName.value = userDetail.firstName ?? "";
//       lastName.value = userDetail.lastName ?? "";
//       emailAddress.value = userDetail.emailAddress ?? "";
//       role.value = userDetail.role ?? "";
//       _fullNameStreamController.add("${userDetail.firstName ?? ""} ${userDetail.lastName ?? ""}");
//     }
//   }
//
//   Stream<AttendanceModel?> watchLastAttendance(String month) {
//     if (_currentUserId == null) {
//       return Stream.value(null);
//     }
//     return staffCollection
//         .doc(_currentUserId)
//         .collection('Record')
//         .where('month', isEqualTo: month)
//         .orderBy('clockIn', descending: true)
//         .limit(1)
//         .snapshots()
//         .map((snapshot) {
//       if (snapshot.docs.isNotEmpty) {
//         return AttendanceModel.fromMap(snapshot.docs.first.data()!)..id = snapshot.docs.first.id.hashCode;
//       } else {
//         return null;
//       }
//     });
//   }
//
//
//   Future<AttendanceModel?> getLastAttendanceFordate(String date) async {
//     if (_currentUserId != null) {
//       try {
//         // IMPORTANT: Ensure you have created the composite index in Firebase Console as per the error message.
//         // The index should be on 'date' (ascending), 'clockIn' (ascending), and '__name__' (ascending) in the 'attendance' collection group.
//         QuerySnapshot<Map<String, dynamic>> querySnapshot = await staffCollection
//             .doc(_currentUserId)
//             .collection('Record')
//             .where('date', isEqualTo: date)
//             .orderBy('clockIn', descending: true)
//             .limit(1)
//             .get();
//
//         if (querySnapshot.docs.isNotEmpty) {
//           DocumentSnapshot<Map<String, dynamic>> lastAttendanceDoc = querySnapshot.docs.first;
//           return AttendanceModel.fromMap(lastAttendanceDoc.data()!)..id = lastAttendanceDoc.id.hashCode;
//         } else {
//           return null;
//         }
//       } catch (error) {
//         print('Error fetching last attendance from Firestore: $error');
//         return null;
//       }
//     }
//     return null;
//   }
//
//
//   Future<List<AttendanceModel>> getAttendanceForDate(String date) async {
//     List<AttendanceModel> attendanceList = [];
//     if (_currentUserId != null) {
//       try {
//         QuerySnapshot<Map<String, dynamic>> querySnapshot = await staffCollection
//             .doc(_currentUserId)
//             .collection('Record')
//             .where('date', isEqualTo: date)
//             .get();
//
//         querySnapshot.docs.forEach((doc) {
//           attendanceList.add(AttendanceModel.fromMap(doc.data())..id = doc.id.hashCode);
//         });
//       } catch (error) {
//         print('Error fetching attendance for date from Firestore: $error');
//       }
//     }
//     return attendanceList;
//   }
//
//
//   Future<void> _getAttendanceSummary() async {
//     try {
//       final attendanceLast = await getLastAttendanceFordate(DateFormat('dd-MMMM-yyyy').format(DateTime.now()));
//
//       if (attendanceLast?.date == currentDate) {
//         clockIn.value = attendanceLast?.clockIn ?? "--/--";
//         clockOut.value = attendanceLast?.clockOut ?? "--/--";
//         clockInLocation.value = attendanceLast?.clockInLocation ?? "";
//         clockOutLocation.value = attendanceLast?.clockOutLocation ?? "";
//         durationWorked.value = attendanceLast?.durationWorked ?? "";
//         comments.value = attendanceLast?.comments ?? "No Comment";
//         _clockInStreamController.add(clockIn.value);
//         _clockOutStreamController.add(clockOut.value);
//         _clockInLocationStreamController.add(clockInLocation.value);
//         _clockOutLocationStreamController.add(clockOutLocation.value);
//       } else {
//         final attendanceResult = await getAttendanceForDate(DateFormat('dd-MMMM-yyyy').format(DateTime.now()));
//         if (attendanceResult.isNotEmpty) {
//           clockIn.value = attendanceResult[0].clockIn ?? "--/--";
//           clockOut.value = attendanceResult[0].clockOut ?? "--/--";
//           clockInLocation.value = attendanceResult[0].clockInLocation ?? "";
//           clockOutLocation.value = attendanceResult[0].clockOutLocation ?? "";
//           durationWorked.value = attendanceResult[0].durationWorked ?? "";
//           comments.value = attendanceResult[0].comments ?? "No Comment";
//           _clockInStreamController.add(clockIn.value);
//           _clockOutStreamController.add(clockOut.value);
//           _clockInLocationStreamController.add(clockInLocation.value);
//           _clockOutLocationStreamController.add(clockOutLocation.value);
//         } else {
//           clockIn.value = "--/--";
//           clockOut.value = "--/--";
//           clockInLocation.value = "";
//           clockOutLocation.value = "";
//           durationWorked.value = "";
//           comments.value = "No Comment";
//           _clockInStreamController.add(clockIn.value);
//           _clockOutStreamController.add(clockOut.value);
//           _clockInLocationStreamController.add(clockInLocation.value);
//           _clockOutLocationStreamController.add(clockOutLocation.value);
//         }
//       }
//     } catch (e) {
//       log(e.toString());
//     }
//   }
//
//
//   Future<void> updateAttendanceWithComment(
//       int attendanceId,
//       AttendanceModel attendanceModel,
//       String commentsForAttendance
//       ) async {
//     final updatedAttendance = {'comments': commentsForAttendance};
//     if (_currentUserId != null) {
//       DocumentReference attendanceRef = staffCollection.doc(_currentUserId).collection('Record').doc(attendanceId.toString());
//       await attendanceRef.update(updatedAttendance);
//     } else {
//       Fluttertoast.showToast(
//         msg: "User ID not available.",
//         toastLength: Toast.LENGTH_LONG,
//         backgroundColor: Colors.black54,
//         gravity: ToastGravity.BOTTOM,
//         timeInSecForIosWeb: 1,
//         textColor: Colors.white,
//         fontSize: 16.0,
//       );
//     }
//   }
//
//
//   Future<void> clockInUpdated(double newlatitude, double newlongitude, String newlocation) async {
//     print("clockInUpdated Web Firestore");
//     if (!isLoading.value) {
//       await _clockInOutLock.synchronized(() async {
//         try {
//           currentDate = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
//           final lastAttend = await getLastAttendanceFordate(currentDate);
//
//           if (lastAttend == null || lastAttend.date != currentDate) {
//             if (newlatitude != 0.0) {
//               final attendance = AttendanceModel(
//                 clockIn: DateFormat('hh:mm a').format(DateTime.now()),
//                 date: currentDate,
//                 clockInLatitude: newlatitude,
//                 clockInLocation: newlocation,
//                 clockInLongitude: newlongitude,
//                 clockOut: "--/--",
//                 clockOutLatitude: 0.0,
//                 clockOutLocation: '',
//                 clockOutLongitude: 0.0,
//                 isSynced: false,
//                 voided: false,
//                 isUpdated: false,
//                 durationWorked: "0 hours 0 minutes",
//                 noOfHours: 0.0,
//                 offDay: false,
//                 month: DateFormat('MMMM yyyy').format(DateTime.now()),
//                 comments: "No Comment",
//               ).toMap();
//
//               if (_currentUserId != null) {
//                 DocumentReference newAttendanceRef = staffCollection.doc(_currentUserId).collection('Record').doc();
//                 await newAttendanceRef.set(attendance);
//                 _clockInStreamController.add(DateFormat('hh:mm a').format(DateTime.now()));
//                 _clockInLocationStreamController.add(location.value);
//                 Fluttertoast.showToast(msg: "Clocking-In..", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.black54, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, textColor: Colors.white, fontSize: 16.0);
//                 Get.off(() => ClockAttendanceWeb());
//               } else {
//                 Fluttertoast.showToast(msg: "User ID not available.", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.black54, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, textColor: Colors.white, fontSize: 16.0);
//               }
//             } else {
//               Fluttertoast.showToast(msg: "Latitude and Longitude cannot be 0.0..", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.black54, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, textColor: Colors.white, fontSize: 16.0);
//             }
//           } else if (lastAttend != null && lastAttend.date == currentDate) {
//             Fluttertoast.showToast(
//                 msg: "You have already clocked In Today",
//                 toastLength: Toast.LENGTH_LONG,
//                 backgroundColor: Colors.black54,
//                 gravity: ToastGravity.BOTTOM,
//                 timeInSecForIosWeb: 1,
//                 textColor: Colors.white,
//                 fontSize: 16.0
//             );
//           }
//         } catch (e) {
//           Fluttertoast.showToast(msg: "Error from clock in: $e", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.black54, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, textColor: Colors.white, fontSize: 16.0);
//         }
//       });
//     }
//   }
//
//
//   Future<void> clockOutUpdated(double newlatitude, double newlongitude, String newlocation) async {
//     print("clockOutUpdated Web Firestore");
//
//     if (!isLoading.value) {
//       await _clockInOutLock.synchronized(() async {
//         try {
//           currentDate = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
//           final lastAttend = await getLastAttendanceFordate(currentDate);
//
//           if (lastAttend?.date == currentDate && lastAttend?.clockOut == "--/--") {
//             final clockInDateTime = DateFormat('dd-MMMM-yyyy hh:mm a').parse('${lastAttend!.date} ${lastAttend.clockIn}');
//             final now = DateTime.now();
//             final difference = now.difference(clockInDateTime);
//
//             if (difference < const Duration(hours: 1)) {
//               Fluttertoast.showToast(msg: "You can clock out after 1 hour", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.black54, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, textColor: Colors.white, fontSize: 16.0);
//               isLoading.value = false;
//             } else {
//               if (lastAttend.clockIn == DateFormat('hh:mm a').format(DateTime.now())) {
//                 Fluttertoast.showToast(msg: "You cannot clock in and clock out the same time", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.black54, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, textColor: Colors.white, fontSize: 16.0);
//                 isLoading.value = false;
//               } else {
//                 final attendanceResult = await getAttendanceForDate(currentDate);
//                 if (newlatitude != 0.0) {
//                   final updatedAttendance = {
//                     'clockOut': DateFormat('hh:mm a').format(DateTime.now()),
//                     'clockOutLatitude': newlatitude,
//                     'clockOutLongitude': newlongitude,
//                     'clockOutLocation': newlocation,
//                     'isUpdated': true,
//                     'durationWorked': _diffClockInOut(attendanceResult[0].clockIn.toString(), DateFormat('h:mm a').format(DateTime.now())),
//                     'noOfHours': _diffHoursWorked(attendanceResult[0].clockIn.toString(), DateFormat('h:mm a').format(DateTime.now())),
//                   };
//                   if (_currentUserId != null) {
//                     DocumentReference attendanceRef = staffCollection.doc(_currentUserId).collection('Record').doc(attendanceResult[0].id.toString());
//                     await attendanceRef.update(updatedAttendance);
//                     _clockOutStreamController.add(DateFormat('hh:mm a').format(DateTime.now()));
//                     _clockOutLocationStreamController.add(location.value);
//                     Fluttertoast.showToast(msg: "Clocking-Out..", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.black54, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, textColor: Colors.white, fontSize: 16.0);
//                     UserModel? bioInfoForUser = await getUserDetail();
//                     // Get.off(() => bioInfoForUser!.role == "User" ? UserDashBoard(service: null) : AdminDashBoard(service: null));
//                   } else {
//                     Fluttertoast.showToast(msg: "User ID not available.", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.black54, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, textColor: Colors.white, fontSize: 16.0);
//                   }
//                 } else {
//                   Fluttertoast.showToast(msg: "Latitude and Longitude cannot be 0.0..", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.black54, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, textColor: Colors.white, fontSize: 16.0);
//                 }
//               }
//             }
//           } else  if (lastAttend?.clockOut != "--/--"){
//             Fluttertoast.showToast(
//                 msg: "You have already clocked Out Today",
//                 toastLength: Toast.LENGTH_LONG,
//                 backgroundColor: Colors.black54,
//                 gravity: ToastGravity.BOTTOM,
//                 timeInSecForIosWeb: 1,
//                 textColor: Colors.white,
//                 fontSize: 16.0
//             );
//           }
//
//
//           await _getAttendanceSummary();
//
//         } catch (e) {
//           Fluttertoast.showToast(msg: "Error: $e", toastLength: Toast.LENGTH_LONG, backgroundColor: Colors.black54, gravity: ToastGravity.BOTTOM, timeInSecForIosWeb: 1, textColor: Colors.white, fontSize: 16.0);
//         }
//       });
//     }
//   }
//
//
//   String _diffClockInOut(String clockInTime, String clockOutTime) {
//     try{
//       var format = DateFormat("h:mm a");
//       var clockTimeIn = format.parse(clockInTime);
//       var clockTimeOut = format.parse(clockOutTime);
//
//       if (clockTimeIn.isAfter(clockTimeOut)) {
//         clockTimeOut = clockTimeOut.add(const Duration(days: 1));
//       } else if (clockInTime == "--/--" || clockOutTime == "--/--") {
//         return "Time not set";
//       }
//
//       Duration diff = clockTimeOut.difference(clockTimeIn);
//       final hours = diff.inHours;
//       final minutes = diff.inMinutes % 60;
//
//       log('$hours hours $minutes minute');
//       return ('$hours hour(s) $minutes minute(s)');
//     }catch(e){
//       return "0 hour(s) 0 minute(s)";
//     }
//
//   }
//
//
//   double _diffHoursWorked(String clockInTime, String clockOutTime) {
//     try{
//       var format = DateFormat("h:mm a");
//       var clockTimeIn = format.parse(clockInTime);
//       var clockTimeOut = format.parse(clockOutTime);
//       if (clockTimeIn.isAfter(clockTimeOut)) {
//         clockTimeOut = clockTimeOut.add(const Duration(days: 1));
//       }
//
//       Duration diff = clockTimeOut.difference(clockTimeIn);
//       final hours = diff.inHours;
//       final minutes = diff.inMinutes % 60;
//       final minCal = minutes / 60;
//       String inStringMin = minCal.toStringAsFixed(3);
//       double roundedMinDouble = double.parse(inStringMin);
//       final totalTime = hours + roundedMinDouble;
//
//       log('$hours hours $minutes minutes');
//       return totalTime;
//     }catch(e){
//       return 0.0;
//     }
//   }
//
//
//   void showBottomSheet3(BuildContext context) {
//     double screenHeight = MediaQuery.of(context).size.height;
//     double screenWidth = MediaQuery.of(context).size.width;
//     final ClockAttendanceWebController controller = Get.find<ClockAttendanceWebController>();
//     Get.bottomSheet(
//       StatefulBuilder(
//         builder: (context, setState) {
//           return Container(
//             padding: const EdgeInsets.only(left: 20, right: 20),
//             width: screenWidth,
//             height: screenHeight * 0.65,
//             color: Colors.white,
//             alignment: Alignment.center,
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.only(top: 20.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     "Out Of Office?",
//                     style: TextStyle(
//                       color: Colors.black87,
//                       fontWeight: FontWeight.bold,
//                       fontSize: screenWidth / 15,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Obx(() => Text(
//                     "Current Latitude: ${controller.lati.value.toStringAsFixed(6)}, Current Longitude: ${controller.longi.value.toStringAsFixed(6)}",
//                     style: TextStyle(
//                       fontFamily: "NexaBold",
//                       fontSize: screenWidth / 23,
//                     ),
//                   )),
//                   const SizedBox(height: 10),
//                   Obx(() => Text(
//                     "Current State: ${controller.administrativeArea.value}",
//                     style: TextStyle(
//                       fontFamily: "NexaBold",
//                       fontSize: screenWidth / 23,
//                     ),
//                   )),
//                   const SizedBox(height: 10),
//                   Obx(() => Text(
//                     "Current Location: ${controller.location.value}",
//                     style: TextStyle(
//                       fontFamily: "NexaBold",
//                       fontSize: screenWidth / 23,
//                     ),
//                   )),
//                   const SizedBox(height: 10),
//                   // MyInputField (You may need to adapt MyInputField for web or use standard TextField)
//                   _buildInputField("Date", DateFormat("dd/MM/yyyy").format(_selectedDate), IconButton(
//                     onPressed: () {
//                       _getDateFromUser(setState);
//                     },
//                     icon: const Icon(Icons.calendar_today_outlined, color: Colors.grey),
//                   )),
//                   _buildDropdownInputField("Reasons For Day off", _reasons, reasonsForDayOff, (String? newValue) {
//                     setState(() {
//                       _reasons = newValue!;
//                     });
//                   }),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: _buildInputField("Start Time", _startTime, IconButton(
//                           onPressed: () {
//                             _getTimeFromUser(isStartTime: true, setState: setState);
//                           },
//                           icon: const Icon(Icons.access_time_rounded, color: Colors.grey),
//                         )),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: _buildInputField("End Time", _endTime, IconButton(
//                           onPressed: () {
//                             _getTimeFromUser(isStartTime: false, setState: setState);
//                           },
//                           icon: const Icon(Icons.access_time_rounded, color: Colors.grey),
//                         )),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 18),
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             "Color",
//                             style: TextStyle(
//                               color: Get.isDarkMode ? Colors.white : Colors.black,
//                               fontSize: screenWidth / 21,
//                               fontFamily: "NexaBold",
//                             ),
//                           ),
//                           const SizedBox(height: 8.0),
//                           Wrap(
//                             crossAxisAlignment: WrapCrossAlignment.start,
//                             children: List<Widget>.generate(3, (int index) {
//                               return GestureDetector(
//                                 onTap: () {
//                                   setState(() {
//                                     _selectedColor = index;
//                                   });
//                                 },
//                                 child: Padding(
//                                   padding: const EdgeInsets.all(8.0),
//                                   child: CircleAvatar(
//                                     radius: 14,
//                                     backgroundColor: index == 0 ? Colors.red : index == 1 ? Colors.blueAccent : Colors.yellow,
//                                     child: _selectedColor == index ? const Icon(Icons.done, color: Colors.white, size: 16) : Container(),
//                                   ),
//                                 ),
//                               );
//                             }),
//                           ),
//                         ],
//                       ),
//                       GestureDetector(
//                         onTap: () => _validateData(context),
//                         child: Container(
//                           width: 120,
//                           height: 60,
//                           decoration: const BoxDecoration(
//                             gradient: LinearGradient(colors: [Colors.red, Colors.black]),
//                             borderRadius: BorderRadius.all(Radius.circular(20)),
//                           ),
//                           child: const Center(
//                             child: Text(
//                               "Submit",
//                               style: TextStyle(color: Colors.white),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 40),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//       isScrollControlled: true,
//     );
//   }
//
//   Widget _buildInputField(String title, String hint, Widget widget) {
//     return Container(
//       margin: const EdgeInsets.only(top: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: Get.textTheme.titleSmall),
//           Container(
//             height: 52,
//             margin: const EdgeInsets.only(top: 8.0),
//             padding: const EdgeInsets.only(left: 14, right: 14),
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.grey, width: 1.0),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Text(hint, style: TextStyle(color: Colors.grey)),
//                 ),
//                 widget,
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDropdownInputField(String title, String hint, List<String> items, Function(String?) onChanged) {
//     return Container(
//       margin: const EdgeInsets.only(top: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: Get.textTheme.titleSmall),
//           Container(
//             height: 52,
//             margin: const EdgeInsets.only(top: 8.0),
//             padding: const EdgeInsets.only(left: 14, right: 14),
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.grey, width: 1.0),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: DropdownButton<String>(
//                     value: hint.isNotEmpty ? hint : null, // Set value to hint if not empty, otherwise null
//                     hint: Text(hint.isEmpty ? "Select Reason" : hint, style: TextStyle(color: Colors.grey)), // Show "Select Reason" hint if hint is empty
//                     icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
//                     iconSize: 32,
//                     elevation: 4,
//                     style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black),
//                     underline: Container(height: 0),
//                     onChanged: onChanged,
//                     items: items.map<DropdownMenuItem<String>>((String value) {
//                       return DropdownMenuItem<String>(
//                         value: value,
//                         child: Text(value, style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black)),
//                       );
//                     }).toList(),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//   void _validateData(BuildContext context) {
//     if (_reasons.isNotEmpty) {
//       _addDaysOffToDb();
//       Get.off(() => ClockAttendanceWeb());
//     } else if (_reasons.isEmpty) {
//       Get.snackbar(
//         "Required",
//         "Reasons For Day Off is required!",
//         colorText: Colors.white,
//         snackPosition: SnackPosition.BOTTOM,
//         backgroundColor: Colors.black87,
//         icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
//       );
//     }
//   }
//
//   _addDaysOffToDb() async {
//     final attendanceLast = await getLastAttendanceFordate(
//         DateFormat('dd-MMMM-yyyy').format(DateTime.now()));
//
//     if (lati.value == 0.0 && longi.value == 0.0) {
//       Fluttertoast.showToast(
//           msg: "Error: Latitude and Longitude Not gotten...Kindly wait",
//           toastLength: Toast.LENGTH_LONG,
//           backgroundColor: Colors.black54,
//           gravity: ToastGravity.BOTTOM,
//           timeInSecForIosWeb: 1,
//           textColor: Colors.white,
//           fontSize: 16.0);
//     } else if (attendanceLast == null || attendanceLast.date != DateFormat('dd-MMMM-yyyy').format(_selectedDate)) {
//       final attendnce = AttendanceModel(
//         clockIn: _startTime,
//         date: DateFormat('dd-MMMM-yyyy').format(_selectedDate),
//         clockInLatitude: lati.value,
//         clockInLocation: location.value,
//         clockInLongitude: longi.value,
//         clockOut: _endTime,
//         clockOutLatitude: lati.value,
//         clockOutLocation: location.value,
//         clockOutLongitude: longi.value,
//         isSynced: false,
//         voided: false,
//         isUpdated: true,
//         offDay: true,
//         durationWorked: _reasons,
//         noOfHours: _diffHoursWorked(_startTime, _endTime),
//         month: DateFormat('MMMM yyyy').format(_selectedDate),
//         comments: "Day Off",
//       ).toMap();
//
//       if (_currentUserId != null) {
//         DocumentReference newAttendanceRef = staffCollection.doc(_currentUserId).collection('Record').doc();
//         await newAttendanceRef.set(attendnce);
//         Fluttertoast.showToast(
//             msg: "Day Off Request Submitted",
//             toastLength: Toast.LENGTH_LONG,
//             backgroundColor: Colors.black54,
//             gravity: ToastGravity.BOTTOM,
//             timeInSecForIosWeb: 1,
//             textColor: Colors.white,
//             fontSize: 16.0);
//       } else {
//         Fluttertoast.showToast(
//           msg: "User ID not available.",
//           toastLength: Toast.LENGTH_LONG,
//           backgroundColor: Colors.black54,
//           gravity: ToastGravity.BOTTOM,
//           timeInSecForIosWeb: 1,
//           textColor: Colors.white,
//           fontSize: 16.0,
//         );
//       }
//
//     } else {
//       Fluttertoast.showToast(
//           msg: "Error: Attendance with same date already exist",
//           toastLength: Toast.LENGTH_LONG,
//           backgroundColor: Colors.black54,
//           gravity: ToastGravity.BOTTOM,
//           timeInSecForIosWeb: 1,
//           textColor: Colors.white,
//           fontSize: 16.0);
//     }
//   }
//
//   void _getDateFromUser(StateSetter setState) async {
//     DateTime? pickerDate = await showDatePicker(
//       context: Get.context!,
//       initialDate: DateTime.now(),
//       firstDate: DateTime(2015),
//       lastDate: DateTime(2090),
//     );
//     if (pickerDate != null) {
//       setState(() {
//         _selectedDate = pickerDate;
//       });
//     } else {
//       print("It's null or something is wrong");
//     }
//   }
//
//   void _getTimeFromUser(
//       {required bool isStartTime, required StateSetter setState}) async {
//     var pickedTime = await _showTimePicker();
//     String formattedTime = pickedTime.format(Get.context!);
//     print(pickedTime);
//     if (isStartTime) {
//       setState(() {
//         _startTime = formattedTime;
//       });
//     } else {
//       setState(() {
//         _endTime = formattedTime;
//       });
//     }
//   }
//
//
//   Future<TimeOfDay> _showTimePicker() async {
//     TimeOfDay? pickedTime = await showTimePicker(
//       initialEntryMode: TimePickerEntryMode.input,
//       context: Get.context!,
//       initialTime: TimeOfDay(
//         hour: int.parse(_startTime.split(":")[0]),
//         minute: int.parse(_startTime.split(":")[1].split(" ")[0]),
//       ),
//       builder: (context, child) {
//         return MediaQuery(
//           data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
//           child: child!,
//         );
//       },
//     );
//     return pickedTime ?? TimeOfDay.now();
//   }
//
//
//   Future<void> _getUserLocation() async {
//     try {
//       geolocator.Position position = await geolocator.Geolocator.getCurrentPosition(
//           desiredAccuracy: geolocator.LocationAccuracy.high);
//
//       lati.value = position.latitude;
//       longi.value = position.longitude;
//       accuracy.value = position.accuracy;
//       altitude.value = position.altitude;
//       speed.value = position.speed;
//       speedAccuracy.value = position.speedAccuracy;
//       heading.value = position.heading;
//       time.value = position.timestamp.millisecondsSinceEpoch.toDouble();
//       isMock.value = position.isMocked;
//      // verticalAccuracy.value = position.verticalAccuracy ?? 0.0;
//       headingAccuracy.value = position.headingAccuracy ?? 0.0;
//      // elapsedRealtimeNanos.value = position.elapsedRealtimeNanos.toDouble();
//      // elapsedRealtimeUncertaintyNanos.value = position.elapsedRealtimeUncertaintyNanos.toDouble();
//
//       List<Placemark> placemark = await placemarkFromCoordinates(position.latitude, position.longitude);
//       if (placemark.isNotEmpty) {
//         location.value =
//         "${placemark[0].street}, ${placemark[0].subLocality}, ${placemark[0].subAdministrativeArea}, ${placemark[0].locality}, ${placemark[0].administrativeArea}, ${placemark[0].postalCode}, ${placemark[0].country}";
//         administrativeArea.value = placemark[0].administrativeArea ?? "";
//       }
//     } catch (e) {
//       log("Location Error: ${e.toString()}");
//     }
//   }
// }
//
// class UserModel {
//   static double lat = 0.0;
//   static double long = 0.0;
//   String? firebaseAuthId;
//   String? firstName;
//   String? lastName;
//   String? role;
//   String? emailAddress;
//   String? profileUrl;
//   String? uid;
//
//
//   UserModel({
//     this.firebaseAuthId,
//     this.firstName,
//     this.lastName,
//     this.role,
//     this.emailAddress,
//     this.profileUrl,
//     this.uid,
//
//   });
//
//
//   UserModel.fromMap(Map<String, dynamic> map)
//       : firebaseAuthId = map['firebaseAuthId'],
//         firstName = map['firstName'],
//         lastName = map['lastName'],
//         role = map['role'],
//         emailAddress = map['emailAddress'],
//         profileUrl = map['profileUrl'],
//         uid = map['uid'];
//
//
//   Map<String, dynamic> toMap() {
//     return {
//       'firebaseAuthId': firebaseAuthId,
//       'firstName': firstName,
//       'lastName': lastName,
//       'role': role,
//       'emailAddress': emailAddress,
//       'profileUrl': profileUrl,
//       'uid': uid,
//     };
//   }
// }
//
// class AttendanceModel {
//   int? id;
//   String? clockIn;
//   String? clockOut;
//   String? date;
//   double? clockInLatitude;
//   double? clockInLongitude;
//   double? clockOutLatitude;
//   double? clockOutLongitude;
//   String? clockInLocation;
//   String? clockOutLocation;
//   bool? isSynced;
//   bool? voided;
//   bool? isUpdated;
//   String? durationWorked;
//   double? noOfHours;
//   bool? offDay;
//   String? month;
//   String? comments;
//
//   AttendanceModel({
//     this.id,
//     this.clockIn,
//     this.clockOut,
//     this.date,
//     this.clockInLatitude,
//     this.clockInLongitude,
//     this.clockOutLatitude,
//     this.clockOutLongitude,
//     this.clockInLocation,
//     this.clockOutLocation,
//     this.isSynced,
//     this.voided,
//     this.isUpdated,
//     this.durationWorked,
//     this.noOfHours,
//     this.offDay,
//     this.month,
//     this.comments,
//   });
//
//   AttendanceModel.fromMap(Map<String, dynamic> map)
//       : clockIn = map['clockIn'],
//         clockOut = map['clockOut'],
//         date = map['date'],
//         clockInLatitude = map['clockInLatitude'],
//         clockInLongitude = map['clockInLongitude'],
//         clockOutLatitude = map['clockOutLatitude'],
//         clockOutLongitude = map['clockOutLongitude'],
//         clockInLocation = map['clockInLocation'],
//         clockOutLocation = map['clockOutLocation'],
//         isSynced = map['isSynced'],
//         voided = map['voided'],
//         isUpdated = map['isUpdated'],
//         durationWorked = map['durationWorked'],
//         noOfHours = map['noOfHours'],
//         offDay = map['offDay'],
//         month = map['month'],
//         comments = map['comments'];
//
//
//   Map<String, dynamic> toMap() {
//     return {
//       'clockIn': clockIn,
//       'clockOut': clockOut,
//       'date': date,
//       'clockInLatitude': clockInLatitude,
//       'clockInLongitude': clockInLongitude,
//       'clockOutLatitude': clockOutLatitude,
//       'clockOutLongitude': clockOutLongitude,
//       'clockInLocation': clockInLocation,
//       'clockOutLocation': clockOutLocation,
//       'isSynced': isSynced,
//       'voided': voided,
//       'isUpdated': isUpdated,
//       'durationWorked': durationWorked,
//       'noOfHours': noOfHours,
//       'offDay': offDay,
//       'month': month,
//       'comments': comments,
//     };
//   }
// }