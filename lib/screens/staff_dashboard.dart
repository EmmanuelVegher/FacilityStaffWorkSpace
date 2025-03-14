import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:rxdart/rxdart.dart'; // Import rxdart for combining streams
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../api/attendance_api.dart';
import '../models/attendance_record.dart';
import '../utils/date_helper.dart';
import '../widgets/drawer.dart';
import 'login_screen.dart';
import '../models/facility_staff_model.dart';

class UserDashboardApp extends StatelessWidget {
  const UserDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: UserDashboardPage(),
    );
  }
}

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  _UserDashboardPageState createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String? formattedMonth;
  final String _reportMessage = '';
  final AttendanceAPI _attendanceAPI = AttendanceAPI();
  List<AttendanceRecord> _attendanceData = [];
  List<LocationRecord> _locationData = [];

  String? _errorMessage;
  bool _isLoading = false;
  bool _isLoadingBestPlayer = false;
  bool _isLoadingClockInData = false;

  String _selectedDepartment = 'All Departments';
  String _selectedMonth = 'January';
  int _selectedYear = 2024;

  int _totalWorkHours = 0;
  int _minHoursWorked = 0;
  final String _minClockInTime = "N/A";
  int _maxHoursWorked = 0;
  final int _maxClockOutTime = 0;
  int _averageHoursWorked = 0;
  int _noOfHolidaysFilled = 0;
  int _noOfAnnualLeaveTaken = 0;

  late Future<void> _initialDataLoadingFuture;

  Timer? _logoutTimer;
  static const int _logoutAfterMinutes = 50;

  Map<String, int> _firestoreBestPlayerCounts = {};
  FacilityStaffModel? _bestPlayerOfWeek;
  String? _currentUserState;
  String? _currentUserLocation;
  String? _currentUserStaffCategory;
  Map<String, Map<String, dynamic>> _bestPlayerCache = {};
  int _totalSurveysCountedForBestPlayer = 0; // Added survey count variable

  void _resetLogoutTimer() {
    _logoutTimer?.cancel();
    _startLogoutTimer();
  }

  void _startLogoutTimer() {
    _logoutTimer = Timer(const Duration(minutes: _logoutAfterMinutes), _logoutUser);
  }

  void _logoutUser() {
    print('User logged out due to inactivity.');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    _initialDataLoadingFuture = _initializeData();
    _startLogoutTimer();
  }

  Future<void> _initializeData() async {
    await _loadCurrentUserBioDataForBestPlayer();
    await Future.wait([
      _fetchAttendanceData(),
      _loadBestPlayerDataForRange(_startDate, _endDate),
    ]);
  }

  Future<void> _loadCurrentUserBioDataForBestPlayer() async {
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

  @override
  void dispose() {
    _logoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double appBarHeightFactor = max(0.8, min(1.2, screenHeight / 800));
    double titleFontSizeFactor = max(0.8, min(1.2, screenWidth / 800));
    double cardPaddingFactor = max(0.8, min(1.2, screenWidth / 800));
    double cardMarginFactor = max(0.8, min(1.2, screenWidth / 800));
    double fontSizeFactor = max(0.8, min(1.2, screenWidth / 800));
    double iconSizeFactor = max(0.8, min(1.2, screenWidth / 800));
    double chartHeightFactor = max(0.8, min(1.2, screenHeight / 800));
    double gridSpacingFactor = max(0.8, min(1.2, screenWidth / 800));
    double appBarIconSizeFactor = max(0.8, min(1.2, screenWidth / 800));
    double chartLegendFontSizeFactor = max(0.8, min(1.2, screenWidth / 800));
    double summaryCardHeightFactor = screenWidth > 800 ? 1.0 : screenWidth > 800 ? 1.0 : 0.8; // Reduced height for tablet and mobile
    double otherCardHeightFactor = max(1.0, min(1.5, screenHeight / 800));
    double generateAnalyticsButtonPaddingFactor =
    max(0.8, min(1.2, screenWidth / 800));
    double chartCardVerticalPaddingFactor =
    max(0.8, min(1.2, screenHeight / 800));
    double cardHeightFactor = max(0.8, min(1.2, screenHeight / 800));

    int summaryGridCrossAxisCount = screenWidth > 1200 ? 6 : screenWidth > 800 ? 4 : 2;
    double summaryGridChildAspectRatio = screenWidth > 1200 ? 2.5 / 1.2 : screenWidth > 800 ? 2.0 / 1.2 : 1.5 / 1.0; // Adjusted for better mobile view

    int otherCardsGridCrossAxisCount = screenWidth > 1200 ? 3 : screenWidth > 800 ? 2 : 1;
    double otherCardsGridChildAspectRatio = screenWidth > 1200 ? 1.0 / 1.1 : screenWidth > 800 ? 1.5 / 1.1 : 2.0 / 1.1;

    return Listener(
      onPointerDown: (_) => _resetLogoutTimer(),
      onPointerMove: (_) => _resetLogoutTimer(),
      onPointerUp: (_) => _resetLogoutTimer(),
      onPointerCancel: (_) => _resetLogoutTimer(),
      onPointerSignal: (_) => _resetLogoutTimer(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        drawer: drawer(
          context,
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                'assets/image/ccfn_logo.png',
                fit: BoxFit.contain,
                height: 40 * appBarHeightFactor,
              ),
              Padding(
                padding: EdgeInsets.only(left: 10 * cardMarginFactor),
                child: Text(
                  'Facility Staff WorkSpace',
                   style: TextStyle(
                    color: Colors.white,
                    fontSize: 20 * titleFontSizeFactor,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF800018),
          toolbarHeight: 80 * appBarHeightFactor,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(60 * appBarHeightFactor),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0 * cardPaddingFactor),
              child: buildFilterBarInAppBar(
                  context,
                  cardPaddingFactor,
                  cardMarginFactor,
                  fontSizeFactor,
                  appBarHeightFactor,
                  generateAnalyticsButtonPaddingFactor),
            ),
          ),
        ),
        body: Stack(
          children: [
            FutureBuilder<void>(
              future: _initialDataLoadingFuture,
              builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  return SingleChildScrollView(
                    child: Padding(
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
                              summaryCardHeightFactor // Pass summaryCardHeightFactor
                          ),
                          // SizedBox(height: 20 * gridSpacingFactor),
                          // _buildRecognitionCardForDashboardInDashboard(
                          //     context, cardPaddingFactor, cardMarginFactor, fontSizeFactor),
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
                            screenWidth, // Pass screenWidth for text scaling in charts
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
            Visibility(
              visible: _isLoading || _isLoadingClockInData,
              child: Stack(
                children: <Widget>[
                  ModalBarrier(
                      dismissible: false, color: Colors.grey.withOpacity(0.5)),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        SizedBox(height: 20 * cardMarginFactor),
                        Text(
                          'Please Wait...',
                          style: TextStyle(
                              fontSize: 16 * fontSizeFactor,
                              color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      double summaryCardHeightFactor // Receive summaryCardHeightFactor
      ) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20 * gridSpacingFactor,
      mainAxisSpacing: 20 * gridSpacingFactor,
      childAspectRatio: childAspectRatio,
      children: [
        _buildSummaryCard(
            context,
            'Total Hours Worked',
            '$_totalWorkHours',
            Icons.timer,
            Colors.blue,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            iconSizeFactor,
            summaryCardHeightFactor // Pass summaryCardHeightFactor to summary card
        ),
        _buildSummaryCard(
            context,
            'Min Hours Worked',
            '$_minHoursWorked',
            Icons.timer_off,
            Colors.purple,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            iconSizeFactor,
            summaryCardHeightFactor// Pass summaryCardHeightFactor to summary card
        ),
        _buildSummaryCard(
            context,
            'Max Hours Worked',
            '$_maxHoursWorked',
            Icons.timer,
            Colors.purple,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            iconSizeFactor,
            summaryCardHeightFactor// Pass summaryCardHeightFactor to summary card
        ),
        _buildSummaryCard(
            context,
            'Avg Hours Worked',
            '$_averageHoursWorked',
            Icons.timelapse,
            Colors.purple,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            iconSizeFactor,
            summaryCardHeightFactor// Pass summaryCardHeightFactor to summary card
        ),
        _buildSummaryCard(
            context,
            'Holidays Filled',
            '$_noOfHolidaysFilled',
            Icons.holiday_village,
            Colors.purple,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            iconSizeFactor,
            summaryCardHeightFactor// Pass summaryCardHeightFactor to summary card
        ),
        _buildSummaryCard(
            context,
            'Annual Leave Taken',
            '$_noOfAnnualLeaveTaken',
            Icons.beach_access,
            Colors.purple,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            iconSizeFactor,
            summaryCardHeightFactor// Pass summaryCardHeightFactor to summary card
        ),
      ],
    );
  }

  Widget _buildRecognitionCardForDashboardInDashboard(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor) {
    return Align(
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Best Team Player (Facility Collective Votes)",
            style: TextStyle(
              fontSize: 16 * fontSizeFactor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8 * cardMarginFactor),
          _isLoadingBestPlayer
              ? SizedBox(
              height: 100 * max(0.8, min(1.2, MediaQuery.of(context).size.height / 800)),
              child: const Center(child: CircularProgressIndicator()))
              : _bestPlayerOfWeek != null
              ? _buildRecognitionCardForDashboard(
              _bestPlayerOfWeek, fontSizeFactor, _firestoreBestPlayerCounts[_bestPlayerOfWeek!.name!] ?? 0, _totalSurveysCountedForBestPlayer) // Pass counts here
              : SizedBox(
              height: 50 * max(0.8, min(1.2, MediaQuery.of(context).size.height / 800)),
              child: const Center(
                  child: Text("No Best Player data for this period"))),
        ],
      ),
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
      double screenWidth // Receive screenWidth
      ) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20 * gridSpacingFactor,
      mainAxisSpacing: 20 * gridSpacingFactor,
      childAspectRatio: childAspectRatio,
      children: [
        _buildFacilityClockInCard(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, otherCardHeightFactor), // New Card Here
        _buildClockInOutTrendsChartCard(
            context,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            chartHeightFactor,
            chartLegendFontSizeFactor,
            otherCardHeightFactor,
            chartCardVerticalPaddingFactor,
            screenWidth // Pass screenWidth
        ),
        _buildEarlyLateClockInsChartCard(
            context,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            chartHeightFactor,
            chartLegendFontSizeFactor,
            otherCardHeightFactor,
            chartCardVerticalPaddingFactor,
            screenWidth// Pass screenWidth
        ),
        _buildDurationWorkedDistributionChartCard(
            context,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            chartHeightFactor,
            chartLegendFontSizeFactor,
            otherCardHeightFactor,
            chartCardVerticalPaddingFactor,
            screenWidth// Pass screenWidth
        ),
        _buildAttendanceByLocationChartCard(
            context,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            chartHeightFactor,
            chartLegendFontSizeFactor,
            otherCardHeightFactor,
            chartCardVerticalPaddingFactor,
            screenWidth// Pass screenWidth
        ),
        _buildBestTeamPlayerCardWrapper(
            context,
            cardPaddingFactor,
            cardMarginFactor,
            fontSizeFactor,
            chartHeightFactor,
            chartLegendFontSizeFactor,
            otherCardHeightFactor,
            chartCardVerticalPaddingFactor,
            screenWidth, // Pass screenWidth
            _totalSurveysCountedForBestPlayer // Pass survey count here
        ),

      ],
    );
  }

  Widget _buildSummaryCard(
      BuildContext context,
      String title,
      String value,
      IconData icon,
      Color cardColor,
      double cardPaddingFactor,
      double cardMarginFactor,
      double fontSizeFactor,
      double iconSizeFactor,
      double summaryCardHeightFactor // Receive summaryCardHeightFactor
      ) {
    return Container(
      padding: EdgeInsets.all(12 * cardPaddingFactor),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * cardMarginFactor),
      ),
      height: 140 * summaryCardHeightFactor, // Use summaryCardHeightFactor here
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.black54, size: 18 * iconSizeFactor),
              SizedBox(width: 5 * cardMarginFactor),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontSize: 10 * fontSizeFactor,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15 * fontSizeFactor,
              fontWeight: FontWeight.bold,
              color: cardColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFilterBarInAppBar(
      BuildContext context,
      double cardPaddingFactor,
      double cardMarginFactor,
      double fontSizeFactor,
      double appBarHeightFactor,
      double generateAnalyticsButtonPaddingFactor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(width: 8 * cardMarginFactor),
        _buildDatePickerInAppBar('Start Date', _startDate, (date) {
          setState(() {
            _startDate = date;
            _resetLogoutTimer();
          });
        }, cardPaddingFactor, cardMarginFactor, fontSizeFactor),
        SizedBox(width: 8 * cardMarginFactor),
        _buildDatePickerInAppBar('End Date', _endDate, (date) {
          setState(() {
            _endDate = date;
            formattedMonth = DateFormat('MMMM yyyy').format(_endDate);
            _resetLogoutTimer();
          });
        }, cardPaddingFactor, cardMarginFactor, fontSizeFactor),
        SizedBox(width: 12 * cardMarginFactor),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _isLoading = true;
            });
            Future.wait([
              _fetchAttendanceData(),
              _loadBestPlayerDataForRange(_startDate, _endDate),
            ]).then((_) {
              setState(() {
                _isLoading = false;
              });
            }).catchError((error) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Error generating analytics: ${error.toString()}';
              });
            });
            _resetLogoutTimer();
          },
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
                horizontal:
                15 * cardPaddingFactor * generateAnalyticsButtonPaddingFactor,
                vertical:
                10 * cardPaddingFactor * generateAnalyticsButtonPaddingFactor),
          ),
          child: Text(
            'Generate Analytics',
            style: TextStyle(
                fontSize: 14 * fontSizeFactor * generateAnalyticsButtonPaddingFactor),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown(double cardPaddingFactor, double fontSizeFactor) {
    return DropdownButton<String>(
      value: _selectedDepartment,
      items: [
        'All Departments',
        'Doctors',
        'Pharmacists',
        'Lab Technicians',
        'Tracking Staff'
      ].map((department) => DropdownMenuItem(
          value: department,
          child: Text(
            department,
            style: TextStyle(fontSize: 14 * fontSizeFactor, color: Colors.white),
          ))).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedDepartment = newValue!;
          _resetLogoutTimer();
        });
      },
      dropdownColor: const Color(0xFF800018),
      style: const TextStyle(color: Colors.white),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
      underline: Container(height: 1, color: Colors.white),
    );
  }

  Widget _buildMonthDropdown(double cardPaddingFactor, double fontSizeFactor) {
    return DropdownButton<String>(
      value: _selectedMonth,
      items: ['January', 'February', 'March', 'April'].map((String month) {
        return DropdownMenuItem(
          value: month,
          child: Text(
            month,
            style: TextStyle(fontSize: 14 * fontSizeFactor, color: Colors.white),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedMonth = newValue!;
          _resetLogoutTimer();
        });
      },
      dropdownColor: const Color(0xFF800018),
      style: const TextStyle(color: Colors.white),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
      underline: Container(height: 1, color: Colors.white),
    );
  }

  Widget _buildYearDropdown(double cardPaddingFactor, double fontSizeFactor) {
    return DropdownButton<int>(
      value: _selectedYear,
      items: List.generate(5, (index) => DateTime.now().year - index)
          .map((int year) => DropdownMenuItem(
          value: year,
          child: Text(
            year.toString(),
            style: TextStyle(fontSize: 14 * fontSizeFactor, color: Colors.white),
          ))).toList(),
      onChanged: (int? newValue) {
        setState(() {
          _selectedYear = newValue!;
          _resetLogoutTimer();
        });
      },
      dropdownColor: const Color(0xFF800018),
      style: const TextStyle(color: Colors.white),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
      underline: Container(height: 1, color: Colors.white),
    );
  }

  Widget _buildClockInOutTrendsChartCard(
      BuildContext context,
      double cardPaddingFactor,
      double cardMarginFactor,
      double fontSizeFactor,
      double chartHeightFactor,
      double chartLegendFontSizeFactor,
      double otherCardHeightFactor,
      double chartCardVerticalPaddingFactor,
      double screenWidth // Receive screenWidth
      ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 16.0 * cardPaddingFactor * otherCardHeightFactor,
            vertical:
            16.0 * cardPaddingFactor * otherCardHeightFactor * chartCardVerticalPaddingFactor),
        child: _buildClockInOutTrendsChartContent(
            fontSizeFactor, cardMarginFactor, screenWidth), // Pass screenWidth
      ),
    );
  }

  Widget _buildClockInOutTrendsChartContent(double fontSizeFactor, double cardMarginFactor, double screenWidth) {
    final timeFormat = DateFormat('hh:mm a');
    double chartTextScaleFactor = screenWidth > 1200 ? 1.0 : screenWidth > 800 ? 0.9 : 0.8; // Scale factor for text

    final filteredAttendanceData = _attendanceData
        .where((data) =>
    data.clockInTime != null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Clock-In and Clock-Out Trends',
          style: TextStyle(
              fontSize: 14 * fontSizeFactor * chartTextScaleFactor, fontWeight: FontWeight.bold), // Apply scale factor
        ),
        SizedBox(height: 8 * cardMarginFactor),
        Expanded(
          child: SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
                title: AxisTitle(
                  text: 'Days of the Week',
                  textStyle: TextStyle(
                      fontSize: 10 * fontSizeFactor * chartTextScaleFactor, // Apply scale factor
                      fontWeight: FontWeight.bold),
                )),
            primaryYAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 12 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
                title: AxisTitle(
                  text: 'Time of the Day',
                  textStyle: TextStyle(
                      fontSize: 10 * fontSizeFactor * chartTextScaleFactor, // Apply scale factor
                      fontWeight: FontWeight.bold),
                ),
                isVisible: false),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              format: 'Clock-In: point.yClockIn\nClock-Out: point.yClockOut',
            ),
            series: <CartesianSeries<AttendanceRecord, String>>[
              LineSeries<AttendanceRecord, String>(
                dataSource: filteredAttendanceData,
                xValueMapper: (data, _) =>
                    DateFormat('dd-MMM').format(data.date),
                yValueMapper: (data, _) {
                  DateTime clockIn = timeFormat.parse(data.clockInTime);
                  return double.parse(
                      (clockIn.hour + (clockIn.minute / 60)).toStringAsFixed(1));
                },
                name: 'Clock-In',
                color: Colors.green,
                markerSettings: const MarkerSettings(isVisible: true),
                dataLabelSettings: DataLabelSettings(
                  isVisible: true,
                  builder: (data, point, series, pointIndex, seriesIndex) {
                    return Text(
                      timeFormat.format(timeFormat.parse(data.clockInTime)),
                      style: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
                    );
                  },
                  labelAlignment: ChartDataLabelAlignment.top,
                ),
              ),
              LineSeries<AttendanceRecord, String>(
                dataSource: filteredAttendanceData,
                xValueMapper: (data, _) =>
                    DateFormat('dd-MMM').format(data.date),
                yValueMapper: (data, _) {
                  if (data.clockOutTime == '--/--') {
                    return null; // Return null to not plot Clock-Out when it's "--/--"
                  } else {
                    DateTime clockOut = timeFormat.parse(data.clockOutTime);
                    return double.parse(
                        (clockOut.hour + (clockOut.minute / 60)).toStringAsFixed(1));
                  }
                },
                name: 'Clock-Out',
                color: Colors.red,
                markerSettings: const MarkerSettings(isVisible: true),
                dataLabelSettings: DataLabelSettings(
                  isVisible: true,
                  builder: (data, point, series, pointIndex, seriesIndex) {
                    // Conditionally show data label only when clockOutTime is not "--/--"
                    return data.clockOutTime == '--/--' ? const Text('') : Text(
                      timeFormat.format(timeFormat.parse(data.clockOutTime)),
                      style: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
                    );
                  },
                  labelAlignment: ChartDataLabelAlignment.bottom,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationWorkedDistributionChartCard(
      BuildContext context,
      double cardPaddingFactor,
      double cardMarginFactor,
      double fontSizeFactor,
      double chartHeightFactor,
      double chartLegendFontSizeFactor,
      double otherCardHeightFactor,
      double chartCardVerticalPaddingFactor,
      double screenWidth // Receive screenWidth
      ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 16.0 * cardPaddingFactor * otherCardHeightFactor,
            vertical:
            16.0 * cardPaddingFactor * otherCardHeightFactor * chartCardVerticalPaddingFactor),
        child: _buildDurationWorkedDistributionChartContent(
            fontSizeFactor, cardMarginFactor, screenWidth), // Pass screenWidth
      ),
    );
  }

  Widget _buildDurationWorkedDistributionChartContent(double fontSizeFactor, double cardMarginFactor, double screenWidth) {
    double chartTextScaleFactor = screenWidth > 1200 ? 1.0 : screenWidth > 800 ? 0.9 : 0.8; // Scale factor for text
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Distribution of Hours Worked',
          style: TextStyle(
              fontSize: 14 * fontSizeFactor * chartTextScaleFactor, fontWeight: FontWeight.bold), // Apply scale factor
        ),
        SizedBox(height: 8 * cardMarginFactor),
        Expanded(
          child: SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
                title: AxisTitle(
                  text: 'Duration of Hours Worked (Grouped By Hours)',
                  textStyle: TextStyle(
                      fontSize: 10 * fontSizeFactor * chartTextScaleFactor, // Apply scale factor
                      fontWeight: FontWeight.bold),
                )),
            primaryYAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
                title: AxisTitle(
                  text: 'Frequency',
                  textStyle: TextStyle(
                      fontSize: 10 * fontSizeFactor * chartTextScaleFactor, // Apply scale factor
                      fontWeight: FontWeight.bold),
                )),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: <HistogramSeries<AttendanceRecord, double>>[
              HistogramSeries<AttendanceRecord, double>(
                dataSource: _attendanceData,
                yValueMapper: (data, _) => DateHelper.calculateHoursWorked(
                    data.clockInTime, data.clockOutTime),
                binInterval: 1,
                color: Colors.purple,
                dataLabelSettings: const DataLabelSettings(isVisible: false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceByLocationChartCard(
      BuildContext context,
      double cardPaddingFactor,
      double cardMarginFactor,
      double fontSizeFactor,
      double chartHeightFactor,
      double chartLegendFontSizeFactor,
      double otherCardHeightFactor,
      double chartCardVerticalPaddingFactor,
      double screenWidth // Receive screenWidth
      ) {
    List<LocationRecord> locationData1 = _getLocationData(_attendanceData);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 16.0 * cardPaddingFactor * otherCardHeightFactor,
            vertical:
            16.0 * cardPaddingFactor * otherCardHeightFactor * chartCardVerticalPaddingFactor),
        child: _buildAttendanceByLocationChartContent(
            fontSizeFactor, cardMarginFactor, locationData1, screenWidth), // Pass screenWidth
      ),
    );
  }

  Widget _buildAttendanceByLocationChartContent(double fontSizeFactor, double cardMarginFactor, List<LocationRecord> locationData1, double screenWidth) {
    double chartTextScaleFactor = screenWidth > 1200 ? 1.0 : screenWidth > 800 ? 0.9 : 0.8; // Scale factor for text
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Attendance by Location',
          style: TextStyle(
              fontSize: 14 * fontSizeFactor * chartTextScaleFactor, fontWeight: FontWeight.bold), // Apply scale factor
        ),
        SizedBox(height: 8 * cardMarginFactor),
        Expanded(
          child: SfCircularChart(
            legend: Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                orientation: LegendItemOrientation.horizontal,
                textStyle: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor)), // Apply scale factor
            series: <CircularSeries>[
              DoughnutSeries<LocationRecord, String>(
                dataSource: locationData1,
                xValueMapper: (LocationRecord data, _) => data.location,
                yValueMapper: (LocationRecord data, _) => data.attendanceCount,
                dataLabelSettings: const DataLabelSettings(
                  isVisible: false,
                  labelPosition: ChartDataLabelPosition.inside,
                ),
                enableTooltip: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEarlyLateClockInsChartCard(
      BuildContext context,
      double cardPaddingFactor,
      double cardMarginFactor,
      double fontSizeFactor,
      double chartHeightFactor,
      double chartLegendFontSizeFactor,
      double otherCardHeightFactor,
      double chartCardVerticalPaddingFactor,
      double screenWidth // Receive screenWidth
      ) {
    final timeFormat = DateFormat('hh:mm a');
    List<Map<String, dynamic>> chartData = _attendanceData.map((record) {
      int earlyLateMinutes = DateHelper.calculateEarlyLateTime(record.clockInTime);
      return {
        'date': DateFormat('dd-MMM').format(record.date),
        'earlyLateMinutes': earlyLateMinutes,
        'clockInTime': timeFormat.format(timeFormat.parse(record.clockInTime)),
      };
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 16.0 * cardPaddingFactor * otherCardHeightFactor,
            vertical:
            16.0 * cardPaddingFactor * otherCardHeightFactor * chartCardVerticalPaddingFactor),
        child: _buildEarlyLateClockInsChartContent(
            fontSizeFactor, cardMarginFactor, chartData, screenWidth), // Pass screenWidth
      ),
    );
  }

  Widget _buildEarlyLateClockInsChartContent(double fontSizeFactor, double cardMarginFactor, List<Map<String, dynamic>> chartData, double screenWidth) {
    double chartTextScaleFactor = screenWidth > 1200 ? 1.0 : screenWidth > 800 ? 0.9 : 0.8; // Scale factor for text
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Did You Clock In Early or Late? (Green = Early, Red = Late, 0 = On Time)',
          style: TextStyle(
              fontSize: 14 * fontSizeFactor * chartTextScaleFactor, fontWeight: FontWeight.bold), // Apply scale factor
        ),
        SizedBox(height: 8 * cardMarginFactor),
        Expanded(
          child: SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
                title: AxisTitle(
                  text: 'Days Of the Week',
                  textStyle: TextStyle(
                      fontSize: 10 * fontSizeFactor * chartTextScaleFactor, // Apply scale factor
                      fontWeight: FontWeight.bold),
                )),
            primaryYAxis: NumericAxis(
              majorGridLines: const MajorGridLines(width: 0),
              axisLine: const AxisLine(width: 0),
              title: AxisTitle(
                text: 'Minutes Early/Late (vs 8:00 AM)',
                textStyle: TextStyle(
                    fontSize: 10 * fontSizeFactor * chartTextScaleFactor, // Apply scale factor
                    fontWeight: FontWeight.bold),
              ),
              labelStyle: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
              minimum: chartData.isNotEmpty // Check if chartData is not empty
                  ? chartData
                  .map((data) => data['earlyLateMinutes'] as int)
                  .reduce((a, b) => a < b ? a : b) < 0
                  ? chartData
                  .map((data) => data['earlyLateMinutes'] as int)
                  .reduce((a, b) => a < b ? a : b)
                  .toDouble()
                  : null
                  : 0, // Default minimum if chartData is empty
              maximum: chartData.isNotEmpty // Check if chartData is not empty
                  ? chartData
                  .map((data) => data['earlyLateMinutes'] as int)
                  .reduce((a, b) => a > b ? a : b) > 0
                  ? chartData
                  .map((data) => data['earlyLateMinutes'] as int)
                  .reduce((a, b) => a > b ? a : b)
                  .toDouble()
                  : null
                  : 0, // Default maximum if chartData is empty,
            ),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: <CartesianSeries<Map<String, dynamic>, String>>[
              ColumnSeries<Map<String, dynamic>, String>(
                dataSource: chartData,
                xValueMapper: (data, _) => data['date'] as String,
                yValueMapper: (data, _) => data['earlyLateMinutes'] as int,
                name: 'Early/Late Minutes',
                pointColorMapper: (data, _) =>
                (data['earlyLateMinutes'] as int) >= 0
                    ? Colors.red
                    : Colors.green,
                dataLabelSettings: const DataLabelSettings(isVisible: false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerInAppBar(
      String label,
      DateTime initialDate,
      Function(DateTime) onDateSelected,
      double cardPaddingFactor,
      double cardMarginFactor,
      double fontSizeFactor) {
    return Row(
      children: [
        Text('$label: ',
            style: TextStyle(fontSize: 14 * fontSizeFactor, color: Colors.white)),
        TextButton(
          onPressed: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (selectedDate != null) {
              onDateSelected(selectedDate);
              _resetLogoutTimer();
            }
          },
          child: Text(DateFormat('dd-MM-yyyy').format(initialDate),
              style: TextStyle(fontSize: 14 * fontSizeFactor, color: Colors.white)),
        ),
      ],
    );
  }

  List<LocationRecord> _getLocationData(List<AttendanceRecord> attendanceData) {
    Map<String, int> locationCounts = {};
    for (var record in attendanceData) {
      final location = record.clockInLocation;
      locationCounts.update(location, (value) => value + 1, ifAbsent: () => 1);
    }
    return locationCounts.entries
        .map((entry) => LocationRecord(
        location: entry.key, attendanceCount: entry.value))
        .toList();
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _attendanceData =
      await getRecordsForDateRangeForChart(_startDate, _endDate);
      _locationData = _getLocationData(_attendanceData);
      _calculateSummaryValues(_attendanceData);
    } catch (error) {
      setState(() {
        _errorMessage = 'Error fetching data: ${error.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateSummaryValues(List<AttendanceRecord> filteredData) {
    if (filteredData.isEmpty) {
      _totalWorkHours = 0;
      _minHoursWorked = 0;
      _maxHoursWorked = 0;
      _averageHoursWorked = 0;
      _noOfHolidaysFilled = 0;
      _noOfAnnualLeaveTaken = 0;
      return;
    }

    _totalWorkHours = _calculateTotalWorkHours(filteredData);
    _minHoursWorked = _calculateMinHoursWorked(filteredData);
    _maxHoursWorked = _calculateMaxHoursWorked(filteredData);
    _averageHoursWorked = _calculateAverageHoursWorked(filteredData);
    _noOfHolidaysFilled = _calculateNoOfHolidaysFilled(filteredData);
    _noOfAnnualLeaveTaken = _calculateNoOfAnnualLeaveTaken(filteredData);
  }

  int _calculateTotalWorkHours(List<AttendanceRecord> filteredData) {
    double totalHours = 0;
    for (var record in filteredData) {
      if (record.durationWorked != "Annual Leave" &&
          record.durationWorked != "Holiday") {
        totalHours += DateHelper.calculateHoursWorked(
            record.clockInTime, record.clockOutTime);
      }
    }
    return totalHours.round();
  }

  int _calculateMinHoursWorked(List<AttendanceRecord> filteredData) {
    if (filteredData.isEmpty) return 0;
    double minHours = double.infinity;
    for (var record in filteredData) {
      if (record.durationWorked != "Annual Leave" &&
          record.durationWorked != "Holiday") {
        double hours = DateHelper.calculateHoursWorked(
            record.clockInTime, record.clockOutTime);
        minHours = minHours < hours ? minHours : hours;
      }
    }
    return minHours == double.infinity ? 0 : minHours.round();
  }

  int _calculateMaxHoursWorked(List<AttendanceRecord> filteredData) {
    if (filteredData.isEmpty) return 0;
    double maxHours = 0;
    for (var record in filteredData) {
      if (record.durationWorked != "Annual Leave" &&
          record.durationWorked != "Holiday") {
        double hours = DateHelper.calculateHoursWorked(
            record.clockInTime, record.clockOutTime);
        maxHours = maxHours > hours ? maxHours : hours;
      }
    }
    return maxHours.round();
  }

  int _calculateAverageHoursWorked(List<AttendanceRecord> filteredData) {
    if (filteredData.isEmpty) return 0;
    double totalHours = 0;
    int validAttendanceCount = 0;
    for (var record in filteredData) {
      if (record.durationWorked != "Annual Leave" &&
          record.durationWorked != "Holiday") {
        totalHours += DateHelper.calculateHoursWorked(
            record.clockInTime, record.clockOutTime);
        validAttendanceCount++;
      }
    }
    return validAttendanceCount == 0
        ? 0
        : (totalHours / validAttendanceCount).round();
  }

  int _calculateNoOfHolidaysFilled(List<AttendanceRecord> filteredData) {
    return filteredData
        .where((record) => record.durationWorked == "Holiday")
        .length;
  }

  int _calculateNoOfAnnualLeaveTaken(List<AttendanceRecord> filteredData) {
    return filteredData
        .where((record) => record.durationWorked == "Annual Leave")
        .length;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<AttendanceRecord>> getRecordsForDateRangeForChart(
      DateTime startDate, DateTime endDate) async {
    final records = <AttendanceRecord>[];
    final User? user = _auth.currentUser;
    final String? userId = user?.uid;

    if (userId == null) {
      print('User not logged in or User ID not found.');
      return [];
    }

    try {
      for (var date = startDate;
      date.isBefore(endDate.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))) {
        final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);

        final recordSnapshot = await _firestore
            .collection('Staff')
            .doc(userId)
            .collection('Record')
            .doc(formattedDate)
            .get();

        if (recordSnapshot.exists) {
          records.add(AttendanceRecord.fromFirestore(recordSnapshot));
        }
      }
    } catch (e) {
      print('Error fetching data: $e');
      rethrow;
    }
    return records;
  }

  Widget _buildBestTeamPlayerCardWrapper(
      BuildContext context,
      double cardPaddingFactor,
      double cardMarginFactor,
      double fontSizeFactor,
      double chartHeightFactor,
      double chartLegendFontSizeFactor,
      double otherCardHeightFactor,
      double chartCardVerticalPaddingFactor,
      double screenWidth, // Receive screenWidth
      int surveyCount // Receive surveyCount
      ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 16.0 * cardPaddingFactor * otherCardHeightFactor,
            vertical:
            16.0 * cardPaddingFactor * otherCardHeightFactor * chartCardVerticalPaddingFactor),
        child: _buildBestTeamPlayerCardContent(
            fontSizeFactor, cardMarginFactor, _startDate, _endDate, screenWidth, surveyCount), // Pass screenWidth and surveyCount
      ),
    );
  }

  Widget _buildBestTeamPlayerCardContent(
      double fontSizeFactor, double cardMarginFactor, DateTime startDate, DateTime endDate, double screenWidth, int surveyCount) {
    double chartTextScaleFactor = screenWidth > 1200 ? 1.0 : screenWidth > 800 ? 0.9 : 0.8; // Scale factor for text
    String bestPlayerName = _bestPlayerOfWeek?.name ?? "No Best Player";
    int bestPlayerVoteCount = _firestoreBestPlayerCounts[bestPlayerName] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Team Player for the Current Month (Facility Votes)',
          style: TextStyle(
              fontSize: 16 * fontSizeFactor * chartTextScaleFactor, fontWeight: FontWeight.bold), // Apply scale factor
        ),
        SizedBox(height: 8 * cardMarginFactor),
        _isLoadingBestPlayer
            ? SizedBox(
            height: 150 * max(0.8, min(1.2, MediaQuery.of(context).size.height / 800)),
            child: const Center(child: CircularProgressIndicator()))
            : _bestPlayerOfWeek != null
            ? _buildRecognitionCardForDashboard(
            _bestPlayerOfWeek, fontSizeFactor, bestPlayerVoteCount, surveyCount) // Pass counts here
            : SizedBox(
            height: 50 * max(0.8, min(1.2, MediaQuery.of(context).size.height / 800)),
            child: const Center(
                child: Text("No data for this period"))),
        SizedBox(height: 8 * cardMarginFactor),
        Expanded(
          child: _isLoadingBestPlayer
              ? const Center(child: SizedBox.shrink())
              : _buildBestPlayerFirestoreChartForDashboard(
              _firestoreBestPlayerCounts, fontSizeFactor, screenWidth, surveyCount), // Pass screenWidth and surveyCount
        ),
      ],
    );
  }

  Widget _buildRecognitionCardForDashboard(
      FacilityStaffModel? bestPlayerOfWeek, double fontSizeFactor, int bestPlayerCount, int surveyCount) {
    if (bestPlayerOfWeek == null) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(Icons.star, color: Colors.orange, size: 30 * fontSizeFactor),
            Text(
              bestPlayerOfWeek.name ?? "Unknown",
              style: TextStyle(fontSize: 14 * fontSizeFactor),
              textAlign: TextAlign.center,
            ),
            Text( // Added votes count display here
              '$bestPlayerCount/$surveyCount votes',
              style: TextStyle(fontSize: 12 * fontSizeFactor, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestPlayerFirestoreChartForDashboard(
      Map<String, int> firestoreBestPlayerCounts, double fontSizeFactor, double screenWidth, int surveyCount) {
    double chartTextScaleFactor = screenWidth > 1200 ? 1.0 : screenWidth > 800 ? 0.9 : 0.8; // Scale factor for text
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (firestoreBestPlayerCounts.isNotEmpty)
          Expanded(
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  labelStyle: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor)), // Apply scale factor
              primaryYAxis: NumericAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
                  isVisible: false),
              series: <CartesianSeries>[
                BarSeries<MapEntry<String, int>, String>(
                  dataSource: firestoreBestPlayerCounts.entries.toList(),
                  xValueMapper: (entry, _) => entry.key,
                  yValueMapper: (entry, _) => entry.value,
                  dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(fontSize: 10 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
                      builder: (data, point, series, pointIndex, seriesIndex) { // Custom builder for data labels
                        return Text('${data.value}/$surveyCount votes'); // Display count and survey count
                      }
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
              height: 80 * max(0.8, min(1.2, MediaQuery.of(context).size.height / 800)),
              child: Center(
                child: Text(
                  "No survey data available for the selected period to display the chart.",
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12 * fontSizeFactor * chartTextScaleFactor), // Apply scale factor
                  textAlign: TextAlign.center,
                ),
              ))
      ],
    );
  }

  Future<void> _loadBestPlayerDataForRange(
      DateTime startDate, DateTime endDate) async {
    if (_currentUserState == null || _currentUserLocation == null) {
      print(
          "Current user state or location is not loaded yet for Best Player Chart.");
      return;
    }

    setState(() {
      _isLoadingBestPlayer = true;
      _firestoreBestPlayerCounts.clear(); // ADDED: Clear counts before fetching new data
    });

    try {
      final bestPlayerCounts = <String, int>{};
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(endDate);
      int surveyCount = 0; // Initialize survey count here
      _totalSurveysCountedForBestPlayer = 0; // Reset survey count in state

      print(
          "Best Player Data Query Range (Function Start): Start Date = $formattedStartDate, End Date = $formattedEndDate"); // Log at function start
      print(
          "Current User State: $_currentUserState, Location: $_currentUserLocation");

      final staffCollection = FirebaseFirestore.instance
          .collection('Staff')
          .where('state', isEqualTo: _currentUserState)
          .where('location', isEqualTo: _currentUserLocation);

      final staffSnapshot = await staffCollection.get();

      print(
          "Number of Staff documents found in current location/state: ${staffSnapshot.docs.length}");

      for (final staffDoc in staffSnapshot.docs) {
        print("Processing Staff Document ID: ${staffDoc.id}");

        final surveyResponsesCollection =
        staffDoc.reference.collection('SurveyResponses');

        final surveyQuerySnapshot = await surveyResponsesCollection
            .where('date', isGreaterThanOrEqualTo: startDate)
            .where('date', isLessThanOrEqualTo: endDate)
            .get();

        print(
            "Number of Survey Responses found for Staff ID ${staffDoc.id} (Field Query): ${surveyQuerySnapshot.docs.length}");

        for (final surveyDoc in surveyQuerySnapshot.docs) {
          surveyCount++; // Increment survey count for each survey document processed
          print("Processing Survey Document ID: ${surveyDoc.id}"); // Log Survey Doc ID

          final surveyDataFull = surveyDoc.data();

          if (surveyDataFull == null) {
            print("Survey data is null for document: ${surveyDoc.id}");
            continue;
          }
          print("Full Survey Data: $surveyDataFull");

          if (surveyDataFull.containsKey('surveyData')) {
            final surveyDataList = surveyDataFull['surveyData'] as List;

            for (var surveyData in surveyDataList) {
              if (surveyData is Map<String, dynamic>) {
                if (surveyData.containsKey(
                    "For the current week, who is the best team player in your facility")) {
                  final bestPlayerFieldValue = surveyData[
                  "For the current week, who is the best team player in your facility"];
                  print("Best Player Field Value (Raw): $bestPlayerFieldValue"); // Log raw field value

                  List<dynamic> bestPlayerList = [];
                  if (bestPlayerFieldValue is String) {
                    try {
                      bestPlayerList = json.decode(bestPlayerFieldValue) as List;
                    } catch (e) {
                      print("Error decoding JSON string (string value case): $e");
                    }
                  } else if (bestPlayerFieldValue is List) {
                    bestPlayerList = bestPlayerFieldValue;
                  }

                  print("Best Player List (Parsed): $bestPlayerList"); // Log parsed list


                  if (bestPlayerList.isNotEmpty) {
                    // Modified part: Only consider the first name in the list as the best team player nomination
                    var firstPlayer = bestPlayerList[0];
                    if (firstPlayer is Map<String, dynamic> &&
                        firstPlayer.containsKey('name')) {
                      final playerName = firstPlayer['name'] as String;
                      print("Extracted Player Name: $playerName"); // Log extracted name
                      bestPlayerCounts[playerName] =
                          (bestPlayerCounts[playerName] ?? 0) + 1;
                      print("Best Player Counts (During Loop): $bestPlayerCounts"); // Log counts during loop
                    }
                  }
                }
              }
            }
          }
        }
      }

      String? bestPlayerName;
      int maxCount = 0;
      bestPlayerCounts.forEach((playerName, count) {
        if (count > maxCount) {
          maxCount = count;
          bestPlayerName = playerName;
        }
      });
      FacilityStaffModel? bestPlayer;
      if (bestPlayerName != null) {
        bestPlayer = FacilityStaffModel(name: bestPlayerName);
      } else {
        bestPlayer = null;
      }

      setState(() {
        _firestoreBestPlayerCounts = bestPlayerCounts;
        _bestPlayerOfWeek = bestPlayer;
        _isLoadingBestPlayer = false;
        _totalSurveysCountedForBestPlayer = surveyCount; // Update survey count in state
      });

      print("Final Best Player Counts: $bestPlayerCounts"); // Log final counts

      final cacheKey =
          '${DateFormat('yyyy-MM-dd').format(startDate)}-${DateFormat('yyyy-MM-dd').format(endDate)}';
      _bestPlayerCache[cacheKey] = {
        'counts': bestPlayerCounts,
        'bestPlayer': bestPlayer,
        'surveyCount': surveyCount // Store survey count in cache
      };
    } catch (e) {
      print('Error loading Best Player Firestore data: $e');
      setState(() {
        _isLoadingBestPlayer = false;
      });
    }
  }

  Widget _buildFacilityClockInCard(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double iconSizeFactor, double otherCardHeightFactor) {
    return Container(
      padding: EdgeInsets.all(15 * cardPaddingFactor * otherCardHeightFactor),
      decoration: BoxDecoration(
        color: Colors.white,
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
                'All Facility Clock-In (Live Feed) - Today',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 16 * fontSizeFactor,
                ),
              ),
              IconButton(onPressed: () {}, icon: Icon(Icons.more_vert, size: 24 * iconSizeFactor)),
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
              stream: _facilityClockInDataStream(),
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
                  return Center(child: Text("No Clock-Ins Today", style: TextStyle(fontSize: 14 * fontSizeFactor, color: Colors.grey)));
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


  Stream<List<Map<String, dynamic>>> _facilityClockInDataStream() {
    final currentUserUUID = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUUID == null || _currentUserState == null || _currentUserLocation == null || _currentUserStaffCategory == null) {
      print("Could not retrieve user info to load facility clock-in data stream.");
      return Stream.value([]); // Return an empty stream if user info is missing
    }

    final currentDateFormatted = DateFormat('dd-MMMM-yyyy').format(DateTime.now());

    // Create a stream builder for the current user's record
    Stream<DocumentSnapshot> currentUserRecordStream = FirebaseFirestore.instance
        .collection('Staff')
        .doc(currentUserUUID)
        .collection('Record')
        .doc(currentDateFormatted)
        .snapshots();

    // Create a stream builder for other staff records in the facility
    Stream<QuerySnapshot> facilityStaffRecordsStream = FirebaseFirestore.instance
        .collection('Staff')
        .where('state', isEqualTo: _currentUserState)
        .where('location', isEqualTo: _currentUserLocation)
        .snapshots();


    return Rx.combineLatest2(
      currentUserRecordStream,
      facilityStaffRecordsStream,
          (currentUserRecordSnapshot, facilityStaffSnapshot) async* {
        List<Map<String, dynamic>> clockInData = [];

        // Process current user's record
        if (currentUserRecordSnapshot.exists) {
          Map<String, dynamic> recordData = currentUserRecordSnapshot.data() as Map<String, dynamic>? ?? {};
          DocumentSnapshot staffDataSnapshot = await FirebaseFirestore.instance.collection('Staff').doc(currentUserUUID).get();
          Map<String, dynamic> staffData = staffDataSnapshot.data() as Map<String, dynamic>? ?? {};

          clockInData.add({
            'fullName': '${staffData['firstName'] ?? 'N/A'} ${staffData['lastName'] ?? 'N/A'}',
            'date': recordData['date'] ?? 'N/A',
            'clockIn': recordData['clockIn'] ?? 'N/A',
            'clockOut': recordData['clockOut'] ?? '--/--', // Include clockOut
          });
        }

        // Process other facility staff records
        for (var staffDoc in facilityStaffSnapshot.docs) {
          if (staffDoc.id == currentUserUUID) continue; // Skip current user as already added

          DocumentSnapshot recordSnapshot = await staffDoc.reference
              .collection('Record')
              .doc(currentDateFormatted)
              .get();

          if (recordSnapshot.exists) {
            Map<String, dynamic> recordData = recordSnapshot.data() as Map<String, dynamic>? ?? {};
            Map<String, dynamic> staffData = staffDoc.data() as Map<String, dynamic>? ?? {};

            clockInData.add({
              'fullName': '${staffData['firstName'] ?? 'N/A'} ${staffData['lastName'] ?? 'N/A'}',
              'date': recordData['date'] ?? 'N/A',
              'clockIn': recordData['clockIn'] ?? 'N/A',
              'clockOut': recordData['clockOut'] ?? '--/--', // Include clockOut
            });
          }
        }
        yield clockInData;
      },
    ).asyncMap((stream) async => await stream.first); // Convert combined stream to single stream of List<Map<String, dynamic>>
  }
}

class LocationRecord {
  LocationRecord({required this.location, required this.attendanceCount});
  final String location;
  final int attendanceCount;
}

class AttendanceData {
  final String day;
  final int onTime;
  final int late;

  AttendanceData(this.day, this.onTime, this.late);
}