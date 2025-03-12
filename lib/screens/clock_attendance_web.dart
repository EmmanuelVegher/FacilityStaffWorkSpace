// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'package:rxdart/rxdart.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:syncfusion_flutter_gauges/gauges.dart';
//
// import '../../models/facility_staff_model.dart';
// import '../../utils/date_helper.dart';
// import '../login_screen.dart';
//
// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});
//
//   @override
//   DashboardScreenState createState() => DashboardScreenState();
// }
//
// class DashboardScreenState extends State<DashboardScreen> {
//   DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
//   DateTime _endDate = DateTime.now();
//   bool _isLoading = false;
//
//   late List<AttendanceData> attendanceData = [];
//   late List<WeeklyTrendData> weeklyTrendData = [];
//   late List<TaskCompletionData> taskCompletionData = [];
//   late List<GeolocationComplianceData> geolocationComplianceData = [];
//   late List<LeaveRequestData> pendingLeaveRequests = [];
//   late List<LeaveRequestData> upcomingLeaves = [];
//   late List<TaskData> taskStatusData = [];
//
//   String? _currentUserState;
//   String? _currentUserLocation;
//   String? _currentUserStaffCategory;
//   Timer? _logoutTimer;
//   static const int _logoutAfterMinutes = 5;
//
//   Map<String, int> _firestoreBestPlayerCounts = {};
//   FacilityStaffModel? _bestPlayerOfWeek;
//   int _totalSurveysCountedForBestPlayer = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeData();
//     _startLogoutTimer();
//   }
//
//   void _resetLogoutTimer() {
//     _logoutTimer?.cancel();
//     _startLogoutTimer();
//   }
//
//   void _startLogoutTimer() {
//     _logoutTimer = Timer(const Duration(minutes: _logoutAfterMinutes), _logoutUser);
//   }
//
//   void _logoutUser() {
//     print('User logged out due to inactivity.');
//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(builder: (context) => const LoginPage()),
//     );
//   }
//
//   Future<void> _initializeData() async {
//     setState(() {
//       _isLoading = true;
//     });
//     await _loadCurrentUserBioData();
//     await _fetchDashboardData();
//     setState(() {
//       _isLoading = false;
//     });
//   }
//
//   Future<void> _loadCurrentUserBioData() async {
//     try {
//       final userUUID = FirebaseAuth.instance.currentUser?.uid;
//       if (userUUID == null) {
//         print("No user logged in.");
//         return;
//       }
//
//       DocumentSnapshot<Map<String, dynamic>> bioDataSnapshot =
//       await FirebaseFirestore.instance.collection("Staff").doc(userUUID).get();
//
//       if (bioDataSnapshot.exists) {
//         final bioData = bioDataSnapshot.data();
//         if (bioData != null) {
//           setState(() {
//             _currentUserState = bioData['state'] as String?;
//             _currentUserLocation = bioData['location'] as String?;
//             _currentUserStaffCategory = bioData['staffCategory'] as String?;
//           });
//           print(
//               "Current User State: $_currentUserState, Location: $_currentUserLocation");
//         } else {
//           print("Bio data is null for UUID: $userUUID");
//         }
//       } else {
//         print("No bio data found for UUID: $userUUID");
//       }
//     } catch (e) {
//       print("Error loading bio data: $e");
//     }
//   }
//
//   Future<void> _fetchDashboardData() async {
//     if (_currentUserState == null) return;
//
//     DateTime currentDate = DateTime.now();
//     String currentDateFormatted = DateFormat('dd-MMMM-yyyy').format(currentDate);
//     String currentMonthYearFormatted = DateFormat('MMMM-yyyy').format(currentDate);
//
//     attendanceData = await _getAttendanceChartData(currentDateFormatted);
//     weeklyTrendData = await _getWeeklyTrendChartData(_startDate, _endDate);
//     taskCompletionData = getTaskCompletionData(); // Sample Data - Replace with Firestore data if needed
//     geolocationComplianceData = getGeolocationComplianceData(); // Sample Data - Replace with Firestore data if needed
//     pendingLeaveRequests = await _getPendingLeaveRequests();
//     upcomingLeaves = await _getUpcomingLeaves();
//     taskStatusData = getTaskStatusData(); // Sample Data - Replace with Firestore data if needed
//   }
//
//   Future<List<AttendanceData>> _getAttendanceChartData(String currentDateFormatted) async {
//     int totalStaffs = 0;
//     int clockedInStaffs = 0;
//     int presentMale = 0;
//     int presentFemale = 0;
//     int absentMale = 0;
//     int absentFemale = 0;
//     int lateMale = 0;
//     int lateFemale = 0;
//     int onLeaveCount = 0;
//
//     QuerySnapshot staffSnapshot = await FirebaseFirestore.instance
//         .collection('Staff')
//         .where('state', isEqualTo: _currentUserState)
//         .get();
//     totalStaffs = staffSnapshot.docs.length;
//
//     for (DocumentSnapshot staffDoc in staffSnapshot.docs) {
//       String staffId = staffDoc.id;
//       DocumentSnapshot recordSnapshot = await FirebaseFirestore.instance
//           .collection('Staff')
//           .doc(staffId)
//           .collection('Record')
//           .doc(currentDateFormatted)
//           .get();
//
//       if (recordSnapshot.exists) {
//         clockedInStaffs++;
//         Map<String, dynamic> recordData = recordSnapshot.data() as Map<String, dynamic>;
//         String? clockInTime = recordData['clockIn'] as String?;
//         // Check if 'gender' field exists before accessing it
//         String gender = staffDoc.data() != null && (staffDoc.data() as Map<String, dynamic>?)?.containsKey('gender') == true
//             ? staffDoc['gender'] as String? ?? 'Other'
//             : 'Other';
//
//         if (clockInTime != null && clockInTime != 'N/A') {
//           if (DateHelper.calculateEarlyLateTime(clockInTime) > 0) {
//             if (gender == 'Male') lateMale++; else lateFemale++;
//           } else {
//             if (gender == 'Male') presentMale++; else presentFemale++;
//           }
//         }
//       } else {
//         // Check if 'gender' field exists before accessing it
//         String gender = staffDoc.data() != null && (staffDoc.data() as Map<String, dynamic>?)?.containsKey('gender') == true
//             ? staffDoc['gender'] as String? ?? 'Other'
//             : 'Other';
//         if (gender == 'Male') absentMale++; else absentFemale++;
//       }
//     }
//
//     onLeaveCount = await _getOnLeaveCount(currentDateFormatted);
//
//     return [
//       AttendanceData('Present', presentMale + presentFemale),
//       AttendanceData('Absent', absentMale + absentFemale),
//       AttendanceData('Late', lateMale + lateFemale),
//       AttendanceData('On Leave', onLeaveCount),
//     ];
//   }
//
//   Future<int> _getOnLeaveCount(String currentDateFormatted) async {
//     int onLeaveCount = 0;
//     QuerySnapshot leaveSnapshot = await FirebaseFirestore.instance
//         .collectionGroup('LeaveRequests')
//         .where('state', isEqualTo: _currentUserState)
//         .where('status', isEqualTo: 'Approved')
//         .where('startDate', isLessThanOrEqualTo: DateTime.parse(DateFormat('yyyy-MM-dd').format(DateTime.now())))
//         .where('endDate', isGreaterThanOrEqualTo: DateTime.parse(DateFormat('yyyy-MM-dd').format(DateTime.now())))
//         .get();
//
//     onLeaveCount = leaveSnapshot.docs.length;
//     return onLeaveCount;
//   }
//
//
//   Future<List<WeeklyTrendData>> _getWeeklyTrendChartData(DateTime startDate, DateTime endDate) async {
//     Map<String, int> dailyClockInCounts = {};
//     DateTime currentDate = startDate;
//     while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
//       String formattedDate = DateFormat('dd-MMMM-yyyy').format(currentDate);
//       dailyClockInCounts[DateFormat('E').format(currentDate)] = 0; // Initialize count for each day
//       currentDate = currentDate.add(const Duration(days: 1));
//     }
//
//     QuerySnapshot staffSnapshot = await FirebaseFirestore.instance
//         .collection('Staff')
//         .where('state', isEqualTo: _currentUserState)
//         .get();
//
//     for (DocumentSnapshot staffDoc in staffSnapshot.docs) {
//       String staffId = staffDoc.id;
//       DateTime date = startDate;
//       while (date.isBefore(endDate.add(const Duration(days: 1)))) {
//         String formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
//         DocumentSnapshot recordSnapshot = await FirebaseFirestore.instance
//             .collection('Staff')
//             .doc(staffId)
//             .collection('Record')
//             .doc(formattedDate)
//             .get();
//
//         if (recordSnapshot.exists) {
//           String dayName = DateFormat('E').format(date);
//           dailyClockInCounts[dayName] = (dailyClockInCounts[dayName] ?? 0) + 1;
//         }
//         date = date.add(const Duration(days: 1));
//       }
//     }
//
//     List<WeeklyTrendData> weeklyTrendData = [];
//     dailyClockInCounts.forEach((day, count) {
//       weeklyTrendData.add(WeeklyTrendData(day, count.toDouble()));
//     });
//     return weeklyTrendData;
//   }
//
//   Future<List<LeaveRequestData>> _getPendingLeaveRequests() async {
//     List<LeaveRequestData> pendingRequests = [];
//     QuerySnapshot leaveSnapshot = await FirebaseFirestore.instance
//         .collectionGroup('LeaveRequests')
//         .where('state', isEqualTo: _currentUserState)
//         .where('status', isEqualTo: 'Pending')
//         .limit(5)
//         .get();
//
//     for (DocumentSnapshot doc in leaveSnapshot.docs) {
//       Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//       DocumentSnapshot staffDoc = await FirebaseFirestore.instance.collection('Staff').doc(data['staffId']).get();
//       String employeeName = '${staffDoc['firstName']} ${staffDoc['lastName']}';
//       pendingRequests.add(LeaveRequestData(
//         employeeName,
//         data['leaveType'] ?? 'N/A',
//         DateFormat('yyyy-MM-dd').format((data['startDate'] as Timestamp).toDate()),
//       ));
//     }
//     return pendingRequests;
//   }
//
//   Future<List<LeaveRequestData>> _getUpcomingLeaves() async {
//     List<LeaveRequestData> upcomingLeavesList = [];
//     QuerySnapshot leaveSnapshot = await FirebaseFirestore.instance
//         .collectionGroup('LeaveRequests')
//         .where('state', isEqualTo: _currentUserState)
//         .where('status', isEqualTo: 'Approved')
//         .where('startDate', isGreaterThan: DateTime.now())
//         .orderBy('startDate')
//         .limit(5)
//         .get();
//
//     for (DocumentSnapshot doc in leaveSnapshot.docs) {
//       Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//       DocumentSnapshot staffDoc = await FirebaseFirestore.instance.collection('Staff').doc(data['staffId']).get();
//       String employeeName = '${staffDoc['firstName']} ${staffDoc['lastName']}';
//       upcomingLeavesList.add(LeaveRequestData(
//         employeeName,
//         data['leaveType'] ?? 'N/A',
//         DateFormat('yyyy-MM-dd').format((data['startDate'] as Timestamp).toDate()),
//       ));
//     }
//     return upcomingLeavesList;
//   }
//
//
//   @override
//   void dispose() {
//     _logoutTimer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//
//     double appBarHeightFactor = max(0.8, min(1.2, screenHeight / 800));
//     double titleFontSizeFactor = max(0.8, min(1.2, screenWidth / 800));
//     double cardPaddingFactor = max(0.8, min(1.2, screenWidth / 800));
//     double cardMarginFactor = max(0.8, min(1.2, screenWidth / 800));
//     double fontSizeFactor = max(0.8, min(1.2, screenWidth / 800));
//     double iconSizeFactor = max(0.8, min(1.2, screenWidth / 800));
//     double chartHeightFactor = max(0.8, min(1.2, screenHeight / 800));
//     double gridSpacingFactor = max(0.8, min(1.2, screenWidth / 800));
//     double appBarIconSizeFactor = max(0.8, min(1.2, screenWidth / 800));
//     double chartLegendFontSizeFactor = max(0.8, min(1.2, screenWidth / 800));
//     double summaryCardHeightFactor = screenWidth > 800 ? 1.0 : screenWidth > 800 ? 1.0 : 0.8;
//     double otherCardHeightFactor = max(1.0, min(1.5, screenHeight / 800));
//     double generateAnalyticsButtonPaddingFactor = max(0.8, min(1.2, screenWidth / 800));
//     double chartCardVerticalPaddingFactor = max(0.8, min(1.2, screenHeight / 800));
//     double cardHeightFactor = max(0.8, min(1.2, screenHeight / 800));
//
//     int crossAxisCount = screenWidth > 1200 ? 4 : screenWidth > 800 ? 3 : 2;
//     double childAspectRatio = screenWidth > 1200 ? 2.0 / 1.2 : screenWidth > 800 ? 1.8 / 1.2 : 1.5 / 1.0;
//
//
//     return Listener(
//       onPointerDown: (_) => _resetLogoutTimer(),
//       onPointerMove: (_) => _resetLogoutTimer(),
//       onPointerUp: (_) => _resetLogoutTimer(),
//       onPointerCancel: (_) => _resetLogoutTimer(),
//       onPointerSignal: (_) => _resetLogoutTimer(),
//       behavior: HitTestBehavior.translucent,
//       child: Scaffold(
//         appBar: AppBar(
//           iconTheme: const IconThemeData(color: Colors.white),
//           title: Row(
//             mainAxisAlignment: MainAxisAlignment.start,
//             children: [
//               Image.asset(
//                 'assets/image/ccfn_logo.png',
//                 fit: BoxFit.contain,
//                 height: 40 * appBarHeightFactor,
//               ),
//               Padding(
//                 padding: EdgeInsets.only(left: 10 * cardMarginFactor),
//                 child: Text(
//                   'State Office Dashboard',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20 * titleFontSizeFactor,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           backgroundColor: const Color(0xFF800018),
//           toolbarHeight: 80 * appBarHeightFactor,
//           bottom: PreferredSize(
//             preferredSize: Size.fromHeight(60 * appBarHeightFactor),
//             child: Padding(
//               padding: EdgeInsets.symmetric(horizontal: 8.0 * cardPaddingFactor),
//               child: buildFilterBarInAppBar(
//                   context,
//                   cardPaddingFactor,
//                   cardMarginFactor,
//                   fontSizeFactor,
//                   appBarHeightFactor,
//                   generateAnalyticsButtonPaddingFactor),
//             ),
//           ),
//         ),
//         body: _isLoading
//             ? const Center(child: CircularProgressIndicator())
//             : Padding(
//           padding: EdgeInsets.all(16.0 * cardPaddingFactor),
//           child: GridView.count(
//             crossAxisCount: crossAxisCount,
//             crossAxisSpacing: 20 * gridSpacingFactor,
//             mainAxisSpacing: 20 * gridSpacingFactor,
//             childAspectRatio: childAspectRatio,
//             children: [
//               _buildCard('Attendance Overview', _buildAttendanceChart(), cardPaddingFactor, cardMarginFactor, fontSizeFactor),
//               _buildCard('Weekly Trends - Staff Clock-Ins', _buildWeeklyTrendChart(cardPaddingFactor, cardMarginFactor, fontSizeFactor, chartHeightFactor, chartLegendFontSizeFactor, otherCardHeightFactor, chartCardVerticalPaddingFactor, screenWidth), cardPaddingFactor, cardMarginFactor, fontSizeFactor),
//               _buildCard('Performance Gauge', _buildPerformanceGauge(cardPaddingFactor, cardMarginFactor, fontSizeFactor, chartHeightFactor, chartLegendFontSizeFactor, otherCardHeightFactor, chartCardVerticalPaddingFactor, screenWidth), cardPaddingFactor, cardMarginFactor, fontSizeFactor),
//               _buildCard('Late Arrivals & Geolocation Compliance Trends', _buildTaskCompletionChart(cardPaddingFactor, cardMarginFactor, fontSizeFactor, chartHeightFactor, chartLegendFontSizeFactor, otherCardHeightFactor, chartCardVerticalPaddingFactor, screenWidth), cardPaddingFactor, cardMarginFactor, fontSizeFactor),
//               _buildCard('Facility Clock-In (Live Feed) - Today', _buildFacilityClockInCard(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, otherCardHeightFactor), cardPaddingFactor, cardMarginFactor, fontSizeFactor), // Replaced Monthly Summary
//               _buildTimesheetStatusCard(cardPaddingFactor, cardMarginFactor, fontSizeFactor),
//               _buildLeaveRequestsCard(cardPaddingFactor, cardMarginFactor, fontSizeFactor),
//               _buildTaskManagementCard(cardPaddingFactor, cardMarginFactor, fontSizeFactor, chartHeightFactor, chartLegendFontSizeFactor, otherCardHeightFactor, chartCardVerticalPaddingFactor, screenWidth),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget buildFilterBarInAppBar(
//       BuildContext context,
//       double cardPaddingFactor,
//       double cardMarginFactor,
//       double fontSizeFactor,
//       double appBarHeightFactor,
//       double generateAnalyticsButtonPaddingFactor) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         SizedBox(width: 8 * cardMarginFactor),
//         _buildDatePickerInAppBar('Start Date', _startDate, (date) {
//           setState(() {
//             _startDate = date;
//             _resetLogoutTimer();
//           });
//         }, cardPaddingFactor, cardMarginFactor, fontSizeFactor),
//         SizedBox(width: 8 * cardMarginFactor),
//         _buildDatePickerInAppBar('End Date', _endDate, (date) {
//           setState(() {
//             _endDate = date;
//             _resetLogoutTimer();
//           });
//         }, cardPaddingFactor, cardMarginFactor, fontSizeFactor),
//         SizedBox(width: 12 * cardMarginFactor),
//         ElevatedButton(
//           onPressed: () {
//             _initializeData();
//             _resetLogoutTimer();
//           },
//           style: ElevatedButton.styleFrom(
//             padding: EdgeInsets.symmetric(
//                 horizontal:
//                 15 * cardPaddingFactor * generateAnalyticsButtonPaddingFactor,
//                 vertical:
//                 10 * cardPaddingFactor * generateAnalyticsButtonPaddingFactor),
//           ),
//           child: Text(
//             'Generate Analytics',
//             style: TextStyle(
//                 fontSize: 14 * fontSizeFactor * generateAnalyticsButtonPaddingFactor),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildDatePickerInAppBar(
//       String label,
//       DateTime initialDate,
//       Function(DateTime) onDateSelected,
//       double cardPaddingFactor,
//       double cardMarginFactor,
//       double fontSizeFactor) {
//     return Row(
//       children: [
//         Text('$label: ',
//             style: TextStyle(fontSize: 14 * fontSizeFactor, color: Colors.white)),
//         TextButton(
//           onPressed: () async {
//             final selectedDate = await showDatePicker(
//               context: context,
//               initialDate: initialDate,
//               firstDate: DateTime(2020),
//               lastDate: DateTime.now(),
//             );
//             if (selectedDate != null) {
//               onDateSelected(selectedDate);
//               _resetLogoutTimer();
//             }
//           },
//           child: Text(DateFormat('dd-MM-yyyy').format(initialDate),
//               style: TextStyle(fontSize: 14 * fontSizeFactor, color: Colors.white)),
//         ),
//       ],
//     );
//   }
//
//
//   Widget _buildCard(String title, Widget child, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * cardMarginFactor)),
//       child: Padding(
//         padding: EdgeInsets.all(16.0 * cardPaddingFactor),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: TextStyle(fontSize: 18 * fontSizeFactor, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 10 * cardMarginFactor),
//             Expanded(child: child),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAttendanceChart() {
//     final screenWidth = MediaQuery.of(context).size.width;
//     double cardMarginFactor = max(0.8, min(1.2, screenWidth / 800));
//     double fontSizeFactor = max(0.8, min(1.2, screenWidth / 800));
//     return Row(
//       children: [
//         Expanded(
//           flex: 4,
//           child: Padding(
//             padding: EdgeInsets.all(8.0 * cardMarginFactor),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 ClipOval(
//                   child: Image.asset(
//                     'assets/image/headshot.png',
//                     fit: BoxFit.cover,
//                     height: 100 * cardMarginFactor,
//                     width: 100 * cardMarginFactor,
//                   ),
//                 ),
//                 SizedBox(height: 8 * cardMarginFactor),
//                 Text(
//                   "Punctuality Champion",
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor),
//                   textAlign: TextAlign.center,
//                 ),
//                 Text(
//                   "Emmanuel Vegher",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(fontSize: 12 * fontSizeFactor),
//                 ),
//               ],
//             ),
//           ),
//         ),
//         Expanded(
//           flex: 3,
//           child: Padding(
//             padding: EdgeInsets.symmetric(horizontal: 16.0 * cardMarginFactor),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   'Dis-Aggregated Data',
//                   style: TextStyle(fontSize: 16 * fontSizeFactor, fontWeight: FontWeight.bold, color: Colors.black54),
//                 ),
//                 SizedBox(height: 20 * cardMarginFactor),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: _buildAttendanceGenderSummary('Male', attendanceData, fontSizeFactor),
//                     ),
//                     Expanded(
//                       child: _buildAttendanceGenderSummary('Female', attendanceData, fontSizeFactor),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 20 * cardMarginFactor),
//                 Row(
//                   children: [
//                     _buildLegendItem(Colors.orange.shade400, 'Total Staffs', fontSizeFactor),
//                     SizedBox(width: 16 * cardMarginFactor),
//                     _buildLegendItem(Colors.green.shade400, '% Clocked-In', fontSizeFactor),
//                   ],
//                 )
//               ],
//             ),
//           ),
//         ),
//         Expanded(
//           flex: 3,
//           child: SfCircularChart(
//             series: <CircularSeries<AttendanceData, String>>[
//               DoughnutSeries<AttendanceData, String>(
//                 dataSource: attendanceData,
//                 xValueMapper: (AttendanceData data, _) => data.status,
//                 yValueMapper: (AttendanceData data, _) => data.count,
//                 dataLabelSettings: const DataLabelSettings(isVisible: false),
//                 enableTooltip: true,
//                 strokeWidth: 2,
//                 strokeColor: Colors.white,
//                 innerRadius: '70%',
//                 pointColorMapper: (AttendanceData data, _) {
//                   if (data.status == 'Present') return Colors.green.shade400;
//                   if (data.status == 'Absent') return Colors.orange.shade400;
//                   if (data.status == 'Late') return Colors.red.shade400;
//                   if (data.status == 'On Leave') return Colors.grey.shade400;
//                   return Colors.grey.shade400;
//                 },
//               )
//             ],
//             annotations: <CircularChartAnnotation>[
//               CircularChartAnnotation(
//                 widget: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text(
//                       _calculateTotalStaffs().toString(),
//                       style: TextStyle(fontSize: 24 * fontSizeFactor, fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       '${_calculateClockedInPercentage()}% Clocked-In',
//                       style: TextStyle(fontSize: 12 * fontSizeFactor, color: Colors.grey.shade600),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   int _calculateTotalStaffs() {
//     int totalStaffs = 0;
//     if (attendanceData.isNotEmpty) {
//       totalStaffs = attendanceData.fold(0, (sum, data) => sum + data.count);
//     }
//     return totalStaffs;
//   }
//
//   double _calculateClockedInPercentage() {
//     int totalPresent = 0;
//     int totalStaffs = _calculateTotalStaffs();
//     if (attendanceData.isNotEmpty) {
//       totalPresent = attendanceData.firstWhere((data) => data.status == 'Present', orElse: () => AttendanceData('Present', 0)).count;
//     }
//     return totalStaffs > 0 ? double.parse(((totalPresent / totalStaffs) * 100).toStringAsFixed(1)) : 0.0;
//   }
//
//
//   Widget _buildAttendanceGenderSummary(String gender, List<AttendanceData> data, double fontSizeFactor) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(gender, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
//         SizedBox(height: 8 * fontSizeFactor),
//         ..._buildAttendanceSummary(gender, data, fontSizeFactor),
//       ],
//     );
//   }
//
//
//   List<Widget> _buildAttendanceSummary(String gender, List<AttendanceData> data, double fontSizeFactor) {
//     return data.where((item) => item.status != 'On Leave').map((item) {
//       Color color;
//       if (item.status == 'Present') color = Colors.green.shade400;
//       else if (item.status == 'Absent') color = Colors.orange.shade400;
//       else if (item.status == 'Late') color = Colors.red.shade400;
//       else color = Colors.grey.shade400;
//
//       String statusText = '';
//       if (item.status == 'Present') statusText = 'Present';
//       else if (item.status == 'Absent') statusText = 'Absent';
//       else if (item.status == 'Late') statusText = 'Late';
//       else statusText = item.status;
//
//
//       return Padding(
//         padding: EdgeInsets.symmetric(vertical: 4 * fontSizeFactor),
//         child: Row(
//           children: [
//             Container(
//               width: 30 * fontSizeFactor,
//               height: 30 * fontSizeFactor,
//               decoration: const BoxDecoration(
//                 shape: BoxShape.circle,
//               ),
//               child: Center(
//                 child: Icon(Icons.person, size: 20 * fontSizeFactor, color: color),
//               ),
//             ),
//             SizedBox(width: 8 * fontSizeFactor),
//             Text(statusText, style: TextStyle(fontSize: 12 * fontSizeFactor)),
//           ],
//         ),
//       );
//     }).toList();
//   }
//
//
//   Widget _buildLegendItem(Color color, String text, double fontSizeFactor) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 12 * fontSizeFactor,
//           height: 12 * fontSizeFactor,
//           color: color,
//         ),
//         SizedBox(width: 5 * fontSizeFactor),
//         Text(text, style: TextStyle(fontSize: 12 * fontSizeFactor)),
//       ],
//     );
//   }
//
//
//   Widget _buildWeeklyTrendChart(double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartHeightFactor, double chartLegendFontSizeFactor, double otherCardHeightFactor, double chartCardVerticalPaddingFactor, double screenWidth) {
//     return SfCartesianChart(
//       primaryXAxis: CategoryAxis(),
//       primaryYAxis: NumericAxis(title: AxisTitle(text: 'Number of Staff')),
//       title: ChartTitle(text: 'Weekly Staff Clock-In Trend'),
//       series: <LineSeries<WeeklyTrendData, String>>[
//         LineSeries<WeeklyTrendData, String>(
//           dataSource: weeklyTrendData,
//           xValueMapper: (WeeklyTrendData data, _) => data.day,
//           yValueMapper: (WeeklyTrendData data, _) => data.percentage,
//           dataLabelSettings: const DataLabelSettings(isVisible: true),
//         )
//       ],
//     );
//   }
//
//   Widget _buildPerformanceGauge(double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartHeightFactor, double chartLegendFontSizeFactor, double otherCardHeightFactor, double chartCardVerticalPaddingFactor, double screenWidth) {
//     return SfRadialGauge(
//       title: GaugeTitle(text: 'Overall Performance', textStyle: TextStyle(fontSize: 16 * fontSizeFactor)),
//       axes: [
//         RadialAxis(minimum: 0, maximum: 100,
//             pointers: [
//               NeedlePointer(value: 75)
//             ],
//             annotations: <GaugeAnnotation>[
//               GaugeAnnotation(widget: Text('75%', style: TextStyle(fontSize: 24 * fontSizeFactor, fontWeight: FontWeight.bold)),
//                   angle: 90, positionFactor: 0.5)
//             ])
//       ],
//     );
//   }
//
//   Widget _buildTaskCompletionChart(double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartHeightFactor, double chartLegendFontSizeFactor, double otherCardHeightFactor, double chartCardVerticalPaddingFactor, double screenWidth) {
//     return SfCartesianChart(
//       title: ChartTitle(text: 'Late Arrivals & Geolocation Compliance Trends'),
//       primaryXAxis: CategoryAxis(
//         title: AxisTitle(text: 'Hour'),
//         labelIntersectAction: AxisLabelIntersectAction.multipleRows,
//       ),
//       primaryYAxis: NumericAxis(
//         title: AxisTitle(text: 'Percentage'),
//         minimum: 0,
//         maximum: 100,
//         interval: 20,
//       ),
//       legend: Legend(isVisible: true, position: LegendPosition.bottom),
//       series: <AreaSeries<GeolocationComplianceData, String>>[
//         AreaSeries<GeolocationComplianceData, String>(
//           dataSource: geolocationComplianceData,
//           xValueMapper: (GeolocationComplianceData data, _) => data.hour,
//           yValueMapper: (GeolocationComplianceData data, _) => data.locationCompliance,
//           name: 'Location compliance',
//           color: const Color(0xFF24B3A8),
//         ),
//         AreaSeries<GeolocationComplianceData, String>(
//           dataSource: geolocationComplianceData,
//           xValueMapper: (GeolocationComplianceData data, _) => data.hour,
//           yValueMapper: (GeolocationComplianceData data, _) => data.other,
//           name: 'Late Arrivals (Other)',
//           color: const Color(0xFFD9E3EA),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildFacilityClockInCard(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double iconSizeFactor, double otherCardHeightFactor) {
//     return Container(
//       padding: EdgeInsets.all(15 * cardPaddingFactor * otherCardHeightFactor),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20 * cardMarginFactor),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'All Facility Clock-In (Live Feed) - Today',
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                   fontSize: 16 * fontSizeFactor,
//                 ),
//               ),
//               IconButton(onPressed: () {}, icon: Icon(Icons.more_vert, size: 24 * iconSizeFactor)),
//             ],
//           ),
//           Divider(height: 10 * cardMarginFactor,),
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: 8.0 * cardPaddingFactor, vertical: 4.0 * cardPaddingFactor),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text("Name & Date", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12 * fontSizeFactor)),
//                 Text("Clock-In Time", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12 * fontSizeFactor)),
//               ],
//             ),
//           ),
//           Expanded(
//             child: StreamBuilder<List<Map<String, dynamic>>>(
//               stream: _facilityClockInDataStream(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//                 if (snapshot.hasError) {
//                   return Center(child: Text('Error: ${snapshot.error}'));
//                 }
//                 List<Map<String, dynamic>> facilityClockInData = snapshot.data ?? [];
//
//                 facilityClockInData.sort((a, b) {
//                   final timeFormat = DateFormat('hh:mm a');
//                   DateTime? timeA, timeB;
//                   try {
//                     timeA = timeFormat.parse(a['clockIn'] ?? '12:00 AM');
//                   } catch (e) {
//                     timeA = DateTime(0);
//                   }
//                   try {
//                     timeB = timeFormat.parse(b['clockIn'] ?? '12:00 AM');
//                   } catch (e) {
//                     timeB = DateTime(0);
//                   }
//
//                   if (a['clockIn'] == 'N/A' && b['clockIn'] == 'N/A') return 0;
//                   if (a['clockIn'] == 'N/A') return 1;
//                   if (b['clockIn'] == 'N/A') return -1;
//
//                   return timeA!.compareTo(timeB!);
//                 });
//
//
//                 if (facilityClockInData.isEmpty) {
//                   return Center(child: Text("No Clock-Ins Today", style: TextStyle(fontSize: 14 * fontSizeFactor, color: Colors.grey)));
//                 }
//                 return SingleChildScrollView(
//                   scrollDirection: Axis.vertical,
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: facilityClockInData.map((data) => _buildClockInListItem(
//                       data['fullName'] ?? 'Unknown Staff',
//                       data['date'] ?? 'N/A',
//                       data['clockIn'] ?? 'N/A',
//                       data['clockOut'] ?? '--/--',
//                       fontSizeFactor,
//                       cardMarginFactor,
//                       cardPaddingFactor,
//                     )).toList(),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildClockInListItem(String title, String date, String clockInTime, String clockOutTime, double fontSizeFactor, double cardMarginFactor, double cardPaddingFactor) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 8.0 * cardMarginFactor, horizontal: 8.0 * cardPaddingFactor),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 14 * fontSizeFactor),
//                 ),
//                 Text(
//                   date,
//                   style: TextStyle(color: Colors.black54, fontSize: 12 * fontSizeFactor),
//                 ),
//               ],
//             ),
//           ),
//           Row(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Text(
//                 clockInTime,
//                 style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor),
//               ),
//               SizedBox(width: 5 * cardMarginFactor),
//               if (clockInTime != 'N/A' && clockOutTime == '--/--')
//                 Column(
//                   children: [
//                     Icon(Icons.check, color: Colors.orange, size: 16 * fontSizeFactor),
//                     SizedBox(width: 3 * cardMarginFactor),
//                     Text("Clocked-In,Yet to Clock Out", style: TextStyle(fontSize: 12 * fontSizeFactor, color: Colors.orange),)
//                   ],
//                 )
//               else if (clockInTime != 'N/A' && clockOutTime != '--/--')
//                 Column(
//                   children: [
//                     Icon(Icons.check_circle, color: Colors.green, size: 16 * fontSizeFactor),
//                     SizedBox(width: 3 * cardMarginFactor),
//                     Text("Clocked-In and Clocked Out", style: TextStyle(fontSize: 12 * fontSizeFactor, color: Colors.green),)
//                   ],
//                 )
//               else
//                 const SizedBox.shrink(),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Stream<List<Map<String, dynamic>>> _facilityClockInDataStream() {
//     final currentUserUUID = FirebaseAuth.instance.currentUser?.uid;
//     if (currentUserUUID == null || _currentUserState == null || _currentUserLocation == null || _currentUserStaffCategory == null) {
//       print("Could not retrieve user info to load facility clock-in data stream.");
//       return Stream.value([]);
//     }
//
//     final currentDateFormatted = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
//
//     Stream<DocumentSnapshot> currentUserRecordStream = FirebaseFirestore.instance
//         .collection('Staff')
//         .doc(currentUserUUID)
//         .collection('Record')
//         .doc(currentDateFormatted)
//         .snapshots();
//
//     Stream<QuerySnapshot> facilityStaffRecordsStream = FirebaseFirestore.instance
//         .collection('Staff')
//         .where('state', isEqualTo: _currentUserState)
//         .where('location', isEqualTo: _currentUserLocation)
//         .snapshots();
//
//
//     return Rx.combineLatest2(
//       currentUserRecordStream,
//       facilityStaffRecordsStream,
//           (currentUserRecordSnapshot, facilityStaffSnapshot) async* {
//         List<Map<String, dynamic>> clockInData = [];
//
//         if (currentUserRecordSnapshot.exists) {
//           Map<String, dynamic> recordData = currentUserRecordSnapshot.data() as Map<String, dynamic>? ?? {};
//           DocumentSnapshot staffDataSnapshot = await FirebaseFirestore.instance.collection('Staff').doc(currentUserUUID).get();
//           Map<String, dynamic> staffData = staffDataSnapshot.data() as Map<String, dynamic>? ?? {};
//
//           clockInData.add({
//             'fullName': '${staffData['firstName'] ?? 'N/A'} ${staffData['lastName'] ?? 'N/A'}',
//             'date': recordData['date'] ?? 'N/A',
//             'clockIn': recordData['clockIn'] ?? 'N/A',
//             'clockOut': recordData['clockOut'] ?? '--/--',
//           });
//         }
//
//         for (var staffDoc in facilityStaffSnapshot.docs) {
//           if (staffDoc.id == currentUserUUID) continue;
//
//           DocumentSnapshot recordSnapshot = await staffDoc.reference
//               .collection('Record')
//               .doc(currentDateFormatted)
//               .get();
//
//           if (recordSnapshot.exists) {
//             Map<String, dynamic> recordData = recordSnapshot.data() as Map<String, dynamic>? ?? {};
//             Map<String, dynamic> staffData = staffDoc.data() as Map<String, dynamic>? ?? {};
//
//             clockInData.add({
//               'fullName': '${staffData['firstName'] ?? 'N/A'} ${staffData['lastName'] ?? 'N/A'}',
//               'date': recordData['date'] ?? 'N/A',
//               'clockIn': recordData['clockIn'] ?? 'N/A',
//               'clockOut': recordData['clockOut'] ?? '--/--',
//             });
//           }
//         }
//         yield clockInData;
//       },
//     ).asyncMap((stream) async => await stream.first);
//   }
//
//
//   Widget _buildTimesheetStatusCard(double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * cardMarginFactor)),
//       child: Padding(
//         padding: EdgeInsets.all(20.0 * cardPaddingFactor),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: <Widget>[
//             Text(
//               'Timesheet Status',
//               style: TextStyle(fontSize: 20 * fontSizeFactor, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 20 * cardMarginFactor),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('Pending Submission:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
//                 Text('${5} Timesheets', style: TextStyle(color: Colors.red, fontSize: 14 * fontSizeFactor)),
//               ],
//             ),
//             SizedBox(height: 10 * cardMarginFactor),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('Pending Approval:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
//                 Text('${3} Timesheets', style: TextStyle(color: Colors.orange, fontSize: 14 * fontSizeFactor)),
//               ],
//             ),
//             SizedBox(height: 20 * cardMarginFactor),
//             Text('Timesheet Completion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
//             SizedBox(height: 10 * cardMarginFactor),
//             SizedBox(
//               height: 80 * cardMarginFactor,
//               child: SfLinearGauge(
//                 minimum: 0,
//                 maximum: 100,
//                 orientation: LinearGaugeOrientation.horizontal,
//                 majorTickStyle: const LinearTickStyle(length: 12),
//                 minorTickStyle: const LinearTickStyle(length: 8),
//                 axisLabelStyle: TextStyle(fontSize: 12 * fontSizeFactor),
//                 barPointers: <LinearBarPointer>[
//                   LinearBarPointer(
//                     value: 75,
//                     thickness: 20 * cardMarginFactor,
//                     color: Colors.blue.shade400,
//                     edgeStyle: LinearEdgeStyle.bothCurve,
//                   ),
//                 ],
//                 markerPointers: <LinearShapePointer>[
//                   LinearShapePointer(
//                     value: 75,
//                     offset: 25,
//                     shapeType: LinearShapePointerType.circle,
//                     color: Colors.blue.shade700,
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: 10 * cardMarginFactor),
//             Align(
//               alignment: Alignment.bottomRight,
//               child: TextButton(
//                 onPressed: () {
//                   print('Navigate to Timesheet Module');
//                 },
//                 child: Text('View Timesheets', style: TextStyle(fontSize: 14 * fontSizeFactor)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLeaveRequestsCard(double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * cardMarginFactor)),
//       child: Padding(
//         padding: EdgeInsets.all(20.0 * cardPaddingFactor),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: <Widget>[
//             Text(
//               'Leave Requests',
//               style: TextStyle(fontSize: 20 * fontSizeFactor, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 20 * cardMarginFactor),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('Pending Requests:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
//                 Text('${pendingLeaveRequests.length} Requests', style: TextStyle(color: Colors.orange, fontSize: 14 * fontSizeFactor)),
//               ],
//             ),
//             SizedBox(height: 10 * cardMarginFactor),
//             SizedBox(
//               height: 150 * cardMarginFactor,
//               child: ListView.builder(
//                 itemCount: pendingLeaveRequests.length,
//                 itemBuilder: (context, index) {
//                   final request = pendingLeaveRequests[index];
//                   return ListTile(
//                     leading: Icon(Icons.pending_actions, color: Colors.orange, size: 24 * fontSizeFactor),
//                     title: Text(request.employeeName, style: TextStyle(fontSize: 14 * fontSizeFactor)),
//                     subtitle: Text('${request.leaveType} - ${request.startDate}', style: TextStyle(fontSize: 12 * fontSizeFactor)),
//                     trailing: IconButton(
//                       icon: Icon(Icons.arrow_forward_ios, size: 20 * fontSizeFactor),
//                       onPressed: () {
//                         print('Navigate to Leave Request Details for ${request.employeeName}');
//                       },
//                     ),
//                   );
//                 },
//               ),
//             ),
//             SizedBox(height: 20 * cardMarginFactor),
//             Text('Upcoming Leaves', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
//             SizedBox(height: 10 * cardMarginFactor),
//             SizedBox(
//               height: 100 * cardMarginFactor,
//               child: ListView.builder(
//                 itemCount: upcomingLeaves.length,
//                 itemBuilder: (context, index) {
//                   final leave = upcomingLeaves[index];
//                   return ListTile(
//                     leading: Icon(Icons.calendar_today, color: Colors.green, size: 24 * fontSizeFactor),
//                     title: Text(leave.employeeName, style: TextStyle(fontSize: 14 * fontSizeFactor)),
//                     subtitle: Text('${leave.leaveType} - ${leave.startDate}', style: TextStyle(fontSize: 12 * fontSizeFactor)),
//                   );
//                 },
//               ),
//             ),
//             SizedBox(height: 10 * cardMarginFactor),
//             Align(
//               alignment: Alignment.bottomRight,
//               child: TextButton(
//                 onPressed: () {
//                   print('Navigate to Leave Requests Module');
//                 },
//                 child: Text('View All Leave Requests', style: TextStyle(fontSize: 14 * fontSizeFactor)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTaskManagementCard(double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartHeightFactor, double chartLegendFontSizeFactor, double otherCardHeightFactor, double chartCardVerticalPaddingFactor, double screenWidth) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * cardMarginFactor)),
//       child: Padding(
//         padding: EdgeInsets.all(20.0 * cardPaddingFactor),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: <Widget>[
//             Text(
//               'Task Management',
//               style: TextStyle(fontSize: 20 * fontSizeFactor, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 20 * cardMarginFactor),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('Tasks In Progress:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
//                 Text('${12} Tasks', style: TextStyle(color: Colors.blue, fontSize: 14 * fontSizeFactor)),
//               ],
//             ),
//             SizedBox(height: 10 * cardMarginFactor),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('Overdue Tasks:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
//                 Text('${2} Tasks', style: TextStyle(color: Colors.red, fontSize: 14 * fontSizeFactor)),
//               ],
//             ),
//             SizedBox(height: 20 * cardMarginFactor),
//             Text('Task Completion Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
//             SizedBox(height: 10 * cardMarginFactor),
//             SizedBox(
//               height: 80 * cardMarginFactor,
//               child: SfLinearGauge(
//                 minimum: 0,
//                 maximum: 100,
//                 orientation: LinearGaugeOrientation.horizontal,
//                 majorTickStyle: const LinearTickStyle(length: 12),
//                 minorTickStyle: const LinearTickStyle(length: 8),
//                 axisLabelStyle: TextStyle(fontSize: 12 * fontSizeFactor),
//                 barPointers: <LinearBarPointer>[
//                   LinearBarPointer(
//                     value: 60,
//                     thickness: 20 * cardMarginFactor,
//                     color: Colors.green.shade400,
//                     edgeStyle: LinearEdgeStyle.bothCurve,
//                   ),
//                 ],
//                 markerPointers: <LinearShapePointer>[
//                   LinearShapePointer(
//                     value: 60,
//                     offset: 25,
//                     shapeType: LinearShapePointerType.circle,
//                     color: Colors.green.shade700,
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: 10 * cardMarginFactor),
//             Align(
//               alignment: Alignment.bottomRight,
//               child: TextButton(
//                 onPressed: () {
//                   print('Navigate to Task Management Module');
//                 },
//                 child: Text('View Tasks', style: TextStyle(fontSize: 14 * fontSizeFactor)),
//               ),
//             ),
//             SizedBox(height:10 * cardMarginFactor),
//             SizedBox(
//               height: 80 * cardMarginFactor,
//               child: SfCartesianChart(
//                 primaryXAxis: CategoryAxis(),
//                 series: [
//                   ColumnSeries<TaskCompletionData, String>(
//                     dataSource: taskCompletionData,
//                     xValueMapper: (TaskCompletionData data, _) => data.task,
//                     yValueMapper: (TaskCompletionData data, _) => data.completion,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
//
// class AttendanceData {
//   final String status;
//   final int count;
//   AttendanceData(this.status, this.count);
// }
//
// class WeeklyTrendData {
//   final String day;
//   final double percentage;
//   WeeklyTrendData(this.day, this.percentage);
// }
//
// class TaskCompletionData {
//   final String task;
//   final double completion;
//   TaskCompletionData(this.task, this.completion);
// }
//
// class GeolocationComplianceData {
//   final String hour;
//   final double locationCompliance;
//   final double other;
//   GeolocationComplianceData(this.hour, this.locationCompliance, this.other);
// }
//
// class LeaveRequestData {
//   final String employeeName;
//   final String leaveType;
//   final String startDate;
//   LeaveRequestData(this.employeeName, this.leaveType, this.startDate);
// }
//
//
// class TaskData {
//   final String status;
//   final int count;
//   TaskData(this.status, this.count);
// }
//
//
// List<TaskCompletionData> getTaskCompletionData() {
//   return [
//     TaskCompletionData('Task A', 90),
//     TaskCompletionData('Task B', 75),
//     TaskCompletionData('Task C', 60),
//     TaskCompletionData('Task D', 85),
//     TaskCompletionData('Task E', 70),
//   ];
// }
//
// List<GeolocationComplianceData> getGeolocationComplianceData() {
//   return [
//     GeolocationComplianceData('0h', 100, 50),
//     GeolocationComplianceData('1h', 200, 100),
//     GeolocationComplianceData('2h', 300, 150),
//     GeolocationComplianceData('3h', 400, 200),
//     GeolocationComplianceData('4h', 500, 250),
//     GeolocationComplianceData('5h', 600, 300),
//     GeolocationComplianceData('6h', 700, 400),
//     GeolocationComplianceData('7h', 800, 500),
//     GeolocationComplianceData('8h', 700, 400),
//     GeolocationComplianceData('9h', 600, 300),
//     GeolocationComplianceData('10h', 500, 200),
//     GeolocationComplianceData('11h', 400, 150),
//   ];
// }
//
//
// List<TaskData> getTaskStatusData() {
//   return [
//     TaskData('In Progress', 12),
//     TaskData('Overdue', 2),
//   ];
// }