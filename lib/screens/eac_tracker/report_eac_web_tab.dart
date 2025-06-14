// REWRITTEN FOR FLUTTER WEB
// This file is designed for trend analysis of historical EAC reports.
// It fetches multiple report documents from Firestore and plots them over time.

import 'dart:convert' show utf8;
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pwpd;


import '../../widgets/drawer.dart'; // Assuming you have a drawer widget

// --- DATA MODELS TO MATCH FIRESTORE STRUCTURE ---

class EacReportModel {
  final String id; // The document ID, which is the date string "yyyy-MM-dd"
  final DateTime reportDate;
  final String trackerName;
  final int totalUniqueClients;
  final TatSummary tat;
  final EacSessionSummary eacSessions;
  final VlSummary vlSummary;

  EacReportModel({
    required this.id,
    required this.reportDate,
    required this.trackerName,
    required this.totalUniqueClients,
    required this.tat,
    required this.eacSessions,
    required this.vlSummary,
  });

  factory EacReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final tatData = data['tat'] as Map<String, dynamic>? ?? {};
    final eacData = data['eacSessions'] as Map<String, dynamic>? ?? {};
    final vlData = data['vlSummary'] as Map<String, dynamic>? ?? {};

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(doc.id);
    } catch (e) {
      parsedDate = (data['lastUpdated'] as Timestamp? ?? Timestamp.now()).toDate();
    }

    return EacReportModel(
      id: doc.id,
      reportDate: parsedDate,
      trackerName: data['trackerName'] as String? ?? 'N/A',
      totalUniqueClients: data['totalUniqueClients'] as int? ?? 0,
      tat: TatSummary.fromMap(tatData),
      eacSessions: EacSessionSummary.fromMap(eacData),
      vlSummary: VlSummary.fromMap(vlData),
    );
  }
}

class TatSummary {
  final int lessThan90Days;
  final int between90and150Days;
  final int moreThan150Days;
  TatSummary({this.lessThan90Days = 0, this.between90and150Days = 0, this.moreThan150Days = 0});
  factory TatSummary.fromMap(Map<String, dynamic> map) => TatSummary(
    lessThan90Days: map['lessThan90Days'] as int? ?? 0,
    between90and150Days: map['between90and150Days'] as int? ?? 0,
    moreThan150Days: map['moreThan150Days'] as int? ?? 0,
  );
}

class EacSessionSummary {
  final int withAtLeast3Sessions;
  final int without3Sessions;
  EacSessionSummary({this.withAtLeast3Sessions = 0, this.without3Sessions = 0});
  factory EacSessionSummary.fromMap(Map<String, dynamic> map) => EacSessionSummary(
    withAtLeast3Sessions: map['withAtLeast3Sessions'] as int? ?? 0,
    without3Sessions: map['without3Sessions'] as int? ?? 0,
  );
}

class VlSummary {
  final int withRepeatVl;
  final int withRepeatVlResult;
  final int suppressedLessThan1000;
  final int suppressedLessThan50;
  final int unsuppressed;
  VlSummary({this.withRepeatVl = 0, this.withRepeatVlResult = 0, this.suppressedLessThan1000 = 0, this.suppressedLessThan50 = 0, this.unsuppressed = 0});
  factory VlSummary.fromMap(Map<String, dynamic> map) => VlSummary(
    withRepeatVl: map['withRepeatVl'] as int? ?? 0,
    withRepeatVlResult: map['withRepeatVlResult'] as int? ?? 0,
    suppressedLessThan1000: map['suppressedLessThan1000'] as int? ?? 0,
    suppressedLessThan50: map['suppressedLessThan50'] as int? ?? 0,
    unsuppressed: map['unsuppressed'] as int? ?? 0,
  );
}

class EacCallLogModel {
  final String? clientName;
  final String? artId;
  final String? phoneNumber;
  final String? eacSessionType;
  final DateTime callDateTime;
  final String? outcome;
  final int duration;
  final String? trackedBy;

  EacCallLogModel({
    this.clientName,
    this.artId,
    this.phoneNumber,
    this.eacSessionType,
    required this.callDateTime,
    this.outcome,
    required this.duration,
    this.trackedBy,
  });

  factory EacCallLogModel.fromFirestore(Map<String, dynamic> data) {
    return EacCallLogModel(
      clientName: data['clientName'] as String?,
      artId: data['artId'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      eacSessionType: data['eacSessionType'] as String?,
      callDateTime: (data['dateTracked'] as Timestamp? ?? Timestamp.now()).toDate(),
      outcome: data['trackingOutcome'] as String?,
      duration: data['callDuration'] as int? ?? 0,
      trackedBy: data['trackedBy'] as String?,
    );
  }
}

// NEW: Helper class for Pie Chart data
class _PieChartData {
  final String category;
  final int value;
  final Color color;
  _PieChartData(this.category, this.value, this.color);
}

// --- MAIN WIDGET ---

class ReportEacWebTab extends StatefulWidget {
  const ReportEacWebTab({super.key});

  @override
  _ReportEacWebTabState createState() => _ReportEacWebTabState();
}

class _ReportEacWebTabState extends State<ReportEacWebTab> {
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  String? _trackerState;
  String? _trackerFacilityLocation;

  List<EacReportModel> _allReports = [];
  List<EacCallLogModel> _allCallLogs = [];
  EacReportModel? get _latestReport => _allReports.isNotEmpty ? _allReports.last : null;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _endDate = DateTime.now();
  // --- New State Variable for PII Masking ---
  bool _allCellsGloballyUnlocked = false;

  // Services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // NEW: GlobalKeys for capturing charts for PDF
  final GlobalKey _tatTrendChartKey = GlobalKey();
  final GlobalKey _eacSessionTrendChartKey = GlobalKey();
  final GlobalKey _vlSuppressionTrendChartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeAndFetchData();
  }

  // --- New Helper Methods for PII Masking ---
  String _maskClientName(String? name) {
    if (_allCellsGloballyUnlocked || name == null || name.isEmpty) return name ?? 'N/A';
    List<String> parts = name.split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? '${parts[0][0]}. (Hidden)' : 'Hidden';
  }

  String _maskPhoneNumber(String? phone) {
    if (_allCellsGloballyUnlocked || phone == null || phone.isEmpty) return phone ?? 'N/A';
    return phone.length > 4 ? '...${phone.substring(phone.length - 4)}' : '****';
  }

  Future<void> _toggleGlobalUnmask() async {
    if (_allCellsGloballyUnlocked) {
      if (mounted) setState(() => _allCellsGloballyUnlocked = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All sensitive data re-masked.')));
    } else {
      final bool isAuthenticated = await _promptForPasswordAndReauthenticate();
      if (isAuthenticated) {
        if (mounted) setState(() => _allCellsGloballyUnlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All sensitive data has been unmasked.')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication failed. Data remains masked.')));
      }
    }
  }

  Future<bool> _promptForPasswordAndReauthenticate() async {
    final passwordController = TextEditingController();
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not signed in or email is not available.")));
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Authentication Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Please enter your password to unmask sensitive data."),
              const SizedBox(height: 10),
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
              child: const Text('Confirm & Unmask'),
              onPressed: () async {
                if (passwordController.text.trim().isEmpty) return;
                try {
                  final credential = EmailAuthProvider.credential(email: user.email!, password: passwordController.text.trim());
                  await user.reauthenticateWithCredential(credential);
                  Navigator.pop(context, true); // Success
                } catch (e) {
                  Navigator.pop(context, false); // Failure
                }
              },
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _initializeAndFetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _loadFirebaseUserDetails();
      if (_trackerState != null && _trackerFacilityLocation != null) {
        await _fetchEacReports();
      } else {
        throw Exception("User's State or Facility is not configured.");
      }
    } catch (e, stack) {
      debugPrint("Error initializing EAC report: $e\n$stack");
      setState(() => _errorMessage = "Failed to load report data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFirebaseUserDetails() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception("User not logged in.");

    final docSnapshot = await _firestore.collection('Staff').doc(user.uid).get();
    if (docSnapshot.exists && docSnapshot.data() != null) {
      final data = docSnapshot.data()!;
      setState(() {
        _trackerState = data['state'] as String?;
        _trackerFacilityLocation = data['location'] as String?;
      });
    } else {
      throw Exception("User profile not found in 'Staff' collection.");
    }
  }

  Future<void> _fetchEacReports() async {
    if (_trackerState == null || _trackerFacilityLocation == null) return;

    if (mounted) setState(() => _isLoading = true);

    final reportsCollection = _firestore
        .collection('EAC_Reports')
        .doc(_trackerState!)
        .collection(_trackerFacilityLocation!);

    final querySnapshot = await reportsCollection
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(_startDate))
        .where(FieldPath.documentId, isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(_endDate))
        .orderBy(FieldPath.documentId)
        .get();

    final fetchedReports = querySnapshot.docs.map((doc) => EacReportModel.fromFirestore(doc)).toList();

    List<EacCallLogModel> fetchedCallLogs = [];
    if(fetchedReports.isNotEmpty) {
      final futures = fetchedReports.map((report) {
        return reportsCollection.doc(report.id).collection('callLogs').get();
      }).toList();

      final logSnapshots = await Future.wait(futures);
      for(final logSnapshot in logSnapshots) {
        for(final doc in logSnapshot.docs) {
          fetchedCallLogs.add(EacCallLogModel.fromFirestore(doc.data()));
        }
      }
    }
    if (mounted) {
      setState(() {
        _allReports = fetchedReports;
        _allCallLogs = fetchedCallLogs..sort((a, b) => b.callDateTime.compareTo(a.callDateTime));
        _isLoading = false;
      });
    }
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: SizedBox(
          width: 350,
          height: 350,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: PickerDateRange(_startDate, _endDate),
            maxDate: DateTime.now(),
            showActionButtons: true,
            onSubmit: (Object? value) {
              if (value is PickerDateRange) {
                if (mounted) {
                  setState(() {
                    _startDate = value.startDate ?? _startDate;
                    _endDate = value.endDate ?? value.startDate ?? _endDate;
                  });
                }
                Navigator.pop(context);
                _fetchEacReports();
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  // --- EXPORT FUNCTIONS ---

  Future<void> _exportToCsv() async {
    if (_allReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to export.")));
      return;
    }
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(milliseconds: 100)); // Allow UI to update

    List<List<dynamic>> rows = [
      ['EAC Report Summary Export'],
      ['Facility', _trackerFacilityLocation],
      ['Date Range', '${DateFormat.yMd().format(_startDate)} - ${DateFormat.yMd().format(_endDate)}'],
      [],
      [
        'Report Date', 'Total Clients', 'TAT <90d', 'TAT 90-150d', 'TAT >150d',
        'Sessions >=3', 'Sessions <3', 'Repeat VL', 'Repeat VL w/ Result',
        'Unsuppressed', 'Suppressed <1k', 'Suppressed <50',
      ],
      ..._allReports.map((r) => [
        DateFormat('yyyy-MM-dd').format(r.reportDate),
        r.totalUniqueClients, r.tat.lessThan90Days, r.tat.between90and150Days, r.tat.moreThan150Days,
        r.eacSessions.withAtLeast3Sessions, r.eacSessions.without3Sessions,
        r.vlSummary.withRepeatVl, r.vlSummary.withRepeatVlResult, r.vlSummary.unsuppressed,
        r.vlSummary.suppressedLessThan1000, r.vlSummary.suppressedLessThan50,
      ])
    ];

    String csvData = const ListToCsvConverter().convert(rows);
    _triggerDownload(utf8.encode(csvData), 'eac_trend_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv', 'text/csv');
    setState(() => _isExporting = false);
  }

  Future<void> _exportToPdf() async {
    if (_allReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No chart data to export.")));
      return;
    }
    setState(() => _isExporting = true);

    try {
      final tatChartBytes = await _captureChartPng(_tatTrendChartKey);
      final eacChartBytes = await _captureChartPng(_eacSessionTrendChartKey);
      final vlChartBytes = await _captureChartPng(_vlSuppressionTrendChartKey);

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: pwpd.PdfPageFormat.a4.landscape,
        header: (context) => pw.Header(text: "EAC Trend Analysis Report"),
        build: (context) => [
          pw.Text("Facility: $_trackerFacilityLocation", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("Date Range: ${DateFormat.yMd().format(_startDate)} to ${DateFormat.yMd().format(_endDate)}"),
          pw.Divider(),
          pw.SizedBox(height: 20),
          if (tatChartBytes != null) ..._buildPdfChartSection("Repeat VL Turn-Around Time (TAT) Trend", tatChartBytes),
          if (eacChartBytes != null) ..._buildPdfChartSection("EAC Session Completion Trend", eacChartBytes),
          if (vlChartBytes != null) ..._buildPdfChartSection("Repeat Viral Load Suppression Trend", vlChartBytes),
        ],
      ));

      final pdfBytes = await pdf.save();
      _triggerDownload(pdfBytes, 'eac_charts_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf', 'application/pdf');

    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  List<pw.Widget> _buildPdfChartSection(String title, Uint8List imageBytes) {
    return [
      pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain, height: 250),
      pw.SizedBox(height: 30),
    ];
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

  void _triggerDownload(List<int> bytes, String filename, String mimeType) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EAC Trend Analysis",style: TextStyle(color: Colors.white,),),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
          icon: Icon(_allCellsGloballyUnlocked ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          tooltip: _allCellsGloballyUnlocked ? 'Mask All Data' : 'Unmask All Data',
          onPressed: _toggleGlobalUnmask,
        ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.date_range),
            label: Text('${DateFormat.yMd().format(_startDate)} - ${DateFormat.yMd().format(_endDate)}'),
            onPressed: _showDateRangePicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Data",
            onPressed: _initializeAndFetchData,
          ),
          if (_isExporting)
            const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined, color: Colors.white),
              tooltip: "Download Options",
              onSelected: (value) {
                if(value == 'csv') _exportToCsv();
                if(value == 'pdf') _exportToPdf();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.table_chart_outlined), title: Text("Export Data (CSV)"))),
                const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text("Export Charts (PDF)"))),
              ],
            )
        ],
      ),
      drawer: drawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)))
          : _allReports.isEmpty
          ? const Center(child: Text("No EAC reports found for the selected date range.", style: TextStyle(fontSize: 16)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildKpiSection(),
            const SizedBox(height: 24),
            _buildTrendChart(
              key: _tatTrendChartKey,
              title: 'Repeat VL Turn-Around Time (TAT) Trend',
              series: [
                _createLineSeries(name: '≤ 3 Months', color: Colors.green, yValueMapper: (r, _) => r.tat.lessThan90Days.toDouble()),
                _createLineSeries(name: '3-5 Months', color: Colors.orange, yValueMapper: (r, _) => r.tat.between90and150Days.toDouble()),
                _createLineSeries(name: '> 5 Months', color: Colors.red, yValueMapper: (r, _) => r.tat.moreThan150Days.toDouble()),
              ],
            ),
            const SizedBox(height: 24),
            _buildTrendChart(
              key: _eacSessionTrendChartKey,
              title: 'EAC Session Completion Trend',
              series: [
                _createLineSeries(name: '≥ 3 Sessions', color: Colors.blue, yValueMapper: (r, _) => r.eacSessions.withAtLeast3Sessions.toDouble()),
                _createLineSeries(name: '< 3 Sessions', color: Colors.purple, yValueMapper: (r, _) => r.eacSessions.without3Sessions.toDouble()),
              ],
            ),
            const SizedBox(height: 24),
            _buildTrendChart(
                key: _vlSuppressionTrendChartKey,
                title: 'Repeat Viral Load Suppression Trend',
                series: [
                  _createLineSeries(name: 'Unsuppressed (≥1k)', color: Colors.red, yValueMapper: (r, _) => r.vlSummary.unsuppressed.toDouble()),
                  _createLineSeries(name: 'Suppressed (<1k)', color: Colors.green, yValueMapper: (r, _) => r.vlSummary.suppressedLessThan1000.toDouble()),
                  _createLineSeries(name: 'Suppressed (<50)', color: Colors.teal, yValueMapper: (r, _) => r.vlSummary.suppressedLessThan50.toDouble()),
                ],
                subtitle: 'Of clients with a repeat VL result'
            ),
            const SizedBox(height: 24),
            Text("Raw Report Data", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            _buildDataTable(),
            const SizedBox(height: 24),
            Text("Recent Call Logs", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            // WITH THIS:
            _buildCallLogSection(),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDER METHODS ---
  Widget _buildKpiSection() {
    final report = _latestReport;
    if (report == null) return const SizedBox.shrink();

    // --- Data for Pie Charts ---

    // 1. TAT Data
    final tatData = [
      _PieChartData('≤ 3m', report.tat.lessThan90Days, Colors.green),
      _PieChartData('3-5m', report.tat.between90and150Days, Colors.orange),
      _PieChartData('> 5m', report.tat.moreThan150Days, Colors.red),
    ];

    // 2. Session Data
    final sessionData = [
      _PieChartData('≥ 3 Sessions', report.eacSessions.withAtLeast3Sessions, Colors.blue),
      _PieChartData('< 3 Sessions', report.eacSessions.without3Sessions, Colors.purple),
    ];

    // NEW: 3. VL Suppression Data (Calculated to prevent double-counting)
    final int suppressed50to999 = report.vlSummary.suppressedLessThan1000 - report.vlSummary.suppressedLessThan50;
    final vlSuppressionData = [
      _PieChartData('Unsuppressed (≥1k)', report.vlSummary.unsuppressed, Colors.red.shade600),
      _PieChartData('Suppressed (50-999)', suppressed50to999 < 0 ? 0 : suppressed50to999, Colors.orangeAccent.shade400),
      _PieChartData('Suppressed (<50)', report.vlSummary.suppressedLessThan50, Colors.teal.shade500),
    ];

    // Create a list of pie chart widgets to display
    final List<Widget> pieCharts = [];
    if (tatData.any((d) => d.value > 0)) {
      pieCharts.add(_buildPieChartCard("Latest TAT Distribution", tatData));
    }
    if (sessionData.any((d) => d.value > 0)) {
      pieCharts.add(_buildPieChartCard("Latest Session Completion", sessionData));
    }
    // NEW: Add the VL suppression chart to the list
    if (vlSuppressionData.any((d) => d.value > 0)) {
      pieCharts.add(_buildPieChartCard("Repeat VL Suppression Status", vlSuppressionData));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Latest Report Snapshot (${DateFormat.yMMMMd().format(report.reportDate)})", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        // --- Section for KPI Cards ---
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildKpiCard('Total Clients on EAC', report.totalUniqueClients.toString()),
            _buildKpiCard('Repeat VL w/ Result', report.vlSummary.withRepeatVlResult.toString(), color: Colors.blue.shade700),
            _buildKpiCard('Unsuppressed (≥1k)', report.vlSummary.unsuppressed.toString(), color: Colors.red.shade700),
            _buildKpiCard('Suppressed (<50)', report.vlSummary.suppressedLessThan50.toString(), color: Colors.green.shade800),
          ],
        ),

        // --- Section for Pie Charts in a GridView ---
        if (pieCharts.isNotEmpty) ...[
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pieCharts.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 350,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 300 / 300,
            ),
            itemBuilder: (context, index) {
              return pieCharts[index];
            },
          ),
        ]
      ],
    );
  }

  Widget _buildPieChartCard(String title, List<_PieChartData> data) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        width: 300,
        height: 250,
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Expanded(
              child: SfCircularChart(
                legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                series: <CircularSeries<_PieChartData, String>>[
                  PieSeries<_PieChartData, String>(
                    dataSource: data.where((d) => d.value > 0).toList(),
                    xValueMapper: (d, _) => d.category,
                    yValueMapper: (d, _) => d.value,
                    pointColorMapper: (d, _) => d.color,
                    dataLabelMapper: (d, _) => d.value.toString(),
                    dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, {Color? color}) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 220,
        height: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart({required Key key, required String title, String? subtitle, required List<CartesianSeries<EacReportModel, DateTime>> series}) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            RepaintBoundary(
              key: key,
              child: Container(
                color: Colors.white, // Important for clean capture
                padding: const EdgeInsets.only(top: 8, right: 8),
                height: 300,
                child: SfCartesianChart(
                  primaryXAxis: DateTimeAxis(
                    edgeLabelPlacement: EdgeLabelPlacement.shift,
                    dateFormat: DateFormat.MMMd(),
                    intervalType: DateTimeIntervalType.auto,
                  ),
                  primaryYAxis: NumericAxis(
                    minimum: 0,
                    majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5,5]),
                  ),
                  legend: Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                  tooltipBehavior: TooltipBehavior(enable: true, header: '', canShowMarker: false),
                  series: series,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineSeries<EacReportModel, DateTime> _createLineSeries({
    required String name,
    required Color color,
    required num Function(EacReportModel, int) yValueMapper,
  }) {
    // Check if there are few data points to make markers more visible
    final bool isSparseData = _allReports.length <= 2;

    return LineSeries<EacReportModel, DateTime>(
      dataSource: _allReports,
      xValueMapper: (EacReportModel report, _) => report.reportDate,
      yValueMapper: yValueMapper,
      name: name,
      color: color,
      // MODIFIED: Markers are now larger and more prominent for sparse data
      markerSettings: MarkerSettings(
        isVisible: true,
        height: isSparseData ? 8 : 4,
        width: isSparseData ? 8 : 4,
        shape: DataMarkerType.circle,
        borderWidth: isSparseData ? 2 : 1,
        borderColor: color,
      ),
    );
  }


  Widget _buildDataTable() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateColor.resolveWith((states) => Colors.blueGrey.shade50),
          sortAscending: true,
          sortColumnIndex: 0,
          columns: const [
            DataColumn(label: Text('Date'), numeric: true),
            DataColumn(label: Text('Clients'), numeric: true),
            DataColumn(label: Text('TAT <3m'), numeric: true),
            DataColumn(label: Text('TAT 3-5m'), numeric: true),
            DataColumn(label: Text('TAT >5m'), numeric: true),
            DataColumn(label: Text('Repeat VL'), numeric: true),
            DataColumn(label: Text('VL w/ Result'), numeric: true),
            DataColumn(label: Text('Unsupp.'), numeric: true),
            DataColumn(label: Text('Supp. <1k'), numeric: true),
            DataColumn(label: Text('Supp. <50'), numeric: true),
          ],
          rows: _allReports.map((report) => DataRow(
              cells: [
                DataCell(Text(DateFormat('yyyy-MM-dd').format(report.reportDate))),
                DataCell(Text(report.totalUniqueClients.toString())),
                DataCell(Text(report.tat.lessThan90Days.toString())),
                DataCell(Text(report.tat.between90and150Days.toString())),
                DataCell(Text(report.tat.moreThan150Days.toString())),
                DataCell(Text(report.vlSummary.withRepeatVl.toString())),
                DataCell(Text(report.vlSummary.withRepeatVlResult.toString())),
                DataCell(Text(report.vlSummary.unsuppressed.toString())),
                DataCell(Text(report.vlSummary.suppressedLessThan1000.toString())),
                DataCell(Text(report.vlSummary.suppressedLessThan50.toString())),
              ]
          )).toList(),
        ),
      ),
    );
  }

  // NEW: Helper to group logs by date
  Map<String, List<EacCallLogModel>> _groupCallLogsByDate() {
    final Map<String, List<EacCallLogModel>> dailyLogs = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');

    for (var log in _allCallLogs) {
      final dateKey = dateKeyFormat.format(log.callDateTime);
      dailyLogs.putIfAbsent(dateKey, () => []).add(log);
    }
    return dailyLogs;
  }

  // REPLACEMENT for _buildCallLogTable
  Widget _buildCallLogSection() {
    if (_allCallLogs.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No call logs found in this date range.')));
    }

    final groupedLogs = _groupCallLogsByDate();
    final sortedDates = groupedLogs.keys.toList()..sort((a,b) => b.compareTo(a)); // Sort descending

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("EAC Call Tracking Logs", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final dateKey = sortedDates[index];
            final dailyLogs = groupedLogs[dateKey]!;
            final displayDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(dateKey));

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ExpansionTile(
                key: PageStorageKey<String>(dateKey),
                title: Text('$displayDate (${dailyLogs.length} calls)', style: const TextStyle(fontWeight: FontWeight.w600)),
                initiallyExpanded: index == 0, // Expand the most recent day by default
                children: dailyLogs.map((log) {
                  final isAnswered = log.outcome?.toLowerCase() == 'answered';
                  return ListTile(
                    leading: Icon(
                      isAnswered ? Icons.call_received : Icons.call_missed_outgoing,
                      color: isAnswered ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    title: Text(_maskClientName(log.clientName), style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phone: ${_maskPhoneNumber(log.phoneNumber)} | ART ID: ${log.artId ?? 'N/A'}'),
                        if(log.eacSessionType != null)
                          Text('EAC Session: ${log.eacSessionType}'),
                        Text('Status: ${log.outcome ?? 'N/A'} | Duration: ${log.duration}s'),
                        if (log.trackedBy != null)
                          Text('Tracker: ${log.trackedBy}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                      ],
                    ),
                    isThreeLine: true,
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}