// STATE-LEVEL EAC REPORT WITH HISTORICAL TREND ANALYSIS (V2 - ENHANCED LAYOUT & AGGREGATION)
// This report aggregates data from multiple facilities over a selected date range.

import 'dart:convert' show utf8;
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:csv/csv.dart';

import '../../widgets/drawer2.dart'; // Assuming a state-level drawer

// --- DATA MODELS (MODIFIED TO BE MUTABLE FOR AGGREGATION) ---

class EacReportModel {
  final String facilityName;
  final DateTime reportDate;
  final TatSummary tat;
  final EacSessionSummary eacSessions;
  final VlSummary vlSummary;

  EacReportModel({
    required this.facilityName, required this.reportDate, required this.tat,
    required this.eacSessions, required this.vlSummary,
  });

  factory EacReportModel.fromFirestore(DocumentSnapshot doc, String facility) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(doc.id);
    } catch (e) {
      parsedDate = (data['lastUpdated'] as Timestamp? ?? Timestamp.now()).toDate();
    }

    return EacReportModel(
      facilityName: facility,
      reportDate: parsedDate,
      tat: TatSummary.fromMap(data['tat'] as Map<String, dynamic>? ?? {}),
      eacSessions: EacSessionSummary.fromMap(data['eacSessions'] as Map<String, dynamic>? ?? {}),
      vlSummary: VlSummary.fromMap(
          data['vlSummary'] as Map<String, dynamic>? ?? {},
          totalClients: data['totalUniqueClients'] as int? ?? 0),
    );
  }
}

// MODIFIED: Removed 'final' to allow fields to be modified for aggregation.
class TatSummary {
  int lessThan90Days;
  int between90and150Days;
  int moreThan150Days;
  TatSummary({this.lessThan90Days = 0, this.between90and150Days = 0, this.moreThan150Days = 0});
  factory TatSummary.fromMap(Map<String, dynamic> map) => TatSummary(
    lessThan90Days: map['lessThan90Days'] as int? ?? 0,
    between90and150Days: map['between90and150Days'] as int? ?? 0,
    moreThan150Days: map['moreThan150Days'] as int? ?? 0,
  );
}

class EacSessionSummary {
  int withAtLeast3Sessions;
  int without3Sessions;
  EacSessionSummary({this.withAtLeast3Sessions = 0, this.without3Sessions = 0});
  factory EacSessionSummary.fromMap(Map<String, dynamic> map) => EacSessionSummary(
    withAtLeast3Sessions: map['withAtLeast3Sessions'] as int? ?? 0,
    without3Sessions: map['without3Sessions'] as int? ?? 0,
  );
}

class VlSummary {
  int withRepeatVl;
  int withRepeatVlResult;
  int suppressedLessThan1000;
  int suppressedLessThan50;
  int unsuppressed;
  int totalUniqueClients;
  VlSummary({this.withRepeatVl = 0, this.withRepeatVlResult = 0, this.suppressedLessThan1000 = 0, this.suppressedLessThan50 = 0, this.unsuppressed = 0, this.totalUniqueClients = 0});

  factory VlSummary.fromMap(Map<String, dynamic> map, {int totalClients = 0}) {
    // The totalClients might come from the root document, so we pass it in.
    return VlSummary(
      withRepeatVl: map['withRepeatVl'] as int? ?? 0,
      withRepeatVlResult: map['withRepeatVlResult'] as int? ?? 0,
      suppressedLessThan1000: map['suppressedLessThan1000'] as int? ?? 0,
      suppressedLessThan50: map['suppressedLessThan50'] as int? ?? 0,
      unsuppressed: map['unsuppressed'] as int? ?? 0,
      totalUniqueClients: totalClients,
    );
  }
}
class EacCallLogModel {
  final String? clientName, artId, phoneNumber, eacSessionType, outcome;
  final String? trackedBy, trackerFacility, designation, supervisorName, supervisorEmail;
  final DateTime callDateTime;
  final int duration;
  EacCallLogModel({
    this.clientName, this.artId, this.phoneNumber, this.eacSessionType, this.outcome,
    this.trackedBy, this.trackerFacility, this.designation, this.supervisorName, this.supervisorEmail,
    required this.callDateTime, required this.duration,
  });
  factory EacCallLogModel.fromFirestore(Map<String, dynamic> data) => EacCallLogModel(
    clientName: data['clientName'] as String?, artId: data['artId'] as String?, phoneNumber: data['phoneNumber'] as String?,
    eacSessionType: data['eacSessionType'] as String?, outcome: data['trackingOutcome'] as String?, trackedBy: data['trackedBy'] as String?,
    trackerFacility: data['trackerFacilityLocation'] as String?, designation: data['designation'] as String?,
    supervisorName: data['supervisorName'] as String?, supervisorEmail: data['supervisorEmail'] as String?,
    callDateTime: (data['dateTracked'] as Timestamp? ?? Timestamp.now()).toDate(), duration: data['callDuration'] as int? ?? 0,
  );
}

// --- HELPER CLASSES FOR AGGREGATION & CHARTS ---
class _ChartData {
  final String category;
  final num value;
  final Color color;
  _ChartData(this.category, this.value, this.color);
}

class DailyAggregatedEacMetrics {
  final DateTime date;
  TatSummary tat = TatSummary();
  EacSessionSummary eacSessions = EacSessionSummary();
  VlSummary vlSummary = VlSummary();
  DailyAggregatedEacMetrics(this.date);
}

class FacilityAggregatedMetrics {
  final String name;
  TatSummary tat = TatSummary();
  EacSessionSummary eacSessions = EacSessionSummary();
  VlSummary vlSummary = VlSummary();
  FacilityAggregatedMetrics(this.name);
}

// NEW: Class to hold the grand total aggregations for the top summary section.
class TotalAggregatedMetrics {
  TatSummary tat = TatSummary();
  EacSessionSummary eacSessions = EacSessionSummary();
  VlSummary vlSummary = VlSummary();
}

// --- MAIN WIDGET ---
class StateEacHistoricalReportTab extends StatefulWidget {
  const StateEacHistoricalReportTab({super.key});
  @override
  _StateEacHistoricalReportTabState createState() => _StateEacHistoricalReportTabState();
}

class _StateEacHistoricalReportTabState extends State<StateEacHistoricalReportTab> {
  // --- Services & State Management ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool _isFilterLoading = true;
  bool _isExporting = false; // <-- ADD THIS LINE
  bool _isLoading = false;
  bool _isInitialState = true;
  String? _errorMessage;

  // NEW: GlobalKeys for capturing charts for PDF
  final GlobalKey _tatBarChartKey = GlobalKey();
  final GlobalKey _sessionBarChartKey = GlobalKey();
  final GlobalKey _tatTrendChartKey = GlobalKey();
  final GlobalKey _sessionTrendChartKey = GlobalKey();

  // --- Filter & User Context ---
  String? _userState;
  List<String> _availableFacilities = [];
  String? _selectedFacilityName;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();


  // --- Data & Aggregation Holders ---
  List<EacReportModel> _allReports = [];
  List<EacCallLogModel> _allCallLogs = [];
  List<DailyAggregatedEacMetrics> _dailyAggregatedMetrics = [];
  Map<String, FacilityAggregatedMetrics> _facilityAggregatedMetrics = {};
  TotalAggregatedMetrics _totalAggregatedMetrics = TotalAggregatedMetrics();

  // --- PII Masking ---
  bool _allCellsGloballyUnlocked = false;

  @override
  void initState() {
    super.initState();
    _initializeUserContext();
  }

  // --- NEW EXPORT AND HELPER METHODS ---

  Future<void> _exportSummaryToCsv() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    final totals = _totalAggregatedMetrics;
    List<List<dynamic>> rows = [
      ['State-Wide EAC Summary Report'],
      ['State', _userState],
      ['Facility Filter', _selectedFacilityName],
      ['Date Range', '${DateFormat.yMd().format(_startDate)} - ${DateFormat.yMd().format(_endDate)}'],
      [],
      ['Metric', 'Value'],
      [],
      ['--- Overall Performance ---', ''],
      ['Total Clients on EAC', totals.vlSummary.totalUniqueClients],
      ['Repeat VL with Result', totals.vlSummary.withRepeatVlResult],
      ['Unsuppressed (>=1k)', totals.vlSummary.unsuppressed],
      ['Suppressed (<50)', totals.vlSummary.suppressedLessThan50],
      [],
      ['--- Turn-Around Time (TAT) ---', ''],
      ['<= 3 Months', totals.tat.lessThan90Days],
      ['3-5 Months', totals.tat.between90and150Days],
      ['> 5 Months', totals.tat.moreThan150Days],
      [],
      ['--- EAC Session Completion ---', ''],
      ['>= 3 Sessions', totals.eacSessions.withAtLeast3Sessions],
      ['< 3 Sessions', totals.eacSessions.without3Sessions],
    ];

    String csvData = const ListToCsvConverter().convert(rows);
    _triggerDownload(utf8.encode(csvData), 'eac_summary_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');

    setState(() => _isExporting = false);
  }

  Future<void> _exportDetailsToCsv() async {
    if (_isExporting) return;
    bool proceed = _allCellsGloballyUnlocked;
    if(!proceed) {
      proceed = await _promptForPasswordAndReauthenticate();
      if(!proceed) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Authentication failed. Export cancelled.")));
        return;
      }
    }
    setState(() => _isExporting = true);

    // Facility Summary Data
    List<List<dynamic>> rows = [
      ['Facility-Level Summary (Aggregated over selected period)'],
      [],
      [
        'Facility', 'Clients', 'TAT <3m', 'TAT 3-5m', 'TAT >5m', 'Sess. >=3', 'Sess. <3',
        'Rpt. VL', 'Rpt. VL w/ Result', 'Unsupp.', 'Supp. <1k', 'Supp. <50'
      ],
      ..._facilityAggregatedMetrics.values.map((agg) => [
        agg.name, agg.vlSummary.totalUniqueClients, agg.tat.lessThan90Days, agg.tat.between90and150Days,
        agg.tat.moreThan150Days, agg.eacSessions.withAtLeast3Sessions, agg.eacSessions.without3Sessions,
        agg.vlSummary.withRepeatVl, agg.vlSummary.withRepeatVlResult, agg.vlSummary.unsuppressed,
        agg.vlSummary.suppressedLessThan1000, agg.vlSummary.suppressedLessThan50
      ]),
      [],
      [],
      ['Call Log Details'],
      [],
      [
        'Facility', 'Date', 'Client Name', 'Phone', 'Outcome', 'Duration (s)',
        'EAC Session', 'Tracker', 'Designation', 'Supervisor'
      ],
      ..._allCallLogs.map((log) => [
        log.trackerFacility ?? 'N/A', DateFormat.yMd().add_jm().format(log.callDateTime),
        log.clientName, log.phoneNumber, log.outcome ?? 'N/A', log.duration,
        log.eacSessionType ?? 'N/A', log.trackedBy ?? 'N/A', log.designation ?? 'N/A',
        log.supervisorName ?? 'N/A'
      ])
    ];

    String csvData = const ListToCsvConverter().convert(rows);
    _triggerDownload(utf8.encode(csvData), 'eac_details_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');

    setState(() => _isExporting = false);
  }

  Future<void> _exportChartsToPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final tatBarBytes = await _captureChartPng(_tatBarChartKey);
      final sessionBarBytes = await _captureChartPng(_sessionBarChartKey);
      final tatTrendBytes = await _captureChartPng(_tatTrendChartKey);
      final sessionTrendBytes = await _captureChartPng(_sessionTrendChartKey);

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (context) => pw.Header(text: "EAC Performance Charts Report"),
        build: (context) => [
          pw.Text("Facility Filter: $_selectedFacilityName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("Date Range: ${DateFormat.yMd().format(_startDate)} to ${DateFormat.yMd().format(_endDate)}"),
          pw.Divider(),
          pw.SizedBox(height: 10),
          if (tatBarBytes != null || sessionBarBytes != null)
            pw.Text("Overall Summary Charts", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (tatBarBytes != null) pw.Image(pw.MemoryImage(tatBarBytes), width: 380),
                if (sessionBarBytes != null) pw.Image(pw.MemoryImage(sessionBarBytes), width: 380),
              ]
          ),
          pw.SizedBox(height: 20),
          if (tatTrendBytes != null || sessionTrendBytes != null)
            pw.Text("Historical Trend Charts", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          if(tatTrendBytes != null) pw.Image(pw.MemoryImage(tatTrendBytes), width: 700),
          pw.SizedBox(height: 20),
          if(sessionTrendBytes != null) pw.Image(pw.MemoryImage(sessionTrendBytes), width: 700),
        ],
      ));

      final pdfBytes = await pdf.save();
      _triggerDownload(pdfBytes, 'eac_charts_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf', 'application/pdf');

    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
    } finally {
      if(mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List?> _captureChartPng(GlobalKey key) async {
    try {
      if (key.currentContext == null) return null;
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // Wrap the chart in a white container for clean capture
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

  Future<void> _initializeUserContext() async {
    setState(() => _isFilterLoading = true);
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      final userState = staffDoc.data()?['state'] as String?;
      if (userState == null || userState.isEmpty) throw Exception("State not found in profile.");
      _userState = userState;
      final facilityNames = await _getFacilitiesForState(userState);
      if (mounted) {
        setState(() {
          _availableFacilities = ['All Facilities', ...facilityNames];
          _isFilterLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Failed to load filters: $e");
    } finally {
      if (mounted) setState(() => _isFilterLoading = false);
    }
  }



  Future<List<String>> _getFacilitiesForState(String state) async {
    final snapshot = await _firestore.collection('Location').doc(state).collection(state).get();
    final List<String> facilityNames = [];
    for (final doc in snapshot.docs) {
      final locationName = doc.data()['LocationName'] as String?;
      if (locationName != null && locationName.isNotEmpty) {
        final lowerCaseName = locationName.toLowerCase();
        if (!lowerCaseName.startsWith('hotel') && !lowerCaseName.startsWith('caritas')) {
          facilityNames.add(locationName);
        }
      }
    }
    facilityNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return facilityNames;
  }

  Future<void> _loadAndCalculateReports() async {
    if (_selectedFacilityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a facility.")));
      return;
    }
    setState(() {
      _isInitialState = false;
      _isLoading = true;
      _errorMessage = null;
    });
    _resetAllMetrics();

    try {
      if (_userState == null) throw Exception("User State is not defined.");
      List<String> facilitiesToFetch = _selectedFacilityName == 'All Facilities'
          ? (List.from(_availableFacilities)..remove('All Facilities'))
          : [_selectedFacilityName!];

      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      for (String facilityName in facilitiesToFetch) {
        final querySnapshot = await _firestore.collection('EAC_Reports').doc(_userState!).collection(facilityName)
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
            .where(FieldPath.documentId, isLessThanOrEqualTo: endDateStr)
            .get();

        for (final doc in querySnapshot.docs) {
          _allReports.add(EacReportModel.fromFirestore(doc, facilityName));
          final callLogSnapshot = await doc.reference.collection('callLogs').get();
          _allCallLogs.addAll(callLogSnapshot.docs.map((logDoc) => EacCallLogModel.fromFirestore(logDoc.data())));
        }
      }
      _calculateMetrics();
    } catch (e, stack) {
      debugPrint('Error loading EAC reports: $e\n$stack');
      if (mounted) setState(() => _errorMessage = 'Failed to load reports: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetAllMetrics() {
    setState(() {
      _allReports = [];
      _allCallLogs = [];
      _dailyAggregatedMetrics = [];
      _facilityAggregatedMetrics = {};
      _totalAggregatedMetrics = TotalAggregatedMetrics();
    });
  }

  void _calculateMetrics() {
    final dailyMetrics = <DateTime, DailyAggregatedEacMetrics>{};
    final facilityMetrics = <String, FacilityAggregatedMetrics>{};
    final totalMetrics = TotalAggregatedMetrics();

    for (final report in _allReports) {
      // 1. Aggregate by day for trend charts
      final dailyAgg = dailyMetrics.putIfAbsent(report.reportDate, () => DailyAggregatedEacMetrics(report.reportDate));
      dailyAgg.tat.lessThan90Days += report.tat.lessThan90Days;
      dailyAgg.tat.between90and150Days += report.tat.between90and150Days;
      dailyAgg.tat.moreThan150Days += report.tat.moreThan150Days;
      dailyAgg.eacSessions.withAtLeast3Sessions += report.eacSessions.withAtLeast3Sessions;
      dailyAgg.eacSessions.without3Sessions += report.eacSessions.without3Sessions;

      // 2. Aggregate by facility for summary table
      final facilityAgg = facilityMetrics.putIfAbsent(report.facilityName, () => FacilityAggregatedMetrics(report.facilityName));
      facilityAgg.tat.lessThan90Days += report.tat.lessThan90Days;
      facilityAgg.tat.between90and150Days += report.tat.between90and150Days;
      facilityAgg.tat.moreThan150Days += report.tat.moreThan150Days;
      facilityAgg.eacSessions.withAtLeast3Sessions += report.eacSessions.withAtLeast3Sessions;
      facilityAgg.eacSessions.without3Sessions += report.eacSessions.without3Sessions;
      facilityAgg.vlSummary.totalUniqueClients += report.vlSummary.totalUniqueClients;
      facilityAgg.vlSummary.withRepeatVl += report.vlSummary.withRepeatVl;
      facilityAgg.vlSummary.withRepeatVlResult += report.vlSummary.withRepeatVlResult;
      facilityAgg.vlSummary.suppressedLessThan1000 += report.vlSummary.suppressedLessThan1000;
      facilityAgg.vlSummary.suppressedLessThan50 += report.vlSummary.suppressedLessThan50;
      facilityAgg.vlSummary.unsuppressed += report.vlSummary.unsuppressed;

      // 3. Aggregate grand totals for top summary section
      totalMetrics.tat.lessThan90Days += report.tat.lessThan90Days;
      totalMetrics.tat.between90and150Days += report.tat.between90and150Days;
      totalMetrics.tat.moreThan150Days += report.tat.moreThan150Days;
      totalMetrics.eacSessions.withAtLeast3Sessions += report.eacSessions.withAtLeast3Sessions;
      totalMetrics.eacSessions.without3Sessions += report.eacSessions.without3Sessions;
      totalMetrics.vlSummary.totalUniqueClients += report.vlSummary.totalUniqueClients;
      totalMetrics.vlSummary.withRepeatVl += report.vlSummary.withRepeatVl;
      totalMetrics.vlSummary.withRepeatVlResult += report.vlSummary.withRepeatVlResult;
      totalMetrics.vlSummary.suppressedLessThan1000 += report.vlSummary.suppressedLessThan1000;
      totalMetrics.vlSummary.suppressedLessThan50 += report.vlSummary.suppressedLessThan50;
      totalMetrics.vlSummary.unsuppressed += report.vlSummary.unsuppressed;
    }

    setState(() {
      _dailyAggregatedMetrics = dailyMetrics.values.toList()..sort((a, b) => a.date.compareTo(b.date));
      _facilityAggregatedMetrics = facilityMetrics;
      _totalAggregatedMetrics = totalMetrics;
    });
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

  // --- PII Masking and other helpers... (same as before)
  String _maskClientName(String? name) { if (_allCellsGloballyUnlocked || name == null || name.isEmpty) return name ?? 'N/A'; return name.split(' ').isNotEmpty ? '${name.split(' ')[0][0]}. (Hidden)' : 'Hidden'; }
  String _maskPhoneNumber(String? phone) { if (_allCellsGloballyUnlocked || phone == null || phone.isEmpty) return phone ?? 'N/A'; return phone.length > 4 ? '...${phone.substring(phone.length - 4)}' : '****'; }
  Future<void> _toggleGlobalUnmask() async { if (_allCellsGloballyUnlocked) { setState(() => _allCellsGloballyUnlocked = false); } else { final confirmed = await _promptForPasswordAndReauthenticate(); if (confirmed) setState(() => _allCellsGloballyUnlocked = true); } }
  Future<bool> _promptForPasswordAndReauthenticate() async { final p = TextEditingController(); final u = _firebaseAuth.currentUser; if (u == null || u.email == null) return false; final c = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(title: const Text('Auth Required'), content: TextField(controller: p, obscureText: true, decoration: const InputDecoration(hintText: 'Password')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(child: const Text('Confirm'), onPressed: () async { try { await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: p.text.trim())); Navigator.pop(ctx, true); } catch (e) { Navigator.pop(ctx, false); } })])); return c ?? false; }

  // --- UI WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    final String reportTitle = _selectedFacilityName == null || _selectedFacilityName == 'All Facilities'
        ? 'State-Wide EAC Historical Report ($_userState)'
        : 'EAC Historical Report for $_selectedFacilityName';

    return Scaffold(
      appBar: AppBar(
        title: Text(reportTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_allCellsGloballyUnlocked ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            tooltip: _allCellsGloballyUnlocked ? 'Mask Data' : 'Unmask Data',
            onPressed: _toggleGlobalUnmask,
          ),
          if (_isExporting)
            const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined),
              tooltip: "Download Options",
              onSelected: (value) {
                if(value == 'csv_summary') _exportSummaryToCsv();
                if(value == 'csv_details') _exportDetailsToCsv();
                if(value == 'pdf_charts') _exportChartsToPdf();
              },
              enabled: !_isInitialState && !_isLoading && _allReports.isNotEmpty,
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'csv_summary',
                    child: ListTile(leading: Icon(Icons.summarize_outlined), title: Text("Export Summary (CSV)"))
                ),
                const PopupMenuItem(
                    value: 'csv_details',
                    child: ListTile(leading: Icon(Icons.table_rows_outlined), title: Text("Export Details (CSV)"))
                ),
                const PopupMenuItem(
                    value: 'pdf_charts',
                    child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text("Export Charts (PDF)"))
                ),
              ],
            )
        ],
      ),
      drawer: drawer2(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterBar(),

            // Show guidance text on initial load, but don't hide the report body.
            if (_isInitialState)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    "Please select filters and click 'Apply' to view the report.",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                  ),
                ),
              ),

            if (_errorMessage != null)
              Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),

            // The main body is now built immediately, showing 0s initially.
            // It gets hidden only during the loading phase.
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else
              _buildReportBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            if (_isFilterLoading) const Text("Loading filters...") else
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 250, maxWidth: 600),
                child: DropdownButtonFormField<String>(
                  value: _selectedFacilityName,
                  hint: const Text('Select Facility'),
                  decoration: const InputDecoration(labelText: 'Facility', border: OutlineInputBorder()),
                  items: _availableFacilities.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                  onChanged: (value) => setState(() => _selectedFacilityName = value),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text('${DateFormat.yMd().format(_startDate)} - ${DateFormat.yMd().format(_endDate)}'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply Filter'),
              onPressed: _isLoading ? null : _loadAndCalculateReports,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW REPORT BODY STRUCTURE ---
  Widget _buildReportBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOverallSummarySection(),
        const Divider(height: 40, thickness: 1),
        Text("Historical Trends", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _buildTrendChart('Repeat VL Turn-Around Time (TAT) Trend', [
          _createLineSeries(name: '≤ 3m', color: Colors.green, yValueMapper: (d, _) => d.tat.lessThan90Days),
          _createLineSeries(name: '3-5m', color: Colors.orange, yValueMapper: (d, _) => d.tat.between90and150Days),
          _createLineSeries(name: '> 5m', color: Colors.red, yValueMapper: (d, _) => d.tat.moreThan150Days),
        ], key: _tatTrendChartKey),
        const SizedBox(height: 24),
        _buildTrendChart('EAC Session Completion Trend', [
          _createLineSeries(name: '≥ 3 Sessions', color: Colors.blue, yValueMapper: (d, _) => d.eacSessions.withAtLeast3Sessions),
          _createLineSeries(name: '< 3 Sessions', color: Colors.purple, yValueMapper: (d, _) => d.eacSessions.without3Sessions),
        ], key: _sessionTrendChartKey),
        const Divider(height: 40, thickness: 1),
        Text("Detailed Breakdowns", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _buildFacilitySummaryTable(),
        const SizedBox(height: 24),
        _buildCallLogTable(),
      ],
    );
  }


  // BUILDS THE TOP SUMMARY SECTION WITH KPIs AND BAR CHARTS
  Widget _buildOverallSummarySection() {
    final totals = _totalAggregatedMetrics;

    // Data for TAT Chart
    final tatData = [
      _ChartData('≤ 3m', totals.tat.lessThan90Days, Colors.green),
      _ChartData('3-5m', totals.tat.between90and150Days, Colors.orange),
      _ChartData('> 5m', totals.tat.moreThan150Days, Colors.red),
    ];

    // Data for Session Chart
    final sessionData = [
      _ChartData('≥ 3 Sess.', totals.eacSessions.withAtLeast3Sessions, Colors.blue),
      _ChartData('< 3 Sess.', totals.eacSessions.without3Sessions, Colors.purple),
    ];

    // NEW: Data for Suppression Chart (calculated to be mutually exclusive)
    final int suppressed50to999 = totals.vlSummary.suppressedLessThan1000 - totals.vlSummary.suppressedLessThan50;
    final vlSuppressionData = [
      _ChartData('Unsupp. (≥1k)', totals.vlSummary.unsuppressed, Colors.red.shade600),
      _ChartData('Supp. (50-999)', suppressed50to999, Colors.orangeAccent.shade400),
      _ChartData('Supp. (<50)', totals.vlSummary.suppressedLessThan50, Colors.teal.shade500),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Overall Summary for Period", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16, runSpacing: 16,
          children: [
            _buildKpiCard("Total Clients on EAC", totals.vlSummary.totalUniqueClients),
            _buildKpiCard("Repeat VL w/ Result", totals.vlSummary.withRepeatVlResult, color: Colors.blue.shade700),
            _buildKpiCard("Unsuppressed (≥1k)", totals.vlSummary.unsuppressed, color: Colors.red.shade700),
            _buildKpiCard("Suppressed (<50)", totals.vlSummary.suppressedLessThan50, color: Colors.green.shade800),
          ],
        ),
        const SizedBox(height: 24),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 450,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5
          ),
          children: [
            _buildBarChart("Total TAT Distribution", tatData, key: _tatBarChartKey),
            _buildBarChart("Total Session Completion", sessionData, key: _sessionBarChartKey),
            // NEW: Add the suppression chart to the grid
            _buildBarChart("Repeat VL Suppression Status", vlSuppressionData, key: GlobalKey()), // Assign a key if you want to export it
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, int value, {Color? color}) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(String title, List<_ChartData> data, {Key? key}) {
    return Card(
      elevation: 4,
      child:

      RepaintBoundary(
        key: key,
        child: Container( // Wrap with container for clean PDF background
          color: Colors.white,
          padding: const EdgeInsets.all(12.0),
        child: SfCartesianChart(
          title: ChartTitle(text: title),
          primaryXAxis: CategoryAxis(),
          primaryYAxis: NumericAxis(minimum: 0, title: AxisTitle(text: "Count")),
          series: <CartesianSeries>[
            ColumnSeries<_ChartData, String>(
              dataSource: data.where((d) => d.value > 0).toList(),
              xValueMapper: (d, _) => d.category,
              yValueMapper: (d, _) => d.value,
              pointColorMapper: (d, _) => d.color,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            )
          ],
        ),
      ),),


    );
  }

  Widget _buildTrendChart(String title, List<LineSeries<DailyAggregatedEacMetrics, DateTime>> series, {Key? key}) {
    return Card(
      elevation: 4,
      child: RepaintBoundary(
        key: key,
        child: Container( // Wrap with container for clean PDF background
          color: Colors.white,
          padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: DateTimeAxis(edgeLabelPlacement: EdgeLabelPlacement.shift, dateFormat: DateFormat.MMMd()),
                primaryYAxis: NumericAxis(minimum: 0),
                legend: Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                tooltipBehavior: TooltipBehavior(enable: true, header: '', canShowMarker: false),
                series: series,
              ),
            ),
          ],
        ),),
      ),
    );
  }

  LineSeries<DailyAggregatedEacMetrics, DateTime> _createLineSeries({
    required String name, required Color color,
    required num Function(DailyAggregatedEacMetrics, int) yValueMapper,
  }) {
    return LineSeries<DailyAggregatedEacMetrics, DateTime>(
      dataSource: _dailyAggregatedMetrics,
      xValueMapper: (d, _) => d.date,
      yValueMapper: yValueMapper,
      name: name, color: color,
      markerSettings: const MarkerSettings(isVisible: true),
    );
  }

  Widget _buildFacilitySummaryTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Summary by Facility (Aggregated)", style: Theme.of(context).textTheme.headlineSmall),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Facility')), DataColumn(label: Text('Clients'), numeric: true),
                DataColumn(label: Text('TAT <3m'), numeric: true), DataColumn(label: Text('TAT 3-5m'), numeric: true),
                DataColumn(label: Text('TAT >5m'), numeric: true), DataColumn(label: Text('Sess. ≥3'), numeric: true),
                DataColumn(label: Text('Sess. <3'), numeric: true), DataColumn(label: Text('Rpt. VL'), numeric: true),
                DataColumn(label: Text('Rpt. VL w/ Result'), numeric: true), DataColumn(label: Text('Unsupp.'), numeric: true),
                DataColumn(label: Text('Supp. <1k'), numeric: true), DataColumn(label: Text('Supp. <50'), numeric: true),
              ],
              rows: _facilityAggregatedMetrics.values.map((agg) => DataRow(cells: [
                DataCell(Text(agg.name)),
                DataCell(Text(agg.vlSummary.totalUniqueClients.toString())),
                DataCell(Text(agg.tat.lessThan90Days.toString())),
                DataCell(Text(agg.tat.between90and150Days.toString())),
                DataCell(Text(agg.tat.moreThan150Days.toString())),
                DataCell(Text(agg.eacSessions.withAtLeast3Sessions.toString())),
                DataCell(Text(agg.eacSessions.without3Sessions.toString())),
                DataCell(Text(agg.vlSummary.withRepeatVl.toString())),
                DataCell(Text(agg.vlSummary.withRepeatVlResult.toString())),
                DataCell(Text(agg.vlSummary.unsuppressed.toString())),
                DataCell(Text(agg.vlSummary.suppressedLessThan1000.toString())),
                DataCell(Text(agg.vlSummary.suppressedLessThan50.toString())),
              ])).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallLogTable() {
    if (_allCallLogs.isEmpty) return const SizedBox.shrink();
    _allCallLogs.sort((a,b) => b.callDateTime.compareTo(a.callDateTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Call Log Details", style: Theme.of(context).textTheme.headlineSmall),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Facility')), DataColumn(label: Text('Date')),
                DataColumn(label: Text('Client Name')), DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Outcome')), DataColumn(label: Text('Duration')),
                DataColumn(label: Text('EAC Session')), DataColumn(label: Text('Tracker')),
                DataColumn(label: Text('Designation')), DataColumn(label: Text('Supervisor')),
              ],
              rows: _allCallLogs.map((log) => DataRow(cells: [
                DataCell(Text(log.trackerFacility ?? 'N/A')),
                DataCell(Text(DateFormat.yMd().add_jm().format(log.callDateTime))),
                DataCell(Text(_maskClientName(log.clientName))),
                DataCell(Text(_maskPhoneNumber(log.phoneNumber))),
                DataCell(Text(log.outcome ?? 'N/A')),
                DataCell(Text('${log.duration}s')),
                DataCell(Text(log.eacSessionType ?? 'N/A')),
                DataCell(Text(log.trackedBy ?? 'N/A')),
                DataCell(Text(log.designation ?? 'N/A')),
                DataCell(Text(log.supervisorName ?? 'N/A')),
              ])).toList(),
            ),
          ),
        ),
      ],
    );
  }
}