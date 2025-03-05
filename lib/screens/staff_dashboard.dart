import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../api/attendance_api.dart';
import '../models/attendance_record.dart';
import '../utils/date_helper.dart';
import '../widgets/drawer.dart';

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
  bool _isLoading = false; // Add loading state

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

  final List<Map<String, dynamic>> _roleAchievements = [
    {'role': 'Doctors', 'achievements': 15, 'kpi': 20, 'badge': 'Top Healer'},
    {'role': 'Pharmacists', 'achievements': 25, 'kpi': 30, 'badge': 'Efficient Dispenser'},
    {'role': 'Lab Technicians', 'achievements': 30, 'kpi': 40, 'badge': 'Fast Processor'},
  ];

  final List<Map<String, dynamic>> _leaderboard = [
    {'name': 'John Doe', 'role': 'Doctor', 'points': 120},
    {'name': 'Jane Smith', 'role': 'Pharmacist', 'points': 110},
    {'name': 'Sam Wilson', 'role': 'Lab Technician', 'points': 105},
  ];

  late Future<void> _initialDataLoadingFuture; // For initial page load

  @override
  void initState() {
    super.initState();
    _initialDataLoadingFuture = _fetchAttendanceData(); // Fetch initial data on page load
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


    if (isMobile) {
      appBarHeightFactor = screenHeight < 600 ? 0.6 : 0.9;
      titleFontSizeFactor = 0.55;
      cardPaddingFactor = 0.45;
      cardMarginFactor = 0.7;
      fontSizeFactor = 0.55;
      iconSizeFactor = 0.55;
      chartHeightFactor = 0.7;
      gridSpacingFactor = 0.1;
      appBarIconSizeFactor = 0.55;
      chartLegendFontSizeFactor = 0.45;
      summaryCardHeightFactor = 2.0;
      otherCardHeightFactor = 1.8; // Reduced height for mobile
      generateAnalyticsButtonPaddingFactor = 0.7;
      chartCardVerticalPaddingFactor = 0.8;
    } else if (isTablet) {
      appBarHeightFactor = 1.1;
      titleFontSizeFactor = 0.55;
      cardPaddingFactor = 0.45;
      cardMarginFactor = 0.7;
      fontSizeFactor = 0.55;
      iconSizeFactor = 0.55;
      chartHeightFactor = 0.7;
      gridSpacingFactor = 0.5;
      appBarIconSizeFactor = 0.55;
      chartLegendFontSizeFactor = 0.45;
      summaryCardHeightFactor = 3.5;
      otherCardHeightFactor = 2.1;
      generateAnalyticsButtonPaddingFactor = 0.7;
      chartCardVerticalPaddingFactor = 0.8;
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
      otherCardHeightFactor = 1.3;
      generateAnalyticsButtonPaddingFactor = 1.0;
      chartCardVerticalPaddingFactor = 1.0;
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
      otherCardHeightFactor = 1.2;
      generateAnalyticsButtonPaddingFactor = 1.0;
      chartCardVerticalPaddingFactor = 1.0;
    }

    return Scaffold(
      drawer: drawer(context,),
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset(
              'assets/image/ccfn_logo.png', // Replace with your logo asset path
              fit: BoxFit.contain,
              height: 40, // Adjust logo height here and factor in responsiveness
            ),
            Padding(
              padding: EdgeInsets.only(left: 10 * cardMarginFactor),
              child: Text(
                'Facility Staff Workflow Platform',
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
            child: buildFilterBarInAppBar(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, appBarHeightFactor, generateAnalyticsButtonPaddingFactor),
          ),
        ),
      ),
      body: Stack( // Wrap SingleChildScrollView with Stack for potential overlay
        children: [
          FutureBuilder<void>(
            future: _initialDataLoadingFuture, // Use initial loading future
            builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // Show loading indicator while initial data is loading
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                // Show error message if initial data loading fails
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                // Data is loaded successfully, build the dashboard UI
                return SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16.0 * cardPaddingFactor),
                    child: Column(
                      children: [
                        _buildSummaryGrid(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, chartHeightFactor, gridSpacingFactor, isMobile, isTablet, isDesktop, isLargeDesktop, chartLegendFontSizeFactor, summaryCardHeightFactor, otherCardHeightFactor),
                        SizedBox(height: 20 * gridSpacingFactor),
                        _buildOtherCardsGrid(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, chartHeightFactor, gridSpacingFactor, isMobile, isTablet, isDesktop, isLargeDesktop, chartLegendFontSizeFactor, summaryCardHeightFactor, otherCardHeightFactor, chartCardVerticalPaddingFactor),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
          Visibility( // Keep Visibility for "Generate Analytics" button loading if needed
            visible: _isLoading,
            child: Stack(
              children: <Widget>[
                ModalBarrier(dismissible: false, color: Colors.grey.withOpacity(0.5)),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      SizedBox(height: 20 * cardMarginFactor),
                      Text(
                        'Please Wait...',
                        style: TextStyle(fontSize: 16 * fontSizeFactor, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double iconSizeFactor, double chartHeightFactor, double gridSpacingFactor, bool isMobile, bool isTablet, bool isDesktop, bool isLargeDesktop, double chartLegendFontSizeFactor, double summaryCardHeightFactor, double otherCardHeightFactor) {
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20 * gridSpacingFactor,
      mainAxisSpacing: 20 * gridSpacingFactor,
      childAspectRatio: 2.5 / summaryCardHeightFactor,
      children: [
        _buildSummaryCard(context, 'Total Hours Worked', '$_totalWorkHours', Icons.timer, Colors.blue, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, summaryCardHeightFactor),
        _buildSummaryCard(context, 'Min Hours Worked', '$_minHoursWorked', Icons.timer_off, Colors.purple, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, summaryCardHeightFactor),
        _buildSummaryCard(context, 'Max Hours Worked', '$_maxHoursWorked', Icons.timer, Colors.purple, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, summaryCardHeightFactor),
        _buildSummaryCard(context, 'Avg Hours Worked', '$_averageHoursWorked', Icons.timelapse, Colors.purple, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, summaryCardHeightFactor),
        _buildSummaryCard(context, 'Holidays Filled', '$_noOfHolidaysFilled', Icons.holiday_village, Colors.purple, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, summaryCardHeightFactor),
        _buildSummaryCard(context, 'Annual Leave Taken', '$_noOfAnnualLeaveTaken', Icons.beach_access, Colors.purple, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, summaryCardHeightFactor),
      ],
    );
  }


  Widget _buildOtherCardsGrid(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double iconSizeFactor, double chartHeightFactor, double gridSpacingFactor, bool isMobile, bool isTablet, bool isDesktop, bool isLargeDesktop, double chartLegendFontSizeFactor, double summaryCardHeightFactor, double otherCardHeightFactor, double chartCardVerticalPaddingFactor) {
    return GridView.count(
      crossAxisCount: isMobile ? 1 : isTablet ? 2 : isDesktop ? 3 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20 * gridSpacingFactor,
      mainAxisSpacing: 20 * gridSpacingFactor,
      childAspectRatio: isMobile ? 1.2 / otherCardHeightFactor :  isTablet ? 1.2 / otherCardHeightFactor : 1.0 / otherCardHeightFactor, // Reduced height for mobile
      children: [
        _buildClockInOutTrendsChartCard(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, chartHeightFactor, chartLegendFontSizeFactor, otherCardHeightFactor, chartCardVerticalPaddingFactor),
        _buildEarlyLateClockInsChartCard(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, chartHeightFactor, chartLegendFontSizeFactor, otherCardHeightFactor, chartCardVerticalPaddingFactor),
        _buildDurationWorkedDistributionChartCard(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, chartHeightFactor, chartLegendFontSizeFactor, otherCardHeightFactor, chartCardVerticalPaddingFactor),
        _buildAttendanceByLocationChartCard(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, chartHeightFactor, chartLegendFontSizeFactor, otherCardHeightFactor, chartCardVerticalPaddingFactor),
        _buildRoleAchievementsCard(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, otherCardHeightFactor),
        _buildLeaderboardCard(context, cardPaddingFactor, cardMarginFactor, fontSizeFactor, iconSizeFactor, otherCardHeightFactor),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color cardColor, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double iconSizeFactor, double summaryCardHeightFactor) {
    return Container(
      padding: EdgeInsets.all(12 * cardPaddingFactor * summaryCardHeightFactor),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * cardMarginFactor),
      ),
      height: 160 * summaryCardHeightFactor,
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
                    fontSize: 12 * fontSizeFactor,
                    overflow: TextOverflow.visible,
                    //softWrap: true,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20 * fontSizeFactor,
              fontWeight: FontWeight.bold,
              color: cardColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFilterBarInAppBar(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double appBarHeightFactor, double generateAnalyticsButtonPaddingFactor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildDepartmentDropdown(cardPaddingFactor, fontSizeFactor),
        SizedBox(width: 8 * cardMarginFactor),
        _buildMonthDropdown(cardPaddingFactor, fontSizeFactor),
        SizedBox(width: 8 * cardMarginFactor),
        _buildYearDropdown(cardPaddingFactor, fontSizeFactor),
        SizedBox(width: 8 * cardMarginFactor),
        _buildDatePickerInAppBar('Start Date', _startDate, (date) {
          setState(() {
            _startDate = date;
          });
        }, cardPaddingFactor, cardMarginFactor, fontSizeFactor),
        SizedBox(width: 8 * cardMarginFactor),
        _buildDatePickerInAppBar('End Date', _endDate, (date) {
          setState(() {
            _endDate = date;
            formattedMonth = DateFormat('MMMM yyyy').format(_endDate);
          });
        }, cardPaddingFactor, cardMarginFactor, fontSizeFactor),
        SizedBox(width: 12 * cardMarginFactor),
        ElevatedButton(
          onPressed: () {
            _fetchAttendanceData(); // Call fetch data on button press
          },
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 15 * cardPaddingFactor * generateAnalyticsButtonPaddingFactor, vertical: 10 * cardPaddingFactor * generateAnalyticsButtonPaddingFactor),
          ),
          child: Text(
            'Generate Analytics',
            style: TextStyle(fontSize: 14 * fontSizeFactor * generateAnalyticsButtonPaddingFactor),
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
        });
      },
      dropdownColor: const Color(0xFF800018),
      style: const TextStyle(color: Colors.white),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
      underline: Container(height: 1, color: Colors.white),
    );
  }

  Widget _buildClockInOutTrendsChartCard(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartHeightFactor, double chartLegendFontSizeFactor, double otherCardHeightFactor, double chartCardVerticalPaddingFactor) {
    final timeFormat = DateFormat('hh:mm a');
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0 * cardPaddingFactor * otherCardHeightFactor, vertical: 16.0 * cardPaddingFactor * otherCardHeightFactor * chartCardVerticalPaddingFactor),
        child: _buildClockInOutTrendsChartContent(fontSizeFactor, cardMarginFactor, timeFormat),
      ),
    );
  }

  Widget _buildClockInOutTrendsChartContent(double fontSizeFactor, double cardMarginFactor, DateFormat timeFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Clock-In and Clock-Out Trends',
          style: TextStyle(
              fontSize: 16 * fontSizeFactor,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8 * cardMarginFactor),
        Expanded(
          child: SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: TextStyle(fontSize: 12 * fontSizeFactor),
                title: AxisTitle(
                  text: 'Days of the Week',
                  textStyle: TextStyle(
                      fontSize: 14 * fontSizeFactor,
                      fontWeight: FontWeight.bold),
                )),
            primaryYAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 12 * fontSizeFactor),
                title: AxisTitle(
                  text: 'Time of the Day',
                  textStyle: TextStyle(
                      fontSize: 14 * fontSizeFactor,
                      fontWeight: FontWeight.bold),
                )),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              format: 'Clock-In: point.yClockIn\nClock-Out: point.yClockOut',
            ),
            series: <CartesianSeries<AttendanceRecord, String>>[
              LineSeries<AttendanceRecord, String>(
                dataSource: _attendanceData,
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
                dataLabelSettings: const DataLabelSettings(isVisible: false),
              ),
              LineSeries<AttendanceRecord, String>(
                dataSource: _attendanceData,
                xValueMapper: (data, _) =>
                    DateFormat('dd-MMM').format(data.date),
                yValueMapper: (data, _) {
                  DateTime clockOut = timeFormat.parse(data.clockOutTime);
                  return double.parse(
                      (clockOut.hour + (clockOut.minute / 60)).toStringAsFixed(1));
                },
                name: 'Clock-Out',
                color: Colors.red,
                markerSettings: const MarkerSettings(isVisible: true),
                dataLabelSettings: const DataLabelSettings(isVisible: false),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildDurationWorkedDistributionChartCard(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartHeightFactor, double chartLegendFontSizeFactor, double otherCardHeightFactor, double chartCardVerticalPaddingFactor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0 * cardPaddingFactor * otherCardHeightFactor, vertical: 16.0 * cardPaddingFactor * otherCardHeightFactor * chartCardVerticalPaddingFactor),
        child: _buildDurationWorkedDistributionChartContent(fontSizeFactor, cardMarginFactor),
      ),
    );
  }

  Widget _buildDurationWorkedDistributionChartContent(double fontSizeFactor, double cardMarginFactor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Distribution of Hours Worked',
          style: TextStyle(
              fontSize: 16 * fontSizeFactor,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8 * cardMarginFactor),
        Expanded(
          child: SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 12 * fontSizeFactor),
                title: AxisTitle(
                  text: 'Duration of Hours Worked (Grouped By Hours)',
                  textStyle: TextStyle(
                      fontSize: 14 * fontSizeFactor,
                      fontWeight: FontWeight.bold),
                )),
            primaryYAxis: NumericAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 12 * fontSizeFactor),
                title: AxisTitle(
                  text: 'Frequency',
                  textStyle: TextStyle(
                      fontSize: 14 * fontSizeFactor,
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

  Widget _buildAttendanceByLocationChartCard(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartHeightFactor, double chartLegendFontSizeFactor, double otherCardHeightFactor, double chartCardVerticalPaddingFactor) {
    List<LocationRecord> locationData1 = _getLocationData(_attendanceData);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0 * cardPaddingFactor * otherCardHeightFactor, vertical: 16.0 * cardPaddingFactor * otherCardHeightFactor * chartCardVerticalPaddingFactor),
        child: _buildAttendanceByLocationChartContent(fontSizeFactor, cardMarginFactor, locationData1),
      ),
    );
  }

  Widget _buildAttendanceByLocationChartContent(double fontSizeFactor, double cardMarginFactor, List<LocationRecord> locationData1) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Attendance by Location',
          style: TextStyle(
              fontSize: 16 * fontSizeFactor,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8 * cardMarginFactor),
        Expanded(
          child: SfCircularChart(
            // plotAreaBorderWidth: 0,
            legend: Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                orientation: LegendItemOrientation.horizontal,
                textStyle: TextStyle(fontSize: 12 * fontSizeFactor)),
            series: <CircularSeries>[
              DoughnutSeries<LocationRecord, String>(
                dataSource: locationData1,
                xValueMapper: (LocationRecord data, _) => data.location,
                yValueMapper: (LocationRecord data, _) => data.attendanceCount,
                dataLabelSettings:  const DataLabelSettings(
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


  Widget _buildEarlyLateClockInsChartCard(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double chartHeightFactor, double chartLegendFontSizeFactor, double otherCardHeightFactor, double chartCardVerticalPaddingFactor) {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0 * cardPaddingFactor * otherCardHeightFactor, vertical: 16.0 * cardPaddingFactor * otherCardHeightFactor * chartCardVerticalPaddingFactor),
        child: _buildEarlyLateClockInsChartContent(fontSizeFactor, cardMarginFactor, chartData),
      ),
    );
  }

  Widget _buildEarlyLateClockInsChartContent(double fontSizeFactor, double cardMarginFactor, List<Map<String, dynamic>> chartData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Did You Clock In Early or Late? (Green = Early, Red = Late, 0 = On Time)',
          style: TextStyle(
              fontSize: 16 * fontSizeFactor,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8 * cardMarginFactor),
        Expanded(
          child: SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: TextStyle(fontSize: 12 * fontSizeFactor),
                title: AxisTitle(
                  text: 'Days Of the Week',
                  textStyle: TextStyle(
                      fontSize: 14 * fontSizeFactor,
                      fontWeight: FontWeight.bold),
                )),
            primaryYAxis: NumericAxis(
              majorGridLines: const MajorGridLines(width: 0),
              axisLine: const AxisLine(width: 0),
              title: AxisTitle(
                text: 'Minutes Early/Late (vs 8:00 AM)',
                textStyle: TextStyle(
                    fontSize: 14 * fontSizeFactor,
                    fontWeight: FontWeight.bold),
              ),
              labelStyle: TextStyle(fontSize: 12 * fontSizeFactor),
              minimum: chartData
                  .map((data) => data['earlyLateMinutes'] as int)
                  .reduce((a, b) => a < b ? a : b) <
                  0
                  ? chartData
                  .map((data) => data['earlyLateMinutes'] as int)
                  .reduce((a, b) => a < b ? a : b)
                  .toDouble()
                  : null,
              maximum: chartData
                  .map((data) => data['earlyLateMinutes'] as int)
                  .reduce((a, b) => a > b ? a : b) >
                  0
                  ? chartData
                  .map((data) => data['earlyLateMinutes'] as int)
                  .reduce((a, b) => a > b ? a : b)
                  .toDouble()
                  : null,
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


  Widget _buildRoleAchievementsCard(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double iconSizeFactor, double otherCardHeightFactor) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: SizedBox(
        height: 350 * otherCardHeightFactor,
        child: Padding(
          padding: EdgeInsets.all(10 * cardPaddingFactor * otherCardHeightFactor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Role-Based Achievements',
                  style: TextStyle(
                      fontSize: 18 * fontSizeFactor,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 10 * cardMarginFactor),
              Expanded(
                child: ListView.builder(
                  itemCount: _roleAchievements.length,
                  itemBuilder: (context, index) {
                    final achievement = _roleAchievements[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12 * cardMarginFactor)),
                      elevation: 4,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Text(
                            achievement['badge'][0],
                            style: TextStyle(fontSize: 14 * fontSizeFactor),
                          ),
                        ),
                        title: Text(
                          achievement['role'],
                          style: TextStyle(fontSize: 16 * fontSizeFactor),
                        ),
                        subtitle: Text(
                          'Achievements: ${achievement['achievements']}/${achievement['kpi']}',
                          style: TextStyle(fontSize: 14 * fontSizeFactor),
                        ),
                        trailing: Text(
                          achievement['badge'],
                          style: TextStyle(fontSize: 14 * fontSizeFactor),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard(BuildContext context, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor, double iconSizeFactor, double otherCardHeightFactor) {
    return Card(
      color: Colors.grey[400],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * cardMarginFactor)),
      child: SizedBox(
        height: 350 * otherCardHeightFactor,
        child: Padding(
          padding: EdgeInsets.all(10 * cardPaddingFactor * otherCardHeightFactor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leaderboard',
                  style: TextStyle(
                      fontSize: 18 * fontSizeFactor,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 10 * cardMarginFactor),
              Expanded(
                child: ListView.builder(
                  itemCount: _leaderboard.length,
                  itemBuilder: (context, index) {
                    final leader = _leaderboard[index];
                    return ListTile(
                      leading: const CircleAvatar(),
                      title: Text(
                        leader['name'],
                        style: TextStyle(fontSize: 16 * fontSizeFactor),
                      ),
                      subtitle: Text(
                        '${leader['role']} - ${leader['points']} pts',
                        style: TextStyle(fontSize: 14 * fontSizeFactor),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildDatePickerInAppBar(String label, DateTime initialDate,
      Function(DateTime) onDateSelected, double cardPaddingFactor, double cardMarginFactor, double fontSizeFactor) {
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
      _isLoading = true; // Set loading to true when button is pressed or initial load
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
        _isLoading = false; // Set loading to false when data fetching is complete
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
      if (record.durationWorked != "Annual Leave" && record.durationWorked != "Holiday") {
        totalHours += DateHelper.calculateHoursWorked(record.clockInTime, record.clockOutTime);
      }
    }
    return totalHours.round();
  }

  int _calculateMinHoursWorked(List<AttendanceRecord> filteredData) {
    if (filteredData.isEmpty) return 0;
    double minHours = double.infinity;
    for (var record in filteredData) {
      if (record.durationWorked != "Annual Leave" && record.durationWorked != "Holiday") {
        double hours = DateHelper.calculateHoursWorked(record.clockInTime, record.clockOutTime);
        minHours = minHours < hours ? minHours : hours;
      }
    }
    return minHours == double.infinity ? 0 : minHours.round();
  }

  int _calculateMaxHoursWorked(List<AttendanceRecord> filteredData) {
    if (filteredData.isEmpty) return 0;
    double maxHours = 0;
    for (var record in filteredData) {
      if (record.durationWorked != "Annual Leave" && record.durationWorked != "Holiday") {
        double hours = DateHelper.calculateHoursWorked(record.clockInTime, record.clockOutTime);
        maxHours = maxHours > hours ? maxHours : hours;
      }
    }
    return maxHours.round();
  }

  int _calculateAverageHoursWorked(List<AttendanceRecord> filteredData) {
    if (filteredData.isEmpty) return 0;
    double totalHours = 0;
    int validAttendanceCount = 0; // Count only valid attendance records for average calculation
    for (var record in filteredData) {
      if (record.durationWorked != "Annual Leave" && record.durationWorked != "Holiday") {
        totalHours += DateHelper.calculateHoursWorked(record.clockInTime, record.clockOutTime);
        validAttendanceCount++;
      }
    }
    return validAttendanceCount == 0 ? 0 : (totalHours / validAttendanceCount).round();
  }


  int _calculateNoOfHolidaysFilled(List<AttendanceRecord> filteredData) {
    return filteredData.where((record) => record.durationWorked == "Holiday").length;
  }

  int _calculateNoOfAnnualLeaveTaken(List<AttendanceRecord> filteredData) {
    return filteredData.where((record) => record.durationWorked == "Annual Leave").length;
  }


  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<AttendanceRecord>> getRecordsForDateRangeForChart(
      DateTime startDate, DateTime endDate) async {
    final records = <AttendanceRecord>[];

    try {
      for (var date = startDate;
      date.isBefore(endDate.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))) {
        final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);

        final recordSnapshot = await _firestore
            .collection('Staff')
            .doc("0A0ySoctMZcmJVh5OaJ5uUTcn073")
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