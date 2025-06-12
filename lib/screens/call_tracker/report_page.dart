import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// Web-specific imports for downloads and rendering
import 'dart:html' as html;
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

// Imports for file generation
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/contact_tracked.dart';

class ReportsPageWeb extends StatefulWidget {
  const ReportsPageWeb({super.key});

  @override
  _ReportsPageWebState createState() => _ReportsPageWebState();
}

class _ReportsPageWebState extends State<ReportsPageWeb> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ContactTracked> trackedContacts = [];
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = true; // Start loading initially
  bool _isUserBioLoading = true;
  String? _errorMessage;

  // --- NEW: Masking and Export State ---
  bool _allCellsGloballyUnlocked = false;
  final GlobalKey _callStatusChartKey = GlobalKey();
  final GlobalKey _artStatusChartKey = GlobalKey();
  final GlobalKey _durationTrendChartKey = GlobalKey();
  final GlobalKey _updateTrendsChartKey = GlobalKey();

  // User Bio Details
  String? currentUserAuthId;
  String? userFirstName;
  String? userLastName;
  String? userDesignation;
  String? userLocation;
  String? userState;
  String? userSupervisor;
  String? userSupervisorEmail;

  // Chart Data Holders
  List<MapEntry<String, int>> callStatusChartData = [];
  List<_ChartDataPoint> callDurationTrendData = [];
  List<_UpdateChartData> updateMetricsData = [];
  List<MapEntry<String, int>> artStatusChartData = [];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _loadCurrentUserBio();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day - 6);
    endDate = DateTime(now.year, now.month, now.day);
    if (mounted && !_isUserBioLoading && _errorMessage == null) {
      await _loadContacts(start: startDate, end: endDate);
    }
  }

  Future<void> _loadCurrentUserBio() async {
    setState(() {
      _isUserBioLoading = true;
      _errorMessage = null;
    });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      currentUserAuthId = user.uid;

      final docSnapshot =
      await _firestore.collection('Staff').doc(currentUserAuthId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        setState(() {
          userFirstName = data['firstName'] as String?;
          userLastName = data['lastName'] as String?;
          userDesignation = data['designation'] as String?;
          userLocation = data['location'] as String?;
          userState = data['state'] as String?;
          userSupervisor = data['supervisor'] as String?;
          userSupervisorEmail = data['supervisorEmail'] as String?;
          _isUserBioLoading = false;
        });
      } else {
        throw Exception(
            "User bio data not found in Firestore 'Staff' collection.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error loading user details: $e";
          _isUserBioLoading = false;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadContacts({DateTime? start, DateTime? end}) async {
    if (_isUserBioLoading ||
        currentUserAuthId == null ||
        userState == null ||
        userLocation == null) {
      if (mounted && !_isUserBioLoading) {
        setState(() {
          isLoading = false;
          _errorMessage = _errorMessage ??
              "Cannot load reports: User details (State/Facility) missing.";
          trackedContacts = [];
          _prepareChartData();
        });
      }
      return;
    }
    if (start == null || end == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
          trackedContacts = [];
          _prepareChartData();
          _errorMessage = "Please select a date range to load reports.";
        });
      }
      return;
    }

    setState(() {
      isLoading = true;
      _errorMessage = null;
      trackedContacts = [];
    });

    List<ContactTracked> fetchedContacts = [];
    DateTime currentDate = start;
    final DateFormat pathDateFormat = DateFormat('dd-MMM-yyyy');

    try {
      while (currentDate.isBefore(end.add(const Duration(days: 1)))) {
        String formattedDate = pathDateFormat.format(currentDate);
        String dailyUserCollectionPath =
            '/Reports/$userState/$userLocation/$formattedDate/$currentUserAuthId';

        try {
          QuerySnapshot dailySnapshot =
          await _firestore.collection(dailyUserCollectionPath).get();
          for (var doc in dailySnapshot.docs) {
            if (doc.exists && doc.data() != null) {
              fetchedContacts.add(ContactTracked.fromFirestore(
                  doc.data() as Map<String, dynamic>, doc.id));
            }
          }
        } catch (dailyError) {
          // It's common for a path not to exist on a day with no calls.
          // We can silently ignore these errors.
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      if (mounted) {
        setState(() {
          trackedContacts = fetchedContacts;
          _prepareChartData();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          _errorMessage = "Error loading reports: $e";
          trackedContacts = [];
          _prepareChartData();
        });
      }
    }
  }

  // --- NEW: Masking, Export, and Helper Functions ---

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : null,
    ));
  }

  String _maskName(String? name) {
    if (name == null || name.isEmpty) return 'N/A';
    return '${name.substring(0, 1)}. (hidden)';
  }

  String _maskPhoneNumber(String? number) {
    if (number == null || number.length < 4) return '••••';
    return '...${number.substring(number.length - 4)}';
  }

  Future<void> _toggleGlobalUnmask() async {
    if (_allCellsGloballyUnlocked) {
      setState(() => _allCellsGloballyUnlocked = false);
      _showSnackBar('All sensitive data has been masked.');
      return;
    }

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      _showSnackBar('Could not verify user. Please log in again.',
          isError: true);
      return;
    }

    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify to Unmask Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Please enter your password for ${user.email} to view sensitive client information.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: const Text('Unlock'),
            onPressed: () async {
              if (passwordController.text.isEmpty) return;
              try {
                final cred = EmailAuthProvider.credential(
                    email: user.email!, password: passwordController.text);
                await user.reauthenticateWithCredential(cred);
                Navigator.pop(context, true); // Success
              } on FirebaseAuthException catch (e) {
                Navigator.pop(context, false); // Close dialog first
                _showSnackBar('Verification failed: ${e.message}',
                    isError: true);
              } catch (e) {
                Navigator.pop(context, false);
                _showSnackBar('An unexpected error occurred: $e',
                    isError: true);
              }
            },
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _allCellsGloballyUnlocked = true);
      _showSnackBar('Verification successful. Data is now visible.');
    }
  }

  Future<void> _exportToCSV() async {
    List<List<String>> rows = [];
    rows.add([
      'Client ID', 'Client Name', 'Client Phone', 'ART Status',
      'Facility', 'State', 'ART ID', 'DatimCode', 'Date Tracked',
      'Time Tracked', 'Call Status', 'Call Duration', 'Tracked By',
      'Designation', 'Tracker Facility', 'Supervisor', 'Supervisor Email'
    ]);

    for (var contact in trackedContacts) {
      rows.add([
        contact.uniqueID ?? '', contact.name ?? '', contact.phoneNumber ?? '',
        contact.artStatus ?? '', contact.facilityName ?? '', contact.state ?? '',
        contact.uniqueID ?? '', contact.datimCode ?? '',
        contact.dateTracked != null ? DateFormat('yyyy-MM-dd').format(contact.dateTracked!) : '',
        contact.dateTracked != null ? DateFormat('HH:mm').format(contact.dateTracked!) : '',
        contact.callStatus ?? '',
        contact.callDuration != null ? formatDuration(contact.callDuration!) : '',
        contact.trackedBy ?? '', contact.designation ?? '',
        contact.trackerFacilityLocation ?? '', contact.supervisorName ?? '',
        contact.supervisorEmail ?? '',
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "tracking_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
    _showSnackBar('CSV export has started.');
  }

  Future<void> _exportToPDF() async {
    Future<pw.Widget?> captureChart(GlobalKey key, String title) async {
      try {
        if (key.currentContext == null) return null;
        RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return null;
        return pw.Column(children: [
          pw.Text(title,
              style:
              pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Image(pw.MemoryImage(byteData.buffer.asUint8List()),
              fit: pw.BoxFit.contain, width: 400),
          pw.SizedBox(height: 25),
        ]);
      } catch (e) {
        return null;
      }
    }

    final pdf = pw.Document();
    final List<pw.Widget> chartWidgets = [];

    final chartsToCapture = {
      if (callStatusChartData.isNotEmpty) _callStatusChartKey: 'Call Status Distribution',
      if (artStatusChartData.isNotEmpty) _artStatusChartKey: 'ART Status Distribution',
      if (callDurationTrendData.isNotEmpty) _durationTrendChartKey: 'Average Call Duration Trend',
      if (updateMetricsData.isNotEmpty) _updateTrendsChartKey: 'Monthly Update Trends',
    };

    for (var entry in chartsToCapture.entries) {
      final chartWidget = await captureChart(entry.key, entry.value);
      if (chartWidget != null) chartWidgets.add(chartWidget);
    }

    if (chartWidgets.isEmpty) {
      _showSnackBar('No charts available to export.', isError: true);
      return;
    }

    pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4, build: (context) => chartWidgets));

    final bytes = await pdf.save();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "charts_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf")
      ..click();
    html.Url.revokeObjectUrl(url);
    _showSnackBar('PDF export has started.');
  }

  // --- Chart and Helper Functions (mostly unchanged) ---

  void _prepareChartData() {
    callStatusChartData = _getCallStatusData();
    callDurationTrendData = _getCallDurationTrendData();
    updateMetricsData = _getUpdateMetricsData();
    artStatusChartData = _getArtStatusData();
  }

  List<MapEntry<String, int>> _getCallStatusData() {
    Map<String, int> statusCounts = {};
    for (var c in trackedContacts) {
      String s = c.callStatus?.trim() ?? 'N/A';
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }
    return statusCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  List<MapEntry<String, int>> _getArtStatusData() {
    Map<String, int> statusCounts = {};
    for (var c in trackedContacts) {
      String s = c.artStatus?.trim() ?? 'Unknown';
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }
    return statusCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  List<_ChartDataPoint> _getCallDurationTrendData() {
    Map<String, List<int>> dailyDurations = {};
    final DateFormat keyFmt = DateFormat('yyyy-MM-dd');
    for (var c in trackedContacts) {
      if (c.dateTracked != null && c.callDuration != null && c.callDuration! > 0) {
        String key = keyFmt.format(c.dateTracked!);
        dailyDurations.putIfAbsent(key, () => []).add(c.callDuration!);
      }
    }
    List<_ChartDataPoint> data = [];
    dailyDurations.forEach((date, durations) {
      double avg = durations.reduce((a, b) => a + b) / durations.length;
      data.add(_ChartDataPoint(date, avg));
    });
    data.sort((a, b) => a.x.compareTo(b.x));
    return data;
  }

  List<_UpdateChartData> _getUpdateMetricsData() {
    Map<String, int> phoneUpd = {};
    Map<String, int> addrUpd = {};
    Map<String, int> visitUpd = {};
    final DateFormat keyFmt = DateFormat('yyyy-MM');
    for (var c in trackedContacts) {
      if (c.datePhoneNumberUpdated != null) {
        String key = keyFmt.format(c.datePhoneNumberUpdated!);
        phoneUpd[key] = (phoneUpd[key] ?? 0) + 1;
      }
      if (c.dateAddressChanged != null) {
        String key = keyFmt.format(c.dateAddressChanged!);
        addrUpd[key] = (addrUpd[key] ?? 0) + 1;
      }
      if (c.dateNextVisitChanged != null) {
        String key = keyFmt.format(c.dateNextVisitChanged!);
        visitUpd[key] = (visitUpd[key] ?? 0) + 1;
      }
    }
    Set<String> allMonths = {...phoneUpd.keys, ...addrUpd.keys, ...visitUpd.keys};
    List<String> sortedMonths = allMonths.toList()..sort();
    return sortedMonths
        .map((m) => _UpdateChartData(m, phoneUpd[m] ?? 0, addrUpd[m] ?? 0, visitUpd[m] ?? 0))
        .toList();
  }

  String formatDuration(int totalSeconds) {
    final d = Duration(seconds: totalSeconds);
    return d.toString().split('.').first.padLeft(8, "0");
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green.shade700;
      case 'missed call': case 'not answered': case 'call failed': return Colors.red.shade700;
      case 'call busy': return Colors.orange.shade700;
      default: return Colors.grey.shade600;
    }
  }

  Map<String, List<ContactTracked>> _groupContactsByDate() {
    final Map<String, List<ContactTracked>> dailyReports = {};
    final DateFormat keyFmt = DateFormat('yyyy-MM-dd');
    final DateFormat displayFmt = DateFormat('EEEE, MMMM d, yyyy');
    for (var c in trackedContacts) {
      final key = c.dateTracked != null ? keyFmt.format(c.dateTracked!) : 'Unknown Date';
      dailyReports.putIfAbsent(key, () => []).add(c);
    }
    final sortedKeys = dailyReports.keys.toList()..sort((a, b) => b.compareTo(a));
    return {
      for (var k in sortedKeys)
        displayFmt.format(keyFmt.parse(k)): dailyReports[k]!
          ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''))
    };
  }

  void _showDateRangePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: SizedBox(
          width: 400, height: 450,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: (startDate != null && endDate != null)
                ? PickerDateRange(startDate!, endDate!) : null,
            showActionButtons: true,
            onSubmit: (Object? value) {
              if (value is PickerDateRange && value.startDate != null && value.endDate != null) {
                setState(() { startDate = value.startDate; endDate = value.endDate; });
                Navigator.pop(context);
                _loadContacts(start: startDate, end: endDate);
              } else {
                Navigator.pop(context);
                _showSnackBar('Please select a valid start and end date.', isError: true);
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_isUserBioLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      bodyContent = Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)));
    } else if (trackedContacts.isEmpty) {
      bodyContent = Center(
          child: Text(startDate == null
              ? 'Please select a date range to view reports.'
              : 'No tracked contacts found for the selected period.'));
    } else {
      bodyContent = _buildReportContent();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Reports (Web)'),
        actions: [
          IconButton(
            icon: Icon(_allCellsGloballyUnlocked ? Icons.visibility_off : Icons.visibility),
            tooltip: _allCellsGloballyUnlocked ? 'Mask Sensitive Data' : 'Unmask Sensitive Data',
            onPressed: (isLoading || _isUserBioLoading) ? null : _toggleGlobalUnmask,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              // For export, first check if data is unmasked
              if (value == 'export_csv' || value == 'export_pdf') {
                if (!_allCellsGloballyUnlocked) {
                  _showSnackBar('Please unmask the data first before exporting.', isError: true);
                  await _toggleGlobalUnmask(); // Prompt user to unmask
                  // Re-check after prompt
                  if (!_allCellsGloballyUnlocked) return;
                }
              }

              switch (value) {
                case 'filter': _showDateRangePicker(context); break;
                case 'refresh': _loadContacts(start: startDate, end: endDate); break;
                case 'export_csv': _exportToCSV(); break;
                case 'export_pdf': _exportToPDF(); break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'filter', child: Text('Filter by Date')),
              const PopupMenuItem(value: 'refresh', child: Text('Refresh Data')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'export_csv', child: Text('Export as CSV')),
              const PopupMenuItem(value: 'export_pdf', child: Text('Export Charts as PDF')),
            ],
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildReportContent() {
    final dailyGroupedReports = _groupContactsByDate();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header and Charts
          if (startDate != null && endDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                  'Displaying data for ${userFirstName ?? ''} ${userLastName ?? ''} from ${DateFormat.yMd().format(startDate!)} to ${DateFormat.yMd().format(endDate!)}',
                  textAlign: TextAlign.center),
            ),
          Wrap(
            spacing: 20.0, runSpacing: 20.0, alignment: WrapAlignment.center,
            children: [
              if (callStatusChartData.isNotEmpty)
                _buildChartCard(
                    key: _callStatusChartKey, title: 'Call Status',
                    chart: SfCircularChart(series: <CircularSeries>[
                      PieSeries<MapEntry<String, int>, String>(
                          dataSource: callStatusChartData,
                          xValueMapper: (d, _) => d.key,
                          yValueMapper: (d, _) => d.value,
                          dataLabelSettings: const DataLabelSettings(isVisible: true))
                    ])),
              if (artStatusChartData.isNotEmpty)
                _buildChartCard(
                    key: _artStatusChartKey, title: 'ART Status',
                    chart: SfCircularChart(series: <CircularSeries>[
                      PieSeries<MapEntry<String, int>, String>(
                          dataSource: artStatusChartData,
                          xValueMapper: (d, _) => d.key,
                          yValueMapper: (d, _) => d.value,
                          dataLabelSettings: const DataLabelSettings(isVisible: true))
                    ])),
              if (callDurationTrendData.isNotEmpty)
                _buildChartCard(
                    key: _durationTrendChartKey, title: 'Avg Call Duration',
                    chart: SfCartesianChart(
                        primaryXAxis: const CategoryAxis(labelRotation: -45),
                        series: <CartesianSeries>[
                          LineSeries<_ChartDataPoint, String>(
                              dataSource: callDurationTrendData,
                              xValueMapper: (d, _) => DateFormat('MMM d').format(DateTime.parse(d.x)),
                              yValueMapper: (d, _) => d.y,
                              markerSettings: const MarkerSettings(isVisible: true)
                          )
                        ])),
              if (updateMetricsData.isNotEmpty)
                _buildChartCard(
                    key: _updateTrendsChartKey, title: 'Monthly Updates',
                    chart: SfCartesianChart(
                        primaryXAxis: const CategoryAxis(labelRotation: -45),
                        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                        series: <CartesianSeries>[
                          LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, name: 'Phone', xValueMapper: (d,_) => d.month, yValueMapper: (d,_) => d.phoneUpdates),
                          LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, name: 'Address', xValueMapper: (d,_) => d.month, yValueMapper: (d,_) => d.addressUpdates),
                          LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, name: 'Next Visit', xValueMapper: (d,_) => d.month, yValueMapper: (d,_) => d.nextVisitUpdates),
                        ])),
            ],
          ),
          const SizedBox(height: 30),
          // Detailed Logs Table
          Text('Detailed Logs', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          ...dailyGroupedReports.entries.map((entry) => Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ExpansionTile(
              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              initiallyExpanded: dailyGroupedReports.keys.first == entry.key,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DataTable(
                      columnSpacing: 15.0,
                      columns: const [
                        DataColumn(label: Text('Client Name')),
                        DataColumn(label: Text('Client Phone')),
                        DataColumn(label: Text('ART ID')),
                        DataColumn(label: Text('ART Status')),
                        DataColumn(label: Text('Time')),
                        DataColumn(label: Text('Call Status')),
                        DataColumn(label: Text('Duration')),
                        DataColumn(label: Text('Facility')),
                      ],
                      rows: entry.value.map((contact) => DataRow(cells: [
                        _MaskedCell(contact.name, mask: _maskName(contact.name), isUnlocked: _allCellsGloballyUnlocked),
                        _MaskedCell(contact.phoneNumber, mask: _maskPhoneNumber(contact.phoneNumber), isUnlocked: _allCellsGloballyUnlocked),
                        _MaskedCell(contact.uniqueID, mask: _maskName(contact.uniqueID), isUnlocked: _allCellsGloballyUnlocked),
                        DataCell(Text(contact.artStatus ?? 'N/A')),
                        DataCell(Text(contact.dateTracked != null ? DateFormat('HH:mm').format(contact.dateTracked!) : 'N/A')),
                        DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            color: _getStatusColor(contact.callStatus ?? '').withOpacity(0.2),
                            child: Text(contact.callStatus ?? 'N/A', style: TextStyle(color: _getStatusColor(contact.callStatus ?? ''))))),
                        DataCell(Text(contact.callDuration != null ? formatDuration(contact.callDuration!) : 'N/A')),
                        DataCell(Text(contact.facilityName ?? 'N/A')),
                      ])).toList(),
                    ),
                  ),
                )
              ],
            ),
          ),
          )
        ],
      ),
    );
  }

  Widget _buildChartCard({required Key key, required String title, required Widget chart}) {
    return RepaintBoundary(
      key: key,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, minHeight: 350),
        child: Card(
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Expanded(child: chart),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Helper Data and UI Classes ---

class _MaskedCell extends DataCell {
  _MaskedCell(String? text, {required String mask, required bool isUnlocked})
      : super(Text(isUnlocked ? text ?? 'N/A' : mask));
}

class _ChartDataPoint {
  final String x; final double y;
  _ChartDataPoint(this.x, this.y);
}

class _UpdateChartData {
  final String month; final int phoneUpdates; final int addressUpdates; final int nextVisitUpdates;
  _UpdateChartData(this.month, this.phoneUpdates, this.addressUpdates, this.nextVisitUpdates);
}