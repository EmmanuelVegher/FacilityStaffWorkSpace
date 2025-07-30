// lib/pages/reports/state_level_engagement_report_page.dart

// A STATE-LEVEL DASHBOARD FOR ATTENDANCE ADOPTION & ENGAGEMENT
// This report provides a tabbed view to compare engagement metrics across different states.
// ** VERSION 7: CORRECTED RUNTIME TypeError by explicitly casting Future.wait results **

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../widgets/drawer3.dart'; // Assuming a generic app drawer

// --- DATA MODELS ---

class AttendanceDataPoint {
  final String staffId;
  final DateTime clockInTime;
  final String state;
  AttendanceDataPoint({required this.staffId, required this.clockInTime, required this.state});
}

class StaffDetails {
  final String id;
  final String name;
  final String state;
  final String location;
  final String category;
  final String phone;
  final String email;
  StaffDetails({
    required this.id,
    required this.name,
    required this.state,
    required this.location,
    required this.category,
    required this.phone,
    required this.email,
  });
}

class _ChartData {
  final String category;
  final double value;
  _ChartData(this.category, this.value);
}

// --- MAIN WIDGET: StateLevelEngagementReportPage ---

class StateLevelEngagementReportPage extends StatefulWidget {
  const StateLevelEngagementReportPage({super.key});

  @override
  _StateLevelEngagementReportPageState createState() =>
      _StateLevelEngagementReportPageState();
}

class _StateLevelEngagementReportPageState
    extends State<StateLevelEngagementReportPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isInitialState = true;
  String? _errorMessage;
  bool _isFacilitiesLoading = false;

  DateTime _startDate = DateTime(2023, 1, 1);
  DateTime _endDate = DateTime.now();

  List<String> _availableStates = ['All States'];
  List<String> _availableFacilities = ['All Facilities'];
  List<String> _selectedStates = ['All States'];
  List<String> _selectedFacilities = ['All Facilities'];

  Map<String, List<_ChartData>> _adoptionByStateData = {};
  Map<String, List<_ChartData>> _activeStaffByStateData = {};
  List<String> _displayStates = [];

  List<_ChartData> _adoptionAllStatesData = [];
  List<_ChartData> _activeStaffAllStatesData = [];

  List<StaffDetails> _inactiveStaffOnLeave = [];
  List<StaffDetails> _completelyInactiveStaff = [];

  List<_ChartData> _moduleActivityByFacilityData = [];
  Map<String, List<String>> _activeFacilitiesByModule = {};


  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  // --- FILTERING & DATA LOADING LOGIC ---

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
      _adoptionByStateData = {};
      _activeStaffByStateData = {};
      _adoptionAllStatesData = [];
      _activeStaffAllStatesData = [];
      _displayStates = [];
      _inactiveStaffOnLeave = [];
      _completelyInactiveStaff = [];
      _moduleActivityByFacilityData = [];
      _activeFacilitiesByModule = {};
    });

    try {
      final Map<String, StaffDetails> filteredStaffDetailsMap = await _getFilteredStaffDetails();
      if (filteredStaffDetailsMap.isEmpty) {
        _processChartData([]);
        _processModuleActivityData([], [], []);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final results = await Future.wait([
        _firestore.collectionGroup('Record').where('timestamp', isGreaterThanOrEqualTo: _startDate).where('timestamp', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1))).get(),
        _firestore.collectionGroup('Leave Request').get(),
        _firestore.collection('CallLogs').where('dateTracked', isGreaterThanOrEqualTo: _startDate).where('dateTracked', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1))).get(),
        _firestore.collection('EacCallLogs').where('dateTracked', isGreaterThanOrEqualTo: _startDate).where('dateTracked', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1))).get(),
        _firestore.collection('VlCallLogs').where('callDateTime', isGreaterThanOrEqualTo: _startDate).where('callDateTime', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1))).get(),
      ]);

      // THIS IS THE FIX: Explicitly cast each item from the results list
      final recordsSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final leaveSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final callLogsSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final eacLogsSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
      final vlLogsSnapshot = results[4] as QuerySnapshot<Map<String, dynamic>>;

      final filteredStaffIds = filteredStaffDetailsMap.keys.toSet();
      final Set<String> staffWithAttendance = {};
      for (final doc in recordsSnapshot.docs) {
        staffWithAttendance.add(doc.reference.parent.parent!.id);
      }
      final Set<String> staffWithLeave = {};
      for (final doc in leaveSnapshot.docs) {
        final staffId = doc.reference.parent.parent!.id;
        if (filteredStaffIds.contains(staffId)) {
          staffWithLeave.add(staffId);
        }
      }
      final onLeaveButInactiveIds = staffWithLeave.difference(staffWithAttendance);
      _inactiveStaffOnLeave = onLeaveButInactiveIds.map((id) => filteredStaffDetailsMap[id]).whereType<StaffDetails>().toList();
      final facilityStaffIds = filteredStaffDetailsMap.values.where((staff) => staff.category == 'Facility Staff').map((staff) => staff.id).toSet();
      final staffWithAnyActivity = staffWithAttendance.union(staffWithLeave);
      final completelyInactiveIds = facilityStaffIds.difference(staffWithAnyActivity);
      _completelyInactiveStaff = completelyInactiveIds.map((id) => filteredStaffDetailsMap[id]).whereType<StaffDetails>().toList();

      _processModuleActivityData(callLogsSnapshot.docs, eacLogsSnapshot.docs, vlLogsSnapshot.docs);

      final List<AttendanceDataPoint> filteredAttendanceData = [];
      for (final doc in recordsSnapshot.docs) {
        final staffId = doc.reference.parent.parent!.id;
        final staffDetails = filteredStaffDetailsMap[staffId];
        if (staffDetails != null) {
          final data = doc.data();
          filteredAttendanceData.add(AttendanceDataPoint(
            staffId: staffId,
            clockInTime: (data['timestamp'] as Timestamp).toDate(),
            state: staffDetails.state,
          ));
        }
      }
      _processChartData(filteredAttendanceData);

    } catch (e, s) {
      debugPrint("Error loading report data: $e\n$s");
      _errorMessage = "An error occurred while fetching data. Please check Firestore console for any required indexes.";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  void _processModuleActivityData(List<QueryDocumentSnapshot<Map<String, dynamic>>> callDocs, List<QueryDocumentSnapshot<Map<String, dynamic>>> eacDocs, List<QueryDocumentSnapshot<Map<String, dynamic>>> vlDocs) {
    final Set<String> callFacilities = {};
    for (var doc in callDocs) {
      final facility = doc.data()['trackerFacilityLocation'] as String?;
      if (facility != null && facility.isNotEmpty) callFacilities.add(facility);
    }
    final Set<String> eacFacilities = {};
    for (var doc in eacDocs) {
      final facility = doc.data()['trackerFacilityLocation'] as String?;
      if (facility != null && facility.isNotEmpty) eacFacilities.add(facility);
    }
    final Set<String> vlFacilities = {};
    for (var doc in vlDocs) {
      final facility = doc.data()['trackerFacility'] as String?;
      if (facility != null && facility.isNotEmpty) vlFacilities.add(facility);
    }

    setState(() {
      _moduleActivityByFacilityData = [
        _ChartData('Call Tracker', callFacilities.length.toDouble()),
        _ChartData('EAC', eacFacilities.length.toDouble()),
        _ChartData('Viral Load', vlFacilities.length.toDouble()),
      ];
      _activeFacilitiesByModule = {
        'Call Tracker': callFacilities.toList()..sort(),
        'EAC': eacFacilities.toList()..sort(),
        'Viral Load': vlFacilities.toList()..sort(),
      };
    });
  }

  void _processChartData(List<AttendanceDataPoint> data) {
    if (data.isEmpty) {
      setState(() { _adoptionByStateData = {}; _activeStaffByStateData = {}; _adoptionAllStatesData = []; _activeStaffAllStatesData = []; _displayStates = []; });
      return;
    }
    final monthFormat = DateFormat('MMM yyyy');

    final Map<String, Map<String, Set<String>>> monthlyActiveStaffByState = {};
    for (final record in data) {
      final monthKey = monthFormat.format(record.clockInTime);
      monthlyActiveStaffByState.putIfAbsent(record.state, () => {});
      monthlyActiveStaffByState[record.state]!.putIfAbsent(monthKey, () => <String>{});
      monthlyActiveStaffByState[record.state]![monthKey]!.add(record.staffId);
    }
    final Map<String, List<_ChartData>> activeStaffResult = {};
    monthlyActiveStaffByState.forEach((state, monthlyData) {
      List<_ChartData> chartData = monthlyData.entries.map((entry) => _ChartData(entry.key, entry.value.length.toDouble())).toList();
      chartData.sort((a, b) => monthFormat.parse(a.category).compareTo(monthFormat.parse(b.category)));
      activeStaffResult[state] = chartData;
    });

    data.sort((a, b) => a.clockInTime.compareTo(b.clockInTime));
    final Map<String, DateTime> firstRecordPerStaff = {};
    for (final record in data) {
      if (!firstRecordPerStaff.containsKey(record.staffId)) { firstRecordPerStaff[record.staffId] = record.clockInTime; }
    }

    final Map<String, Map<String, int>> monthlyAdoptionCountsByState = {};
    firstRecordPerStaff.forEach((staffId, firstDate) {
      final state = data.firstWhere((r) => r.staffId == staffId).state;
      final monthKey = monthFormat.format(firstDate);
      monthlyAdoptionCountsByState.putIfAbsent(state, () => {});
      monthlyAdoptionCountsByState[state]![monthKey] = (monthlyAdoptionCountsByState[state]![monthKey] ?? 0) + 1;
    });
    final Map<String, List<_ChartData>> adoptionResult = {};
    monthlyAdoptionCountsByState.forEach((state, monthlyData) {
      List<_ChartData> chartData = monthlyData.entries.map((entry) => _ChartData(entry.key, entry.value.toDouble())).toList();
      chartData.sort((a, b) => monthFormat.parse(a.category).compareTo(monthFormat.parse(b.category)));
      adoptionResult[state] = chartData;
    });

    final Map<String, Set<String>> allMonthlyActive = {};
    for (final record in data) {
      final monthKey = monthFormat.format(record.clockInTime);
      allMonthlyActive.putIfAbsent(monthKey, () => <String>{});
      allMonthlyActive[monthKey]!.add(record.staffId);
    }
    List<_ChartData> allActiveStaffChartData = allMonthlyActive.entries.map((e) => _ChartData(e.key, e.value.length.toDouble())).toList();
    allActiveStaffChartData.sort((a,b) => monthFormat.parse(a.category).compareTo(monthFormat.parse(b.category)));

    final Map<String, int> allMonthlyAdoption = {};
    for (final date in firstRecordPerStaff.values) {
      final monthKey = monthFormat.format(date);
      allMonthlyAdoption[monthKey] = (allMonthlyAdoption[monthKey] ?? 0) + 1;
    }
    List<_ChartData> allAdoptionChartData = allMonthlyAdoption.entries.map((e) => _ChartData(e.key, e.value.toDouble())).toList();
    allAdoptionChartData.sort((a,b) => monthFormat.parse(a.category).compareTo(monthFormat.parse(b.category)));

    final displayStates = activeStaffResult.keys.toList()..sort();
    setState(() {
      _adoptionByStateData = adoptionResult;
      _activeStaffByStateData = activeStaffResult;
      _adoptionAllStatesData = allAdoptionChartData;
      _activeStaffAllStatesData = allActiveStaffChartData;
      _displayStates = displayStates;
    });
  }

  // --- WIDGET BUILD METHODS ---
  @override
  Widget build(BuildContext context) {
    final hasData = _displayStates.isNotEmpty || _inactiveStaffOnLeave.isNotEmpty || _completelyInactiveStaff.isNotEmpty;

    return DefaultTabController(
      length: hasData ? _displayStates.length + 1 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("State-Level Engagement Report", style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF003366),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: !hasData ? null : TabBar(
            isScrollable: true, labelColor: Colors.white, unselectedLabelColor: Colors.white70, indicatorColor: Colors.lightBlueAccent,
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
                  if (_errorMessage != null)
                    _buildMessageDisplay(Icons.error_outline, Colors.red, "An Error Occurred", _errorMessage!)
                  else if (_isInitialState)
                    _buildMessageDisplay(Icons.filter_list, Colors.grey, "Awaiting Analysis", "Please select filters and click 'Load Report' to begin.")
                  else if (!_isLoading && !hasData)
                      _buildMessageDisplay(Icons.search_off, Colors.orange, "No Data Found", "No data was found for the selected criteria.")
                    else
                      _buildDashboardBody(),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardBody() {
    if (_displayStates.isEmpty && _inactiveStaffOnLeave.isEmpty && _completelyInactiveStaff.isEmpty) return const SizedBox.shrink();

    return TabBarView(
      children: [
        _buildStateTabView(adoptionData: _adoptionAllStatesData, activeStaffData: _activeStaffAllStatesData, stateName: "All Selected States"),
        ..._displayStates.map((state) {
          return _buildStateTabView(adoptionData: _adoptionByStateData[state] ?? [], activeStaffData: _activeStaffByStateData[state] ?? [], stateName: state);
        }),
      ],
    );
  }

  Widget _buildStateTabView({ required List<_ChartData> adoptionData, required List<_ChartData> activeStaffData, required String stateName }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          if(stateName == "All Selected States") ...[
            _buildCompletelyInactiveStaffSection(),
            const SizedBox(height: 24),
            _buildInactiveStaffOnLeaveSection(),
            const SizedBox(height: 24),
            _buildModuleActivitySection(),
            const SizedBox(height: 24),
          ],
          Wrap(
            spacing: 24, runSpacing: 24, alignment: WrapAlignment.center,
            children: [
              _buildChartCard(title: "New User Adoption in $stateName", subtitle: "Staff who recorded their first attendance each month.", chart: _buildAdoptionBarChart(adoptionData), isWide: true),
              _buildChartCard(title: "Monthly Active Staff Trend in $stateName", subtitle: "Unique staff with at least one record each month.", chart: _buildActiveStaffLineChart(activeStaffData), isWide: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletelyInactiveStaffSection() {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>('completelyInactiveExpansion'), initiallyExpanded: true, backgroundColor: Colors.red.shade50, collapsedBackgroundColor: Colors.red.shade50,
        leading: Icon(Icons.no_accounts_outlined, color: Colors.red.shade800),
        title: Text("Completely Inactive 'Facility Staff'", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
        subtitle: const Text("Staff who have never recorded attendance or requested leave."),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildKpiCard(title: "Completely Inactive 'Facility Staff'", value: _completelyInactiveStaff.length, icon: Icons.no_accounts_outlined, color: Colors.red.shade800),
                const SizedBox(height: 16),
                if (_completelyInactiveStaff.isNotEmpty)
                  SizedBox(width: double.infinity, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.red.shade100),
                      columns: const [ DataColumn(label: Text('Staff Name')), DataColumn(label: Text('State')), DataColumn(label: Text('Location')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Email')) ],
                      rows: _completelyInactiveStaff.map((staff) => DataRow(cells: [ DataCell(Text(staff.name)), DataCell(Text(staff.state)), DataCell(Text(staff.location)), DataCell(Text(staff.phone)), DataCell(Text(staff.email)) ])).toList())))
                else
                  const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Text("No completely inactive staff found for this criteria."))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveStaffOnLeaveSection() {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>('inactiveStaffOnLeaveExpansion'), initiallyExpanded: false, backgroundColor: Colors.orange.shade50, collapsedBackgroundColor: Colors.orange.shade50,
        leading: Icon(Icons.person_off_outlined, color: Colors.orange.shade800),
        title: Text("Inactive Staff Analysis", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
        subtitle: const Text("Staff on leave who have never recorded attendance."),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildKpiCard(title: "Staff on Leave with No Attendance", value: _inactiveStaffOnLeave.length, icon: Icons.warning_amber_rounded, color: Colors.orange.shade800),
                const SizedBox(height: 16),
                if (_inactiveStaffOnLeave.isNotEmpty)
                  SizedBox(width: double.infinity, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.orange.shade100),
                      columns: const [ DataColumn(label: Text('Staff Name')), DataColumn(label: Text('State')), DataColumn(label: Text('Location')), DataColumn(label: Text('Phone')), DataColumn(label: Text('Email')) ],
                      rows: _inactiveStaffOnLeave.map((staff) => DataRow(cells: [ DataCell(Text(staff.name)), DataCell(Text(staff.state)), DataCell(Text(staff.location)), DataCell(Text(staff.phone)), DataCell(Text(staff.email)) ])).toList())))
                else
                  const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Text("No staff found in this category."))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleActivitySection() {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>('moduleActivityExpansion'), initiallyExpanded: true, backgroundColor: Colors.blue.shade50, collapsedBackgroundColor: Colors.blue.shade50,
        leading: Icon(Icons.phone_in_talk_outlined, color: Colors.blue.shade800),
        title: Text("Module Activity by Facility", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
        subtitle: const Text("Number of unique facilities using each communication module."),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(spacing: 24, runSpacing: 24, alignment: WrapAlignment.center, children: [
              SizedBox(width: 400, height: 350, child: _buildModuleActivityChart()),
              SizedBox(width: 400, height: 350, child: _buildActiveFacilitiesTable())
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleActivityChart() {
    return SfCartesianChart(
        primaryXAxis: const CategoryAxis(),
        primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Number of Active Facilities'), numberFormat: NumberFormat.compact()),
        series: <CartesianSeries>[ BarSeries<_ChartData, String>(dataSource: _moduleActivityByFacilityData, xValueMapper: (d,_) => d.category, yValueMapper: (d,_) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true)) ]
    );
  }

  Widget _buildActiveFacilitiesTable() {
    final tabs = _activeFacilitiesByModule.keys.toList();
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
                  final facilities = _activeFacilitiesByModule[name]!;
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

  Widget _buildKpiCard({required String title, required int value, required IconData icon, required Color color}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(children: [ Icon(icon, size: 40, color: color), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(value.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)), Text(title, style: Theme.of(context).textTheme.bodyMedium) ])) ]),
      ),
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
