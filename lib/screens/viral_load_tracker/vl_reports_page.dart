// lib/pages/reports/user_facility_vl_tracking_page.dart

// USER-FACILITY-SPECIFIC VIRAL LOAD (VL) TRACKING REPORTS PAGE
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:csv/csv.dart';

import '../../widgets/drawer.dart';
import '../../widgets/drawer2.dart';

// --- DATA MODELS ---
class VlCallLog {
  final String? artId, callStatus, clientName, firebaseAuthId, phoneNumberCalled;
  final String? trackedBy, trackerDesignation, trackerFacility, trackerState, uuid;
  final DateTime? callDateTime, syncedAt;
  final int? callDurationInSeconds, vlEligibleRecordId;

  VlCallLog({
    this.artId, this.callDateTime, this.callDurationInSeconds, this.callStatus,
    this.clientName, this.firebaseAuthId, this.phoneNumberCalled, this.syncedAt,
    this.trackedBy, this.trackerDesignation, this.trackerFacility, this.trackerState,
    this.uuid, this.vlEligibleRecordId,
  });

  factory VlCallLog.fromJson(Map<String, dynamic> data) {
    return VlCallLog(
      artId: data['artId'] as String?,
      callDateTime: (data['callDateTime'] as Timestamp?)?.toDate(),
      callDurationInSeconds: data['callDurationInSeconds'] as int?,
      callStatus: data['callStatus'] as String?,
      clientName: data['clientName'] as String?,
      firebaseAuthId: data['firebaseAuthId'] as String?,
      phoneNumberCalled: data['phoneNumberCalled'] as String?,
      syncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
      trackedBy: data['trackedBy'] as String?,
      trackerDesignation: data['trackerDesignation'] as String?,
      trackerFacility: data['trackerFacility'] as String?,
      trackerState: data['trackerState'] as String?,
      uuid: data['uuid'] as String?,
      vlEligibleRecordId: data['vlEligibleRecordId'] as int?,
    );
  }
}

class VlReportSummary {
  final double percentageResultsReceived, percentageSamplesCollected;
  final int refillsDueInQuarter, resultsReturned, samplesCollected;
  final int suppressed, unsuppressed, totalEligibleClientsInFilter;

  VlReportSummary({
    required this.percentageResultsReceived, required this.percentageSamplesCollected,
    required this.refillsDueInQuarter, required this.resultsReturned, required this.samplesCollected,
    required this.suppressed, required this.unsuppressed, required this.totalEligibleClientsInFilter,
  });

  factory VlReportSummary.fromJson(Map<String, dynamic> data) {
    return VlReportSummary(
      percentageResultsReceived: (data['percentageResultsReceived'] as num?)?.toDouble() ?? 0.0,
      percentageSamplesCollected: (data['percentageSamplesCollected'] as num?)?.toDouble() ?? 0.0,
      refillsDueInQuarter: data['refillsDueInQuarter'] as int? ?? 0,
      resultsReturned: data['resultsReturned'] as int? ?? 0,
      samplesCollected: data['samplesCollected'] as int? ?? 0,
      suppressed: data['suppressed'] as int? ?? 0,
      unsuppressed: data['unsuppressed'] as int? ?? 0,
      totalEligibleClientsInFilter: data['totalEligibleClientsInFilter'] as int? ?? 0,
    );
  }
}

// --- GlobalKeys for chart export ---
final GlobalKey _callOutcomesChartKey = GlobalKey();

class UserFacilityVlTrackingPageWeb extends StatefulWidget {
  const UserFacilityVlTrackingPageWeb({super.key});
  @override
  _UserFacilityVlTrackingPageWebState createState() => _UserFacilityVlTrackingPageWebState();
}

class _UserFacilityVlTrackingPageWebState extends State<UserFacilityVlTrackingPageWeb> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isFacilitiesLoading = false; // FIX: Variable declared here

  List<VlCallLog> _masterLogList = [];
  VlReportSummary? _summary; // Only one summary for one facility
  DateTime? startDate, endDate;
  bool isLoading = false, _isInitialState = true, _isFilterLoading = true;
  String? _errorMessage, _summaryErrorMessage;
  bool _isExporting = false;
  List<ScrollController> _logTableControllers = [];
  int _currentlyExpandedDateIndex = -1;

  // --- User-specific location ---
  String? _currentUserState;
  String? _currentUserFacility;

  // --- Filter State ---
  List<String> _availableQuarters = [];
  String? _selectedQuarter;

  // --- Chart Data ---
  List<MapEntry<String, int>> callOutcomesChartData = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Set the start date to 6 days before today.
    startDate = DateTime(now.year, now.month, now.day - 6);
    endDate = DateTime(now.year, now.month, now.day);
    _initializePage();
  }
  @override
  void dispose() {
    for (final controller in _logTableControllers) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _initializePage() async {
    // Set the main loading flags at the start of the process.
    setState(() {
      isLoading = true;
      _isFilterLoading = true;
    });

    try {
      // Set up synchronous filter options first.
      _generateQuarterList();

      // Load the current user's profile to get their assigned state and facility.
      await _loadCurrentUserBio();

      if (mounted) {
        // The filter UI is now ready.
        setState(() => _isFilterLoading = false);

        // Check if the user's profile is valid before proceeding.
        if (_currentUserState != null && _currentUserFacility != null) {
          // Automatically load reports with the default filters.
          // This method will set `isLoading` to false when it completes.
          await _loadReports();
        } else {
          // If the profile is invalid, stop the main loading indicator.
          // The error message will have already been set in _loadCurrentUserBio.
          setState(() => isLoading = false);
        }
      }
    } catch (e, s) {
      debugPrint("Error during initial page load: $e\n$s");
      if (mounted) {
        setState(() {
          _errorMessage = "An error occurred during page initialization: $e";
          isLoading = false;
          _isFilterLoading = false;
        });
      }
    }
  }

  Future<void> _loadCurrentUserBio() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final docSnapshot = await _firestore.collection('Staff').doc(user.uid).get();

      if(docSnapshot.exists && mounted) {
        final data = docSnapshot.data();
        final state = data?['state'] as String?;
        final facility = data?['location'] as String?; // Use 'location' field

        if (state == null || state.isEmpty || facility == null || facility.isEmpty) {
          throw Exception("Your user profile is missing a 'state' or 'location' field.");
        }
        setState(() {
          _currentUserState = state;
          _currentUserFacility = facility;
        });
      } else {
        throw Exception("Your user profile was not found in the 'Staff' collection.");
      }
    } catch (e, s) {
      debugPrint("Error loading user bio: $e\n$s");
      if(mounted) setState(() => _errorMessage = "Could not load user profile: $e");
    }
  }

  String _getQuarterString(DateTime date) {
    int year = date.year;
    int month = date.month;
    int fiscalYear = (month >= 10) ? year + 1 : year;
    String quarter;
    if (month >= 10) quarter = 'Q1';
    else if (month >= 7) quarter = 'Q4';
    else if (month >= 4) quarter = 'Q3';
    else quarter = 'Q2';
    return '$quarter (FY${fiscalYear.toString().substring(2)})';
  }

  void _generateQuarterList() {
    List<String> quarters = [];
    DateTime date = DateTime.now();
    for (int i = 0; i < 8; i++) {
      quarters.add(_getQuarterString(date));
      date = DateTime(date.year, date.month - 3, 1);
    }
    setState(() {
      _availableQuarters = quarters.toSet().toList();
      _selectedQuarter = _availableQuarters.first;
    });
  }

  Future<void> _loadReports() async {
    if (_currentUserState == null || _currentUserFacility == null) {
      _showSnackBar("Cannot load reports: Your state or facility is missing.");
      return;
    }
    if (_selectedQuarter == null) {
      _showSnackBar("Please select a quarter to generate a report.");
      return;
    }
    setState(() {
      isLoading = true;
      _isInitialState = false;
      _errorMessage = _summaryErrorMessage = null;
      _masterLogList.clear();
      _summary = null;
    });

    try {
      await Future.wait([_fetchCallLogs(), _fetchSummary()]);
      if (mounted) {
        _applyAllFiltersAndRecalculate();
        if (_masterLogList.isEmpty && _summary == null) {
          _showSnackBar("No VL data found for the selected criteria.");
        }
      }
    } catch (e, s) {
      debugPrint("Error loading reports: $e\n$s");
      if (mounted) setState(() => _errorMessage = "An error occurred: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchCallLogs() async {
    Query query = _firestore.collection('VlCallLogs')
        .where('trackerState', isEqualTo: _currentUserState)
        .where('trackerFacility', isEqualTo: _currentUserFacility) // Filter by user's facility
        .where('callDateTime', isGreaterThanOrEqualTo: startDate)
        .where('callDateTime', isLessThanOrEqualTo: endDate!.add(const Duration(days: 1)));

    final querySnapshot = await query.orderBy('callDateTime', descending: true).get();
    if(mounted) {
      _masterLogList = querySnapshot.docs.map((doc) => VlCallLog.fromJson(doc.data() as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _fetchSummary() async {
    try {
      final path = 'VlReportSummaries/$_currentUserState/$_currentUserFacility/$_selectedQuarter';
      final docSnapshot = await _firestore.doc(path).get();

      if(mounted) {
        if (docSnapshot.exists) {
          setState(() => _summary = VlReportSummary.fromJson(docSnapshot.data() as Map<String, dynamic>));
        } else {
          setState(() => _summaryErrorMessage = "No summary found for $_selectedQuarter.");
        }
      }
    } catch(e,s) {
      debugPrint("Error fetching summary: $e\n$s");
      if(mounted) setState(() => _summaryErrorMessage = "Failed to load VL summary.");
    }
  }

  void _applyAllFiltersAndRecalculate() {
    setState(() {
      _prepareChartData();
      for (final controller in _logTableControllers) { controller.dispose(); }
      final dateGroups = _groupLogsByDate();
      _logTableControllers = List.generate(dateGroups.length, (_) => ScrollController());
      _currentlyExpandedDateIndex = _masterLogList.isNotEmpty ? 0 : -1;
    });
  }

  void _prepareChartData() {
    callOutcomesChartData = _getCallOutcomesChartData();
  }

  Color _getStatusColor(String status) {
    String lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'answered':
      case 'incoming answered':
      case 'completed':
        return Colors.green.shade700;
      case 'outgoing failed/not answered':
      case 'unknown (no outgoing log detail)':
      case 'missed':
      case 'missed call':
      case 'call failed':
      case 'call dropped':
      case 'unknown (no log detail)':
        return Colors.red.shade700;
      case 'call busy':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildStatusCell(String? status) {
    if (status == null || status.isEmpty) {
      return const Text('N/A');
    }
    Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_isFilterLoading) {
      bodyContent = const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Loading User Profile...")],));
    } else if (isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      bodyContent = Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)));
    } else {
      bodyContent = _buildDashboardContent();
    }

    String appBarTitle = 'My Facility VL Report';
    if(_currentUserFacility != null) {
      appBarTitle = 'VL Report for $_currentUserFacility';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _buildAppBarActions(),
      ),
      drawer: drawer(context),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      if (_isExporting)
        const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
      else
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: "Export Options",
          onSelected: (value) async { if (value == 'csv') await _exportToCSV(); },
          enabled: !isLoading && !_isInitialState && (_masterLogList.isNotEmpty || _summary != null),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.grid_on_outlined, color: Colors.green), title: Text('Export CSV'))),
          ],
        ),
    ];
  }

  Widget _buildFilterBar() {
    if (_isFilterLoading || _currentUserState == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8.0), elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16.0, runSpacing: 12.0, alignment: WrapAlignment.start,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: _selectedQuarter,
                hint: const Text('Select Quarter'),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Quarter', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
                items: _availableQuarters.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                onChanged: (value) => setState(() => _selectedQuarter = value),
              ),
            ),

            OutlinedButton.icon(
              onPressed: isLoading ? null : _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text((startDate != null && endDate != null) ? '${_formatDateWithSuffix(startDate!)} - ${_formatDateWithSuffix(endDate!)}' : 'Select Dates'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),

            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply Filter'),
              onPressed: isLoading ? null : _loadReports,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_isInitialState && !isLoading) {
      return Center(child: Text("Select a quarter and apply filter to view your facility's VL report.", style: TextStyle(color: Colors.grey.shade700)));
    }
    if (_masterLogList.isEmpty && _summary == null && !isLoading) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("No VL data found for the selected criteria.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700))));
    }

    final Map<String, List<VlCallLog>> dailyGroupedReports = _groupLogsByDate();
    final dailyGroupedKeys = dailyGroupedReports.keys.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_summary != null || _summaryErrorMessage != null) ...[
            _buildVlSummarySection(),
            const SizedBox(height: 24),
          ],
          if(_masterLogList.isNotEmpty)...[
            Text('Call Log Analysis', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _buildCallLogChartSection(),
            const SizedBox(height: 30),
            Text('Detailed Call Logs', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            _buildDetailedLogSection(dailyGroupedKeys, dailyGroupedReports),
          ]
        ],
      ),
    );
  }

  Widget _buildVlSummarySection() {
    if (_summaryErrorMessage != null) {
      return Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text("Summary Error: $_summaryErrorMessage", style: TextStyle(color: Colors.red.shade800)))])));
    }
    if (_summary == null) return const SizedBox.shrink();

    final summary = _summary!;
    final double sampleCollectionRate = summary.totalEligibleClientsInFilter > 0 ? (summary.samplesCollected / summary.totalEligibleClientsInFilter) * 100 : 0.0;
    final double resultReturnRate = summary.samplesCollected > 0 ? (summary.resultsReturned / summary.samplesCollected) * 100 : 0.0;

    return Card(
      clipBehavior: Clip.antiAlias, elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VL Summary for $_selectedQuarter', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800)),
            const Divider(height: 24),
            Wrap(
              spacing: 20.0, runSpacing: 20.0, alignment: WrapAlignment.spaceAround,
              children: [
                _buildInfoTile(iconWidget: Icon(Icons.people_alt_outlined, size: 36, color: Colors.blue.shade700), label: 'Total Eligible Clients', value: summary.totalEligibleClientsInFilter.toString()),
                _buildInfoTile(iconWidget: Icon(Icons.bloodtype_outlined, size: 36, color: Colors.red.shade700), label: 'Samples Collected', value: summary.samplesCollected.toString(), subtitle: '${sampleCollectionRate.toStringAsFixed(1)}% of eligible'),
                _buildInfoTile(iconWidget: Icon(Icons.assignment_turned_in_outlined, size: 36, color: Colors.green.shade700), label: 'Results Returned', value: summary.resultsReturned.toString(), subtitle: '${resultReturnRate.toStringAsFixed(1)}% of samples'),
                _buildInfoTile(iconWidget: Icon(Icons.check_circle_outline, size: 36, color: Colors.green.shade900), label: 'Suppressed', value: summary.suppressed.toString()),
                _buildInfoTile(iconWidget: Icon(Icons.warning_amber_rounded, size: 36, color: Colors.orange.shade900), label: 'Unsuppressed', value: summary.unsuppressed.toString()),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCallLogChartSection() {
    return Wrap(
      spacing: 20.0, runSpacing: 20.0, alignment: WrapAlignment.start,
      children: [
        _buildChartCard(title: 'Call Outcome Distribution', chartKey: _callOutcomesChartKey, chart: SfCircularChart(annotations: (callOutcomesChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null, legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap), series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: callOutcomesChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])),
      ],
    );
  }

  Widget _buildDetailedLogSection(List<String> dailyGroupedKeys, Map<String, List<VlCallLog>> dailyGroupedReports) {
    if (dailyGroupedKeys.isEmpty) { return const Card(child: SizedBox(height: 100, child: Center(child: Text("No call logs match the current filters.")))); }
    return ExpansionPanelList(
      expansionCallback: (int index, bool isExpanded) => setState(() => _currentlyExpandedDateIndex = _currentlyExpandedDateIndex == index ? -1 : index),
      animationDuration: const Duration(milliseconds: 300),
      children: dailyGroupedKeys.map<ExpansionPanel>((String dateKey) {
        final index = dailyGroupedKeys.indexOf(dateKey);
        final dailyLogList = dailyGroupedReports[dateKey]!;
        final bool isExpanded = _currentlyExpandedDateIndex == index;
        return ExpansionPanel(
          isExpanded: isExpanded, canTapOnHeader: true,
          headerBuilder: (BuildContext context, bool isExpanded) => ListTile(title: Text(dateKey, style: const TextStyle(fontWeight: FontWeight.bold))),
          body: SingleChildScrollView(
            controller: _logTableControllers.length > index ? _logTableControllers[index] : null, scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DataTable(
                columns: const [DataColumn(label: Text('Call Status')), DataColumn(label: Text('Client Name')), DataColumn(label: Text('ART ID')), DataColumn(label: Text('Phone No.')), DataColumn(label: Text('Time')), DataColumn(label: Text('Duration')), DataColumn(label: Text('Tracked By'))],
                rows: dailyLogList.map((log) => DataRow(cells: [
                  DataCell(_buildStatusCell(log.callStatus)),
                  DataCell(Text(log.clientName ?? 'N/A')), DataCell(Text(log.artId ?? 'N/A')), DataCell(Text(log.phoneNumberCalled ?? 'N/A')), DataCell(Text(log.callDateTime != null ? DateFormat('HH:mm').format(log.callDateTime!) : 'N/A')), DataCell(Text(formatDuration(log.callDurationInSeconds ?? 0))), DataCell(Text(log.trackedBy ?? 'N/A')),
                ])).toList(),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _exportToCSV() async {
    setState(() => _isExporting = true);
    try {
      List<List<dynamic>> rows = [];
      rows.add(['VIRAL LOAD REPORT FOR $_currentUserFacility']);
      rows.add(['Quarter:', _selectedQuarter]);
      rows.add([]);
      rows.add(['Metric', 'Value']);
      if(_summary != null) {
        rows.add(['Total Eligible Clients', _summary!.totalEligibleClientsInFilter]);
        rows.add(['Samples Collected', _summary!.samplesCollected]);
        rows.add(['Results Returned', _summary!.resultsReturned]);
        rows.add(['Suppressed', _summary!.suppressed]);
        rows.add(['Unsuppressed', _summary!.unsuppressed]);
      }
      rows.add([]);
      rows.add(['DETAILED CALL LOGS']);
      rows.add(['Call Status', 'Client Name', 'ART ID', 'Phone No', 'Date', 'Time', 'Duration(s)', 'Tracked By']);
      for (var log in _masterLogList) {
        rows.add([log.callStatus, log.clientName, log.artId, log.phoneNumberCalled, log.callDateTime != null ? DateFormat('yyyy-MM-dd').format(log.callDateTime!) : '', log.callDateTime != null ? DateFormat('HH:mm').format(log.callDateTime!) : '', log.callDurationInSeconds, log.trackedBy]);
      }
      String csvData = const ListToCsvConverter().convert(rows);
      _triggerDownload(utf8.encode(csvData), 'my_facility_vl_report.csv', 'text/csv');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _triggerDownload(List<int> bytes, String filename, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement..href = url..style.display = 'none'..download = filename;
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  void _showSnackBar(String message) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20))); }

  void _showDateRangePicker() { showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Select Date Range'), content: SizedBox(width: 400, height: 450, child: SfDateRangePicker(selectionMode: DateRangePickerSelectionMode.range, initialSelectedRange: (startDate != null && endDate != null) ? PickerDateRange(startDate!, endDate!) : null, showActionButtons: true, onSubmit: (Object? value) { Navigator.pop(context); if (value is PickerDateRange && value.startDate != null) { setState(() { startDate = value.startDate; endDate = value.endDate ?? value.startDate; }); } }, onCancel: () => Navigator.pop(context))))); }

  String _formatDateWithSuffix(DateTime date) { String day = DateFormat('d').format(date); String suffix = 'th'; int dayInt = int.parse(day); if (dayInt >= 11 && dayInt <= 13) { suffix = 'th'; } else { switch (dayInt % 10) { case 1: suffix = 'st'; break; case 2: suffix = 'nd'; break; case 3: suffix = 'rd'; break; default: suffix = 'th'; } } return DateFormat("d'$suffix'-MMMM-y").format(date); }

  List<MapEntry<String, int>> _getCallOutcomesChartData() { Map<String, int> statusCounts = {}; for (var log in _masterLogList) { String status = log.callStatus?.trim() ?? 'N/A'; if (status.isEmpty) status = 'N/A'; statusCounts[status] = (statusCounts[status] ?? 0) + 1; } return statusCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)); }
  String formatDuration(int totalSeconds) { if (totalSeconds <= 0) return '0s'; final int hours = totalSeconds ~/ 3600; final int minutes = (totalSeconds % 3600) ~/ 60; final int seconds = totalSeconds % 60; List<String> parts = []; if (hours > 0) parts.add('${hours}h'); if (minutes > 0) parts.add('${minutes}m'); if (seconds > 0 || parts.isEmpty) parts.add('${seconds}s'); return parts.join(' '); }
  Map<String, List<VlCallLog>> _groupLogsByDate() { final Map<String, List<VlCallLog>> dailyReports = {}; final DateFormat displayFormat = DateFormat('EEEE, MMMM d, yyyy'); for (var log in _masterLogList) { final dateKey = log.callDateTime != null ? displayFormat.format(log.callDateTime!) : 'Unknown Date'; dailyReports.putIfAbsent(dateKey, () => []).add(log); } return dailyReports; }

  Widget _buildFilterChip(String label, String value, IconData icon, VoidCallback onPressed, {bool disabled = false}) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), InputChip(avatar: _isFacilitiesLoading && label=="Facility" ? const SizedBox(height:18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 18), label: Text(value, overflow: TextOverflow.ellipsis), onPressed: disabled ? null : onPressed, showCheckmark: false, side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.7)), backgroundColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),)]);}
  Widget _buildInfoTile({required Widget iconWidget, required String label, required String value, String? subtitle}) { return Row(mainAxisSize: MainAxisSize.min, children: [ iconWidget, const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), if (subtitle != null && subtitle.isNotEmpty) ...[const SizedBox(height: 2), Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600))], ],), ],); }
  Widget _buildChartCard({required String title, required Widget chart, GlobalKey? chartKey, bool isWide = false}) { return ConstrainedBox(constraints: BoxConstraints(maxWidth: isWide ? 600 : 400, minWidth: 350), child: Card(elevation: 2.0, child: Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 10), SizedBox(height: 250, child: RepaintBoundary(key: chartKey, child: Container(color: Colors.white, child: chart)))],),),),); }

  Future<void> _showMultiSelectDialog({ required BuildContext context, required String title, required List<String> allOptions, required List<String> selectedOptions, required String allKeyword, required Function(List<String>) onConfirm, }) async {
    final tempSelected = List<String>.from(selectedOptions);
    await showDialog(context: context, builder: (dialogContext) {
      return StatefulBuilder(builder: (bldContext, setStateDialog) {
        return AlertDialog(title: Text(title),
            content: SizedBox(width: 350,
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: allOptions.length,
                    itemBuilder: (context, index) {
                      final option = allOptions[index];
                      final isAllOptionKeyword = option == allKeyword;
                      if (isAllOptionKeyword) {
                        return CheckboxListTile(
                          title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold)),
                          value: tempSelected.contains(allKeyword),
                          onChanged: (bool? value) {
                            setStateDialog(() {
                              if (value == true) {
                                tempSelected.clear();
                                tempSelected.addAll(allOptions);
                              } else {
                                tempSelected.clear();
                                tempSelected.add(allKeyword);
                              }
                            });
                          },
                        );
                      } else {
                        return CheckboxListTile(
                          title: Text(option),
                          value: tempSelected.contains(option),
                          onChanged: (bool? value) {
                            setStateDialog(() {
                              if (value == true) {
                                tempSelected.add(option);
                                final allOtherOptions = allOptions.where((o) => o != allKeyword).toSet();
                                if (tempSelected.toSet().containsAll(allOtherOptions)) {
                                  if (!tempSelected.contains(allKeyword)) {
                                    tempSelected.add(allKeyword);
                                  }
                                }
                              } else {
                                tempSelected.remove(option);
                                tempSelected.remove(allKeyword);
                                if(tempSelected.isEmpty){
                                  tempSelected.add(allKeyword);
                                }
                              }
                            });
                          },
                        );
                      }
                    }
                )
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () {
                    final allOtherOptions = allOptions.where((o) => o != allKeyword).toSet();
                    if (tempSelected.toSet().containsAll(allOtherOptions)) {
                      onConfirm([allKeyword]);
                    } else if (tempSelected.contains(allKeyword) && tempSelected.length == 1) {
                      onConfirm([allKeyword]);
                    } else {
                      tempSelected.remove(allKeyword);
                      onConfirm(tempSelected);
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Apply')
              )
            ]
        );
      });
    });
  }
}