// lib/pages/state_dashboard.dart

// STATE-LEVEL MONITORING DASHBOARD
// ** VERSION 12: FINAL POLISH & ENHANCEMENTS **

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart' as gauges;

import '../../widgets/drawer2.dart';
import '../attendance_analysis_page/attendance_analysis_page.dart';
import '../leave_request/state_leave_request_page.dart';
import '../timesheet/timesheet_management_dashboard.dart';

// --- ENUMS & MODELS ---

enum AttendanceFilter { all, onTime, late }

class StaffInfo {
  final String id, name, gender, location;
  final String? imageUrl, designation, department, phoneNumber, supervisorName;

  StaffInfo({
    required this.id, required this.name, required this.gender,
    required this.location, this.imageUrl, this.designation, this.department,
    this.phoneNumber, this.supervisorName,
  });
}

class AttendanceRecord {
  final String staffId, staffName, staffLocation, clockInTime;
  final DateTime timestamp;
  final bool isLate;

  AttendanceRecord({
    required this.staffId, required this.staffName, required this.staffLocation,
    required this.timestamp, required this.clockInTime, this.isLate = false,
  });
}

class DashboardData {
  final List<StaffInfo> staffList, yetToClockIn;
  final List<AttendanceRecord> attendanceRecords;
  final List<LeaveRequest> pendingLeaves;

  DashboardData({
    required this.staffList, required this.attendanceRecords,
    required this.yetToClockIn, required this.pendingLeaves,
  });
}

class TimesheetMetrics {
  final int totalExpected, totalSubmitted, pendingApproval, fullyApproved;
  TimesheetMetrics({this.totalExpected=0, this.totalSubmitted=0, this.pendingApproval=0, this.fullyApproved=0});
}

class LeaveRequest {
  final String staffName, leaveType, status;
  final DateTime startDate, endDate;

  LeaveRequest({required this.staffName, required this.leaveType, required this.startDate, required this.endDate, required this.status});

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

// --- MAIN WIDGET ---

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StreamController<String> _timeStreamController = StreamController.broadcast();

  String? _currentUserState;
  Stream<DashboardData>? _dashboardStream;
  final _filterController = BehaviorSubject<AttendanceFilter>.seeded(AttendanceFilter.all);
  final _dateRangeController = BehaviorSubject<DateTimeRange>();
  late int _selectedTimesheetMonth, _selectedTimesheetYear;
  final StreamController<TimesheetMetrics> _timesheetStreamController = StreamController.broadcast();
  bool _isTimesheetLoading = false;
  late Timer _timer;
  final String _liveTime = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedTimesheetMonth = now.month;
    _selectedTimesheetYear = now.year;
    _dateRangeController.add(DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day)));
    _initializeStreams();

    // MODIFIED: This timer now sends data to the stream instead of calling setState.
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted && !_timeStreamController.isClosed) {
        _timeStreamController.add(DateFormat('hh:mm:ss a').format(DateTime.now()));
      }
    });
  }

  @override
  void dispose() {
    _filterController.close();
    _dateRangeController.close();
    _timesheetStreamController.close();
    _timeStreamController.close();
    _timer.cancel();
    super.dispose();
  }

  DateTime _parseTime(String timeString) {
    try {
      final now = DateTime.now();
      return DateFormat("hh:mm a").parse(timeString).copyWith(year: now.year, month: now.month, day: now.day);
    } catch (e) {
      return DateTime.now().add(const Duration(days: 1));
    }
  }

  void _initializeStreams() async {
    try {
      await _loadCurrentUserBioData();
      if (_currentUserState != null) {
        _dashboardStream = Rx.combineLatest2(
            _dateRangeController.stream,
            _filterController.stream,
                (dateRange, attendanceFilter) => {'range': dateRange, 'filter': attendanceFilter}
        ).switchMap((filters) {
          final dateRange = filters['range'] as DateTimeRange;
          final attendanceFilter = filters['filter'] as AttendanceFilter;
          return _fetchDashboardData(dateRange, attendanceFilter);
        });
        _loadTimesheetMetrics();
      }
      if (mounted) setState(() {});
    } catch (e, s) {
      debugPrint("FATAL: Error during stream initialization: $e\n$s");
    }
  }

  Future<void> _loadCurrentUserBioData() async {
    try {
      final userUUID = _auth.currentUser?.uid;
      if (userUUID == null) return;
      final doc = await _firestore.collection("Staff").doc(userUUID).get();
      if (doc.exists && mounted) {
        _currentUserState = doc.data()?['state'] as String?;
      }
    } catch (e) {
      debugPrint("Error loading user bio data: $e");
    }
  }

  Stream<DashboardData> _fetchDashboardData(DateTimeRange dateRange, AttendanceFilter filter) {
    if (_currentUserState == null) return Stream.value(DashboardData(staffList: [], attendanceRecords: [], yetToClockIn: [], pendingLeaves: []));

    final staffQuery = _firestore.collection('Staff').where('state', isEqualTo: _currentUserState).where('staffCategory', isEqualTo: 'Facility Staff');
    final leaveRequestStream = _firestore.collectionGroup('Leave Request').where('staffState', isEqualTo: _currentUserState).where('status', isEqualTo: 'Pending').snapshots().map((snapshot) => snapshot.docs.map((doc) => LeaveRequest.fromMap(doc.data())).toList());

    return Rx.combineLatest2(staffQuery.snapshots(), leaveRequestStream, (staff, leaves) => {'staff': staff, 'leaves': leaves})
        .switchMap((data) {
      final staffSnapshot = data['staff'] as QuerySnapshot<Map<String, dynamic>>;
      final pendingLeaves = data['leaves'] as List<LeaveRequest>;

      final staffList = staffSnapshot.docs.map((doc) {
        final data = doc.data();
        return StaffInfo(
          id: doc.id,
          name: '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          gender: data['gender'] ?? 'Unknown',
          location: data['location'] ?? 'N/A',
          imageUrl: data['imageUrl'] as String?,
          designation: data['designation'] as String?,
          department: data['department'] as String?,
          phoneNumber: data['mobile'] as String?,
          supervisorName: data['supervisor'] as String?,
        );
      }).toList();

      if (staffList.isEmpty) return Stream.value(DashboardData(staffList: [], attendanceRecords: [], yetToClockIn: [], pendingLeaves: []));

      final staffMap = {for (var staff in staffList) staff.id: staff};
      final lateCutoff = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day, 8, 0, 1);

      Query recordsQuery = _firestore.collectionGroup('Record').where('timestamp', isGreaterThanOrEqualTo: dateRange.start).where('timestamp', isLessThan: dateRange.end.add(const Duration(days: 1)));

      return recordsQuery.snapshots().map((recordsSnapshot) {
        final allRecordsForPeriod = recordsSnapshot.docs.map((doc) {
          final staffInfo = staffMap[doc.reference.parent.parent!.id];
          if (staffInfo == null) return null;
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          final clockInTime = data['clockIn'] ?? 'N/A';
          return AttendanceRecord(staffId: staffInfo.id, staffName: staffInfo.name, staffLocation: staffInfo.location, timestamp: timestamp, clockInTime: clockInTime, isLate: _parseTime(clockInTime).isAfter(lateCutoff));
        }).whereType<AttendanceRecord>().toList();

        final filteredRecords = (filter == AttendanceFilter.all) ? allRecordsForPeriod : allRecordsForPeriod.where((r) => filter == AttendanceFilter.onTime ? !r.isLate : r.isLate).toList();
        filteredRecords.sort((a, b) => _parseTime(a.clockInTime).compareTo(_parseTime(b.clockInTime)));

        final todaysRecords = allRecordsForPeriod.where((r) => DateFormat('yyyy-MM-dd').format(r.timestamp) == DateFormat('yyyy-MM-dd').format(DateTime.now()));
        final clockedInIds = todaysRecords.map((r) => r.staffId).toSet();
        final yetToClockIn = staffList.where((staff) => !clockedInIds.contains(staff.id)).toList();

        return DashboardData(staffList: staffList, attendanceRecords: filteredRecords, yetToClockIn: yetToClockIn, pendingLeaves: pendingLeaves);
      });
    });
  }

  void _loadTimesheetMetrics() async {
    if (_currentUserState == null) return;
    if (mounted) setState(() => _isTimesheetLoading = true);
    try {
      final metrics = await _fetchTimesheetMetrics(state: _currentUserState!, year: _selectedTimesheetYear, month: _selectedTimesheetMonth);
      if (!_timesheetStreamController.isClosed) _timesheetStreamController.add(metrics);
    } catch (e, s) {
      debugPrint("Error loading timesheet metrics: $e\n$s");
      if (!_timesheetStreamController.isClosed) _timesheetStreamController.addError(e);
    } finally {
      if (mounted) setState(() => _isTimesheetLoading = false);
    }
  }

  Future<TimesheetMetrics> _fetchTimesheetMetrics({required String state, required int year, required int month}) async {
    final facilityStaffQuery = _firestore.collection('Staff').where('state', isEqualTo: state).where('staffCategory', isEqualTo: 'Facility Staff');
    final staffSnapshot = await facilityStaffQuery.get();
    if (staffSnapshot.docs.isEmpty) return TimesheetMetrics();
    int expected = staffSnapshot.docs.length, submitted = 0, pending = 0, approved = 0;
    final monthName = DateFormat('MMMM').format(DateTime(year, month));
    final timesheetDocId = '${monthName}_$year';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer2(context),
      appBar: AppBar(
        title: Text('$_currentUserState Monitoring Dashboard', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF5C1A2E), // Corporate Maroon
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            // MODIFIED: Wrap the clock Text in a StreamBuilder to prevent global rebuilds.
            child: Center(
              child: StreamBuilder<String>(
                stream: _timeStreamController.stream,
                initialData: DateFormat('hh:mm:ss a').format(DateTime.now()), // Show initial time
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? '',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Image.asset("assets/image/ccfn_logo.png"),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SelectionArea(
        child: Column(
          children: [
            _buildTopFilterBar(),
            Expanded(
              child: StreamBuilder<DashboardData>(
                stream: _dashboardStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) {
                    debugPrint("Dashboard Stream Error: ${snapshot.error}\n${snapshot.stackTrace}");
                    return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("An error occurred: ${snapshot.error}", style: GoogleFonts.poppins(color: Colors.red))));
                  }
                  if (!snapshot.hasData || snapshot.data!.staffList.isEmpty) return Center(child: Text("No 'Facility Staff' found for your state.", style: GoogleFonts.poppins()));
                  return _buildDashboardContent(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SegmentedButton<AttendanceFilter>(
        segments: [
          ButtonSegment(value: AttendanceFilter.all, label: Text('All', style: GoogleFonts.poppins()), icon: const Icon(Icons.people)),
          ButtonSegment(value: AttendanceFilter.onTime, label: Text('On Time', style: GoogleFonts.poppins()), icon: const Icon(Icons.timer_outlined)),
          ButtonSegment(value: AttendanceFilter.late, label: Text('Late', style: GoogleFonts.poppins()), icon: const Icon(Icons.history_toggle_off)),
        ],
        selected: {_filterController.value},
        onSelectionChanged: (newSelection) => _filterController.add(newSelection.first),
      ),
    );
  }

  Widget _buildDashboardContent(DashboardData data) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    double childAspectRatio;
    if (screenWidth > 1600) { crossAxisCount = 3; childAspectRatio = 1.4; }
    else if (screenWidth > 1100) { crossAxisCount = 2; childAspectRatio = 1.3; }
    else if (screenWidth > 750) { crossAxisCount = 2; childAspectRatio = 1.1; }
    else { crossAxisCount = 1; childAspectRatio = 1.2; }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _buildSummaryGrid(data,),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20, mainAxisSpacing: 20,
            childAspectRatio: childAspectRatio,
            children: [
              _buildCard(title: 'Live Clock-In Feed', trailing: Tooltip(message: "View Full Feed", child: Icon(Icons.open_in_full, color: Colors.grey.shade400)), child: _buildFacilityClockInCard(data), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveFeedFullScreenPage(records: data.attendanceRecords)))),
              _buildCard(title: 'Staff Yet to Clock-In Today', child: _buildYetToClockInCard(data)),
              _buildCard(title: 'Timesheet Status', child: _buildTimesheetStatusCard()),
              _buildCard(title: 'Weekly Trends', child: _buildWeeklyTrendChart(data)),
              _buildCard(title: 'Attendance Gauge', child: _buildPerformanceGauge(data)),
              _buildCard(title: 'Pending Leave Requests', child: _buildLeaveRequestCard(data)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child, Widget? trailing, VoidCallback? onTap}) {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(title, style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)), overflow: TextOverflow.ellipsis)),
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid1(DashboardData data, {bool isLargeScreen = false}) {
    return GridView.count(
      crossAxisCount: 1, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isLargeScreen ? 2.0 : 0.8,
      children: [
        _buildCard(title: 'Today\'s Attendance Overview', child: _buildAttendanceChart(data, isLargeScreen: isLargeScreen)),
      ],
    );
  }

  Widget _buildSummaryGrid(DashboardData data) {
    // 1. Get the current screen width to make responsive decisions.
    final screenWidth = MediaQuery.of(context).size.width;

    // 2. Define breakpoints and corresponding aspect ratios for different screen sizes.
    //    An aspect ratio > 1.0 means the widget is wider than it is tall.
    //    An aspect ratio < 1.0 means the widget is taller than it is wide.
    double childAspectRatio;

    if (screenWidth < 600) {
      // Mobile: The card needs to be much taller to accommodate the vertical column layout.
      childAspectRatio = 0.9;
    } else if (screenWidth < 900) {
      // Tablet (Portrait): Give it more space than mobile, but still tall.
      childAspectRatio = 1.3;
    } else if (screenWidth < 1200) {
      // Tablet (Landscape) / Small Laptop: Can start being wider.
      childAspectRatio = 1.9;
    } else if (screenWidth < 1600) {
      // Standard Desktop: The card can be quite wide.
      childAspectRatio = 2.3;
    } else {
      // Large Desktop Screens: Make it even wider.
      childAspectRatio = 2.7;
    }

    // 3. Return the GridView using the dynamically calculated aspect ratio.
    return GridView.count(
      crossAxisCount: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Use the calculated aspect ratio here.
      childAspectRatio: childAspectRatio,
      children: [
        _buildCard(
          title: 'Today\'s Attendance Overview',
          // The 'isLargeScreen' parameter is no longer passed, as the child
          // widget now handles its own internal responsive layout.
          child: _buildAttendanceChart(data),
        ),
      ],
    );
  }

  Widget _buildAttendanceChart(DashboardData data, {bool isLargeScreen = false}) {
    // --- START: RESPONSIVENESS FIX ---
    // Get the screen width to determine the layout
    final screenWidth = MediaQuery.of(context).size.width;
    // Define a breakpoint for mobile layout. You can adjust this value.
    final bool isMobile = screenWidth < 750;
    // --- END: RESPONSIVENESS FIX ---

    final today = DateTime.now();
    final todaysRecords = data.attendanceRecords.where((r) => DateFormat('yyyy-MM-dd').format(r.timestamp) == DateFormat('yyyy-MM-dd').format(today)).toList();
    AttendanceRecord? championRecord;
    if (todaysRecords.isNotEmpty) {
      final punctual = todaysRecords.where((r) => !r.isLate).toList();
      if(punctual.isNotEmpty) {
        punctual.sort((a,b) => _parseTime(a.clockInTime).compareTo(_parseTime(b.clockInTime)));
        championRecord = punctual.first;
      }
    }
    final championInfo = championRecord != null ? data.staffList.firstWhere((s) => s.id == championRecord!.staffId, orElse: () => StaffInfo(id: '', name: '', gender: '', location: '')) : null;
    final presentIds = todaysRecords.map((e) => e.staffId).toSet();
    final lateCount = todaysRecords.where((r) => r.isLate).length;
    final onTimeCount = presentIds.length - lateCount;
    final absentCount = data.staffList.length - presentIds.length;
    final malePresent = presentIds.where((id) => data.staffList.firstWhere((s) => s.id == id).gender == 'Male').length;
    final femalePresent = presentIds.where((id) => data.staffList.firstWhere((s) => s.id == id).gender == 'Female').length;

    final chartData = [ ChartData('On Time', onTimeCount, Colors.green.shade400), ChartData('Absent', absentCount, Colors.orange.shade400), ChartData('Late', lateCount, Colors.red.shade400)];

    // Main content widgets that will be arranged responsively
    final genderBreakdownWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Gender Breakdown', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 12),
        Text('Male: $malePresent / ${data.staffList.where((s) => s.gender == 'Male').length} Present', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Female: $femalePresent / ${data.staffList.where((s) => s.gender == 'Female').length} Present', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ],
    );

    final doughnutChartWidget = SfCircularChart(
      tooltipBehavior: TooltipBehavior(enable: true, format: 'point.x: point.y'),
      series: <CircularSeries<ChartData, String>>[
        DoughnutSeries<ChartData, String>(
          dataSource: chartData.where((d) => d.value > 0).toList(),
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
          pointColorMapper: (data, _) => data.color,
          // --- START: LABEL VISIBILITY FIX ---
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            // This forces the labels to always be drawn, preventing them from disappearing.
            labelIntersectAction: LabelIntersectAction.none,
          ),
          // --- END: LABEL VISIBILITY FIX ---
          innerRadius: '70%',
        )
      ],
      annotations: <CircularChartAnnotation>[
        CircularChartAnnotation(
          widget: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("${presentIds.length}", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
              Text("Clocked In /\n${data.staffList.length} Staff", textAlign: TextAlign.center, style: GoogleFonts.poppins()),
            ],
          ),
        ),
      ],
    );

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceAnalysisPage())),
            icon: const Icon(Icons.analytics_outlined, size: 16),
            label: Text("View Full Analysis", style: GoogleFonts.poppins()),
          ),
        ),
        Expanded(
          // --- START: RESPONSIVENESS FIX ---
          // Use a different layout for mobile vs. desktop
          child: isMobile
              ? Column( // On mobile, stack everything vertically
            children: [
              Expanded(child: doughnutChartWidget),
              const SizedBox(height: 24),
              genderBreakdownWidget,
              const SizedBox(height: 24),
              _buildPunctualityChampion(championInfo, championRecord),
            ],
          )
              : Row( // On desktop, use the horizontal layout
            children: [
              Expanded(flex: 4, child: _buildPunctualityChampion(championInfo, championRecord)),
              Expanded(flex: 4, child: genderBreakdownWidget),
              Expanded(flex: 3, child: doughnutChartWidget),
            ],
          ),
          // --- END: RESPONSIVENESS FIX ---
        ),
      ],
    );
  }

  Widget _buildPunctualityChampion(StaffInfo? champion, AttendanceRecord? record) {
    if (champion == null || record == null) {
      return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [ const Icon(Icons.shield_moon_outlined, size: 80, color: Colors.grey), const SizedBox(height: 8), Text("Punctuality Champion", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), Text("No punctual staff today", style: GoogleFonts.poppins(color: Colors.grey))]);
    }
    final championImage = champion.imageUrl;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40, backgroundColor: Colors.grey.shade200,
          child: championImage != null && championImage.isNotEmpty
              ? ClipOval(child: Image.network(championImage, fit: BoxFit.cover, width: 80, height: 80, loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : const CircularProgressIndicator(), errorBuilder: (context, error, stackTrace) => Icon(champion.gender == 'Male' ? Icons.person : Icons.person_2, size: 50, color: Colors.grey)))
              : Icon(champion.gender == 'Male' ? Icons.person : Icons.person_2, size: 50, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Text("Punctuality Champion", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        Text(champion.name, textAlign: TextAlign.center, style: GoogleFonts.poppins()),
        Text(champion.location, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
        Text(record.clockInTime, style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildYetToClockInCard(DashboardData data) {
    final yetToClockInList = data.yetToClockIn;
    if (yetToClockInList.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle, color: Colors.green, size: 40), const SizedBox(height: 8), Text("All staff have clocked in!", textAlign: TextAlign.center, style: GoogleFonts.poppins())]));
    }
    return ListView.builder(
      itemCount: yetToClockInList.length,
      itemBuilder: (context, index) {
        final staff = yetToClockInList[index];
        return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: Colors.red.shade100, child: Text(staff.name.isNotEmpty ? staff.name[0] : '?', style: GoogleFonts.poppins(color: Colors.red.shade800))), title: Text(staff.name, style: GoogleFonts.poppins(fontSize: 14)), subtitle: Text(staff.location, style: GoogleFonts.poppins(fontSize: 12)));
      },
    );
  }

  Widget _buildFacilityClockInCard(DashboardData data) {
    return data.attendanceRecords.isEmpty ? Center(child: Text("No clock-in records found.", style: GoogleFonts.poppins())) : ListView.builder(
      itemCount: data.attendanceRecords.length,
      itemBuilder: (context, index) {
        final record = data.attendanceRecords[index];
        return ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(record.staffName, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)), subtitle: Text('${record.staffLocation}\n${DateFormat('dd-MMM-yyyy').format(record.timestamp)}', style: GoogleFonts.poppins()), isThreeLine: true, trailing: Text(record.clockInTime, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: record.isLate ? Colors.red : Colors.green)));
      },
    );
  }

  Widget _buildTimesheetStatusCard() {
    return Column(
      children: [
        Text(DateFormat('MMMM yyyy').format(DateTime(_selectedTimesheetYear, _selectedTimesheetMonth)), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        Expanded(
          child: StreamBuilder<TimesheetMetrics>(
            stream: _timesheetStreamController.stream,
            builder: (context, snapshot) {
              if (_isTimesheetLoading) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) { debugPrint("Timesheet Stream Error: ${snapshot.error}\n${snapshot.stackTrace}"); return Center(child: Text("Error", style: GoogleFonts.poppins(color: Colors.red))); }
              if (!snapshot.hasData || snapshot.data == null || snapshot.data!.totalExpected == 0) return Center(child: Text("No Data", style: GoogleFonts.poppins(color: Colors.grey)));
              final metrics = snapshot.data!;
              final pendingSubmission = metrics.totalExpected - metrics.totalSubmitted;
              final completionPercentage = metrics.totalExpected > 0 ? (metrics.fullyApproved / metrics.totalExpected) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildStatusRow('Expected', '${metrics.totalExpected} Staff', Colors.blue),
                    _buildStatusRow('Pending Submission', '$pendingSubmission Staff', Colors.orange),
                    _buildStatusRow('Pending Approval', '${metrics.pendingApproval} Timesheets', Colors.red),
                    const Spacer(),
                    Text('Overall Approval: ${completionPercentage.toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: completionPercentage / 100, minHeight: 10, borderRadius: BorderRadius.circular(5), backgroundColor: Colors.grey.shade300, valueColor: const AlwaysStoppedAnimation<Color>(Colors.green)),
                    Align(alignment: Alignment.bottomRight, child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TimesheetReviewPage())), child: Text('View Details', style: GoogleFonts.poppins()))),
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildStatusRow(String title, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [ Row(children: [Icon(Icons.circle, color: color, size: 10), const SizedBox(width: 8), Text(title, style: GoogleFonts.poppins())]), Text(count, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)) ],
      ),
    );
  }

  Widget _buildWeeklyTrendChart(DashboardData data) {
    Map<String, Set<String>> dailyUniqueStaff = {};
    for (var record in data.attendanceRecords) {
      dailyUniqueStaff.update(DateFormat('E').format(record.timestamp), (value) => value..add(record.staffId), ifAbsent: () => {record.staffId});
    }
    final trendData = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) => ChartData(day, dailyUniqueStaff[day]?.length ?? 0)).toList();
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(), primaryYAxis: NumericAxis(title: AxisTitle(text: 'Unique Staff Count')),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: [ColumnSeries<ChartData, String>(dataSource: trendData, xValueMapper: (data, _) => data.category, yValueMapper: (data, _) => data.value)],
    );
  }

  Widget _buildPerformanceGauge(DashboardData data) {
    final totalStaff = data.staffList.length;
    final presentToday = data.attendanceRecords.where((r) => DateFormat('yyyy-MM-dd').format(r.timestamp) == DateFormat('yyyy-MM-dd').format(DateTime.now())).map((r) => r.staffId).toSet().length;
    final percentage = totalStaff > 0 ? (presentToday / totalStaff) * 100 : 0.0;
    return gauges.SfRadialGauge(
      axes: [
        gauges.RadialAxis(
          minimum: 0, maximum: 100, showLabels: false, showTicks: false,
          axisLineStyle: const gauges.AxisLineStyle(thickness: 0.2, thicknessUnit: gauges.GaugeSizeUnit.factor, cornerStyle: gauges.CornerStyle.bothCurve),
          pointers: [
            gauges.RangePointer(value: percentage, width: 0.2, sizeUnit: gauges.GaugeSizeUnit.factor, cornerStyle: gauges.CornerStyle.bothCurve, color: Colors.teal),
            gauges.MarkerPointer(value: percentage, markerHeight: 10, markerWidth: 10, markerType: gauges.MarkerType.circle, color: Colors.white)
          ],
          annotations: <gauges.GaugeAnnotation>[gauges.GaugeAnnotation(widget: Text('${percentage.toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)), angle: 90, positionFactor: 0.1)],
        )
      ],
    );
  }

  Widget _buildLeaveRequestCard(DashboardData data) {
    final pendingLeaves = data.pendingLeaves;
    if (pendingLeaves.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle_outline, color: Colors.green, size: 40), const SizedBox(height: 8), Text("No pending leave requests.", textAlign: TextAlign.center, style: GoogleFonts.poppins())]));
    }
    return Column(
      children: [
        Text("${pendingLeaves.length} Pending Request(s)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: pendingLeaves.length,
            itemBuilder: (context, index) {
              final leave = pendingLeaves[index];
              return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.person_outline)), title: Text(leave.staffName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)), subtitle: Text('${leave.leaveType} (${DateFormat('dd MMM').format(leave.startDate)} - ${DateFormat('dd MMM').format(leave.endDate)})', style: GoogleFonts.poppins(fontSize: 12)));
            },
          ),
        ),
        Align(alignment: Alignment.bottomRight, child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StateLeaveRequestManagementPage())), child: Text('View Details', style: GoogleFonts.poppins()))),
      ],
    );
  }
}

// --- NEW FULL-SCREEN PAGE FOR LIVE FEED ---
class LiveFeedFullScreenPage extends StatelessWidget {
  final List<AttendanceRecord> records;
  const LiveFeedFullScreenPage({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Full Clock-In Feed', style: GoogleFonts.poppins())),
      body: records.isEmpty ? Center(child: Text("No clock-in records to display.", style: GoogleFonts.poppins())) : ListView.builder(
        padding: const EdgeInsets.all(8.0), itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: ListTile(
              title: Text(record.staffName, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Text('${record.staffLocation} - ${DateFormat('dd-MMM-yyyy').format(record.timestamp)}', style: GoogleFonts.poppins()),
              trailing: Text(record.clockInTime, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: record.isLate ? Colors.red.shade700 : Colors.green.shade700)),
            ),
          );
        },
      ),
    );
  }
}