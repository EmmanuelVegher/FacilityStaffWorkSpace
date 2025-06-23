// NEW: Import dart:html for web downloads and other necessary packages
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

import '../../models/contact_tracked.dart';
import '../../widgets/drawer.dart';

// NEW: Add GlobalKeys to capture chart images for PDF export
final GlobalKey _callStatusChartKey = GlobalKey();
final GlobalKey _artStatusChartKey = GlobalKey();
final GlobalKey _callDurationChartKey = GlobalKey();
final GlobalKey _updateMetricsChartKey = GlobalKey();


class ReportsPageWeb extends StatefulWidget {
  const ReportsPageWeb({super.key});

  @override
  _ReportsPageWebState createState() => _ReportsPageWebState();
}

class _ReportsPageWebState extends State<ReportsPageWeb> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // NEW: State variables for call cost calculation
  double _totalCallCost = 0.0;
  final double _costPerSecond = 0.23; // 0.24 Naira per second

  List<ContactTracked> trackedContacts = [];
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = true;
  bool _isUserBioLoading = true;
  String? _errorMessage;

  // NEW: State variables for masking and exporting
  bool _allCellsGloballyUnlocked = false;
  bool _isExporting = false;

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
    _loadContacts(start: startDate, end: endDate);
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

      final docSnapshot = await _firestore.collection('Staff').doc(currentUserAuthId).get();

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
        throw Exception("User bio data not found in Firestore 'Staff' collection.");
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

  // Future<void> _loadContacts1({DateTime? start, DateTime? end}) async {
  //   if (_isUserBioLoading || currentUserAuthId == null || userState == null || userLocation == null) {
  //     if (!_isUserBioLoading && mounted) {
  //       setState(() {
  //         isLoading = false;
  //         _errorMessage = _errorMessage ?? "Cannot load reports: User details (State/Facility) missing.";
  //         trackedContacts = [];
  //         _prepareChartData();
  //       });
  //     } else if (mounted) {
  //       setState(() { isLoading = true; });
  //     }
  //     return;
  //   }
  //   if (start == null || end == null) {
  //     if (mounted) {
  //       setState(() {
  //         isLoading = false;
  //         trackedContacts = [];
  //         _prepareChartData();
  //         _errorMessage = "Please select a date range to load reports.";
  //       });
  //     }
  //     return;
  //   }
  //
  //   setState(() {
  //     isLoading = true;
  //     _errorMessage = null;
  //     trackedContacts = [];
  //   });
  //
  //   List<ContactTracked> fetchedContacts = [];
  //   DateTime currentDate = start;
  //   final DateFormat pathDateFormat = DateFormat('dd-MMM-yyyy');
  //
  //   try {
  //     while (currentDate.isBefore(end.add(const Duration(days: 1)))) {
  //       String formattedDate = pathDateFormat.format(currentDate);
  //       String dailyUserCollectionPath = '/Reports/$userState/CallTracker/$userLocation/$formattedDate/$currentUserAuthId/$currentUserAuthId';
  //
  //       try {
  //         QuerySnapshot dailySnapshot = await _firestore.collection(dailyUserCollectionPath).get();
  //         for (var doc in dailySnapshot.docs) {
  //           if (doc.exists && doc.data() != null) {
  //             fetchedContacts.add(ContactTracked.fromFirestore(doc.data() as Map<String, dynamic>, doc.id));
  //           }
  //         }
  //       } catch (dailyError) {
  //         // This error is expected if no calls were made on a given day.
  //         // print("No data for path $dailyUserCollectionPath or error: $dailyError");
  //       }
  //       currentDate = currentDate.add(const Duration(days: 1));
  //     }
  //
  //     if (mounted) {
  //       setState(() {
  //         trackedContacts = fetchedContacts;
  //         _prepareChartData();
  //         isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() {
  //         isLoading = false;
  //         _errorMessage = "Error loading reports: $e";
  //         trackedContacts = [];
  //         _prepareChartData();
  //       });
  //     }
  //   }
  // }

  // In _ReportsPageWebState class

  /// Fetches contact logs for the current user from the flattened 'CallLogs' collection within a specific date range.
// In _ReportsPageWebState class

  /// Fetches contact logs for the current user from the flattened 'CallLogs' collection
  /// for the specified date range.
  // In _ReportsPageWebState class

  /// Fetches contact logs and calculates the estimated call cost.
  Future<void> _loadContacts({DateTime? start, DateTime? end}) async {
    // 1. Guard against running without necessary information.
    if (_isUserBioLoading || currentUserAuthId == null) {
      if (!_isUserBioLoading && mounted) {
        setState(() { isLoading = false; _errorMessage = "Cannot load reports: User details are missing."; });
      }
      return;
    }
    if (start == null || end == null) {
      if (mounted) {
        setState(() { isLoading = false; trackedContacts = []; _prepareChartData(); _errorMessage = "Please select a date range."; });
      }
      return;
    }

    // 2. Set the UI to a loading state and reset previous data.
    setState(() {
      isLoading = true;
      _errorMessage = null;
      trackedContacts = [];
      _totalCallCost = 0.0; // Reset the cost for a new query
    });

    try {
      // 3. Execute the Firestore query.
      final QuerySnapshot querySnapshot = await _firestore
          .collection('CallLogs')
          .where('firebaseAuthId', isEqualTo: currentUserAuthId)
          .where('dateTracked', isGreaterThanOrEqualTo: start)
          .where('dateTracked', isLessThanOrEqualTo: end.add(const Duration(days: 1)))
          .orderBy('dateTracked', descending: true)
          .get();

      // 4. Process the results.
      final List<ContactTracked> fetchedContacts = querySnapshot.docs.map((doc) {
        return ContactTracked.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      // --- THIS IS THE NEW CALCULATION LOGIC ---
      int totalDurationInSeconds = fetchedContacts.fold(0, (sum, contact) => sum + (contact.callDuration ?? 0));
      double calculatedCost = totalDurationInSeconds * _costPerSecond;
      // ------------------------------------------

      // 5. Update the UI with the fetched data and the calculated cost.
      if (mounted) {
        setState(() {
          trackedContacts = fetchedContacts;
          _totalCallCost = calculatedCost; // Set the calculated cost
          _prepareChartData();
          isLoading = false;
        });
      }
    } catch (e) {
      // 6. Handle any errors.
      if (mounted) {
        setState(() {
          isLoading = false;
          _errorMessage = "Error loading reports: $e";
          trackedContacts = [];
          _totalCallCost = 0.0; // Reset cost on error
          _prepareChartData();
        });
      }
      print("Error loading reports: $e");
    }
  }

  // Add these two methods inside the _ReportsPageWebState class

  // Add these two methods inside the _ReportsPageWebState class

  Widget _buildSummaryInfoCard() {
    final currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final numberFormatter = NumberFormat.compact();
    final totalDuration = trackedContacts.fold<int>(0, (sum, item) => sum + (item.callDuration ?? 0));

    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 20.0,
          runSpacing: 16.0,
          children: [
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
            // _buildInfoTile(
            //   iconWidget: Text(
            //     '₦',
            //     style: TextStyle(
            //       fontSize: 36,
            //       fontWeight: FontWeight.bold,
            //       color: Colors.green.shade800,
            //     ),
            //   ),
            //   label: 'Estimated Call Cost',
            //   value: currencyFormatter.format(_totalCallCost),
            //   subtitle: '(at ₦${_costPerSecond}/sec)',
            // ),
          ],
        ),
      ),
    );
  }

// Helper for the summary card tiles
  Widget _buildInfoTile({
    required Widget iconWidget,
    required String label,
    required String value,
    String? subtitle,
  }) {
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
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _prepareChartData() {
    callStatusChartData = _getCallStatusData();
    callDurationTrendData = _getCallDurationTrendData();
    updateMetricsData = _getUpdateMetricsData();
    artStatusChartData = _getArtStatusData();
  }

  // --- MASKING AND UNMASKING METHODS (NEW) ---

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _maskClientName(String? name) {
    if (_allCellsGloballyUnlocked || name == null || name.isEmpty) return name ?? 'N/A';
    List<String> parts = name.split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? '${parts[0][0]}. (Hidden)' : 'Hidden';
  }

  String _maskPhoneNumber(String? phone) {
    if (_allCellsGloballyUnlocked || phone == null || phone.isEmpty) return phone ?? 'N/A';
    return phone.length > 4 ? '...${phone.substring(phone.length - 4)}' : phone.replaceAll(RegExp(r'.'), '*');
  }

  Future<bool> _promptForPasswordAndReauthenticate() async {
    final passwordController = TextEditingController();
    final user = _auth.currentUser;

    if (user == null) {
      _showSnackBar("Not signed in. Cannot perform action.");
      return false;
    }
    if (user.email == null) {
      _showSnackBar("User email is not available for password authentication.");
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

  // --- EXPORT METHODS (NEW) ---

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
          // Use masking functions for sensitive data
          _allCellsGloballyUnlocked ? (contact.name ?? 'N/A') : _maskClientName(contact.name),
          _allCellsGloballyUnlocked ? (contact.phoneNumber ?? 'N/A') : _maskPhoneNumber(contact.phoneNumber),
          contact.artStatus ?? 'N/A',
          contact.facilityName ?? 'N/A',
          contact.state ?? 'N/A',
          contact.uniqueID ?? 'N/A',
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
      ui.Image image = await boundary.toImage(pixelRatio: 2.5); // Higher pixel ratio for better quality
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
      // Capture all chart images
      final Uint8List? callStatusBytes = await _captureChartPng(_callStatusChartKey);
      final Uint8List? artStatusBytes = await _captureChartPng(_artStatusChartKey);
      final Uint8List? callDurationBytes = await _captureChartPng(_callDurationChartKey);
      final Uint8List? updateMetricsBytes = await _captureChartPng(_updateMetricsChartKey);

      final pw.MemoryImage? callStatusImg = callStatusBytes != null ? pw.MemoryImage(callStatusBytes) : null;
      final pw.MemoryImage? artStatusImg = artStatusBytes != null ? pw.MemoryImage(artStatusBytes) : null;
      final pw.MemoryImage? callDurationImg = callDurationBytes != null ? pw.MemoryImage(callDurationBytes) : null;
      final pw.MemoryImage? updateMetricsImg = updateMetricsBytes != null ? pw.MemoryImage(updateMetricsBytes) : null;

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
              text: 'Report for: ${userFirstName ?? ''} ${userLastName ?? ''} at ${userLocation ?? 'N/A'}\n'
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

  // --- Chart Data Preparation Functions (Keep as is) ---
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

  // --- Other Helper Functions (Keep as is) ---
  String formatDuration(int totalSeconds) {
    if (totalSeconds < 0) return 'N/A';
    if (totalSeconds == 0) return '0 Seconds';
    final int minutes = totalSeconds ~/ 60;
    final int remainingSeconds = totalSeconds % 60;
    String minuteString = minutes > 0 ? '$minutes minute${minutes > 1 ? 's' : ''}' : '';
    String secondString = remainingSeconds > 0 ? '$remainingSeconds second${remainingSeconds > 1 ? 's' : ''}' : '';
    if (minuteString.isNotEmpty && secondString.isNotEmpty) return '$minuteString $secondString';
    return minuteString.isNotEmpty ? minuteString : secondString;
  }
  Color _getStatusColor(String status) {
    String lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'answered': case 'completed': return Colors.green.shade700;
      case 'missed': case 'missed call': case 'not answered': case 'call failed': case 'call dropped': return Colors.red.shade700;
      case 'call busy': return Colors.orange.shade700;
      case 'unknown (no log detail)': case 'n/a': case 'unknown': return Colors.grey.shade600;
      default: return Colors.blue.shade700;
    }
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
  void _showDateRangePicker(BuildContext context) {
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
              if (value is PickerDateRange && value.startDate != null && value.endDate != null) {
                setState(() {
                  startDate = value.startDate;
                  endDate = value.endDate;
                });
                Navigator.pop(context);
                _loadContacts(start: startDate, end: endDate);
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select both a start and end date.')),
                );
              }
            },
            onCancel: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final Map<String, List<ContactTracked>> dailyGroupedReports = (isLoading || _isUserBioLoading) ? {} : _groupContactsByDate();
    Widget bodyContent;

    if (_isUserBioLoading) {
      bodyContent = const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Loading user details...")],
      ));
    } else if (isLoading) {
      bodyContent = const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Loading reports...")],
      ));
    } else if (_errorMessage != null) {
      bodyContent = Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,),
      ));
    } else if (trackedContacts.isEmpty) {
      bodyContent = Center(
          child: Text(
            startDate == null
                ? 'Please select a date range to view reports.'
                : 'No tracked contacts found for the selected period.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          )
      );
    } else {
      bodyContent = SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (startDate != null && endDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Displaying data for ${userFirstName ?? ''} ${userLastName ?? ''} (${userLocation ?? 'N/A Facility'}) from ${DateFormat.yMd().format(startDate!)} to ${DateFormat.yMd().format(endDate!)}',
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                ),

              // NEW: Add the summary card here
              _buildSummaryInfoCard(),

              // --- Charts Section ---
              Text('Summary Charts', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 20.0,
                runSpacing: 20.0,
                alignment: WrapAlignment.start,
                children: [
                  if (callStatusChartData.isNotEmpty)
                    _buildChartCard(
                      title: 'Call Status Distribution',
                      chartKey: _callStatusChartKey, // NEW: Pass key
                      chart: SfCircularChart(
                          legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                          series: <CircularSeries>[ PieSeries<MapEntry<String, int>, String>(
                            dataSource: callStatusChartData, xValueMapper: (d,_) => d.key, yValueMapper: (d,_) => d.value,
                            dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside),
                            radius: '80%',
                          )]
                      ),
                    ),
                  if (artStatusChartData.isNotEmpty)
                    _buildChartCard(
                      title: 'ART Status Distribution',
                      chartKey: _artStatusChartKey, // NEW: Pass key
                      chart: SfCircularChart(
                          legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                          series: <CircularSeries>[ PieSeries<MapEntry<String, int>, String>(
                            dataSource: artStatusChartData, xValueMapper: (d,_) => d.key, yValueMapper: (d,_) => d.value,
                            dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside),
                            radius: '80%',
                          )]
                      ),
                    ),
                  if (callDurationTrendData.isNotEmpty)
                    _buildChartCard(
                      title: 'Average Call Duration Trend (Daily)',
                      isWide: true, // NEW: Make it wider
                      chartKey: _callDurationChartKey, // NEW: Pass key
                      chart: SfCartesianChart(
                          primaryXAxis: const CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Date Tracked'), majorGridLines: MajorGridLines(width: 0)),
                          primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Avg. Duration (Seconds)'), numberFormat: NumberFormat.compact()),
                          tooltipBehavior: TooltipBehavior(enable: true),
                          series: <CartesianSeries<dynamic, dynamic>>[ LineSeries<_ChartDataPoint, String>(
                            dataSource: callDurationTrendData,
                            xValueMapper: (data, _) => DateFormat('MMM d').format(DateFormat('yyyy-MM-dd').parse(data.x)),
                            yValueMapper: (data, _) => data.y,
                            name: 'Avg Duration', markerSettings: const MarkerSettings(isVisible: true),
                          )]
                      ),
                    ),
                  if (updateMetricsData.isNotEmpty)
                    _buildChartCard(
                      title: 'Monthly Update Trends',
                      isWide: true, // NEW: Make it wider
                      chartKey: _updateMetricsChartKey, // NEW: Pass key
                      chart: SfCartesianChart(
                          primaryXAxis: const CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Month'), majorGridLines: MajorGridLines(width: 0)),
                          primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Number of Updates'), majorTickLines: MajorTickLines(size: 0)),
                          legend: const Legend(isVisible: true, position: LegendPosition.top, overflowMode: LegendItemOverflowMode.wrap),
                          tooltipBehavior: TooltipBehavior(enable: true, shared: true),
                          series: <CartesianSeries<dynamic, dynamic>>[
                            LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d,_) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d,_) => d.phoneUpdates, name: 'Phone Updates', markerSettings: const MarkerSettings(isVisible: true)),
                            LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d,_) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d,_) => d.addressUpdates, name: 'Address Updates', markerSettings: const MarkerSettings(isVisible: true)),
                            LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d,_) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d,_) => d.nextVisitUpdates, name: 'Next Visit Updates', markerSettings: const MarkerSettings(isVisible: true)),
                          ]
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 30),

              // --- Data Table Section ---
              Text('Detailed Logs', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              if (dailyGroupedReports.isEmpty && !(isLoading || _isUserBioLoading))
                const Center(child: Text('No detailed logs found for the selected period.'))
              else if (!isLoading && !_isUserBioLoading)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dailyGroupedReports.keys.length,
                  itemBuilder: (context, index) {
                    final displayDateKey = dailyGroupedReports.keys.elementAt(index);
                    final dailyContactList = dailyGroupedReports[displayDateKey]!;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        title: Text(displayDateKey, style: const TextStyle(fontWeight: FontWeight.bold)),
                        initiallyExpanded: index == 0,
                        children: <Widget>[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: DataTable(
                                columnSpacing: 15.0,
                                headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                                columns: const [
                                  DataColumn(label: Text('Client Name')),
                                  DataColumn(label: Text('Client PhoneNo')),
                                  DataColumn(label: Text('Client ART Status')),
                                  DataColumn(label: Text("Client's Facility")),
                                  DataColumn(label: Text('Client State')),
                                  DataColumn(label: Text('Client ART ID')),
                                  DataColumn(label: Text('DatimCode')),
                                  DataColumn(label: Text('Time Tracking Done')),
                                  DataColumn(label: Text('Call Status')),
                                  DataColumn(label: Text('Duration of Call')),
                                  DataColumn(label: Text('Tracked By')),
                                  DataColumn(label: Text("Tracker's Designation")),
                                  DataColumn(label: Text("Tracker's Facility")),
                                  DataColumn(label: Text("Tracker's Supervisor")),
                                  DataColumn(label: Text("Tracker's Supervisor Email")),
                                ],
                                rows: dailyContactList.map((contact) {
                                  return DataRow(cells: [
                                    DataCell(Text(_maskClientName(contact.name))), // MODIFIED
                                    DataCell(Text(_maskPhoneNumber(contact.phoneNumber))), // MODIFIED
                                    DataCell(Text(contact.artStatus ?? 'N/A')),
                                    DataCell(Text(contact.facilityName ?? 'N/A')),
                                    DataCell(Text(contact.state ?? 'N/A')),
                                    DataCell(Text(contact.uniqueID ?? 'N/A')),
                                    DataCell(Text(contact.datimCode ?? 'N/A')),
                                    DataCell(Text(contact.dateTracked != null ? DateFormat('HH:mm').format(contact.dateTracked!) : 'N/A')),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: contact.callStatus != null ? _getStatusColor(contact.callStatus!).withOpacity(0.2) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4)
                                      ),
                                      child: Text(contact.callStatus ?? 'N/A', style: TextStyle(
                                          color: contact.callStatus != null ? _getStatusColor(contact.callStatus!) : Colors.black87,
                                          fontWeight: FontWeight.w500
                                      )),
                                    )),
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
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }

    // --- Scaffold ---
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Reports',style: TextStyle(color: Colors.white,),),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: _allCellsGloballyUnlocked ? 'Mask Sensitive Data' : 'Unmask Sensitive Data',
            icon: Icon(_allCellsGloballyUnlocked ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: (isLoading || _isUserBioLoading) ? null : _toggleGlobalUnmask,
          ),
          IconButton(
            tooltip: 'Filter by Date Range',
            icon: const Icon(Icons.filter_list),
            onPressed: (isLoading || _isUserBioLoading) ? null : () => _showDateRangePicker(context),
          ),
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh),
            onPressed: (isLoading || _isUserBioLoading) ? null : () => _loadContacts(start: startDate, end: endDate),
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
                if (value == 'csv') await _exportToCSV();
                else if (value == 'pdf') await _exportToPDF();
              },
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
      drawer: drawer(context),
      body: bodyContent,
    );
  }

  Widget _buildChartCard({required String title, required Widget chart, GlobalKey? chartKey, bool isWide = false}) {
    // MODIFIED: Wrap chart in RepaintBoundary and constrain width
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
              SizedBox(
                height: 250,
                child: chartWithBoundary, // Use the chart with the boundary
              ),
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