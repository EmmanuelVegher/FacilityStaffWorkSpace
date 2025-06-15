// A DEDICATED, FEATURE-RICH PAGE FOR ATTENDANCE ANALYSIS (FINAL OPTIMIZED VERSION)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';


import '../../widgets/drawer2.dart'; // Assuming a state-level drawer
// NEW WIDGET: Animates a number from its old value to a new one.
class AnimatedNumberText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final Duration duration;
  final int fractionDigits;
  final String suffix;

  const AnimatedNumberText(
      this.value, {
        super.key,
        this.style,
        this.duration = const Duration(milliseconds: 1200),
        this.fractionDigits = 1,
        this.suffix = '',
      });

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder will animate from the previous 'end' value to the new one.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      builder: (context, animatedValue, child) {
        // Determine if the original value was an integer to format correctly.
        final isInt = value is int && fractionDigits == 0;
        final textValue = isInt
            ? animatedValue.toInt().toString()
            : animatedValue.toStringAsFixed(fractionDigits);

        return Text(
          '$textValue$suffix',
          style: style,
        );
      },
    );
  }
}
// --- DATA MODELS ---
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
  final Color? color;
  _ChartData(this.category, this.value, [this.color]);
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

  // NEW: Add ScrollControllers for the tables
  final ScrollController _facilityTableController = ScrollController();
  final ScrollController _designationTableController = ScrollController();

  bool _isLoading = false;
  bool _isExporting = false;
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

  // --- Data & Chart Keys ---
  List<AttendanceRecord> _allRecords = [];
  Map<String, AggregatedSummary> _facilitySummaries = {};
  Map<String, AggregatedSummary> _designationSummaries = {};
  Map<String, Map<String, AggregatedSummary>> _facilityStaffSummaries = {};
  List<DateTime> _dateRangeForTables = [];
  double _totalHoursAll = 0;
  final GlobalKey _barChartKey = GlobalKey();
  final GlobalKey _facilityPieChartKey = GlobalKey();
  final GlobalKey _designationPieChartKey = GlobalKey();


  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  @override
  void dispose() {
    // NEW: Dispose of the controllers
    _facilityTableController.dispose();
    _designationTableController.dispose();
    super.dispose();
  }


  Future<void> _initializeFilters() async {
    // ... (This method remains unchanged)
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
    // ... (This method remains unchanged)
    if(_userState == null) return [];
    final snapshot = await _firestore.collection('Staff').where('state', isEqualTo: _userState).where('staffCategory', isEqualTo: "Facility Staff").get();
    final Set<String> values = {};
    for (final doc in snapshot.docs) {
      final value = doc.data()[field] as String?;
      if (value != null && value.isNotEmpty) values.add(value);
    }
    final sortedList = values.toList()..sort();
    return sortedList;
  }

  Future<void> _updateStaffFilter() async {
    // ... (This method remains unchanged)
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

// --- REWRITTEN & HIGHLY OPTIMIZED DATA LOADING ---
  Future<void> _loadDashboardData() async {
    if (_userState == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User state not found.")));
      return;
    }
    setState(() { _isLoading = true; _isInitialState = false; _errorMessage = null; });

    try {
      // 1. Get the list of staff that match the filters (this is one fast query).
      var staffQuery = _firestore.collection('Staff').where('state', isEqualTo: _userState);
      if(_selectedFacility != null && _selectedFacility != 'All Facilities') staffQuery = staffQuery.where('location', isEqualTo: _selectedFacility);
      if(_selectedDesignation != null && _selectedDesignation != 'All Designations') staffQuery = staffQuery.where('designation', isEqualTo: _selectedDesignation);
      if(_selectedStaffId != null) staffQuery = staffQuery.where(FieldPath.documentId, isEqualTo: _selectedStaffId);

      final staffSnapshot = await staffQuery.get();
      final staffList = staffSnapshot.docs.map((doc) => StaffInfo(id: doc.id, name: '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'.trim(), location: doc.data()['location'] ?? 'N/A', designation: doc.data()['designation'] ?? 'N/A')).toList();

      if (staffList.isEmpty) {
        _processAndAggregateData([], [], []);
        if (mounted) setState(() => _isLoading = false); // Stop loading if no staff
        return;
      }

      // 2. Create a list to hold all the asynchronous read operations.
      final List<Future<DocumentSnapshot>> futures = [];
      final dateRange = List.generate(_endDate.difference(_startDate).inDays + 1, (i) => _startDate.add(Duration(days: i)));

      for (var staff in staffList) {
        for(var date in dateRange) {
          final dateStr = DateFormat('dd-MMMM-yyyy').format(date);
          // 3. Add the Future to the list without awaiting.
          futures.add(_firestore.collection('Staff').doc(staff.id).collection('Record').doc(dateStr).get());
        }
      }

      // 4. Execute all reads in parallel.
      final List<DocumentSnapshot> results = await Future.wait(futures);

      // 5. Process the results in memory.
      List<AttendanceRecord> allRecords = [];
      int i = 0;
      for (var staff in staffList) {
        for(var date in dateRange) {
          final recordDoc = results[i];
          if(recordDoc.exists) {
            // --- FIX IS HERE ---
            // Create a safe, non-nullable variable for the data
            final data = recordDoc.data() as Map<String, dynamic>;
            // Now we can safely use the [] operator on `data`
            allRecords.add(
                AttendanceRecord(
                    staffId: staff.id, // Use staff.id for consistency
                    date: date,
                    hoursWorked: (data['noOfHours'] as num? ?? 0.0).toDouble()
                )
            );
          }
          i++;
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
    // ... (This method remains unchanged)
    final facilityData = <String, AggregatedSummary>{};
    final designationData = <String, AggregatedSummary>{};
    final facilityStaffData = <String, Map<String, AggregatedSummary>>{};
    final staffMap = {for(var s in staff) s.id: s};

    for(final record in records) {
      final staffInfo = staffMap[record.staffId];
      if(staffInfo == null) continue;
      facilityData.putIfAbsent(staffInfo.location, () => AggregatedSummary(name: staffInfo.location));
      facilityData[staffInfo.location]!.dailyHours[record.date] = (facilityData[staffInfo.location]!.dailyHours[record.date] ?? 0) + record.hoursWorked;
      designationData.putIfAbsent(staffInfo.designation, () => AggregatedSummary(name: staffInfo.designation));
      designationData[staffInfo.designation]!.dailyHours[record.date] = (designationData[staffInfo.designation]!.dailyHours[record.date] ?? 0) + record.hoursWorked;
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

  // --- UI BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Analysis Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if(_isExporting)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined),
              tooltip: "Download Options",
              onSelected: (value) {
                if(value == 'csv') _exportToCsv();
                if(value == 'pdf') _exportChartsToPdf();
              },
              enabled: !_isLoading && _allRecords.isNotEmpty,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.table_chart_outlined), title: Text("Export Data (CSV)"))),
                const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text("Export Charts (PDF)"))),
              ],
            )
        ],
      ),
      drawer: drawer2(context),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                : _buildDashboardBody(), // Always build the body
          ),
        ],
      ),
    );
  }
  // All other UI builder methods (_buildFilterBar, _showDateRangePicker, _buildKpiSection, etc.) remain unchanged...
  // ... they are included here for completeness ...

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
              decoration: const InputDecoration(labelText: 'Facility', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 600)),
              items: _availableFacilities.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) => setState(() { _selectedFacility = value; _updateStaffFilter(); }),
            ),
            DropdownButtonFormField<String>(
              value: _selectedDesignation, hint: const Text('Designation'),
              decoration: const InputDecoration(labelText: 'Designation', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 400)),
              items: _availableDesignations.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) => setState(() { _selectedDesignation = value; _updateStaffFilter(); }),
            ) ,
            DropdownButtonFormField<String>(
              value: _selectedStaffId, hint: const Text('Staff'),
              decoration: const InputDecoration(labelText: 'Staff', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 400)),
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

  // UPDATED: This method handles the initial state hint
  Widget _buildDashboardBody() {
    // The data for the chart will be empty on initial load, showing an empty chart.
    final top10Facilities = _facilitySummaries.values.toList()..sort((a,b) => b.totalHours.compareTo(a.totalHours));
    final chartData = top10Facilities.take(10).map((s) => _ChartData(s.name, s.totalHours)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isInitialState)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Center(
                child: Text(
                  "Please select filters and click 'Load Dashboard' to view analysis.",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          _buildKpiSection(),
          const SizedBox(height: 24),
          _buildChartCard("Top 10 Facilities by Hours",
              SfCartesianChart(
                  primaryXAxis: CategoryAxis(labelRotation: -45, majorGridLines: const MajorGridLines(width: 0)),
                  primaryYAxis: NumericAxis(majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5,5])),
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


  // UPDATED: This method calls the new KpiCard with appropriate formatting
  Widget _buildKpiSection(){
    return Wrap(
      spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
      children: [
        _buildKpiCard("Total Hours Logged", _totalHoursAll, Icons.timer_rounded, Colors.blue.shade800, fractionDigits: 1),
        _buildKpiCard("Active Staff", _allRecords.map((r) => r.staffId).toSet().length, Icons.person_4_rounded, Colors.green.shade700),
        _buildKpiCard("Facilities Reporting", _facilitySummaries.keys.length, Icons.location_city_rounded, Colors.purple.shade700),
      ],
    );
  }


// UPDATED: This method now uses the AnimatedNumberText widget
  Widget _buildKpiCard(String title, num value, IconData icon, Color color, {int fractionDigits = 0, String suffix = ''}) {
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
            AnimatedNumberText(
              value,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
              fractionDigits: fractionDigits,
              suffix: suffix,
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }


  Widget _buildChartCard(String title, Widget chartWidget, {Key? key}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: RepaintBoundary(
        key: key,
        child: Container(
          color: Colors.white,
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
      ),
    );
  }

  Widget _buildSummaryPieChart(String title, Map<String, AggregatedSummary> summaryMap, {Key? key}) {
    if (summaryMap.isEmpty) return const SizedBox.shrink();

    final sortedList = summaryMap.values.toList()..sort((a,b) => b.totalHours.compareTo(a.totalHours));
    List<_ChartData> chartData = [];
    double othersHours = 0;

    for (int i=0; i < sortedList.length; i++) {
      if (i < 6) { // Top 6
        chartData.add(_ChartData(sortedList[i].name, sortedList[i].totalHours));
      } else {
        othersHours += sortedList[i].totalHours;
      }
    }
    if (othersHours > 0) {
      chartData.add(_ChartData("Others", othersHours));
    }

    return _buildChartCard(title,
      SfCircularChart(
          legend: const Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
          series: <CircularSeries>[
            PieSeries<_ChartData, String>(
              dataSource: chartData,
              xValueMapper: (d,_) => d.category,
              yValueMapper: (d,_) => d.value,
              dataLabelMapper: (d,_) => '${d.category}\n${d.value.toStringAsFixed(1)} hrs',
              dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside),
            )
          ]
      ),
      key: key,
    );
  }

  // REPLACED: This method now includes scroll buttons
  Widget _buildFacilitySummaryTable() {
    final sortedFacilities = _facilityStaffSummaries.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Attendance by Facility", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SingleChildScrollView(
                controller: _facilityTableController, // Assign controller
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  // ... (DataTable columns and rows are unchanged)
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
              // NEW: Row for scroll buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      _facilityTableController.animateTo(
                        _facilityTableController.offset - 300, // scroll left
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () {
                      _facilityTableController.animateTo(
                        _facilityTableController.offset + 300, // scroll right
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSummaryPieChart("Facility Hours Distribution", _facilitySummaries, key: _facilityPieChartKey),
      ],
    );
  }

  // REPLACED: This method now includes scroll buttons
  Widget _buildDesignationSummaryTable() {
    final sortedDesignations = _designationSummaries.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Attendance by Designation", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SingleChildScrollView(
                controller: _designationTableController, // Assign controller
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  // ... (DataTable columns and rows are unchanged)
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
              // NEW: Row for scroll buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      _designationTableController.animateTo(
                        _designationTableController.offset - 300, // scroll left
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () {
                      _designationTableController.animateTo(
                        _designationTableController.offset + 300, // scroll right
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSummaryPieChart("Designation Hours Distribution", _designationSummaries, key: _designationPieChartKey),
      ],
    );
  }

  // --- NEW EXPORT AND HELPER METHODS ---
  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);
    List<List<dynamic>> rows = [];

    // Facility Summary
    rows.add(['Attendance Summary by Facility']);
    rows.add(['Facility', 'Total Hours']);
    _facilitySummaries.forEach((key, value) {
      rows.add([key, value.totalHours.toStringAsFixed(2)]);
    });
    rows.add([]); // Spacer

    // Designation Summary
    rows.add(['Attendance Summary by Designation']);
    rows.add(['Designation', 'Total Hours']);
    _designationSummaries.forEach((key, value) {
      rows.add([key, value.totalHours.toStringAsFixed(2)]);
    });

    String csvData = const ListToCsvConverter().convert(rows);
    _triggerDownload(utf8.encode(csvData), 'attendance_summary_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');

    setState(() => _isExporting = false);
  }

  Future<void> _exportChartsToPdf() async {
    setState(() => _isExporting = true);
    try {
      final barChartBytes = await _captureChartPng(_barChartKey);
      final facilityPieBytes = await _captureChartPng(_facilityPieChartKey);
      final designationPieBytes = await _captureChartPng(_designationPieChartKey);

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Header(text: "Attendance Charts Report"),
        build: (context) => [
          pw.Text("Filters Applied", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
          pw.Text("Date Range: ${DateFormat.yMd().format(_startDate)} to ${DateFormat.yMd().format(_endDate)}"),
          pw.Text("Facility: ${_selectedFacility ?? 'All'}"),
          pw.Text("Designation: ${_selectedDesignation ?? 'All'}"),
          pw.Divider(height: 20),
          if (barChartBytes != null) ...[
            pw.Text("Top 10 Facilities by Hours", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Image(pw.MemoryImage(barChartBytes), fit: pw.BoxFit.contain, height: 250),
            pw.SizedBox(height: 20),
          ],
          if (facilityPieBytes != null) ...[
            pw.Text("Facility Hours Distribution", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Image(pw.MemoryImage(facilityPieBytes), fit: pw.BoxFit.contain, height: 250),
            pw.SizedBox(height: 20),
          ],
          if (designationPieBytes != null) ...[
            pw.Text("Designation Hours Distribution", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Image(pw.MemoryImage(designationPieBytes), fit: pw.BoxFit.contain, height: 250),
          ],
        ],
      ));

      final pdfBytes = await pdf.save();
      _triggerDownload(pdfBytes, 'attendance_charts_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf', 'application/pdf');

    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
    } finally {
      if(mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List?> _captureChartPng(GlobalKey key) async {
    try {
      if (key.currentContext == null) return null;
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing chart: $e");
      return null;
    }
  }

  void _triggerDownload(List<int> bytes, String filename, [String mimeType = 'text/csv']) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

}