// lib/pages/dashboards/state_performance_impact_dashboard.dart

// A STATE-LEVEL DASHBOARD FOR STRATEGIC ANALYSIS AND PRESENTATIONS
// This page synthesizes data from multiple modules to answer key business questions
// regarding platform adoption, behavioral change, staff performance, and programmatic impact.
// ** VERSION 1.0: Aligned with HQ report for state-specific view **

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../widgets/drawer2.dart'; // State-level drawer

// --- DATA MODELS (from HQ Report) ---

class StaffDetails {
  final String id, name, state, location, category, phone, email;
  StaffDetails({
    required this.id, required this.name, required this.state, required this.location,
    required this.category, required this.phone, required this.email,
  });
}

class RecentlyInactiveStaff {
  final StaffDetails staffDetails;
  final DateTime lastAttendanceDate;
  final int daysSinceLastAttendance;
  RecentlyInactiveStaff({
    required this.staffDetails, required this.lastAttendanceDate, required this.daysSinceLastAttendance,
  });
}

class AttendanceDataPoint {
  final String staffId;
  final DateTime clockInTime;
  final String state;
  AttendanceDataPoint({required this.staffId, required this.clockInTime, required this.state});
}

class _PunctualityTrendData {
  final DateTime date;
  final int earlyCount;
  final int lateCount;
  _PunctualityTrendData({required this.date, required this.earlyCount, required this.lateCount});
}

class _ChartData {
  final String category;
  final double value;
  _ChartData(this.category, this.value);
}

class _PunctualityCounter {
  int early = 0;
  int late = 0;
}

// --- DataTableSources for Paginated Tables ---
class _InactiveStaffDataSource extends DataTableSource {
  final List<StaffDetails> _staffList;
  _InactiveStaffDataSource(this._staffList);

  @override
  DataRow? getRow(int index) {
    if (index >= _staffList.length) return null;
    final staff = _staffList[index];
    return DataRow.byIndex(index: index, cells: [
      DataCell(Text(staff.name)),
      DataCell(Text(staff.state)),
      DataCell(Text(staff.location)),
      DataCell(Text(staff.phone)),
      DataCell(Text(staff.email)),
    ]);
  }
  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => _staffList.length;
  @override
  int get selectedRowCount => 0;
}

class _RecentlyInactiveStaffDataSource extends DataTableSource {
  final List<RecentlyInactiveStaff> _staffList;
  final DateFormat _dateFormatter = DateFormat('dd-MMM-yyyy');
  _RecentlyInactiveStaffDataSource(this._staffList);

  @override
  DataRow? getRow(int index) {
    if (index >= _staffList.length) return null;
    final data = _staffList[index];
    return DataRow.byIndex(index: index, cells: [
      DataCell(Text(data.staffDetails.name)),
      DataCell(Text(_dateFormatter.format(data.lastAttendanceDate))),
      DataCell(Text('${data.daysSinceLastAttendance} days ago')),
      DataCell(Text(data.staffDetails.location)),
      DataCell(Text(data.staffDetails.phone)),
      DataCell(Text(data.staffDetails.email)),
    ]);
  }
  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => _staffList.length;
  @override
  int get selectedRowCount => 0;
}


// --- MAIN WIDGET: StatePerformanceImpactDashboardPage ---

class StatePerformanceImpactDashboardPage extends StatefulWidget {
  const StatePerformanceImpactDashboardPage({super.key});

  @override
  _StatePerformanceImpactDashboardPageState createState() => _StatePerformanceImpactDashboardPageState();
}

class _StatePerformanceImpactDashboardPageState extends State<StatePerformanceImpactDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- UI & State Management ---
  bool _isLoading = true; // Start loading immediately
  bool _isInitialState = true;
  String? _errorMessage;
  bool _isFacilitiesLoading = false;

  // --- Filter State ---
  DateTime _startDate = DateTime(DateTime.now().year - 1, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime.now();
  List<String> _availableFacilities = ['All Facilities'];
  List<String> _selectedFacilities = ['All Facilities'];

  // --- Current State (determined from user context) ---
  String _currentState = '';

  // --- State-Specific Data ---
  List<_ChartData> _adoptionData = [], _activeStaffData = [];
  List<_PunctualityTrendData> _punctualityTrend = [];
  List<StaffDetails> _inactiveStaffOnLeave = [], _completelyInactiveStaff = [];
  List<RecentlyInactiveStaff> _recentlyInactiveStaff = [];
  List<_ChartData> _moduleActivityData = [];
  Map<String, List<String>> _activeFacilitiesByModule = {};
  int _totalFilteredFacilities = 0;
  int _callTrackerTotalCalls = 0, _eacTotalCalls = 0, _vlTotalCalls = 0;
  int _callTrackerTotalDuration=0, _callTrackerOutgoingAnswered=0, _callTrackerMissed=0, _callTrackerIncomingAnswered=0;
  double _callTrackerOutgoingCost=0.0, _callTrackerIncomingCost=0.0;
  int _eacTotalDuration=0, _eacOutgoingAnswered=0, _eacMissed=0, _eacIncomingAnswered=0;
  double _eacOutgoingCost=0.0, _eacIncomingCost=0.0;
  int _vlTotalDuration=0, _vlOutgoingAnswered=0, _vlMissed=0, _vlIncomingAnswered=0;
  double _vlOutgoingCost=0.0, _vlIncomingCost=0.0;
  final double _costPerSecond = 0.25;

  @override
  void initState() {
    super.initState();
    _initializeStateAndFilters();
  }

  void _clearData() {
    setState(() {
      _adoptionData = []; _activeStaffData = []; _punctualityTrend = [];
      _inactiveStaffOnLeave = []; _completelyInactiveStaff = []; _recentlyInactiveStaff = [];
      _moduleActivityData = []; _activeFacilitiesByModule = {}; _totalFilteredFacilities = 0;
      _callTrackerTotalCalls = 0; _callTrackerTotalDuration=0; _callTrackerOutgoingAnswered=0; _callTrackerMissed=0; _callTrackerIncomingAnswered=0; _callTrackerOutgoingCost=0.0; _callTrackerIncomingCost=0.0;
      _eacTotalCalls = 0; _eacTotalDuration=0; _eacOutgoingAnswered=0; _eacMissed=0; _eacIncomingAnswered=0; _eacOutgoingCost=0.0; _eacIncomingCost=0.0;
      _vlTotalCalls = 0; _vlTotalDuration=0; _vlOutgoingAnswered=0; _vlMissed=0; _vlIncomingAnswered=0; _vlOutgoingCost=0.0; _vlIncomingCost=0.0;
    });
  }

  Future<void> _initializeStateAndFilters() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final userDoc = await _firestore.collection('Staff').doc(user.uid).get();
      final userState = userDoc.data()?['state'] as String?;
      if (userState == null || userState.isEmpty) throw Exception("Unable to determine user's state");

      if (mounted) setState(() => _currentState = userState);
      await _loadFacilitiesForState(userState);

      // Automatically load data on initial load
      await _loadDashboardData();

    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error initializing dashboard: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFacilitiesForState(String state) async {
    setState(() => _isFacilitiesLoading = true);
    try {
      final facilitySnapshot = await _firestore.collection('Location').doc(state).collection(state).where('category', isEqualTo: 'Facility').get();
      final facilities = facilitySnapshot.docs
          .map((doc) => doc.data()['LocationName'] as String?)
          .where((name) => name != null && name.isNotEmpty).cast<String>().toList()..sort();
      if (mounted) setState(() => _availableFacilities.addAll(facilities));
    } catch (e) {
      if (mounted) _showSnackBar("Error fetching facility lists.");
    } finally {
      if (mounted) setState(() => _isFacilitiesLoading = false);
    }
  }

  Future<void> _loadDashboardData() async {
    if (_currentState.isEmpty) {
      setState(() => _errorMessage = "User state not found. Cannot load data.");
      return;
    }
    setState(() { _isLoading = true; _isInitialState = false; _errorMessage = null; _clearData(); });

    try {
      final filteredStaffDetailsMap = await _getFilteredStaffDetails();
      if (filteredStaffDetailsMap.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final futures = [
        _firestore.collectionGroup('Record').where('state', isEqualTo: _currentState).get(),
        _firestore.collectionGroup('Leave Request').where('state', isEqualTo: _currentState).get(),
        _firestore.collection('CallLogs').where('trackerFacilityState', isEqualTo: _currentState).where('dateTracked', isGreaterThanOrEqualTo: _startDate).where('dateTracked', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1))).get(),
        _firestore.collection('EacCallLogs').where('trackerState', isEqualTo: _currentState).where('dateTracked', isGreaterThanOrEqualTo: _startDate).where('dateTracked', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1))).get(),
        _firestore.collection('VlCallLogs').where('trackerState', isEqualTo: _currentState).where('callDateTime', isGreaterThanOrEqualTo: _startDate).where('callDateTime', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1))).get(),
      ];
      final results = await Future.wait(futures);

      final allRecordsSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final allLeaveSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final callLogsSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final eacLogsSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
      final vlLogsSnapshot = results[4] as QuerySnapshot<Map<String, dynamic>>;

      _processAllData(filteredStaffDetailsMap, allRecordsSnapshot, allLeaveSnapshot, callLogsSnapshot, eacLogsSnapshot, vlLogsSnapshot);
    } catch (e, s) {
      debugPrint("Error loading report data: $e\n$s");
      if(mounted) setState(() => _errorMessage = "An error occurred. Check for missing data fields or required indexes.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processAllData( Map<String, StaffDetails> filteredStaffMap, QuerySnapshot<Map<String, dynamic>> allRecords, QuerySnapshot<Map<String, dynamic>> allLeave, QuerySnapshot<Map<String, dynamic>> callLogs, QuerySnapshot<Map<String, dynamic>> eacLogs, QuerySnapshot<Map<String, dynamic>> vlLogs ) {
    _totalFilteredFacilities = filteredStaffMap.values.where((s) => s.category == 'Facility Staff' && s.location.isNotEmpty).map((s) => s.location).toSet().length;

    final staffIdToStateMap = { for (var staff in filteredStaffMap.values) staff.id: staff.state };
    _processCallMetrics(callLogs.docs, staffIdToStateMap);
    _processEacMetrics(eacLogs.docs, staffIdToStateMap);
    _processVlMetrics(vlLogs.docs, staffIdToStateMap);
    _processModuleActivityData(callLogs.docs, eacLogs.docs, vlLogs.docs, staffIdToStateMap);

    final allStaffWithAttendance = allRecords.docs.map((doc) => doc.reference.parent.parent!.id).toSet();
    final allStaffWithLeave = allLeave.docs.map((doc) => doc.reference.parent.parent!.id).toSet();
    final facilityStaffIds = filteredStaffMap.values.where((s) => s.category == 'Facility Staff').map((s) => s.id).toSet();

    final completelyInactive = facilityStaffIds.difference(allStaffWithAttendance).difference(allStaffWithLeave);
    _completelyInactiveStaff = completelyInactive.map((id) => filteredStaffMap[id]).whereType<StaffDetails>().toList();

    final onLeaveNoAttendance = allStaffWithLeave.difference(allStaffWithAttendance);
    final inactiveOnLeave = facilityStaffIds.intersection(onLeaveNoAttendance);
    _inactiveStaffOnLeave = inactiveOnLeave.map((id) => filteredStaffMap[id]).whereType<StaffDetails>().toList();

    _calculateRecentlyInactiveStaff(allRecords, filteredStaffMap);

    final List<AttendanceDataPoint> dateFilteredAttendance = [];
    for (final doc in allRecords.docs) {
      final staffId = doc.reference.parent.parent!.id;
      final staffDetails = filteredStaffMap[staffId];
      if (staffDetails != null) {
        final data = doc.data();
        if (data['timestamp'] is Timestamp) {
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          if (timestamp.isAfter(_startDate.subtract(const Duration(microseconds: 1))) && timestamp.isBefore(_endDate.add(const Duration(days: 1)))) {
            dateFilteredAttendance.add(AttendanceDataPoint(staffId: staffId, clockInTime: timestamp, state: staffDetails.state));
          }
        }
      }
    }
    _processChartData(dateFilteredAttendance);

    setState((){}); // Trigger rebuild with new data
  }

  void _calculateRecentlyInactiveStaff(QuerySnapshot<Map<String, dynamic>> allRecords, Map<String, StaffDetails> filteredStaffMap) {
    final Map<String, DateTime> lastAttendanceMap = {};
    final now = DateTime.now();
    for (final doc in allRecords.docs) {
      final staffId = doc.reference.parent.parent!.id;
      if (filteredStaffMap.containsKey(staffId)) {
        final data = doc.data();
        if (data['timestamp'] is Timestamp) {
          final attendanceDate = (data['timestamp'] as Timestamp).toDate();
          if (!lastAttendanceMap.containsKey(staffId) || attendanceDate.isAfter(lastAttendanceMap[staffId]!)) {
            lastAttendanceMap[staffId] = attendanceDate;
          }
        }
      }
    }

    final List<RecentlyInactiveStaff> inactiveList = [];
    lastAttendanceMap.forEach((staffId, lastDate) {
      final daysSince = now.difference(lastDate).inDays;
      if (daysSince > 3) {
        final staffDetails = filteredStaffMap[staffId];
        if (staffDetails != null) {
          inactiveList.add(RecentlyInactiveStaff(staffDetails: staffDetails, lastAttendanceDate: lastDate, daysSinceLastAttendance: daysSince));
        }
      }
    });

    inactiveList.sort((a, b) => b.daysSinceLastAttendance.compareTo(a.daysSinceLastAttendance));
    _recentlyInactiveStaff = inactiveList;
  }

  // --- PROCESSING LOGIC (Copied & simplified from HQ Report) ---

  void _processCallMetrics(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Map<String, String> staffStateMap) {
    for (var doc in docs) {
      final data = doc.data();
      final duration = data['callDuration'] as int? ?? 0;
      final status = (data['callStatus'] as String?)?.toLowerCase().trim() ?? '';
      _callTrackerTotalCalls++; _callTrackerTotalDuration += duration;
      if (status == 'answered') {
        _callTrackerOutgoingAnswered++; _callTrackerOutgoingCost += duration * _costPerSecond;
      } else if (status == 'incoming answered') {
        _callTrackerIncomingAnswered++; _callTrackerIncomingCost += duration * _costPerSecond;
      } else if (status.contains('missed') || status.contains('not answered') || status.contains('failed')) {
        _callTrackerMissed++;
      }
    }
  }

  void _processEacMetrics(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Map<String, String> staffStateMap) {
    for (var doc in docs) {
      final data = doc.data();
      final duration = data['callDuration'] as int? ?? 0;
      final status = (data['trackingOutcome'] as String?)?.toLowerCase().trim() ?? '';
      _eacTotalCalls++; _eacTotalDuration += duration;
      if (status == 'answered' || status == 'completed') {
        _eacOutgoingAnswered++; _eacOutgoingCost += duration * _costPerSecond;
      } else if (status == 'incoming answered') {
        _eacIncomingAnswered++; _eacIncomingCost += duration * _costPerSecond;
      } else if (status.contains('missed') || status.contains('not answered') || status.contains('failed')) {
        _eacMissed++;
      }
    }
  }

  void _processVlMetrics(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Map<String, String> staffStateMap) {
    for (var doc in docs) {
      final data = doc.data();
      final duration = data['callDurationInSeconds'] as int? ?? 0;
      final status = (data['callStatus'] as String?)?.toLowerCase().trim() ?? '';
      _vlTotalCalls++; _vlTotalDuration += duration;
      if (status == 'answered' || status == 'completed') {
        _vlOutgoingAnswered++; _vlOutgoingCost += duration * _costPerSecond;
      } else if (status == 'incoming answered') {
        _vlIncomingAnswered++; _vlIncomingCost += duration * _costPerSecond;
      } else if (status.contains('missed') || status.contains('not answered') || status.contains('failed')) {
        _vlMissed++;
      }
    }
  }

  void _processModuleActivityData(List<QueryDocumentSnapshot<Map<String, dynamic>>> callDocs, List<QueryDocumentSnapshot<Map<String, dynamic>>> eacDocs, List<QueryDocumentSnapshot<Map<String, dynamic>>> vlDocs, Map<String, String> staffStateMap) {
    final Set<String> callFacs = {}, eacFacs = {}, vlFacs = {};
    for(var doc in callDocs){
      final facility = doc.data()['trackerFacilityLocation'] as String?; if (facility != null && facility.isNotEmpty) callFacs.add(facility);
    }
    for(var doc in eacDocs){
      final facility = doc.data()['trackerFacilityLocation'] as String?; if (facility != null && facility.isNotEmpty) eacFacs.add(facility);
    }
    for(var doc in vlDocs){
      final facility = doc.data()['trackerFacility'] as String?; if (facility != null && facility.isNotEmpty) vlFacs.add(facility);
    }
    _moduleActivityData = [
      _ChartData('Call Tracker', callFacs.length.toDouble()),
      _ChartData('EAC', eacFacs.length.toDouble()),
      _ChartData('Viral Load', vlFacs.length.toDouble()),
    ];
    _activeFacilitiesByModule = {
      'Call Tracker': callFacs.toList()..sort(), 'EAC': eacFacs.toList()..sort(), 'Viral Load': vlFacs.toList()..sort(),
    };
  }

  void _processChartData(List<AttendanceDataPoint> data) {
    if (data.isEmpty) return;
    final monthFormat = DateFormat('MMM yyyy');
    final dayFormat = DateFormat('yyyy-MM-dd');

    final Map<String, _PunctualityCounter> dailyPunctuality = {};
    for (var record in data) {
      final dateKey = dayFormat.format(record.clockInTime);
      final eightAm = DateTime(record.clockInTime.year, record.clockInTime.month, record.clockInTime.day, 8, 0, 1);
      final counter = dailyPunctuality.putIfAbsent(dateKey, () => _PunctualityCounter());
      if (record.clockInTime.isBefore(eightAm)) counter.early++; else counter.late++;
    }
    _punctualityTrend = dailyPunctuality.entries.map((entry) {
      return _PunctualityTrendData(date: dayFormat.parse(entry.key), earlyCount: entry.value.early, lateCount: entry.value.late);
    }).toList()..sort((a,b) => a.date.compareTo(b.date));

    final Map<String, Set<String>> monthlyActiveStaff = {};
    for (var record in data) {
      final monthKey = monthFormat.format(record.clockInTime);
      monthlyActiveStaff.putIfAbsent(monthKey, () => {}).add(record.staffId);
    }
    _activeStaffData = monthlyActiveStaff.entries.map((entry) => _ChartData(entry.key, entry.value.length.toDouble())).toList()
      ..sort((a, b) => monthFormat.parse(a.category).compareTo(monthFormat.parse(b.category)));

    data.sort((a, b) => a.clockInTime.compareTo(b.clockInTime));
    final Map<String, DateTime> firstRecordPerStaff = {};
    for (var record in data) { firstRecordPerStaff.putIfAbsent(record.staffId, () => record.clockInTime); }

    final Map<String, int> monthlyAdoptionCounts = {};
    firstRecordPerStaff.forEach((staffId, firstDate) {
      final monthKey = monthFormat.format(firstDate);
      monthlyAdoptionCounts[monthKey] = (monthlyAdoptionCounts[monthKey] ?? 0) + 1;
    });
    _adoptionData = monthlyAdoptionCounts.entries.map((entry) => _ChartData(entry.key, entry.value.toDouble())).toList()
      ..sort((a, b) => monthFormat.parse(a.category).compareTo(monthFormat.parse(b.category)));
  }

  Future<Map<String, StaffDetails>> _getFilteredStaffDetails() async {
    List<String> facilitiesToQuery = _selectedFacilities.contains('All Facilities') ? [] : _selectedFacilities;

    Query<Map<String, dynamic>> staffQuery = _firestore.collection('Staff').where('state', isEqualTo: _currentState);
    if (facilitiesToQuery.isNotEmpty) {
      staffQuery = staffQuery.where('location', whereIn: facilitiesToQuery);
    }

    final staffSnapshot = await staffQuery.get();
    return { for (var doc in staffSnapshot.docs) doc.id: StaffDetails(
      id: doc.id, name: "${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}".trim(), state: doc.data()['state'] ?? 'N/A',
      location: doc.data()['location'] ?? 'N/A', category: doc.data()['staffCategory'] ?? 'Unknown', phone: doc.data()['mobile'] ?? 'N/A',
      email: doc.data()['emailAddress'] ?? 'N/A',
    )};
  }

  // --- WIDGET BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    bool hasData = _adoptionData.isNotEmpty || _activeStaffData.isNotEmpty || _recentlyInactiveStaff.isNotEmpty || _completelyInactiveStaff.isNotEmpty || _moduleActivityData.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text("Performance Impact - $_currentState", style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: drawer2(context),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Stack(
              children: [
                if (_errorMessage != null)
                  _buildMessageDisplay(Icons.error_outline, Colors.red, "An Error Occurred", _errorMessage!)
                else if (_isInitialState)
                  _buildMessageDisplay(Icons.filter_list, Colors.grey, "Awaiting Analysis", "Please select filters and click 'Load Dashboard' to begin.")
                else if (!_isLoading && !hasData)
                    _buildMessageDisplay(Icons.search_off, Colors.orange, "No Data Found", "No data was found for the selected criteria.")
                  else
                    _buildDashboardBody(),

                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center( child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 16), Text("Analyzing Data...", style: TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none))])),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    String facilityButtonText = _selectedFacilities.contains('All Facilities') ? 'All Facilities' : _selectedFacilities.length == 1 ? _selectedFacilities.first : '${_selectedFacilities.length} Facilities';

    return Card(
      margin: const EdgeInsets.all(8.0), elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _showDateRangePicker, icon: const Icon(Icons.date_range_outlined),
              label: Text('${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            ),
            _buildFilterChip("Facility", facilityButtonText, Icons.business_center, () {
              _showMultiSelectDialog(
                title: 'Select Facilities', allOptions: _availableFacilities, selectedOptions: _selectedFacilities, allKeyword: 'All Facilities', onConfirm: (results) => setState(() => _selectedFacilities = results),
              );
            }, disabled: _isFacilitiesLoading),
            ElevatedButton.icon(
              icon: const Icon(Icons.analytics_outlined), label: const Text('Load Report'),
              onPressed: _isLoading ? null : _loadDashboardData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF722F37), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildChartCard(title: "New User Adoption in $_currentState", subtitle: "Staff who recorded their first attendance each month.", chart: _buildAdoptionBarChart(_adoptionData), isWide: true),
          const SizedBox(height: 24),
          _buildChartCard(title: "Monthly Active Staff Trend in $_currentState", subtitle: "Unique staff with at least one record each month.", chart: _buildActiveStaffLineChart(_activeStaffData), isWide: true),
          const SizedBox(height: 24),
          _buildChartCard(title: "Daily Clock-in Punctuality Trend in $_currentState", subtitle: "Daily count of early vs. late clock-in records.", chart: _buildPunctualityTrendChart(_punctualityTrend), isWide: true),
          const SizedBox(height: 24),
          _buildRecentlyInactiveStaffSection(_recentlyInactiveStaff),
          const SizedBox(height: 24),
          _buildCompletelyInactiveStaffSection(_completelyInactiveStaff),
          const SizedBox(height: 24),
          _buildInactiveStaffOnLeaveSection(_inactiveStaffOnLeave),
          const SizedBox(height: 24),
          _buildModuleActivitySection(_moduleActivityData, _activeFacilitiesByModule, _totalFilteredFacilities),
          const SizedBox(height: 24),
          _buildMetricSummarySection(),
        ],
      ),
    );
  }

  Widget _buildRecentlyInactiveStaffSection(List<RecentlyInactiveStaff> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    return _ScrollablePaginatedTable(
      header: Row(children: [
        Icon(Icons.watch_later_outlined, color: Colors.blue.shade800),
        const SizedBox(width: 8),
        Expanded(child: Text("Staffs whose last clock-in > 3 days (${data.length})", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900), overflow: TextOverflow.ellipsis)),
      ]),
      columns: const [ DataColumn(label: Text('Staff Name')), DataColumn(label: Text('Last Clock-in Date')), DataColumn(label: Text('Days since last clock-in')), DataColumn(label: Text('Location')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Email')), ],
      source: _RecentlyInactiveStaffDataSource(data),
    );
  }

  Widget _buildCompletelyInactiveStaffSection(List<StaffDetails> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    return _ScrollablePaginatedTable(
      header: Row(children: [
        Icon(Icons.no_accounts_outlined, color: Colors.red.shade800),
        const SizedBox(width: 8),
        Expanded(child: Text("Completely Inactive 'Facility Staff' (${data.length})", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900), overflow: TextOverflow.ellipsis)),
      ]),
      columns: const [ DataColumn(label: Text('Staff Name')), DataColumn(label: Text('State')), DataColumn(label: Text('Location')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Email')), ],
      source: _InactiveStaffDataSource(data),
    );
  }

  Widget _buildInactiveStaffOnLeaveSection(List<StaffDetails> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    return _ScrollablePaginatedTable(
      header: Row(children: [
        Icon(Icons.person_off_outlined, color: Colors.orange.shade800),
        const SizedBox(width: 8),
        Expanded(child: Text("Staff on leave with no attendance (${data.length})", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900), overflow: TextOverflow.ellipsis)),
      ]),
      columns: const [ DataColumn(label: Text('Staff Name')), DataColumn(label: Text('State')), DataColumn(label: Text('Location')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Email')), ],
      source: _InactiveStaffDataSource(data),
    );
  }

  Widget _buildModuleActivitySection(List<_ChartData> moduleData, Map<String, List<String>> facilityData, int totalFacilities) {
    if (moduleData.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey<String>('moduleActivityExpansion_${moduleData.hashCode}'),
        initiallyExpanded: true,
        backgroundColor: Colors.blue.shade50, collapsedBackgroundColor: Colors.blue.shade50,
        leading: Icon(Icons.phone_in_talk_outlined, color: Colors.blue.shade800),
        title: Text("Call tracking Module", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
        subtitle: const Text("Number of unique facilities using each communication module."),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(spacing: 24, runSpacing: 24, alignment: WrapAlignment.center, children: [
              SizedBox(width: 400, height: 350, child: _buildModuleActivityChart(moduleData, totalFacilities)),
              SizedBox(width: 400, height: 350, child: _buildActiveFacilitiesTable(facilityData))
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Call Tracker summary", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: const Color(0xFF722F37))),
        const SizedBox(height: 4),
        Text("Aggregate call metrics for $_currentState within the selected date range.", style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16.0),
        Wrap(
          spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
          children: [
            _buildModuleSummaryCard(title: "Call Tracker", icon: Icons.phone_in_talk, totalCalls: _callTrackerTotalCalls, totalDuration: _callTrackerTotalDuration, outgoingAnswered: _callTrackerOutgoingAnswered, missed: _callTrackerMissed, incomingAnswered: _callTrackerIncomingAnswered, outgoingCost: _callTrackerOutgoingCost, incomingCost: _callTrackerIncomingCost),
            _buildModuleSummaryCard(title: "EAC Tracker", icon: Icons.support_agent, totalCalls: _eacTotalCalls, totalDuration: _eacTotalDuration, outgoingAnswered: _eacOutgoingAnswered, missed: _eacMissed, incomingAnswered: _eacIncomingAnswered, outgoingCost: _eacOutgoingCost, incomingCost: _eacIncomingCost),
            _buildModuleSummaryCard(title: "Viral Load Tracker", icon: Icons.science, totalCalls: _vlTotalCalls, totalDuration: _vlTotalDuration, outgoingAnswered: _vlOutgoingAnswered, missed: _vlMissed, incomingAnswered: _vlIncomingAnswered, outgoingCost: _vlOutgoingCost, incomingCost: _vlIncomingCost),
          ],
        ),
      ],
    );
  }
  
  // --- HELPER & CHART WIDGETS (Copied from HQ Report) ---

  Widget _buildModuleSummaryCard({ required String title, required IconData icon, required int totalCalls, required int totalDuration, required int outgoingAnswered, required int missed, required int incomingAnswered, required double outgoingCost, required double incomingCost, }) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, minWidth: 350),
        child: Column(
          children: [
            Container( color: Colors.grey.shade200, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row( children: [
                Icon(icon, color: const Color(0xFF722F37)), const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ]),
            ),
            Padding( padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  _buildMetricTile("Total Calls Logged", totalCalls.toString()),
                  _buildMetricTile("Total Call Duration", formatDuration(totalDuration)),
                  _buildMetricTile("Outgoing Answered", outgoingAnswered.toString(), color: Colors.green.shade800),
                  _buildMetricTile("Incoming Answered", incomingAnswered.toString(), color: Colors.blue.shade800),
                  _buildMetricTile("Missed/Failed", missed.toString(), color: Colors.red.shade800),
                  _buildMetricTile("Est. Outgoing Cost", currencyFormatter.format(outgoingCost), color: Colors.green.shade900),
                  _buildMetricTile("Est. Incoming Cost", currencyFormatter.format(incomingCost), color: Colors.blue.shade900),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, {Color color = Colors.black87}) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildModuleActivityChart(List<_ChartData> data, int totalFacilities) {
    return SfCartesianChart(
        primaryXAxis: const CategoryAxis(),
        primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Number of Active Facilities'), numberFormat: NumberFormat.compact()),
        series: <CartesianSeries>[
          BarSeries<_ChartData, String>(
              dataSource: data, xValueMapper: (d,_) => d.category, yValueMapper: (d,_) => d.value,
              dataLabelSettings: DataLabelSettings(
                  isVisible: true,
                  builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                    final count = point.y.toInt();
                    if (totalFacilities == 0) return Text('$count');
                    final double percentage = (count / totalFacilities) * 100;
                    return Text('$count (${percentage.toStringAsFixed(0)}%)');
                  }
              )
          )
        ]
    );
  }

  Widget _buildActiveFacilitiesTable(Map<String, List<String>> data) {
    final tabs = data.keys.toList();
    if(tabs.isEmpty) return const Center(child: Text("No module activity data."));
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Active Facility List", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TabBar(tabs: tabs.map((name) => Tab(text: name)).toList(), labelColor: Colors.blue.shade800, unselectedLabelColor: Colors.grey),
          Expanded(
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
              child: TabBarView(
                children: tabs.map((name) {
                  final facilities = data[name]!;
                  if(facilities.isEmpty) { return const Center(child: Text("No facilities were active.")); }
                  return ListView.builder(itemCount: facilities.length, itemBuilder: (context, index) => ListTile(dense: true, leading: CircleAvatar(child: Text('${index + 1}')), title: Text(facilities[index])));
                }).toList(),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAdoptionBarChart(List<_ChartData> data) {
    return SfCartesianChart(
        primaryXAxis: const CategoryAxis(labelIntersectAction: AxisLabelIntersectAction.rotate45),
        primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Number of New Staff'), numberFormat: NumberFormat.compact()),
        tooltipBehavior: TooltipBehavior(enable: true, header: 'New Users'),
        series: <CartesianSeries>[ BarSeries<_ChartData, String>(dataSource: data, xValueMapper: (d, _) => d.category, yValueMapper: (d, _) => d.value, name: 'New Users', dataLabelSettings: const DataLabelSettings(isVisible: true, labelAlignment: ChartDataLabelAlignment.top), color: Colors.deepPurple, borderRadius: const BorderRadius.all(Radius.circular(5))) ]
    );
  }

  Widget _buildActiveStaffLineChart(List<_ChartData> data) {
    return SfCartesianChart(
        primaryXAxis: const CategoryAxis(labelIntersectAction: AxisLabelIntersectAction.rotate45),
        primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Number of Active Staff'), numberFormat: NumberFormat.compact()),
        tooltipBehavior: TooltipBehavior(enable: true, header: 'Active Staff'),
        series: <CartesianSeries>[ LineSeries<_ChartData, String>(dataSource: data, xValueMapper: (d, _) => d.category, yValueMapper: (d, _) => d.value, name: 'Active Staff', color: Colors.teal, markerSettings: const MarkerSettings(isVisible: true), dataLabelSettings: const DataLabelSettings(isVisible: true)) ]
    );
  }

  Widget _buildPunctualityTrendChart(List<_PunctualityTrendData> data) {
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(dateFormat: DateFormat.MMMd(), intervalType: DateTimeIntervalType.auto, majorGridLines: const MajorGridLines(width: 0)),
      primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Number of Clock-ins'), numberFormat: NumberFormat.compact()),
      legend: const Legend(isVisible: true, position: LegendPosition.top),
      tooltipBehavior: TooltipBehavior(enable: true, shared: true),
      series: <CartesianSeries>[
        LineSeries<_PunctualityTrendData, DateTime>(
            dataSource: data, xValueMapper: (d, _) => d.date, yValueMapper: (d, _) => d.earlyCount, name: 'Early Clock-ins (<= 8:00 AM)', color: Colors.green, markerSettings: const MarkerSettings(isVisible: true),
            dataLabelSettings: DataLabelSettings( isVisible: true, builder: (dynamic d, dynamic point, dynamic series, int pI, int sI) { final cd = data[pI]; final t = cd.earlyCount + cd.lateCount; if (t == 0) return const Text(''); final p = (cd.earlyCount / t) * 100; return Text('${p.toStringAsFixed(0)}%'); } )
        ),
        LineSeries<_PunctualityTrendData, DateTime>(
            dataSource: data, xValueMapper: (d, _) => d.date, yValueMapper: (d, _) => d.lateCount, name: 'Late Clock-ins (> 8:00 AM)', color: Colors.orange, markerSettings: const MarkerSettings(isVisible: true),
            dataLabelSettings: DataLabelSettings( isVisible: true, builder: (dynamic d, dynamic point, dynamic series, int pI, int sI) { final cd = data[pI]; final t = cd.earlyCount + cd.lateCount; if (t == 0) return const Text(''); final p = (cd.lateCount / t) * 100; return Text('${p.toStringAsFixed(0)}%'); } )
        ),
      ],
    );
  }

  Widget _buildChartCard({required String title, String? subtitle, required Widget chart, bool isWide = false}) {
    return SizedBox(
      width: isWide ? 800 : 400,
      child: Card(
        elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitle != null) ...[ const SizedBox(height: 4), Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)) ],
            const SizedBox(height: 20),
            SizedBox(height: 400, child: chart),
          ]),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon, VoidCallback onPressed, {bool disabled = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4),
      InputChip(
          avatar: _isFacilitiesLoading && label=="Facility" ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 18),
          label: Text(value, overflow: TextOverflow.ellipsis), onPressed: disabled ? null : onPressed, showCheckmark: false,
          side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.7)), backgroundColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
      )
    ]);
  }

  Widget _buildMessageDisplay(IconData icon, Color color, String title, String message) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 60, color: color.withOpacity(0.7)), const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color)), const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700)),
        ],),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20)));
  }

  String formatDuration(int totalSeconds) {
    if (totalSeconds < 0) return 'N/A';
    if (totalSeconds == 0) return '0s';
    final int hours = totalSeconds ~/ 3600; final int minutes = (totalSeconds % 3600) ~/ 60; final int remainingSeconds = totalSeconds % 60;
    List<String> parts = [];
    if (hours > 0) parts.add('${hours}h'); if (minutes > 0) parts.add('${minutes}m'); if (remainingSeconds > 0 || parts.isEmpty) parts.add('${remainingSeconds}s');
    return parts.join(' ');
  }

  void _showDateRangePicker() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Select Date Range'),
      content: SizedBox(
        width: 350, height: 350,
        child: SfDateRangePicker(
          selectionMode: DateRangePickerSelectionMode.range, initialSelectedRange: PickerDateRange(_startDate, _endDate), maxDate: DateTime.now(), showActionButtons: true,
          onSubmit: (Object? value) {
            if (value is PickerDateRange && value.startDate != null) { setState(() { _startDate = value.startDate!; _endDate = value.endDate ?? value.startDate!; }); }
            Navigator.pop(context);
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    ));
  }

  Future<void> _showMultiSelectDialog({ required String title, required List<String> allOptions, required List<String> selectedOptions, required String allKeyword, required Function(List<String>) onConfirm }) async {
    final tempSelected = List<String>.from(selectedOptions);
    await showDialog(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (dialogContext, setStateDialog) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 350,
            child: ListView.builder(
              shrinkWrap: true, itemCount: allOptions.length,
              itemBuilder: (context, index) {
                final option = allOptions[index]; final isAllOption = option == allKeyword;
                return CheckboxListTile(
                  title: Text(option, style: TextStyle(fontWeight: isAllOption ? FontWeight.bold : FontWeight.normal)),
                  value: tempSelected.contains(option),
                  onChanged: (bool? value) {
                    setStateDialog(() {
                      if (value == true) {
                        if (isAllOption) { tempSelected..clear()..add(allKeyword); } else { tempSelected.remove(allKeyword); tempSelected.add(option); }
                      } else {
                        tempSelected.remove(option);
                        if (tempSelected.isEmpty && allOptions.contains(allKeyword)) { tempSelected.add(allKeyword); }
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () { onConfirm(tempSelected); Navigator.pop(context); }, child: const Text('Apply')),
          ],
        );
      });
    });
  }
}

class _ScrollablePaginatedTable extends StatefulWidget {
  final Widget header;
  final List<DataColumn> columns;
  final DataTableSource source;
  const _ScrollablePaginatedTable({required this.header, required this.columns, required this.source});

  @override
  __ScrollablePaginatedTableState createState() => __ScrollablePaginatedTableState();
}

class __ScrollablePaginatedTableState extends State<_ScrollablePaginatedTable> {
  final ScrollController _scrollController = ScrollController();
  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: widget.header),
                IconButton( icon: const Icon(Icons.arrow_back), tooltip: "Scroll Left", onPressed: () => _scrollController.animateTo(_scrollController.offset - 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut), ),
                IconButton( icon: const Icon(Icons.arrow_forward), tooltip: "Scroll Right", onPressed: () => _scrollController.animateTo(_scrollController.offset + 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut), ),
              ],
            ),
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1300,
                child: PaginatedDataTable( rowsPerPage: 5, showFirstLastButtons: true, columns: widget.columns, source: widget.source, ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}