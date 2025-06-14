// A DEDICATED, FEATURE-RICH PAGE FOR ATTENDANCE ANALYSIS

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';


import '../../widgets/drawer2.dart'; // Assuming a state-level drawer

// --- DATA MODELS FOR THE DASHBOARD ---

class StaffInfo {
  final String id;
  final String name;
  final String location;
  final String designation;

  StaffInfo({required this.id, required this.name, required this.location, required this.designation});
}

class AttendanceRecord {
  final String staffId;
  final DateTime date;
  final double hoursWorked;

  AttendanceRecord({required this.staffId, required this.date, required this.hoursWorked});
}

class AggregatedSummary {
  final String name;
  Map<DateTime, double> dailyHours = {};
  double get totalHours => dailyHours.values.fold(0.0, (sum, item) => sum + item);

  AggregatedSummary({required this.name});
}

class _ChartData {
  final String category;
  final double value;
  _ChartData(this.category, this.value);
}


// --- MAIN WIDGET ---
class AttendanceAnalysisPage extends StatefulWidget {
  const AttendanceAnalysisPage({super.key});

  @override
  _AttendanceAnalysisPageState createState() => _AttendanceAnalysisPageState();
}

class _AttendanceAnalysisPageState extends State<AttendanceAnalysisPage> {
  // --- Services & State ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isInitialState = true;
  String? _errorMessage;
  String? _userState;

  // --- Filter State ---
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  List<String> _availableFacilities = [];
  String? _selectedFacility;
  List<String> _availableDesignations = [];
  String? _selectedDesignation;
  List<StaffInfo> _availableStaff = [];
  String? _selectedStaffId;

  // --- Data Holders ---
  List<AttendanceRecord> _allRecords = [];
  Map<String, AggregatedSummary> _facilitySummaries = {};
  Map<String, AggregatedSummary> _designationSummaries = {};
  Map<String, Map<String, AggregatedSummary>> _facilityStaffSummaries = {}; // facility -> staffName -> summary
  List<DateTime> _dateRangeForTables = [];
  double _totalHoursAll = 0;

  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  Future<void> _initializeFilters() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      if(mounted) {
        setState(() {
          _userState = staffDoc.data()?['state'] as String?;
        });
        if(_userState != null) {
          final facilities = await _getUniqueFieldValues('location');
          final designations = await _getUniqueFieldValues('designation');
          if(mounted) {
            setState(() {
              _availableFacilities = ['All Facilities', ...facilities];
              _availableDesignations = ['All Designations', ...designations];
            });
          }
        }
      }
    } catch(e) {
      if(mounted) setState(() => _errorMessage = "Error initializing filters: $e");
    }
  }

  Future<List<String>> _getUniqueFieldValues(String field) async {
    if(_userState == null) return [];
    final snapshot = await _firestore.collection('Staff').where('state', isEqualTo: _userState).get();

    // FIX IS HERE: Using a for-loop with an explicit null check
    final Set<String> values = {}; // Use a Set to automatically handle duplicates
    for (final doc in snapshot.docs) {
      final value = doc.data()[field] as String?;
      if (value != null && value.isNotEmpty) {
        values.add(value);
      }
    }

    final sortedList = values.toList();
    sortedList.sort();
    return sortedList;
  }

  Future<void> _updateStaffFilter() async {
    if(_userState == null) return;
    var query = _firestore.collection('Staff').where('state', isEqualTo: _userState);

    if(_selectedFacility != null && _selectedFacility != 'All Facilities'){
      query = query.where('location', isEqualTo: _selectedFacility);
    }
    if(_selectedDesignation != null && _selectedDesignation != 'All Designations'){
      query = query.where('designation', isEqualTo: _selectedDesignation);
    }

    final snapshot = await query.get();
    final staffList = snapshot.docs.map((doc) => StaffInfo(
        id: doc.id,
        name: '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'.trim(),
        location: doc.data()['location'] ?? '',
        designation: doc.data()['designation'] ?? ''
    )).toList()..sort((a, b) => a.name.compareTo(b.name));

    if(mounted){
      setState(() {
        _availableStaff = staffList;
        _selectedStaffId = null; // Reset selection
      });
    }
  }

  Future<void> _loadDashboardData() async {
    if (_userState == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User state not found.")));
      return;
    }
    setState(() { _isLoading = true; _isInitialState = false; _errorMessage = null; });

    try {
      var staffQuery = _firestore.collection('Staff').where('state', isEqualTo: _userState);
      if(_selectedFacility != null && _selectedFacility != 'All Facilities') staffQuery = staffQuery.where('location', isEqualTo: _selectedFacility);
      if(_selectedDesignation != null && _selectedDesignation != 'All Designations') staffQuery = staffQuery.where('designation', isEqualTo: _selectedDesignation);
      if(_selectedStaffId != null) staffQuery = staffQuery.where(FieldPath.documentId, isEqualTo: _selectedStaffId);

      final staffSnapshot = await staffQuery.get();
      final staffList = staffSnapshot.docs.map((doc) => StaffInfo(id: doc.id, name: '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'.trim(), location: doc.data()['location'] ?? 'N/A', designation: doc.data()['designation'] ?? 'N/A')).toList();

      List<AttendanceRecord> allRecords = [];
      final dateRange = List.generate(_endDate.difference(_startDate).inDays + 1, (i) => _startDate.add(Duration(days: i)));

      for (var staff in staffList) {
        for(var date in dateRange) {
          final dateStr = DateFormat('dd-MMMM-yyyy').format(date);
          final recordDoc = await _firestore.collection('Staff').doc(staff.id).collection('Record').doc(dateStr).get();
          if(recordDoc.exists) {
            allRecords.add(AttendanceRecord(staffId: staff.id, date: date, hoursWorked: (recordDoc.data()!['noOfHours'] as num? ?? 0).toDouble()));
          }
        }
      }
      _processAndAggregateData(allRecords, staffList, dateRange);

    } catch (e, stack) {
      debugPrint("Error loading dashboard data: $e\n$stack");
      if(mounted) setState(() => _errorMessage = "An error occurred: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _processAndAggregateData(List<AttendanceRecord> records, List<StaffInfo> staff, List<DateTime> dateRange){
    final facilityData = <String, AggregatedSummary>{};
    final designationData = <String, AggregatedSummary>{};
    final facilityStaffData = <String, Map<String, AggregatedSummary>>{};

    final staffMap = {for(var s in staff) s.id: s};

    for(final record in records) {
      final staffInfo = staffMap[record.staffId];
      if(staffInfo == null) continue;

      // Facility Summary
      facilityData.putIfAbsent(staffInfo.location, () => AggregatedSummary(name: staffInfo.location));
      facilityData[staffInfo.location]!.dailyHours[record.date] = (facilityData[staffInfo.location]!.dailyHours[record.date] ?? 0) + record.hoursWorked;

      // Designation Summary
      designationData.putIfAbsent(staffInfo.designation, () => AggregatedSummary(name: staffInfo.designation));
      designationData[staffInfo.designation]!.dailyHours[record.date] = (designationData[staffInfo.designation]!.dailyHours[record.date] ?? 0) + record.hoursWorked;

      // Facility -> Staff Summary
      facilityStaffData.putIfAbsent(staffInfo.location, () => {});
      facilityStaffData[staffInfo.location]!.putIfAbsent(staffInfo.name, () => AggregatedSummary(name: staffInfo.name));
      facilityStaffData[staffInfo.location]![staffInfo.name]!.dailyHours[record.date] = (facilityStaffData[staffInfo.location]![staffInfo.name]!.dailyHours[record.date] ?? 0) + record.hoursWorked;
    }

    if(mounted){
      setState(() {
        _allRecords = records;
        _facilitySummaries = facilityData;
        _designationSummaries = designationData;
        _facilityStaffSummaries = facilityStaffData;
        _dateRangeForTables = dateRange;
        _totalHoursAll = records.fold(0.0, (sum, r) => sum + r.hoursWorked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Analysis Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: drawer2(context),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isInitialState
                ? const Center(child: Text("Please select filters and click 'Load Dashboard' to view analysis."))
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                : _buildDashboardBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text('${DateFormat.yMd().format(_startDate)} - ${DateFormat.yMd().format(_endDate)}'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            DropdownButtonFormField<String>(
              value: _selectedFacility, hint: const Text('Facility'),
              decoration: const InputDecoration(labelText: 'Facility', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 220)),
              items: _availableFacilities.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) => setState(() { _selectedFacility = value; _updateStaffFilter(); }),
            ),
            DropdownButtonFormField<String>(
              value: _selectedDesignation, hint: const Text('Designation'),
              decoration: const InputDecoration(labelText: 'Designation', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 220)),
              items: _availableDesignations.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) => setState(() { _selectedDesignation = value; _updateStaffFilter(); }),
            ),
            DropdownButtonFormField<String>(
              value: _selectedStaffId, hint: const Text('Staff'),
              decoration: const InputDecoration(labelText: 'Staff', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 220)),
              items: [const DropdownMenuItem<String>(value: null, child: Text('All Staff')), ..._availableStaff.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))],
              onChanged: (value) => setState(() => _selectedStaffId = value),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart_rounded),
              label: const Text('Load Dashboard'),
              onPressed: _isLoading ? null : _loadDashboardData,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: SizedBox(
          width: 350, height: 350,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: PickerDateRange(_startDate, _endDate),
            maxDate: DateTime.now(),
            showActionButtons: true,
            onSubmit: (Object? value) {
              if (value is PickerDateRange) {
                setState(() {
                  _startDate = value.startDate ?? _startDate;
                  _endDate = value.endDate ?? value.startDate ?? _endDate;
                });
              }
              Navigator.pop(context);
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardBody() {
    if (_allRecords.isEmpty) return const Center(child: Text("No attendance records found for the selected criteria."));

    final top10Facilities = _facilitySummaries.values.toList()
      ..sort((a,b) => b.totalHours.compareTo(a.totalHours));
    final chartData = top10Facilities.take(10).map((s) => _ChartData(s.name, s.totalHours)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKpiSection(),
          const SizedBox(height: 24),
          _buildChartCard("Top 10 Facilities by Hours",
              SfCartesianChart(
                  primaryXAxis: CategoryAxis(
                      labelRotation: -45,
                      majorGridLines: const MajorGridLines(width: 0) // Cleaner look
                  ),
                  primaryYAxis: NumericAxis(
                      majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5,5]) // Dotted grid lines
                  ),
                  // FIX IS HERE: Changed ChartSeries to CartesianSeries
                  series: <CartesianSeries>[
                    BarSeries<_ChartData, String>(
                        dataSource: chartData,
                        xValueMapper: (d,_) => d.category,
                        yValueMapper: (d,_) => d.value,
                        dataLabelSettings: const DataLabelSettings(isVisible: true, labelAlignment: ChartDataLabelAlignment.top),
                        color: Colors.teal,
                        borderRadius: const BorderRadius.all(Radius.circular(5))
                    )
                  ]
              )
          ),
          const SizedBox(height: 24),
          _buildFacilitySummaryTable(),
          const SizedBox(height: 24),
          _buildDesignationSummaryTable(),
        ],
      ),
    );
  }

  Widget _buildKpiSection(){
    return Wrap(
      spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
      children: [
        _buildKpiCard("Total Hours Logged", _totalHoursAll.toStringAsFixed(1), Icons.timer_rounded, Colors.blue.shade800),
        _buildKpiCard("Active Staff", _allRecords.map((r) => r.staffId).toSet().length.toString(), Icons.person_4_rounded, Colors.green.shade700),
        _buildKpiCard("Facilities Reporting", _facilitySummaries.keys.length.toString(), Icons.location_city_rounded, Colors.purple.shade700),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 28, color: color)),
            const SizedBox(height: 16),
            Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chartWidget) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 350, child: chartWidget),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitySummaryTable() {
    final sortedFacilities = _facilityStaffSummaries.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Attendance by Facility", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Location / Staff')),
                ..._dateRangeForTables.map((date) => DataColumn(label: Text(DateFormat('EEE\nMMM dd').format(date)), numeric: true)),
                const DataColumn(label: Text('Total'), numeric: true),
              ],
              rows: sortedFacilities.expand((facility) {
                final staffSummaries = _facilityStaffSummaries[facility]!;
                final sortedStaff = staffSummaries.keys.toList()..sort();

                final facilityTotal = staffSummaries.values.fold(0.0, (sum, s) => sum + s.totalHours);

                return [
                  DataRow(
                    color: WidgetStateProperty.all(Colors.blue.withOpacity(0.1)),
                    cells: [
                      DataCell(Text(facility, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ..._dateRangeForTables.map((date) {
                        final dailyTotal = staffSummaries.values.fold(0.0, (sum, s) => sum + (s.dailyHours[date] ?? 0.0));
                        return DataCell(Text(dailyTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)));
                      }),
                      DataCell(Text(facilityTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  ...sortedStaff.map((staffName) {
                    final summary = staffSummaries[staffName]!;
                    return DataRow(cells: [
                      DataCell(Padding(padding: const EdgeInsets.only(left: 16.0), child: Text(staffName))),
                      ..._dateRangeForTables.map((date) => DataCell(Text((summary.dailyHours[date] ?? 0).toStringAsFixed(2)))),
                      DataCell(Text(summary.totalHours.toStringAsFixed(2))),
                    ]);
                  })
                ];
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesignationSummaryTable() {
    final sortedDesignations = _designationSummaries.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Attendance by Designation", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Designation')),
                ..._dateRangeForTables.map((date) => DataColumn(label: Text(DateFormat('EEE\nMMM dd').format(date)), numeric: true)),
                const DataColumn(label: Text('Total'), numeric: true),
              ],
              rows: sortedDesignations.map((designation) {
                final summary = _designationSummaries[designation]!;
                return DataRow(cells: [
                  DataCell(Text(summary.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ..._dateRangeForTables.map((date) => DataCell(Text((summary.dailyHours[date] ?? 0).toStringAsFixed(2)))),
                  DataCell(Text(summary.totalHours.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}