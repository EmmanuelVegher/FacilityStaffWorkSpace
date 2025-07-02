// REWRITTEN FOR FLUTTER WEB & FACILITY-LEVEL FILTERING (PATH-BASED COMPATIBLE VERSION)
import 'dart:convert' show utf8;
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' show PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../models/contact_tracked.dart';
import '../../widgets/drawer2.dart';

// GlobalKeys to capture chart images for PDF export
final GlobalKey _callStatusChartKey = GlobalKey();
final GlobalKey _artStatusChartKey = GlobalKey();
final GlobalKey _callDurationChartKey = GlobalKey();
final GlobalKey _updateMetricsChartKey = GlobalKey();


class ReportsPageWeb2 extends StatefulWidget {
  const ReportsPageWeb2({super.key});

  @override
  _ReportsPageWeb2State createState() => _ReportsPageWeb2State();
}

class _ReportsPageWeb2State extends State<ReportsPageWeb2> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Core Data & UI State ---
  List<ContactTracked> trackedContacts = [];
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;
  bool _allCellsGloballyUnlocked = false;

  // --- State variables for filters and context ---
  bool _isFilterLoading = true;
  bool _isInitialState = true;
  List<String> _availableFacilities = [];

  // User Bio Details
  String? userFirstName;
  String? userLastName;
  String? userDesignation;
  String? userState;

  // --- REWRITTEN: Controller management for expandable widgets ---
  List<ScrollController> _logTableControllers = [];
  int _currentlyExpandedDateIndex = -1;
  bool _isClientSummaryExpanded = false;
  final ScrollController _clientSummaryScrollController = ScrollController();


  // Chart Data Holders
  List<MapEntry<String, int>> callStatusChartData = [];
  List<_ChartDataPoint> callDurationTrendData = [];
  List<_UpdateChartData> updateMetricsData = [];
  List<MapEntry<String, int>> artStatusChartData = [];

  // --- State variables for multi-select filters and calculations ---
  List<ContactTracked> _masterContactList = [];
  List<String> _selectedFacilities = [];
  List<String> _availableTrackers = ['All Trackers'];
  List<String> _selectedTrackers = ['All Trackers'];
  List<String> _availableCallStatuses = ['All Statuses'];
  List<String> _selectedCallStatuses = ['All Statuses'];
  // --- REWRITTEN: Three separate costs for detailed reporting ---
  double _totalCallCost = 0.0;
  double _outgoingAnsweredCost = 0.0;
  double _incomingAnsweredCost = 0.0;
  final double _costPerSecond = 0.25;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day - 6);
    endDate = DateTime(now.year, now.month, now.day);
    _initializeFilters();
  }

  @override
  void dispose() {
    for (final controller in _logTableControllers) {
      controller.dispose();
    }
    _clientSummaryScrollController.dispose();
    super.dispose();
  }

  void _updateAvailableFiltersFromData() {
    if (_masterContactList.isEmpty) {
      setState(() {
        _availableTrackers = ['All Trackers'];
        _selectedTrackers = ['All Trackers'];
        _availableCallStatuses = ['All Statuses'];
        _selectedCallStatuses = ['All Statuses'];
      });
      return;
    }

    final trackers = _masterContactList.map((c) => c.trackedBy).whereType<String>().where((t) => t.isNotEmpty).toSet();
    final statuses = _masterContactList.map((c) => c.callStatus).whereType<String>().where((s) => s.isNotEmpty).toSet();

    setState(() {
      _availableTrackers = ['All Trackers', ...trackers.toList()..sort()];
      _availableCallStatuses = ['All Statuses', ...statuses.toList()..sort()];

      _selectedTrackers.retainWhere((t) => _availableTrackers.contains(t));
      if (_selectedTrackers.isEmpty) _selectedTrackers = ['All Trackers'];

      _selectedCallStatuses.retainWhere((s) => _availableCallStatuses.contains(s));
      if (_selectedCallStatuses.isEmpty) _selectedCallStatuses = ['All Statuses'];
    });
  }

  // --- REWRITTEN: This function now calculates three separate costs ---
  void _applyAllFiltersAndRecalculate() {
    List<ContactTracked> filteredList = List.from(_masterContactList);

    if (!_selectedTrackers.contains('All Trackers') && _selectedTrackers.isNotEmpty) {
      filteredList = filteredList.where((c) => _selectedTrackers.contains(c.trackedBy)).toList();
    }

    if (!_selectedCallStatuses.contains('All Statuses') && _selectedCallStatuses.isNotEmpty) {
      filteredList = filteredList.where((c) => _selectedCallStatuses.contains(c.callStatus)).toList();
    }

    // 1. Total cost for ALL calls
    int totalDurationInSeconds = filteredList.fold(0, (sum, contact) => sum + (contact.callDuration ?? 0));
    double calculatedTotalCost = totalDurationInSeconds * _costPerSecond;

    // 2. Cost for "Answered" calls
    int outgoingDuration = filteredList
        .where((c) => c.callStatus?.toLowerCase() == 'answered')
        .fold(0, (sum, contact) => sum + (contact.callDuration ?? 0));
    double calculatedOutgoingCost = outgoingDuration * _costPerSecond;

    // 3. Cost for "Incoming Answered" calls
    int incomingDuration = filteredList
        .where((c) => c.callStatus?.toLowerCase() == 'incoming answered')
        .fold(0, (sum, contact) => sum + (contact.callDuration ?? 0));
    double calculatedIncomingCost = incomingDuration * _costPerSecond;

    setState(() {
      trackedContacts = filteredList;
      _totalCallCost = calculatedTotalCost;
      _outgoingAnsweredCost = calculatedOutgoingCost;
      _incomingAnsweredCost = calculatedIncomingCost;
      _prepareChartData();
      _currentlyExpandedDateIndex = trackedContacts.isNotEmpty ? 0 : -1;

      for (final controller in _logTableControllers) {
        controller.dispose();
      }
      final dateGroups = _groupContactsByDate();
      _logTableControllers = List.generate(dateGroups.length, (_) => ScrollController());
    });
  }

  Future<void> _initializeFilters() async {
    setState(() => _isFilterLoading = true);
    await _loadCurrentUserBio();

    if (userState != null) {
      final facilities = await _getFacilitiesForState(userState!);
      if (mounted) {
        setState(() {
          _availableFacilities = ['All Facilities', ...facilities];
          _selectedFacilities = ['All Facilities'];
          _isFilterLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isFilterLoading = false;
          _errorMessage = "Could not determine your state from your profile. Cannot load facilities.";
        });
      }
    }
  }

  Future<void> _loadCurrentUserBio() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final docSnapshot = await _firestore.collection('Staff').doc(user.uid).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (mounted) {
          setState(() {
            userFirstName = data['firstName'] as String?;
            userLastName = data['lastName'] as String?;
            userDesignation = data['designation'] as String?;
            userState = data['state'] as String?;
          });
        }
      } else {
        throw Exception("User bio data not found in Firestore 'Staff' collection.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error loading user details: $e";
          _isFilterLoading = false;
        });
      }
    }
  }

  Future<List<String>> _getFacilitiesForState(String state) async {
    try {
      final snapshot = await _firestore
          .collection('Location')
          .doc(state)
          .collection(state)
          .where('category', isEqualTo: 'Facility')
          .get();

      final List<String> facilityNames = [];
      for (final doc in snapshot.docs) {
        final locationName = doc.data()['LocationName'] as String?;
        if (locationName != null && locationName.isNotEmpty) {
          facilityNames.add(locationName);
        }
      }
      facilityNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return facilityNames;
    } catch (e) {
      debugPrint("Error fetching facilities for state '$state': $e");
      if (e.toString().contains('INDEX_NOT_FOUND') || e.toString().contains('requires an index')) {
        _showSnackBar("A database index is required for this query. Please create it in your Firebase console.");
      } else {
        _showSnackBar("Error fetching facility list: $e");
      }
      return [];
    }
  }

  Future<void> _loadReports() async {
    if (_selectedFacilities.isEmpty) {
      _showSnackBar("Please select at least one facility to generate a report.");
      return;
    }
    if (startDate == null || endDate == null) {
      _showSnackBar("Please select a valid date range.");
      return;
    }
    if (userState == null) {
      _showSnackBar("Cannot load reports: Your state is not defined in your profile.");
      return;
    }

    setState(() {
      isLoading = true;
      _isInitialState = false;
      _errorMessage = null;
      _masterContactList.clear();
      trackedContacts.clear();
      _totalCallCost = 0.0;
      _outgoingAnsweredCost = 0.0;
      _incomingAnsweredCost = 0.0;
      _currentlyExpandedDateIndex = -1;
    });

    try {
      Query query = _firestore.collection('CallLogs');

      query = query
          .where('trackerFacilityState', isEqualTo: userState)
          .where('dateTracked', isGreaterThanOrEqualTo: startDate)
          .where('dateTracked', isLessThanOrEqualTo: endDate!.add(const Duration(days: 1)));

      if (!_selectedFacilities.contains('All Facilities')) {
        if (_selectedFacilities.length > 30) {
          _showSnackBar("Querying for more than 30 facilities at once is not supported. Please narrow your selection.");
          if (mounted) {
            setState(() => isLoading = false);
          }
          return;
        }
        query = query.where('trackerFacilityLocation', whereIn: _selectedFacilities);
      }

      query = query.orderBy('dateTracked', descending: true);

      final QuerySnapshot querySnapshot = await query.get();

      final List<ContactTracked> fetchedContacts = querySnapshot.docs.map((doc) {
        return ContactTracked.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      if (mounted) {
        setState(() {
          _masterContactList = fetchedContacts;
          _updateAvailableFiltersFromData();
          _applyAllFiltersAndRecalculate();
          isLoading = false;
        });
        if (fetchedContacts.isEmpty) {
          _showSnackBar("No call logs found for the selected criteria.");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          _errorMessage = "An error occurred while loading reports: $e";
          trackedContacts = [];
          _prepareChartData();
        });
      }
      debugPrint("Firestore Query Error: $e");
    }
  }

  // ... (All other methods like _prepareChartData, _showSnackBar, _masking, _exporting, etc., remain the same)
  // ... (Methods from _promptForPasswordAndReauthenticate to the end of the file remain unchanged)

  void _prepareChartData() {
    callStatusChartData = _getCallStatusData();
    callDurationTrendData = _getCallDurationTrendData();
    updateMetricsData = _getUpdateMetricsData();
    artStatusChartData = _getArtStatusData();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                        hintText: 'Password',
                        border: OutlineInputBorder()
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isAuthenticating ? null : () async {
                  if (passwordController.text.isEmpty) {
                    _showSnackBar("Password cannot be empty.");
                    return;
                  }
                  setState(() => isAuthenticating = true);
                  try {
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: passwordController.text.trim(),
                    );
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
      if (!proceed) {
        _showSnackBar('Authentication failed. Export will contain masked data.');
      }
    }

    try {
      List<List<dynamic>> rows = [
        [
          'Client Name', 'Client PhoneNo', 'Client ART Status', "Client's Facility",
          'Client State', 'Client ART ID', 'DatimCode', 'Date Tracked', 'Time Tracked',
          'Call Status', 'Duration of Call (s)', 'Tracked By', "Tracker's Designation",
          "Tracker's Facility", "Tracker's Supervisor", "Tracker's Supervisor Email"
        ]
      ];

      for (var contact in trackedContacts) {
        rows.add([
          _allCellsGloballyUnlocked ? (contact.name ?? 'N/A') : _maskClientName(contact.name),
          _allCellsGloballyUnlocked ? (contact.phoneNumber ?? 'N/A') : _maskPhoneNumber(contact.phoneNumber),
          contact.artStatus ?? 'N/A',
          contact.facilityName ?? 'N/A',
          contact.state ?? 'N/A',
          _allCellsGloballyUnlocked ? (contact.uniqueID ?? 'N/A') : _maskClientName(contact.uniqueID),
          contact.datimCode ?? 'N/A',
          contact.dateTracked != null ? DateFormat('yyyy-MM-dd').format(contact.dateTracked!) : 'N/A',
          contact.dateTracked != null ? DateFormat('HH:mm').format(contact.dateTracked!) : 'N/A',
          contact.callStatus ?? 'N/A',
          contact.callDuration ?? 0,
          contact.trackedBy ?? 'N/A',
          contact.designation ?? 'N/A',
          contact.trackerFacilityLocation ?? 'N/A',
          contact.supervisorName ?? 'N/A',
          contact.supervisorEmail ?? 'N/A',
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final filename = 'call_tracker_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;

      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      _showSnackBar('CSV download started.');

    } catch (e) {
      _showSnackBar('Error exporting CSV: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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

  Future<void> _exportToPDF() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();
      final Uint8List? callStatusBytes = await _captureChartPng(_callStatusChartKey);
      final Uint8List? artStatusBytes = await _captureChartPng(_artStatusChartKey);
      final Uint8List? callDurationBytes = await _captureChartPng(_callDurationChartKey);
      final Uint8List? updateMetricsBytes = await _captureChartPng(_updateMetricsChartKey);

      final pw.MemoryImage? callStatusImg = callStatusBytes != null ? pw.MemoryImage(callStatusBytes) : null;
      final pw.MemoryImage? artStatusImg = artStatusBytes != null ? pw.MemoryImage(artStatusBytes) : null;
      final pw.MemoryImage? callDurationImg = callDurationBytes != null ? pw.MemoryImage(callDurationBytes) : null;
      final pw.MemoryImage? updateMetricsImg = updateMetricsBytes != null ? pw.MemoryImage(updateMetricsBytes) : null;

      final facilityText = _selectedFacilities.contains("All Facilities")
          ? "All Facilities"
          : _selectedFacilities.join(", ");

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          header: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Call Tracking Report - ${DateFormat.yMMMMd().format(DateTime.now())}',
                style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey)),
          ),
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey)),
          ),
          build: (pw.Context context) => [
            pw.Header(level: 0, text: 'Call Tracking Summary Report'),
            pw.Paragraph(
              text: 'Report for: $facilityText\n'
                  'Date Range: ${DateFormat.yMd().format(startDate!)} to ${DateFormat.yMd().format(endDate!)}',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 20),
            pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: pw.WrapAlignment.spaceEvenly,
                children: [
                  if (callStatusImg != null)
                    pw.Container(width: 350, child: pw.Column(children: [pw.Text('Call Status Distribution', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 5), pw.Image(callStatusImg, fit: pw.BoxFit.contain, height: 200)])),
                  if (artStatusImg != null)
                    pw.Container(width: 350, child: pw.Column(children: [pw.Text('ART Status Distribution', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 5), pw.Image(artStatusImg, fit: pw.BoxFit.contain, height: 200)])),
                  if (callDurationImg != null)
                    pw.Container(width: 350, child: pw.Column(children: [pw.Text('Average Call Duration Trend', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 5), pw.Image(callDurationImg, fit: pw.BoxFit.contain, height: 200)])),
                  if (updateMetricsImg != null)
                    pw.Container(width: 350, child: pw.Column(children: [pw.Text('Monthly Update Trends', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 5), pw.Image(updateMetricsImg, fit: pw.BoxFit.contain, height: 200)])),
                ]
            ),
            pw.SizedBox(height: 20),
            pw.Paragraph(text: "Note: Detailed logs are available in the CSV export.", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final filename = 'call_tracker_charts_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;

      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      _showSnackBar('PDF download started.');

    } catch (e) {
      _showSnackBar('Error exporting PDF: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // --- Chart Data Preparation Methods ---
  List<MapEntry<String, int>> _getCallStatusData() {
    Map<String, int> statusCounts = {};
    for (var contact in trackedContacts) {
      String status = contact.callStatus?.trim() ?? 'N/A';
      if (status.isEmpty) status = 'N/A';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }
  List<_ChartDataPoint> _getCallDurationTrendData() {
    Map<String, List<int>> dailyDurations = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');
    for (var contact in trackedContacts) {
      if (contact.dateTracked != null && contact.callDuration != null && contact.callDuration! > 0) {
        String dateKey = dateKeyFormat.format(contact.dateTracked!);
        dailyDurations.putIfAbsent(dateKey, () => []).add(contact.callDuration!);
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
  List<_UpdateChartData> _getUpdateMetricsData() {
    Map<String, int> phoneUpdates = {};
    Map<String, int> addressUpdates = {};
    Map<String, int> nextVisitUpdates = {};
    final DateFormat monthKeyFormat = DateFormat('yyyy-MM');
    for (var contact in trackedContacts) {
      if (contact.datePhoneNumberUpdated != null) {
        String monthKey = monthKeyFormat.format(contact.datePhoneNumberUpdated!);
        phoneUpdates[monthKey] = (phoneUpdates[monthKey] ?? 0) + 1;
      }
      if (contact.dateAddressChanged != null) {
        String monthKey = monthKeyFormat.format(contact.dateAddressChanged!);
        addressUpdates[monthKey] = (addressUpdates[monthKey] ?? 0) + 1;
      }
      if (contact.dateNextVisitChanged != null) {
        String monthKey = monthKeyFormat.format(contact.dateNextVisitChanged!);
        nextVisitUpdates[monthKey] = (nextVisitUpdates[monthKey] ?? 0) + 1;
      }
    }
    Set<String> allMonths = {...phoneUpdates.keys, ...addressUpdates.keys, ...nextVisitUpdates.keys};
    List<String> sortedMonths = allMonths.toList()..sort();
    List<_UpdateChartData> chartData = [];
    for (String month in sortedMonths) {
      chartData.add(_UpdateChartData(month, phoneUpdates[month] ?? 0, addressUpdates[month] ?? 0, nextVisitUpdates[month] ?? 0));
    }
    return chartData;
  }
  List<MapEntry<String, int>> _getArtStatusData() {
    Map<String, int> statusCounts = {};
    for (var contact in trackedContacts) {
      String status = contact.artStatus?.trim() ?? 'Unknown';
      if (status.isEmpty) status = 'Unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  // --- UI Helper Methods ---
  String formatDuration(int totalSeconds) {
    if (totalSeconds < 0) return 'N/A';
    if (totalSeconds == 0) return '0s';
    final int minutes = totalSeconds ~/ 60;
    final int remainingSeconds = totalSeconds % 60;
    String minuteString = minutes > 0 ? '${minutes} minute(s)' : '';
    String secondString = remainingSeconds > 0 ? ' ${remainingSeconds} second(s)' : '';
    return (minuteString + secondString).trim();
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

    final lowerStatus = status.toLowerCase();
    Color color = _getStatusColor(status);
    Widget? icon;

    if (lowerStatus.contains('answered')) {
      icon = Icon(Icons.call_received, color: color, size: 16);
    } else if (lowerStatus == 'outgoing failed' || lowerStatus == 'not answered' || lowerStatus.contains('missed')) {
      icon = Icon(Icons.phone_missed, color: color, size: 16);
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

  Map<String, List<ContactTracked>> _groupContactsByDate() {
    final Map<String, List<ContactTracked>> dailyReports = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');
    final DateFormat displayFormat = DateFormat('EEEE, MMMM d, yyyy');
    for (var contact in trackedContacts) {
      final dateKey = contact.dateTracked != null ? dateKeyFormat.format(contact.dateTracked!) : 'Unknown Date';
      dailyReports.putIfAbsent(dateKey, () => []).add(contact);
    }
    final sortedKeys = dailyReports.keys.toList()
      ..sort((a, b) {
        if (a == 'Unknown Date') return 1;
        if (b == 'Unknown Date') return -1;
        return b.compareTo(a);
      });
    final sortedMap = { for (var k in sortedKeys) k : dailyReports[k]! };
    final displayMap = <String, List<ContactTracked>>{};
    sortedMap.forEach((key, value) {
      final displayKey = key == 'Unknown Date' ? 'Unknown Tracking Date' : displayFormat.format(dateKeyFormat.parse(key));
      value.sort((c1, c2) => (c1.name ?? '').toLowerCase().compareTo((c2.name ?? '').toLowerCase()));
      displayMap[displayKey] = value;
    });
    return displayMap;
  }

  Map<String, _ClientCallSummary> _generateClientCallSummary() {
    final Map<String, _ClientCallSummary> summaryMap = {};

    for (var contact in trackedContacts) {
      final clientId = contact.uniqueID ?? 'Unknown ID';
      final clientName = contact.name ?? 'Unknown Name';
      final clientPhone = contact.phoneNumber ?? 'Unknown Phone';

      if (!summaryMap.containsKey(clientId)) {
        summaryMap[clientId] = _ClientCallSummary(
          clientId: clientId,
          clientName: clientName,
          clientPhoneNumber: clientPhone,
        );
      }

      summaryMap[clientId]!.totalCalls += 1;

      final status = contact.callStatus?.toLowerCase() ?? 'unknown';
      summaryMap[clientId]!.statusCounts[status] =
          (summaryMap[clientId]!.statusCounts[status] ?? 0) + 1;
    }

    return summaryMap;
  }

  String _formatDateWithSuffix(DateTime date) {
    String day = DateFormat('d').format(date);
    String suffix = 'th';
    int dayInt = int.parse(day);

    if (dayInt >= 11 && dayInt <= 13) {
      suffix = 'th';
    } else {
      switch (dayInt % 10) {
        case 1: suffix = 'st'; break;
        case 2: suffix = 'nd'; break;
        case 3: suffix = 'rd'; break;
        default: suffix = 'th';
      }
    }
    return DateFormat("d'$suffix'-MMMM-y").format(date);
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: SizedBox(
          width: 400,
          height: 450,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: (startDate != null && endDate != null)
                ? PickerDateRange(startDate!, endDate!)
                : null,
            showActionButtons: true,
            cancelText: 'Cancel',
            confirmText: 'Apply',
            onSubmit: (Object? value) {
              Navigator.pop(context);
              if (value is PickerDateRange && value.startDate != null) {
                setState(() {
                  startDate = value.startDate;
                  endDate = value.endDate ?? value.startDate;
                });
              } else {
                _showSnackBar('Please select both a start and end date.');
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
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
      builder: (ctx) {
        return StatefulBuilder(builder: (dialogContext, setStateDialog) {
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
                          if (tempSelected.isEmpty) {
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () {
                    onConfirm(tempSelected);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply')),
            ],
          );
        });
      },
    );
  }

  Widget _buildFilterBar() {
    String facilityButtonText = _selectedFacilities.contains('All Facilities')
        ? 'All Facilities'
        : _selectedFacilities.length == 1
        ? _selectedFacilities.first
        : '${_selectedFacilities.length} Facilities';

    String trackerButtonText = _selectedTrackers.contains('All Trackers')
        ? 'All Trackers'
        : _selectedTrackers.length == 1
        ? _selectedTrackers.first
        : '${_selectedTrackers.length} Trackers';

    String statusButtonText = _selectedCallStatuses.contains('All Statuses')
        ? 'All Statuses'
        : _selectedCallStatuses.length == 1
        ? _selectedCallStatuses.first
        : '${_selectedCallStatuses.length} Statuses';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: _isFilterLoading
            ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("Loading filters...")))
            : Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16.0,
          runSpacing: 12.0,
          alignment: WrapAlignment.start,
          children: [
            _buildFilterChip('Facility', facilityButtonText, Icons.business, () {
              _showMultiSelectDialog(
                context: context,
                title: 'Select Facilities',
                allOptions: _availableFacilities,
                selectedOptions: _selectedFacilities,
                allKeyword: 'All Facilities',
                onConfirm: (List<String> selected) {
                  setState(() {
                    _selectedFacilities = selected;
                    _selectedTrackers = ['All Trackers'];
                    _selectedCallStatuses = ['All Statuses'];
                  });
                },
              );
            }),

            _buildFilterChip('Tracked By', trackerButtonText, Icons.person_search, () {
              _showMultiSelectDialog(
                context: context,
                title: 'Select Trackers',
                allOptions: _availableTrackers,
                selectedOptions: _selectedTrackers,
                allKeyword: 'All Trackers',
                onConfirm: (List<String> selected) {
                  setState(() => _selectedTrackers = selected);
                  _applyAllFiltersAndRecalculate();
                },
              );
            }, disabled: _isInitialState),

            _buildFilterChip('Call Status', statusButtonText, Icons.phone_callback, () {
              _showMultiSelectDialog(
                context: context,
                title: 'Select Call Statuses',
                allOptions: _availableCallStatuses,
                selectedOptions: _selectedCallStatuses,
                allKeyword: 'All Statuses',
                onConfirm: (List<String> selected) {
                  setState(() => _selectedCallStatuses = selected);
                  _applyAllFiltersAndRecalculate();
                },
              );
            }, disabled: _isInitialState),

            OutlinedButton.icon(
              onPressed: isLoading ? null : _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                (startDate != null && endDate != null)
                    ? '${_formatDateWithSuffix(startDate!)} - ${_formatDateWithSuffix(endDate!)}'
                    : 'Select Date Range',
                style: const TextStyle(fontWeight: FontWeight.normal),
              ),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
            ),

            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply Filter'),
              onPressed: isLoading ? null : _loadReports,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon, VoidCallback onPressed, {bool disabled = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        InputChip(
          avatar: Icon(icon, size: 18),
          label: Text(value, overflow: TextOverflow.ellipsis),
          onPressed: disabled ? null : onPressed,
          showCheckmark: false,
          side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.7)),
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ],
    );
  }

  // --- REWRITTEN: The summary card now displays three separate costs ---
  Widget _buildSummaryInfoCard() {
    final numberFormatter = NumberFormat.compact();
    final currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final totalDuration = trackedContacts.fold<int>(0, (sum, item) => sum + (item.callDuration ?? 0));

    final int facilityCount = _selectedFacilities.contains('All Facilities')
        ? _availableFacilities.length > 0 ? _availableFacilities.length - 1 : 0
        : _selectedFacilities.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
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
                  iconWidget: Icon(Icons.location_city, color: Colors.teal.shade700, size: 36),
                  label: 'Selected Facilities',
                  value: facilityCount.toString(),
                  subtitle: _selectedFacilities.contains('All Facilities') ? 'All available' : null,
                ),
                _buildInfoTile(
                  iconWidget: Icon(Icons.call, color: Colors.blue.shade700, size: 36),
                  label: 'Total Calls Logged',
                  value: numberFormatter.format(trackedContacts.length),
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
                  subtitle: '(at ₦${_costPerSecond.toStringAsFixed(2)}/sec)',
                ),
                _buildInfoTile(
                  iconWidget: Text('₦', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  label: 'Estimated Cost (Outgoing Answered)',
                  value: currencyFormatter.format(_outgoingAnsweredCost),
                  subtitle: '(at ₦${_costPerSecond.toStringAsFixed(2)}/sec)',
                ),
                _buildInfoTile(
                  iconWidget: Text('₦', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.lightGreen.shade700)),
                  label: 'Estimated Cost (Incoming Answered)',
                  value: currencyFormatter.format(_incomingAnsweredCost),
                  subtitle: '(at ₦${_costPerSecond.toStringAsFixed(2)}/sec)',
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({required Widget iconWidget, required String label, required String value, String? subtitle}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<ContactTracked>> dailyGroupedReports = _groupContactsByDate();
    final dailyGroupedKeys = dailyGroupedReports.keys.toList();
    final Map<String, _ClientCallSummary> clientSummaryMap = _generateClientCallSummary();

    Widget bodyContent;

    if (_errorMessage != null) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ),
      );
    } else {
      bodyContent = SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isInitialState)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Displaying reports for: ${_selectedFacilities.join(", ")}\nFrom ${_formatDateWithSuffix(startDate!)} to ${_formatDateWithSuffix(endDate!)}',
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                ),

              if (!_isInitialState && !isLoading) _buildSummaryInfoCard(),

              Text('Summary Charts', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 20.0,
                runSpacing: 20.0,
                alignment: WrapAlignment.start,
                children: [
                  _buildChartCard(
                    title: 'Call Status Distribution',
                    chartKey: _callStatusChartKey,
                    chart: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SfCircularChart(
                        annotations: (callStatusChartData.isEmpty && !_isInitialState) ? const <CircularChartAnnotation>[CircularChartAnnotation(widget: Text("No data"))] : null,
                        legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                        series: <CircularSeries>[
                          PieSeries<MapEntry<String, int>, String>(
                            dataSource: callStatusChartData,
                            xValueMapper: (d, _) => d.key,
                            yValueMapper: (d, _) => d.value,
                            dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside),
                            radius: '80%',
                          )
                        ]),
                  ),
                  _buildChartCard(
                    title: 'ART Status Distribution',
                    chartKey: _artStatusChartKey,
                    chart: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SfCircularChart(
                        annotations: (artStatusChartData.isEmpty && !_isInitialState) ? const <CircularChartAnnotation>[CircularChartAnnotation(widget: Text("No data"))] : null,
                        legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                        series: <CircularSeries>[
                          PieSeries<MapEntry<String, int>, String>(
                            dataSource: artStatusChartData,
                            xValueMapper: (d, _) => d.key,
                            yValueMapper: (d, _) => d.value,
                            dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside),
                            radius: '80%',
                          )
                        ]),
                  ),
                  _buildChartCard(
                    title: 'Average Call Duration Trend (Daily)',
                    isWide: true,
                    chartKey: _callDurationChartKey,
                    chart: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SfCartesianChart(
                        annotations: (callDurationTrendData.isEmpty && !_isInitialState)
                            ? const <CartesianChartAnnotation>[CartesianChartAnnotation(widget: Text("No data"), coordinateUnit: CoordinateUnit.point, region: AnnotationRegion.chart, x: '50%', y: '50%')]
                            : null,
                        primaryXAxis: const CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Date Tracked'), majorGridLines: MajorGridLines(width: 0)),
                        primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Avg. Duration (Seconds)'), numberFormat: NumberFormat.compact()),
                        tooltipBehavior: TooltipBehavior(enable: true),
                        series: <CartesianSeries<dynamic, dynamic>>[
                          LineSeries<_ChartDataPoint, String>(
                            dataSource: callDurationTrendData,
                            xValueMapper: (data, _) => DateFormat('MMM d').format(DateFormat('yyyy-MM-dd').parse(data.x)),
                            yValueMapper: (data, _) => data.y,
                            name: 'Avg Duration',
                            markerSettings: const MarkerSettings(isVisible: true),
                          )
                        ]),
                  ),
                  _buildChartCard(
                    title: 'Monthly Update Trends',
                    isWide: true,
                    chartKey: _updateMetricsChartKey,
                    chart: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SfCartesianChart(
                        annotations: (updateMetricsData.isEmpty && !_isInitialState)
                            ? const <CartesianChartAnnotation>[CartesianChartAnnotation(widget: Text("No data"), coordinateUnit: CoordinateUnit.point, region: AnnotationRegion.chart, x: '50%', y: '50%')]
                            : null,
                        primaryXAxis: const CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Month'), majorGridLines: MajorGridLines(width: 0)),
                        primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Number of Updates'), majorTickLines: MajorTickLines(size: 0)),
                        legend: const Legend(isVisible: true, position: LegendPosition.top, overflowMode: LegendItemOverflowMode.wrap),
                        tooltipBehavior: TooltipBehavior(enable: true, shared: true),
                        series: <CartesianSeries<dynamic, dynamic>>[
                          LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d, _) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d, _) => d.phoneUpdates, name: 'Phone Updates', markerSettings: const MarkerSettings(isVisible: true)),
                          LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d, _) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d, _) => d.addressUpdates, name: 'Address Updates', markerSettings: const MarkerSettings(isVisible: true)),
                          LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d, _) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d, _) => d.nextVisitUpdates, name: 'Next Visit Updates', markerSettings: const MarkerSettings(isVisible: true)),
                        ]),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              if (!isLoading && clientSummaryMap.isNotEmpty) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Summary of Calls per Client',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Visibility(
                          visible: _isClientSummaryExpanded,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                tooltip: 'Scroll Left',
                                onPressed: () {
                                  _clientSummaryScrollController.animateTo(
                                    _clientSummaryScrollController.offset - 350,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                tooltip: 'Scroll Right',
                                onPressed: () {
                                  _clientSummaryScrollController.animateTo(
                                    _clientSummaryScrollController.offset + 350,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    initiallyExpanded: _isClientSummaryExpanded,
                    onExpansionChanged: (isExpanded) {
                      setState(() {
                        _isClientSummaryExpanded = isExpanded;
                      });
                    },
                    children: [
                      SingleChildScrollView(
                        controller: _clientSummaryScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: DataTable(
                            columnSpacing: 15.0,
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                            columns: const [
                              DataColumn(label: Text('Client ART ID')),
                              DataColumn(label: Text('Client Name')),
                              DataColumn(label: Text('Client Phone')),
                              DataColumn(label: Text('Total Calls')),
                              DataColumn(label: Text('Call Status Summary')),
                            ],
                            rows: clientSummaryMap.values.map((summary) {
                              final statusSummary = summary.statusCounts.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(', ');

                              return DataRow(cells: [
                                DataCell(Text(_maskClientName(summary.clientId))),
                                DataCell(Text(_maskClientName(summary.clientName))),
                                DataCell(Text(_maskPhoneNumber(summary.clientPhoneNumber))),
                                DataCell(Text(summary.totalCalls.toString())),
                                DataCell(Text(statusSummary)),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],

              Text('Detailed Call Logs', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),

              if (isLoading)
                const Card(elevation: 2, child: SizedBox(height: 200, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Loading Detailed Logs...")]))))
              else if (_isInitialState || dailyGroupedReports.isEmpty)
                Card(
                  elevation: 2,
                  child: Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: Text(
                      _isInitialState ? "Apply a filter to view detailed logs." : "No detailed logs found for the selected criteria.",
                      style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                ExpansionPanelList(
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      _currentlyExpandedDateIndex = _currentlyExpandedDateIndex == index ? -1 : index;
                    });
                  },
                  animationDuration: const Duration(milliseconds: 300),
                  children: dailyGroupedKeys.map<ExpansionPanel>((String dateKey) {
                    final index = dailyGroupedKeys.indexOf(dateKey);
                    final dailyContactList = dailyGroupedReports[dateKey]!;
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
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back),
                                      tooltip: 'Scroll Left',
                                      onPressed: () {
                                        _logTableControllers[index].animateTo(_logTableControllers[index].offset - 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_forward),
                                      tooltip: 'Scroll Right',
                                      onPressed: () {
                                        _logTableControllers[index].animateTo(_logTableControllers[index].offset + 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                                      },
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
                            columnSpacing: 15.0,
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                            columns: const [
                              DataColumn(label: Text('Client Name')), DataColumn(label: Text('Client PhoneNo')), DataColumn(label: Text('Client ART Status')),
                              DataColumn(label: Text("Client's Facility")), DataColumn(label: Text('Client State')), DataColumn(label: Text('Client ART ID')),
                              DataColumn(label: Text('DatimCode')), DataColumn(label: Text('Time Tracked')), DataColumn(label: Text('Call Status')),
                              DataColumn(label: Text('Duration')), DataColumn(label: Text('Tracked By')), DataColumn(label: Text("Tracker's Designation")),
                              DataColumn(label: Text("Tracker's Facility")), DataColumn(label: Text("Tracker's Supervisor")), DataColumn(label: Text("Tracker's Supervisor Email")),
                            ],
                            rows: dailyContactList.map((contact) {
                              return DataRow(cells: [
                                DataCell(Text(_maskClientName(contact.name))),
                                DataCell(Text(_maskPhoneNumber(contact.phoneNumber))),
                                DataCell(Text(contact.artStatus ?? 'N/A')),
                                DataCell(Text(contact.facilityName ?? 'N/A')),
                                DataCell(Text(contact.state ?? 'N/A')),
                                DataCell(Text(_maskClientName(contact.uniqueID))),
                                DataCell(Text(contact.datimCode ?? 'N/A')),
                                DataCell(Text(contact.dateTracked != null ? DateFormat('HH:mm').format(contact.dateTracked!) : 'N/A')),
                                DataCell(_buildStatusCell(contact.callStatus)),
                                DataCell(Text(contact.callDuration != null ? formatDuration(contact.callDuration!) : 'N/A')),
                                DataCell(Text(contact.trackedBy ?? 'N/A')),
                                DataCell(Text(contact.designation ?? 'N/A')),
                                DataCell(Text(contact.trackerFacilityLocation ?? 'N/A')),
                                DataCell(Text(contact.supervisorName ?? 'N/A')),
                                DataCell(Text(contact.supervisorEmail ?? 'N/A')),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      );
    }

    String appBarTitle;
    if (_isInitialState) {
      appBarTitle = 'Call Tracking Reports';
    } else {
      appBarTitle = _selectedFacilities.contains("All Facilities")
          ? 'Report for All Facilities'
          : _selectedFacilities.length > 2
          ? 'Report for ${_selectedFacilities.length} Facilities'
          : 'Report for: ${_selectedFacilities.join(", ")}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: _allCellsGloballyUnlocked ? 'Mask Sensitive Data' : 'Unmask Sensitive Data',
            icon: Icon(_allCellsGloballyUnlocked ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: (isLoading || _isFilterLoading) ? null : _toggleGlobalUnmask,
          ),
          IconButton(
            tooltip: 'Filter by Date Range',
            icon: const Icon(Icons.date_range_outlined),
            onPressed: (isLoading || _isFilterLoading) ? null : _showDateRangePicker,
          ),
          if (_isExporting)
            const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: "Export Options",
              onSelected: (value) async {
                if (value == 'csv') await _exportToCSV();
                else if (value == 'pdf') await _exportToPDF();
              },
              enabled: !isLoading && !_isInitialState && trackedContacts.isNotEmpty,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'csv',
                  child: Row(children: [Icon(Icons.grid_on_outlined, color: Colors.green[700]), const SizedBox(width: 8), const Text('Export CSV (Detailed Logs)')]),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(children: [Icon(Icons.picture_as_pdf_outlined, color: Colors.red[700]), const SizedBox(width: 8), const Text('Export PDF (Charts)')]),
                ),
              ],
            ),
        ],
      ),
      drawer: drawer2(context),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_isFilterLoading) const Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget chart, GlobalKey? chartKey, bool isWide = false}) {
    Widget chartWithBoundary = RepaintBoundary(key: chartKey, child: chart);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isWide ? 600 : 400),
      child: Card(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              SizedBox(height: 250, child: chartWithBoundary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartDataPoint {
  final String x;
  final double y;
  _ChartDataPoint(this.x, this.y);
}

class _UpdateChartData {
  final String month;
  final int phoneUpdates;
  final int addressUpdates;
  final int nextVisitUpdates;
  _UpdateChartData(this.month, this.phoneUpdates, this.addressUpdates, this.nextVisitUpdates);
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