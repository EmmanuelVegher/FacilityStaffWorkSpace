import 'dart:math';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

import '../../widgets/drawer2.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late List<AttendanceData> attendanceData;
  late List<WeeklyTrendData> weeklyTrendData;
  late List<TaskCompletionData> taskCompletionData;
  late List<GeolocationComplianceData> geolocationComplianceData;
  late List<AttendanceData> attendanceChartData;
  late List<WeeklyAttendanceTrend1> weeklyTrendData1;
  late List<LeaveRequestData> pendingLeaveRequests;
  late List<LeaveRequestData> upcomingLeaves;
  late List<TaskData> taskStatusData;

  String? _currentUserState;
  String? _currentUserLocation;
  String? _currentUserStaffCategory;
  bool _isLoadingClockInData = false;
  String _selectedDateRange = "Today";
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  int malePresentCount1 = 0;
  int malePresentCount2 = 0;
  int maleAbsentCount1 = 0;
  int maleLateCount1 = 0;
  bool _isDataLoaded = false; // Add a loading flag

  @override
  void initState() {
    super.initState();
    _initializeData(); // Call a separate async function for initialization

  }

  Future<void> _initializeData() async {
    await _loadCurrentUserBioDataForClockInCard(); // Await user bio data loading

    attendanceData = getAttendanceData(); // You can keep these synchronous data initializations here as they are dummy data
    weeklyTrendData = getWeeklyTrendData();
    taskCompletionData = getTaskCompletionData();
    geolocationComplianceData = getGeolocationComplianceData();
    attendanceChartData = getAttendanceData();
    weeklyTrendData1 = getWeeklyTrendData1();
    pendingLeaveRequests = getPendingLeaveRequests();
    upcomingLeaves = getUpcomingLeaves();
    taskStatusData = getTaskStatusData();
    _isDataLoaded = true; // Set the flag to true when data is loaded
    setState(() {}); // Trigger a rebuild to reflect the data loading completion
  }

  Future<void> _loadCurrentUserBioDataForClockInCard() async {
    try {
      final userUUID = FirebaseAuth.instance.currentUser?.uid;
      if (userUUID == null) {
        print("No user logged in.");
        return;
      }

      DocumentSnapshot<Map<String, dynamic>> bioDataSnapshot =
      await FirebaseFirestore.instance.collection("Staff").doc(userUUID).get();

      if (bioDataSnapshot.exists) {
        final bioData = bioDataSnapshot.data();
        if (bioData != null) {
          setState(() {
            _currentUserState = bioData['state'] as String?;
            _currentUserLocation = bioData['location'] as String?;
            _currentUserStaffCategory = bioData['staffCategory'] as String?;
          });
          print(
              "Current User State: $_currentUserState, Location: $_currentUserLocation");
        } else {
          print("Bio data is null for UUID: $userUUID");
        }
      } else {
        print("No bio data found for UUID: $userUUID");
      }
    } catch (e) {
      print("Error loading bio data: $e");
    }
  }

  void _handleDateRangeSelection(String value) {
    setState(() {
      _selectedDateRange = value;
      _startDateFilter = null;
      _endDateFilter = null;

      DateTime now = DateTime.now();
      if (value == "Past 2 days") {
        _endDateFilter = now;
        _startDateFilter = now.subtract(const Duration(days: 2));
      } else if (value == "Past 7 days") {
        _endDateFilter = now;
        _startDateFilter = now.subtract(const Duration(days: 7));
      } else if (value == "Past 2 weeks") {
        _endDateFilter = now;
        _startDateFilter = now.subtract(const Duration(days: 14));
      } else if (value == "Past 1 Month") {
        _endDateFilter = now;
        _startDateFilter = DateTime(now.year, now.month - 1, now.day);
      } else if (value == "Past 3 Month(s)") {
        _endDateFilter = now;
        _startDateFilter = DateTime(now.year, now.month - 3, now.day);
      } else if (value == "Past 6 Month(s)") {
        _endDateFilter = now;
        _startDateFilter = DateTime(now.year, now.month - 6, now.day);
      } else if (value == "Past 1 year") {
        _endDateFilter = now;
        _startDateFilter = DateTime(now.year - 1, now.month, now.day);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Define screen size breakpoints
    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1200;
    bool isDesktop = screenWidth >= 1200 && screenWidth < 1920;
    bool isLargeDesktop = screenWidth >= 1920;

    // Scaling factors for responsiveness based on screen size
    double appBarHeightFactor;
    double titleFontSizeFactor;
    double cardPaddingFactor;
    double cardMarginFactor;
    double fontSizeFactor;
    double iconSizeFactor;
    double chartHeightFactor;
    double gridSpacingFactor;
    double appBarIconSizeFactor;
    double chartLegendFontSizeFactor;
    double summaryCardHeightFactor;
    double otherCardHeightFactor;
    double generateAnalyticsButtonPaddingFactor;
    double chartCardVerticalPaddingFactor;
    double cardHeightFactor;
    double otherGridTextFontSizeFactor; // New factor for OtherGrid text

    if (isMobile) {
      appBarHeightFactor = screenHeight < 600 ? 0.6 : 0.9;
      titleFontSizeFactor = 0.55;
      cardPaddingFactor = 0.55;
      cardMarginFactor = 0.8;
      fontSizeFactor = 0.55;
      iconSizeFactor = 0.55;
      chartHeightFactor = 0.8;
      gridSpacingFactor = 0.2;
      appBarIconSizeFactor = 0.55;
      chartLegendFontSizeFactor = 0.45;
      summaryCardHeightFactor = 1.6;
      otherCardHeightFactor = 2.0;
      generateAnalyticsButtonPaddingFactor = 0.55;
      chartCardVerticalPaddingFactor = 0.55;
      cardHeightFactor = 0.8;
      otherGridTextFontSizeFactor = 1.0; // Base text size for mobile
    } else if (isTablet) {
      appBarHeightFactor = 0.9;
      titleFontSizeFactor = 0.75;
      cardPaddingFactor = 0.75;
      cardMarginFactor = 1.0;
      fontSizeFactor = 0.75;
      iconSizeFactor = 0.75;
      chartHeightFactor = 0.9;
      gridSpacingFactor = 0.5;
      appBarIconSizeFactor = 0.75;
      chartLegendFontSizeFactor = 0.65;
      summaryCardHeightFactor = 1.4;
      otherCardHeightFactor = 2.2;
      generateAnalyticsButtonPaddingFactor = 0.75;
      chartCardVerticalPaddingFactor = 0.75;
      cardHeightFactor = 1.0;
      otherGridTextFontSizeFactor = 0.95; // Slightly reduced text size for tablet
    } else if (isDesktop) {
      appBarHeightFactor = 1.1;
      titleFontSizeFactor = 0.95;
      cardPaddingFactor = 0.95;
      cardMarginFactor = 1.3;
      fontSizeFactor = 0.95;
      iconSizeFactor = 0.95;
      chartHeightFactor = 1.0;
      gridSpacingFactor = 0.7;
      appBarIconSizeFactor = 0.95;
      chartLegendFontSizeFactor = 0.85;
      summaryCardHeightFactor = 1.2;
      otherCardHeightFactor = 2.4;
      generateAnalyticsButtonPaddingFactor = 0.95;
      chartCardVerticalPaddingFactor = 0.95;
      cardHeightFactor = 1.1;
      otherGridTextFontSizeFactor = 0.90; // Reduced text size for desktop
    } else { // isLargeDesktop
      appBarHeightFactor = 1.3;
      titleFontSizeFactor = 1.0;
      cardPaddingFactor = 1.0;
      cardMarginFactor = 1.5;
      fontSizeFactor = 1.0;
      iconSizeFactor = 1.0;
      chartHeightFactor = 1.1;
      gridSpacingFactor = 0.8;
      appBarIconSizeFactor = 1.0;
      chartLegendFontSizeFactor = 0.9;
      summaryCardHeightFactor = 1.1;
      otherCardHeightFactor = 2.6;
      generateAnalyticsButtonPaddingFactor = 1.0;
      chartCardVerticalPaddingFactor = 1.0;
      cardHeightFactor = 1.2;
      otherGridTextFontSizeFactor = 0.85; // Further reduced text size for large desktop
    }

    // Set summary grid to always be 1 column
    int summaryGridCrossAxisCount = 1;
    double summaryGridChildAspectRatio;

    if (isMobile) {
      summaryGridChildAspectRatio = 2.0;
    } else if (isTablet) {
      summaryGridChildAspectRatio = 1.8;
    } else if (isDesktop) {
      summaryGridChildAspectRatio = 3.0;
    } else { // isLargeDesktop
      summaryGridChildAspectRatio = 3.5;
    }


    int otherCardsGridCrossAxisCount = isMobile ? 1 : isTablet ? 2 : isDesktop ? 3 : 3;
    double otherCardsGridChildAspectRatio = isMobile ? 1.8 : isTablet ? 1.5 : isDesktop ? 1.3 : 1.1;


    return Scaffold(
      drawer: drawer2(
        context,
      ),
      appBar: AppBar(
        title: Text(
          'Monitoring Dashboard',
          style: TextStyle(fontSize: 20 * titleFontSizeFactor),
        ),
        centerTitle: true,
        toolbarHeight: 60 * appBarHeightFactor,
      ),
      body: _isDataLoaded // Conditionally build the UI
          ? SingleChildScrollView(
        padding: EdgeInsets.all(16.0 * cardPaddingFactor),
        child: Column(
          children: [
            _buildSummaryGrid(
              context,
              cardPaddingFactor,
              cardMarginFactor,
              fontSizeFactor,
              iconSizeFactor,
              chartHeightFactor,
              gridSpacingFactor,
              summaryGridCrossAxisCount,
              summaryGridChildAspectRatio,
              summaryCardHeightFactor,
              isTablet || isDesktop || isLargeDesktop,
            ),
            SizedBox(height: 20 * gridSpacingFactor),
            _buildOtherCardsGrid(
              context,
              cardPaddingFactor,
              cardMarginFactor,
              fontSizeFactor,
              iconSizeFactor,
              chartHeightFactor,
              gridSpacingFactor,
              otherCardsGridCrossAxisCount,
              otherCardsGridChildAspectRatio,
              chartLegendFontSizeFactor,
              summaryCardHeightFactor,
              otherCardHeightFactor,
              chartCardVerticalPaddingFactor,
              otherGridTextFontSizeFactor, // Pass the new factor here
            ),
          ],
        ),
      )
          : const Center(child: CircularProgressIndicator()), // Show loading indicator
    );
  }

  Widget _buildSummaryGrid(
      BuildContext context,
      double cardPaddingFactor,
      double cardMarginFactor,
      double fontSizeFactor,
      double iconSizeFactor,
      double chartHeightFactor,
      double gridSpacingFactor,
      int crossAxisCount,
      double childAspectRatio,
      double summaryCardHeightFactor,
      bool isLargeScreen) {
    return GridView.count(
      crossAxisCount: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20 * gridSpacingFactor,
      mainAxisSpacing: 20 * gridSpacingFactor,
      childAspectRatio: childAspectRatio,
      children: [
        _buildCard(
          title: 'Attendance Overview',
          child: _buildAttendanceChart(
              cardPaddingFactor: cardPaddingFactor,
              cardMarginFactor: cardMarginFactor,
              fontSizeFactor: fontSizeFactor,
              iconSizeFactor: iconSizeFactor,
              isLargeScreen: isLargeScreen),
          cardPaddingFactor: cardPaddingFactor,
          cardMarginFactor: cardMarginFactor,
          fontSizeFactor: fontSizeFactor,
          chartLegendFontSizeFactor: max(0.8, min(1.2, MediaQuery.of(context).size.width / 800)),
          iconSizeFactor: iconSizeFactor,
          isLargeScreen: isLargeScreen,
        ),
      ],
    );
  }

  Widget _buildOtherCardsGrid(
      BuildContext context,
      double cardPaddingFactor,
      double cardMarginFactor,
      double fontSizeFactor,
      double iconSizeFactor,
      double chartHeightFactor,
      double gridSpacingFactor,
      int crossAxisCount,
      double childAspectRatio,
      double chartLegendFontSizeFactor,
      double summaryCardHeightFactor,
      double otherCardHeightFactor,
      double chartCardVerticalPaddingFactor,
      double otherGridTextFontSizeFactor // Receive the new factor
      ) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20 * gridSpacingFactor,
      mainAxisSpacing: 20 * gridSpacingFactor,
      childAspectRatio: childAspectRatio,
      children: [
        _buildCard(
          title: 'Weekly Trends',
          child: _buildWeeklyTrendChart(
              cardPaddingFactor: cardPaddingFactor,
              cardMarginFactor: cardMarginFactor,
              fontSizeFactor: fontSizeFactor,
              chartLegendFontSizeFactor: chartLegendFontSizeFactor,
              chartHeightFactor: chartHeightFactor),
          cardPaddingFactor: cardPaddingFactor,
          cardMarginFactor: cardMarginFactor,
          fontSizeFactor: fontSizeFactor,
          chartLegendFontSizeFactor: chartLegendFontSizeFactor,
          iconSizeFactor: iconSizeFactor,
        ),
        _buildCard(
          title: 'Performance Gauge',
          child: _buildPerformanceGauge(
              cardPaddingFactor: cardPaddingFactor,
              cardMarginFactor: cardMarginFactor,
              fontSizeFactor: fontSizeFactor,
              chartLegendFontSizeFactor: chartLegendFontSizeFactor,
              iconSizeFactor: iconSizeFactor,
              chartHeightFactor: chartHeightFactor),
          cardPaddingFactor: cardPaddingFactor,
          cardMarginFactor: cardMarginFactor,
          fontSizeFactor: fontSizeFactor,
          chartLegendFontSizeFactor: chartLegendFontSizeFactor,
          iconSizeFactor: iconSizeFactor,
        ),
        _buildCard(
          title: 'Late Arrivals & Geolocation compliance Trends',
          child: _buildTaskCompletionChart(
              cardPaddingFactor: cardPaddingFactor,
              cardMarginFactor: cardMarginFactor,
              fontSizeFactor: fontSizeFactor,
              chartLegendFontSizeFactor: chartLegendFontSizeFactor,
              chartHeightFactor: chartHeightFactor),
          cardPaddingFactor: cardPaddingFactor,
          cardMarginFactor: cardMarginFactor,
          fontSizeFactor: fontSizeFactor,
          chartLegendFontSizeFactor: chartLegendFontSizeFactor,
          iconSizeFactor: iconSizeFactor,
        ),
        _buildCard(
          title: 'Live Facility Clock-In',
          child: _buildFacilityClockInCard(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, otherCardHeightFactor), // REPLACED HERE
          cardPaddingFactor: cardPaddingFactor,
          cardMarginFactor: cardMarginFactor,
          fontSizeFactor: fontSizeFactor,
          chartLegendFontSizeFactor: chartLegendFontSizeFactor,
          iconSizeFactor: iconSizeFactor,
        ),
        _buildTimesheetStatusCard(cardPaddingFactor, cardMarginFactor, fontSizeFactor,
            chartLegendFontSizeFactor, iconSizeFactor, otherCardHeightFactor, otherGridTextFontSizeFactor), // Pass new factor
        _buildLeaveRequestsCard(cardPaddingFactor, cardMarginFactor, fontSizeFactor,
            chartLegendFontSizeFactor, iconSizeFactor, max(1.2, min(2.0, MediaQuery.of(context).size.height / 700)), otherGridTextFontSizeFactor), // Pass new factor
        _buildTaskManagementCard(cardPaddingFactor, cardMarginFactor, fontSizeFactor,
            chartLegendFontSizeFactor, iconSizeFactor, otherCardHeightFactor, otherGridTextFontSizeFactor) // Pass new factor
      ],
    );
  }


  Widget _buildLeaveRequestsCard(double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartLegendFontSizeFactor, double iconSizeFactor, double otherCardHeightFactor, double otherGridTextFontSizeFactor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.all(20.0 * cardPaddingFactor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Leave Requests',
              style: TextStyle(fontSize: 20 * fontSizeFactor * otherGridTextFontSizeFactor, fontWeight: FontWeight.bold), // Apply factor here
            ),
            SizedBox(height: 20 * cardMarginFactor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pending Requests:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
                Text('${pendingLeaveRequests.length} Requests', style: TextStyle(color: Colors.orange, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
              ],
            ),
            SizedBox(height: 2),
            SizedBox(
              height: 50 * cardMarginFactor * otherCardHeightFactor,
              child: ListView.builder(
                itemCount: pendingLeaveRequests.length,
                itemBuilder: (context, index) {
                  final request = pendingLeaveRequests[index];
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(vertical: 2 * cardMarginFactor),
                    leading: Icon(Icons.pending_actions, color: Colors.orange, size: 24 * iconSizeFactor),
                    title: Text(request.employeeName, style: TextStyle(fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
                    subtitle: Text('${request.leaveType} - ${request.startDate}', style: TextStyle(fontSize: 12 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
                    trailing: IconButton(
                      icon: Icon(Icons.arrow_forward_ios, size: 20 * iconSizeFactor),
                      onPressed: () {
                        print('Navigate to Leave Request Details for ${request.employeeName}');
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 10 * cardMarginFactor),
            Text('Upcoming Leaves', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
            SizedBox(height: 2),
            SizedBox(
              height: 50 * cardMarginFactor * otherCardHeightFactor,
              child: ListView.builder(
                itemCount: upcomingLeaves.length,
                itemBuilder: (context, index) {
                  final leave = upcomingLeaves[index];
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(vertical: 2 * cardMarginFactor),
                    leading: Icon(Icons.calendar_today, color: Colors.green, size: 24 * iconSizeFactor),
                    title: Text(leave.employeeName, style: TextStyle(fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
                    subtitle: Text('${leave.leaveType} - ${leave.startDate}', style: TextStyle(fontSize: 12 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
                  );
                },
              ),
            ),
            SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () {
                  print('Navigate to Leave Requests Module');
                },
                child: Text('View All Leave Requests', style: TextStyle(fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimesheetStatusCard(double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartLegendFontSizeFactor, double iconSizeFactor, double otherCardHeightFactor, double otherGridTextFontSizeFactor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.all(20.0 * cardPaddingFactor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Timesheet Status',
              style: TextStyle(fontSize: 20 * fontSizeFactor * otherGridTextFontSizeFactor, fontWeight: FontWeight.bold), // Apply factor here
            ),
            SizedBox(height: 20 * cardMarginFactor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pending Submission:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
                Text('${5} Timesheets', style: TextStyle(color: Colors.red, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
              ],
            ),
            SizedBox(height: 10 * cardMarginFactor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pending Approval:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
                Text('${3} Timesheets', style: TextStyle(color: Colors.orange, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
              ],
            ),
            SizedBox(height: 20 * cardMarginFactor),
            Text('Timesheet Completion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
            SizedBox(height: 10),
            SizedBox(
              height: 50 * cardMarginFactor * otherCardHeightFactor,
              child: SfLinearGauge(
                minimum: 0,
                maximum: 100,
                orientation: LinearGaugeOrientation.horizontal,
                majorTickStyle: LinearTickStyle(length: 12 * cardMarginFactor),
                minorTickStyle: LinearTickStyle(length: 8 * cardMarginFactor),
                axisLabelStyle: TextStyle(fontSize: 12 * fontSizeFactor * otherGridTextFontSizeFactor), // Apply factor here
                barPointers: <LinearBarPointer>[
                  LinearBarPointer(
                    value: 75,
                    thickness: 20 * cardMarginFactor,
                    color: Colors.blue.shade400,
                    edgeStyle: LinearEdgeStyle.bothCurve,
                  ),
                ],
                markerPointers: <LinearShapePointer>[
                  LinearShapePointer(
                    value: 75,
                    offset: 25 * cardMarginFactor,
                    shapeType: LinearShapePointerType.circle,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () {
                  print('Navigate to Timesheet Module');
                },
                child: Text('View Timesheets', style: TextStyle(fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskManagementCard(double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartLegendFontSizeFactor, double iconSizeFactor, double otherCardHeightFactor, double otherGridTextFontSizeFactor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.all(20.0 * cardPaddingFactor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Task Management',
              style: TextStyle(fontSize: 20 * fontSizeFactor * otherGridTextFontSizeFactor, fontWeight: FontWeight.bold), // Apply factor here
            ),
            SizedBox(height: 20 * cardMarginFactor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tasks In Progress:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
                Text('${12} Tasks', style: TextStyle(color: Colors.blue, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
              ],
            ),
            SizedBox(height: 10 * cardMarginFactor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Overdue Tasks:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
                Text('${2} Tasks', style: TextStyle(color: Colors.red, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
              ],
            ),
            SizedBox(height: 20 * cardMarginFactor),
            Text('Task Completion Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
            SizedBox(height: 10 * cardMarginFactor),
            SizedBox(
              height: 50 * cardMarginFactor * otherCardHeightFactor,
              child: SfLinearGauge(
                minimum: 0,
                maximum: 100,
                orientation: LinearGaugeOrientation.horizontal,
                majorTickStyle: LinearTickStyle(length: 12 * cardMarginFactor),
                minorTickStyle: LinearTickStyle(length: 8 * cardMarginFactor),
                axisLabelStyle: TextStyle(fontSize: 12 * fontSizeFactor * otherGridTextFontSizeFactor), // Apply factor here
                barPointers: <LinearBarPointer>[
                  LinearBarPointer(
                    value: 60,
                    thickness: 20 * cardMarginFactor,
                    color: Colors.green.shade400,
                    edgeStyle: LinearEdgeStyle.bothCurve,
                  ),
                ],
                markerPointers: <LinearShapePointer>[
                  LinearShapePointer(
                    value: 60,
                    offset: 25 * cardMarginFactor,
                    shapeType: LinearShapePointerType.circle,
                    color: Colors.green.shade700,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () {
                  print('Navigate to Task Management Module');
                },
                child: Text('View Tasks', style: TextStyle(fontSize: 14 * fontSizeFactor * otherGridTextFontSizeFactor)), // Apply factor here
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildCard({
    required String title,
    required Widget child,
    required double cardPaddingFactor,
    required double cardMarginFactor,
    required double fontSizeFactor,
    required double chartLegendFontSizeFactor,
    required double iconSizeFactor,
    bool isLargeScreen = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.all(16.0 * cardPaddingFactor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18 * fontSizeFactor, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10 * cardMarginFactor),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceChart({
    required double cardPaddingFactor,
    required double cardMarginFactor,
    required double fontSizeFactor,
    required double iconSizeFactor,
    bool isLargeScreen = false,
  }) {
    return Row(
      children: [
        Expanded(
          flex: isLargeScreen ? 4 : 1,
          child: Padding(
            padding: EdgeInsets.all(8.0 * cardPaddingFactor),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/image/headshot.png',
                    fit: BoxFit.cover,
                    height: 100 * cardMarginFactor,
                    width: 100 * cardMarginFactor,
                  ),
                ),
                SizedBox(height: 8 * cardMarginFactor),
                Text(
                  "Punctuality Champion",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Emmanuel Vegher",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12 * fontSizeFactor),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: isLargeScreen ? 3 : 1,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0 * cardPaddingFactor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Dis-Aggregated Data',
                  style: TextStyle(fontSize: 16 * fontSizeFactor, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                SizedBox(height: 20 * cardMarginFactor),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Male', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
                          SizedBox(height: 8 * cardMarginFactor),
                          StreamBuilder<List<AttendanceData>>( // StreamBuilder for Male Data
                            stream: _facilityAttendanceDataStream(), // Use the new stream
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator(); // Loading indicator
                              }
                              if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}'); // Error message
                              }
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Text('No attendance data'); // No data message
                              }
                              List<AttendanceData> attendanceData = snapshot.data!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildAttendanceSummary('Male', attendanceData, fontSizeFactor, iconSizeFactor), // Use stream data
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Females', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor)),
                          SizedBox(height: 8 * cardMarginFactor),
                          StreamBuilder<List<AttendanceData>>( // StreamBuilder for Female Data (You might need a separate stream for female if you want to optimize queries, but for now, using the same stream and filtering in UI is fine)
                            stream: _facilityAttendanceDataStream(), // Re-use the same stream for now
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              }
                              if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}');
                              }
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Text('No attendance data');
                              }
                              List<AttendanceData> attendanceData = snapshot.data!;

                              // Calculate total present and total staff count
                              int totalPresent = 0;
                              int totalCount = 0;
                              for (var data in attendanceData) {
                                totalCount += data.count;
                                if (data.status == 'Present') {
                                  totalPresent = data.count;
                                }
                              }

                              // Calculate percentage
                              double percentage = 0.0;
                              if (totalCount > 0) {
                                percentage = (totalPresent / totalCount) * 100;
                              }

                              // Format percentage string
                              String percentageString = '${percentage.toStringAsFixed(1)}%'; // Format to 1 decimal place

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildAttendanceSummary('Female', attendanceData, fontSizeFactor, iconSizeFactor), // Use stream data
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20 * cardMarginFactor),
                Row(
                  children: [
                    _buildLegendItem(Colors.orange.shade400, 'Total Staffs', fontSizeFactor),
                    SizedBox(width: 16 * cardMarginFactor),
                    _buildLegendItem(Colors.green.shade400, '% Clocked-In', fontSizeFactor),
                  ],
                )
              ],
            ),
          ),
        ),
        Expanded(
          flex: isLargeScreen ? 3 : 1,
          child: StreamBuilder<List<AttendanceData>>( // StreamBuilder for Chart Data
            stream: _facilityAttendanceDataStream(), // Use the new stream
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No attendance data for chart');
              }
              List<AttendanceData> chartData = snapshot.data!;

              // Calculate total present and total staff count
              int totalPresent = 0;
              int totalCount = 0;
              for (var data in chartData) {
                totalCount += data.count;
                if (data.status == 'Present') {
                  totalPresent = data.count;
                }
              }

              // Calculate percentage
              double percentage = 0.0;
              if (totalCount > 0) {
                percentage = (totalPresent / totalCount) * 100;
              }

              // Format percentage string
              String percentageString = '${percentage.toStringAsFixed(1)}%'; // Format to 1 decimal place

              return SfCircularChart(
                series: <CircularSeries<AttendanceData, String>>[
                  DoughnutSeries<AttendanceData, String>(
                    dataSource: chartData, // Use stream data for chart
                    xValueMapper: (AttendanceData data, _) => data.status,
                    yValueMapper: (AttendanceData data, _) => data.count,
                    dataLabelSettings: const DataLabelSettings(isVisible: false),
                    enableTooltip: true,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                    innerRadius: '70%',
                    pointColorMapper: (AttendanceData data, _) {
                      if (data.status == 'Present') return Colors.green.shade400;
                      if (data.status == 'Absent') return Colors.orange.shade400;
                      if (data.status == 'Late') return Colors.red.shade400;
                      if (data.status == 'On Leave') return Colors.blue.shade400; // Color for On Leave
                      return Colors.grey.shade400;
                    },
                  )
                ],
                annotations: <CircularChartAnnotation>[
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Total Clocked In", // Display total staff count
                          style: TextStyle(fontSize: 18 * fontSizeFactor, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${totalPresent} ClockedIn / ${totalCount} Staffs', // Display dynamic percentage
                          style: TextStyle(fontSize: 12 * fontSizeFactor, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAttendanceSummary(String gender, List<AttendanceData> data, double fontSizeFactor, double iconSizeFactor) {
    return data.map((item) {
      Color color;
      if (item.status == 'Present') color = Colors.green.shade400;
      else if (item.status == 'Absent') color = Colors.orange.shade400;
      else if (item.status == 'Late') color = Colors.red.shade400;
      else color = Colors.grey.shade400;

      String statusText = '';
      if (item.status == 'Present') statusText = 'Present';
      else if (item.status == 'Absent') statusText = 'Absent';
      else if (item.status == 'Late') statusText = 'Late';
      else statusText = item.status;


      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 30 * 0.8 * iconSizeFactor,
              height: 30 * 0.8 * iconSizeFactor,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.person, size: 20 * iconSizeFactor, color: color),
              ),
            ),
            const SizedBox(width: 8),
            Text(statusText, style: TextStyle(fontSize: 12 * fontSizeFactor)),
          ],
        ),
      );
    }).toList();
  }


  Widget _buildLegendItem(Color color, String text, double fontSizeFactor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12 * 0.8 * fontSizeFactor,
          height: 12 * 0.8 * fontSizeFactor,
          color: color,
        ),
        SizedBox(width: 5 * 0.8 * fontSizeFactor),
        Text(text, style: TextStyle(fontSize: 12 * fontSizeFactor)),
      ],
    );
  }


  Widget _buildWeeklyTrendChart({
    required double cardPaddingFactor,
    required double cardMarginFactor,
    required double fontSizeFactor,
    required double chartLegendFontSizeFactor,
    required double chartHeightFactor,
  }) {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10 * fontSizeFactor)),
      primaryYAxis: NumericAxis(labelStyle: TextStyle(fontSize: 10 * fontSizeFactor)),
      title: ChartTitle(text: 'Weekly Attendance Trend', textStyle: TextStyle(fontSize: 14 * fontSizeFactor)),
      legend: Legend(isVisible: false),
      series: [
        LineSeries<WeeklyTrendData, String>(
          dataSource: weeklyTrendData,
          xValueMapper: (WeeklyTrendData data, _) => data.day,
          yValueMapper: (WeeklyTrendData data, _) => data.percentage,
          markerSettings: MarkerSettings(isVisible: true, height: 5 * chartHeightFactor * fontSizeFactor, width: 5 * chartHeightFactor * fontSizeFactor),
          dataLabelSettings: const DataLabelSettings(isVisible: false),
        ),
      ],
    );
  }

  Widget _buildPerformanceGauge({
    required double cardPaddingFactor,
    required double cardMarginFactor,
    required double fontSizeFactor,
    required double chartLegendFontSizeFactor,
    required double iconSizeFactor,
    required double chartHeightFactor,
  }) {
    return SfRadialGauge(
      axes: [
        RadialAxis(
          minimum: 0,
          maximum: 100,
          axisLineStyle: AxisLineStyle(thickness: 20 * cardMarginFactor * fontSizeFactor,),
          pointers: [
            NeedlePointer(
              value: 75,
              needleLength: 0.7,
              enableAnimation: true,
              animationDuration: 1500,
              needleColor: Colors.blue.shade700,
              tailStyle: TailStyle(length: 0.2, width: 20 * cardMarginFactor * fontSizeFactor, color: Colors.blue.shade700),
              knobStyle: KnobStyle(knobRadius: 0.09, color: Colors.white, borderColor: Colors.blue.shade700, borderWidth: 10 * fontSizeFactor),
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(widget: Text('75%', style: TextStyle(fontSize: 24 * fontSizeFactor, fontWeight: FontWeight.bold, color: Colors.blue.shade700)), angle: 90, positionFactor: 0.5)
          ],
        )
      ],
    );
  }

  Widget _buildTaskCompletionChart({
    required double cardPaddingFactor,
    required double cardMarginFactor,
    required double fontSizeFactor,
    required double chartLegendFontSizeFactor,
    required double chartHeightFactor,
  }) {
    return SfCartesianChart(
      title: ChartTitle(text: 'Late Arrivals &\nGeolocation compliance Trends', textStyle: TextStyle(fontSize: 14 * fontSizeFactor)),
      primaryXAxis: CategoryAxis(
          title: AxisTitle(text: 'Hour', textStyle: TextStyle(fontSize: 10 * fontSizeFactor)),
          labelIntersectAction: AxisLabelIntersectAction.multipleRows,
          labelStyle: TextStyle(fontSize: 10 * fontSizeFactor)
      ),
      primaryYAxis: NumericAxis(
          title: AxisTitle(text: '', textStyle: TextStyle(fontSize: 10 * fontSizeFactor)),
          minimum: 0,
          maximum: 900,
          interval: 200,
          labelStyle: TextStyle(fontSize: 10 * fontSizeFactor)
      ),
      legend: Legend(isVisible: true, position: LegendPosition.bottom, textStyle: TextStyle(fontSize: 12 * chartLegendFontSizeFactor)),
      series: <AreaSeries<GeolocationComplianceData, String>>[
        AreaSeries<GeolocationComplianceData, String>(
          dataSource: geolocationComplianceData,
          xValueMapper: (GeolocationComplianceData data, _) => data.hour,
          yValueMapper: (GeolocationComplianceData data, _) => data.locationCompliance,
          name: 'Location compliance',
          color: const Color(0xFF24B3A8),
        ),
        AreaSeries<GeolocationComplianceData, String>(
          dataSource: geolocationComplianceData,
          xValueMapper: (GeolocationComplianceData data, _) => data.hour,
          yValueMapper: (GeolocationComplianceData data, _) => data.other,
          name: 'other',
          color: const Color(0xFFD9E3EA),
        ),
      ],
    );
  }


  Widget _buildFacilityClockInCard(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double iconSizeFactor, double otherCardHeightFactor) {
    return Container(
      padding: EdgeInsets.all(15 * cardPaddingFactor * otherCardHeightFactor),
      decoration: BoxDecoration(
        //color: Colors.white,
        borderRadius: BorderRadius.circular(20 * cardMarginFactor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Facility Clock-In (Live Feed) - ${_selectedDateRange}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 16 * fontSizeFactor,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 24 * iconSizeFactor),
                onSelected: _handleDateRangeSelection,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: "Past 2 days",
                    child: Text('Past 2 days'),
                  ),
                  const PopupMenuItem<String>(
                    value: "Past 7 days",
                    child: Text('Past 7 days'),
                  ),
                  const PopupMenuItem<String>(
                    value: "Past 2 weeks",
                    child: Text('Past 2 weeks'),
                  ),
                  const PopupMenuItem<String>(
                    value: "Past 1 Month",
                    child: Text('Past 1 Month'),
                  ),
                  const PopupMenuItem<String>(
                    value: "Past 3 Month(s)",
                    child: Text('Past 3 Month(s)'),
                  ),
                  const PopupMenuItem<String>(
                    value: "Past 6 Month(s)",
                    child: Text('Past 6 Month(s)'),
                  ),
                  const PopupMenuItem<String>(
                    value: "Past 1 year",
                    child: Text('Past 1 year'),
                  ),
                  const PopupMenuItem<String>(
                    value: "Today",
                    child: Text('Today'),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 10 * cardMarginFactor,),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0 * cardPaddingFactor, vertical: 4.0 * cardPaddingFactor),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Name & Date", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12 * fontSizeFactor)),
                Text("Clock-In Time", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12 * fontSizeFactor)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _facilityClockInDataStream(startDate: _startDateFilter, endDate: _endDateFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                List<Map<String, dynamic>> facilityClockInData = snapshot.data ?? [];

                // Sort the list by clock-in time
                facilityClockInData.sort((a, b) {
                  final timeFormat = DateFormat('hh:mm a');
                  DateTime? timeA, timeB;
                  try {
                    timeA = timeFormat.parse(a['clockIn'] ?? '12:00 AM'); // Default to midnight for 'N/A'
                  } catch (e) {
                    timeA = DateTime(0); // Fallback in case of parsing error
                  }
                  try {
                    timeB = timeFormat.parse(b['clockIn'] ?? '12:00 AM'); // Default to midnight for 'N/A'
                  } catch (e) {
                    timeB = DateTime(0); // Fallback in case of parsing error
                  }

                  if (a['clockIn'] == 'N/A' && b['clockIn'] == 'N/A') return 0;
                  if (a['clockIn'] == 'N/A') return 1; // 'N/A' comes last
                  if (b['clockIn'] == 'N/A') return -1; // 'N/A' comes last

                  return timeA!.compareTo(timeB!);
                });


                if (facilityClockInData.isEmpty) {
                  return Center(
                      child: Text("No Clock-Ins for ${_selectedDateRange}",
                          style: TextStyle(fontSize: 14 * fontSizeFactor, color: Colors.grey)));
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: facilityClockInData.map((data) => _buildClockInListItem(
                      data['fullName'] ?? 'Unknown Staff',
                      data['date'] ?? 'N/A',
                      data['clockIn'] ?? 'N/A',
                      data['clockOut'] ?? '--/--', // Ensure clockOut is not null, default to '--/--'
                      fontSizeFactor,
                      cardMarginFactor,
                      cardPaddingFactor,
                    )).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildClockInListItem(String title, String date, String clockInTime, String clockOutTime, double fontSizeFactor, double cardMarginFactor, double cardPaddingFactor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0 * cardMarginFactor, horizontal: 8.0 * cardPaddingFactor), // Added horizontal padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically center
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 14 * fontSizeFactor),
                ),
                Text(
                  date,
                  style: TextStyle(color: Colors.black54, fontSize: 12 * fontSizeFactor),
                ),
              ],
            ),
          ),
          Row( // Wrap Clock-In Time and Tick in a Row
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center, // Align tick vertically center
            children: [
              Text(
                clockInTime,
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14 * fontSizeFactor), // Increased font size
              ),
              SizedBox(width: 5 * cardMarginFactor),
              if (clockInTime != 'N/A' && clockOutTime == '--/--')
                Column(
                  children: [
                    Icon(Icons.check, color: Colors.orange, size: 16 * fontSizeFactor),
                    SizedBox(width: 3 * cardMarginFactor),
                    Text("Clocked-In,Yet to Clock Out", style: TextStyle(fontSize: 12 * fontSizeFactor, color: Colors.orange),)
                  ],
                )
              else if (clockInTime != 'N/A' && clockOutTime != '--/--')
                Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16 * fontSizeFactor),
                    SizedBox(width: 3 * cardMarginFactor),
                    Text("Clocked-In and Clocked Out", style: TextStyle(fontSize: 12 * fontSizeFactor, color: Colors.green),)
                  ],
                )
              else
                SizedBox.shrink(), // No icon if clockIn is 'N/A'
            ],
          ),
        ],
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _facilityClockInDataStream({DateTime? startDate, DateTime? endDate}) {
    final currentUserUUID = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUUID == null || _currentUserState == null || _currentUserLocation == null || _currentUserStaffCategory == null) {
      print("Could not retrieve user info to load facility clock-in data stream.");
      return Stream.value([]); // Return an empty stream if user info is missing
    }

    DateFormat dateFormatter = DateFormat('dd-MMMM-yyyy');
    DateTime queryStartDate = startDate ?? DateTime.now();
    DateTime queryEndDate = endDate ?? DateTime.now();


    BehaviorSubject<List<Map<String, dynamic>>> dataSubject = BehaviorSubject<List<Map<String, dynamic>>>();

    Future<void> fetchData() async {
      List<Map<String, dynamic>> allClockInData = [];
      List<DateTime> dateRange = [];

      // Generate date range in reverse chronological order
      for (DateTime date = queryEndDate; date.isAfter(queryStartDate.subtract(const Duration(days: 1))); date = date.subtract(const Duration(days: 1))) {
        dateRange.add(date);
      }

      // Fetch data for each date in the reversed range
      for (DateTime date in dateRange) {
        String formattedDate = dateFormatter.format(date);

        // Fetch current user's record
        DocumentSnapshot currentUserRecordSnapshot = await FirebaseFirestore.instance
            .collection('Staff')
            .doc(currentUserUUID)
            .collection('Record')
            .doc(formattedDate)
            .get();
        if (currentUserRecordSnapshot.exists) {
          Map<String, dynamic> recordData = currentUserRecordSnapshot.data() as Map<String, dynamic>? ?? {};
          DocumentSnapshot staffDataSnapshot = await FirebaseFirestore.instance.collection('Staff').doc(currentUserUUID).get();
          Map<String, dynamic> staffData = staffDataSnapshot.data() as Map<String, dynamic>? ?? {};

          allClockInData.add({
            'fullName': '${staffData['firstName'] ?? 'N/A'} ${staffData['lastName'] ?? 'N/A'}',
            'date': recordData['date'] ?? formattedDate, // Use formattedDate if date is null from Firestore
            'clockIn': recordData['clockIn'] ?? 'N/A',
            'clockOut': recordData['clockOut'] ?? '--/--',
          });
        }

        // Fetch facility staff records
        QuerySnapshot facilityStaffSnapshot = await FirebaseFirestore.instance
            .collection('Staff')
            .where('state', isEqualTo: _currentUserState)
            .where('location', isEqualTo: _currentUserLocation)
            .get();

        for (var staffDoc in facilityStaffSnapshot.docs) {
          if (staffDoc.id == currentUserUUID) continue;
          DocumentSnapshot recordSnapshot = await staffDoc.reference
              .collection('Record')
              .doc(formattedDate)
              .get();
          if (recordSnapshot.exists) {
            Map<String, dynamic> recordData = recordSnapshot.data() as Map<String, dynamic>? ?? {};
            Map<String, dynamic> staffData = staffDoc.data() as Map<String, dynamic>? ?? {};

            allClockInData.add({
              'fullName': '${staffData['firstName'] ?? 'N/A'} ${staffData['lastName'] ?? 'N/A'}',
              'date': recordData['date'] ?? formattedDate, // Use formattedDate if date is null from Firestore
              'clockIn': recordData['clockIn'] ?? 'N/A',
              'clockOut': recordData['clockOut'] ?? '--/--',
            });
          }
        }
      }

      // Sort the data by date (descending) and then by clock-in time (ascending)
      allClockInData.sort((a, b) {
        // First, compare dates
        DateFormat displayDateFormat = DateFormat('dd-MMMM-yyyy');
        DateTime? dateA, dateB;
        try {
          dateA = displayDateFormat.parse(a['date'] ?? '01-January-1970'); // Default to epoch for 'N/A'
        } catch (e) {
          dateA = DateTime(0); // Fallback in case of parsing error
        }
        try {
          dateB = displayDateFormat.parse(b['date'] ?? '01-January-1970'); // Default to epoch for 'N/A'
        } catch (e) {
          dateB = DateTime(0); // Fallback in case of parsing error
        }

        int dateComparison = dateB!.compareTo(dateA!); // Reverse order for dates (descending)
        if (dateComparison != 0) {
          return dateComparison; // Dates are different, return date comparison
        }

        // If dates are the same, compare clock-in times
        final timeFormat = DateFormat('hh:mm a');
        DateTime? timeA, timeB;
        try {
          timeA = timeFormat.parse(a['clockIn'] ?? '12:00 AM'); // Default to midnight for 'N/A'
        } catch (e) {
          timeA = DateTime(0); // Fallback in case of parsing error
        }
        try {
          timeB = timeFormat.parse(b['clockIn'] ?? '12:00 AM'); // Default to midnight for 'N/A'
        } catch (e) {
          timeB = DateTime(0); // Fallback in case of parsing error
        }

        if (a['clockIn'] == 'N/A' && b['clockIn'] == 'N/A') return 0;
        if (a['clockIn'] == 'N/A') return 1; // 'N/A' comes last
        if (b['clockIn'] == 'N/A') return -1; // 'N/A' comes last

        return timeA!.compareTo(timeB!); // Ascending order for times
      });
      dataSubject.add(allClockInData);
    }

    fetchData(); // Initial data fetch
    return dataSubject.stream;
  }

  // Helper function to parse time from string
  DateTime _parseTime(String timeString) {
    try {
      return DateFormat("hh:mm a").parse(timeString); // e.g., "08:00 AM"
    } catch (e) {
      print("Error parsing time: $e");
      return DateTime(2000); // Return a default value if parsing fails
    }
  }


  Stream<List<AttendanceData>> _facilityAttendanceDataStream() {
    final currentUserUUID = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUUID == null || _currentUserState == null || _currentUserLocation == null) {
      print("Could not retrieve user info to load facility attendance data stream.");
      return Stream.value([]); // Return an empty stream if user info is missing
    }

    BehaviorSubject<List<AttendanceData>> dataSubject = BehaviorSubject<List<AttendanceData>>();

    Future<void> fetchData() async {
      DateFormat dateFormatter = DateFormat('dd-MMMM-yyyy');
      String currentDateFormatted = dateFormatter.format(DateTime.now());
      List<AttendanceData> attendanceDataList = [];

      int malePresentCount = 0;
      int maleAbsentCount = 0;
      int maleLateCount = 0;
      int maleOnLeaveCount = 0;

      int femalePresentCount = 0;
      int femaleAbsentCount = 0;
      int femaleLateCount = 0;
      int femaleOnLeaveCount = 0;

      int otherGenderPresentCount = 0; // For staff with no/unrecognized gender
      int otherGenderAbsentCount = 0;
      int otherGenderLateCount = 0;
      int otherGenderOnLeaveCount = 0;


      // --- All Staff Data (within location/state, no gender filter in query) ---
      QuerySnapshot allStaffSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .where('state', isEqualTo: _currentUserState)
          .where('location', isEqualTo: _currentUserLocation)
          .get();

      List<QueryDocumentSnapshot> maleStaffDocs = [];
      List<QueryDocumentSnapshot> femaleStaffDocs = [];
      List<QueryDocumentSnapshot> otherStaffDocs = [];

      for (var staffDoc in allStaffSnapshot.docs) {
        Map<String, dynamic> staffData = staffDoc.data() as Map<String, dynamic>;
        // print("staffData ==$staffData");
        String? gender = staffData['gender'] as String?;
        if (gender == 'Male') {
          print("MalestaffData ==$staffDoc");
          maleStaffDocs.add(staffDoc);
        } else if (gender == 'Female') {
          // print("FemalestaffData ==$staffDoc");
          femaleStaffDocs.add(staffDoc);
        } else {
          //print("OtherstaffData ==$staffDoc");
          otherStaffDocs.add(staffDoc); // Staff with missing or other gender values
        }
      }

      int totalMaleStaffCount = maleStaffDocs.length;
      int totalFemaleStaffCount = femaleStaffDocs.length;
      int totalOtherStaffCount = otherStaffDocs.length;


      // --- Process Male Staff ---
      // Reset counts before processing
      malePresentCount2 = 0;
      maleAbsentCount1 = 0;
      maleLateCount1 = 0;

      for (var staffDoc in maleStaffDocs) {
        DocumentSnapshot recordSnapshot = await staffDoc.reference
            .collection('Record')
            .doc(currentDateFormatted)
            .get();

        print("MaleRecordSnapshot === $recordSnapshot");

        if (recordSnapshot.exists) {
          malePresentCount2++; // Increment present count
          print("malePresentCount2Count ==$malePresentCount2");

          // Check if "clockIn" field exists in the sub-document
          var clockInTime = recordSnapshot.get("clockIn") ?? "";

          if (clockInTime.isNotEmpty) {
            DateTime parsedClockInTime = _parseTime(clockInTime);
            DateTime lateThreshold = _parseTime("08:00 AM");

            if (parsedClockInTime.isAfter(lateThreshold) || parsedClockInTime.isAtSameMomentAs(lateThreshold)) {
              maleLateCount1++; // Increment late count
            }
          }

          await _processAttendanceRecord(
            recordSnapshot,
            isMale: true,
            onPresent: () => malePresentCount++,
            onLate: () => maleLateCount++,
            onLeave: () => maleOnLeaveCount++,
          );

          malePresentCount++; // Count as present if record exists and not late or on leave
          print("malePresentCount === $malePresentCount");
        } else {
          maleAbsentCount1++; // Increment absent count if no record exists
        }
        // Print final global variable values
        print("Global malePresentCount1 === $malePresentCount2");
        print("Global maleAbsentCount1 === $maleAbsentCount1");
        print("Global maleLateCount1 === $maleLateCount1");
      }
      maleAbsentCount = totalMaleStaffCount - malePresentCount - maleLateCount - maleOnLeaveCount;
      if (maleAbsentCount < 0) maleAbsentCount = 0;


      // --- Process Female Staff ---
      for (var staffDoc in femaleStaffDocs) {
        DocumentSnapshot recordSnapshot = await staffDoc.reference
            .collection('Record')
            .doc(currentDateFormatted)
            .get();
        if (await _processAttendanceRecord(recordSnapshot, isMale: false, onPresent: () => femalePresentCount++, onLate: () => femaleLateCount++, onLeave: () => femaleOnLeaveCount++)) {
          femalePresentCount++; // Count as present if record exists and _processAttendanceRecord didn't handle late or leave
        }
        // Leave Request Check is now handled in _processAttendanceRecord
      }
      femaleAbsentCount = totalFemaleStaffCount - femalePresentCount - femaleLateCount - femaleOnLeaveCount;
      if (femaleAbsentCount < 0) femaleAbsentCount = 0;


      // --- Process Other Gender Staff (or missing gender) ---
      int malePresentCount1 = 0;

      for (var staffDoc in maleStaffDocs) {
        DocumentSnapshot recordSnapshot = await staffDoc.reference
            .collection('Record')
            .doc(currentDateFormatted)
            .get();

        print("MaleRecordSnapshot === $recordSnapshot");

        if (recordSnapshot.exists) {
          malePresentCount1++; // Increment count if a record exists for the current month

          await _processAttendanceRecord(
            recordSnapshot,
            isMale: true,
            onPresent: () => malePresentCount++,
            onLate: () => maleLateCount++,
            onLeave: () => maleOnLeaveCount++,
          );

          malePresentCount++; // Count as present if record exists and no late or leave detected
          print("malePresentCount === $malePresentCount");
        }
      }

      print("malePresentCount1 === $malePresentCount1");

      otherGenderAbsentCount = totalOtherStaffCount - otherGenderPresentCount - otherGenderLateCount - otherGenderOnLeaveCount;
      if (otherGenderAbsentCount < 0) otherGenderAbsentCount = 0;


      // --- Overall Attendance Data for Chart ---
      attendanceDataList.add(AttendanceData('Present', malePresentCount + femalePresentCount + otherGenderPresentCount));
      attendanceDataList.add(AttendanceData('Absent', maleAbsentCount + femaleAbsentCount + otherGenderAbsentCount));
      attendanceDataList.add(AttendanceData('Late', maleLateCount + femaleLateCount + otherGenderLateCount));
      attendanceDataList.add(AttendanceData('On Leave', maleOnLeaveCount + femaleOnLeaveCount + otherGenderOnLeaveCount));


      // --- Update UI via Stream ---
      dataSubject.add(attendanceDataList);
    }

    fetchData(); // Initial data fetch
    return dataSubject.stream;
  }

  // Helper function to process attendance record and leave request (DRY principle)
  Future<bool> _processAttendanceRecord(DocumentSnapshot recordSnapshot, {required bool isMale, required VoidCallback onPresent, required VoidCallback onLate, required VoidCallback onLeave}) async {
    DateFormat dateFormatter = DateFormat('dd-MMMM-yyyy');
    String currentDateFormatted = dateFormatter.format(DateTime.now());

    String genderType = isMale ? 'Male' : 'Female'; // For potential logging/debugging

    if (recordSnapshot.exists) {
      Map<String, dynamic> recordData = recordSnapshot.data() as Map<String, dynamic>? ?? {};
      String? clockInTime = recordData['clockIn'] as String?;
      if (clockInTime != null) {
        try {
          DateFormat timeFormat = DateFormat('hh:mm a');
          DateTime clockInDateTime = timeFormat.parse(clockInTime);
          DateTime lateTime = timeFormat.parse('8:00 AM');
          if (clockInDateTime.isAfter(lateTime) || clockInDateTime.isAtSameMomentAs(lateTime)) {
            onLate(); // Increment late count
            return false; // Indicate not just 'present' - was handled as late
          }
        } catch (e) {
          print("Error parsing clockIn time for $genderType staff: $e");
        }
      }

      // Leave Request Check - Moved inside _processAttendanceRecord for reusability
      final staffDocRef = recordSnapshot.reference.parent.parent; // Get the Staff document reference

      if (staffDocRef != null) { // Null check here!
        QuerySnapshot leaveRequestSnapshot = await staffDocRef.collection('Leave Request').get();
        for (var leaveDoc in leaveRequestSnapshot.docs) {
          Map<String, dynamic> leaveData = leaveDoc.data() as Map<String, dynamic>? ?? {};
          var startDateFieldValue = leaveData['startDate'];
          var endDateFieldValue = leaveData['endDate'];

          Timestamp? startDateTimestamp;
          Timestamp? endDateTimestamp;

          if (startDateFieldValue is Timestamp) {
            startDateTimestamp = startDateFieldValue;
          } else {
            print("Warning: startDate is not a Timestamp for $genderType staff, Leave Doc ${leaveDoc.id}. Value: $startDateFieldValue, Type: ${startDateFieldValue.runtimeType}");
            continue;
          }
          if (endDateFieldValue is Timestamp) {
            endDateTimestamp = endDateFieldValue;
          } else {
            print("Warning: endDate is not a Timestamp for $genderType staff, Leave Doc ${leaveDoc.id}. Value: $endDateFieldValue, Type: ${endDateFieldValue.runtimeType}");
            continue;
          }

          if (startDateTimestamp != null && endDateTimestamp != null) {
            DateTime startDate = startDateTimestamp.toDate();
            DateTime endDate = endDateTimestamp.toDate();
            DateTime now = DateTime.now();
            if (now.isAfter(startDate.subtract(const Duration(days: 1))) && now.isBefore(endDate.add(const Duration(days: 1)))) {
              onLeave(); // Increment on leave count
              return false; // Indicate not just 'present' - was handled as on leave
            }
          }
        }
      } else {
        print("Warning: Could not get Staff Document Reference to check for Leave Requests.");
      }


      onPresent(); // Increment present if not late and not on leave
      return true; // Indicate was handled as present (or potentially late/leave in callbacks)
    }
    return false; // No record, not present (will be counted as absent)
  }

}

class AttendanceData {
  final String status;
  final int count;
  AttendanceData(this.status, this.count);
}

class WeeklyTrendData {
  final String day;
  final double percentage;
  WeeklyTrendData(this.day, this.percentage);
}

class TaskCompletionData {
  final String task;
  final double completion;
  TaskCompletionData(this.task, this.completion);
}

class GeolocationComplianceData {
  final String hour;
  final double locationCompliance;
  final double other;

  GeolocationComplianceData(this.hour, this.locationCompliance, this.other);
}


List<AttendanceData> getAttendanceData() {
  return [
    AttendanceData('Present', 120),
    AttendanceData('Absent', 30),
    AttendanceData('Late', 20),
    AttendanceData('On Leave', 10),
  ];
}


List<WeeklyTrendData> getWeeklyTrendData() {
  return [
    WeeklyTrendData('Mon', 80),
    WeeklyTrendData('Tue', 85),
    WeeklyTrendData('Wed', 78),
    WeeklyTrendData('Thu', 88),
    WeeklyTrendData('Fri', 90),
  ];
}

List<TaskCompletionData> getTaskCompletionData() {
  return [
    TaskCompletionData('Task A', 90),
    TaskCompletionData('Task B', 75),
    TaskCompletionData('Task C', 60),
    TaskCompletionData('Task D', 85),
    TaskCompletionData('Task E', 70),
  ];
}

List<GeolocationComplianceData> getGeolocationComplianceData() {
  return [
    GeolocationComplianceData('0h', 100, 50),
    GeolocationComplianceData('1h', 200, 100),
    GeolocationComplianceData('2h', 300, 150),
    GeolocationComplianceData('3h', 400, 200),
    GeolocationComplianceData('4h', 500, 250),
    GeolocationComplianceData('5h', 600, 300),
    GeolocationComplianceData('6h', 700, 400),
    GeolocationComplianceData('7h', 800, 500),
    GeolocationComplianceData('8h', 700, 400),
    GeolocationComplianceData('9h', 600, 300),
    GeolocationComplianceData('10h', 500, 200),
    GeolocationComplianceData('11h', 400, 150),
  ];
}


class LeaveRequestData {
  final String employeeName;
  final String leaveType;
  final String startDate;
  LeaveRequestData(this.employeeName, this.leaveType, this.startDate);
}

List<LeaveRequestData> getPendingLeaveRequests() {
  return [
    LeaveRequestData('John Doe', 'Vacation', '2024-08-10'),
    LeaveRequestData('Jane Smith', 'Sick Leave', '2024-08-12'),
  ];
}

List<LeaveRequestData> getUpcomingLeaves() {
  return [
    LeaveRequestData('Alice Johnson', 'Vacation', '2024-08-15'),
    LeaveRequestData('Bob Williams', 'Personal Leave', '2024-08-18'),
  ];
}

class TaskData {
  final String status;
  final int count;
  TaskData(this.status, this.count);
}

List<TaskData> getTaskStatusData() {
  return [
    TaskData('In Progress', 12),
    TaskData('Overdue', 2),
  ];
}

class AttendanceData1 {
  final String status;
  final int count;
  AttendanceData1(this.status, this.count);
}

List<AttendanceData> getAttendanceData1() {
  return [
    AttendanceData('Present', 85),
    AttendanceData('Absent', 5),
    AttendanceData('On Leave', 8),
    AttendanceData('Late', 2),
  ];
}

class WeeklyAttendanceTrend1 {
  final String day;
  final double onTimePercentage;
  WeeklyAttendanceTrend1(this.day, this.onTimePercentage);
}

List<WeeklyAttendanceTrend1> getWeeklyTrendData1() {
  return [
    WeeklyAttendanceTrend1('Mon', 92),
    WeeklyAttendanceTrend1('Tue', 95),
    WeeklyAttendanceTrend1('Wed', 90),
    WeeklyAttendanceTrend1('Thu', 93),
    WeeklyAttendanceTrend1('Fri', 96),
  ];
}