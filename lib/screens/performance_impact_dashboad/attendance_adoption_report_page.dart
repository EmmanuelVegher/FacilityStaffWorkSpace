// lib/pages/reports/state_level_engagement_report_page.dart

// PERFORMANCE IMPACT DASHBOARD
// ** VERSION 13.1: FULLY IMPLEMENTED PER-STATE SUMMARIES, REORDERED LAYOUT, AND UI/UX ENHANCEMENTS **

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../widgets/drawer3.dart'; // Assuming a generic app drawer

// --- DATA MODELS ---

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

class _ChartData {
  final String category;
  final double value;
  _ChartData(this.category, this.value);
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


// --- MAIN WIDGET ---

class StateLevelEngagementReportPage extends StatefulWidget {
  const StateLevelEngagementReportPage({super.key});

  @override
  _StateLevelEngagementReportPageState createState() =>
      _StateLevelEngagementReportPageState();
}

class _StateLevelEngagementReportPageState
    extends State<StateLevelEngagementReportPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false, _isInitialState = true, _isFacilitiesLoading = false;
  String? _errorMessage;

  DateTime _startDate = DateTime(DateTime.now().year - 1, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime.now();

  List<String> _availableStates = ['All States'], _availableFacilities = ['All Facilities'];
  List<String> _selectedStates = ['All States'], _selectedFacilities = ['All Facilities'];
  List<String> _displayStates = [];

  // --- GLOBAL AGGREGATES FOR 'ALL STATES' TAB ---
  List<_ChartData> _adoptionAllStatesData = [], _activeStaffAllStatesData = [];
  List<StaffDetails> _inactiveStaffOnLeaveAll = [], _completelyInactiveStaffAll = [];
  List<RecentlyInactiveStaff> _recentlyInactiveStaffAll = [];
  List<_ChartData> _moduleActivityAllStatesData = [];
  Map<String, List<String>> _activeFacilitiesByModuleAll = {};
  int _callTrackerTotalCallsAll = 0, _eacTotalCallsAll = 0, _vlTotalCallsAll = 0;
  int _callTrackerTotalDurationAll=0, _callTrackerOutgoingAnsweredAll=0, _callTrackerMissedAll=0, _callTrackerIncomingAnsweredAll=0;
  double _callTrackerOutgoingCostAll=0.0, _callTrackerIncomingCostAll=0.0;
  int _eacTotalDurationAll=0, _eacOutgoingAnsweredAll=0, _eacMissedAll=0, _eacIncomingAnsweredAll=0;
  double _eacOutgoingCostAll=0.0, _eacIncomingCostAll=0.0;
  int _vlTotalDurationAll=0, _vlOutgoingAnsweredAll=0, _vlMissedAll=0, _vlIncomingAnsweredAll=0;
  double _vlOutgoingCostAll=0.0, _vlIncomingCostAll=0.0;

  // --- PER-STATE DATA FOR INDIVIDUAL TABS ---
  Map<String, List<_ChartData>> _adoptionByStateData = {}, _activeStaffByStateData = {};
  Map<String, List<StaffDetails>> _inactiveStaffOnLeaveByState = {}, _completelyInactiveStaffByState = {};
  Map<String, List<RecentlyInactiveStaff>> _recentlyInactiveStaffByState = {};
  Map<String, List<_ChartData>> _moduleActivityByStateData = {};
  Map<String, Map<String, List<String>>> _activeFacilitiesByModuleByState = {};
  Map<String, int> _callTrackerTotalCallsByState = {}, _eacTotalCallsByState = {}, _vlTotalCallsByState = {};
  Map<String, int> _callTrackerTotalDurationByState={}, _callTrackerOutgoingAnsweredByState={}, _callTrackerMissedByState={}, _callTrackerIncomingAnsweredByState={};
  Map<String, double> _callTrackerOutgoingCostByState={}, _callTrackerIncomingCostByState={};
  Map<String, int> _eacTotalDurationByState={}, _eacOutgoingAnsweredByState={}, _eacMissedByState={}, _eacIncomingAnsweredByState={};
  Map<String, double> _eacOutgoingCostByState={}, _eacIncomingCostByState={};
  Map<String, int> _vlTotalDurationByState={}, _vlOutgoingAnsweredByState={}, _vlMissedByState={}, _vlIncomingAnsweredByState={};
  Map<String, double> _vlOutgoingCostByState={}, _vlIncomingCostByState={};

  final double _costPerSecond = 0.25;

  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  void _clearAllStateData() {
    _adoptionAllStatesData = []; _activeStaffAllStatesData = []; _inactiveStaffOnLeaveAll = [];
    _completelyInactiveStaffAll = []; _recentlyInactiveStaffAll = []; _moduleActivityAllStatesData = [];
    _activeFacilitiesByModuleAll = {};
    _adoptionByStateData = {}; _activeStaffByStateData = {}; _inactiveStaffOnLeaveByState = {};
    _completelyInactiveStaffByState = {}; _recentlyInactiveStaffByState = {}; _moduleActivityByStateData = {};
    _activeFacilitiesByModuleByState = {};

    _callTrackerTotalCallsAll = 0; _callTrackerTotalDurationAll=0; _callTrackerOutgoingAnsweredAll=0; _callTrackerMissedAll=0; _callTrackerIncomingAnsweredAll=0; _callTrackerOutgoingCostAll=0.0; _callTrackerIncomingCostAll=0.0;
    _eacTotalCallsAll = 0; _eacTotalDurationAll=0; _eacOutgoingAnsweredAll=0; _eacMissedAll=0; _eacIncomingAnsweredAll=0; _eacOutgoingCostAll=0.0; _eacIncomingCostAll=0.0;
    _vlTotalCallsAll = 0; _vlTotalDurationAll=0; _vlOutgoingAnsweredAll=0; _vlMissedAll=0; _vlIncomingAnsweredAll=0; _vlOutgoingCostAll=0.0; _vlIncomingCostAll=0.0;

    _callTrackerTotalCallsByState = {}; _eacTotalCallsByState = {}; _vlTotalCallsByState = {};
    _callTrackerTotalDurationByState={}; _callTrackerOutgoingAnsweredByState={}; _callTrackerMissedByState={}; _callTrackerIncomingAnsweredByState={}; _callTrackerOutgoingCostByState={}; _callTrackerIncomingCostByState={};
    _eacTotalDurationByState={}; _eacOutgoingAnsweredByState={}; _eacMissedByState={}; _eacIncomingAnsweredByState={}; _eacOutgoingCostByState={}; _eacIncomingCostByState={};
    _vlTotalDurationByState={}; _vlOutgoingAnsweredByState={}; _vlMissedByState={}; _vlIncomingAnsweredByState={}; _vlOutgoingCostByState={}; _vlIncomingCostByState={};
  }

  Future<void> _initializeFilters() async {
    setState(() => _isFacilitiesLoading = true);
    try {
      final snapshot = await _firestore.collection('Location').get();
      if (!mounted) return;
      final states = snapshot.docs.map((doc) => doc.id).where((id) => id.isNotEmpty).toList()..sort();
      setState(() {
        _availableStates.addAll(states);
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error initializing filters: $e");
    } finally {
      if (mounted) setState(() => _isFacilitiesLoading = false);
    }
  }

  Future<void> _onStatesChanged(List<String> newStates) async {
    setState(() {
      _selectedStates = newStates;
      _isFacilitiesLoading = true;
      _availableFacilities = ['All Facilities'];
      _selectedFacilities = ['All Facilities'];
    });

    List<String> statesToQuery = newStates.contains('All States')
        ? _availableStates.where((s) => s != 'All States').toList()
        : newStates;

    if (statesToQuery.isEmpty) {
      setState(() => _isFacilitiesLoading = false);
      return;
    }

    try {
      final Set<String> facilities = {};
      for (final state in statesToQuery) {
        final facilitySnapshot = await _firestore.collection('Location').doc(state).collection(state).where('category', isEqualTo: 'Facility').get();
        for (final doc in facilitySnapshot.docs) {
          final locationName = doc.data()['LocationName'] as String?;
          if (locationName != null && locationName.isNotEmpty) {
            facilities.add(locationName);
          }
        }
      }
      if (mounted) {
        setState(() => _availableFacilities.addAll(facilities.toList()..sort()));
      }
    } catch (e) {
      if (mounted) _showSnackBar("Error fetching facility lists.");
    } finally {
      if (mounted) setState(() => _isFacilitiesLoading = false);
    }
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _isInitialState = false;
      _errorMessage = null;
      _displayStates = [];
      _clearAllStateData();
    });

    try {
      final filteredStaffDetailsMap = await _getFilteredStaffDetails();
      if (filteredStaffDetailsMap.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final futures = [
        _firestore.collectionGroup('Record').get(),
        _firestore.collectionGroup('Leave Request').get(),
        _firestore.collection('CallLogs').where('dateTracked', isGreaterThanOrEqualTo: _startDate).where('dateTracked', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1))).get(),
        _firestore.collection('EacCallLogs').where('dateTracked', isGreaterThanOrEqualTo: _startDate).where('dateTracked', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1))).get(),
        _firestore.collection('VlCallLogs').where('callDateTime', isGreaterThanOrEqualTo: _startDate).where('callDateTime', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1))).get(),
      ];
      final results = await Future.wait(futures);

      final allRecordsSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final allLeaveSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final callLogsSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final eacLogsSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
      final vlLogsSnapshot = results[4] as QuerySnapshot<Map<String, dynamic>>;

      _processAllData(
          filteredStaffDetailsMap, allRecordsSnapshot, allLeaveSnapshot,
          callLogsSnapshot, eacLogsSnapshot, vlLogsSnapshot
      );

    } catch (e, s) {
      debugPrint("Error loading report data: $e\n$s");
      if(mounted) setState(() => _errorMessage = "An error occurred. Check for missing data fields (like timestamps) or required indexes.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processAllData(
      Map<String, StaffDetails> filteredStaffMap,
      QuerySnapshot<Map<String, dynamic>> allRecords,
      QuerySnapshot<Map<String, dynamic>> allLeave,
      QuerySnapshot<Map<String, dynamic>> callLogs,
      QuerySnapshot<Map<String, dynamic>> eacLogs,
      QuerySnapshot<Map<String, dynamic>> vlLogs
      ) {
    // A map to quickly find a staff's state. Crucial for attributing logs to states.
    final Map<String, String> staffIdToStateMap = {
      for (var staff in filteredStaffMap.values) staff.id: staff.state
    };

    _processCallMetrics(callLogs.docs, staffIdToStateMap);
    _processEacMetrics(eacLogs.docs, staffIdToStateMap);
    _processVlMetrics(vlLogs.docs, staffIdToStateMap);
    _processModuleActivityData(callLogs.docs, eacLogs.docs, vlLogs.docs, staffIdToStateMap);

    final allStaffWithAttendance = allRecords.docs.map((doc) => doc.reference.parent.parent!.id).toSet();
    final allStaffWithLeave = allLeave.docs.map((doc) => doc.reference.parent.parent!.id).toSet();

    final Map<String, Set<String>> facilityStaffIdsByState = {};
    for (var staff in filteredStaffMap.values) {
      if (staff.category == 'Facility Staff') {
        facilityStaffIdsByState.putIfAbsent(staff.state, () => {}).add(staff.id);
      }
    }

    facilityStaffIdsByState.forEach((state, staffIdsInState) {
      final completelyInactive = staffIdsInState.difference(allStaffWithAttendance).difference(allStaffWithLeave);
      _completelyInactiveStaffByState[state] = completelyInactive.map((id) => filteredStaffMap[id]).whereType<StaffDetails>().toList();

      final onLeaveNoAttendance = allStaffWithLeave.difference(allStaffWithAttendance);
      final inactiveOnLeave = staffIdsInState.intersection(onLeaveNoAttendance);
      _inactiveStaffOnLeaveByState[state] = inactiveOnLeave.map((id) => filteredStaffMap[id]).whereType<StaffDetails>().toList();
    });

    _completelyInactiveStaffAll = _completelyInactiveStaffByState.values.expand((list) => list).toList();
    _inactiveStaffOnLeaveAll = _inactiveStaffOnLeaveByState.values.expand((list) => list).toList();

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

    setState(() {
      final allDisplayStates = {..._adoptionByStateData.keys, ..._activeStaffByStateData.keys, ...facilityStaffIdsByState.keys};
      _displayStates = allDisplayStates.toList()..sort();
    });
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

    final Map<String, List<RecentlyInactiveStaff>> byState = {};
    lastAttendanceMap.forEach((staffId, lastDate) {
      final daysSince = now.difference(lastDate).inDays;
      if (daysSince > 3) {
        final staffDetails = filteredStaffMap[staffId];
        if (staffDetails != null) {
          final item = RecentlyInactiveStaff(staffDetails: staffDetails, lastAttendanceDate: lastDate, daysSinceLastAttendance: daysSince);
          byState.putIfAbsent(staffDetails.state, () => []).add(item);
        }
      }
    });

    byState.forEach((state, list) {
      list.sort((a, b) => b.daysSinceLastAttendance.compareTo(a.daysSinceLastAttendance));
      _recentlyInactiveStaffByState[state] = list;
    });

    _recentlyInactiveStaffAll = byState.values.expand((list) => list).toList()
      ..sort((a, b) => b.daysSinceLastAttendance.compareTo(a.daysSinceLastAttendance));
  }

  void _processCallMetrics(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Map<String, String> staffStateMap) {
    for (var doc in docs) {
      final data = doc.data();
      // Use 'trackedById' if available, otherwise fall back to 'trackerFacilityState' from the log itself
      final state = staffStateMap[data['trackedById']] ?? data['trackerFacilityState'] as String?;
      if (state == null) continue;

      final duration = data['callDuration'] as int? ?? 0;
      final status = (data['callStatus'] as String?)?.toLowerCase().trim() ?? '';

      _callTrackerTotalCallsAll++;
      _callTrackerTotalDurationAll += duration;
      _callTrackerTotalCallsByState[state] = (_callTrackerTotalCallsByState[state] ?? 0) + 1;
      _callTrackerTotalDurationByState[state] = (_callTrackerTotalDurationByState[state] ?? 0) + duration;

      if (status == 'answered') {
        final cost = duration * _costPerSecond;
        _callTrackerOutgoingAnsweredAll++;
        _callTrackerOutgoingCostAll += cost;
        _callTrackerOutgoingAnsweredByState[state] = (_callTrackerOutgoingAnsweredByState[state] ?? 0) + 1;
        _callTrackerOutgoingCostByState[state] = (_callTrackerOutgoingCostByState[state] ?? 0.0) + cost;
      } else if (status == 'incoming answered') {
        final cost = duration * _costPerSecond;
        _callTrackerIncomingAnsweredAll++;
        _callTrackerIncomingCostAll += cost;
        _callTrackerIncomingAnsweredByState[state] = (_callTrackerIncomingAnsweredByState[state] ?? 0) + 1;
        _callTrackerIncomingCostByState[state] = (_callTrackerIncomingCostByState[state] ?? 0.0) + cost;
      } else if (status.contains('missed') || status.contains('not answered') || status.contains('failed')) {
        _callTrackerMissedAll++;
        _callTrackerMissedByState[state] = (_callTrackerMissedByState[state] ?? 0) + 1;
      }
    }
  }

  void _processEacMetrics(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Map<String, String> staffStateMap) {
    for (var doc in docs) {
      final data = doc.data();
      final state = staffStateMap[data['trackedById']] ?? data['trackerState'] as String?;
      if (state == null) continue;

      final duration = data['callDuration'] as int? ?? 0;
      final status = (data['trackingOutcome'] as String?)?.toLowerCase().trim() ?? '';

      _eacTotalCallsAll++;
      _eacTotalDurationAll += duration;
      _eacTotalCallsByState[state] = (_eacTotalCallsByState[state] ?? 0) + 1;
      _eacTotalDurationByState[state] = (_eacTotalDurationByState[state] ?? 0) + duration;

      if (status == 'answered' || status == 'completed') {
        final cost = duration * _costPerSecond;
        _eacOutgoingAnsweredAll++;
        _eacOutgoingCostAll += cost;
        _eacOutgoingAnsweredByState[state] = (_eacOutgoingAnsweredByState[state] ?? 0) + 1;
        _eacOutgoingCostByState[state] = (_eacOutgoingCostByState[state] ?? 0) + cost;
      } else if (status == 'incoming answered') {
        final cost = duration * _costPerSecond;
        _eacIncomingAnsweredAll++;
        _eacIncomingCostAll += cost;
        _eacIncomingAnsweredByState[state] = (_eacIncomingAnsweredByState[state] ?? 0) + 1;
        _eacIncomingCostByState[state] = (_eacIncomingCostByState[state] ?? 0.0) + cost;
      } else if (status.contains('missed') || status.contains('not answered') || status.contains('failed')) {
        _eacMissedAll++;
        _eacMissedByState[state] = (_eacMissedByState[state] ?? 0) + 1;
      }
    }
  }

  void _processVlMetrics(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Map<String, String> staffStateMap) {
    for (var doc in docs) {
      final data = doc.data();
      final state = staffStateMap[data['trackedById']] ?? data['trackerState'] as String?;
      if (state == null) continue;

      final duration = data['callDurationInSeconds'] as int? ?? 0;
      final status = (data['callStatus'] as String?)?.toLowerCase().trim() ?? '';

      _vlTotalCallsAll++;
      _vlTotalDurationAll += duration;
      _vlTotalCallsByState[state] = (_vlTotalCallsByState[state] ?? 0) + 1;
      _vlTotalDurationByState[state] = (_vlTotalDurationByState[state] ?? 0) + duration;

      if (status == 'answered' || status == 'completed') {
        final cost = duration * _costPerSecond;
        _vlOutgoingAnsweredAll++;
        _vlOutgoingCostAll += cost;
        _vlOutgoingAnsweredByState[state] = (_vlOutgoingAnsweredByState[state] ?? 0) + 1;
        _vlOutgoingCostByState[state] = (_vlOutgoingCostByState[state] ?? 0.0) + cost;
      } else if (status == 'incoming answered') {
        final cost = duration * _costPerSecond;
        _vlIncomingAnsweredAll++;
        _vlIncomingCostAll += cost;
        _vlIncomingAnsweredByState[state] = (_vlIncomingAnsweredByState[state] ?? 0) + 1;
        _vlIncomingCostByState[state] = (_vlIncomingCostByState[state] ?? 0.0) + cost;
      } else if (status.contains('missed') || status.contains('not answered') || status.contains('failed')) {
        _vlMissedAll++;
        _vlMissedByState[state] = (_vlMissedByState[state] ?? 0) + 1;
      }
    }
  }

  void _processModuleActivityData(List<QueryDocumentSnapshot<Map<String, dynamic>>> callDocs, List<QueryDocumentSnapshot<Map<String, dynamic>>> eacDocs, List<QueryDocumentSnapshot<Map<String, dynamic>>> vlDocs, Map<String, String> staffStateMap) {
    final Map<String, Set<String>> callFacsByState = {}, eacFacsByState = {}, vlFacsByState = {};

    for(var doc in callDocs){
      final state = staffStateMap[doc.data()['trackedById']] ?? doc.data()['trackerFacilityState'];
      final facility = doc.data()['trackerFacilityLocation'] as String?;
      if (state != null && facility != null && facility.isNotEmpty) callFacsByState.putIfAbsent(state, ()=>{}).add(facility);
    }
    for(var doc in eacDocs){
      final state = staffStateMap[doc.data()['trackedById']] ?? doc.data()['trackerState'];
      final facility = doc.data()['trackerFacilityLocation'] as String?;
      if (state != null && facility != null && facility.isNotEmpty) eacFacsByState.putIfAbsent(state, ()=>{}).add(facility);
    }
    for(var doc in vlDocs){
      final state = staffStateMap[doc.data()['trackedById']] ?? doc.data()['trackerState'];
      final facility = doc.data()['trackerFacility'] as String?;
      if (state != null && facility != null && facility.isNotEmpty) vlFacsByState.putIfAbsent(state, ()=>{}).add(facility);
    }

    final allStatesWithData = {...callFacsByState.keys, ...eacFacsByState.keys, ...vlFacsByState.keys};

    for (var state in allStatesWithData) {
      final stateCallFacs = callFacsByState[state] ?? {};
      final stateEacFacs = eacFacsByState[state] ?? {};
      final stateVlFacs = vlFacsByState[state] ?? {};

      _moduleActivityByStateData[state] = [
        _ChartData('Call Tracker', stateCallFacs.length.toDouble()),
        _ChartData('EAC', stateEacFacs.length.toDouble()),
        _ChartData('Viral Load', stateVlFacs.length.toDouble()),
      ];
      _activeFacilitiesByModuleByState[state] = {
        'Call Tracker': stateCallFacs.toList()..sort(),
        'EAC': stateEacFacs.toList()..sort(),
        'Viral Load': stateVlFacs.toList()..sort(),
      };
    }

    final allCallFacs = callFacsByState.values.expand((s) => s).toSet();
    final allEacFacs = eacFacsByState.values.expand((s) => s).toSet();
    final allVlFacs = vlFacsByState.values.expand((s) => s).toSet();

    _moduleActivityAllStatesData = [
      _ChartData('Call Tracker', allCallFacs.length.toDouble()),
      _ChartData('EAC', allEacFacs.length.toDouble()),
      _ChartData('Viral Load', allVlFacs.length.toDouble()),
    ];
    _activeFacilitiesByModuleAll = {
      'Call Tracker': allCallFacs.toList()..sort(),
      'EAC': allEacFacs.toList()..sort(),
      'Viral Load': allVlFacs.toList()..sort(),
    };
  }

  void _processChartData(List<AttendanceDataPoint> data) {
    if (data.isEmpty) {
      setState(() { _adoptionByStateData = {}; _activeStaffByStateData = {}; _adoptionAllStatesData = []; _activeStaffAllStatesData = []; });
      return;
    }
    final monthFormat = DateFormat('MMM yyyy');

    final Map<String, Map<String, Set<String>>> monthlyActiveStaffByState = {};
    for (var record in data) {
      final monthKey = monthFormat.format(record.clockInTime);
      monthlyActiveStaffByState.putIfAbsent(record.state, () => {}).putIfAbsent(monthKey, () => {}).add(record.staffId);
    }
    monthlyActiveStaffByState.forEach((state, monthlyData) {
      _activeStaffByStateData[state] = monthlyData.entries.map((entry) => _ChartData(entry.key, entry.value.length.toDouble())).toList()
        ..sort((a, b) => monthFormat.parse(a.category).compareTo(monthFormat.parse(b.category)));
    });

    data.sort((a, b) => a.clockInTime.compareTo(b.clockInTime));
    final Map<String, DateTime> firstRecordPerStaff = {};
    for (var record in data) {
      firstRecordPerStaff.putIfAbsent(record.staffId, () => record.clockInTime);
    }

    final Map<String, Map<String, int>> monthlyAdoptionCountsByState = {};
    firstRecordPerStaff.forEach((staffId, firstDate) {
      final state = data.firstWhere((r) => r.staffId == staffId).state;
      final monthKey = monthFormat.format(firstDate);
      monthlyAdoptionCountsByState.putIfAbsent(state, () => {})[monthKey] = (monthlyAdoptionCountsByState[state]![monthKey] ?? 0) + 1;
    });
    monthlyAdoptionCountsByState.forEach((state, monthlyData) {
      _adoptionByStateData[state] = monthlyData.entries.map((entry) => _ChartData(entry.key, entry.value.toDouble())).toList()
        ..sort((a, b) => monthFormat.parse(a.category).compareTo(monthFormat.parse(b.category)));
    });

    _activeStaffAllStatesData = _activeStaffByStateData.values.expand((list) => list)
        .fold<Map<String, double>>({}, (prev, e) { prev[e.category] = (prev[e.category] ?? 0) + e.value; return prev; })
        .entries.map((e) => _ChartData(e.key, e.value)).toList()
      ..sort((a,b) => monthFormat.parse(a.category).compareTo(monthFormat.parse(b.category)));

    _adoptionAllStatesData = _adoptionByStateData.values.expand((list) => list)
        .fold<Map<String, double>>({}, (prev, e) { prev[e.category] = (prev[e.category] ?? 0) + e.value; return prev; })
        .entries.map((e) => _ChartData(e.key, e.value)).toList()
      ..sort((a,b) => monthFormat.parse(a.category).compareTo(monthFormat.parse(b.category)));
  }

  Future<Map<String, StaffDetails>> _getFilteredStaffDetails() async {
    List<String> statesToQuery = _selectedStates.contains('All States') ? _availableStates.where((s) => s != 'All States').toList() : _selectedStates;
    List<String> facilitiesToQuery = _selectedFacilities.contains('All Facilities') ? [] : _selectedFacilities;

    Query<Map<String, dynamic>> staffQuery = _firestore.collection('Staff');
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs;
    if (statesToQuery.isNotEmpty) {
      staffDocs = await _fetchWithChunkedIn(staffQuery, 'state', statesToQuery);
    } else {
      final snapshot = await staffQuery.get();
      staffDocs = snapshot.docs;
    }
    if (facilitiesToQuery.isNotEmpty) {
      final facilitySet = facilitiesToQuery.toSet();
      staffDocs.retainWhere((doc) => facilitySet.contains(doc.data()['location']));
    }

    return { for (var doc in staffDocs) doc.id: StaffDetails(
      id: doc.id,
      name: "${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}".trim(),
      state: doc.data()['state'] ?? 'N/A',
      location: doc.data()['location'] ?? 'N/A',
      category: doc.data()['staffCategory'] ?? 'Unknown',
      phone: doc.data()['mobile'] ?? 'N/A',
      email: doc.data()['emailAddress'] ?? 'N/A',
    )};
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchWithChunkedIn(Query<Map<String, dynamic>> baseQuery, Object field, List<String> values) async {
    if (values.isEmpty) return [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];
    for (var i = 0; i < values.length; i += 30) {
      final chunk = values.sublist(i, min(i + 30, values.length));
      final snapshot = await baseQuery.where(field, whereIn: chunk).get();
      allDocs.addAll(snapshot.docs);
    }
    return allDocs;
  }

  // --- WIDGET BUILD METHODS ---
  @override
  Widget build(BuildContext context) {
    final hasData = _displayStates.isNotEmpty;

    return DefaultTabController(
      length: hasData ? _displayStates.length + 1 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Performance Impact", style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF722F37),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: !hasData ? null : TabBar(
            isScrollable: true, labelColor: Colors.white, unselectedLabelColor: Colors.white70, indicatorColor: Colors.amberAccent,
            tabs: [ const Tab(text: "All States (Combined)"), ..._displayStates.map((state) => Tab(text: state)), ],
          ),
        ),
        drawer: drawer3(context),
        body: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: Stack(
                children: [
                  if (_errorMessage != null) _buildMessageDisplay(Icons.error_outline, Colors.red, "An Error Occurred", _errorMessage!)
                  else if (_isInitialState) _buildMessageDisplay(Icons.filter_list, Colors.grey, "Awaiting Analysis", "Please select filters and click 'Load Report' to begin.")
                  else if (!_isLoading && !hasData) _buildMessageDisplay(Icons.search_off, Colors.orange, "No Data Found", "No data was found for the selected criteria.")
                    else _buildDashboardBody(),
                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 16), Text("Analyzing Data...", style: TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none))])),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    String stateButtonText = _selectedStates.contains('All States') ? 'All States' : _selectedStates.length == 1 ? _selectedStates.first : '${_selectedStates.length} States';
    String facilityButtonText = _selectedFacilities.contains('All Facilities') ? 'All Facilities' : _selectedFacilities.length == 1 ? _selectedFacilities.first : '${_selectedFacilities.length} Facilities';

    return Card(
      margin: const EdgeInsets.all(8.0), elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text('${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            ),
            _buildFilterChip("State", stateButtonText, Icons.map_outlined, () {
              _showMultiSelectDialog(
                title: 'Select States', allOptions: _availableStates, selectedOptions: _selectedStates, allKeyword: 'All States', onConfirm: (results) => _onStatesChanged(results),
              );
            }),
            _buildFilterChip("Facility", facilityButtonText, Icons.business_center, () {
              _showMultiSelectDialog(
                title: 'Select Facilities', allOptions: _availableFacilities, selectedOptions: _selectedFacilities, allKeyword: 'All Facilities', onConfirm: (results) => setState(() => _selectedFacilities = results),
              );
            }, disabled: _isFacilitiesLoading),
            ElevatedButton.icon(
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Load Report'),
              onPressed: _isLoading ? null : _loadReportData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF722F37), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardBody() {
    return TabBarView(
      children: [
        _buildStateTabView(isAllStatesTab: true, stateName: "All Selected States"),
        ..._displayStates.map((state) {
          return _buildStateTabView(isAllStatesTab: false, stateName: state);
        }),
      ],
    );
  }

  Widget _buildStateTabView({ required bool isAllStatesTab, required String stateName }) {
    // Determine which data source to use based on the tab
    final adoptionData = isAllStatesTab ? _adoptionAllStatesData : _adoptionByStateData[stateName] ?? [];
    final activeStaffData = isAllStatesTab ? _activeStaffAllStatesData : _activeStaffByStateData[stateName] ?? [];
    final recentlyInactive = isAllStatesTab ? _recentlyInactiveStaffAll : _recentlyInactiveStaffByState[stateName] ?? [];
    final completelyInactive = isAllStatesTab ? _completelyInactiveStaffAll : _completelyInactiveStaffByState[stateName] ?? [];
    final onLeaveInactive = isAllStatesTab ? _inactiveStaffOnLeaveAll : _inactiveStaffOnLeaveByState[stateName] ?? [];
    final moduleActivityData = isAllStatesTab ? _moduleActivityAllStatesData : _moduleActivityByStateData[stateName] ?? [];
    final activeFacilities = isAllStatesTab ? _activeFacilitiesByModuleAll : _activeFacilitiesByModuleByState[stateName] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildChartCard(title: "New User Adoption in $stateName", subtitle: "Staff who recorded their first attendance each month within the date range.", chart: _buildAdoptionBarChart(adoptionData), isWide: true),
          const SizedBox(height: 24),
          _buildChartCard(title: "Monthly Active Staff Trend in $stateName", subtitle: "Unique staff with at least one record each month within the date range.", chart: _buildActiveStaffLineChart(activeStaffData), isWide: true),
          const SizedBox(height: 24),
          _buildRecentlyInactiveStaffSection(recentlyInactive),
          const SizedBox(height: 24),
          _buildCompletelyInactiveStaffSection(completelyInactive),
          const SizedBox(height: 24),
          _buildInactiveStaffOnLeaveSection(onLeaveInactive),
          const SizedBox(height: 24),
          _buildModuleActivitySection(moduleActivityData, activeFacilities),
          const SizedBox(height: 24),
          _buildMetricSummarySection(isAllStatesTab, stateName),
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
      columns: const [
        DataColumn(label: Text('Staff Name')),
        DataColumn(label: Text('Last Clock-in Date')),
        DataColumn(label: Text('Days since last clock-in')),
        DataColumn(label: Text('Location')),
        DataColumn(label: Text('Phone')),
        DataColumn(label: Text('Email')),
      ],
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
      columns: const [
        DataColumn(label: Text('Staff Name')),
        DataColumn(label: Text('State')),
        DataColumn(label: Text('Location')),
        DataColumn(label: Text('Phone')),
        DataColumn(label: Text('Email')),
      ],
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
      columns: const [
        DataColumn(label: Text('Staff Name')),
        DataColumn(label: Text('State')),
        DataColumn(label: Text('Location')),
        DataColumn(label: Text('Phone')),
        DataColumn(label: Text('Email')),
      ],
      source: _InactiveStaffDataSource(data),
    );
  }

  Widget _buildModuleActivitySection(List<_ChartData> moduleData, Map<String, List<String>> facilityData) {
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
              SizedBox(width: 400, height: 350, child: _buildModuleActivityChart(moduleData)),
              SizedBox(width: 400, height: 350, child: _buildActiveFacilitiesTable(facilityData))
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSummarySection(bool isAllStates, String stateName) {
    final callTotal = isAllStates ? _callTrackerTotalCallsAll : _callTrackerTotalCallsByState[stateName] ?? 0;
    final callDuration = isAllStates ? _callTrackerTotalDurationAll : _callTrackerTotalDurationByState[stateName] ?? 0;
    final callOutAns = isAllStates ? _callTrackerOutgoingAnsweredAll : _callTrackerOutgoingAnsweredByState[stateName] ?? 0;
    final callInAns = isAllStates ? _callTrackerIncomingAnsweredAll : _callTrackerIncomingAnsweredByState[stateName] ?? 0;
    final callMissed = isAllStates ? _callTrackerMissedAll : _callTrackerMissedByState[stateName] ?? 0;
    final callOutCost = isAllStates ? _callTrackerOutgoingCostAll : _callTrackerOutgoingCostByState[stateName] ?? 0.0;
    final callInCost = isAllStates ? _callTrackerIncomingCostAll : _callTrackerIncomingCostByState[stateName] ?? 0.0;

    final eacTotal = isAllStates ? _eacTotalCallsAll : _eacTotalCallsByState[stateName] ?? 0;
    final eacDuration = isAllStates ? _eacTotalDurationAll : _eacTotalDurationByState[stateName] ?? 0;
    final eacOutAns = isAllStates ? _eacOutgoingAnsweredAll : _eacOutgoingAnsweredByState[stateName] ?? 0;
    final eacInAns = isAllStates ? _eacIncomingAnsweredAll : _eacIncomingAnsweredByState[stateName] ?? 0;
    final eacMissed = isAllStates ? _eacMissedAll : _eacMissedByState[stateName] ?? 0;
    final eacOutCost = isAllStates ? _eacOutgoingCostAll : _eacOutgoingCostByState[stateName] ?? 0.0;
    final eacInCost = isAllStates ? _eacIncomingCostAll : _eacIncomingCostByState[stateName] ?? 0.0;

    final vlTotal = isAllStates ? _vlTotalCallsAll : _vlTotalCallsByState[stateName] ?? 0;
    final vlDuration = isAllStates ? _vlTotalDurationAll : _vlTotalDurationByState[stateName] ?? 0;
    final vlOutAns = isAllStates ? _vlOutgoingAnsweredAll : _vlOutgoingAnsweredByState[stateName] ?? 0;
    final vlInAns = isAllStates ? _vlIncomingAnsweredAll : _vlIncomingAnsweredByState[stateName] ?? 0;
    final vlMissed = isAllStates ? _vlMissedAll : _vlMissedByState[stateName] ?? 0;
    final vlOutCost = isAllStates ? _vlOutgoingCostAll : _vlOutgoingCostByState[stateName] ?? 0.0;
    final vlInCost = isAllStates ? _vlIncomingCostAll : _vlIncomingCostByState[stateName] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Call Tracker summary", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: const Color(0xFF722F37))),
        const SizedBox(height: 4),
        Text("Aggregate call metrics for $stateName within the selected date range.", style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16.0),
        Wrap(
          spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
          children: [
            _buildModuleSummaryCard(title: "Call Tracker", icon: Icons.phone_in_talk, totalCalls: callTotal, totalDuration: callDuration, outgoingAnswered: callOutAns, missed: callMissed, incomingAnswered: callInAns, outgoingCost: callOutCost, incomingCost: callInCost),
            _buildModuleSummaryCard(title: "EAC Tracker", icon: Icons.support_agent, totalCalls: eacTotal, totalDuration: eacDuration, outgoingAnswered: eacOutAns, missed: eacMissed, incomingAnswered: eacInAns, outgoingCost: eacOutCost, incomingCost: eacInCost),
            _buildModuleSummaryCard(title: "Viral Load Tracker", icon: Icons.science, totalCalls: vlTotal, totalDuration: vlDuration, outgoingAnswered: vlOutAns, missed: vlMissed, incomingAnswered: vlInAns, outgoingCost: vlOutCost, incomingCost: vlInCost),
          ],
        ),
      ],
    );
  }

  Widget _buildModuleSummaryCard({
    required String title, required IconData icon, required int totalCalls, required int totalDuration,
    required int outgoingAnswered, required int missed, required int incomingAnswered, required double outgoingCost, required double incomingCost,
  }) {
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

  // Other builder methods (_buildFilterChip, _buildMessageDisplay, charts, etc.) are below
  // They are mostly unchanged but are included for completeness.

  Widget _buildMetricTile(String label, String value, {Color color = Colors.black87}) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildModuleActivityChart(List<_ChartData> data) {
    return SfCartesianChart(
        primaryXAxis: const CategoryAxis(),
        primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Number of Active Facilities'), numberFormat: NumberFormat.compact()),
        series: <CartesianSeries>[ BarSeries<_ChartData, String>(dataSource: data, xValueMapper: (d,_) => d.category, yValueMapper: (d,_) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true)) ]
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
          ],
          ),
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
    ]
    );
  }

  Widget _buildMessageDisplay(IconData icon, Color color, String title, String message) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 60, color: color.withOpacity(0.7)), const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color)), const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700)),
        ],
        ),
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
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int remainingSeconds = totalSeconds % 60;

    List<String> parts = [];
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (remainingSeconds > 0 || parts.isEmpty) parts.add('${remainingSeconds}s');

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
    ),
    );
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
                final option = allOptions[index];
                final isAllOption = option == allKeyword;
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
    },
    );
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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                IconButton(
                  icon: const Icon(Icons.arrow_back), tooltip: "Scroll Left",
                  onPressed: () => _scrollController.animateTo(_scrollController.offset - 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward), tooltip: "Scroll Right",
                  onPressed: () => _scrollController.animateTo(_scrollController.offset + 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                ),
              ],
            ),
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1300, // A fixed wide width to ensure horizontal scrolling is needed
                child: PaginatedDataTable(
                  rowsPerPage: 5,
                  showFirstLastButtons: true,
                  columns: widget.columns,
                  source: widget.source,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
