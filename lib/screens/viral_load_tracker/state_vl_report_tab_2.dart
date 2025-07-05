// REWRITTEN FOR FLUTTER WEB & STATE-LEVEL AGGREGATION
// VERSION 2.1: Waits for explicit user filter action before loading data. All methods are fully implemented.

import 'dart:convert' show utf8;
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:attendanceappmailtool/screens/viral_load_tracker/vl_call_log_model.dart';
import 'package:attendanceappmailtool/screens/viral_load_tracker/vl_eligible_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart' show PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;

import '../../widgets/drawer2.dart';
import '../../widgets/drawer3.dart';

// Define separate keys for RepaintBoundary to capture chart images for PDF export.
final GlobalKey _currentQuarterChartBoundaryKey = GlobalKey();
final GlobalKey _previousQuarterChartBoundaryKey = GlobalKey();
final GlobalKey _olderSamplesChartBoundaryKey = GlobalKey();
final GlobalKey _callOutcomesChartBoundaryKey = GlobalKey();
// NEW WIDGET: Animates a number from its old value to a new value.
class AnimatedNumberText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final Duration duration;
  final int fractionDigits;
  final String suffix;

  const AnimatedNumberText(
      this.value, {
        super.key,
        this.style,
        this.duration = const Duration(milliseconds: 1200),
        this.fractionDigits = 1,
        this.suffix = '',
      });

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder will animate from the previous 'end' value to the new one.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      builder: (context, animatedValue, child) {
        // Determine if the original value was an integer to format correctly.
        final isInt = value is int;
        final textValue = isInt
            ? animatedValue.toInt().toString()
            : animatedValue.toStringAsFixed(fractionDigits);

        return Text(
          '$textValue$suffix',
          style: style,
        );
      },
    );
  }
}


class StateVlReportTab2 extends StatefulWidget {
  const StateVlReportTab2({super.key});

  @override
  State<StateVlReportTab2> createState() => _StateVlReportTab2State();
}

class _ChartData {
  _ChartData(this.x, this.y, [this.color]);
  final String x;
  final double y;
  final Color? color;
}

class _StateVlReportTab2State extends State<StateVlReportTab2> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  final ScrollController _vlSummaryTableController = ScrollController();
  final ScrollController _callLogTableController = ScrollController();

  // --- State variables for filters and user context ---
  bool _isFilterLoading = true;
  String? _userState;
  List<String> _availableFacilities = [];
  String? _selectedFacility; // Initially null to force user selection
  String? _errorMessage;
  String? _selectedFacilityName;

  // --- State to manage UI flow ---
  bool _isInitialState = true; // True until the first filter is applied

  // --- Core Data & UI State Variables ---
  bool _isLoading = false; // For data loading spinner after button click
  bool _isExporting = false;

  List<VlEligibleModel> _allEligibleList = [];
  List<VlCallLogModel> _masterCallLogs = [];
  List<VlCallLogModel> _callLogs = []; // The filtered list for display

  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  bool _allCellsGloballyUnlocked = false;

  // --- Metrics (will be aggregated from fetched data) ---
  String _currentQuarter = '';
  String _currentQuarterDisplay = '';
  int _totalEligibleOverall = 0;
  int _totalEligibleDueForRefillInQuarter = 0;
  int _totalEligibleDueForRefillOutsideQuarter = 0;
  int _samplesCollectedInQuarter = 0;
  int _resultsReturnedInQuarter = 0;
  int _suppressedInQuarter = 0;
  int _unsuppressedInQuarter = 0;
  int _tatExceeded3MonthsCurrentQuarter = 0;
  int _tatOver3MonthsWithResultCurrentQuarter = 0;

  String _previousQuarter = '';
  String _previousQuarterDisplay = '';
  int _samplesCollectedPreviousQuarter = 0;
  int _resultsReturnedPreviousQuarter = 0;
  int _suppressedPreviousQuarter = 0;
  int _unsuppressedPreviousQuarter = 0;
  int _tatExceeded3MonthsPreviousQuarter = 0;
  int _tatOver3MonthsWithResultPreviousQuarter = 0;

  String _olderSamplesDisplayTitle = '';
  int _samplesCollectedOlder = 0;
  int _resultsReturnedOlder = 0;
  int _suppressedOlder = 0;
  int _unsuppressedOlder = 0;
  int _tatExceeded3MonthsOlder = 0;
  int _tatOver3MonthsWithResultOlder = 0;

  int _totalCallsMade = 0;
  int _callsAnswered = 0;
  int _callsNotAnsweredOrFailed = 0;
  double _averageCallDurationSeconds = 0;

  double _percentageSampleCollected = 0.0;
  double _percentageResultReceived = 0.0;

  int _totalNotActive = 0;
  int _totalDeaths = 0;
  int _totalTransferredOut = 0;
  int _totalMissedAppointments = 0;
  int _totalIIT = 0;
  int _totalDiscontinuedCare = 0;

  late TooltipBehavior _tooltipBehavior;


  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    // Only initializes filters, does not load report data.
    _initializeUserContext();
  }

  @override
  void dispose() {
    // NEW: Dispose of the controllers
    _vlSummaryTableController.dispose();
    _callLogTableController.dispose();
    super.dispose();
  }

  /// Initializes the user's context by fetching their state and the list of
  Future<void> _initializeUserContext() async {
    setState(() => _isFilterLoading = true);
    _calculateCurrentAndPreviousQuarters();
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      final staffData = staffDoc.data();
      final userState = staffData?['state'] as String?;

      if (userState == null || userState.isEmpty) {
        throw Exception("State not found in your staff profile.");
      }

      _userState = userState;
      final facilityNames = await _getFacilitiesForState(userState);

      if (mounted) {
        setState(() {
          _availableFacilities = ['All Facilities', ...facilityNames];
          _isFilterLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint("Error initializing user state: $e");
      if(mounted) {
        setState(() {
          _errorMessage = "Failed to load user profile and facilities: $e";
          _isFilterLoading = false;
        });
      }
    }
  }


  /// MODIFIED: Fetches facilities, returning a list of `LocationName` strings.
  Future<List<String>> _getFacilitiesForState(String state) async {
    try {
      final snapshot = await _firestore.collection('Location').doc(state).collection(state).get();
      final List<String> facilityNames = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final locationName = data['LocationName'] as String?;
        // Only add the facility if it has a valid, non-empty LocationName
        if (locationName != null && locationName.isNotEmpty) {
          facilityNames.add(locationName);
        }
      }
      // Sort the list of names alphabetically for a better UX.
      facilityNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      return facilityNames;
    } catch (e) {
      debugPrint("Error fetching facilities: $e");
      _showSnackBar("Error fetching facility list: $e");
      return [];
    }
  }
  /// The primary data loading function, triggered explicitly by the 'Apply Filter' button.
  /// Fetches data for the selected facility (or all facilities) and calculates metrics.
  /// MODIFIED: Uses the `_selectedFacilityName` string to drive the data fetching logic.
  Future<void> _loadAndCalculateReports() async {
    if (_selectedFacilityName == null) {
      _showSnackBar("Please select a facility from the dropdown.");
      return;
    }

    if (mounted) {
      setState(() {
        _isInitialState = false;
        _isLoading = true;
        _errorMessage = null;
      });
    }

    _resetAllMetrics();

    try {
      if (_userState == null || _currentQuarterDisplay.isEmpty) {
        throw Exception("User State or Quarter is not defined.");
      }

      List<String> facilitiesToFetch;
      if (_selectedFacilityName == 'All Facilities') {
        facilitiesToFetch = List.from(_availableFacilities)..remove('All Facilities');
      } else {
        facilitiesToFetch = [_selectedFacilityName!];
      }

      _allEligibleList = [];
      _masterCallLogs = [];

      for (String facilityName in facilitiesToFetch) {
        // CRUCIAL CHANGE: The 'facilityName' string is now used as the collection name.
        final quarterSummaryDocRef = _firestore
            .collection('VlReportSummaries')
            .doc(_userState!)
            .collection(facilityName)
            .doc(_currentQuarterDisplay);

        final summarySnapshot = await quarterSummaryDocRef.get();
        if (summarySnapshot.exists && summarySnapshot.data() != null) {
          _allEligibleList.add(VlEligibleModel.fromMap(
            summarySnapshot.id,
            summarySnapshot.data() as Map<String, dynamic>,
          ));
        }

        final callLogSnapshot = await quarterSummaryDocRef.collection('callLogs').get();
        _masterCallLogs.addAll(callLogSnapshot.docs
            .map((doc) => VlCallLogModel.fromMap(doc.id, doc.data()))
            .toList());
      }

      _applyDateFilterToCallLogs();
      _calculateMetrics();

    } catch (e, stack) {
      debugPrint('❌ Error in _loadAndCalculateReports: $e\n$stack');
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load reports from server: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Resets all metric counters and data lists to zero/empty.
  /// Called before each new data fetch to prevent stale data.
  void _resetAllMetrics() {
    _allEligibleList = [];
    _masterCallLogs = [];
    _callLogs = [];
    _totalEligibleOverall = 0;
    _totalEligibleDueForRefillInQuarter = 0;
    _totalEligibleDueForRefillOutsideQuarter = 0;
    _samplesCollectedInQuarter = 0;
    _resultsReturnedInQuarter = 0;
    _suppressedInQuarter = 0;
    _unsuppressedInQuarter = 0;
    _tatExceeded3MonthsCurrentQuarter = 0;
    _tatOver3MonthsWithResultCurrentQuarter = 0;
    _samplesCollectedPreviousQuarter = 0;
    _resultsReturnedPreviousQuarter = 0;
    _suppressedPreviousQuarter = 0;
    _unsuppressedPreviousQuarter = 0;
    _tatExceeded3MonthsPreviousQuarter = 0;
    _tatOver3MonthsWithResultPreviousQuarter = 0;
    _samplesCollectedOlder = 0;
    _resultsReturnedOlder = 0;
    _suppressedOlder = 0;
    _unsuppressedOlder = 0;
    _tatExceeded3MonthsOlder = 0;
    _tatOver3MonthsWithResultOlder = 0;
    _totalNotActive = 0;
    _totalDeaths = 0;
    _totalTransferredOut = 0;
    _totalMissedAppointments = 0;
    _totalIIT = 0;
    _totalDiscontinuedCare = 0;
    _percentageSampleCollected = 0.0;
    _percentageResultReceived = 0.0;
    _totalCallsMade = 0;
    _callsAnswered = 0;
    _callsNotAnsweredOrFailed = 0;
    _averageCallDurationSeconds = 0.0;
  }


  /// Aggregates data from all fetched facility summaries and recalculates all metrics.
  void _calculateMetrics() {

    // Sum up VL summary data from all fetched facilities
    for (final summary in _allEligibleList) {
      _totalEligibleOverall += summary.totalEligibleClientsInFilter;
      _totalEligibleDueForRefillInQuarter += summary.refillsDueInQuarter;
      _totalEligibleDueForRefillOutsideQuarter += summary.refillsDueOutsideQuarter;
      _samplesCollectedInQuarter += summary.samplesCollected;
      _resultsReturnedInQuarter += summary.resultsReturned;
      _suppressedInQuarter += summary.suppressed;
      _unsuppressedInQuarter += summary.unsuppressed;
      _tatExceeded3MonthsCurrentQuarter += summary.tatPendingOver90Days;
      _tatOver3MonthsWithResultCurrentQuarter += summary.tatResultOver90Days;
      _totalNotActive += summary.totalNotActive;
      _totalDeaths += summary.totalDeaths;
      _totalTransferredOut += summary.totalTransferredOut;
      _totalMissedAppointments += summary.totalMissedAppointments;
      _totalIIT += summary.totalIIT;
      _totalDiscontinuedCare += summary.totalDiscontinuedCare;
      _samplesCollectedPreviousQuarter += summary.samplesCollectedPreviousQuarter;
      _resultsReturnedPreviousQuarter += summary.resultsReturnedPreviousQuarter;
      _suppressedPreviousQuarter += summary.suppressedPreviousQuarter;
      _unsuppressedPreviousQuarter += summary.unsuppressedPreviousQuarter;
      _tatExceeded3MonthsPreviousQuarter += summary.tatExceeded3MonthsPreviousQuarter;
      _tatOver3MonthsWithResultPreviousQuarter += summary.tatOver3MonthsWithResultPreviousQuarter;
      _samplesCollectedOlder += summary.samplesCollectedOlder;
      _resultsReturnedOlder += summary.resultsReturnedOlder;
      _suppressedOlder += summary.suppressedOlder;
      _unsuppressedOlder += summary.unsuppressedOlder;
      _tatExceeded3MonthsOlder += summary.tatExceeded3MonthsOlder;
      _tatOver3MonthsWithResultOlder += summary.tatOver3MonthsWithResultOlder;
    }

    // Set display titles (should be consistent across summaries)
    if (_allEligibleList.isNotEmpty) {
      _previousQuarterDisplay = _allEligibleList.first.previousQuarterDisplay ?? _previousQuarterDisplay;
      _olderSamplesDisplayTitle = _allEligibleList.first.olderSamplesDisplayTitle ?? "Older Samples";
    }

    // Recalculate overall percentages based on aggregated totals
    if (_totalEligibleOverall > 0) {
      _percentageSampleCollected = (_samplesCollectedInQuarter / _totalEligibleOverall) * 100;
    }
    if (_samplesCollectedInQuarter > 0) {
      _percentageResultReceived = (_resultsReturnedInQuarter / _samplesCollectedInQuarter) * 100;
    }

    // Calculate call log metrics from the (potentially date-filtered) _callLogs list
    if (_callLogs.isNotEmpty) {
      _totalCallsMade = _callLogs.length;
      _callsAnswered = _callLogs.where((log) => log.callStatus?.toLowerCase() == "answered").length;
      _callsNotAnsweredOrFailed = _totalCallsMade - _callsAnswered;
      if (_callsAnswered > 0) {
        var answeredLogs = _callLogs.where((log) => log.callStatus?.toLowerCase() == "answered" && (log.callDurationInSeconds ?? 0) > 0);
        if (answeredLogs.isNotEmpty) {
          _averageCallDurationSeconds = answeredLogs.map((log) => log.callDurationInSeconds!).reduce((a, b) => a + b) / answeredLogs.length;
        }
      }
    }

    if (mounted) setState(() {});
  }

  /// Filters the master list of call logs based on the selected date range.
  void _applyDateFilterToCallLogs() {
    if (_startDateFilter != null && _endDateFilter != null) {
      final adjustedEndDate = DateTime(_endDateFilter!.year, _endDateFilter!.month, _endDateFilter!.day, 23, 59, 59);
      _callLogs = _masterCallLogs.where((log) {
        return log.callDateTime != null && !log.callDateTime!.isBefore(_startDateFilter!) && !log.callDateTime!.isAfter(adjustedEndDate);
      }).toList();
    } else {
      _callLogs = List.from(_masterCallLogs);
    }
  }

  // --- All other helper methods (unchanged from original logic) ---

  void _calculateCurrentAndPreviousQuarters() {
    final now = DateTime.now();
    int currentMonth = now.month;
    int currentYear = now.year;
    if (currentMonth >= 10) {
      _currentQuarter = 'Q1';
      _currentQuarterDisplay = 'Q1 (FY${(currentYear + 1).toString().substring(2)})';
      _previousQuarter = 'Q4';
      _previousQuarterDisplay = 'Q4 (FY${currentYear.toString().substring(2)})';
    } else if (currentMonth >= 7) {
      _currentQuarter = 'Q4';
      _currentQuarterDisplay = 'Q4 (FY${currentYear.toString().substring(2)})';
      _previousQuarter = 'Q3';
      _previousQuarterDisplay = 'Q3 (FY${currentYear.toString().substring(2)})';
    } else if (currentMonth >= 4) {
      _currentQuarter = 'Q3';
      _currentQuarterDisplay = 'Q3 (FY${currentYear.toString().substring(2)})';
      _previousQuarter = 'Q2';
      _previousQuarterDisplay = 'Q2 (FY${currentYear.toString().substring(2)})';
    } else {
      _currentQuarter = 'Q2';
      _currentQuarterDisplay = 'Q2 (FY${currentYear.toString().substring(2)})';
      _previousQuarter = 'Q1';
      _previousQuarterDisplay = 'Q1 (FY${currentYear.toString().substring(2)})';
    }
  }

  String _maskClientName(String? name) {
    if (_allCellsGloballyUnlocked || name == null || name.isEmpty) return name ?? 'N/A';
    List<String> parts = name.split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? '${parts[0][0]}. (Hidden)' : 'Hidden';
  }

  String _maskArtId(String? artId) {
    if (_allCellsGloballyUnlocked || artId == null || artId.isEmpty) return artId ?? 'N/A';
    return artId.length > 4 ? '${artId.substring(0, 2)}...${artId.substring(artId.length - 2)}' : artId.replaceAll(RegExp(r'.'), '*');
  }

  String _maskPhoneNumber(String? phone) {
    if (_allCellsGloballyUnlocked || phone == null || phone.isEmpty) return phone ?? 'N/A';
    return phone.length > 4 ? '...${phone.substring(phone.length - 4)}' : phone.replaceAll(RegExp(r'.'), '*');
  }

  Future<bool> _promptForPasswordAndReauthenticate() async {
    final passwordController = TextEditingController();
    final user = _firebaseAuth.currentUser;

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
                    decoration: const InputDecoration(hintText: 'Password', border: OutlineInputBorder()),
                    onSubmitted: (_) async { /* can trigger auth here */ },
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
                  } on FirebaseAuthException catch (e) {
                    _showSnackBar('Authentication Error: ${e.message ?? "An error occurred."}');
                    Navigator.pop(context, false); // Failure
                  } catch (e) {
                    _showSnackBar('An unexpected error occurred during authentication.');
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
        _showSnackBar('All sensitive data has been unmasked for this session.');
      } else if (mounted) {
        _showSnackBar('Authentication failed. Data remains masked.');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Uint8List?> _captureChartPng(GlobalKey key) async {
    try {
      if (key.currentContext == null) return null;
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      if (mounted) _showSnackBar('Error capturing chart image: $e');
      return null;
    }
  }

  Future<void> _exportToCSV() async {
    if (_isExporting) return;
    if (mounted) setState(() => _isExporting = true);

    bool proceed = _allCellsGloballyUnlocked;
    if (!proceed) proceed = await _promptForPasswordAndReauthenticate();

    if (!proceed) {
      if (mounted) setState(() => _isExporting = false);
      return;
    }

    try {
      List<List<String>> rows = [
        ['Client Name', 'ART ID', 'Phone Number', 'Call Date & Time', 'Call Status', 'Duration (s)', 'Tracked By', 'Tracker Facility']
      ];
      rows.addAll(_callLogs.map((log) => [
        log.clientName ?? 'N/A',
        log.artId ?? 'N/A',
        log.phoneNumberCalled ?? 'N/A',
        log.callDateTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(log.callDateTime!) : 'N/A',
        log.callStatus ?? 'N/A',
        log.callDurationInSeconds?.toString() ?? 'N/A',
        log.trackedBy ?? 'N/A',
        log.trackerFacility ?? 'N/A',
      ]));

      String csvData = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final filename = 'vl_state_call_log_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;

      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      if (mounted) _showSnackBar('Call Log CSV download started.');

    } catch (e) {
      if (mounted) _showSnackBar('Error exporting CSV: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportSummaryToCSV() async {
    if (_isExporting) return;
    if (mounted) setState(() => _isExporting = true);

    try {
      List<List<dynamic>> rows = [
        ['Metric', 'Value'],
        [],
        ['--- OVERALL PERFORMANCE ---', ''],
        ['% Samples Collected (Overall)', '${_percentageSampleCollected.toStringAsFixed(1)}%'],
        ['% Results Received (Overall)', '${_percentageResultReceived.toStringAsFixed(1)}%'],
        [],
        ['--- CLIENTS NOT ON ACTIVE TREATMENT ---', ''],
        ['Total Not Active', _totalNotActive],
        ['Deaths', _totalDeaths],
        ['Transferred Out', _totalTransferredOut],
        ['Missed Appointments', _totalMissedAppointments],
        ['IIT (Interrupted in Treatment)', _totalIIT],
        ['Discontinued Care', _totalDiscontinuedCare],
        [],
        ['--- VL SUMMARY ($_currentQuarterDisplay) ---', ''],
        ['Total Eligible Clients (Filtered)', _totalEligibleOverall],
        ['Due for Refill (In Quarter)', _totalEligibleDueForRefillInQuarter],
        ['Refill Due (Outside Quarter)', _totalEligibleDueForRefillOutsideQuarter],
        ['Samples Collected', _samplesCollectedInQuarter],
        ['Results Returned', _resultsReturnedInQuarter],
        ['Suppressed (<1k)', _suppressedInQuarter],
        ['Unsuppressed (>=1k)', _unsuppressedInQuarter],
        ['TAT: Pending > 90 days', _tatExceeded3MonthsCurrentQuarter],
        ['TAT: Result Received > 90 days', _tatOver3MonthsWithResultCurrentQuarter],
        [],
        ['--- VL SUMMARY ($_previousQuarterDisplay) ---', ''],
        ['Samples Collected', _samplesCollectedPreviousQuarter],
        ['Results Returned', _resultsReturnedPreviousQuarter],
        ['Suppressed (<1k)', _suppressedPreviousQuarter],
        ['Unsuppressed (>=1k)', _unsuppressedPreviousQuarter],
        ['TAT: Pending > 90 days', _tatExceeded3MonthsPreviousQuarter],
        ['TAT: Result Received > 90 days', _tatOver3MonthsWithResultPreviousQuarter],
        [],
        ['--- VL SUMMARY ($_olderSamplesDisplayTitle) ---', ''],
        ['Samples Collected', _samplesCollectedOlder],
        ['Results Returned', _resultsReturnedOlder],
        ['Suppressed (<1k)', _suppressedOlder],
        ['Unsuppressed (>=1k)', _unsuppressedOlder],
        ['TAT: Pending > 90 days', _tatExceeded3MonthsOlder],
        ['TAT: Result Received > 90 days', _tatOver3MonthsWithResultOlder],
        [],
        ['--- CALL LOG ANALYSIS ---', ''],
        ['Total Calls Made', _totalCallsMade],
        ['Calls Answered', _callsAnswered],
        ['Calls Not Answered/Failed', _callsNotAnsweredOrFailed],
        ['Average Call Duration (Answered)', '${_averageCallDurationSeconds.toStringAsFixed(1)}s'],
      ];

      String csvData = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final filename = 'vl_state_summary_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;

      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      if (mounted) _showSnackBar('Dashboard Summary CSV download started.');

    } catch (e) {
      if (mounted) _showSnackBar('Error exporting Summary CSV: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToPDF() async {
    if (_isExporting) return;
    if (mounted) setState(() => _isExporting = true);

    bool proceed = _allCellsGloballyUnlocked;
    if (!proceed) proceed = await _promptForPasswordAndReauthenticate();

    if (!proceed) {
      if (mounted) setState(() => _isExporting = false);
      return;
    }

    try {
      final pdf = pw.Document();
      final Uint8List? currentQChartImgBytes = await _captureChartPng(_currentQuarterChartBoundaryKey);
      final Uint8List? prevQChartImgBytes = await _captureChartPng(_previousQuarterChartBoundaryKey);
      final Uint8List? olderSamplesChartImgBytes = await _captureChartPng(_olderSamplesChartBoundaryKey);
      final Uint8List? callOutcomesChartImgBytes = await _captureChartPng(_callOutcomesChartBoundaryKey);

      final pw.MemoryImage? currentQPdfImg = currentQChartImgBytes != null ? pw.MemoryImage(currentQChartImgBytes) : null;
      final pw.MemoryImage? prevQPdfImg = prevQChartImgBytes != null ? pw.MemoryImage(prevQChartImgBytes) : null;
      final pw.MemoryImage? olderSamplesPdfImg = olderSamplesChartImgBytes != null ? pw.MemoryImage(olderSamplesChartImgBytes) : null;
      final pw.MemoryImage? callOutcomesPdfImg = callOutcomesChartImgBytes != null ? pw.MemoryImage(callOutcomesChartImgBytes) : null;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (pw.Context context) => pw.Container(alignment: pw.Alignment.centerRight, child: pw.Text('VL Report - ${DateFormat.yMMMMd().format(DateTime.now())}', style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey))),
          footer: (pw.Context context) => pw.Container(alignment: pw.Alignment.centerRight, child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey))),
          build: (pw.Context context) => [
            pw.Header(level: 0, text: 'Viral Load Report Summary ($_selectedFacility)', textStyle: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            if (_startDateFilter != null && _endDateFilter != null)
              pw.Paragraph(text: 'Data filtered from: ${DateFormat.yMd().format(_startDateFilter!)} to ${DateFormat.yMd().format(_endDateFilter!)}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 10),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Overall Performance:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Text('% Samples Collected (Overall): ${_percentageSampleCollected.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 11)),
                        pw.Text('% Results Received (Overall): ${_percentageResultReceived.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 11)),
                      ]),
                  pw.SizedBox(width: 20),
                  pw.Text('Total Eligible Clients (Filtered): $_totalEligibleOverall', style: const pw.TextStyle(fontSize: 11)),
                ]),
            pw.SizedBox(height: 15),
            pw.Header(level: 1, text: 'Summary Charts', textStyle: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Wrap(
              spacing: 10, runSpacing: 10,
              children: [
                if (currentQPdfImg != null && _samplesCollectedInQuarter > 0)
                  pw.Container(width: 250, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [pw.Text('$_currentQuarterDisplay: VL Status & TAT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)), pw.SizedBox(height:3), pw.Image(currentQPdfImg, fit: pw.BoxFit.contain, height: 150)])),
                if (prevQPdfImg != null && _samplesCollectedPreviousQuarter > 0)
                  pw.Container(width: 250, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [pw.Text('$_previousQuarterDisplay: VL Status & TAT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)), pw.SizedBox(height:3), pw.Image(prevQPdfImg, fit: pw.BoxFit.contain, height: 150)])),
                if (olderSamplesPdfImg != null && _samplesCollectedOlder > 0)
                  pw.Container(width: 250, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [pw.Text('Older Samples: VL Status & TAT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)), pw.SizedBox(height:3), pw.Image(olderSamplesPdfImg, fit: pw.BoxFit.contain, height: 150)])),
                if (callOutcomesPdfImg != null && _totalCallsMade > 0)
                  pw.Container(width: 250, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [pw.Text('Call Outcomes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)), pw.SizedBox(height:3), pw.Image(callOutcomesPdfImg, fit: pw.BoxFit.contain, height: 150)])),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Paragraph(text: "Note: Detailed call logs are available in the CSV export.", style:  pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final filename = 'vl_state_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;

      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      if (mounted) _showSnackBar('PDF download started.');

    } catch (e) {
      if (mounted) _showSnackBar('Error exporting PDF: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Displays a date range picker. On selection, it re-filters the currently loaded
  /// call log data without needing another network request.
  void _showAndApplyDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range for Call Logs for Eligible Clients'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.5,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: (_startDateFilter != null && _endDateFilter != null)
                ? PickerDateRange(_startDateFilter!, _endDateFilter!)
                : null,
            showActionButtons: true,
            cancelText: 'Clear Filter',
            confirmText: 'Apply',
            onSubmit: (Object? value) {
              Navigator.pop(context);
              if (value is PickerDateRange) {
                setState(() {
                  _startDateFilter = value.startDate;
                  _endDateFilter = value.endDate ?? value.startDate;
                });
                _applyDateFilterToCallLogs();
                _calculateMetrics(); // Re-calculate only call log metrics
              }
            },
            onCancel: () {
              Navigator.pop(context);
              setState(() {
                _startDateFilter = null;
                _endDateFilter = null;
              });
              _applyDateFilterToCallLogs();
              _calculateMetrics(); // Re-calculate only call log metrics
            },
          ),
        ),
      ),
    );
  }

  Map<String, List<VlCallLogModel>> _groupCallLogsByDate() {
    final Map<String, List<VlCallLogModel>> dailyLogs = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');

    for (var log in _callLogs) {
      final dateKey = log.callDateTime != null ? dateKeyFormat.format(log.callDateTime!) : 'Unknown Date';
      dailyLogs.putIfAbsent(dateKey, () => []).add(log);
    }

    final sortedKeys = dailyLogs.keys.toList()
      ..sort((a, b) {
        if (a == 'Unknown Date') return 1; if (b == 'Unknown Date') return -1;
        try { return DateTime.parse(b).compareTo(DateTime.parse(a)); } catch (e) { return a.compareTo(b); }
      });

    return { for (var k in sortedKeys) k : dailyLogs[k]! };
  }

  // --- WIDGET BUILDER METHODS ---

  /// Builds the filter bar with the facility dropdown and the 'Apply Filter' button.
  /// MODIFIED: Builds the filter bar dropdown using the `_availableFacilities` list of names.
  Widget _buildFilterBar() {
    // REWRITTEN FOR FLUTTER WEB & FACILITY-LEVEL FILTERING (PATH-BASED COMPATIBLE VERSION)
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: _isFilterLoading
            ? const Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Loading filters..."),
          ),
        )
            : Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16.0, // Horizontal spacing between elements
          runSpacing: 12.0, // Vertical spacing if they wrap
          alignment: WrapAlignment.center,
          children: [
            // 1. Facility Dropdown (now flexible)
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 250, // Ensures it doesn't get too small on wide screens
                maxWidth: 350, // Prevents it from getting too large and allows wrapping
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedFacilityName,
                hint: const Text('Select a Facility'),
                isExpanded: true, // Allows dropdown text to use available space
                decoration: const InputDecoration(
                  labelText: 'Facility',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                ),
                items: _availableFacilities.map((String facilityName) {
                  return DropdownMenuItem<String>(
                    value: facilityName,
                    child: Text(facilityName, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (String? newName) {
                  setState(() => _selectedFacilityName = newName);
                },
              ),
            ),

            // 2. Date Range Filter (as requested)
            OutlinedButton.icon(
              onPressed: _isInitialState ? null : _showAndApplyDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                (_startDateFilter != null && _endDateFilter != null)
                    ? '${DateFormat.yMd().format(_startDateFilter!)} - ${DateFormat.yMd().format(_endDateFilter!)}'
                    : 'Select Date Range',
                style: const TextStyle(fontWeight: FontWeight.normal),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),

            // 3. Apply Filter Button
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply Filter'),
              onPressed: _isLoading ? null : _loadAndCalculateReports,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a reusable card widget to display a single metric.
  // MODIFIED: This widget now takes a `num` and uses the AnimatedNumberText widget.
  Widget _buildMetricCard(
      String title,
      num value, {
        String? subtitle,
        double? width,
        Color? valueColor,
        String suffix = '',
        int fractionDigits = 1,
      }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              // Use the new animated widget here
              AnimatedNumberText(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor),
                suffix: suffix,
                fractionDigits: fractionDigits,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis, maxLines: 2),
              ]
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a doughnut chart for visualizing categorical data.
  Widget _buildDoughnutChart(String title, List<_ChartData> data, {GlobalKey? boundaryKey}) {
    List<_ChartData> filteredData = data.where((d) => d.y > 0).toList();
    if (filteredData.isEmpty) return const SizedBox.shrink();

    Widget chartWidget = SfCircularChart(
      title: ChartTitle(text: title, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      legend: const Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap, position: LegendPosition.bottom),
      tooltipBehavior: _tooltipBehavior,
      series: <CircularSeries<_ChartData, String>>[
        DoughnutSeries<_ChartData, String>(
          dataSource: filteredData,
          xValueMapper: (_ChartData data, _) => data.x,
          yValueMapper: (_ChartData data, _) => data.y,
          pointColorMapper: (_ChartData data, _) => data.color,
          dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside),
          dataLabelMapper: (_ChartData data, _) => '${data.x}\n${data.y.toInt()}',
          innerRadius: '50%',
        )
      ],
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: boundaryKey != null
            ? RepaintBoundary(key: boundaryKey, child: chartWidget)
            : chartWidget,
      ),
    );
  }

  /// Builds the detailed table of call logs, grouped by date.
  Widget _buildCallLogSummaryTable1() {
    if (_callLogs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: Text('No call logs available for this selection.')),
      );
    }

    final Map<String, List<VlCallLogModel>> groupedLogs = _groupCallLogsByDate();
    final DateFormat displayDateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Detailed Call Logs by Date", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groupedLogs.keys.length,
          itemBuilder: (context, index) {
            final dateKey = groupedLogs.keys.elementAt(index);
            final dailyLogs = groupedLogs[dateKey]!;
            final String displayDate = dateKey == 'Unknown Date' ? 'Unknown Date' : displayDateFormat.format(DateTime.parse(dateKey));

            dailyLogs.sort((a, b) => (b.callDateTime ?? DateTime(1900)).compareTo(a.callDateTime ?? DateTime(1900)));

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
              child: ExpansionTile(
                key: PageStorageKey<String>(dateKey),
                title: Text('$displayDate (${dailyLogs.length} calls)', style: const TextStyle(fontWeight: FontWeight.w600)),
                initiallyExpanded: index == 0,
                children: dailyLogs.map((log) {
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      log.callStatus?.toLowerCase() == 'answered' ? Icons.call_received : Icons.call_missed_outgoing,
                      color: log.callStatus?.toLowerCase() == 'answered' ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    title: Text(_maskClientName(log.clientName), style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ART ID: ${_maskArtId(log.artId)} | Phone: ${_maskPhoneNumber(log.phoneNumberCalled)}'),
                        Text('Time: ${log.callDateTime != null ? DateFormat('HH:mm:ss').format(log.callDateTime!) : 'N/A'}'),
                        Text('Status: ${log.callStatus ?? 'N/A'} | Duration: ${log.callDurationInSeconds ?? 0}s'),
                        if (_selectedFacility == 'All Facilities')
                          Text('Facility: ${log.trackerFacility ?? 'N/A'}', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey[700])),
                        if (log.trackedBy != null && log.trackedBy!.isNotEmpty)
                          Text('Tracker: ${log.trackedBy}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
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

  // REPLACED: This method now includes scroll buttons
  Widget _buildVlSummaryTable() {
    if (_allEligibleList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Facility-Level Viral Load Summary",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SingleChildScrollView(
                controller: _vlSummaryTableController, // Assign controller
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  // ... (DataTable columns and rows are unchanged)
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                  columns: const [
                    DataColumn(label: Text('State', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Facility Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Total\nEligible'), numeric: true),
                    DataColumn(label: Text('Refills Due\n(In Qtr)'), numeric: true),
                    DataColumn(label: Text('Samples Coll.\n(Current Qtr)'), numeric: true),
                    DataColumn(label: Text('Results Rcvd\n(Current Qtr)'), numeric: true),
                    DataColumn(label: Text('Suppressed\n(Current Qtr)'), numeric: true),
                    DataColumn(label: Text('Unsuppressed\n(Current Qtr)'), numeric: true),
                    DataColumn(label: Text('Samples Coll.\n(Prev Qtr)'), numeric: true),
                    DataColumn(label: Text('Results Rcvd\n(Prev Qtr)'), numeric: true),
                    DataColumn(label: Text('Suppressed\n(Prev Qtr)'), numeric: true),
                    DataColumn(label: Text('Unsuppressed\n(Prev Qtr)'), numeric: true),
                    DataColumn(label: Text('Samples Coll.\n(Older)'), numeric: true),
                    DataColumn(label: Text('Results Rcvd\n(Older)'), numeric: true),
                    DataColumn(label: Text('Suppressed\n(Older)'), numeric: true),
                    DataColumn(label: Text('Unsuppressed\n(Older)'), numeric: true),
                    DataColumn(label: Text('Deaths'), numeric: true),
                    DataColumn(label: Text('Transferred\nOut'), numeric: true),
                    DataColumn(label: Text('IIT'), numeric: true),
                    DataColumn(label: Text('Missed\nAppts'), numeric: true),
                    DataColumn(label: Text('Discontinued'), numeric: true),
                  ],
                  rows: _allEligibleList.map((summary) {
                    return DataRow(cells: [
                      DataCell(Text(summary.state ?? 'N/A')),
                      DataCell(Text(summary.facilityName ?? 'N/A')),
                      DataCell(Text(summary.totalEligibleClientsInFilter.toString())),
                      DataCell(Text(summary.refillsDueInQuarter.toString())),
                      DataCell(Text(summary.samplesCollected.toString())),
                      DataCell(Text(summary.resultsReturned.toString())),
                      DataCell(Text(summary.suppressed.toString())),
                      DataCell(Text(summary.unsuppressed.toString())),
                      DataCell(Text(summary.samplesCollectedPreviousQuarter.toString())),
                      DataCell(Text(summary.resultsReturnedPreviousQuarter.toString())),
                      DataCell(Text(summary.suppressedPreviousQuarter.toString())),
                      DataCell(Text(summary.unsuppressedPreviousQuarter.toString())),
                      DataCell(Text(summary.samplesCollectedOlder.toString())),
                      DataCell(Text(summary.resultsReturnedOlder.toString())),
                      DataCell(Text(summary.suppressedOlder.toString())),
                      DataCell(Text(summary.unsuppressedOlder.toString())),
                      DataCell(Text(summary.totalDeaths.toString())),
                      DataCell(Text(summary.totalTransferredOut.toString())),
                      DataCell(Text(summary.totalIIT.toString())),
                      DataCell(Text(summary.totalMissedAppointments.toString())),
                      DataCell(Text(summary.totalDiscontinuedCare.toString())),
                    ]);
                  }).toList(),
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
                      _vlSummaryTableController.animateTo(
                        _vlSummaryTableController.offset - 400,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Scroll Right',
                    onPressed: () {
                      _vlSummaryTableController.animateTo(
                        _vlSummaryTableController.offset + 400,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }


  // REPLACED: This method now includes scroll buttons
  Widget _buildCallLogSummaryTable() {
    if (_isInitialState && _callLogs.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_callLogs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: Text('No call logs available for this selection.')),
      );
    }

    _callLogs.sort((a, b) => (b.callDateTime ?? DateTime(1900)).compareTo(a.callDateTime ?? DateTime(1900)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Detailed Call Logs",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SingleChildScrollView(
                controller: _callLogTableController, // Assign controller
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  // ... (DataTable columns and rows are unchanged)
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                  columns: const [
                    DataColumn(label: Text('State', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Facility', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Tracked By', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('ART ID', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Call Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Duration (s)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  ],
                  rows: _callLogs.map((log) {
                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (log.callStatus?.toLowerCase() == 'answered') return Colors.green.withOpacity(0.08);
                        if (log.callStatus?.toLowerCase().contains('fail') ?? false) return Colors.red.withOpacity(0.08);
                        return null;
                      }),
                      cells: [
                        DataCell(Text(log.trackerState ?? 'N/A')),
                        DataCell(Text(log.trackerFacility ?? 'N/A')),
                        DataCell(Text(log.trackedBy ?? 'N/A')),
                        DataCell(Text(_maskClientName(log.clientName))),
                        DataCell(Text(_maskArtId(log.artId))),
                        DataCell(Text(_maskPhoneNumber(log.phoneNumberCalled))),
                        DataCell(Text(log.callDateTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(log.callDateTime!) : 'N/A')),
                        DataCell(
                          Row(
                            children: [
                              Icon(
                                log.callStatus?.toLowerCase() == 'answered' ? Icons.call_received : Icons.call_missed_outgoing,
                                color: log.callStatus?.toLowerCase() == 'answered' ? Colors.green.shade700 : Colors.red.shade700,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(log.callStatus ?? 'N/A'),
                            ],
                          ),
                        ),
                        DataCell(Text(log.callDurationInSeconds?.toString() ?? '0')),
                      ],
                    );
                  }).toList(),
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
                      _callLogTableController.animateTo(
                        _callLogTableController.offset - 400,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Scroll Right',
                    onPressed: () {
                      _callLogTableController.animateTo(
                        _callLogTableController.offset + 400,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }


  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // MODIFIED: The title logic is now simpler.
    final String reportTitle = _selectedFacilityName == null
        ? 'State VL Reports Dashboard'
        : _selectedFacilityName == 'All Facilities'
        ? 'State-wide VL Report ($_userState)'
        : 'VL Report for $_selectedFacilityName';

    // Define chart data lists using the aggregated state variables
    final List<_ChartData> currentQuarterChartData = [
      _ChartData('Samples Coll.', _samplesCollectedInQuarter.toDouble(), Colors.orange.shade300),
      _ChartData('Results Rcvd', _resultsReturnedInQuarter.toDouble(), Colors.teal.shade300),
      _ChartData('Suppressed', _suppressedInQuarter.toDouble(), Colors.green.shade400),
      _ChartData('Unsuppressed', _unsuppressedInQuarter.toDouble(), Colors.red.shade400),
      _ChartData('TAT >3m No Result', _tatExceeded3MonthsCurrentQuarter.toDouble(), Colors.purple.shade300),
      _ChartData('Result TAT >3m', _tatOver3MonthsWithResultCurrentQuarter.toDouble(), Colors.deepOrange.shade300),
    ];

    final List<_ChartData> previousQuarterChartData = [
      _ChartData('Samples Coll.', _samplesCollectedPreviousQuarter.toDouble(), Colors.orange.shade200),
      _ChartData('Results Rcvd', _resultsReturnedPreviousQuarter.toDouble(), Colors.teal.shade200),
      _ChartData('Suppressed', _suppressedPreviousQuarter.toDouble(), Colors.green.shade300),
      _ChartData('Unsuppressed', _unsuppressedPreviousQuarter.toDouble(), Colors.red.shade300),
      _ChartData('TAT >3m No Result', _tatExceeded3MonthsPreviousQuarter.toDouble(), Colors.purple.shade200),
      _ChartData('Result TAT >3m', _tatOver3MonthsWithResultPreviousQuarter.toDouble(), Colors.deepOrange.shade200),
    ];

    final List<_ChartData> olderSamplesChartData = [
      _ChartData('Samples Coll.', _samplesCollectedOlder.toDouble(), Colors.blueGrey.shade200),
      _ChartData('Results Rcvd', _resultsReturnedOlder.toDouble(), Colors.cyan.shade200),
      _ChartData('Suppressed', _suppressedOlder.toDouble(), Colors.lightGreen.shade300),
      _ChartData('Unsuppressed', _unsuppressedOlder.toDouble(), Colors.orange.shade300),
      _ChartData('TAT >3m No Result', _tatExceeded3MonthsOlder.toDouble(), Colors.grey.shade400),
      _ChartData('TAT: Result TAT >3m', _tatOver3MonthsWithResultOlder.toDouble(), Colors.brown.shade200),
    ];

    final List<_ChartData> callStatusData = [
      _ChartData('Answered', _callsAnswered.toDouble(), Colors.greenAccent.shade400),
      _ChartData('Not Answered/\nFailed/Error', _callsNotAnsweredOrFailed.toDouble(), Colors.pinkAccent.shade100),
    ];

    final double reportCardWidth = MediaQuery.of(context).size.width > 900
        ? (MediaQuery.of(context).size.width / 4.5) - 12
        : (MediaQuery.of(context).size.width / 2.3) - 12;

    return Scaffold(
      appBar: AppBar(
       // automaticallyImplyLeading: false,
        title: Text(reportTitle,style: TextStyle(color: Colors.white,),),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _allCellsGloballyUnlocked
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white,
            ),
            tooltip: _allCellsGloballyUnlocked ? 'Mask All Data' : 'Unmask All Data',
            onPressed: _toggleGlobalUnmask,
          ),
          IconButton(
            icon: const Icon(Icons.date_range_outlined, color: Colors.white),
            tooltip: 'Filter Call Logs by Date',
            onPressed: _isInitialState ? null : _showAndApplyDateRangePicker,
          ),
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_download_outlined, color: Colors.white),
              tooltip: "Export Options",
              onSelected: (value) async {
                switch (value) {
                  case 'csv_summary':
                    await _exportSummaryToCSV();
                    break;
                  case 'csv_call_log':
                    await _exportToCSV();
                    break;
                  case 'pdf':
                    await _exportToPDF();
                    break;
                }
              },
              enabled: !_isInitialState &&
                  !_isLoading &&
                  (_allEligibleList.isNotEmpty || _callLogs.isNotEmpty),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'csv_summary',
                  child: Row(
                    children: [
                      const Icon(Icons.summarize_outlined, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text('Export CSV (Summaries)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'csv_call_log',
                  child: Row(
                    children: [
                      const Icon(Icons.grid_on_outlined, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text('Export CSV (Call Log)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text('Export PDF (Charts)'),
                    ],
                  ),
                ),
              ],
            ),

        ],
      ),
      drawer: drawer3(context,),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterBar(),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()))
            else if (_allEligibleList.isEmpty && _masterCallLogs.isEmpty && !_isInitialState)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(
                    "No data available for '$_currentQuarterDisplay' in the $_selectedFacilityName.",
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
            // This Column builds on initial state (with 0s) and after data is loaded.
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Show a helpful hint only on the initial screen load.
                  if (_isInitialState)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        "Showing default values. Please select a facility and click 'Apply Filter' to load the report.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                      ),
                    ),

                  if (_startDateFilter != null && _endDateFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'Call logs filtered from ${DateFormat.yMMMMd().format(_startDateFilter!)} to ${DateFormat.yMMMMd().format(_endDateFilter!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Wrap(
                      spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.spaceEvenly,
                      children: [
                        // MODIFIED: Pass numbers directly and add suffix
                        _buildMetricCard('% Samples Collected', _percentageSampleCollected, subtitle: 'Based on eligible clients', width: reportCardWidth, valueColor: Colors.indigoAccent, suffix: '%'),
                        _buildMetricCard('% Results Received', _percentageResultReceived, subtitle: 'Based on samples collected', width: reportCardWidth, valueColor: Colors.teal, suffix: '%'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Clients Not on Active Treatment', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
                    children: [
                      // MODIFIED: Pass numbers directly
                      _buildMetricCard('Total Not Active', _totalNotActive, width: reportCardWidth, subtitle: '(Across Filtered List)', valueColor: Colors.red.shade800),
                      _buildMetricCard('Deaths', _totalDeaths, width: reportCardWidth, subtitle: 'Overall', valueColor: Colors.black),
                      _buildMetricCard('Transferred Out', _totalTransferredOut, width: reportCardWidth, subtitle: 'Overall', valueColor: Colors.blueGrey),
                      _buildMetricCard('Missed Appt.', _totalMissedAppointments, width: reportCardWidth, subtitle: 'Overall', valueColor: Colors.orange),
                      _buildMetricCard('IIT', _totalIIT, width: reportCardWidth, subtitle: 'Overall', valueColor: Colors.red.shade700),
                      _buildMetricCard('Discontinued Care', _totalDiscontinuedCare, width: reportCardWidth, subtitle: 'Overall', valueColor: Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text('VL Summary ($_currentQuarterDisplay)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
                    children: [
                      // MODIFIED: Pass numbers directly
                      _buildMetricCard('Total Eligible Clients', _totalEligibleOverall, width: reportCardWidth, subtitle: "(Filtered List)"),
                      _buildMetricCard('Due for Refill', _totalEligibleDueForRefillInQuarter, width: reportCardWidth, subtitle: 'In $_currentQuarterDisplay'),
                      _buildMetricCard('Refill (Outside Qtr)', _totalEligibleDueForRefillOutsideQuarter, width: reportCardWidth),
                      _buildMetricCard('Samples Collected', _samplesCollectedInQuarter, width: reportCardWidth, subtitle: 'In $_currentQuarterDisplay'),
                      _buildMetricCard('Results Returned', _resultsReturnedInQuarter, width: reportCardWidth, subtitle: 'For samples in $_currentQuarterDisplay'),
                      _buildMetricCard('Suppressed', _suppressedInQuarter, width: reportCardWidth, subtitle: 'In $_currentQuarterDisplay (<1k)'),
                      _buildMetricCard('Unsuppressed', _unsuppressedInQuarter, width: reportCardWidth, subtitle: 'In $_currentQuarterDisplay (>=1k)'),
                      _buildMetricCard('TAT: No Result >3m', _tatExceeded3MonthsCurrentQuarter, width: reportCardWidth, subtitle: 'Samples from $_currentQuarterDisplay'),
                      _buildMetricCard('TAT: Result TAT >3m', _tatOver3MonthsWithResultCurrentQuarter, width: reportCardWidth, subtitle: 'Samples from $_currentQuarterDisplay'),
                    ],
                  ),
                  if (_samplesCollectedInQuarter > 0)
                    _buildDoughnutChart('$_currentQuarterDisplay: VL Status & TAT', currentQuarterChartData, boundaryKey: _currentQuarterChartBoundaryKey),
                  const SizedBox(height: 20),

                  // ... The rest of the build method follows the same pattern ...
                  // All calls to _buildMetricCard are changed to pass numeric values.

                  Text('VL Summary ($_previousQuarterDisplay)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
                    children: [
                      _buildMetricCard('Samples Collected', _samplesCollectedPreviousQuarter, width: reportCardWidth, subtitle: 'In $_previousQuarterDisplay'),
                      _buildMetricCard('Results Returned', _resultsReturnedPreviousQuarter, width: reportCardWidth, subtitle: 'For samples in $_previousQuarterDisplay'),
                      _buildMetricCard('Suppressed', _suppressedPreviousQuarter, width: reportCardWidth, subtitle: 'In $_previousQuarterDisplay (<1k)'),
                      _buildMetricCard('Unsuppressed', _unsuppressedPreviousQuarter, width: reportCardWidth, subtitle: 'In $_previousQuarterDisplay (>=1k)'),
                      _buildMetricCard('TAT: No Result >3m', _tatExceeded3MonthsPreviousQuarter, width: reportCardWidth, subtitle: 'Samples from $_previousQuarterDisplay'),
                      _buildMetricCard('TAT: Result TAT >3m', _tatOver3MonthsWithResultPreviousQuarter, width: reportCardWidth, subtitle: 'Samples from $_previousQuarterDisplay'),
                    ],
                  ),
                  if (_samplesCollectedPreviousQuarter > 0)
                    _buildDoughnutChart('$_previousQuarterDisplay: VL Status & TAT', previousQuarterChartData, boundaryKey: _previousQuarterChartBoundaryKey),
                  const SizedBox(height: 20),

                  Text(_olderSamplesDisplayTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
                    children: [
                      _buildMetricCard('Samples Collected', _samplesCollectedOlder, width: reportCardWidth, subtitle: 'Collected before $_previousQuarterDisplay'),
                      _buildMetricCard('Results Returned', _resultsReturnedOlder, width: reportCardWidth, subtitle: 'For older samples'),
                      _buildMetricCard('Suppressed', _suppressedOlder, width: reportCardWidth, subtitle: 'Older samples (<1k)'),
                      _buildMetricCard('Unsuppressed', _unsuppressedOlder, width: reportCardWidth, subtitle: 'Older samples (>=1k)'),
                      _buildMetricCard('TAT: No Result >3m', _tatExceeded3MonthsOlder, width: reportCardWidth, subtitle: 'Older samples'),
                      _buildMetricCard('TAT: Result TAT >3m', _tatOver3MonthsWithResultOlder, width: reportCardWidth, subtitle: 'Older samples'),
                    ],
                  ),
                  if (_samplesCollectedOlder > 0)
                    _buildDoughnutChart('Older Samples: VL Status & TAT', olderSamplesChartData, boundaryKey: _olderSamplesChartBoundaryKey),
                  const SizedBox(height: 20),

                  Text('Call Log Analysis', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
                    children: [
                      _buildMetricCard('Total Calls Made', _totalCallsMade, width: reportCardWidth),
                      _buildMetricCard('Calls Answered', _callsAnswered, width: reportCardWidth),
                      _buildMetricCard('Not Answered/Failed', _callsNotAnsweredOrFailed, width: reportCardWidth),
                      _buildMetricCard('Avg. Call Duration', _averageCallDurationSeconds, width: reportCardWidth, subtitle: "(Answered)", suffix: 's', fractionDigits: 1),
                    ],
                  ),
                  if (_totalCallsMade > 0)
                    _buildDoughnutChart('Call Outcomes', callStatusData, boundaryKey: _callOutcomesChartBoundaryKey),
                  const SizedBox(height: 20),
                  // NEW: Add the detailed summary and call log tables here
                  _buildVlSummaryTable(),
                  const SizedBox(height: 20),

                  _buildCallLogSummaryTable(),
                ],
              ),
          ],
        ),
      ),
    );
  }

}