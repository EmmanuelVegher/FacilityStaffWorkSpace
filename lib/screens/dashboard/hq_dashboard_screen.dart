// lib/pages/hq_dashboard.dart

// A HIGH-LEVEL HEADQUARTERS DASHBOARD
// ** VERSION 12: APPBAR LOGO & NAVIGATION BUTTON **

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../widgets/drawer3.dart';
import '../attendance_analysis_page/hq_attendance_analysis_page.dart';
import '../leave_request/hq_leave_request_management_page.dart';
import '../timesheet/hq_timesheet_review_page.dart';
// TODO: IMPORT YOUR ATTENDANCE ANALYSIS PAGE HERE
// import '../path/to/your/attendance_analysis_page.dart';


// --- WIDGETS AND MODELS ---
class AnimatedNumberText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final Duration duration;
  final int fractionDigits;

  const AnimatedNumberText(this.value, {
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
      builder: (context, animatedValue, child) =>
          Text(animatedValue.toStringAsFixed(fractionDigits), style: style),
    );
  }
}

class StaffInfo {
  final String id, name, state, location, emailAddress;
  final String? designation, department, phoneNumber, supervisorName;

  StaffInfo({
    required this.id, required this.name, required this.state, required this.location,
    required this.emailAddress, this.designation, this.department,
    this.phoneNumber, this.supervisorName,
  });
}

class StateAttendanceData {
  final String state;
  int totalStaff, present, late, onLeave;
  StateAttendanceData({ required this.state, required this.totalStaff, this.present = 0, this.late = 0, this.onLeave = 0 });
  int get expectedAttendance => totalStaff - onLeave;
  int get absent => expectedAttendance - present;
  double get attendancePercentage => expectedAttendance > 0 ? (present / expectedAttendance) * 100 : 0.0;
}

class NationwideSummary {
  int totalStaff = 0, totalPresent = 0, totalLate = 0, totalOnLeave = 0;
  int get totalAbsent => (totalStaff - totalOnLeave) - totalPresent;
  int get totalOnTime => totalPresent - totalLate;
  double get overallAttendancePercentage => (totalStaff - totalOnLeave) > 0 ? (totalPresent / (totalStaff - totalOnLeave)) * 100 : 0.0;
  double get overallPunctualityPercentage => totalPresent > 0 ? ((totalPresent - totalLate) / totalPresent) * 100 : 0.0;
}

class TimesheetMetrics {
  final int totalExpected, totalSubmitted, pendingApproval, fullyApproved;
  TimesheetMetrics({ this.totalExpected = 0, this.totalSubmitted = 0, this.pendingApproval = 0, this.fullyApproved = 0 });
}

class LeaveRequest {
  final String staffName, leaveType, status;
  final DateTime startDate, endDate;
  LeaveRequest({ required this.staffName, required this.leaveType, required this.startDate, required this.endDate, required this.status });
  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    DateTime parse(dynamic date) => (date is Timestamp) ? date.toDate() : DateTime.tryParse(date ?? '') ?? DateTime.now();
    return LeaveRequest(
      staffName: '${map['firstName'] ?? ''} ${map['lastName'] ?? 'Unknown'}'.trim(),
      leaveType: map['type'] ?? 'N/A',
      startDate: parse(map['startDate']),
      endDate: parse(map['endDate']),
      status: map['status'] ?? 'Pending',
    );
  }
}

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
  Map<String, StaffInfo> _presentStaffMap = {};
  NationwideSummary _nationwideSummary = NationwideSummary();
  List<StateAttendanceData> _attendanceByStateData = [];
  Stream<TimesheetMetrics>? _timesheetStream;
  Stream<List<LeaveRequest>>? _leaveRequestStream;
  late int _selectedTimesheetMonth, _selectedTimesheetYear;

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
    setState(() {
      _timesheetStream = _fetchTimesheetMetrics(state: _selectedState).asStream();
      _leaveRequestStream = _fetchLeaveRequests(state: _selectedState);
    });
  }

  Future<void> _fetchAvailableStates() async {
    try {
      final staffSnapshot = await _firestore.collection('Staff').where('staffCategory', isEqualTo: 'Facility Staff').get();
      final statesSet = staffSnapshot.docs.map((doc) => doc.data()['state'] as String?).whereType<String>().toSet();
      if (mounted) setState(() => _states = ['All States', ...statesSet.toList()..sort()]);
    } catch (e) {
      debugPrint("Error fetching states: $e");
    }
  }

  Future<void> _fetchAndProcessData() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final lateCutoff = DateTime(now.year, now.month, now.day, 8, 0, 1);

    Query<Map<String, dynamic>> staffQuery = _firestore.collection('Staff').where('staffCategory', isEqualTo: 'Facility Staff');
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
          location: doc.data()['location'] ?? 'N/A',
          emailAddress: doc.data()['emailAddress'] ?? 'N/A',
          designation: doc.data()['designation'] ?? 'N/A',
          department: doc.data()['department'] ?? 'N/A',
          phoneNumber: doc.data()['mobile'] ?? 'N/A',
          supervisorName: doc.data()['supervisor'] ?? 'N/A',
        )
    };
    if (staffMap.isEmpty) { _resetData(); return; }

    final recordsSnapshot = await _firestore.collectionGroup('Record').where('timestamp', isGreaterThanOrEqualTo: todayStart).where('timestamp', isLessThan: todayEnd).get();
    Map<String, StateAttendanceData> stateDataMap = {};
    for (var staff in staffMap.values) {
      stateDataMap.putIfAbsent(staff.state, () => StateAttendanceData(state: staff.state, totalStaff: 0));
      stateDataMap[staff.state]!.totalStaff++;
    }

    final presentStaffIds = <String>{};
    final presentStaffMap = <String, StaffInfo>{};
    for (final recordDoc in recordsSnapshot.docs) {
      final staffId = recordDoc.reference.parent.parent!.id;
      final staffInfo = staffMap[staffId];
      if (staffInfo != null && !presentStaffIds.contains(staffId)) {
        presentStaffIds.add(staffId);
        presentStaffMap[staffId] = staffInfo;
        final data = recordDoc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final stateData = stateDataMap[staffInfo.state];
        if (stateData != null) {
          stateData.present++;
          if (timestamp.isAfter(lateCutoff)) stateData.late++;
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
        _presentStaffMap = presentStaffMap;
        _attendanceByStateData = stateDataMap.values.toList()..sort((a, b) => a.state.compareTo(b.state));
        _nationwideSummary = summary;
      });
    }
  }

  Future<TimesheetMetrics> _fetchTimesheetMetrics({required String state}) async {
    Query staffQuery = _firestore.collection('Staff').where('staffCategory', isEqualTo: 'Facility Staff');
    if (state != 'All States') staffQuery = staffQuery.where('state', isEqualTo: state);
    final staffSnapshot = await staffQuery.get();
    if (staffSnapshot.docs.isEmpty) return TimesheetMetrics();
    int expected = staffSnapshot.docs.length, submitted = 0, pending = 0, approved = 0;
    final monthName = DateFormat('MMMM').format(DateTime(_selectedTimesheetYear, _selectedTimesheetMonth));
    final timesheetDocId = '${monthName}_$_selectedTimesheetYear';
    final futures = staffSnapshot.docs.map((staffDoc) => staffDoc.reference.collection('TimeSheets').doc(timesheetDocId).get());
    final results = await Future.wait(futures);
    for (final doc in results) {
      if (doc.exists) {
        submitted++;
        final data = doc.data() as Map<String, dynamic>;
        if ((data['facilitySupervisorSignatureStatus'] ?? 'Pending') == 'Approved' && (data['caritasSupervisorSignatureStatus'] ?? 'Pending') == 'Approved') { approved++; } else { pending++; }
      }
    }
    return TimesheetMetrics(totalExpected: expected, totalSubmitted: submitted, pendingApproval: pending, fullyApproved: approved);
  }

  Stream<List<LeaveRequest>> _fetchLeaveRequests({required String state}) {
    Query query = _firestore.collectionGroup('Leave Request').where('status', isEqualTo: 'Pending');
    if (state != 'All States') query = query.where('staffState', isEqualTo: state);
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) => LeaveRequest.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  void _resetData() {
    if (mounted) setState(() { _nationwideSummary = NationwideSummary(); _attendanceByStateData = []; });
  }

  void _onStateChanged(String? newValue) {
    if (newValue == null || newValue == _selectedState) return;
    setState(() => _selectedState = newValue);
    _initializeDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HQ Monitoring Dashboard', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF5C1A2E),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5C1A2E), Color(0xFF2E0215)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          _isLoading
              ? const Padding(padding: EdgeInsets.only(right: 12.0), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))))
              : IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh Data', onPressed: _initializeDashboard),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Image.asset("assets/image/ccfn_logo.png"), // CCFN Logo
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: drawer3(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SelectionArea(
              child: RefreshIndicator(
                onRefresh: _initializeDashboard,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterBar(),
                      const SizedBox(height: 16),
                      _buildNationwideSummaryCards(),
                      const SizedBox(height: 24),
                      _buildAttendanceByStateChart(),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount;
                          double childAspectRatio;
                          if (constraints.maxWidth > 1600) {
                            crossAxisCount = 3;
                            childAspectRatio = 1.4;
                          } else if (constraints.maxWidth > 1100) {
                            crossAxisCount = 2;
                            childAspectRatio = 1.3;
                          } else if (constraints.maxWidth > 750) {
                            crossAxisCount = 2;
                            childAspectRatio = 1.1;
                          }
                          else {
                            crossAxisCount = 1;
                            childAspectRatio = 1.2;
                          }
                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16, mainAxisSpacing: 16,
                            childAspectRatio: childAspectRatio,
                            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
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
            ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedState, isExpanded: true, icon: const Icon(Icons.public),
          onChanged: _onStateChanged,
          items: _states.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)))).toList(),
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
          crossAxisCount: crossAxisCount, crossAxisSpacing: 16, mainAxisSpacing: 16,
          childAspectRatio: crossAxisCount > 2 ? 1.8 : 2.5,
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildSummaryCard('Total Staff', summary.totalStaff, Icons.people, Colors.blue, onTap: () => _showStaffListDialog('All Staff in Filter (${summary.totalStaff})', _staffMap.values.toList())),
            _buildSummaryCard('Present Today', summary.totalPresent, Icons.how_to_reg, Colors.green, onTap: () => _showStaffListDialog('Present Staff (${summary.totalPresent})', _presentStaffMap.values.toList())),
            _buildSummaryCard('Attendance Rate', summary.overallAttendancePercentage, Icons.pie_chart, Colors.orange, suffix: '%', fractionDigits: 1),
            _buildSummaryCard('Punctuality', summary.overallPunctualityPercentage, Icons.timer, Colors.purple, suffix: '%', fractionDigits: 1),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, num value, IconData icon, Color color, {int fractionDigits = 0, String suffix = '', VoidCallback? onTap}) {
    return Card(
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontWeight: FontWeight.bold)), Icon(icon, color: color)]),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                children: [
                  AnimatedNumberText(value, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: color), fractionDigits: fractionDigits),
                  if (suffix.isNotEmpty) Text(suffix, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStaffListDialog(String title, List<StaffInfo> staffList) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: staffList.isEmpty
                ? const Center(child: Text('No staff to display.'))
                : ListView.builder(
              shrinkWrap: true,
              itemCount: staffList.length,
              itemBuilder: (context, index) {
                final user = staffList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('State: ${user.state}'),
                        Text('Location: ${user.location}'),
                        Text('Designation: ${user.designation ?? 'N/A'}'),
                        Text('Department: ${user.department ?? 'N/A'}'),
                        Text('Email: ${user.emailAddress}'),
                        Text('Phone: ${user.phoneNumber ?? 'N/A'}'),
                        Text('Supervisor: ${user.supervisorName ?? 'N/A'}'),
                      ],
                    ),
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

  Widget _buildAttendanceByStateChart() {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 450,
              child: SfCartesianChart(
                title: ChartTitle(text: 'Attendance by State', textStyle: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                primaryXAxis: CategoryAxis(majorGridLines: const MajorGridLines(width: 0), axisLine: const AxisLine(width: 0.8, color: Colors.black54)),
                primaryYAxis: NumericAxis(title: AxisTitle(text: 'Number of Staff'), majorGridLines: const MajorGridLines(width: 0.5), axisLine: const AxisLine(width: 0), majorTickLines: const MajorTickLines(size: 0)),
                legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                tooltipBehavior: TooltipBehavior(enable: true, format: 'point.series.name: point.y'),
                selectionType: SelectionType.point,
                selectionGesture: ActivationMode.singleTap,
                onSelectionChanged: (SelectionArgs args) { _showStaffListDialog('Users in ${_attendanceByStateData[args.pointIndex].state}', _staffMap.values.where((s) => s.state == _attendanceByStateData[args.pointIndex].state).toList());  },
                series: <CartesianSeries<StateAttendanceData, String>>[
                  ColumnSeries<StateAttendanceData, String>(dataSource: _attendanceByStateData, xValueMapper: (data, _) => data.state, yValueMapper: (data, _) => data.expectedAttendance, name: 'Expected', color: const Color(0xFFE57373), borderRadius: const BorderRadius.all(Radius.circular(8)), selectionBehavior: SelectionBehavior(enable: true), dataLabelSettings: DataLabelSettings(isVisible: true, textStyle: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12))),
                  ColumnSeries<StateAttendanceData, String>(dataSource: _attendanceByStateData, xValueMapper: (data, _) => data.state, yValueMapper: (data, _) => data.present, name: 'Present', color: const Color(0xFFFFB74D), borderRadius: const BorderRadius.all(Radius.circular(8)), selectionBehavior: SelectionBehavior(enable: true),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                        final stateData = data as StateAttendanceData;
                        if (stateData.present <= 0) return const SizedBox.shrink();
                        return Text('${stateData.present} (${stateData.attendancePercentage.toStringAsFixed(0)}%)', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12));
                      },
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HQAttendanceAnalysisPage()),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Navigation to Attendance Analysis Page.")));
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('View Attendance Analysis'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNationwideAttendanceChart() {
    final summary = _nationwideSummary;
    final totalExpected = summary.totalStaff - summary.totalOnLeave;
    final List<ChartData> chartData = [ChartData('On Time', summary.totalOnTime, Colors.green.shade400), ChartData('Late', summary.totalLate, Colors.red.shade400), ChartData('Absent', summary.totalAbsent, Colors.orange.shade400)];
    final List<ChartData> displayData = chartData.where((d) => d.value > 0).toList();
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            Text('Today\'s Attendance Summary', style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Text('Filtered for: $_selectedState', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
            Expanded(
              child: SfCircularChart(
                legend: const Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap, position: LegendPosition.bottom, toggleSeriesVisibility: false),
                tooltipBehavior: TooltipBehavior(enable: true, format: 'point.x: point.y staff', textStyle: const TextStyle(color: Colors.white)),
                series: <CircularSeries<ChartData, String>>[
                  DoughnutSeries<ChartData, String>(
                    dataSource: displayData, xValueMapper: (data, _) => data.category, yValueMapper: (data, _) => data.value, pointColorMapper: (data, _) => data.color,
                    radius: '100%', innerRadius: '65%', explode: true, explodeGesture: ActivationMode.singleTap,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true, labelPosition: ChartDataLabelPosition.inside,
                      builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                        final chartData = data as ChartData;
                        final percentage = totalExpected > 0 ? (chartData.value / totalExpected * 100) : 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(4), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.15), blurRadius: 3, offset: const Offset(1,1)) ]),
                          child: Text('${chartData.category}\n${chartData.value} (${percentage.toStringAsFixed(1)}%)', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
                        );
                      },
                    ),
                  )
                ],
                annotations: <CircularChartAnnotation>[
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("${summary.totalPresent}", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF00695C))),
                        Text("Clocked In\nof $totalExpected Expected", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey.shade700)),
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

  Widget _buildTimesheetStatusCard() {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timesheet Status', style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Text(DateFormat('MMMM yyyy').format(DateTime(_selectedTimesheetYear, _selectedTimesheetMonth)), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            Expanded(
              child: StreamBuilder<TimesheetMetrics>(
                stream: _timesheetStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  if (!snapshot.hasData || snapshot.data!.totalExpected == 0) return const Center(child: Text("No timesheet data for this period."));
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
                      LinearProgressIndicator(value: completionPercentage / 100, minHeight: 10, borderRadius: BorderRadius.circular(5), backgroundColor: Colors.grey.shade300, valueColor: const AlwaysStoppedAnimation<Color>(Colors.green)),
                     // const Spacer(),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TimesheetReviewPageHq())), child: const Text('View Details')),
                      ),
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

  Widget _buildLeaveRequestsCard() {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pending Leave Requests', style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            const Divider(height: 20),
            Expanded(
              child: StreamBuilder<List<LeaveRequest>>(
                stream: _leaveRequestStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  final pendingLeaves = snapshot.data ?? [];
                  if (pendingLeaves.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle_outline, color: Colors.green, size: 40), const SizedBox(height: 8), Text("No pending leave requests.", textAlign: TextAlign.center, style: GoogleFonts.poppins())]));
                  }
                  return ListView.builder(
                    itemCount: pendingLeaves.length,
                    itemBuilder: (context, index) {
                      final leave = pendingLeaves[index];
                      return ListTile(
                        dense: true, contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                        title: Text(leave.staffName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text('${leave.leaveType} (${DateFormat('dd MMM').format(leave.startDate)} - ${DateFormat('dd MMM').format(leave.endDate)})', style: GoogleFonts.poppins(fontSize: 12)),
                      );
                    },
                  );
                },
              ),
            ),
          //  const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaveRequestManagementPage())), child: const Text('View Details')),
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
          Row(children: [Icon(Icons.circle, color: color, size: 10), const SizedBox(width: 8), Text(title, style: GoogleFonts.poppins())]),
          Text(count, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}