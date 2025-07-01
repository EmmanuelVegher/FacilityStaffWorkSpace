// STATE-LEVEL MONITORING DASHBOARD
// REWRITTEN FOR PERFORMANCE USING STREAMS AND ADVANCED FILTERING
// ** VERSION 10 (FINAL & COMPLETE): FACILITY STAFF FILTER, "YET TO CLOCK-IN" LIST, & UI ENHANCEMENTS **

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart' as gauges;

import '../../widgets/drawer2.dart';
// Note: Ensure this path is correct for your project structure
import '../attendance_analysis_page/attendance_analysis_page.dart';
import '../attendance_analysis_page/hq_attendance_analysis_page.dart';
import '../timesheet/timesheet_management_dashboard.dart';

// --- ENUMS & MODELS ---

enum AttendanceFilter { all, onTime, late }

class StaffInfo {
  final String id;
  final String name;
  final String gender;
  final String? imageUrl;
  final String location;
  StaffInfo({
    required this.id,
    required this.name,
    required this.gender,
    required this.location,
    this.imageUrl,
  });
}

class AttendanceRecord {
  final String staffId;
  final String staffName;
  final String staffLocation;
  final DateTime timestamp;
  final String clockInTime;
  final bool isLate;
  AttendanceRecord({
    required this.staffId,
    required this.staffName,
    required this.staffLocation,
    required this.timestamp,
    required this.clockInTime,
    this.isLate = false,
  });
}


class DashboardData {
  final List<StaffInfo> staffList;
  final List<AttendanceRecord> attendanceRecords;
  final List<StaffInfo> yetToClockIn;
  final List<LeaveRequest> pendingLeaves;

  DashboardData({
    required this.staffList,
    required this.attendanceRecords,
    required this.yetToClockIn,
    required this.pendingLeaves, // Added to constructor
  });
}

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

// FIX: New model for Leave Requests
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
    // Helper to safely parse date strings
    DateTime _parseDate(String? dateStr) {
      if (dateStr == null) return DateTime.now();
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return DateTime.now();
      }
    }

    return LeaveRequest(
      staffName: '${map['firstName'] ?? ''} ${map['lastName'] ?? 'Unknown'}'.trim(),
      leaveType: map['type'] ?? 'N/A',
      startDate: _parseDate(map['startDate']),
      endDate: _parseDate(map['endDate']),
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

  String? _currentUserState;
  Stream<DashboardData>? _dashboardStream;
  final _filterController = BehaviorSubject<AttendanceFilter>.seeded(AttendanceFilter.all);
  final _dateRangeController = BehaviorSubject<DateTimeRange>();

  late int _selectedTimesheetMonth;
  late int _selectedTimesheetYear;
  StreamController<TimesheetMetrics> _timesheetStreamController = StreamController.broadcast();
  bool _isTimesheetLoading = false;

  late Timer _timer;
  String _liveTime = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedTimesheetMonth = now.month;
    _selectedTimesheetYear = now.year;

    _dateRangeController.add(DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day),
    ));
    _initializeStreams();

    _liveTime = DateFormat('hh:mm:ss a').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if(mounted) {
        setState(() {
          _liveTime = DateFormat('hh:mm:ss a').format(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _filterController.close();
    _dateRangeController.close();
    _timesheetStreamController.close();
    _timer.cancel();
    super.dispose();
  }

  DateTime _parseTime(String timeString) {
    try {
      final now = DateTime.now();
      final format = DateFormat("hh:mm a");
      final dt = format.parse(timeString);
      return DateTime(now.year, now.month, now.day, dt.hour, dt.minute);
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
      // FIX: Catch any errors during initialization
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

    final staffQuery = _firestore.collection('Staff')
        .where('state', isEqualTo: _currentUserState)
        .where('staffCategory', isEqualTo: 'Facility Staff');

    // FIX: Create a new stream for leave requests
    final leaveRequestStream = _firestore.collectionGroup('Leave Request')
        .where('staffState', isEqualTo: _currentUserState)
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => LeaveRequest.fromMap(doc.data())).toList());

    return Rx.combineLatest2(
        staffQuery.snapshots(),
        leaveRequestStream,
            (staffSnapshot, pendingLeaves) {
          return {'staff': staffSnapshot, 'leaves': pendingLeaves};
        }
    ).switchMap((data) {
      final staffSnapshot = data['staff'] as QuerySnapshot<Map<String, dynamic>>;
      final pendingLeaves = data['leaves'] as List<LeaveRequest>;

      final staffList = staffSnapshot.docs.map((doc) {
        final data = doc.data();
        return StaffInfo(
            id: doc.id,
            name: '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
            gender: data['gender'] ?? 'Unknown',
            location: data['location'] ?? 'N/A',
            imageUrl: data['imageUrl'] as String?);
      }).toList();

      if (staffList.isEmpty) return Stream.value(DashboardData(staffList: [], attendanceRecords: [], yetToClockIn: [], pendingLeaves: []));

      final staffMap = {for (var staff in staffList) staff.id: staff};
      final lateCutoff = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day, 8, 0, 1);

      Query recordsQuery = _firestore
          .collectionGroup('Record')
          .where('timestamp', isGreaterThanOrEqualTo: dateRange.start)
          .where('timestamp', isLessThan: dateRange.end.add(const Duration(days: 1)));

      return recordsQuery.snapshots().map((recordsSnapshot) {
        final allRecordsForPeriod = recordsSnapshot.docs.map((doc) {
          final staffInfo = staffMap[doc.reference.parent.parent!.id];
          if (staffInfo == null) return null;
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          final clockInTime = data['clockIn'] ?? 'N/A';
          final parsedClockInTime = _parseTime(clockInTime);
          return AttendanceRecord(
              staffId: staffInfo.id,
              staffName: staffInfo.name,
              staffLocation: staffInfo.location,
              timestamp: timestamp,
              clockInTime: clockInTime,
              isLate: parsedClockInTime.isAfter(lateCutoff));
        }).whereType<AttendanceRecord>().toList();

        List<AttendanceRecord> filteredRecords;
        switch(filter) {
          case AttendanceFilter.onTime:
            filteredRecords = allRecordsForPeriod.where((r) => !r.isLate).toList();
            break;
          case AttendanceFilter.late:
            filteredRecords = allRecordsForPeriod.where((r) => r.isLate).toList();
            break;
          case AttendanceFilter.all:
          default:
            filteredRecords = allRecordsForPeriod;
            break;
        }
        filteredRecords.sort((a, b) => _parseTime(a.clockInTime).compareTo(_parseTime(b.clockInTime)));

        final todaysRecords = allRecordsForPeriod.where((r) => DateFormat('yyyy-MM-dd').format(r.timestamp) == DateFormat('yyyy-MM-dd').format(DateTime.now()));
        final clockedInIds = todaysRecords.map((r) => r.staffId).toSet();
        final yetToClockIn = staffList.where((staff) => !clockedInIds.contains(staff.id)).toList();

        return DashboardData(
          staffList: staffList,
          attendanceRecords: filteredRecords,
          yetToClockIn: yetToClockIn,
          pendingLeaves: pendingLeaves,
        );
      });
    });
  }

  void _loadTimesheetMetrics() async {
    if (_currentUserState == null) return;
    if (mounted) setState(() => _isTimesheetLoading = true);
    try {
      final metrics = await _fetchTimesheetMetrics(
          state: _currentUserState!,
          year: _selectedTimesheetYear,
          month: _selectedTimesheetMonth
      );
      if (!_timesheetStreamController.isClosed) {
        _timesheetStreamController.add(metrics);
      }
    } catch (e, s) {
      // FIX: Print error and stack trace here too
      debugPrint("Error loading timesheet metrics: $e\n$s");
      if (!_timesheetStreamController.isClosed) {
        _timesheetStreamController.addError(e);
      }
    } finally {
      if (mounted) setState(() => _isTimesheetLoading = false);
    }
  }

  Future<TimesheetMetrics> _fetchTimesheetMetrics({required String state, required int year, required int month}) async {
    final facilityStaffQuery = _firestore.collection('Staff').where('state', isEqualTo: state).where('staffCategory', isEqualTo: 'Facility Staff');
    final staffSnapshot = await facilityStaffQuery.get();
    if (staffSnapshot.docs.isEmpty) return TimesheetMetrics();
    int expected = staffSnapshot.docs.length;
    int submitted = 0;
    int pending = 0;
    int approved = 0;
    final monthName = DateFormat('MMMM').format(DateTime(year, month));
    final timesheetDocId = '${monthName}_$year';
    final futures = staffSnapshot.docs.map((staffDoc) => staffDoc.reference.collection('TimeSheets').doc(timesheetDocId).get());
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

  // --- BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer2(context),
      appBar: AppBar(
        title: Text('$_currentUserState Monitoring'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(_liveTime, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopFilterBar(),
          Expanded(
            child: StreamBuilder<DashboardData>(
              stream: _dashboardStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                // FIX: Enhanced error handling to print to console
                if (snapshot.hasError) {
                  debugPrint("Dashboard Stream Error: ${snapshot.error}\n${snapshot.stackTrace}");
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text("An error occurred. Please check the console logs.\n${snapshot.error}", style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.staffList.isEmpty) {
                  return const Center(child: Text("No 'Facility Staff' found for this state."));
                }
                final data = snapshot.data!;
                return _buildDashboardContent(data);
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTopFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SegmentedButton<AttendanceFilter>(
        segments: const [
          ButtonSegment(value: AttendanceFilter.all, label: Text('All'), icon: Icon(Icons.people)),
          ButtonSegment(value: AttendanceFilter.onTime, label: Text('On Time'), icon: Icon(Icons.timer_outlined)),
          ButtonSegment(value: AttendanceFilter.late, label: Text('Late'), icon: Icon(Icons.history_toggle_off)),
        ],
        selected: {_filterController.value},
        onSelectionChanged: (newSelection) {
          _filterController.add(newSelection.first);
        },
      ),
    );
  }

  Widget _buildDashboardContent(DashboardData data) {
    final screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1200;
    int otherCardsGridCrossAxisCount = isMobile ? 1 : isTablet ? 2 : 3;
    double otherCardsGridChildAspectRatio = isMobile ? 1.5 : isTablet ? 1.4 : 1.3;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _buildSummaryGrid(data, isLargeScreen: !isMobile),
          const SizedBox(height: 20),
          _buildOtherCardsGrid(data, otherCardsGridCrossAxisCount, otherCardsGridChildAspectRatio),
          const SizedBox(height: 20),
         // _buildMoreAnalysisButton(),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(DashboardData data, {bool isLargeScreen = false}) {
    return GridView.count(
      crossAxisCount: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isLargeScreen ? 3.0 : 1.8,
      children: [
        _buildCard(
          title: 'Today\'s Attendance Overview',
          child: _buildAttendanceChart(data, isLargeScreen: isLargeScreen),
        ),
      ],
    );
  }

  Widget _buildOtherCardsGrid(DashboardData data, int crossAxisCount, double childAspectRatio) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: childAspectRatio,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => LiveFeedFullScreenPage(records: data.attendanceRecords),
            ));
          },
          child: _buildCard(
            title: 'Live Clock-In Feed',
            trailing: Tooltip(
                message: "View Full Feed",
                child: Icon(Icons.open_in_full, color: Colors.grey.shade400)),
            child: _buildFacilityClockInCard(data),
          ),
        ),
        _buildCard(title: 'Staff Yet to Clock-In Today', child: _buildYetToClockInCard(data)),
        _buildCard(title: 'Timesheet Status', child: _buildTimesheetStatusCard()),
        _buildCard(title: 'Weekly Trends', child: _buildWeeklyTrendChart(data)),
        _buildCard(title: 'Attendance Gauge', child: _buildPerformanceGauge(data)),
        _buildCard(title: 'Pending Leave Requests', child: _buildLeaveRequestCard(data)),
      ],
    );
  }

  Widget _buildCard({required String title, required Widget child, Widget? trailing}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18), overflow: TextOverflow.ellipsis)),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceChart(DashboardData data, {bool isLargeScreen = false}) {
    final today = DateTime.now();
    final allStaffInState = data.staffList;
    final todaysRecords = data.attendanceRecords.where((r) => DateFormat('yyyy-MM-dd').format(r.timestamp) == DateFormat('yyyy-MM-dd').format(today)).toList();

    AttendanceRecord? championRecord;
    if (todaysRecords.isNotEmpty) {
      final punctualRecords = todaysRecords.where((r) => !r.isLate).toList();
      if(punctualRecords.isNotEmpty) {
        punctualRecords.sort((a,b) => _parseTime(a.clockInTime).compareTo(_parseTime(b.clockInTime)));
        championRecord = punctualRecords.first;
      }
    }
    final championInfo = championRecord != null ? allStaffInState.firstWhere((s) => s.id == championRecord!.staffId) : null;

    final presentIds = todaysRecords.map((e) => e.staffId).toSet();
    final lateCount = todaysRecords.where((r) => r.isLate).length;
    final onTimeCount = presentIds.length - lateCount;
    final absentCount = allStaffInState.length - presentIds.length;

    final maleStaff = allStaffInState.where((s) => s.gender == 'Male').toList();
    final femaleStaff = allStaffInState.where((s) => s.gender == 'Female').toList();
    final malePresent = presentIds.where((id) => maleStaff.any((s) => s.id == id)).length;
    final femalePresent = presentIds.where((id) => femaleStaff.any((s) => s.id == id)).length;

    final chartData = [
      ChartData('On Time', onTimeCount, Colors.green.shade400),
      ChartData('Absent', absentCount, Colors.orange.shade400),
      ChartData('Late', lateCount, Colors.red.shade400),
    ];

    return Column(
      children: [
        // FIX: Moved button here
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AttendanceAnalysisPage(),
              ));
            },
            child: const Text("Tap to View Detailed Attendance Analysis..."),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              if (isLargeScreen) Expanded(flex: 4, child: _buildPunctualityChampion(championInfo, championRecord)),
              Expanded(
                flex: isLargeScreen ? 4 : 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Dis-Aggregated Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 20),
                    Text('Male: $malePresent / ${maleStaff.length} Present', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Female: $femalePresent / ${femaleStaff.length} Present', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                flex: isLargeScreen ? 3 : 2,
                child: SfCircularChart(
                  tooltipBehavior: TooltipBehavior(enable: true, format: 'point.x: point.y'),
                  series: <CircularSeries<ChartData, String>>[
                    DoughnutSeries<ChartData, String>(
                      dataSource: chartData.where((d) => d.value > 0).toList(),
                      xValueMapper: (data, _) => data.category,
                      yValueMapper: (data, _) => data.value,
                      pointColorMapper: (data, _) => data.color,
                      dataLabelSettings: const DataLabelSettings(isVisible: false),
                      innerRadius: '70%',
                    )
                  ],
                  annotations: <CircularChartAnnotation>[
                    CircularChartAnnotation(
                      widget: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("${presentIds.length}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text("Clocked In /\n${allStaffInState.length} Staffs", textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPunctualityChampion(StaffInfo? champion, AttendanceRecord? record) {
    if (champion == null || record == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_moon_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 8),
          Text("Punctuality Champion", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("No punctual staff today", style: TextStyle(color: Colors.grey)),
        ],
      );
    }
    final championImage = champion.imageUrl;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey.shade200,
          child: championImage != null && championImage.isNotEmpty
              ? ClipOval(
            child: Image.network(
              championImage,
              fit: BoxFit.cover, width: 80, height: 80,
              loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : const CircularProgressIndicator(),
              errorBuilder: (context, error, stackTrace) => Icon(champion.gender == 'Male' ? Icons.person : Icons.person_2, size: 50, color: Colors.grey),
            ),
          )
              : Icon(champion.gender == 'Male' ? Icons.person : Icons.person_2, size: 50, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        const Text("Punctuality Champion", style: TextStyle(fontWeight: FontWeight.bold)),
        Text(champion.name, textAlign: TextAlign.center),
        Text(champion.location, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(record.clockInTime, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildYetToClockInCard(DashboardData data) {
    final yetToClockInList = data.yetToClockIn;
    if (yetToClockInList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 40),
            SizedBox(height: 8),
            Text("All staff have clocked in!", textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: yetToClockInList.length,
      itemBuilder: (context, index) {
        final staff = yetToClockInList[index];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: Text(
              staff.name.isNotEmpty ? staff.name[0] : '?',
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
          title: Text(staff.name, style: const TextStyle(fontSize: 14)),
          subtitle: Text(staff.location, style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }

  Widget _buildFacilityClockInCard(DashboardData data) {
    return Column(
      children: [
        Expanded(
          child: data.attendanceRecords.isEmpty
              ? const Center(child: Text("No clock-in records found."))
              : ListView.builder(
            itemCount: data.attendanceRecords.length,
            itemBuilder: (context, index) {
              final record = data.attendanceRecords[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(record.staffName, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${record.staffLocation}\n${DateFormat('dd-MMM-yyyy').format(record.timestamp)}'),
                isThreeLine: true,
                trailing: Text(record.clockInTime, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: record.isLate ? Colors.red : Colors.green
                )),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimesheetStatusCard() {
    return Column(
      children: [
        Text(
            DateFormat('MMMM yyyy').format(DateTime(_selectedTimesheetYear, _selectedTimesheetMonth)),
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)
        ),
        Expanded(
          child: StreamBuilder<TimesheetMetrics>(
            stream: _timesheetStreamController.stream,
            builder: (context, snapshot) {
              if (_isTimesheetLoading) return const Center(child: CircularProgressIndicator());
              // FIX: Enhanced error handling to print to console
              if (snapshot.hasError) {
                debugPrint("Timesheet Stream Error: ${snapshot.error}\n${snapshot.stackTrace}");
                return Center(child: Text("Error", style: const TextStyle(color: Colors.red)));
              }
              if (!snapshot.hasData || snapshot.data == null || snapshot.data!.totalExpected == 0) {
                return const Center(child: Text("No Data", style: TextStyle(color: Colors.grey)));
              }

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
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TimesheetReviewPage()),
                          );
                        },
                        child: const Text('View Details'),
                      ),
                    )
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
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: color, size: 10),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          Text(count, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendChart(DashboardData data) {
    Map<String, Set<String>> dailyUniqueStaff = {};
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (var record in data.attendanceRecords) {
      String day = DateFormat('E').format(record.timestamp);
      dailyUniqueStaff.update(day, (value) => value..add(record.staffId), ifAbsent: () => {record.staffId});
    }
    final trendData = days.map((day) => ChartData(day, dailyUniqueStaff[day]?.length ?? 0)).toList();
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(title: AxisTitle(text: 'Unique Staff Count')),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: [
        ColumnSeries<ChartData, String>(
          dataSource: trendData,
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
        ),
      ],
    );
  }

  Widget _buildPerformanceGauge(DashboardData data) {
    final totalStaff = data.staffList.length;
    final presentToday = data.attendanceRecords.where((r) => DateFormat('yyyy-MM-dd').format(r.timestamp) == DateFormat('yyyy-MM-dd').format(DateTime.now())).map((r) => r.staffId).toSet().length;
    final percentage = totalStaff > 0 ? (presentToday / totalStaff) * 100 : 0.0;
    return gauges.SfRadialGauge(
      axes: [
        gauges.RadialAxis(
          minimum: 0,
          maximum: 100,
          showLabels: false,
          showTicks: false,
          axisLineStyle: gauges.AxisLineStyle(thickness: 0.2, thicknessUnit: gauges.GaugeSizeUnit.factor, cornerStyle: gauges.CornerStyle.bothCurve),
          pointers: [
            gauges.RangePointer(value: percentage, width: 0.2, sizeUnit: gauges.GaugeSizeUnit.factor, cornerStyle: gauges.CornerStyle.bothCurve, color: Colors.teal),
            gauges.MarkerPointer(value: percentage, markerHeight: 10, markerWidth: 10, markerType: gauges.MarkerType.circle, color: Colors.white)
          ],
          annotations: <gauges.GaugeAnnotation>[
            gauges.GaugeAnnotation(
                widget: Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                angle: 90,
                positionFactor: 0.1)
          ],
        )
      ],
    );
  }

  // --- NEW LEAVE REQUEST CARD ---
  Widget _buildLeaveRequestCard(DashboardData data) {

    final pendingLeaves = data.pendingLeaves;
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
    return Column(
      children: [
        Text(
          "${pendingLeaves.length} Pending Request(s)",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
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
          ),
        ),
      ],
    );
  }


  Widget _buildMoreAnalysisButton() {
    return Center(
      child: OutlinedButton.icon(
        icon: const Icon(Icons.analytics_outlined),
        label: const Text("View Detailed Attendance Analysis"),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const HQAttendanceAnalysisPage(),
          ));
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard({required String title, required IconData icon}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            const Text("(To be implemented)", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
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
      appBar: AppBar(
        title: const Text('Full Clock-In Feed'),
      ),
      body: records.isEmpty
          ? const Center(child: Text("No clock-in records to display."))
          : ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: ListTile(
              title: Text(record.staffName, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('${record.staffLocation} - ${DateFormat('dd-MMM-yyyy').format(record.timestamp)}'),
              trailing: Text(record.clockInTime, style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: record.isLate ? Colors.red.shade700 : Colors.green.shade700,
              )),
            ),
          );
        },
      ),
    );
  }
}