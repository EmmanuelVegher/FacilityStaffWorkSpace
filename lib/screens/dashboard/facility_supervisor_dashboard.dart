import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart' as gauges;

// Import your project's relevant pages and widgets.
// These paths might need to be adjusted for your project structure.
import '../../models/facility_staff_model.dart';
// Assuming drawer2 is for State/Supervisor level
import '../../widgets/drawer4.dart';
import '../attendance_analysis_page/facility_supervisor_analysis_page.dart';
import 'package:service_delivery_workspace/screens/leave_request/state_leave_request_page.dart';
import 'package:service_delivery_workspace/screens/timesheet/timesheet_management_dashboard.dart';


// --- ENUMS & MODELS (These are reusable across dashboards) ---

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

// The main data model for this dashboard's stream
class DashboardData {
  final List<StaffInfo> staffList, yetToClockIn;
  final List<AttendanceRecord> attendanceRecords;
  final List<LeaveRequest> pendingLeaves;
  final FacilityStaffModel? bestPlayer;
  final Map<String, int> bestPlayerVotes;
  final int totalSurveys;

  DashboardData({
    required this.staffList,
    required this.attendanceRecords,
    required this.yetToClockIn,
    required this.pendingLeaves,
    this.bestPlayer,
    this.bestPlayerVotes = const {},
    this.totalSurveys = 0,
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

class FacilitySupervisorDashboard extends StatefulWidget {
  const FacilitySupervisorDashboard({super.key});
  @override
  FacilitySupervisorDashboardState createState() => FacilitySupervisorDashboardState();
}

class FacilitySupervisorDashboardState extends State<FacilitySupervisorDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StreamController<String> _timeStreamController = StreamController.broadcast();

  String? _currentUserState;
  String? _currentUserFacility; // KEY: We need the supervisor's specific facility/location
  Stream<DashboardData>? _dashboardStream;
  final _filterController = BehaviorSubject<AttendanceFilter>.seeded(AttendanceFilter.all);
  final _dateRangeController = BehaviorSubject<DateTimeRange>();
  late int _selectedTimesheetMonth, _selectedTimesheetYear;
  final StreamController<TimesheetMetrics> _timesheetStreamController = StreamController.broadcast();
  bool _isTimesheetLoading = false;
  late Timer _timer;

  // New Constants for Styling
  static const Color maroonPrimary = Color(0xFF5C1A2E);
  static const Color wineColor = Color(0xFF722F37);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedTimesheetMonth = now.month;
    _selectedTimesheetYear = now.year;
    // Default to today for live feeds
    _dateRangeController.add(DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now));
    _initializeStreams();

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
      // Return a future date to ensure it's always considered "late" if parsing fails
      return DateTime.now().add(const Duration(days: 1));
    }
  }

  void _initializeStreams() async {
    try {
      await _loadCurrentUserBioData();
      if (_currentUserState != null && _currentUserFacility != null) {
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
        if (mounted) setState(() {});
      }
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
        setState(() {
          _currentUserState = doc.data()?['state'] as String?;
          _currentUserFacility = doc.data()?['location'] as String?; // Fetch the facility
        });
      }
    } catch (e) {
      debugPrint("Error loading supervisor bio data: $e");
    }
  }

  Stream<DashboardData> _fetchDashboardData(DateTimeRange dateRange, AttendanceFilter filter) {
    if (_currentUserState == null || _currentUserFacility == null) {
      return Stream.value(DashboardData(staffList: [], attendanceRecords: [], yetToClockIn: [], pendingLeaves: []));
    }

    // QUERY 1: Get staff for the supervisor's specific state AND location/facility.
    final staffQuery = _firestore.collection('Staff')
        .where('state', isEqualTo: _currentUserState)
        .where('location', isEqualTo: _currentUserFacility)
        .where('staffCategory', isEqualTo: 'Facility Staff');

    // QUERY 2: Get pending leave requests for the facility.
    // NOTE: This assumes 'staffFacility' field exists on Leave Request documents for efficient querying.
    final leaveRequestStream = _firestore.collectionGroup('Leave Request')
        .where('staffState', isEqualTo: _currentUserState)
        .where('staffFacility', isEqualTo: _currentUserFacility)
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => LeaveRequest.fromMap(doc.data())).toList());

    // QUERY 3: Get "Best Team Player" data for the facility.
    final bestPlayerStream = _fetchBestPlayerData(dateRange.start, dateRange.end);

    // Combine all three streams into one dashboard data object.
    return Rx.combineLatest3(staffQuery.snapshots(), leaveRequestStream, bestPlayerStream,
            (staff, leaves, bestPlayerData) => {'staff': staff, 'leaves': leaves, 'bestPlayer': bestPlayerData}
    )
        .switchMap((data) {
      final staffSnapshot = data['staff'] as QuerySnapshot<Map<String, dynamic>>;
      final pendingLeaves = data['leaves'] as List<LeaveRequest>;
      final bestPlayerData = data['bestPlayer'] as Map<String, dynamic>;

      final staffList = staffSnapshot.docs.map((doc) {
        final data = doc.data();
        return StaffInfo(
          id: doc.id,
          name: '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          gender: data['gender'] ?? 'Unknown',
          location: data['location'] ?? 'N/A',
          imageUrl: data['photoUrl'] as String?,
          designation: data['designation'] as String?,
        );
      }).toList();

      if (staffList.isEmpty) return Stream.value(DashboardData(staffList: [], attendanceRecords: [], yetToClockIn: [], pendingLeaves: []));

      // Create a map of staff IDs for easy lookup. This is key to filtering the records.
      final staffMap = {for (var staff in staffList) staff.id: staff};
      final lateCutoff = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day, 8, 0, 1);

      // QUERY 4: Get all attendance records within the date range.
      // We can't filter collectionGroup by a parent's field, so we fetch all and filter client-side.
      Query recordsQuery = _firestore.collectionGroup('Record')
          .where('timestamp', isGreaterThanOrEqualTo: dateRange.start)
          .where('timestamp', isLessThan: dateRange.end.add(const Duration(days: 1)));

      return recordsQuery.snapshots().map((recordsSnapshot) {
        final allRecordsForPeriod = recordsSnapshot.docs.map((doc) {
          // Here is the client-side filter: Only include records from staff in our facility.
          final staffInfo = staffMap[doc.reference.parent.parent!.id];
          if (staffInfo == null) return null;

          final data = doc.data() as Map<String, dynamic>;
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          final clockInTime = data['clockIn'] ?? 'N/A';
          return AttendanceRecord(
              staffId: staffInfo.id,
              staffName: staffInfo.name,
              staffLocation: staffInfo.location,
              timestamp: timestamp,
              clockInTime: clockInTime,
              isLate: _parseTime(clockInTime).isAfter(lateCutoff)
          );
        }).whereType<AttendanceRecord>().toList();

        // Apply the On-Time/Late filter from the UI
        final filteredRecords = (filter == AttendanceFilter.all)
            ? allRecordsForPeriod
            : allRecordsForPeriod.where((r) => filter == AttendanceFilter.onTime ? !r.isLate : r.isLate).toList();
        filteredRecords.sort((a, b) => _parseTime(a.clockInTime).compareTo(_parseTime(b.clockInTime)));

        // Determine who is yet to clock in today
        final todaysRecords = allRecordsForPeriod.where((r) => DateFormat('yyyy-MM-dd').format(r.timestamp) == DateFormat('yyyy-MM-dd').format(DateTime.now()));
        final clockedInIds = todaysRecords.map((r) => r.staffId).toSet();
        final yetToClockIn = staffList.where((staff) => !clockedInIds.contains(staff.id)).toList();

        // Return the final, combined data object for the UI to build
        return DashboardData(
          staffList: staffList,
          attendanceRecords: filteredRecords,
          yetToClockIn: yetToClockIn,
          pendingLeaves: pendingLeaves,
          bestPlayer: bestPlayerData['bestPlayer'],
          bestPlayerVotes: bestPlayerData['votes'],
          totalSurveys: bestPlayerData['surveyCount'],
        );
      });
    });
  }

  Stream<Map<String, dynamic>> _fetchBestPlayerData(DateTime startDate, DateTime endDate) {
    if (_currentUserState == null || _currentUserFacility == null) {
      return Stream.value({'bestPlayer': null, 'votes': <String, int>{}, 'surveyCount': 0});
    }

    // Efficiently query all survey responses for this facility in the date range
    return FirebaseFirestore.instance
        .collectionGroup('SurveyResponses')
        .where('State', isEqualTo: _currentUserState)
        .where('FacilityName', isEqualTo: _currentUserFacility)
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .snapshots()
        .map((snapshot) {
      final bestPlayerCounts = <String, int>{};
      int surveyCount = snapshot.docs.length;

      for (final surveyDoc in snapshot.docs) {
        final surveyDataFull = surveyDoc.data();
        if (surveyDataFull.containsKey('surveyData')) {
          final surveyDataList = surveyDataFull['surveyData'] as List;
          for (var surveyItem in surveyDataList) {
            if (surveyItem is Map<String, dynamic> && surveyItem.containsKey("For the current week, who is the best team player in your facility")) {
              final bestPlayerFieldValue = surveyItem["For the current week, who is the best team player in your facility"];
              List<dynamic> bestPlayerList = [];
              if (bestPlayerFieldValue is String) { try { bestPlayerList = json.decode(bestPlayerFieldValue) as List; } catch (e) { /* ignore */ }
              } else if (bestPlayerFieldValue is List) { bestPlayerList = bestPlayerFieldValue; }

              if (bestPlayerList.isNotEmpty) {
                var firstPlayer = bestPlayerList[0];
                if (firstPlayer is Map<String, dynamic> && firstPlayer.containsKey('name')) {
                  final playerName = firstPlayer['name'] as String;
                  bestPlayerCounts[playerName] = (bestPlayerCounts[playerName] ?? 0) + 1;
                }
              }
            }
          }
        }
      }

      // Determine the winner from the vote counts
      String? bestPlayerName;
      int maxCount = 0;
      bestPlayerCounts.forEach((playerName, count) {
        if (count > maxCount) {
          maxCount = count;
          bestPlayerName = playerName;
        }
      });

      return {
        'bestPlayer': bestPlayerName != null ? FacilityStaffModel(name: bestPlayerName) : null,
        'votes': bestPlayerCounts,
        'surveyCount': surveyCount,
      };
    }).handleError((error) {
      debugPrint("Error fetching best player data: $error");
      return {'bestPlayer': null, 'votes': <String, int>{}, 'surveyCount': 0};
    });
  }


  void _loadTimesheetMetrics() async {
    if (_currentUserState == null || _currentUserFacility == null) return;
    if (mounted) setState(() => _isTimesheetLoading = true);
    try {
      final metrics = await _fetchTimesheetMetrics(state: _currentUserState!, facility: _currentUserFacility!, year: _selectedTimesheetYear, month: _selectedTimesheetMonth);
      if (!_timesheetStreamController.isClosed) _timesheetStreamController.add(metrics);
    } catch (e, s) {
      debugPrint("Error loading timesheet metrics: $e\n$s");
      if (!_timesheetStreamController.isClosed) _timesheetStreamController.addError(e);
    } finally {
      if (mounted) setState(() => _isTimesheetLoading = false);
    }
  }

  Future<TimesheetMetrics> _fetchTimesheetMetrics({required String state, required String facility, required int year, required int month}) async {
    // Filter by facility as well.
    final facilityStaffQuery = _firestore.collection('Staff')
        .where('state', isEqualTo: state)
        .where('location', isEqualTo: facility)
        .where('staffCategory', isEqualTo: 'Facility Staff');

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
      drawer: drawer4(context),
      appBar: AppBar(
        title: Text('${_currentUserFacility ?? "Facility"} Dashboard', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [maroonPrimary, Color(0xFF2E0215)], // Maroon gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: StreamBuilder<String>(
                stream: _timeStreamController.stream,
                initialData: DateFormat('hh:mm:ss a').format(DateTime.now()),
                builder: (context, snapshot) {
                  return Text( snapshot.data ?? '', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),);
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
      body: SelectionArea( // Wrapped in SelectionArea for copyable text
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
                    return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("An error occurred: ${snapshot.error}", style: const TextStyle(color: Colors.red))));
                  }
                  if (!snapshot.hasData || snapshot.data!.staffList.isEmpty) return Center(child: Text("No 'Facility Staff' found for $_currentUserFacility."));
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
        segments: const [
          ButtonSegment(value: AttendanceFilter.all, label: Text('All'), icon: Icon(Icons.people)),
          ButtonSegment(value: AttendanceFilter.onTime, label: Text('On Time'), icon: Icon(Icons.timer_outlined)),
          ButtonSegment(value: AttendanceFilter.late, label: Text('Late'), icon: Icon(Icons.history_toggle_off)),
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
    if (screenWidth > 1600) { crossAxisCount = 3; childAspectRatio = 1.3; }
    else if (screenWidth > 1100) { crossAxisCount = 2; childAspectRatio = 1.2; }
    else if (screenWidth > 750) { crossAxisCount = 2; childAspectRatio = 1.0; }
    else { crossAxisCount = 1; childAspectRatio = 1.1; }

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
              _buildCard(title: 'Timesheet Status (This Month)', child: _buildTimesheetStatusCard()),
              _buildCard(title: 'Best Team Player (This Month)', child: _buildBestTeamPlayerCard(data)),
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
                  Flexible(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18), overflow: TextOverflow.ellipsis)),
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

  Widget _buildSummaryGrid(DashboardData data) {
    final screenWidth = MediaQuery.of(context).size.width;
    double childAspectRatio;
    if (screenWidth < 600) { childAspectRatio = 0.9; }
    else if (screenWidth < 900) { childAspectRatio = 1.3; }
    else if (screenWidth < 1200) { childAspectRatio = 1.9; }
    else { childAspectRatio = 2.3; }

    return GridView.count(
      crossAxisCount: 1, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: childAspectRatio,
      children: [
        _buildCard(
          title: 'Today\'s Attendance Overview',
          child: _buildAttendanceChart(data),
        ),
      ],
    );
  }

  Widget _buildAttendanceChart(DashboardData data) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 750;

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
    final chartData = [ ChartData('On Time', onTimeCount, Colors.green.shade400), ChartData('Absent', absentCount, Colors.orange.shade400), ChartData('Late', lateCount, Colors.red.shade400)];

    final doughnutChartWidget = SfCircularChart(
      tooltipBehavior: TooltipBehavior(enable: true, format: 'point.x: point.y'),
      series: <CircularSeries<ChartData, String>>[
        DoughnutSeries<ChartData, String>(
          dataSource: chartData.where((d) => d.value > 0).toList(),
          xValueMapper: (data, _) => data.category, yValueMapper: (data, _) => data.value,
          pointColorMapper: (data, _) => data.color,
          dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside, labelIntersectAction: LabelIntersectAction.none,),
          innerRadius: '70%',
        )
      ],
      annotations: <CircularChartAnnotation>[
        CircularChartAnnotation(
          widget: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("${presentIds.length}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text("Clocked In /\n${data.staffList.length} Total", textAlign: TextAlign.center),
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
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FacilitySupervisorAttendanceAnalysisPage())),
            icon: const Icon(Icons.analytics_outlined, size: 16),
            label: const Text("View Full Analysis"),
          ),
        ),
        Expanded(
          child: isMobile
              ? Column(
            children: [
              Expanded(child: doughnutChartWidget),
              const SizedBox(height: 24),
              _buildPunctualityChampion(championInfo, championRecord),
            ],
          )
              : Row(
            children: [
              Expanded(flex: 4, child: _buildPunctualityChampion(championInfo, championRecord)),
              Expanded(flex: 3, child: doughnutChartWidget),
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
          children: [ Icon(Icons.shield_moon_outlined, size: 80, color: Colors.grey), SizedBox(height: 8), Text("Punctuality Champion", style: TextStyle(fontWeight: FontWeight.bold)), Text("No punctual staff today", style: TextStyle(color: Colors.grey))]);
    }
    final championImage = champion.imageUrl;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40, backgroundColor: Colors.grey.shade200,
          backgroundImage: (championImage != null && championImage.isNotEmpty) ? NetworkImage(championImage) : null,
          child: (championImage == null || championImage.isEmpty) ? Icon(champion.gender == 'Male' ? Icons.person : Icons.person_2, size: 50, color: Colors.grey.shade700) : null,
        ),
        const SizedBox(height: 8),
        const Text("Punctuality Champion", style: TextStyle(fontWeight: FontWeight.bold)),
        Text(champion.name, textAlign: TextAlign.center),
        Text(record.clockInTime, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildYetToClockInCard(DashboardData data) {
    final yetToClockInList = data.yetToClockIn;
    if (yetToClockInList.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.green, size: 40), SizedBox(height: 8), Text("All staff have clocked in!", textAlign: TextAlign.center)]));
    }
    return ListView.builder(
      itemCount: yetToClockInList.length,
      itemBuilder: (context, index) {
        final staff = yetToClockInList[index];
        return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: Colors.red.shade100, child: Text(staff.name.isNotEmpty ? staff.name[0] : '?', style: TextStyle(color: Colors.red.shade800))), title: Text(staff.name, style: const TextStyle(fontSize: 14)), subtitle: Text(staff.designation ?? 'N/A', style: const TextStyle(fontSize: 12)));
      },
    );
  }

  Widget _buildFacilityClockInCard(DashboardData data) {
    return data.attendanceRecords.isEmpty ? const Center(child: Text("No clock-in records found.")) : ListView.builder(
      itemCount: data.attendanceRecords.length,
      itemBuilder: (context, index) {
        final record = data.attendanceRecords[index];
        return ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(record.staffName, style: const TextStyle(fontWeight: FontWeight.w500)), subtitle: Text('Clocked-in at ${DateFormat('dd-MMM').format(record.timestamp)}'), isThreeLine: false, trailing: Text(record.clockInTime, style: TextStyle(fontWeight: FontWeight.bold, color: record.isLate ? Colors.red : Colors.green)));
      },
    );
  }

  Widget _buildTimesheetStatusCard() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<TimesheetMetrics>(
            stream: _timesheetStreamController.stream,
            builder: (context, snapshot) {
              if (_isTimesheetLoading) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return const Center(child: Text("Error", style: TextStyle(color: Colors.red)));
              if (!snapshot.hasData || snapshot.data!.totalExpected == 0) return const Center(child: Text("No Data", style: TextStyle(color: Colors.grey)));
              final metrics = snapshot.data!;
              final pendingSubmission = metrics.totalExpected - metrics.totalSubmitted;
              final completionPercentage = metrics.totalExpected > 0 ? (metrics.fullyApproved / metrics.totalExpected) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatusRow('Expected', '${metrics.totalExpected} Staff', Colors.blue),
                    _buildStatusRow('Pending Submission', '$pendingSubmission Staff', Colors.orange),
                    _buildStatusRow('Pending Approval', '${metrics.pendingApproval} Timesheets', Colors.red),
                    const Spacer(),
                    Text('Overall Approval: ${completionPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: completionPercentage / 100, minHeight: 10, borderRadius: BorderRadius.circular(5), backgroundColor: Colors.grey.shade300, valueColor: const AlwaysStoppedAnimation<Color>(Colors.green)),
                    Align(alignment: Alignment.bottomRight, child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TimesheetReviewPage())), child: const Text('View Details'))),
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
        children: [ Row(children: [Icon(Icons.circle, color: color, size: 10), const SizedBox(width: 8), Text(title)]), Text(count, style: const TextStyle(fontWeight: FontWeight.bold)) ],
      ),
    );
  }

  Widget _buildBestTeamPlayerCard(DashboardData data) {
    if (data.bestPlayer == null) {
      return const Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sentiment_dissatisfied, color: Colors.grey, size: 40),
                SizedBox(height: 8),
                Text(
                  "No survey data for 'Best Player' this month.",
                  textAlign: TextAlign.center,
                )
              ]));
    }

    final votes = data.bestPlayerVotes;
    final bestPlayer = data.bestPlayer!;
    final totalSurveys = data.totalSurveys;

    // Sort votes for chart display
    final sortedVotes = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bestPlayerInfo = data.staffList.firstWhere(
            (s) => s.name == bestPlayer.name,
        orElse: () => StaffInfo(
            id: '', name: bestPlayer.name!, gender: 'Unknown', location: ''));
    final playerImage = bestPlayerInfo.imageUrl;

    return Column(
      children: [
        // Highlight the winner
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.amber.shade100,
          backgroundImage: (playerImage != null && playerImage.isNotEmpty)
              ? NetworkImage(playerImage)
              : null,
          child: (playerImage == null || playerImage.isEmpty)
              ? Icon(
              bestPlayerInfo.gender == 'Male'
                  ? Icons.person
                  : Icons.person_2,
              size: 30,
              color: Colors.amber.shade800)
              : null,
        ),
        const SizedBox(height: 8),
        Text(bestPlayer.name!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text('${votes[bestPlayer.name] ?? 0} Votes (out of $totalSurveys)',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const Divider(height: 16),
        // Chart for all votes
        Expanded(
          child: votes.isEmpty
              ? const Center(child: Text("No votes cast yet."))
              : SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(isVisible: false),
            primaryYAxis: NumericAxis(isVisible: false),
            tooltipBehavior: TooltipBehavior(
                enable: true, header: '', format: 'point.x: point.y votes'),

            // ================== THE FIX IS HERE ==================
            // The list is now correctly typed as <CartesianSeries>
            series: <CartesianSeries>[
              // =====================================================
              BarSeries<MapEntry<String, int>, String>(
                dataSource: sortedVotes,
                xValueMapper: (entry, _) =>
                entry.key.split(' ').first, // Use first name for label
                yValueMapper: (entry, _) => entry.value,
                pointColorMapper: (entry, _) =>
                entry.key == bestPlayer.name
                    ? Colors.amber.shade700
                    : Colors.grey.shade400,
                dataLabelSettings:
                const DataLabelSettings(isVisible: true),
              )
            ],
          ),
        )
      ],
    );
  }

  // --- Gauge Widget ---
  Widget _buildPerformanceGauge(DashboardData data)   {
    // A simple attendance gauge comparing 'Present' to 'Total Expected'
    final totalExpected = data.staffList.length;
    final today = DateTime.now();
    final presentCount = data.attendanceRecords.where((r) => DateFormat('yyyy-MM-dd').format(r.timestamp) == DateFormat('yyyy-MM-dd').format(today)).map((e) => e.staffId).toSet().length;

    final double percentage = totalExpected == 0 ? 0 : (presentCount / totalExpected) * 100;

    return SfCircularChart(
        series: <CircularSeries>[
          RadialBarSeries<ChartData, String>(
            dataSource: [ChartData('Present', percentage, Colors.blue)],
            xValueMapper: (ChartData data, _) => data.category,
            yValueMapper: (ChartData data, _) => data.value,
            maximumValue: 100,
            radius: '80%',
            cornerStyle: CornerStyle.bothCurve,
            innerRadius: '60%',
          )
        ],
        annotations: <CircularChartAnnotation>[
          CircularChartAnnotation(
            widget: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ]
    );
  }

  // --- Leave Request Widget ---
  Widget _buildLeaveRequestCard(DashboardData data) {
    if (data.pendingLeaves.isEmpty) {
      return const Center(child: Text("No pending leave requests."));
    }
    return ListView.builder(
      itemCount: data.pendingLeaves.length,
      itemBuilder: (context, index) {
        final leave = data.pendingLeaves[index];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(leave.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${leave.leaveType} (${DateFormat('MM/dd').format(leave.startDate)} - ${DateFormat('MM/dd').format(leave.endDate)})'),
          trailing: Chip(
            label: Text(leave.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.orange,
            visualDensity: VisualDensity.compact,
          ),
          onTap: () {
            // Navigate to leave approval page if exists
            Navigator.push(context, MaterialPageRoute(builder: (context) => const StateLeaveRequestManagementPage()));
          },
        );
      },
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
        title: Text('Full Clock-In Feed', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5C1A2E), Color(0xFF2E0215)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: records.isEmpty 
          ? Center(child: Text("No clock-in records to display.", style: GoogleFonts.poppins())) 
          : ListView.builder(
              padding: const EdgeInsets.all(16.0), 
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(record.staffName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    subtitle: Text('${record.staffLocation}\n${DateFormat('dd-MMM-yyyy').format(record.timestamp)}', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
                    trailing: Text(
                      record.clockInTime, 
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: record.isLate ? Colors.red.shade700 : Colors.green.shade700)
                    ),
                  ),
                );
              },
            ),
    );
  }
}