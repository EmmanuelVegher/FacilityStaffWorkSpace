// A HIGH-LEVEL HEADQUARTERS DASHBOARD
// REWRITTEN TO USE LIVE, SCALABLE FIRESTORE QUERIES
// ** VERSION 3: CORRECTED NULL-SAFETY AND FINAL FIELD ERRORS **

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../widgets/drawer3.dart'; // Assuming a generic app drawer

// --- WIDGETS AND MODELS ---

// (AnimatedNumberText widget remains the same)
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

// In --- WIDGETS AND MODELS --- section

class StaffInfo {
  final String id;
  final String name;
  final String state;
  final String location;     // Added
  final String emailAddress; // Added

  StaffInfo({
    required this.id,
    required this.name,
    required this.state,
    required this.location,     // Added
    required this.emailAddress, // Added
  });
}

// FIX 2: 'totalStaff' is no longer final to allow for modification during aggregation.
// In --- WIDGETS AND MODELS --- section

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

  // Add this new getter
  int get expectedAttendance => totalStaff - onLeave;

  int get absent => expectedAttendance - present; // Also makes sense to update absent logic
  double get attendancePercentage => expectedAttendance > 0 ? (present / expectedAttendance) * 100 : 0.0;
}

class NationwideSummary {
  int totalStaff = 0;
  int totalPresent = 0;
  int totalLate = 0;
  int totalOnLeave = 0;
  int get totalAbsent => totalStaff - totalPresent - totalOnLeave;

  double get overallAttendancePercentage => (totalStaff - totalOnLeave) > 0 ? (totalPresent / (totalStaff - totalOnLeave)) * 100 : 0.0;
  double get overallPunctualityPercentage => totalPresent > 0 ? ((totalPresent - totalLate) / totalPresent) * 100 : 0.0;
}

class LeaveRequestData {
  final String employeeName;
  final String leaveType;
  final String startDate;
  final String state;
  LeaveRequestData(this.employeeName, this.leaveType, this.startDate, this.state);
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

  // Add this map to store detailed staff info
  Map<String, StaffInfo> _staffMap = {};

  NationwideSummary _nationwideSummary = NationwideSummary();
  List<StateAttendanceData> _attendanceByStateData = [];
  List<Map<String, dynamic>> _liveClockInData = [];
  late List<LeaveRequestData> _leaveRequests;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    setState(() => _isLoading = true);
    await _fetchAvailableStates();
    await _fetchAndProcessData();
    _leaveRequests = getLeaveRequestsHQ();
    if(mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAvailableStates() async {
    try {
      // --- UPDATE THIS LINE ---
      final staffSnapshot = await _firestore
          .collection('Staff')
          .where('staffCategory', isEqualTo: 'Facility Staff') // Add this filter
          .get();

      // FIX 1: Use `whereType<String>()` to filter out nulls and correctly cast the collection type.
      final statesSet = staffSnapshot.docs
          .map((doc) => doc.data()['state'] as String?)
          .whereType<String>() // This filters nulls AND returns a collection of non-nullable Strings.
          .toSet();

      if (mounted) {
        setState(() {
          _states = ['All States', ...statesSet.toList()..sort()];
        });
      }

    } catch (e) {
      debugPrint("Error fetching states: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching states: $e")));
    }
  }

  Future<void> _fetchAndProcessData() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final lateCutoff = DateTime(now.year, now.month, now.day, 9, 0, 0);

    Query<Map<String, dynamic>> staffQuery = _firestore.collection('Staff');

    // Add the filter for "Facility Staff"
    staffQuery = staffQuery.where('staffCategory', isEqualTo: 'Facility Staff');

    if (_selectedState != 'All States') {
      staffQuery = staffQuery.where('state', isEqualTo: _selectedState);
    }

    final staffSnapshot = await staffQuery.get();
    // Update this map creation to include the new fields
    final staffMap = {
      for (var doc in staffSnapshot.docs)
        doc.id: StaffInfo(
            id: doc.id,
            name: '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'.trim(),
            state: doc.data()['state'] ?? 'Unknown',
            // Fetch new fields, with fallbacks for null data
            location: doc.data()['location'] ?? doc.data()['state'] ?? 'N/A',
            emailAddress: doc.data()['emailAddress'] ?? 'No Email Provided'
        )
    };
    final staffIds = staffMap.keys.toList();

    if (staffIds.isEmpty) {
      _resetData();
      return;
    }

    final recordsSnapshot = await _firestore.collectionGroup('Record')
        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
        .where('timestamp', isLessThan: todayEnd)
        .orderBy('timestamp', descending: true)
        .get();

    Map<String, StateAttendanceData> stateDataMap = {};
    for (var staff in staffMap.values) {
      stateDataMap.putIfAbsent(staff.state, () => StateAttendanceData(state: staff.state, totalStaff: 0));
      // This is now valid because `totalStaff` is not final
      stateDataMap[staff.state]!.totalStaff++;
    }

    final List<Map<String, dynamic>> liveFeed = [];
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
        liveFeed.add({
          'fullName': staffInfo.name,
          'state': staffInfo.state,
          'clockIn': DateFormat('hh:mm a').format(timestamp),
          'date': DateFormat('dd-MMMM-yyyy').format(timestamp),
        });
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
        _staffMap = staffMap; // Store the detailed staff map in the state variable
        _attendanceByStateData = stateDataMap.values.toList()..sort((a,b) => a.state.compareTo(b.state));
        _nationwideSummary = summary;
        _liveClockInData = liveFeed;
      });
    }
  }

  void _resetData() {
    if (mounted) {
      setState(() {
        _nationwideSummary = NationwideSummary();
        _attendanceByStateData = [];
        _liveClockInData = [];
      });
    }
  }

  void _onStateChanged(String? newValue) {
    if (newValue == null || newValue == _selectedState) return;
    setState(() {
      _selectedState = newValue;
      _initializeDashboard();
    });
  }

  // --- All UI build methods from here onwards are unchanged ---

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
                  double childAspectRatio = crossAxisCount == 3 ? 2.0 : (crossAxisCount == 2 ? 2.2 : 1.8);

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildLiveClockInCard(),
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

// In class HQDashboardScreenState

// In class HQDashboardScreenState


// In class HQDashboardScreenState

// In class HQDashboardScreenState

// In class HQDashboardScreenState

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
              // --- BAR 1: Total Expected Attendance (Updated) ---
              ColumnSeries<StateAttendanceData, String>(
                dataSource: _attendanceByStateData,
                xValueMapper: (data, _) => data.state,
                yValueMapper: (data, _) => data.expectedAttendance,
                name: 'Total Expected Attendance',
                // 1. Warmer Color
                color: const Color(0xFFE57373), // A soft, warm red
                // 2. Curved Edges
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                // 3. Space between bars
                spacing: 0.2,
                selectionBehavior: SelectionBehavior(enable: true),
                // 4. Data label with total figure
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              // --- BAR 2: Total Present Today (Updated) ---
              ColumnSeries<StateAttendanceData, String>(
                dataSource: _attendanceByStateData,
                xValueMapper: (data, _) => data.state,
                yValueMapper: (data, _) => data.present,
                name: 'Total Present Today',
                // 1. Warmer Color
                color: const Color(0xFFFFB74D), // A warm amber/gold
                // 2. Curved Edges
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                // 3. Space between bars
                spacing: 0.2,
                selectionBehavior: SelectionBehavior(enable: true),
                // 4. Data label with total figure AND percentage
                dataLabelSettings: DataLabelSettings(
                  isVisible: true,
                  builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                    final stateData = data as StateAttendanceData;
                    final percentage = stateData.attendancePercentage;

                    // Don't show a label if no one is present
                    if (stateData.present <= 0) {
                      return const SizedBox.shrink();
                    }

                    // Combine the total count and the percentage in one string
                    final labelText = '${stateData.present} (${percentage.toStringAsFixed(0)}%)';

                    return Text(
                      labelText,
                      style: const TextStyle(
                        // 5. Black text color
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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


  void _showUsersInStateDialog(String state) {
    // Filter the staff list based on the selected state from the chart
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
                ? const Center(
                child: Text('No user data available for this state.'))
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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }




  Widget _buildLiveClockInCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Clock-In Feed', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Expanded(
              child: _liveClockInData.isEmpty
                  ? const Center(child: Text("No clock-ins to display for the selected criteria."))
                  : ListView.builder(
                itemCount: _liveClockInData.length,
                itemBuilder: (context, index) {
                  final data = _liveClockInData[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(data['fullName'], style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(data['state']),
                    trailing: Text(data['clockIn'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimesheetStatusCard() {
    int expected = _nationwideSummary.totalStaff;
    int pendingSubmission = (expected * 0.15).round();
    int pendingApproval = (expected * 0.08).round();
    double completion = expected > 0 ? ((expected - pendingSubmission) / expected) * 100 : 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timesheet Status (Nationwide)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStatusRow('Expected Submissions', '$expected Staff', Colors.blue),
            _buildStatusRow('Pending Submissions', '$pendingSubmission Staff', Colors.orange),
            _buildStatusRow('Pending Approvals', '$pendingApproval Timesheets', Colors.red),
            const Spacer(),
            Text('Overall Completion: ${completion.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: completion / 100, minHeight: 10, borderRadius: BorderRadius.circular(5)),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(onPressed: () {}, child: const Text('View Details')),
            )
          ],
        ),
      ),
    );
  }

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
              child: _leaveRequests.isEmpty
                  ? const Center(child: Text("No pending leave requests."))
                  : ListView.builder(
                itemCount: _leaveRequests.length,
                itemBuilder: (context, index) {
                  final request = _leaveRequests[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(request.employeeName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${request.state} - ${request.leaveType}'),
                    trailing: Text(request.startDate, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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
          Row(children: [ Icon(Icons.circle, color: color, size: 10), const SizedBox(width: 8), Text(title) ]),
          Text(count, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// Mock data remains the same
List<LeaveRequestData> getLeaveRequestsHQ() {
  return [
    LeaveRequestData('John Doe', 'Vacation', '2024-08-10', 'Lagos'),
    LeaveRequestData('Jane Smith', 'Sick Leave', '2024-08-12', 'Abuja'),
    LeaveRequestData('Chinedu Okeke', 'Personal', '2024-08-11', 'Rivers'),
  ];
}