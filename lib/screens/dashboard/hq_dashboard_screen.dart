// A HIGH-LEVEL HEADQUARTERS DASHBOARD
// REWRITTEN TO USE LIVE, SCALABLE FIRESTORE QUERIES AND ADVANCED WIDGETS
// ** VERSION 6: LARGER & WIDER NATIONWIDE ATTENDANCE CHART **

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../widgets/drawer3.dart'; // Assuming a generic app drawer

// --- WIDGETS AND MODELS (ADAPTED FROM STATE-LEVEL DASHBOARD) ---

class AnimatedNumberText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final Duration duration;
  final int fractionDigits;

  const AnimatedNumberText(
      this.value, {
        super.key,
        this.style,
        this.duration = const Duration(milliseconds: 800),
        this.fractionDigits = 0,
      });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      builder: (context, animatedValue, child) {
        final textValue = animatedValue.toStringAsFixed(fractionDigits);
        return Text(textValue, style: style);
      },
    );
  }
}

class StaffInfo {
  final String id;
  final String name;
  final String state;
  final String location;
  final String emailAddress;

  StaffInfo({
    required this.id,
    required this.name,
    required this.state,
    required this.location,
    required this.emailAddress,
  });
}

class StateAttendanceData {
  final String state;
  int totalStaff;
  int present;
  int late;
  int onLeave;

  StateAttendanceData({
    required this.state,
    required this.totalStaff,
    this.present = 0,
    this.late = 0,
    this.onLeave = 0,
  });

  int get expectedAttendance => totalStaff - onLeave;
  int get absent => expectedAttendance - present;
  double get attendancePercentage => expectedAttendance > 0 ? (present / expectedAttendance) * 100 : 0.0;
}

class NationwideSummary {
  int totalStaff = 0;
  int totalPresent = 0;
  int totalLate = 0;
  int totalOnLeave = 0;
  int get totalAbsent => (totalStaff - totalOnLeave) - totalPresent;
  int get totalOnTime => totalPresent - totalLate;

  double get overallAttendancePercentage => (totalStaff - totalOnLeave) > 0 ? (totalPresent / (totalStaff - totalOnLeave)) * 100 : 0.0;
  double get overallPunctualityPercentage => totalPresent > 0 ? ((totalPresent - totalLate) / totalPresent) * 100 : 0.0;
}

// NEW: Model for Timesheet metrics, from state-level dashboard
class TimesheetMetrics {
  final int totalExpected;
  final int totalSubmitted;
  final int pendingApproval;
  final int fullyApproved;
  TimesheetMetrics({
    this.totalExpected = 0,
    this.totalSubmitted = 0,
    this.pendingApproval = 0,
    this.fullyApproved = 0,
  });
}

// NEW: Model for Leave Requests, from state-level dashboard
class LeaveRequest {
  final String staffName;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  LeaveRequest({
    required this.staffName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    DateTime _parseFirestoreDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return LeaveRequest(
      staffName: '${map['firstName'] ?? ''} ${map['lastName'] ?? 'Unknown'}'.trim(),
      leaveType: map['type'] ?? 'N/A',
      startDate: _parseFirestoreDate(map['startDate']),
      endDate: _parseFirestoreDate(map['endDate']),
      status: map['status'] ?? 'Pending',
    );
  }
}

// NEW: Model for chart data points
class ChartData {
  final String category;
  final num value;
  final Color? color;
  ChartData(this.category, this.value, [this.color]);
}

// --- MAIN DASHBOARD WIDGET ---

class HQDashboardScreen extends StatefulWidget {
  const HQDashboardScreen({super.key});

  @override
  HQDashboardScreenState createState() => HQDashboardScreenState();
}

class HQDashboardScreenState extends State<HQDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _selectedState = 'All States';
  List<String> _states = ['All States'];

  Map<String, StaffInfo> _staffMap = {};
  NationwideSummary _nationwideSummary = NationwideSummary();
  List<StateAttendanceData> _attendanceByStateData = [];

  // --- NEW: Streams for async data loading ---
  Stream<TimesheetMetrics>? _timesheetStream;
  Stream<List<LeaveRequest>>? _leaveRequestStream;
  late int _selectedTimesheetMonth;
  late int _selectedTimesheetYear;


  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedTimesheetMonth = now.month;
    _selectedTimesheetYear = now.year;
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    setState(() => _isLoading = true);
    await _fetchAvailableStates();
    await _fetchAndProcessData();
    _setupLiveStreams();
    if (mounted) setState(() => _isLoading = false);
  }

  void _setupLiveStreams() {
    // These streams will now react to the _selectedState filter
    setState(() {
      _timesheetStream = _fetchTimesheetMetrics(state: _selectedState).asStream();
      _leaveRequestStream = _fetchLeaveRequests(state: _selectedState);
    });
  }


  Future<void> _fetchAvailableStates() async {
    try {
      final staffSnapshot = await _firestore
          .collection('Staff')
          .where('staffCategory', isEqualTo: 'Facility Staff')
          .get();

      final statesSet = staffSnapshot.docs
          .map((doc) => doc.data()['state'] as String?)
          .whereType<String>()
          .toSet();

      if (mounted) {
        setState(() {
          _states = ['All States', ...statesSet.toList()..sort()];
        });
      }
    } catch (e) {
      debugPrint("Error fetching states: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching states: $e")));
    }
  }

  Future<void> _fetchAndProcessData() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final lateCutoff = DateTime(now.year, now.month, now.day, 8, 0, 1);

    Query<Map<String, dynamic>> staffQuery = _firestore.collection('Staff')
        .where('staffCategory', isEqualTo: 'Facility Staff');

    if (_selectedState != 'All States') {
      staffQuery = staffQuery.where('state', isEqualTo: _selectedState);
    }

    final staffSnapshot = await staffQuery.get();
    final staffMap = {
      for (var doc in staffSnapshot.docs)
        doc.id: StaffInfo(
          id: doc.id,
          name: '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'.trim(),
          state: doc.data()['state'] ?? 'Unknown',
          location: doc.data()['location'] ?? doc.data()['state'] ?? 'N/A',
          emailAddress: doc.data()['emailAddress'] ?? 'No Email Provided',
        )
    };

    if (staffMap.isEmpty) {
      _resetData();
      return;
    }

    final recordsSnapshot = await _firestore.collectionGroup('Record')
        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
        .where('timestamp', isLessThan: todayEnd)
        .get();

    Map<String, StateAttendanceData> stateDataMap = {};
    for (var staff in staffMap.values) {
      stateDataMap.putIfAbsent(staff.state, () => StateAttendanceData(state: staff.state, totalStaff: 0));
      stateDataMap[staff.state]!.totalStaff++;
    }

    final presentStaffIds = <String>{};
    for (final recordDoc in recordsSnapshot.docs) {
      final staffId = recordDoc.reference.parent.parent!.id;
      final staffInfo = staffMap[staffId];

      if (staffInfo != null && !presentStaffIds.contains(staffId)) {
        presentStaffIds.add(staffId);
        final data = recordDoc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final stateData = stateDataMap[staffInfo.state];
        if (stateData != null) {
          stateData.present++;
          if (timestamp.isAfter(lateCutoff)) {
            stateData.late++;
          }
        }
      }
    }

    final summary = NationwideSummary();
    for (var data in stateDataMap.values) {
      summary.totalStaff += data.totalStaff;
      summary.totalPresent += data.present;
      summary.totalLate += data.late;
      summary.totalOnLeave += data.onLeave;
    }

    if (mounted) {
      setState(() {
        _staffMap = staffMap;
        _attendanceByStateData = stateDataMap.values.toList()..sort((a, b) => a.state.compareTo(b.state));
        _nationwideSummary = summary;
      });
    }
  }

  // --- NEW: Data fetching logic for Timesheets ---
  Future<TimesheetMetrics> _fetchTimesheetMetrics({required String state}) async {
    Query staffQuery = _firestore.collection('Staff').where('staffCategory', isEqualTo: 'Facility Staff');

    if (state != 'All States') {
      staffQuery = staffQuery.where('state', isEqualTo: state);
    }

    final staffSnapshot = await staffQuery.get();
    if (staffSnapshot.docs.isEmpty) return TimesheetMetrics();

    int expected = staffSnapshot.docs.length;
    int submitted = 0;
    int pending = 0;
    int approved = 0;

    final monthName = DateFormat('MMMM').format(DateTime(_selectedTimesheetYear, _selectedTimesheetMonth));
    final timesheetDocId = '${monthName}_$_selectedTimesheetYear';

    final futures = staffSnapshot.docs.map((staffDoc) =>
        staffDoc.reference.collection('TimeSheets').doc(timesheetDocId).get());
    final results = await Future.wait(futures);

    for (final doc in results) {
      if (doc.exists) {
        submitted++;
        final data = doc.data() as Map<String, dynamic>;
        final facilityStatus = data['facilitySupervisorSignatureStatus'] ?? 'Pending';
        final caritasStatus = data['caritasSupervisorSignatureStatus'] ?? 'Pending';
        if (facilityStatus == 'Approved' && caritasStatus == 'Approved') {
          approved++;
        } else {
          pending++;
        }
      }
    }
    return TimesheetMetrics(totalExpected: expected, totalSubmitted: submitted, pendingApproval: pending, fullyApproved: approved);
  }

  // --- NEW: Data fetching logic for Leave Requests ---
  Stream<List<LeaveRequest>> _fetchLeaveRequests({required String state}) {
    Query query = _firestore.collectionGroup('Leave Request')
        .where('status', isEqualTo: 'Pending');

    if (state != 'All States') {
      query = query.where('staffState', isEqualTo: state);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => LeaveRequest.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  void _resetData() {
    if (mounted) {
      setState(() {
        _nationwideSummary = NationwideSummary();
        _attendanceByStateData = [];
      });
    }
  }

  void _onStateChanged(String? newValue) {
    if (newValue == null || newValue == _selectedState) return;
    setState(() {
      _selectedState = newValue;
      // Re-run the full initialization process to update all data
      _initializeDashboard();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer3(context),
      appBar: AppBar(
        title: const Text('HQ Monitoring Dashboard'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _initializeDashboard,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterBar(),
              const SizedBox(height: 16),
              _buildNationwideSummaryCards(),
              const SizedBox(height: 20),
              _buildAttendanceByStateChart(),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth > 1200 ? 3 : (constraints.maxWidth > 800 ? 2 : 1);
                  // --- MODIFIED: Adjusting aspect ratio to make cards taller ("bigger") ---
                  double childAspectRatio = crossAxisCount == 3 ? 1.4 : (crossAxisCount == 2 ? 1.5 : 1.2);

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildNationwideAttendanceChart(),
                      _buildTimesheetStatusCard(),
                      _buildLeaveRequestsCard(),
                    ],
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedState,
          isExpanded: true,
          icon: const Icon(Icons.public),
          onChanged: _onStateChanged,
          items: _states.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNationwideSummaryCards() {
    final summary = _nationwideSummary;
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 1000 ? 4 : (constraints.maxWidth < 500 ? 1 : 2);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: crossAxisCount > 2 ? 1.8 : 2.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildSummaryCard('Total Staff', summary.totalStaff, Icons.people, Colors.blue),
            _buildSummaryCard('Present Today', summary.totalPresent, Icons.how_to_reg, Colors.green),
            _buildSummaryCard('Attendance Rate', summary.overallAttendancePercentage, Icons.pie_chart, Colors.orange, suffix: '%', fractionDigits: 1),
            _buildSummaryCard('Punctuality', summary.overallPunctualityPercentage, Icons.timer, Colors.purple, suffix: '%', fractionDigits: 1),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, num value, IconData icon, Color color, {int fractionDigits = 0, String suffix = ''}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                Icon(icon, color: color),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedNumberText(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color), fractionDigits: fractionDigits),
                if (suffix.isNotEmpty) Text(suffix, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceByStateChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 350,
          child: SfCartesianChart(
            title: ChartTitle(
                text: 'Attendance by State',
                textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
            ),
            primaryXAxis: CategoryAxis(
              majorGridLines: const MajorGridLines(width: 0),
              axisLine: const AxisLine(width: 0.8, color: Colors.black54),
            ),
            primaryYAxis: NumericAxis(
              title: AxisTitle(text: 'Number of Staff'),
              majorGridLines: const MajorGridLines(width: 0.5),
              axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              overflowMode: LegendItemOverflowMode.wrap,
            ),
            tooltipBehavior: TooltipBehavior(enable: true, format: 'point.series.name: point.y'),
            selectionType: SelectionType.point,
            selectionGesture: ActivationMode.singleTap,
            onSelectionChanged: (SelectionArgs args) {
              if (args.pointIndex != null) {
                final String tappedState = _attendanceByStateData[args.pointIndex!].state;
                _showUsersInStateDialog(tappedState);
              }
            },
            series: <CartesianSeries<StateAttendanceData, String>>[
              ColumnSeries<StateAttendanceData, String>(
                dataSource: _attendanceByStateData,
                xValueMapper: (data, _) => data.state,
                yValueMapper: (data, _) => data.expectedAttendance,
                name: 'Total Expected Attendance',
                color: const Color(0xFFE57373),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                spacing: 0.2,
                selectionBehavior: SelectionBehavior(enable: true),
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              ColumnSeries<StateAttendanceData, String>(
                dataSource: _attendanceByStateData,
                xValueMapper: (data, _) => data.state,
                yValueMapper: (data, _) => data.present,
                name: 'Total Present Today',
                color: const Color(0xFFFFB74D),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                spacing: 0.2,
                selectionBehavior: SelectionBehavior(enable: true),
                dataLabelSettings: DataLabelSettings(
                  isVisible: true,
                  builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                    final stateData = data as StateAttendanceData;
                    final percentage = stateData.attendancePercentage;
                    if (stateData.present <= 0) return const SizedBox.shrink();
                    final labelText = '${stateData.present} (${percentage.toStringAsFixed(0)}%)';
                    return Text(labelText, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUsersInStateDialog(String state) {
    final List<StaffInfo> usersInState =
    _staffMap.values.where((user) => user.state == state).toList();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Users in $state'),
          content: SizedBox(
            width: double.maxFinite,
            child: usersInState.isEmpty
                ? const Center(child: Text('No user data available for this state.'))
                : ListView.builder(
              shrinkWrap: true,
              itemCount: usersInState.length,
              itemBuilder: (context, index) {
                final user = usersInState[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Location: ${user.location}'),
                        Text('Email: ${user.emailAddress}'),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // --- REWRITTEN: Doughnut Chart (BIGGER, WIDER, & MORE INTERACTIVE) ---
  Widget _buildNationwideAttendanceChart() {
    final summary = _nationwideSummary;
    final totalExpected = summary.totalStaff - summary.totalOnLeave;

    final List<ChartData> chartData = [
      ChartData('On Time', summary.totalOnTime, Colors.green.shade400),
      ChartData('Late', summary.totalLate, Colors.red.shade400),
      ChartData('Absent', summary.totalAbsent, Colors.orange.shade400),
    ];

    final List<ChartData> displayData = chartData.where((d) => d.value > 0).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // Adjust padding for legend
        child: Column(
          children: [
            Text(
              'Today\'s Attendance Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Filtered for: $_selectedState',
              style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
            Expanded(
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  overflowMode: LegendItemOverflowMode.wrap,
                  position: LegendPosition.bottom,
                  toggleSeriesVisibility: true,
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'point.x: point.y staff',
                  textStyle: const TextStyle(color: Colors.white),
                ),
                series: <CircularSeries<ChartData, String>>[
                  DoughnutSeries<ChartData, String>(
                    dataSource: displayData,
                    xValueMapper: (data, _) => data.category,
                    yValueMapper: (data, _) => data.value,
                    pointColorMapper: (data, _) => data.color,
                    // --- MODIFIED: Making the chart bigger and the ring wider ---
                    radius: '95%',       // Use more of the available space for the chart radius.
                    innerRadius: '60%',   // Make the doughnut ring itself thicker.
                    explode: true,
                    explodeGesture: ActivationMode.singleTap,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                        final chartData = data as ChartData;
                        final percentage = totalExpected > 0 ? (chartData.value / totalExpected * 100) : 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.15), blurRadius: 3, offset: const Offset(1,1)) ]
                          ),
                          child: Text(
                            '${chartData.value}\n(${percentage.toStringAsFixed(1)}%)',
                            textAlign: TextAlign.center,
                            style: const TextStyle( color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        );
                      },
                      connectorLineSettings: const ConnectorLineSettings( type: ConnectorType.curve, length: '20%'),
                    ),
                  )
                ],
                annotations: <CircularChartAnnotation>[
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${summary.totalPresent}",
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
                        ),
                        Text(
                          "Clocked In\nof $totalExpected Expected",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
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

  // --- REWRITTEN: Timesheet Card using StreamBuilder ---
  Widget _buildTimesheetStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timesheet Status (Nationwide)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                DateFormat('MMMM yyyy').format(DateTime(_selectedTimesheetYear, _selectedTimesheetMonth)),
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)
            ),
            Expanded(
              child: StreamBuilder<TimesheetMetrics>(
                stream: _timesheetStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData || snapshot.data!.totalExpected == 0) {
                    return const Center(child: Text("No timesheet data for this period."));
                  }

                  final metrics = snapshot.data!;
                  final pendingSubmission = metrics.totalExpected - metrics.totalSubmitted;
                  final completionPercentage = metrics.totalExpected > 0 ? (metrics.fullyApproved / metrics.totalExpected) * 100 : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildStatusRow('Expected', '${metrics.totalExpected} Staff', Colors.blue),
                      _buildStatusRow('Pending Submission', '$pendingSubmission Staff', Colors.orange),
                      _buildStatusRow('Pending Approval', '${metrics.pendingApproval} Timesheets', Colors.red),
                      const Spacer(),
                      Text('Overall Approval: ${completionPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: completionPercentage / 100,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: TextButton(onPressed: () { /* TODO: Navigate to details page */ }, child: const Text('View Details')),
                      )
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REWRITTEN: Leave Requests Card using StreamBuilder ---
  Widget _buildLeaveRequestsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pending Leave Requests', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Expanded(
              child: StreamBuilder<List<LeaveRequest>>(
                stream: _leaveRequestStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  }
                  final pendingLeaves = snapshot.data ?? [];
                  if (pendingLeaves.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green, size: 40),
                          SizedBox(height: 8),
                          Text("No pending leave requests.", textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: pendingLeaves.length,
                    itemBuilder: (context, index) {
                      final leave = pendingLeaves[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                        title: Text(leave.staffName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                            '${leave.leaveType} (${DateFormat('dd MMM').format(leave.startDate)} - ${DateFormat('dd MMM').format(leave.endDate)})',
                            style: const TextStyle(fontSize: 12)
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String title, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Icon(Icons.circle, color: color, size: 10), const SizedBox(width: 8), Text(title)]),
          Text(count, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}