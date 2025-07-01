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
  String? _selectedFacility;
  List<String> _availableFacilities = [];

  // User Bio Details
  String? userFirstName;
  String? userLastName;
  String? userDesignation;
  String? userState;

  // NEW: Add a ScrollController for the detailed log table
  final ScrollController _logTableController = ScrollController();

  // Chart Data Holders
  List<MapEntry<String, int>> callStatusChartData = [];
  List<_ChartDataPoint> callDurationTrendData = [];
  List<_UpdateChartData> updateMetricsData = [];
  List<MapEntry<String, int>> artStatusChartData = [];

  // --- NEW State variables for extra filters and calculations ---
  List<ContactTracked> _masterContactList = []; // Holds all data from Firestore before final filtering
  List<String> _availableTrackers = ['All Trackers'];
  String _selectedTracker = 'All Trackers';
  double _totalCallCost = 0.0;
  final double _costPerSecond = 0.23; // Call cost rate as specified

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
    // NEW: Dispose of the controller
    _logTableController.dispose();
    super.dispose();
  }

  // In _ReportsPageWeb2State class

  /// Populates the tracker dropdown list from the master data.
// In _ReportsPageWeb2State class

  /// Populates the tracker dropdown list from the master data.
  void _updateAvailableTrackers() {
    if (_masterContactList.isEmpty) {
      setState(() {
        _availableTrackers = ['All Trackers'];
        _selectedTracker = 'All Trackers';
      });
      return;
    }

    // Use a Set to get unique tracker names from the fetched data
    final trackers = _masterContactList
        .map((contact) => contact.trackedBy) // 1. Get an Iterable<String?>
        .whereType<String>()                 // 2. Filter out nulls AND get a type-safe Iterable<String>
        .where((name) => name.isNotEmpty)   // 3. Now safely filter out empty strings
        .toSet();                           // 4. This results in a Set<String>

    setState(() {
      // This assignment is now type-safe because 'trackers' is a Set<String>
      _availableTrackers = ['All Trackers', ...trackers.toList()..sort()];

      // If the previously selected tracker is no longer in the list after a refresh, reset it.
      if (!_availableTrackers.contains(_selectedTracker)) {
        _selectedTracker = 'All Trackers';
      }
    });
  }

  /// Applies the selected tracker filter to the master list and recalculates all metrics.
  // In _ReportsPageWeb2State class

  /// Applies the selected tracker filter to the master list and recalculates all metrics.
  void _applyTrackerAndRecalculate() {
    List<ContactTracked> filteredList;

    // Filter the master list based on the selected tracker
    if (_selectedTracker != 'All Trackers') {
      filteredList = _masterContactList.where((c) => c.trackedBy == _selectedTracker).toList();
    } else {
      // If 'All Trackers' is selected, use the whole master list
      filteredList = List.from(_masterContactList);
    }

    // Calculate total call cost based on the *final filtered* list
    int totalDurationInSeconds = filteredList.fold(0, (sum, contact) => sum + (contact.callDuration ?? 0));

    // --- CALCULATION UPDATED ---
    // The cost is now total seconds multiplied by the cost per second.
    double calculatedCost = totalDurationInSeconds * _costPerSecond;

    setState(() {
      trackedContacts = filteredList; // This is the list the UI will display
      _totalCallCost = calculatedCost;
      _prepareChartData(); // Re-run chart calculations on the final filtered data
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
      final snapshot = await _firestore.collection('Location').doc(state).collection(state).get();
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
      _showSnackBar("Error fetching facility list: $e");
      return [];
    }
  }

  // --- NEW, ROBUST DATA LOADING METHOD BASED ON EXACT PATH ---
// --- CORRECTED DATA LOADING METHOD ---
// This version precisely matches your path: .../{facilityName}/{formattedDate}/{user_id}/{user_id}/{uuid}
// --- NEW ROBUST DATA LOADING METHOD ---
// This version avoids the "ghost document" problem by first fetching a list of users.
// --- THE NEW, FAST & SIMPLE DATA LOADING METHOD ---
// This works because the `_syncPendingRecords` fix creates real, queryable documents.

//   Future<void> _loadReports() async {
//     if (_selectedFacility == null) {
//       _showSnackBar("Please select a facility to generate a report.");
//       return;
//     }
//     if (startDate == null || endDate == null) {
//       _showSnackBar("Please select a valid date range.");
//       return;
//     }
//     if (userState == null) {
//       _showSnackBar("Cannot load reports: User state is missing.");
//       return;
//     }
//
//     setState(() {
//       isLoading = true;
//       _isInitialState = false;
//       _errorMessage = null;
//       trackedContacts.clear();
//     });
//
//     try {
//       List<String> facilitiesToQuery;
//       if (_selectedFacility == 'All Facilities') {
//         facilitiesToQuery = List.from(_availableFacilities)..remove('All Facilities');
//       } else {
//         facilitiesToQuery = [_selectedFacility!];
//       }
//
//       List<ContactTracked> fetchedContacts = [];
//       final DateFormat pathDateFormat = DateFormat('dd-MMM-yyyy');
//
//       // Loop 1: Iterate through each selected facility
//       for (final facility in facilitiesToQuery) {
//         final String facilityName = facility.trim();
//
//         DateTime currentDate = startDate!;
//         // Loop 2: Iterate through each day in the date range
//         while (currentDate.isBefore(endDate!.add(const Duration(days: 1)))) {
//           String formattedDate = pathDateFormat.format(currentDate);
//
//           try {
//             // 1. Get a reference to the collection of USERS for that day
//             CollectionReference usersCollectionRef = _firestore
//                 .collection('Reports')
//                 .doc(userState!)
//                 .collection('CallTracker')
//                 .doc(facilityName)
//                 .collection(formattedDate); // The date is a collection
//
//             // 2. Get all REAL documents from that date collection. This will now work!
//             QuerySnapshot userSnapshot = await usersCollectionRef.get();
//
//             // Loop 3: Iterate through each user document found for that day
//             for (final userDoc in userSnapshot.docs) {
//               String userId = userDoc.id;
//
//               // 3. Get the sub-collection of calls
//               CollectionReference callsCollectionRef = userDoc.reference.collection(userId);
//
//               QuerySnapshot callsSnapshot = await callsCollectionRef.get();
//               for (var callDoc in callsSnapshot.docs) {
//                 if (callDoc.exists && callDoc.data() != null) {
//                   fetchedContacts.add(ContactTracked.fromFirestore(callDoc.data() as Map<String, dynamic>, callDoc.id));
//                 }
//               }
//             }
//           } catch (e) {
//             // Safely ignore errors for non-existent paths
//           }
//           currentDate = currentDate.add(const Duration(days: 1));
//         }
//       }
//
//       if (mounted) {
//         setState(() {
//           trackedContacts = fetchedContacts;
//           _prepareChartData();
//           isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//           _errorMessage = "A major error occurred while loading reports: $e";
//           trackedContacts = [];
//           _prepareChartData();
//         });
//       }
//     }
//   }

  // In _ReportsPageWeb2State class

  /// Fetches contact logs from the flattened 'CallLogs' collection based on the selected filters.
// In _ReportsPageWeb2State class

  /// Fetches contact logs from the flattened 'CallLogs' collection based on the selected filters.
  Future<void> _loadReports1() async {
    // 1. Validate Filters
    if (_selectedFacility == null) {
      _showSnackBar("Please select a facility to generate a report.");
      return;
    }
    if (startDate == null || endDate == null) {
      _showSnackBar("Please select a valid date range.");
      return;
    }
    if (userState == null) {
      _showSnackBar("Cannot load reports: Your state is not defined.");
      return;
    }

    setState(() {
      isLoading = true;
      _isInitialState = false;
      _errorMessage = null;
      trackedContacts.clear();
    });

    try {
      // --- 2. Build the Firestore Query ---

      // Start with a base query on the flattened 'CallLogs' collection
      Query query = _firestore.collection('CallLogs');

      // Add print statements to see the exact values being used for filtering
      print("--- Firestore Query Parameters ---");
      print("State Filter: '$userState'");

      // Apply required filters
      query = query
          .where('state', isEqualTo: userState)
          .where('dateTracked', isGreaterThanOrEqualTo: startDate)
          .where('dateTracked', isLessThanOrEqualTo: endDate!.add(const Duration(days: 1)));

      // Conditionally add the facility filter
      if (_selectedFacility != 'All Facilities') {
        print("Facility Filter: '$_selectedFacility'");
        query = query.where('facilityName', isEqualTo: _selectedFacility);
      } else {
        print("Facility Filter: All Facilities (no filter applied)");
      }

      // Add ordering
      query = query.orderBy('dateTracked', descending: true);
      print("----------------------------------");

      // --- 3. Execute the Query ---
      final QuerySnapshot querySnapshot = await query.get();

      // --- 4. Process the Results ---
      print("Query executed. Found ${querySnapshot.docs.length} documents.");

      if (querySnapshot.docs.isEmpty && _selectedFacility != 'All Facilities') {
        _showSnackBar("No call logs found for $_selectedFacility in the selected date range.");
      } else if (querySnapshot.docs.isEmpty) {
        _showSnackBar("No call logs found for any facility in this state for the selected date range.");
      }

      final List<ContactTracked> fetchedContacts = querySnapshot.docs.map((doc) {
        return ContactTracked.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();


      // --- 5. Update the UI State ---
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
          // This will now catch and display the "Missing Index" error from Firestore
          _errorMessage = "A major error occurred while loading reports: $e";
          trackedContacts = [];
          _prepareChartData();
        });
      }
      print("Firestore Query Error: $e");
    }
  }

  /// Fetches contact logs from the flattened 'CallLogs' collection based on the selected filters.
// In _ReportsPageWeb2State class

  /// Fetches contact logs from the flattened 'CallLogs' collection and prepares for display.
  Future<void> _loadReports() async {
    // 1. Validate that all necessary filters are selected.
    if (_selectedFacility == null) {
      _showSnackBar("Please select a facility to generate a report.");
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

    // 2. Set the UI to a loading state.
    setState(() {
      isLoading = true;
      _isInitialState = false;
      _errorMessage = null;
      _masterContactList.clear(); // Clear the master list for a new query
      trackedContacts.clear();
      _totalCallCost = 0.0;
    });

    try {
      // 3. Build the Firestore Query dynamically.
      Query query = _firestore.collection('CallLogs');

      query = query
          .where('trackerFacilityState', isEqualTo: userState)
          .where('dateTracked', isGreaterThanOrEqualTo: startDate)
          .where('dateTracked', isLessThanOrEqualTo: endDate!.add(const Duration(days: 1)));

      if (_selectedFacility != 'All Facilities') {
        query = query.where('trackerFacilityLocation', isEqualTo: _selectedFacility);
      }

      query = query.orderBy('dateTracked', descending: true);

      // 4. Execute the Query.
      final QuerySnapshot querySnapshot = await query.get();

      // 5. Process the results.
      final List<ContactTracked> fetchedContacts = querySnapshot.docs.map((doc) {
        return ContactTracked.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      // 6. Update the UI State using the new helper methods.
      if (mounted) {
        setState(() {
          _masterContactList = fetchedContacts;
          _updateAvailableTrackers(); // Populate the tracker dropdown
          _applyTrackerAndRecalculate(); // Filter by tracker and calculate metrics
          isLoading = false;
        });
        if (fetchedContacts.isEmpty) {
          _showSnackBar("No call logs found for the selected criteria.");
        }
      }
    } catch (e) {
      // 7. Handle any errors during the process.
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

  void _prepareChartData() {
    callStatusChartData = _getCallStatusData();
    callDurationTrendData = _getCallDurationTrendData();
    updateMetricsData = _getUpdateMetricsData();
    artStatusChartData = _getArtStatusData();
  }

  // --- MASKING, EXPORT, AND ALL OTHER HELPER/UI METHODS (REMAIN UNCHANGED) ---

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
              text: 'Report for: $_selectedFacility\n'
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

  // In _ReportsPageWeb2State class

  Widget _buildFilterBar() {
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
          alignment: WrapAlignment.center,
          children: [
            // 1. Facility Dropdown
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 600),
              child: DropdownButtonFormField<String>(
                value: _selectedFacility,
                hint: const Text('Select a Facility'),
                decoration: const InputDecoration(labelText: 'Facility', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15)),
                items: _availableFacilities.map((String facilityName) {
                  return DropdownMenuItem<String>(value: facilityName, child: Text(facilityName, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (String? newName) {
                  if (newName != null && newName != _selectedFacility) {
                    setState(() {
                      _selectedFacility = newName;
                      // Reset sub-filter when primary filter changes
                      _selectedTracker = 'All Trackers';
                      _availableTrackers = ['All Trackers'];
                    });
                  }
                },
              ),
            ),

            // 2. NEW: Tracked By Dropdown
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
              child: DropdownButtonFormField<String>(
                value: _selectedTracker,
                hint: const Text('Select Tracker'),
                // Disable dropdown if there's no data or if it's loading
                disabledHint: const Text('Apply filter first'),
                decoration: const InputDecoration(labelText: 'Tracked By', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15)),
                items: _availableTrackers.map((String trackerName) {
                  return DropdownMenuItem<String>(value: trackerName, child: Text(trackerName, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (_masterContactList.isEmpty || isLoading)
                    ? null // Disable if no master data is loaded
                    : (String? newName) {
                  setState(() => _selectedTracker = newName ?? 'All Trackers');
                  _applyTrackerAndRecalculate(); // Re-filter and re-calculate on change
                },
              ),
            ),

            // 3. Date Range Filter
            OutlinedButton.icon(
              onPressed: isLoading ? null : _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                (startDate != null && endDate != null) ? '${DateFormat.yMd().format(startDate!)} - ${DateFormat.yMd().format(endDate!)}' : 'Select Date Range',
                style: const TextStyle(fontWeight: FontWeight.normal),
              ),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.7)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
            ),

            // 4. Apply Filter Button
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply Filter'),
              onPressed: isLoading ? null : _loadReports,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
            ),
          ],
        ),
      ),
    );
  }

  // In _ReportsPageWeb2State class


// In _ReportsPageWeb2State class

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
              // Pass a full Icon widget
              iconWidget: Icon(Icons.call, color: Colors.blue.shade700, size: 36),
              label: 'Total Calls Logged',
              value: numberFormatter.format(trackedContacts.length),
            ),
            _buildInfoTile(
              // Pass a full Icon widget
              iconWidget: Icon(Icons.timer_outlined, color: Colors.purple.shade700, size: 36),
              label: 'Total Call Duration',
              value: formatDuration(totalDuration),
            ),
            _buildInfoTile(
              // NEW: Pass a styled Text widget as the icon
              iconWidget: Text(
                '₦',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              label: 'Estimated Call Cost',
              value: currencyFormatter.format(_totalCallCost),
              subtitle: '(at ₦${_costPerSecond}/sec)',
            ),
          ],
        ),
      ),
    );
  }


// Helper for the summary card tiles
  // In _ReportsPageWeb2State class

// In _ReportsPageWeb2State class

// Helper for the summary card tiles
  Widget _buildInfoTile({
    required Widget iconWidget, // UPDATED: Changed from IconData to Widget
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // We no longer need to wrap this in an Icon widget.
        // We just display the widget that was passed in.
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

  @override
  Widget build(BuildContext context) {
    // This calculation is now always performed. It will be empty on initial load.
    final Map<String, List<ContactTracked>> dailyGroupedReports = _groupContactsByDate();
    Widget bodyContent;

    // A critical error is the only state that will replace the entire report layout.
    if (_errorMessage != null) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ),
      );
    } else {
      // The main UI structure is now always visible.
      // Its contents (charts, tables) will be populated or show loading/empty states.
      bodyContent = SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Only show the header text AFTER the first filter is applied.
              if (!_isInitialState)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Displaying reports for: $_selectedFacility\nFrom ${DateFormat.yMd().format(startDate!)} to ${DateFormat.yMd().format(endDate!)}',
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                ),

              // NEW: Add the summary card here
              if (!_isInitialState && !isLoading)
                _buildSummaryInfoCard(),

              Text('Summary Charts', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),

              Wrap(
                spacing: 20.0,
                runSpacing: 20.0,
                alignment: WrapAlignment.start,
                children: [
                  // The cards are always built. Their inner content is determined by the app's state.
                  _buildChartCard(
                    title: 'Call Status Distribution',
                    chartKey: _callStatusChartKey,
                    // The chart's content is now determined by the loading/data state.
                    chart: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SfCircularChart(
                        annotations: (callStatusChartData.isEmpty && !_isInitialState)
                            ? const <CircularChartAnnotation>[
                          CircularChartAnnotation(widget: Text("No data"))
                        ]
                            : null,
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
                        annotations: (artStatusChartData.isEmpty && !_isInitialState)
                            ? const <CircularChartAnnotation>[
                          CircularChartAnnotation(widget: Text("No data"))
                        ]
                            : null,
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
                            ? const <CartesianChartAnnotation>[
                          CartesianChartAnnotation(widget: Text("No data"), coordinateUnit: CoordinateUnit.point, region: AnnotationRegion.chart, x: '50%', y: '50%')
                        ]
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
                            ? const <CartesianChartAnnotation>[
                          CartesianChartAnnotation(widget: Text("No data"), coordinateUnit: CoordinateUnit.point, region: AnnotationRegion.chart, x: '50%', y: '50%')
                        ]
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

              Text('Detailed Logs', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),

              // Conditional display for the detailed logs section
              if (isLoading)
                const Card(
                  elevation: 2,
                  child: SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Loading Detailed Logs...")
                        ],
                      ),
                    ),
                  ),
                )
              else if (_isInitialState || dailyGroupedReports.isEmpty)
                Card(
                  elevation: 2,
                  child: Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: Text(
                      _isInitialState
                          ? "Apply a filter to view detailed logs."
                          : "No detailed logs found for the selected criteria.",
                      style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else // Data is available, build the table
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
                          // The SingleChildScrollView now has a controller
                          SingleChildScrollView(
                            controller: _logTableController, // Assign controller
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
                                    DataCell(Text(_maskClientName(contact.name))),
                                    DataCell(Text(_maskPhoneNumber(contact.phoneNumber))),
                                    DataCell(Text(contact.artStatus ?? 'N/A')),
                                    DataCell(Text(contact.facilityName ?? 'N/A')),
                                    DataCell(Text(contact.state ?? 'N/A')),
                                  //  DataCell(Text(contact.uniqueID ?? 'N/A')),
                                    DataCell(Text(_maskClientName(contact.uniqueID))),
                                    DataCell(Text(contact.datimCode ?? 'N/A')),
                                    DataCell(Text(contact.dateTracked != null ? DateFormat('HH:mm').format(contact.dateTracked!) : 'N/A')),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: contact.callStatus != null ? _getStatusColor(contact.callStatus!).withOpacity(0.2) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4)),
                                      child: Text(contact.callStatus ?? 'N/A', style: TextStyle(
                                          color: contact.callStatus != null ? _getStatusColor(contact.callStatus!) : Colors.black87,
                                          fontWeight: FontWeight.w500)),
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
                          // NEW: Row for scroll buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                tooltip: 'Scroll Left',
                                onPressed: () {
                                  _logTableController.animateTo(
                                    _logTableController.offset - 350, // scroll left
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                tooltip: 'Scroll Right',
                                onPressed: () {
                                  _logTableController.animateTo(
                                    _logTableController.offset + 350, // scroll right
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                },
                              ),
                            ],
                          )
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


    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedFacility == null ? 'Call Tracking Reports' : 'Report for: $_selectedFacility',style: TextStyle(color: Colors.white,),),
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
      drawer: drawer2(context,),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_isFilterLoading)
            const Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()),
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
              SizedBox(
                height: 250,
                child: chartWithBoundary,
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