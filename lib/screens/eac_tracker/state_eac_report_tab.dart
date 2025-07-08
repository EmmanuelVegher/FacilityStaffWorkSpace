// lib/pages/reports/facility_eac_reports_page.dart

// FACILITY-LEVEL (MULTI-SELECT) EAC REPORTS PAGE
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart' show PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;

import '../../widgets/drawer2.dart';


// --- DATA MODELS ---
class EacCallLog {
  final String? clientName, phoneNumber, artStatus, facilityName, state, artId, datimCode;
  final DateTime? dateTracked;
  final String? trackingOutcome, trackedBy, designation, trackerFacilityLocation, supervisorName, supervisorEmail, eacSessionType;
  final int? callDuration;

  EacCallLog({
    this.clientName, this.phoneNumber, this.artStatus, this.facilityName, this.state,
    this.artId, this.datimCode, this.dateTracked, this.trackingOutcome, this.callDuration,
    this.trackedBy, this.designation, this.trackerFacilityLocation, this.supervisorName,
    this.supervisorEmail, this.eacSessionType,
  });

  factory EacCallLog.fromJson(Map<String, dynamic> data) {
    return EacCallLog(
      clientName: data['clientName'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      artStatus: data['artStatus'] as String?,
      facilityName: data['facilityName'] as String?,
      state: data['trackerState'] as String?,
      artId: data['artId'] as String?,
      datimCode: data['datimCode'] as String?,
      dateTracked: (data['dateTracked'] as Timestamp?)?.toDate(),
      trackingOutcome: data['trackingOutcome'] as String?,
      callDuration: data['callDuration'] as int?,
      trackedBy: data['trackedBy'] as String?,
      designation: data['designation'] as String?,
      trackerFacilityLocation: data['trackerFacilityLocation'] as String?,
      supervisorName: data['supervisorName'] as String?,
      supervisorEmail: data['supervisorEmail'] as String?,
      eacSessionType: data['eacSessionType'] as String?,
    );
  }
}

class EacSummary {
  final String reportId, facility, trackerName;
  final DateTime reportDate;
  final int totalUniqueClients;
  final EacSessionsSummary eacSessions;
  final TatSummary tat;
  final VlSummary vlSummary;

  EacSummary({
    required this.reportId, required this.facility, required this.reportDate,
    required this.totalUniqueClients, required this.trackerName, required this.eacSessions,
    required this.tat, required this.vlSummary,
  });

  factory EacSummary.fromJson(Map<String, dynamic> data) {
    DateTime parsedDate;
    try {
      if (data['reportDate'] is Timestamp) parsedDate = (data['reportDate'] as Timestamp).toDate();
      else if (data['reportDate'] is String) parsedDate = DateFormat('yyyy-MM-dd').parse(data['reportDate']);
      else parsedDate = (data['lastUpdated'] as Timestamp).toDate();
    } catch (e) { parsedDate = DateTime.now(); }

    return EacSummary(
      reportId: data['reportId'] as String? ?? 'N/A',
      facility: data['facility'] as String? ?? 'N/A',
      reportDate: parsedDate,
      totalUniqueClients: data['totalUniqueClients'] as int? ?? 0,
      trackerName: data['trackerName'] as String? ?? 'N/A',
      eacSessions: EacSessionsSummary.fromJson(data['eacSessions'] as Map<String, dynamic>? ?? {}),
      tat: TatSummary.fromJson(data['tat'] as Map<String, dynamic>? ?? {}),
      vlSummary: VlSummary.fromJson(data['vlSummary'] as Map<String, dynamic>? ?? {}),
    );
  }
}
class EacSessionsSummary {
  final int withAtLeast3Sessions, without3Sessions;
  EacSessionsSummary({required this.withAtLeast3Sessions, required this.without3Sessions});
  factory EacSessionsSummary.fromJson(Map<String, dynamic> data) => EacSessionsSummary(
      withAtLeast3Sessions: data['withAtLeast3Sessions'] as int? ?? 0,
      without3Sessions: data['without3Sessions'] as int? ?? 0);
}
class TatSummary {
  final int lessThan90Days, between90and150Days, moreThan150Days;
  TatSummary({required this.lessThan90Days, required this.between90and150Days, required this.moreThan150Days});
  factory TatSummary.fromJson(Map<String, dynamic> data) => TatSummary(
      lessThan90Days: data['lessThan90Days'] as int? ?? 0,
      between90and150Days: data['between90and150Days'] as int? ?? 0,
      moreThan150Days: data['moreThan150Days'] as int? ?? 0);
}
class VlSummary {
  final int suppressedLessThan50, suppressedLessThan1000, unsuppressed, withRepeatVl, switchReviewCount;
  VlSummary({required this.suppressedLessThan50, required this.suppressedLessThan1000, required this.unsuppressed, required this.withRepeatVl, required this.switchReviewCount});
  factory VlSummary.fromJson(Map<String, dynamic> data) => VlSummary(
      suppressedLessThan50: data['suppressedLessThan50'] as int? ?? 0,
      suppressedLessThan1000: data['suppressedLessThan1000'] as int? ?? 0,
      unsuppressed: data['unsuppressed'] as int? ?? 0,
      withRepeatVl: data['withRepeatVl'] as int? ?? 0,
      switchReviewCount: data['switchReviewCount'] as int? ?? 0);
}

// --- GlobalKeys for chart export ---
final GlobalKey _outcomeChartKey = GlobalKey();
final GlobalKey _artStatusChartKey = GlobalKey();
final GlobalKey _sessionTypeChartKey = GlobalKey();
final GlobalKey _callDurationChartKey = GlobalKey();

class StateEacReportsPageWeb extends StatefulWidget {
  const StateEacReportsPageWeb({super.key});
  @override
  _StateEacReportsPageWebState createState() => _StateEacReportsPageWebState();
}

class _StateEacReportsPageWebState extends State<StateEacReportsPageWeb> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Core Data & UI State ---
  List<EacCallLog> _masterLogList = [];
  List<EacCallLog> _filteredLogList = [];
  List<EacSummary> _eacSummaries = [];
  DateTime? startDate, endDate;
  bool isLoading = false, _isInitialState = true, _isFilterLoading = true, _isFacilitiesLoading = false;
  String? _errorMessage, _summaryErrorMessage;
  bool _isExporting = false;

  // --- UI State for Expandable Sections ---
  List<ScrollController> _logTableControllers = [];
  int _currentlyExpandedDateIndex = -1;
  bool _isClientSummaryExpanded = false, _isAnalysisExpanded = true;
  final ScrollController _clientSummaryScrollController = ScrollController();

  // --- Filter State ---
  String? _currentUserState; // Automatically determined state
  List<String> _availableFacilities = ['All Facilities'];
  List<String> _selectedFacilities = ['All Facilities'];

  // --- Call Costs & Chart Data ---
  double _totalCallCost = 0.0, _costPerSecond = 0.25;
  List<MapEntry<String, int>> outcomeChartData = [], artStatusChartData = [], sessionTypeChartData = [];
  List<_ChartDataPoint> callDurationTrendData = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month, now.day);
    _initializePage();
  }

  @override
  void dispose() {
    for (final controller in _logTableControllers) { controller.dispose(); }
    _clientSummaryScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    setState(() => _isFilterLoading = true);
    await _loadCurrentUserBio();
    if (_currentUserState != null) {
      await _loadFacilitiesForState(_currentUserState!);
    }
    if (mounted) setState(() => _isFilterLoading = false);
  }

  Future<void> _loadCurrentUserBio() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final docSnapshot = await _firestore.collection('Staff').doc(user.uid).get();

      if(docSnapshot.exists && mounted) {
        setState(() {
          _currentUserState = docSnapshot.data()?['state'] as String?;
        });
        if (_currentUserState == null) {
          throw Exception("State not found in your user profile.");
        }
      } else {
        throw Exception("Your user profile was not found in the 'Staff' collection.");
      }
    } catch (e, s) {
      debugPrint("Error loading user bio: $e\n$s");
      if(mounted) setState(() => _errorMessage = "Could not load user profile: $e");
    }
  }

  Future<void> _loadFacilitiesForState(String state) async {
    setState(() => _isFacilitiesLoading = true);
    try {
      final snapshot = await _firestore.collection('Location').doc(state).collection(state).get();
      final facilities = snapshot.docs.map((doc) => doc['LocationName'] as String).where((name) => name.isNotEmpty).toList()..sort();
      if (mounted) {
        setState(() => _availableFacilities.addAll(facilities));
      }
    } catch (e, s) {
      debugPrint("Error fetching facilities for $state: $e\n$s");
      if(mounted) _showSnackBar("Error fetching facility list for $state.");
    } finally {
      if (mounted) setState(() => _isFacilitiesLoading = false);
    }
  }

  Future<void> _loadReports() async {
    if (_currentUserState == null) {
      _showSnackBar("Cannot load reports: Your state is missing from your profile.");
      return;
    }
    setState(() {
      isLoading = true;
      _isInitialState = false;
      _errorMessage = _summaryErrorMessage = null;
      _masterLogList.clear();
      _filteredLogList.clear();
      _eacSummaries.clear();
    });

    try {
      await Future.wait([_fetchCallLogs(), _fetchEacSummaries()]);
      if (mounted) {
        _applyAllFiltersAndRecalculate();
        if (_masterLogList.isEmpty && _eacSummaries.isEmpty) {
          _showSnackBar("No EAC data found for the selected criteria.");
        }
      }
    } catch (e, s) {
      debugPrint("Error loading reports: $e\n$s");
      if (mounted) setState(() => _errorMessage = "An error occurred while loading reports: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchCallLogs() async {
    Query query = _firestore.collection('EacCallLogs')
        .where('trackerState', isEqualTo: _currentUserState)
        .where('dateTracked', isGreaterThanOrEqualTo: startDate)
        .where('dateTracked', isLessThanOrEqualTo: endDate!.add(const Duration(days: 1)));

    if (!_selectedFacilities.contains('All Facilities')) {
      if (_selectedFacilities.length > 30) {
        _showSnackBar("Log query limited to first 30 facilities due to system limits.");
        query = query.where('trackerFacilityLocation', whereIn: _selectedFacilities.take(30).toList());
      } else {
        query = query.where('trackerFacilityLocation', whereIn: _selectedFacilities);
      }
    }

    final querySnapshot = await query.orderBy('dateTracked', descending: true).get();
    if(mounted) {
      _masterLogList = querySnapshot.docs.map((doc) => EacCallLog.fromJson(doc.data() as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _fetchEacSummaries() async {
    List<String> facilitiesToQuery = [];
    if (_selectedFacilities.contains('All Facilities')) {
      facilitiesToQuery = _availableFacilities.where((f) => f != 'All Facilities').toList();
    } else {
      facilitiesToQuery = List.from(_selectedFacilities);
    }

    if (facilitiesToQuery.isEmpty) {
      if(mounted) setState(() => _eacSummaries = []);
      return;
    }

    List<Future<QuerySnapshot>> futures = [];
    for (String facility in facilitiesToQuery) {
      final locationPrefix = facility.replaceAll(' ', '_');
      futures.add(_firestore.collection('EacSummaries')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: locationPrefix)
          .where(FieldPath.documentId, isLessThan: '$locationPrefix\uf8ff')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get());
    }

    try {
      final List<QuerySnapshot> results = await Future.wait(futures);
      final List<EacSummary> summaries = [];
      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          if (doc.exists) {
            summaries.add(EacSummary.fromJson(doc.data() as Map<String, dynamic>));
          }
        }
      }
      if(mounted) setState(() => _eacSummaries = summaries);
    } catch (e, s) {
      debugPrint("Error fetching summaries: $e\n$s");
      if(mounted) setState(() => _summaryErrorMessage = "Failed to load EAC summaries.");
    }
  }

  void _applyAllFiltersAndRecalculate() {
    setState(() {
      _filteredLogList = _masterLogList;
      _totalCallCost = _filteredLogList.fold(0, (sum, c) => sum + (c.callDuration ?? 0)) * _costPerSecond;
      _prepareChartData();
      for (final controller in _logTableControllers) { controller.dispose(); }
      final dateGroups = _groupLogsByDate();
      _logTableControllers = List.generate(dateGroups.length, (_) => ScrollController());
      _currentlyExpandedDateIndex = _filteredLogList.isNotEmpty ? 0 : -1;
    });
  }

  void _prepareChartData() {
    outcomeChartData = _getOutcomeData();
    artStatusChartData = _getArtStatusData();
    sessionTypeChartData = _getSessionTypeData();
    callDurationTrendData = _getCallDurationTrendData();
  }

  // --- NEW: Helper function to color status cells ---
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

  // --- NEW: Helper widget to build the colored status cell ---
  Widget _buildStatusCell(String? status) {
    if (status == null || status.isEmpty) {
      return const Text('N/A');
    }
    final lowerStatus = status.toLowerCase();
    Color color = _getStatusColor(status);
    Widget? icon;
    if (lowerStatus.contains('answered')) {
      icon = Icon(Icons.call_received, color: color, size: 16);
    } else if (lowerStatus.contains('failed') || lowerStatus.contains('missed')) {
      icon = Icon(Icons.phone_missed, color: color, size: 16);
    } else if (lowerStatus.contains('busy')) {
      icon = Icon(Icons.phone_in_talk, color: color, size: 16);
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w500))),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

    String appBarTitle = 'Facility EAC Reports';
    if(_currentUserState != null) {
      appBarTitle = 'EAC Reports for $_currentUserState';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _buildAppBarActions(),
      ),
      drawer: drawer2(context),
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
          enabled: !isLoading && !_isInitialState && (_filteredLogList.isNotEmpty || _eacSummaries.isNotEmpty),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.grid_on_outlined, color: Colors.green), title: Text('Export CSV'))),
          ],
        ),
    ];
  }

  Widget _buildFilterBar() {
    if (_isFilterLoading) return const SizedBox.shrink(); // Don't show bar until user state is known

    String facilityButtonText = _selectedFacilities.contains('All Facilities') ? 'All Facilities' : _selectedFacilities.length == 1 ? _selectedFacilities.first : '${_selectedFacilities.length} Facilities';

    return Card(
      margin: const EdgeInsets.all(8.0), elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16.0, runSpacing: 12.0, alignment: WrapAlignment.start,
          children: [
            _buildFilterChip("Facility", facilityButtonText, Icons.business_center, () {
              _showMultiSelectDialog(
                context: context, title: 'Select Facilities', allOptions: _availableFacilities,
                selectedOptions: _selectedFacilities, allKeyword: 'All Facilities',
                onConfirm: (results) => setState(() => _selectedFacilities = results),
              );
            }, disabled: _isFacilitiesLoading),

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
      return Center(child: Text("Select facilities and apply filters to view EAC reports.", style: TextStyle(color: Colors.grey.shade700)));
    }
    if (_filteredLogList.isEmpty && _eacSummaries.isEmpty && !isLoading) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("No EAC data found for the selected criteria.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700))));
    }

    final Map<String, List<EacCallLog>> dailyGroupedReports = _groupLogsByDate();
    final Map<String, _ClientCallSummary> clientSummaryMap = _generateClientCallSummary();
    final dailyGroupedKeys = dailyGroupedReports.keys.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryInfoCard(),
          const SizedBox(height: 24),
          if (_eacSummaries.isNotEmpty || _summaryErrorMessage != null) ...[
            _buildEacAnalysisSection(),
            const SizedBox(height: 24),
          ],
          if(_filteredLogList.isNotEmpty)...[
            Text('Call Log Summary Charts', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _buildChartSection(),
            const SizedBox(height: 30),
            if (clientSummaryMap.isNotEmpty) ...[
              _buildClientSummarySection(clientSummaryMap),
              const SizedBox(height: 30),
            ],
            Text('Detailed EAC Logs', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            _buildDetailedLogSection(dailyGroupedKeys, dailyGroupedReports),
          ]
        ],
      ),
    );
  }

  Widget _buildEacAnalysisSection() {
    if (_summaryErrorMessage != null) {
      return Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text("Analysis Error: $_summaryErrorMessage", style: TextStyle(color: Colors.red.shade800)))])));
    }
    if (_eacSummaries.isEmpty) return const SizedBox.shrink();

    final EacSessionsSummary totalSessions = _eacSummaries.fold(EacSessionsSummary(withAtLeast3Sessions: 0, without3Sessions: 0), (p, s) => EacSessionsSummary(withAtLeast3Sessions: p.withAtLeast3Sessions + s.eacSessions.withAtLeast3Sessions, without3Sessions: p.without3Sessions + s.eacSessions.without3Sessions));
    final int totalClients = _eacSummaries.fold(0, (p, s) => p + s.totalUniqueClients);
    final TatSummary totalTat = _eacSummaries.fold(TatSummary(lessThan90Days: 0, between90and150Days: 0, moreThan150Days: 0), (p, s) => TatSummary(lessThan90Days: p.lessThan90Days + s.tat.lessThan90Days, between90and150Days: p.between90and150Days + s.tat.between90and150Days, moreThan150Days: p.moreThan150Days + s.tat.moreThan150Days));
    final VlSummary totalVl = _eacSummaries.fold(VlSummary(suppressedLessThan50: 0, suppressedLessThan1000: 0, unsuppressed: 0, withRepeatVl: 0, switchReviewCount: 0), (p, s) => VlSummary(suppressedLessThan50: p.suppressedLessThan50 + s.vlSummary.suppressedLessThan50, suppressedLessThan1000: p.suppressedLessThan1000 + s.vlSummary.suppressedLessThan1000, unsuppressed: p.unsuppressed + s.vlSummary.unsuppressed, withRepeatVl: p.withRepeatVl + s.vlSummary.withRepeatVl, switchReviewCount: p.switchReviewCount + s.vlSummary.switchReviewCount));

    String subtitle = 'For ${_selectedFacilities.contains("All Facilities") ? "All Facilities" : "${_selectedFacilities.length} Facilitie(s)"} in $_currentUserState';

    return Card(
      clipBehavior: Clip.antiAlias, elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: _isAnalysisExpanded,
        onExpansionChanged: (isExpanded) => setState(() => _isAnalysisExpanded = isExpanded),
        backgroundColor: Colors.blueGrey.shade50.withOpacity(0.5),
        title: Text('Aggregated Programmatic EAC Analysis', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.blueGrey.shade600)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 40.0, runSpacing: 24.0,
              children: [
                _buildAnalysisCategory(title: 'EAC Session Adherence', icon: Icons.checklist_rtl_outlined, iconColor: Colors.teal, metrics: {'Total Unique Clients on EAC': totalClients.toString(), 'Completed 3+ Sessions': totalSessions.withAtLeast3Sessions.toString(), 'Incomplete (< 3 Sessions)': totalSessions.without3Sessions.toString()}),
                _buildAnalysisCategory(title: 'Viral Load (VL) Summary', icon: Icons.science_outlined, iconColor: Colors.deepPurple, metrics: {'Suppressed (< 50 c/ml)': totalVl.suppressedLessThan50.toString(), 'Suppressed (< 1000 c/ml)': totalVl.suppressedLessThan1000.toString(), 'Unsuppressed (≥ 1000 c/ml)': totalVl.unsuppressed.toString(), 'Clients with Repeat VL': totalVl.withRepeatVl.toString(), 'Clients for Switch Review': totalVl.switchReviewCount.toString()}),
                _buildAnalysisCategory(title: 'Turn-Around Time (TAT) for VL', icon: Icons.hourglass_top_outlined, iconColor: Colors.amber.shade800, metrics: {'Less than 90 Days': totalTat.lessThan90Days.toString(), '90 - 150 Days': totalTat.between90and150Days.toString(), 'More than 150 Days': totalTat.moreThan150Days.toString()}),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAnalysisCategory({required String title, required IconData icon, required Color iconColor, required Map<String, String> metrics}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 300, maxWidth: 450),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: iconColor), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))]),
          const Divider(height: 12),
          ...metrics.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(entry.key, style: Theme.of(context).textTheme.bodyMedium),
              Text(entry.value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
            ],),
          )),
        ],
      ),
    );
  }

  Widget _buildSummaryInfoCard() {
    final numberFormatter = NumberFormat.compact();
    final currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final totalDuration = _filteredLogList.fold<int>(0, (sum, item) => sum + (item.callDuration ?? 0));
    final uniqueClients = _filteredLogList.map((log) => log.artId).toSet().length;

    final int facilityCount;
    if (_selectedFacilities.contains('All Facilities')) {
      facilityCount = _availableFacilities.length > 1 ? _availableFacilities.length - 1 : 0;
    } else {
      facilityCount = _selectedFacilities.length;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 0), elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          alignment: WrapAlignment.spaceAround, spacing: 20.0, runSpacing: 16.0,
          children: [
            _buildInfoTile(iconWidget: Icon(Icons.location_city, color: Colors.blueGrey, size: 36), label: 'Selected Facilities', value: facilityCount.toString()),
            _buildInfoTile(iconWidget: Icon(Icons.group, color: Colors.teal.shade700, size: 36), label: 'Unique Clients in Logs', value: numberFormatter.format(uniqueClients)),
            _buildInfoTile(iconWidget: Icon(Icons.call, color: Colors.blue.shade700, size: 36), label: 'Total EAC Calls Logged', value: numberFormatter.format(_filteredLogList.length)),
            _buildInfoTile(iconWidget: Icon(Icons.timer_outlined, color: Colors.purple.shade700, size: 36), label: 'Total Call Duration', value: formatDuration(totalDuration)),
            _buildInfoTile(iconWidget: Text('₦', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange.shade800)), label: 'Estimated Call Cost', value: currencyFormatter.format(_totalCallCost), subtitle: '(at ₦${_costPerSecond.toStringAsFixed(2)}/sec)')
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Wrap(
      spacing: 20.0, runSpacing: 20.0, alignment: WrapAlignment.start,
      children: [
        _buildChartCard(title: 'Call Outcome Distribution', chartKey: _outcomeChartKey, chart: SfCircularChart(annotations: (outcomeChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null, legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap), series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: outcomeChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])),
        _buildChartCard(title: 'EAC Session Distribution', chartKey: _sessionTypeChartKey, chart: SfCircularChart(annotations: (sessionTypeChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null, legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap), series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: sessionTypeChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])),
        _buildChartCard(title: 'ART Status Distribution', chartKey: _artStatusChartKey, chart: SfCircularChart(annotations: (artStatusChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null, legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap), series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: artStatusChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])),
        _buildChartCard(isWide: true, title: 'Average Call Duration Trend (Daily)', chartKey: _callDurationChartKey, chart: SfCartesianChart(annotations: (callDurationTrendData.isEmpty) ? [const CartesianChartAnnotation(widget: Text("No data"), coordinateUnit: CoordinateUnit.point, region: AnnotationRegion.chart, x: '50%', y: '50%')] : null, primaryXAxis: const CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Date Tracked')), primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Avg. Duration (s)'), numberFormat: NumberFormat.compact()), tooltipBehavior: TooltipBehavior(enable: true), series: <CartesianSeries>[LineSeries<_ChartDataPoint, String>(dataSource: callDurationTrendData, xValueMapper: (data, _) => DateFormat('MMM d').format(DateFormat('yyyy-MM-dd').parse(data.x)), yValueMapper: (data, _) => data.y, name: 'Avg Duration', markerSettings: const MarkerSettings(isVisible: true))])),
      ],
    );
  }

  Widget _buildDetailedLogSection(List<String> dailyGroupedKeys, Map<String, List<EacCallLog>> dailyGroupedReports) {
    if (dailyGroupedKeys.isEmpty) { return const Card(child: SizedBox(height: 100, child: Center(child: Text("No detailed logs match the current filters.")))); }
    return ExpansionPanelList(
      expansionCallback: (int index, bool isExpanded) => setState(() => _currentlyExpandedDateIndex = _currentlyExpandedDateIndex == index ? -1 : index),
      animationDuration: const Duration(milliseconds: 300),
      children: dailyGroupedKeys.map<ExpansionPanel>((String dateKey) {
        final index = dailyGroupedKeys.indexOf(dateKey);
        final dailyLogList = dailyGroupedReports[dateKey]!;
        final bool isExpanded = _currentlyExpandedDateIndex == index;
        return ExpansionPanel(
          isExpanded: isExpanded, canTapOnHeader: true,
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text(dateKey, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Visibility(
                visible: isExpanded,
                maintainSize: true, maintainAnimation: true, maintainState: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Scroll Left',
                      onPressed: () {
                        if (_logTableControllers.length > index) {
                          _logTableControllers[index].animateTo(_logTableControllers[index].offset - 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: 'Scroll Right',
                      onPressed: () {
                        if (_logTableControllers.length > index) {
                          _logTableControllers[index].animateTo(_logTableControllers[index].offset + 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          body: SingleChildScrollView(
            controller: _logTableControllers[index], scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DataTable(
                columns: const [DataColumn(label: Text('Outcome')), DataColumn(label: Text('Client Name')), DataColumn(label: Text('PhoneNo')), DataColumn(label: Text('ART Status')), DataColumn(label: Text("Facility")), DataColumn(label: Text('State')), DataColumn(label: Text('ART ID')), DataColumn(label: Text('DatimCode')), DataColumn(label: Text('Time')), DataColumn(label: Text('EAC Session')), DataColumn(label: Text('Duration')), DataColumn(label: Text('Tracked By'))],
                rows: dailyLogList.map((log) => DataRow(cells: [
                  DataCell(_buildStatusCell(log.trackingOutcome)),
                  DataCell(Text(log.clientName ?? 'N/A')), DataCell(Text(log.phoneNumber ?? 'N/A')), DataCell(Text(log.artStatus ?? 'N/A')), DataCell(Text(log.facilityName ?? 'N/A')), DataCell(Text(log.state ?? 'N/A')), DataCell(Text(log.artId ?? 'N/A')), DataCell(Text(log.datimCode ?? 'N/A')), DataCell(Text(log.dateTracked != null ? DateFormat('HH:mm').format(log.dateTracked!) : 'N/A')), DataCell(Text(log.eacSessionType ?? 'N/A')), DataCell(Text(formatDuration(log.callDuration ?? 0))), DataCell(Text(log.trackedBy ?? 'N/A')),
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
      List<List<dynamic>> rows = [['Client Name', 'PhoneNo', 'ART Status', 'Facility', 'State', 'ART ID', 'DatimCode', 'Date Tracked', 'EAC Session', 'Outcome', 'Duration(s)', 'Tracked By']];
      for (var log in _filteredLogList) {
        rows.add([log.clientName, log.phoneNumber, log.artStatus, log.facilityName, log.state, log.artId, log.datimCode, log.dateTracked, log.eacSessionType, log.trackingOutcome, log.callDuration, log.trackedBy]);
      }
      String csvData = const ListToCsvConverter().convert(rows);
      _triggerDownload(utf8.encode(csvData), 'facility_eac_report.csv', 'text/csv');
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

  List<MapEntry<String, int>> _getOutcomeData() { Map<String, int> statusCounts = {}; for (var log in _filteredLogList) { String status = log.trackingOutcome?.trim() ?? 'N/A'; if (status.isEmpty) status = 'N/A'; statusCounts[status] = (statusCounts[status] ?? 0) + 1; } return statusCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)); }
  List<MapEntry<String, int>> _getSessionTypeData() { Map<String, int> sessionCounts = {}; for (var log in _filteredLogList) { String session = log.eacSessionType?.trim() ?? 'Unknown'; if (session.isEmpty) session = 'Unknown'; sessionCounts[session] = (sessionCounts[session] ?? 0) + 1; } return sessionCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)); }
  List<MapEntry<String, int>> _getArtStatusData() { Map<String, int> statusCounts = {}; for (var log in _filteredLogList) { String status = log.artStatus?.trim() ?? 'Unknown'; if (status.isEmpty) status = 'Unknown'; statusCounts[status] = (statusCounts[status] ?? 0) + 1; } return statusCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)); }
  List<_ChartDataPoint> _getCallDurationTrendData() { Map<String, List<int>> dailyDurations = {}; final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd'); for (var log in _filteredLogList) { if (log.dateTracked != null && log.callDuration != null && log.callDuration! > 0) { String dateKey = dateKeyFormat.format(log.dateTracked!); dailyDurations.putIfAbsent(dateKey, () => []).add(log.callDuration!); } } List<_ChartDataPoint> chartData = []; dailyDurations.forEach((date, durations) { double averageDuration = durations.reduce((a, b) => a + b) / durations.length; chartData.add(_ChartDataPoint(date, averageDuration)); }); chartData.sort((a, b) => a.x.compareTo(b.x)); return chartData; }
  String formatDuration(int totalSeconds) { if (totalSeconds <= 0) return '0s'; final int hours = totalSeconds ~/ 3600; final int minutes = (totalSeconds % 3600) ~/ 60; final int seconds = totalSeconds % 60; List<String> parts = []; if (hours > 0) parts.add('${hours}h'); if (minutes > 0) parts.add('${minutes}m'); if (seconds > 0 || parts.isEmpty) parts.add('${seconds}s'); return parts.join(' '); }
  Map<String, List<EacCallLog>> _groupLogsByDate() { final Map<String, List<EacCallLog>> dailyReports = {}; final DateFormat displayFormat = DateFormat('EEEE, MMMM d, yyyy'); for (var log in _filteredLogList) { final dateKey = log.dateTracked != null ? displayFormat.format(log.dateTracked!) : 'Unknown Date'; dailyReports.putIfAbsent(dateKey, () => []).add(log); } return dailyReports; }
  Map<String, _ClientCallSummary> _generateClientCallSummary() { final Map<String, _ClientCallSummary> summaryMap = {}; for (var log in _filteredLogList) { final clientId = log.artId ?? 'Unknown ID'; final clientName = log.clientName ?? 'Unknown Name'; if (!summaryMap.containsKey(clientId)) { summaryMap[clientId] = _ClientCallSummary(clientId: clientId, clientName: clientName); } summaryMap[clientId]!.totalCalls += 1; final status = log.trackingOutcome?.toLowerCase() ?? 'unknown'; summaryMap[clientId]!.statusCounts[status] = (summaryMap[clientId]!.statusCounts[status] ?? 0) + 1; } return summaryMap; }

  Widget _buildFilterChip(String label, String value, IconData icon, VoidCallback onPressed, {bool disabled = false}) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), InputChip(avatar: _isFacilitiesLoading && label=="Facility" ? const SizedBox(height:18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 18), label: Text(value, overflow: TextOverflow.ellipsis), onPressed: disabled ? null : onPressed, showCheckmark: false, side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.7)), backgroundColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),)]);}
  Widget _buildInfoTile({required Widget iconWidget, required String label, required String value, String? subtitle}) { return Row(mainAxisSize: MainAxisSize.min, children: [ iconWidget, const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), if (subtitle != null && subtitle.isNotEmpty) ...[const SizedBox(height: 2), Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600))], ],), ],); }
  Widget _buildChartCard({required String title, required Widget chart, GlobalKey? chartKey, bool isWide = false}) { return ConstrainedBox(constraints: BoxConstraints(maxWidth: isWide ? 600 : 400, minWidth: 350), child: Card(elevation: 2.0, child: Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 10), SizedBox(height: 250, child: RepaintBoundary(key: chartKey, child: Container(color: Colors.white, child: chart)))],),),),); }

  Widget _buildClientSummarySection(Map<String, _ClientCallSummary> clientSummaryMap) { return Card(clipBehavior: Clip.antiAlias, elevation: 2, margin: const EdgeInsets.symmetric(vertical: 8.0), child: ExpansionTile(title: Row(children: [Expanded(child: Text('Summary of Calls per Client', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))), Visibility(visible: _isClientSummaryExpanded, maintainSize: true, maintainAnimation: true, maintainState: true, child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Scroll Left', onPressed: () => _clientSummaryScrollController.animateTo(_clientSummaryScrollController.offset - 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)), IconButton(icon: const Icon(Icons.arrow_forward), tooltip: 'Scroll Right', onPressed: () => _clientSummaryScrollController.animateTo(_clientSummaryScrollController.offset + 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut))]))]), initiallyExpanded: _isClientSummaryExpanded, onExpansionChanged: (isExpanded) => setState(() => _isClientSummaryExpanded = isExpanded), children: [SingleChildScrollView(controller: _clientSummaryScrollController, scrollDirection: Axis.horizontal, child: Padding(padding: const EdgeInsets.all(8.0), child: DataTable(columnSpacing: 15.0, headingRowColor: MaterialStateProperty.all(Colors.grey.shade200), columns: const [DataColumn(label: Text('Client ART ID')), DataColumn(label: Text('Client Name')), DataColumn(label: Text('Total Calls')), DataColumn(label: Text('Call Outcome Summary'))], rows: clientSummaryMap.values.map((summary) { final statusSummary = summary.statusCounts.entries.map((e) => '${e.key}: ${e.value}').join(', '); return DataRow(cells: [DataCell(Text(summary.clientId)), DataCell(Text(summary.clientName)), DataCell(Text(summary.totalCalls.toString())), DataCell(Text(statusSummary))]); }).toList())))])); }

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

// --- Helper classes ---
class _ChartDataPoint {
  final String x;
  final double y;
  _ChartDataPoint(this.x, this.y);
}

class _ClientCallSummary {
  final String clientId, clientName;
  int totalCalls = 0;
  Map<String, int> statusCounts = {};
  _ClientCallSummary({required this.clientId, required this.clientName});
}