import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// Web-specific imports
import 'dart:html' as html;
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

// Imports for file generation
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/contact_tracked.dart'; // Ensure this path is correct

class StateReportsPageWeb extends StatefulWidget {
  const StateReportsPageWeb({super.key});

  @override
  _StateReportsPageWebState createState() => _StateReportsPageWebState();
}

class _StateReportsPageWebState extends State<StateReportsPageWeb> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ContactTracked> trackedContacts = [];
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = true;
  bool _isUserBioLoading = true;
  String? _errorMessage;

  // Masking and Export State
  bool _allCellsGloballyUnlocked = false;
  final GlobalKey _callStatusChartKey = GlobalKey();
  final GlobalKey _artStatusChartKey = GlobalKey();
  final GlobalKey _durationTrendChartKey = GlobalKey();
  final GlobalKey _updateTrendsChartKey = GlobalKey();

  // User Bio Details (only state is needed for filtering)
  String? userState;

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
      await _loadStateContacts(start: startDate, end: endDate);
    }
  }

  Future<void> _loadCurrentUserBio() async {
    setState(() => _isUserBioLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final docSnapshot =
      await _firestore.collection('Staff').doc(user.uid).get();
      if (docSnapshot.exists) {
        setState(() {
          userState = docSnapshot.data()?['state'] as String?;
          _isUserBioLoading = false;
        });
        if (userState == null) {
          throw Exception("User's state is not defined in their profile.");
        }
      } else {
        throw Exception("User bio not found in Firestore 'Staff' collection.");
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

  /// --- MODIFIED DATA FETCHING LOGIC FOR STATE-LEVEL ---
  /// Fetches all contacts for the user's entire state within a date range.
  /// This uses a collectionGroup query and requires a specific data structure and Firestore indexes.
  Future<void> _loadStateContacts({DateTime? start, DateTime? end}) async {
    // Ensure user's state is loaded and a date range is provided
    if (userState == null || start == null || end == null) {
      setState(() {
        isLoading = false;
        _errorMessage = userState == null
            ? "Cannot load reports: User's state is unknown."
            : "Please select a date range.";
        trackedContacts = [];
        _prepareChartData();
      });
      return;
    }

    setState(() {
      isLoading = true;
      _errorMessage = null;
      trackedContacts = [];
    });

    try {
      // **IMPORTANT**: This query requires a Firestore index.
      // The Firestore console will provide a link to create it automatically when you first run this query.
      // The collection group ID ('TrackedCalls' in this example) must be consistent across your database.
      final querySnapshot = await _firestore
          .collectionGroup('TrackedCalls') // Query all collections with this ID
          .where('state', isEqualTo: userState) // Filter by the user's state
          .where('dateTracked', isGreaterThanOrEqualTo: start) // Filter by start date
          .where('dateTracked', isLessThanOrEqualTo: end.add(const Duration(days: 1))) // Filter by end date
          .get();

      final fetchedContacts = querySnapshot.docs
          .map((doc) => ContactTracked.fromFirestore(doc.data(), doc.id))
          .toList();

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
          // Provide a more helpful error message for common index issues.
          print("Error loading state reports: $e.");
          _errorMessage =
          "Error loading state reports: $e. \n\nNOTE: This may be due to a missing Firestore index. Check the debug console for a link to create it.";
          trackedContacts = [];
          _prepareChartData();
        });
      }
    }
  }

  // --- MASKING, EXPORT, AND OTHER HELPERS (Identical to previous version) ---
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : null,
    ));
  }

  String _maskName(String? name) =>
      (name?.isNotEmpty ?? false) ? '${name![0]}. (hidden)' : 'N/A';

  String _maskPhoneNumber(String? number) =>
      (number != null && number.length > 4)
          ? '...${number.substring(number.length - 4)}'
          : '••••';

  Future<void> _toggleGlobalUnmask() async {
    if (_allCellsGloballyUnlocked) {
      setState(() => _allCellsGloballyUnlocked = false);
      _showSnackBar('All sensitive data has been masked.');
      return;
    }
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verify to Unmask Data'),
          content: /* ... content identical to previous version ... */
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter your password for ${user.email} to view sensitive client information.'),
              const SizedBox(height: 16),
              TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            ],
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
            ElevatedButton(child: const Text('Unlock'), onPressed: () async {
              try {
                await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: passwordController.text));
                Navigator.pop(context, true);
              } catch (e) {
                Navigator.pop(context, false);
                _showSnackBar('Verification failed. Please try again.', isError: true);
              }
            },
            ),
          ],
        ));
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
      'Designation'
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
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "state_report_${userState}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _exportToPDF() async {
    // This function remains identical to the previous version
    Future<pw.Widget?> captureChart(GlobalKey key, String title) async {
      try {
        RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return null;
        return pw.Column(children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Image(pw.MemoryImage(byteData.buffer.asUint8List()), fit: pw.BoxFit.contain, width: 400),
          pw.SizedBox(height: 25),
        ]);
      } catch (e) { return null; }
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
    if (chartWidgets.isEmpty) { _showSnackBar('No charts to export.', isError: true); return; }
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (context) => chartWidgets));
    final bytes = await pdf.save();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "state_charts_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // Chart data preparation functions are identical
  void _prepareChartData() { /* ... identical ... */
    callStatusChartData = _getCallStatusData();
    callDurationTrendData = _getCallDurationTrendData();
    updateMetricsData = _getUpdateMetricsData();
    artStatusChartData = _getArtStatusData();
  }
  List<MapEntry<String, int>> _getCallStatusData() { /* ... identical ... */
    Map<String, int> statusCounts = {};
    for (var c in trackedContacts) { String s = c.callStatus?.trim() ?? 'N/A'; statusCounts[s] = (statusCounts[s] ?? 0) + 1; }
    return statusCounts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
  }
  List<MapEntry<String, int>> _getArtStatusData() { /* ... identical ... */
    Map<String, int> statusCounts = {};
    for (var c in trackedContacts) { String s = c.artStatus?.trim() ?? 'Unknown'; statusCounts[s] = (statusCounts[s] ?? 0) + 1; }
    return statusCounts.entries.toList()..sort((a,b) => a.key.compareTo(b.key));
  }
  List<_ChartDataPoint> _getCallDurationTrendData() { /* ... identical ... */
    Map<String, List<int>> dailyDurations = {};
    final DateFormat keyFmt = DateFormat('yyyy-MM-dd');
    for(var c in trackedContacts) {
      if (c.dateTracked != null && c.callDuration != null && c.callDuration! > 0) {
        String key = keyFmt.format(c.dateTracked!);
        dailyDurations.putIfAbsent(key, () => []).add(c.callDuration!);
      }
    }
    List<_ChartDataPoint> data = [];
    dailyDurations.forEach((date, durations) {
      data.add(_ChartDataPoint(date, durations.reduce((a,b) => a+b) / durations.length));
    });
    data.sort((a,b) => a.x.compareTo(b.x));
    return data;
  }
  List<_UpdateChartData> _getUpdateMetricsData() { /* ... identical ... */
    Map<String, int> phoneUpd = {}; Map<String, int> addrUpd = {}; Map<String, int> visitUpd = {};
    final DateFormat keyFmt = DateFormat('yyyy-MM');
    for(var c in trackedContacts) {
      if(c.datePhoneNumberUpdated != null) { phoneUpd.putIfAbsent(keyFmt.format(c.datePhoneNumberUpdated!), () => 0); phoneUpd[keyFmt.format(c.datePhoneNumberUpdated!)] = phoneUpd[keyFmt.format(c.datePhoneNumberUpdated!)]! + 1; }
      if(c.dateAddressChanged != null) { addrUpd.putIfAbsent(keyFmt.format(c.dateAddressChanged!), () => 0); addrUpd[keyFmt.format(c.dateAddressChanged!)] = addrUpd[keyFmt.format(c.dateAddressChanged!)]! + 1; }
      if(c.dateNextVisitChanged != null) { visitUpd.putIfAbsent(keyFmt.format(c.dateNextVisitChanged!), () => 0); visitUpd[keyFmt.format(c.dateNextVisitChanged!)] = visitUpd[keyFmt.format(c.dateNextVisitChanged!)]! + 1; }
    }
    List<String> sortedMonths = {...phoneUpd.keys, ...addrUpd.keys, ...visitUpd.keys}.toList()..sort();
    return sortedMonths.map((m) => _UpdateChartData(m, phoneUpd[m]??0, addrUpd[m]??0, visitUpd[m]??0)).toList();
  }
  String formatDuration(int totalSeconds) => Duration(seconds: totalSeconds).toString().split('.').first.padLeft(8, "0");
  Color _getStatusColor(String s) { /* ... identical ... */
    switch(s.toLowerCase()) {
      case 'completed': return Colors.green.shade700;
      case 'missed call': case 'not answered': case 'call failed': return Colors.red.shade700;
      case 'call busy': return Colors.orange.shade700;
      default: return Colors.grey.shade600;
    }
  }

  // Other helper functions are identical
  void _showDateRangePicker(BuildContext context) { /* ... identical to previous version ... */
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Select Date Range'),
      content: SizedBox(width: 400, height: 450, child: SfDateRangePicker(
        selectionMode: DateRangePickerSelectionMode.range,
        initialSelectedRange: (startDate != null && endDate != null) ? PickerDateRange(startDate!, endDate!) : null,
        showActionButtons: true,
        onSubmit: (Object? value) {
          if (value is PickerDateRange && value.startDate != null && value.endDate != null) {
            setState(() { startDate = value.startDate; endDate = value.endDate; });
            Navigator.pop(context);
            _loadStateContacts(start: startDate, end: endDate);
          } else { Navigator.pop(context); }
        },
        onCancel: () => Navigator.pop(context),
      )),
    ));
  }


  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_isUserBioLoading || isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      bodyContent = Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,)));
    } else if (trackedContacts.isEmpty) {
      bodyContent = const Center(child: Text('No tracked contacts found for the selected state and period.'));
    } else {
      bodyContent = _buildReportContent();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('State-Level Reports (${userState ?? "..."})'),
        actions: [
          IconButton(
            icon: Icon(_allCellsGloballyUnlocked ? Icons.visibility_off : Icons.visibility),
            tooltip: 'Toggle Sensitive Data Visibility',
            onPressed: (_isUserBioLoading || isLoading) ? null : _toggleGlobalUnmask,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value.startsWith('export') && !_allCellsGloballyUnlocked) {
                _showSnackBar('Please unmask data before exporting.', isError: true);
                await _toggleGlobalUnmask();
                if (!_allCellsGloballyUnlocked) return; // Stop if user cancelled
              }
              switch (value) {
                case 'filter': _showDateRangePicker(context); break;
                case 'refresh': _loadStateContacts(start: startDate, end: endDate); break;
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
    // Grouping by location first, then by date for the table display
    final Map<String, List<ContactTracked>> groupedByLocation = {};
    for (var contact in trackedContacts) {
      final locationKey = contact.facilityName ?? 'Unknown Facility';
      groupedByLocation.putIfAbsent(locationKey, () => []).add(contact);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Charts Section (shows aggregated state data)
          Wrap(alignment: WrapAlignment.center, spacing: 20, runSpacing: 20, children: [
            if (callStatusChartData.isNotEmpty) _buildChartCard(key: _callStatusChartKey, title: 'Call Status (State-wide)', chart: SfCircularChart(series: [PieSeries<MapEntry<String,int>,String>(dataSource: callStatusChartData, xValueMapper: (d,_) => d.key, yValueMapper: (d,_) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true))])),
            if (artStatusChartData.isNotEmpty) _buildChartCard(key: _artStatusChartKey, title: 'ART Status (State-wide)', chart: SfCircularChart(series: [PieSeries<MapEntry<String,int>,String>(dataSource: artStatusChartData, xValueMapper: (d,_) => d.key, yValueMapper: (d,_) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true))])),
            if (callDurationTrendData.isNotEmpty) _buildChartCard(key: _durationTrendChartKey, title: 'Avg. Call Duration (State-wide)', chart: SfCartesianChart(primaryXAxis: const CategoryAxis(labelRotation: -45), series: [LineSeries<_ChartDataPoint, String>(dataSource: callDurationTrendData, xValueMapper: (d,_) => DateFormat('MMM d').format(DateTime.parse(d.x)), yValueMapper: (d,_) => d.y)])),
            if (updateMetricsData.isNotEmpty) _buildChartCard(key: _updateTrendsChartKey, title: 'Update Trends (State-wide)', chart: SfCartesianChart(primaryXAxis: const CategoryAxis(labelRotation: -45), legend: const Legend(isVisible: true), series: [LineSeries<_UpdateChartData,String>(dataSource: updateMetricsData, name: 'Phone', xValueMapper: (d,_) => d.month, yValueMapper: (d,_) => d.phoneUpdates), LineSeries<_UpdateChartData,String>(dataSource: updateMetricsData, name: 'Address', xValueMapper: (d,_) => d.month, yValueMapper: (d,_) => d.addressUpdates), LineSeries<_UpdateChartData,String>(dataSource: updateMetricsData, name: 'Visit', xValueMapper: (d,_) => d.month, yValueMapper: (d,_) => d.nextVisitUpdates)])),
          ]),
          const SizedBox(height: 30),
          Text('Detailed Logs by Facility', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          // ExpansionTiles for each location
          ...groupedByLocation.entries.map((entry) => Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ExpansionTile(
              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${entry.value.length} records'),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DataTable(
                      columns: const [
                        // Added 'Tracked By' to see which user made the call
                        DataColumn(label: Text('Tracked By')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Client Name')),
                        DataColumn(label: Text('Client Phone')),
                        DataColumn(label: Text('ART ID')),
                        DataColumn(label: Text('ART Status')),
                        DataColumn(label: Text('Call Status')),
                      ],
                      rows: entry.value.map((contact) => DataRow(cells: [
                        DataCell(Text(contact.trackedBy ?? 'N/A')),
                        DataCell(Text(contact.dateTracked != null ? DateFormat('yyyy-MM-dd').format(contact.dateTracked!) : 'N/A')),
                        _MaskedCell(contact.name, mask: _maskName(contact.name), isUnlocked: _allCellsGloballyUnlocked),
                        _MaskedCell(contact.phoneNumber, mask: _maskPhoneNumber(contact.phoneNumber), isUnlocked: _allCellsGloballyUnlocked),
                        _MaskedCell(contact.uniqueID, mask: _maskName(contact.uniqueID), isUnlocked: _allCellsGloballyUnlocked),
                        DataCell(Text(contact.artStatus ?? 'N/A')),
                        DataCell(Container(
                          padding: const EdgeInsets.all(4),
                          color: _getStatusColor(contact.callStatus ?? '').withOpacity(0.2),
                          child: Text(contact.callStatus ?? 'N/A', style: TextStyle(color: _getStatusColor(contact.callStatus ?? ''))),
                        )),
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

  Widget _buildChartCard({required Key key, required String title, required Widget chart}) =>
      RepaintBoundary(
        key: key,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, minHeight: 350),
          child: Card(elevation: 2.0, child: Padding(padding: const EdgeInsets.all(12.0),
            child: Column(children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Expanded(child: chart),
            ]),
          )),
        ),
      );
}

// Helper Classes (identical to previous version)
class _MaskedCell extends DataCell {
  _MaskedCell(String? text, {required String mask, required bool isUnlocked}) : super(Text(isUnlocked ? text ?? 'N/A' : mask));
}
class _ChartDataPoint { final String x; final double y; _ChartDataPoint(this.x, this.y); }
class _UpdateChartData { final String month; final int phoneUpdates; final int addressUpdates; final int nextVisitUpdates; _UpdateChartData(this.month, this.phoneUpdates, this.addressUpdates, this.nextVisitUpdates); }