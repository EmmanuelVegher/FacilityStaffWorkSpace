// lib/pages/reports/eac_reports_page_web.dart

// FACILITY-LEVEL EAC & CALLS TRACKER REPORTS PAGE - REWRITTEN FOR FLATTENED DATA
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

import '../../widgets/drawer.dart'; // Assuming you have a drawer widget

// --- DATA MODEL TO MATCH THE FLATTENED 'EACTrackedLogs' COLLECTION ---
class EacCallLog {
  final String? clientName;
  final String? phoneNumber;
  final String? artStatus;
  final String? facilityName;
  final String? state;
  final String? artId; // This is the uniqueID from the mobile app
  final String? datimCode;
  final DateTime? dateTracked;
  final String? trackingOutcome; // Replaces callStatus
  final int? callDuration;
  final String? trackedBy;
  final String? designation;
  final String? trackerFacilityLocation;
  final String? supervisorName;
  final String? supervisorEmail;
  final String? eacSessionType; // Crucial field for EAC reporting

  EacCallLog({
    this.clientName,
    this.phoneNumber,
    this.artStatus,
    this.facilityName,
    this.state,
    this.artId,
    this.datimCode,
    this.dateTracked,
    this.trackingOutcome,
    this.callDuration,
    this.trackedBy,
    this.designation,
    this.trackerFacilityLocation,
    this.supervisorName,
    this.supervisorEmail,
    this.eacSessionType,
  });

  factory EacCallLog.fromJson(Map<String, dynamic> data) {
    return EacCallLog(
      clientName: data['clientName'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      artStatus: data['artStatus'] as String?,
      facilityName: data['facilityName'] as String?,
      state: data['trackerState'] as String?, // Note: Field name from mobile app
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

// --- NEW: DATA MODELS FOR EacSummaries COLLECTION ---
class EacSessionsSummary {
  final int withAtLeast3Sessions;
  final int without3Sessions;
  EacSessionsSummary({required this.withAtLeast3Sessions, required this.without3Sessions});
  factory EacSessionsSummary.fromJson(Map<String, dynamic> data) {
    return EacSessionsSummary(
      withAtLeast3Sessions: data['withAtLeast3Sessions'] as int? ?? 0,
      without3Sessions: data['without3Sessions'] as int? ?? 0,
    );
  }
}

class TatSummary {
  final int lessThan90Days;
  final int between90and150Days;
  final int moreThan150Days;
  TatSummary({required this.lessThan90Days, required this.between90and150Days, required this.moreThan150Days});
  factory TatSummary.fromJson(Map<String, dynamic> data) {
    return TatSummary(
      lessThan90Days: data['lessThan90Days'] as int? ?? 0,
      between90and150Days: data['between90and150Days'] as int? ?? 0,
      moreThan150Days: data['moreThan150Days'] as int? ?? 0,
    );
  }
}

class VlSummary {
  final int suppressedLessThan50;
  final int suppressedLessThan1000;
  final int unsuppressed;
  final int withRepeatVl;
  final int switchReviewCount;
  VlSummary({
    required this.suppressedLessThan50,
    required this.suppressedLessThan1000,
    required this.unsuppressed,
    required this.withRepeatVl,
    required this.switchReviewCount,
  });
  factory VlSummary.fromJson(Map<String, dynamic> data) {
    return VlSummary(
      suppressedLessThan50: data['suppressedLessThan50'] as int? ?? 0,
      suppressedLessThan1000: data['suppressedLessThan1000'] as int? ?? 0,
      unsuppressed: data['unsuppressed'] as int? ?? 0,
      withRepeatVl: data['withRepeatVl'] as int? ?? 0,
      switchReviewCount: data['switchReviewCount'] as int? ?? 0,
    );
  }
}

class EacSummary {
  final String reportId;
  final String facility;
  final DateTime reportDate;
  final int totalUniqueClients;
  final String trackerName;
  final EacSessionsSummary eacSessions;
  final TatSummary tat;
  final VlSummary vlSummary;

  EacSummary({
    required this.reportId,
    required this.facility,
    required this.reportDate,
    required this.totalUniqueClients,
    required this.trackerName,
    required this.eacSessions,
    required this.tat,
    required this.vlSummary,
  });

  factory EacSummary.fromJson(Map<String, dynamic> data) {
    DateTime parsedDate;
    try {
      // Handles both Timestamp and String date formats
      if (data['reportDate'] is Timestamp) {
        parsedDate = (data['reportDate'] as Timestamp).toDate();
      } else if (data['reportDate'] is String) {
        parsedDate = DateFormat('yyyy-MM-dd').parse(data['reportDate']);
      } else {
        parsedDate = DateTime.now(); // Fallback
      }
    } catch (e) {
      parsedDate = DateTime.now(); // Fallback on parsing error
    }

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
// --- END NEW DATA MODELS ---

// GlobalKeys to capture chart images for PDF export
final GlobalKey _outcomeChartKey = GlobalKey();
final GlobalKey _artStatusChartKey = GlobalKey();
final GlobalKey _sessionTypeChartKey = GlobalKey(); // New chart key
final GlobalKey _callDurationChartKey = GlobalKey();


class EacReportsPageWeb extends StatefulWidget {
  const EacReportsPageWeb({super.key});

  @override
  _EacReportsPageWebState createState() => _EacReportsPageWebState();
}

class _EacReportsPageWebState extends State<EacReportsPageWeb> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Core Data & UI State ---
  List<EacCallLog> _masterLogList = [];
  List<EacCallLog> _filteredLogList = [];
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = true;
  bool _isInitialState = true;
  String? _errorMessage;

  // --- NEW: State for EAC Summary Analysis ---
  List<EacSummary> _eacSummaries = [];
  String? _summaryErrorMessage;
  bool _isAnalysisExpanded = true;
  // --- END NEW ---

  // --- State variables for masking and exporting ---
  bool _allCellsGloballyUnlocked = false;
  bool _isExporting = false;

  // --- UI State for Expandable Sections ---
  List<ScrollController> _logTableControllers = [];
  int _currentlyExpandedDateIndex = -1;
  bool _isClientSummaryExpanded = false;
  final ScrollController _clientSummaryScrollController = ScrollController();

  // User Bio Details
  String? currentUserAuthId;
  String? userFirstName;
  String? userLastName;
  String? userLocation;

  // --- Filter State ---
  List<String> _availableOutcomes = ['All Outcomes'];
  List<String> _selectedOutcomes = ['All Outcomes'];
  List<String> _availableSessionTypes = ['All Sessions'];
  List<String> _selectedSessionTypes = ['All Sessions'];

  // --- Segregated Call Costs ---
  double _totalCallCost = 0.0;
  double _outgoingAnsweredCost = 0.0;
  double _incomingAnsweredCost = 0.0;
  final double _costPerSecond = 0.25;

  // Chart Data Holders
  List<MapEntry<String, int>> outcomeChartData = [];
  List<MapEntry<String, int>> artStatusChartData = [];
  List<MapEntry<String, int>> sessionTypeChartData = []; // New chart data
  List<_ChartDataPoint> callDurationTrendData = [];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    for (final controller in _logTableControllers) {
      controller.dispose();
    }
    _clientSummaryScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await _loadCurrentUserBio();
    if (_errorMessage == null) {
      final now = DateTime.now();
      startDate = DateTime(now.year, now.month, now.day - 29); // Default to last 30 days
      endDate = DateTime(now.year, now.month, now.day);
      await _loadReports();
    }
  }

  Future<void> _loadCurrentUserBio() async {
    setState(() => isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      currentUserAuthId = user.uid;

      final docSnapshot = await _firestore.collection('Staff').doc(currentUserAuthId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if(mounted) {
          setState(() {
            userFirstName = data['firstName'] as String?;
            userLastName = data['lastName'] as String?;
            userLocation = data['location'] as String?;
          });
        }
      } else {
        throw Exception("User bio data not found in Firestore 'Staff' collection.");
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error loading user details: $e");
    } finally {
      if(mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadReports() async {
    if (userLocation == null) {
      _showSnackBar("Cannot load reports: User facility location is missing.");
      return;
    }
    if (startDate == null || endDate == null) {
      _showSnackBar("Please select a date range.");
      return;
    }

    setState(() {
      isLoading = true;
      _isInitialState = false;
      _errorMessage = null;
      _masterLogList.clear();
      _filteredLogList.clear();
    });

    try {
      // --- MODIFIED: Load both reports and summaries in parallel ---
      await Future.wait([
        _fetchCallLogs(),
        _loadEacSummaries(),
      ]);
      // --- END MODIFIED ---

      if (mounted) {
        setState(() {
          _updateAvailableFiltersFromData();
          _applyAllFiltersAndRecalculate();
        });
        if (_masterLogList.isEmpty) {
          _showSnackBar("No EAC call logs found for the selected period.");
        }
      }
    } catch (e) {
      print("Error loading reports: $e");
      if (mounted) setState(() => _errorMessage = "Error loading reports: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- MODIFIED: Extracted log fetching to its own method ---
  Future<void> _fetchCallLogs() async {
    final QuerySnapshot querySnapshot = await _firestore
        .collection('EacCallLogs')
        .where('trackerFacilityLocation', isEqualTo: userLocation)
        .where('dateTracked', isGreaterThanOrEqualTo: startDate)
        .where('dateTracked', isLessThanOrEqualTo: endDate!.add(const Duration(days: 1)))
        .orderBy('dateTracked', descending: true)
        .get();

    final List<EacCallLog> fetchedLogs = querySnapshot.docs.map((doc) {
      return EacCallLog.fromJson(doc.data() as Map<String, dynamic>);
    }).toList();

    if (mounted) {
      _masterLogList = fetchedLogs;
    }
  }

  // --- NEW: Load data from the EacSummaries collection ---
  Future<void> _loadEacSummaries() async {
    if (userLocation == null || userLocation!.isEmpty) {
      return; // No location to filter by
    }

    setState(() {
      _summaryErrorMessage = null;
    });

    try {
      // Format location for query: "Facility Name" -> "Facility_Name"
      final locationPrefix = userLocation!.replaceAll(' ', '_');

      // Query for documents where the ID starts with the location prefix
      final querySnapshot = await _firestore
          .collection('EacSummaries')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: locationPrefix)
          .where(FieldPath.documentId, isLessThan: '$locationPrefix\uf8ff')
          .orderBy(FieldPath.documentId, descending: true) // Get the latest summary first
          .limit(5) // Get the last 5 summaries for this facility
          .get();

      final List<EacSummary> fetchedSummaries = querySnapshot.docs.map((doc) {
        return EacSummary.fromJson(doc.data());
      }).toList();

      if (mounted) {
        setState(() {
          _eacSummaries = fetchedSummaries;
        });
      }
    } catch (e) {
      print("Error loading EAC Summaries: $e");
      if (mounted) {
        setState(() => _summaryErrorMessage = "Could not load EAC analysis summary: $e");
      }
    }
  }

  // --- END NEW ---

  void _updateAvailableFiltersFromData() {
    final outcomes = _masterLogList.map((c) => c.trackingOutcome).whereType<String>().where((s) => s.isNotEmpty).toSet();
    _availableOutcomes = ['All Outcomes', ...outcomes.toList()..sort()];
    _selectedOutcomes = ['All Outcomes'];

    final sessionTypes = _masterLogList.map((c) => c.eacSessionType).whereType<String>().where((s) => s.isNotEmpty).toSet();
    _availableSessionTypes = ['All Sessions', ...sessionTypes.toList()..sort()];
    _selectedSessionTypes = ['All Sessions'];
  }

  void _applyAllFiltersAndRecalculate() {
    List<EacCallLog> currentlyFiltered = List.from(_masterLogList);

    if (!_selectedOutcomes.contains('All Outcomes')) {
      currentlyFiltered = currentlyFiltered.where((c) => _selectedOutcomes.contains(c.trackingOutcome)).toList();
    }

    if (!_selectedSessionTypes.contains('All Sessions')) {
      currentlyFiltered = currentlyFiltered.where((c) => _selectedSessionTypes.contains(c.eacSessionType)).toList();
    }

    int totalDuration = currentlyFiltered.fold(0, (sum, c) => sum + (c.callDuration ?? 0));
    int outgoingDuration = currentlyFiltered.where((c) => c.trackingOutcome?.toLowerCase() == 'answered').fold(0, (sum, c) => sum + (c.callDuration ?? 0));
    int incomingDuration = currentlyFiltered.where((c) => c.trackingOutcome?.toLowerCase() == 'incoming answered').fold(0, (sum, c) => sum + (c.callDuration ?? 0));

    setState(() {
      _filteredLogList = currentlyFiltered;
      _totalCallCost = totalDuration * _costPerSecond;
      _outgoingAnsweredCost = outgoingDuration * _costPerSecond;
      _incomingAnsweredCost = incomingDuration * _costPerSecond;

      _prepareChartData();

      for (final controller in _logTableControllers) {
        controller.dispose();
      }
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

  // --- UI BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      bodyContent = Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,),
      ));
    } else {
      bodyContent = _buildDashboardContent();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('EAC Reports for ${userLocation ?? "Your Facility"}', style: const TextStyle(color: Colors.white)),
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
      IconButton(
        tooltip: _allCellsGloballyUnlocked ? 'Mask Sensitive Data' : 'Unmask Sensitive Data',
        icon: Icon(_allCellsGloballyUnlocked ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: (isLoading) ? null : _toggleGlobalUnmask,
      ),
      if (_isExporting)
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
        )
      else
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: "Export Options",
          onSelected: (value) async {
            if (value == 'csv') {
              await _exportToCSV();
            } else if (value == 'pdf') await _exportToPDF();
          },
          enabled: !isLoading && !_isInitialState && _filteredLogList.isNotEmpty,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.grid_on_outlined, color: Colors.green), title: Text('Export CSV'))),
            const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined, color: Colors.red), title: Text('Export PDF (Charts)'))),
          ],
        ),
    ];
  }

  Widget _buildFilterBar() {
    String outcomeButtonText = _selectedOutcomes.contains('All Outcomes')
        ? 'All Outcomes'
        : _selectedOutcomes.length == 1
        ? _selectedOutcomes.first
        : '${_selectedOutcomes.length} Outcomes';

    String sessionButtonText = _selectedSessionTypes.contains('All Sessions')
        ? 'All Sessions'
        : _selectedSessionTypes.length == 1
        ? _selectedSessionTypes.first
        : '${_selectedSessionTypes.length} Sessions';

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16.0,
          runSpacing: 12.0,
          alignment: WrapAlignment.start,
          children: [
            _buildFilterChip("EAC Session Type", sessionButtonText, Icons.repeat_one, () {
              _showMultiSelectDialog(
                context: context,
                title: 'Select EAC Session Types',
                allOptions: _availableSessionTypes,
                selectedOptions: _selectedSessionTypes,
                allKeyword: 'All Sessions',
                onConfirm: (results) {
                  setState(() => _selectedSessionTypes = results);
                  _applyAllFiltersAndRecalculate();
                },
              );
            }, disabled: _availableSessionTypes.length <= 1 || isLoading),

            _buildFilterChip("Call Outcome", outcomeButtonText, Icons.phone_callback, () {
              _showMultiSelectDialog(
                context: context,
                title: 'Select Call Outcomes',
                allOptions: _availableOutcomes,
                selectedOptions: _selectedOutcomes,
                allKeyword: 'All Outcomes',
                onConfirm: (results) {
                  setState(() => _selectedOutcomes = results);
                  _applyAllFiltersAndRecalculate();
                },
              );
            }, disabled: _availableOutcomes.length <= 1 || isLoading),

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
      return Center(child: Text("Apply a filter to view EAC reports.", style: TextStyle(color: Colors.grey.shade700)));
    }
    if (_filteredLogList.isEmpty && _eacSummaries.isEmpty && !isLoading) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("No EAC data found for the selected criteria.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
      ));
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
          // --- NEW: Analysis Section ---
          if (_eacSummaries.isNotEmpty || _summaryErrorMessage != null) ...[
            _buildEacAnalysisSection(),
            const SizedBox(height: 24),
          ],
          // --- END NEW ---
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
        ],
      ),
    );
  }

  // --- NEW: EAC Analysis Summary Widget ---
  Widget _buildEacAnalysisSection() {
    if (_summaryErrorMessage != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Could not load analysis summary: $_summaryErrorMessage", style: TextStyle(color: Colors.red.shade800)),
        ),
      );
    }
    if (_eacSummaries.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no summaries are loaded
    }

    final latestSummary = _eacSummaries.first; // We sorted by date, so the first is the latest

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: ExpansionTile(
        key: const ValueKey('eac-analysis-tile'), // Add key to maintain state
        initiallyExpanded: _isAnalysisExpanded,
        onExpansionChanged: (isExpanded) => setState(() => _isAnalysisExpanded = isExpanded),
        backgroundColor: Colors.blueGrey.shade50.withOpacity(0.5),
        collapsedBackgroundColor: Colors.blueGrey.shade50.withOpacity(0.5),
        title: Text(
          'Latest Programmatic EAC Analysis',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800),
        ),
        subtitle: Text(
          'Summary from ${DateFormat.yMMMMd().format(latestSummary.reportDate)} by ${latestSummary.trackerName}',
          style: TextStyle(color: Colors.blueGrey.shade600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 40.0,
              runSpacing: 24.0,
              children: [
                _buildAnalysisCategory(
                  title: 'EAC Session Adherence',
                  icon: Icons.checklist_rtl_outlined,
                  iconColor: Colors.teal,
                  metrics: {
                    'Total Unique Clients on EAC': latestSummary.totalUniqueClients.toString(),
                    'Completed 3+ Sessions': latestSummary.eacSessions.withAtLeast3Sessions.toString(),
                    'Incomplete (< 3 Sessions)': latestSummary.eacSessions.without3Sessions.toString(),
                  },
                ),
                _buildAnalysisCategory(
                  title: 'Viral Load (VL) Summary',
                  icon: Icons.science_outlined,
                  iconColor: Colors.deepPurple,
                  metrics: {
                    'Suppressed (< 50 c/ml)': latestSummary.vlSummary.suppressedLessThan50.toString(),
                    'Suppressed (< 1000 c/ml)': latestSummary.vlSummary.suppressedLessThan1000.toString(),
                    'Unsuppressed (≥ 1000 c/ml)': latestSummary.vlSummary.unsuppressed.toString(),
                    'Clients with Repeat VL': latestSummary.vlSummary.withRepeatVl.toString(),
                    'Clients for Switch Review': latestSummary.vlSummary.switchReviewCount.toString(),
                  },
                ),
                _buildAnalysisCategory(
                  title: 'Turn-Around Time (TAT) for VL',
                  icon: Icons.hourglass_top_outlined,
                  iconColor: Colors.amber.shade800,
                  metrics: {
                    'Less than 90 Days': latestSummary.tat.lessThan90Days.toString(),
                    '90 - 150 Days': latestSummary.tat.between90and150Days.toString(),
                    'More than 150 Days': latestSummary.tat.moreThan150Days.toString(),
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAnalysisCategory({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Map<String, String> metrics
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 12),
          ...metrics.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  entry.value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  // --- END NEW ---

  Widget _buildSummaryInfoCard() {
    final numberFormatter = NumberFormat.compact();
    final currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final totalDuration = _filteredLogList.fold<int>(0, (sum, item) => sum + (item.callDuration ?? 0));
    final uniqueClients = _filteredLogList.map((log) => log.artId).toSet().length;

    return Card(
      margin: const EdgeInsets.only(bottom: 0), // Modified margin
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 20.0,
              runSpacing: 16.0,
              children: [
                _buildInfoTile(
                  iconWidget: Icon(Icons.group, color: Colors.teal.shade700, size: 36),
                  label: 'Unique Clients Contacted',
                  value: numberFormatter.format(uniqueClients),
                  subtitle: 'in selected period',
                ),
                _buildInfoTile(
                  iconWidget: Icon(Icons.call, color: Colors.blue.shade700, size: 36),
                  label: 'Total EAC Calls Logged',
                  value: numberFormatter.format(_filteredLogList.length),
                  subtitle: 'in selected period',
                ),
                _buildInfoTile(
                  iconWidget: Icon(Icons.timer_outlined, color: Colors.purple.shade700, size: 36),
                  label: 'Total Call Duration',
                  value: formatDuration(totalDuration),
                ),
              ],
            ),
            const Divider(height: 24.0, thickness: 1.0),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 20.0,
              runSpacing: 16.0,
              children: [
                _buildInfoTile(
                  iconWidget: Text('₦', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                  label: 'Estimated Call Cost (All)',
                  value: currencyFormatter.format(_totalCallCost),
                ),
                _buildInfoTile(
                  iconWidget: Text('₦', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  label: 'Cost (Outgoing Answered)',
                  value: currencyFormatter.format(_outgoingAnsweredCost),
                ),
                _buildInfoTile(
                  iconWidget: Text('₦', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.lightGreen.shade700)),
                  label: 'Cost (Incoming Answered)',
                  value: currencyFormatter.format(_incomingAnsweredCost),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('(at ₦${_costPerSecond.toStringAsFixed(2)}/sec)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Wrap(
      spacing: 20.0,
      runSpacing: 20.0,
      alignment: WrapAlignment.start,
      children: [
        _buildChartCard(title: 'Call Outcome Distribution', chartKey: _outcomeChartKey, chart: SfCircularChart(
            annotations: (outcomeChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null,
            legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
            series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: outcomeChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])),

        _buildChartCard(title: 'EAC Session Distribution', chartKey: _sessionTypeChartKey, chart: SfCircularChart(
            annotations: (sessionTypeChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null,
            legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
            series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: sessionTypeChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])),

        _buildChartCard(title: 'ART Status Distribution', chartKey: _artStatusChartKey, chart: SfCircularChart(
            annotations: (artStatusChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null,
            legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
            series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: artStatusChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])),

        _buildChartCard(isWide: true, title: 'Average Call Duration Trend (Daily)', chartKey: _callDurationChartKey, chart: SfCartesianChart(
            annotations: (callDurationTrendData.isEmpty) ? [const CartesianChartAnnotation(widget: Text("No data"), coordinateUnit: CoordinateUnit.point, region: AnnotationRegion.chart, x: '50%', y: '50%')] : null,
            primaryXAxis: const CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Date Tracked')),
            primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Avg. Duration (s)'), numberFormat: NumberFormat.compact()),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: <CartesianSeries>[LineSeries<_ChartDataPoint, String>(dataSource: callDurationTrendData, xValueMapper: (data, _) => DateFormat('MMM d').format(DateFormat('yyyy-MM-dd').parse(data.x)), yValueMapper: (data, _) => data.y, name: 'Avg Duration', markerSettings: const MarkerSettings(isVisible: true))])),
      ],
    );
  }

  Widget _buildDetailedLogSection(List<String> dailyGroupedKeys, Map<String, List<EacCallLog>> dailyGroupedReports) {
    if (dailyGroupedKeys.isEmpty) { // Simplified check
      return const Card(child: SizedBox(height: 100, child: Center(child: Text("No detailed logs match the current filters."))));
    }
    return ExpansionPanelList(
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          _currentlyExpandedDateIndex = _currentlyExpandedDateIndex == index ? -1 : index;
        });
      },
      animationDuration: const Duration(milliseconds: 300),
      children: dailyGroupedKeys.map<ExpansionPanel>((String dateKey) {
        final index = dailyGroupedKeys.indexOf(dateKey);
        final dailyLogList = dailyGroupedReports[dateKey]!;
        final bool isExpanded = _currentlyExpandedDateIndex == index;

        return ExpansionPanel(
          isExpanded: isExpanded,
          canTapOnHeader: true,
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Row(
                children: [
                  Expanded(child: Text(dateKey, style: const TextStyle(fontWeight: FontWeight.bold))),
                  Visibility(
                    visible: isExpanded,
                    maintainSize: true, maintainAnimation: true, maintainState: true,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Scroll Left',
                          onPressed: () => _logTableControllers[index].animateTo(_logTableControllers[index].offset - 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          tooltip: 'Scroll Right',
                          onPressed: () => _logTableControllers[index].animateTo(_logTableControllers[index].offset + 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          body: SingleChildScrollView(
            controller: _logTableControllers[index],
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Client Name')), DataColumn(label: Text('Client PhoneNo')), DataColumn(label: Text('Client ART Status')),
                  DataColumn(label: Text("Client's Facility")), DataColumn(label: Text('Client State')), DataColumn(label: Text('Client ART ID')),
                  DataColumn(label: Text('DatimCode')), DataColumn(label: Text('Time Tracked')), DataColumn(label: Text('EAC Session')),
                  DataColumn(label: Text('Call Outcome')), DataColumn(label: Text('Duration')), DataColumn(label: Text('Tracked By')),
                  DataColumn(label: Text("Tracker's Designation")), DataColumn(label: Text("Tracker's Facility")),
                  DataColumn(label: Text("Tracker's Supervisor")), DataColumn(label: Text("Tracker's Supervisor Email")),
                ],
                rows: dailyLogList.map((log) {
                  return DataRow(cells: [
                    DataCell(Text(_maskClientName(log.clientName))),
                    DataCell(Text(_maskPhoneNumber(log.phoneNumber))),
                    DataCell(Text(log.artStatus ?? 'N/A')),
                    DataCell(Text(log.facilityName ?? 'N/A')),
                    DataCell(Text(log.state ?? 'N/A')),
                    DataCell(Text(_maskClientName(log.artId))),
                    DataCell(Text(log.datimCode ?? 'N/A')),
                    DataCell(Text(log.dateTracked != null ? DateFormat('HH:mm').format(log.dateTracked!) : 'N/A')),
                    DataCell(Text(log.eacSessionType ?? 'N/A')),
                    DataCell(_buildStatusCell(log.trackingOutcome)),
                    DataCell(Text(formatDuration(log.callDuration ?? 0))),
                    DataCell(Text(log.trackedBy ?? 'N/A')),
                    DataCell(Text(log.designation ?? 'N/A')),
                    DataCell(Text(log.trackerFacilityLocation ?? 'N/A')),
                    DataCell(Text(log.supervisorName ?? 'N/A')),
                    DataCell(Text(log.supervisorEmail ?? 'N/A')),
                  ]);
                }).toList(),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- HELPER METHODS (Mostly copied from Facility Tracker, adapted for EacCallLog) ---

  // ... (All helper methods from here on are adapted from the facility tracker page)
  // ... (_showSnackBar, _maskClientName, _maskPhoneNumber, _promptForPasswordAndReauthenticate, _toggleGlobalUnmask)
  // ... (_exportToCSV, _exportToPDF, _buildPdfChart, _captureChartPng, _triggerDownload)
  // ... (_getCallDurationTrendData, _getArtStatusData, formatDuration, _getStatusColor, _buildStatusCell)
  // ... (_groupLogsByDate, _generateClientCallSummary, _formatDateWithSuffix, _showDateRangePicker)
  // ... (_showMultiSelectDialog, _buildFilterChip, _buildInfoTile, _buildChartCard, _buildClientSummarySection)
  // ... (The class definitions for _ChartDataPoint and _ClientCallSummary also remain)

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20)));
  }

  String _maskClientName(String? name) {
    if (_allCellsGloballyUnlocked || name == null || name.isEmpty) return name ?? 'N/A';
    List<String> parts = name.split(' ');
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      if (!name.contains(" ") && name.length > 6) {
        return '...${name.substring(name.length - 4)} (Hidden)';
      }
      return '${parts[0][0]}. (Hidden)';
    }
    return 'Hidden';
  }

  String _maskPhoneNumber(String? phone) {
    if (_allCellsGloballyUnlocked || phone == null || phone.isEmpty) return phone ?? 'N/A';
    return phone.length > 4 ? '...${phone.substring(phone.length - 4)}' : phone.replaceAll(RegExp(r'.'), '*');
  }

  Future<bool> _promptForPasswordAndReauthenticate() async {
    final passwordController = TextEditingController();
    final user = _auth.currentUser;

    if (user == null || user.email == null) {
      _showSnackBar("Cannot authenticate: User or user email is not available.");
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isAuthenticating = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Authentication Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Please enter your password to unmask sensitive data."),
                const SizedBox(height: 10),
                if (isAuthenticating)
                  const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator()))
                else
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: 'Password', border: OutlineInputBorder()),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isAuthenticating ? null : () async {
                  if (passwordController.text.isEmpty) { _showSnackBar("Password cannot be empty."); return; }
                  setState(() => isAuthenticating = true);
                  try {
                    final credential = EmailAuthProvider.credential(email: user.email!, password: passwordController.text.trim());
                    await user.reauthenticateWithCredential(credential);
                    Navigator.pop(context, true); // Success
                  } catch (e) {
                    _showSnackBar('Authentication Error. Please try again.');
                    Navigator.pop(context, false); // Failure
                  }
                },
                child: const Text('Confirm & Unmask'),
              ),
            ],
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _toggleGlobalUnmask() async {
    if (_allCellsGloballyUnlocked) {
      if (mounted) setState(() => _allCellsGloballyUnlocked = false);
      _showSnackBar('All sensitive data re-masked.');
    } else {
      final bool isAuthenticated = await _promptForPasswordAndReauthenticate();
      if (isAuthenticated) {
        if (mounted) setState(() => _allCellsGloballyUnlocked = true);
        _showSnackBar('All sensitive data has been unmasked.');
      } else if (mounted) {
        _showSnackBar('Authentication failed. Data remains masked.');
      }
    }
  }

  Future<void> _exportToCSV() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    bool proceed = _allCellsGloballyUnlocked;
    if (!proceed) {
      proceed = await _promptForPasswordAndReauthenticate();
      if (!proceed) { _showSnackBar('Authentication failed. Export will contain masked data.'); }
    }

    try {
      List<List<dynamic>> rows = [
        [
          'Client Name', 'Client PhoneNo', 'Client ART Status', "Client's Facility",
          'Client State', 'Client ART ID', 'DatimCode', 'Date Tracked', 'Time Tracked',
          'EAC Session', 'Call Outcome', 'Duration of Call (s)', 'Tracked By', "Tracker's Designation",
          "Tracker's Facility", "Tracker's Supervisor", "Tracker's Supervisor Email"
        ]
      ];
      for (var log in _filteredLogList) {
        rows.add([
          _allCellsGloballyUnlocked ? (log.clientName ?? 'N/A') : _maskClientName(log.clientName),
          _allCellsGloballyUnlocked ? (log.phoneNumber ?? 'N/A') : _maskPhoneNumber(log.phoneNumber),
          log.artStatus ?? 'N/A',
          log.facilityName ?? 'N/A',
          log.state ?? 'N/A',
          log.artId ?? 'N/A',
          log.datimCode ?? 'N/A',
          log.dateTracked != null ? DateFormat('yyyy-MM-dd').format(log.dateTracked!) : 'N/A',
          log.dateTracked != null ? DateFormat('HH:mm').format(log.dateTracked!) : 'N/A',
          log.eacSessionType ?? 'N/A',
          log.trackingOutcome ?? 'N/A',
          log.callDuration ?? 0,
          log.trackedBy ?? 'N/A',
          log.designation ?? 'N/A',
          log.trackerFacilityLocation ?? 'N/A',
          log.supervisorName ?? 'N/A',
          log.supervisorEmail ?? 'N/A',
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvData);
      _triggerDownload(bytes, 'eac_call_log_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv', 'text/csv');
    } catch (e) {
      _showSnackBar('Error exporting CSV: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToPDF() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();
      final Uint8List? outcomeBytes = await _captureChartPng(_outcomeChartKey);
      final Uint8List? artStatusBytes = await _captureChartPng(_artStatusChartKey);
      final Uint8List? sessionTypeBytes = await _captureChartPng(_sessionTypeChartKey);
      final Uint8List? callDurationBytes = await _captureChartPng(_callDurationChartKey);

      final pw.MemoryImage? outcomeImg = outcomeBytes != null ? pw.MemoryImage(outcomeBytes) : null;
      final pw.MemoryImage? artStatusImg = artStatusBytes != null ? pw.MemoryImage(artStatusBytes) : null;
      final pw.MemoryImage? sessionTypeImg = sessionTypeBytes != null ? pw.MemoryImage(sessionTypeBytes) : null;
      final pw.MemoryImage? callDurationImg = callDurationBytes != null ? pw.MemoryImage(callDurationBytes) : null;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          header: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('EAC Call Tracking Report - ${DateFormat.yMMMMd().format(DateTime.now())}',
                style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey)),
          ),
          build: (pw.Context context) => [
            pw.Header(level: 0, text: 'EAC Call Tracking Summary Report'),
            pw.Paragraph(
              text: 'Report for: ${userFirstName ?? ''} ${userLastName ?? ''} at ${userLocation ?? 'N/A'}\n'
                  'Date Range: ${DateFormat.yMd().format(startDate!)} to ${DateFormat.yMd().format(endDate!)}',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 20),
            pw.Wrap(
                spacing: 20, runSpacing: 20, alignment: pw.WrapAlignment.spaceEvenly,
                children: [
                  if (outcomeImg != null) _buildPdfChart('Call Outcome Distribution', outcomeImg),
                  if (sessionTypeImg != null) _buildPdfChart('EAC Session Distribution', sessionTypeImg),
                  if (artStatusImg != null) _buildPdfChart('ART Status Distribution', artStatusImg),
                  if (callDurationImg != null) _buildPdfChart('Average Call Duration Trend', callDurationImg),
                ]
            ),
          ],
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      _triggerDownload(pdfBytes, 'eac_call_charts_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf', 'application/pdf');
    } catch (e) {
      _showSnackBar('Error exporting PDF: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.Widget _buildPdfChart(String title, pw.MemoryImage image) {
    return pw.Container(width: 350, child: pw.Column(children: [pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 5), pw.Image(image, fit: pw.BoxFit.contain, height: 200)]));
  }

  Future<Uint8List?> _captureChartPng(GlobalKey key) async {
    try {
      if (key.currentContext == null) return null;
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      _showSnackBar('Error capturing chart image: $e');
      return null;
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

  List<MapEntry<String, int>> _getOutcomeData() {
    Map<String, int> statusCounts = {};
    for (var log in _filteredLogList) {
      String status = log.trackingOutcome?.trim() ?? 'N/A';
      if (status.isEmpty) status = 'N/A';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }


  List<_ChartDataPoint> _getCallDurationTrendData() {
    Map<String, List<int>> dailyDurations = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');
    for (var log in _filteredLogList) {
      if (log.dateTracked != null && log.callDuration != null && log.callDuration! > 0) {
        String dateKey = dateKeyFormat.format(log.dateTracked!);
        dailyDurations.putIfAbsent(dateKey, () => []).add(log.callDuration!);
      }
    }
    List<_ChartDataPoint> chartData = [];
    dailyDurations.forEach((date, durations) {
      double averageDuration = durations.reduce((a, b) => a + b) / durations.length;
      chartData.add(_ChartDataPoint(date, averageDuration));
    });
    chartData.sort((a, b) => a.x.compareTo(b.x));
    return chartData;
  }

  List<MapEntry<String, int>> _getSessionTypeData() {
    Map<String, int> sessionCounts = {};
    for (var log in _filteredLogList) {
      String session = log.eacSessionType?.trim() ?? 'Unknown';
      if (session.isEmpty) session = 'Unknown';
      sessionCounts[session] = (sessionCounts[session] ?? 0) + 1;
    }
    return sessionCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }


  List<MapEntry<String, int>> _getArtStatusData() {
    Map<String, int> statusCounts = {};
    for (var log in _filteredLogList) {
      String status = log.artStatus?.trim() ?? 'Unknown';
      if (status.isEmpty) status = 'Unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
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

  Color _getStatusColor(String status) {
    String lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'answered':
      case 'incoming answered':
      case 'completed':
        return Colors.green.shade700;
      case 'outgoing failed/not answered':
      case 'unknown (no outgoing log detail)':
      case 'missed incoming':
      case 'rejected incoming':
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
    final lowerStatus = status.toLowerCase();
    Color color = _getStatusColor(status);
    Widget? icon;
    if (lowerStatus.contains('answered')) {
      icon = Icon(Icons.call_received, color: color, size: 16);
    } else if (lowerStatus.contains('failed') || lowerStatus.contains('missed')) icon = Icon(Icons.phone_missed, color: color, size: 16);
    if (icon != null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 6), Flexible(child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w500)))]);
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w500)));
  }

  Map<String, List<EacCallLog>> _groupLogsByDate() {
    final Map<String, List<EacCallLog>> dailyReports = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');
    final DateFormat displayFormat = DateFormat('EEEE, MMMM d, yyyy');
    for (var log in _filteredLogList) {
      final dateKey = log.dateTracked != null ? dateKeyFormat.format(log.dateTracked!) : 'Unknown Date';
      dailyReports.putIfAbsent(dateKey, () => []).add(log);
    }
    final sortedKeys = dailyReports.keys.toList()..sort((a, b) {
      if (a == 'Unknown Date') return 1; if (b == 'Unknown Date') return -1; return b.compareTo(a);
    });
    return { for (var k in sortedKeys) (k == 'Unknown Date' ? 'Unknown Date' : displayFormat.format(dateKeyFormat.parse(k))) : dailyReports[k]! };
  }

  Map<String, _ClientCallSummary> _generateClientCallSummary() {
    final Map<String, _ClientCallSummary> summaryMap = {};
    for (var log in _filteredLogList) {
      final clientId = log.artId ?? 'Unknown ID';
      final clientName = log.clientName ?? 'Unknown Name';
      final clientPhone = log.phoneNumber ?? 'Unknown Phone';
      if (!summaryMap.containsKey(clientId)) {
        summaryMap[clientId] = _ClientCallSummary(clientId: clientId, clientName: clientName, clientPhoneNumber: clientPhone);
      }
      summaryMap[clientId]!.totalCalls += 1;
      final status = log.trackingOutcome?.toLowerCase() ?? 'unknown';
      summaryMap[clientId]!.statusCounts[status] = (summaryMap[clientId]!.statusCounts[status] ?? 0) + 1;
    }
    return summaryMap;
  }

  String _formatDateWithSuffix(DateTime date) {
    String day = DateFormat('d').format(date);
    String suffix = 'th'; int dayInt = int.parse(day);
    if (dayInt >= 11 && dayInt <= 13) { suffix = 'th'; } else {
      switch (dayInt % 10) { case 1: suffix = 'st'; break; case 2: suffix = 'nd'; break; case 3: suffix = 'rd'; break; default: suffix = 'th'; }
    }
    return DateFormat("d'$suffix'-MMMM-y").format(date);
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: SizedBox(width: 400, height: 450,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: (startDate != null && endDate != null) ? PickerDateRange(startDate!, endDate!) : null,
            showActionButtons: true,
            onSubmit: (Object? value) {
              Navigator.pop(context);
              if (value is PickerDateRange && value.startDate != null) {
                setState(() { startDate = value.startDate; endDate = value.endDate ?? value.startDate; });
              }
            },
            onCancel: () => Navigator.pop(context),
          ),),),);
  }

  Future<void> _showMultiSelectDialog({
    required BuildContext context,
    required String title,
    required List<String> allOptions,
    required List<String> selectedOptions,
    required String allKeyword,
    required Function(List<String>) onConfirm,
  }) async {
    final tempSelected = List<String>.from(selectedOptions);
    await showDialog(
      context: context,
      builder: (ctx) { // This is the dialog's outer context
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) { // This is the inner context we'll use
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 350,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allOptions.length,
                  itemBuilder: (context, index) {
                    final option = allOptions[index];
                    final isAllOption = option == allKeyword;
                    return CheckboxListTile(
                      title: Text(option, style: TextStyle(fontWeight: isAllOption ? FontWeight.bold : FontWeight.normal)),
                      value: tempSelected.contains(option),
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            if (isAllOption) {
                              tempSelected.clear();
                              tempSelected.add(allKeyword);
                            } else {
                              tempSelected.remove(allKeyword);
                              tempSelected.add(option);
                            }
                          } else {
                            tempSelected.remove(option);
                            if (tempSelected.isEmpty && allOptions.contains(allKeyword)) {
                              tempSelected.add(allKeyword);
                            }
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                // --- FIX --- Use the dialog's context to pop
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                // --- FIX --- Use the dialog's context to pop
                ElevatedButton(
                  onPressed: () {
                    onConfirm(tempSelected);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _buildFilterChip(String label, String value, IconData icon, VoidCallback onPressed, {bool disabled = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      InputChip(avatar: Icon(icon, size: 18), label: Text(value, overflow: TextOverflow.ellipsis), onPressed: disabled ? null : onPressed, showCheckmark: false, side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.7)), backgroundColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),),
    ],);
  }

  Widget _buildInfoTile({required Widget iconWidget, required String label, required String value, String? subtitle}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      iconWidget,
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        if (subtitle != null && subtitle.isNotEmpty) ...[const SizedBox(height: 2), Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600))],
      ],),
    ],);
  }

  Widget _buildChartCard({required String title, required Widget chart, GlobalKey? chartKey, bool isWide = false}) {
    Widget chartWithBoundary = RepaintBoundary(key: chartKey, child: Container(color: Colors.white, child: chart));
    return ConstrainedBox(constraints: BoxConstraints(maxWidth: isWide ? 600 : 400, minWidth: 350),
      child: Card(elevation: 2.0, child: Padding(padding: const EdgeInsets.all(12.0),
        child: Column(children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 10), SizedBox(height: 250, child: chartWithBoundary)],),),),);
  }

  Widget _buildClientSummarySection(Map<String, _ClientCallSummary> clientSummaryMap) {
    return Card(clipBehavior: Clip.antiAlias, elevation: 2, margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        title: Row(children: [
          Expanded(child: Text('Summary of Calls per Client', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
          Visibility(visible: _isClientSummaryExpanded, maintainSize: true, maintainAnimation: true, maintainState: true,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Scroll Left', onPressed: () => _clientSummaryScrollController.animateTo(_clientSummaryScrollController.offset - 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
              IconButton(icon: const Icon(Icons.arrow_forward), tooltip: 'Scroll Right', onPressed: () => _clientSummaryScrollController.animateTo(_clientSummaryScrollController.offset + 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
            ],),),
        ],),
        initiallyExpanded: _isClientSummaryExpanded,
        onExpansionChanged: (isExpanded) => setState(() => _isClientSummaryExpanded = isExpanded),
        children: [
          SingleChildScrollView(controller: _clientSummaryScrollController, scrollDirection: Axis.horizontal,
            child: Padding(padding: const EdgeInsets.all(8.0),
              child: DataTable(columnSpacing: 15.0, headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                columns: const [DataColumn(label: Text('Client ART ID')), DataColumn(label: Text('Client Name')), DataColumn(label: Text('Client Phone')), DataColumn(label: Text('Total Calls')), DataColumn(label: Text('Call Outcome Summary'))],
                rows: clientSummaryMap.values.map((summary) {
                  final statusSummary = summary.statusCounts.entries.map((e) => '${e.key}: ${e.value}').join(', ');
                  return DataRow(cells: [DataCell(Text(_maskClientName(summary.clientId))), DataCell(Text(_maskClientName(summary.clientName))), DataCell(Text(_maskPhoneNumber(summary.clientPhoneNumber))), DataCell(Text(summary.totalCalls.toString())), DataCell(Text(statusSummary))]);
                }).toList(),
              ),),),],),);
  }
}

// Helper classes for chart data points and client summaries
class _ChartDataPoint {
  final String x;
  final double y;
  _ChartDataPoint(this.x, this.y);
}

class _ClientCallSummary {
  final String clientId;
  final String clientName;
  final String clientPhoneNumber;
  int totalCalls = 0;
  Map<String, int> statusCounts = {};

  _ClientCallSummary({
    required this.clientId,
    required this.clientName,
    required this.clientPhoneNumber,
  });
}